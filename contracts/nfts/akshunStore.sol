// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "./../common/Signable.sol";

interface IAkshun {
    function mint(address to) external returns(uint256);
    function burn(uint256 tokenId) external;
    function transferFrom(address from, address to, uint256 tokenId) external;
}

contract AkshunStore is OwnableUpgradeable, PausableUpgradeable, ReentrancyGuardUpgradeable, Signable {

    event AkshunTierUpdated(uint256 typeId, uint256 price, uint256 totalSupply);

    event AskhunBought(uint256 typeId, uint256 price, address user, uint256[] akshunIds);

    event WithdrawFunds(address owner, uint balance);

    IAkshun public akshun;

    struct AkshunTier {
        uint256 price;
        uint256 totalSupply;
        uint256 totalSold;
    }

    //akshun tier id => akshun tier information
    mapping(uint256 => AkshunTier) public akshunTiers;

    mapping(address => uint256) public numAkshuns;

    mapping(address => uint256) public nonces;

    address payable[] recipients;

    function initialize(IAkshun _akshun)
        public
        initializer
    {
        __Ownable_init();
        __Pausable_init();
        __ReentrancyGuard_init();

        akshun = _akshun;

        address msgSender = _msgSender();

        _setSigner(msgSender);
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

    function buy(uint256 _typeId, uint256 _quantity, bytes memory _signature)
        public
        payable
        whenNotPaused
        nonReentrant
    {
        address msgSender = _msgSender();

        require(_verifySignature(abi.encodePacked(msgSender, nonces[msgSender], block.chainid, this), _signature), "AskhunStore: signature is invalid");

        AkshunTier storage akshunTier = akshunTiers[_typeId];

        require(akshunTier.price > 0, "AskhunNFT: Tier does not exist");

        uint256 remain = akshunTier.totalSupply - akshunTier.totalSold;

        require(remain > 0, "AskhunNFT: sold out");

        if (_quantity > remain) {
            _quantity = remain;
        }

        nonces[msgSender]++;

        akshunTier.totalSold += _quantity;

        numAkshuns[msgSender] += _quantity;

        uint256[] memory ids = new uint256[](_quantity);

        for (uint256 i = 0; i < _quantity; i++) {
            ids[i] = akshun.mint(msgSender);
        }

        emit AskhunBought(_typeId, akshunTier.price, msgSender, ids);
    }

    function withdrawFunds() public onlyOwner {
        uint balance = address(this).balance;
        
        require(balance > 0, "Balance should be > 0.");

        payable(msg.sender).transfer(balance);
        
        emit WithdrawFunds(msg.sender, balance);
    }    

    function claimReward(address payable recipient, uint256 amount, bytes memory _signature) external {
        address msgSender = _msgSender();

        require(_verifySignature(abi.encodePacked(msgSender, nonces[msgSender], block.chainid, this), _signature), "AskhunStore: signature is invalid");

        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success, ) = recipient.call{ value: amount }("");

        require(success, "Address: unable to send value, recipient may have reverted");
    }
}