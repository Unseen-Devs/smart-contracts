// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Marketplace is OwnableUpgradeable, PausableUpgradeable, ReentrancyGuardUpgradeable {

    using SafeERC20 for IERC20;

    uint256 constant public ONE_HUNDRED_PERCENT = 10000; // 100%

    event SystemFeeUpdated(uint256 systemFee);
    event TreasuryUpdated(address treasury);
    event Erc20WhitelistUpdated(address[] erc20s, bool status);
    event Erc721WhitelistUpdated(address[] erc721s, bool status);

    event AskCreated(address erc721, address erc20, address seller, uint256 price, uint256 tokenId);
    event AskCanceled(address erc721, address erc20, address seller, uint256 price, uint256 tokenId);
    event BidCreated(address erc721, address erc20, address bidder, uint256 price, uint256 tokenId, uint256 bidId);
    event BidCanceled(address erc721, address erc20, address bidder, uint256 price, uint256 tokenId, uint256 bidId);
    event BidAccepted(address erc721, address erc20, address bidder, address seller, uint256 price, uint256 tokenId, uint256 bidId);
    event TokenSold(address erc721, address erc20, address buyer, address seller, uint256 price, uint256 tokenId);
    event Payout(address erc721, address erc20, uint256 tokenId, uint256 systemFeePayment, uint256 sellerPayment);

    uint256 public systemFeePercent;

    address public treasury;

    // erc20 address => status
    mapping(address => bool) public erc20Whitelist;

    // erc721 address => status
    mapping(address => bool) public erc721Whitelist;

    struct Ask {
        address erc20;
        address seller;
        uint256 price;
    }

    struct Bid {
        address erc20;
        address bidder;
        uint256 price;
    }

    uint256 public bidCounter;

    // erc721 address => token id => bid id => bid order
    mapping(address => mapping(uint256 => mapping(uint256 => Bid))) public bids;

    // user address => erc721 address => token id => bid id
    mapping(address => mapping(address => mapping(uint256 => uint256))) public currentBids;

    // erc721 address => token id => sell order
    mapping(address => mapping(uint256 => Ask)) public asks;

    modifier inWhitelist(address erc721, address erc20) {
        require(erc721Whitelist[erc721] && erc20Whitelist[erc20], "Marketplace: erc721 and erc20 must be in whitelist");
        _;
    }

    function initialize()
        public
        initializer
    {
        __Ownable_init();
        __Pausable_init();
        __ReentrancyGuard_init();

        systemFeePercent = 250; // 2.5%

        treasury = _msgSender();
    }

    function setSystemFee(uint256 percent)
        public
        onlyOwner
    {
        require(percent <= ONE_HUNDRED_PERCENT, "Marketplace: percent is invalid");

        systemFeePercent = percent;

        emit SystemFeeUpdated(percent);
    }

    function setTreasury(address wallet)
        public
        onlyOwner
    {
        require(wallet != address(0), "Marketplace: address is invalid");

        treasury = wallet;

        emit TreasuryUpdated(wallet);
    }

    function setErc20Whitelist(address[] memory erc20s, bool status)
        public
        onlyOwner
    {
        uint256 length = erc20s.length;

        require(length > 0, "Marketplace: array length is invalid");

        for (uint256 i = 0; i < length; i++) {
            erc20Whitelist[erc20s[i]] = status;
        }

        emit Erc20WhitelistUpdated(erc20s, status);
    }

   function setErc721Whitelist(address[] memory erc721s, bool status)
        public
        onlyOwner
    {
        uint256 length = erc721s.length;

        require(length > 0, "Marketplace: array length is invalid");

        for (uint256 i = 0; i < length; i++) {
            erc721Whitelist[erc721s[i]] = status;
        }

        emit Erc721WhitelistUpdated(erc721s, status);
    }

    function pause()
        public
        onlyOwner
    {
        _pause();
    }

    function unpause()
        public
        onlyOwner
    {
        _unpause();
    }

    function setSalePrice(address erc721, address erc20, uint256 tokenId, uint256 price)
        public
        whenNotPaused
        nonReentrant
        inWhitelist(erc721, erc20)
    {
        address msgSender = _msgSender();

        require(price > 0, "Marketplace: price must be greater than 0");

        Ask memory info = asks[erc721][tokenId];

        if (info.seller == address(0)) {
            IERC721(erc721).transferFrom(msgSender, address(this), tokenId);

        } else {
            require(info.seller == msgSender, "Marketplace: can not change sale if sender has not made one");
        }

        asks[erc721][tokenId] = Ask(erc20, msgSender, price);

        emit AskCreated(erc721, erc20, msgSender, price, tokenId);
    }

    function cancelSalePrice(address erc721, uint256 tokenId)
        public
        whenNotPaused
        nonReentrant
    {
        address msgSender = _msgSender();

        Ask memory info = asks[erc721][tokenId];

        require(info.seller == msgSender, "Marketplace: can not cancel sale if sender has not made one");

        IERC721(erc721).transferFrom(address(this), msgSender, tokenId);

        emit AskCanceled(erc721, info.erc20, msgSender, info.price, tokenId);

        delete asks[erc721][tokenId];
    }

    function bid(address erc721, address erc20, uint256 tokenId, uint256 price)
        public
        payable
        whenNotPaused
        nonReentrant
        inWhitelist(erc721, erc20)
    {
        require(price > 0, "Marketplace: price must be greater than 0");

        address msgSender = _msgSender();

        address nftOwner = IERC721(erc721).ownerOf(tokenId);

        require(asks[erc721][tokenId].seller != msgSender && nftOwner != msgSender, "Marketplace: can not bid");

        if (erc20 == address(0)) {
            require(msg.value == price, "Marketplace: deposit amount is not enough");

        } else {
            IERC20(erc20).safeTransferFrom(msgSender, address(this), price);
        }

        uint256 oldBid = currentBids[msgSender][erc721][tokenId];

        uint256 newBid = ++bidCounter;

        bids[erc721][tokenId][newBid] = Bid(erc20, msgSender, price);

        currentBids[msgSender][erc721][tokenId] = newBid;

        emit BidCreated(erc721, erc20, msgSender, price, tokenId, newBid);

        if (oldBid > 0) {
            _cancelBid(erc721, tokenId, msgSender, oldBid);
        }
    }

    function cancelBid(address erc721, uint256 tokenId)
        public
        whenNotPaused
        nonReentrant
    {
        address msgSender = _msgSender();

        _cancelBid(erc721, tokenId, msgSender, currentBids[msgSender][erc721][tokenId]);

        delete currentBids[msgSender][erc721][tokenId];
    }

    function _cancelBid(address erc721, uint256 tokenId, address bidder, uint256 bidId)
        internal
    {
        Bid memory info = bids[erc721][tokenId][bidId];

        require(info.bidder == bidder, "Marketplace: can not cancel a bid if sender has not made one");

        if (info.erc20 == address(0)) {
            payable(bidder).transfer(info.price);

        } else {
            IERC20(info.erc20).safeTransfer(bidder, info.price);
        }

        emit BidCanceled(erc721, info.erc20, bidder, info.price, tokenId, bidId);

        delete bids[erc721][tokenId][bidId];
    }

    function acceptBid(address erc721, uint256 tokenId, uint256 bidId)
        public
        whenNotPaused
        nonReentrant
    {
        address msgSender = _msgSender();

        Bid memory info = bids[erc721][tokenId][bidId];

        require(info.bidder != address(0), "Marketplace: can not accept a bid when there is none");

        address nftOwner = IERC721(erc721).ownerOf(tokenId);

        require(asks[erc721][tokenId].seller == msgSender || nftOwner == msgSender, "Marketplace: sender is not token owner");

        if (nftOwner == address(this)) {
            IERC721(erc721).transferFrom(address(this), info.bidder, tokenId);

        } else {
            IERC721(erc721).transferFrom(msgSender, info.bidder, tokenId);
        }

        _payout(erc721, info.erc20, tokenId, info.price, msgSender);

        emit BidAccepted(erc721, info.erc20, info.bidder, msgSender, info.price, tokenId, bidId);

        delete asks[erc721][tokenId];
        delete currentBids[info.bidder][erc721][tokenId];
        delete bids[erc721][tokenId][bidId];
    }

    function buy(address erc721, uint256 tokenId, uint256 price)
        public
        payable
        whenNotPaused
        nonReentrant
    {
        address msgSender = _msgSender();

        Ask memory info = asks[erc721][tokenId];

        require(info.price > 0, "Marketplace: token is not for sale");

        require(info.price == price, "Marketplace: price does not match");

        require(info.seller != msgSender, "Marketplace: can not buy");

        if (info.erc20 == address(0)) {
            require(msg.value == info.price, "Marketplace: deposit amount is not enough");

        } else {
            IERC20(info.erc20).safeTransferFrom(msgSender, address(this), info.price);
        }

        IERC721(erc721).transferFrom(address(this), msgSender, tokenId);

        _payout(erc721, info.erc20, tokenId, info.price, info.seller);

        emit TokenSold(erc721, info.erc20, msgSender, info.seller, info.price, tokenId);

        uint256 oldBid = currentBids[msgSender][erc721][tokenId];

        delete asks[erc721][tokenId];
        delete bids[erc721][tokenId][oldBid];
        delete currentBids[msgSender][erc721][tokenId];
    }

    function _payout(address erc721, address erc20, uint256 tokenId, uint256 price, address seller)
        internal
    {
        uint256 systemFeePayment = _calculateSystemFee(price, systemFeePercent);

        uint256 sellerPayment = price - systemFeePayment;

        if (erc20 == address(0)) {
            if (systemFeePayment > 0) {
                payable(treasury).transfer(systemFeePayment);
            }

            if (sellerPayment > 0) {
                payable(seller).transfer(sellerPayment);
            }

        } else {
            if (systemFeePayment > 0) {
                IERC20(erc20).safeTransfer(treasury, systemFeePayment);
            }

            if (sellerPayment > 0) {
                IERC20(erc20).safeTransfer(seller, sellerPayment);
            }
        }

        emit Payout(erc721, erc20, tokenId, systemFeePayment, sellerPayment);
    }

    function _calculateSystemFee(uint256 price, uint256 feePercent)
        internal
        pure
        returns (uint256)
    {
        return price * feePercent / ONE_HUNDRED_PERCENT;
    }

}