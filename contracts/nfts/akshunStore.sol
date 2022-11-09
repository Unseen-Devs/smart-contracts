// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./../common/Signable.sol";

interface IAkshun {
    function mint(address to) external returns(uint256);
    function burn(uint256 tokenId) external;
    function transferFrom(address from, address to, uint256 tokenId) external;
}

contract AkshunStore is OwnableUpgradeable, PausableUpgradeable, ReentrancyGuardUpgradeable, Signable {

    using SafeERC20 for IERC20;

    event TreasuryUpdated(address treasury);

    event AkshunTierUpdated(uint256 typeId, uint256 price, uint256 totalSupply);

    event AskhunBought(uint256 typeId, uint256 price, address user, uint256[] akshunIds);

    IERC20 public eth;

    IAkshun public akshun;

    address public treasury;

    struct AkshunTier {
        uint256 price;
        uint256 totalSupply;
        uint256 totalSold;
    }

    //akshun tier id => akshun tier information
    mapping(uint256 => AkshunTier) public akshunTiers;

    mapping(address => uint256) public nonces;

    function initialize(IERC20 _eth, IAkshun _akshun)
        public
        initializer
    {
        __Ownable_init();
        __Pausable_init();
        __ReentrancyGuard_init();

        eth = _eth;
        akshun = _akshun;

        address msgSender = _msgSender();

        treasury = msgSender;

        _setSigner(msgSender);
    }

    function setTreasury(address _treasury)
        public
        onlyOwner
    {
        require(_treasury != address(0), "AskhunNFT: address is invalid");

        treasury = _treasury;

        emit TreasuryUpdated(_treasury);
    }

    function setSigner(address _signer)
        public
        onlyOwner
    {
        _setSigner(_signer);
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


    function setAkshunTier(uint256 _typeId, uint256 _price, uint256 _totalSupply)
        public
        onlyOwner
    {
        require(_price > 0, "AskhunNFT: price is invalid");

        AkshunTier storage akshunTier = akshunTiers[_typeId];

        require(_totalSupply >= akshunTier.totalSold, "AskhunNFT: total supply is invalid");

        if (akshunTier.price != _price) {
            akshunTier.price = _price;
        }

        if (akshunTier.totalSupply != _totalSupply) {
            akshunTier.totalSupply = _totalSupply;
        }

        emit AkshunTierUpdated(_typeId, _price, _totalSupply);
    }

    function buy(uint256 _typeId, uint256 _quantity)
        public
        whenNotPaused
        nonReentrant
    {
        _quantity = 1;

        require(_quantity > 0, "AskhunNFT: quantity is invalid");

        AkshunTier storage akshunTier = akshunTiers[_typeId];

        require(akshunTier.price > 0, "AskhunNFT: Tier does not exist");

        uint256 remain = akshunTier.totalSupply - akshunTier.totalSold;

        require(remain > 0, "AskhunNFT: sold out");

        if (_quantity > remain) {
            _quantity = remain;
        }

        address msgSender = _msgSender();

        eth.safeTransferFrom(msgSender, treasury, akshunTier.price * _quantity);

        akshunTier.totalSold += _quantity;

        uint256[] memory ids = new uint256[](_quantity);

        for (uint256 i = 0; i < _quantity; i++) {
            ids[i] = akshun.mint(msgSender);
        }

        emit AskhunBought(_typeId, akshunTier.price, msgSender, ids);
    }
}