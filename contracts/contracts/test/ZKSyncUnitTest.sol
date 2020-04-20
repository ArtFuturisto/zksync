pragma solidity ^0.5.0;

import "../generated/FranklinTest.sol";


contract ZKSyncUnitTest is FranklinTest {

    function changePubkeySignatureCheck(bytes calldata _signature, bytes20 _newPkHash, uint32 _nonce, address _ethAddress) external pure returns (bool) {
        return verifyChangePubkeySignature(_signature, _newPkHash, _nonce, _ethAddress);
    }

    function setBalanceToWithdraw(address _owner, uint16 _token, uint128 _amount) external {
        balancesToWithdraw[_owner][_token] = _amount;
    }

    function receiveETH() payable external{}

    function addPendingWithdrawal(address _to, uint16 _tokenId, uint128 _amount) external {
        storeWithdrawalAsPending(_to, _tokenId, _amount);
    }

    function testProcessOperation(
        bytes calldata _publicData,
        bytes calldata _ethWitness,
        uint32[] calldata _ethWitnessSizes
    ) external {
        collectOnchainOps(_publicData, _ethWitness, _ethWitnessSizes);
    }

    function testRecoverAddressFromEthSignature(bytes calldata _signature, bytes calldata _message) external pure returns (address) {
        return recoverAddressFromEthSignature(_signature, _message);
    }
}
