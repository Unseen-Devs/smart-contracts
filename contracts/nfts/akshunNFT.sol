// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";

contract Akshun is AccessControlEnumerable, ERC721Enumerable, ERC721Burnable  {

    event BaseURIChanged(string uri);

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    string private _uri;

    uint256 public currentId;

    constructor(string memory name, string memory symbol, string memory uri) ERC721(name, symbol) {
        _uri = uri;

        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());

        _setupRole(MINTER_ROLE, _msgSender());
    }

    function setBaseURI(string memory uri) public virtual {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "Akshun NFT: must have admin role to set");

        require(bytes(uri).length > 0, "Akshun NFT: uri is invalid");

        _uri = uri;

        emit BaseURIChanged(uri);
    }

    function mint(address to) public virtual returns (uint256) {
        require(hasRole(MINTER_ROLE, _msgSender()), "Akshun NFT: must have minter role to mint");

        uint256 id = ++currentId;

        _mint(to, id);

        return id;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _uri;
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal virtual override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(AccessControlEnumerable, ERC721, ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

}