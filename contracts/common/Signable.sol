// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./../lib/Signature.sol";

abstract contract Signable {

    using Signature for bytes32;

    event SignerUpdated(address signer);

    address public signer;

    function _setSigner(address _signer)
        internal
    {
        require(_signer != address(0), "Signable: address is invalid");

        signer = _signer;

        emit SignerUpdated(_signer);
    }

    function _verifySignature(bytes memory _data, bytes memory _signature)
        internal
        view
        returns(bool)
    {
        bytes32 message = keccak256(_data).prefixed();

        return message.recoverSigner(_signature) == signer;
    }

}