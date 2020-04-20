pragma solidity ^0.5.0;

import "../node_modules/openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import "../node_modules/openzeppelin-solidity/contracts/utils/ReentrancyGuard.sol";

import "./Storage.sol";
import "./Config.sol";
import "./Events.sol";

import "./Bytes.sol";
import "./Operations.sol";


/// @title zkSync main contract
/// @author Matter Labs
contract Franklin is UpgradeableMaster, Storage, Config, Events, ReentrancyGuard {

    // Upgrade functional

    /// @notice Notice period before activation preparation status of upgrade mode
    function upgradeNoticePeriod() external returns (uint) {
        return UPGRADE_NOTICE_PERIOD;
    }

    /// @notice Notification that upgrade notice period started
    function upgradeNoticePeriodStarted() external {

    }

    /// @notice Notification that upgrade preparation status is activated
    function upgradePreparationStarted() external {
        upgradePreparationActive = true;
        upgradePreparationActivationTime = now;
    }

    /// @notice Notification that upgrade canceled
    function upgradeCanceled() external {
        upgradePreparationActive = false;
        upgradePreparationActivationTime = 0;
    }

    /// @notice Notification that upgrade finishes
    function upgradeFinishes() external {
        upgradePreparationActive = false;
        upgradePreparationActivationTime = 0;
    }

    /// @notice Checks that contract is ready for upgrade
    /// @return bool flag indicating that contract is ready for upgrade
    function readyForUpgrade() external returns (bool) {
        return !exodusMode && totalOpenPriorityRequests == 0;
    }

    // // Migration

    // // Address of the new version of the contract to migrate accounts to
    // // Can be proposed by network governor
    // address public migrateTo;

    // // Migration deadline: after this ETH block number migration may happen with the contract
    // // entering exodus mode for all users who have not opted in for migration
    // uint32  public migrateByBlock;

    // // Flag for the new contract to indicate that the migration has been sealed
    // bool    public migrationSealed;

    // mapping (uint32 => bool) tokenMigrated;

    constructor() public {}

    /// @notice Franklin contract initialization
    /// @param initializationParameters Encoded representation of initialization parameters:
    /// _governanceAddress The address of Governance contract
    /// _verifierAddress The address of Verifier contract
    /// _ // FIXME: remove _genesisAccAddress
    /// _genesisRoot Genesis blocks (first block) root
    function initialize(bytes calldata initializationParameters) external {
        (
        address _governanceAddress,
        address _verifierAddress,
        ,
        bytes32 _genesisRoot
        ) = abi.decode(initializationParameters, (address, address, address, bytes32));

        verifier = Verifier(_verifierAddress);
        governance = Governance(_governanceAddress);

        blocks[0].stateRoot = _genesisRoot;
    }

    /// @notice executes pending withdrawals
    /// @param _n The number of withdrawals to complete starting from oldest
    function completeWithdrawals(uint32 _n) external nonReentrant {
        // TODO: when switched to multi validators model we need to add incentive mechanism to call complete.
        uint32 toProcess = minU32(_n, numberOfPendingWithdrawals);
        uint32 startIndex = firstPendingWithdrawalIndex;
        numberOfPendingWithdrawals -= toProcess;
        if (numberOfPendingWithdrawals == 0) {
            firstPendingWithdrawalIndex = 0;
        } else {
            firstPendingWithdrawalIndex += toProcess;
        }

        for (uint32 i = startIndex; i < startIndex + toProcess; ++i) {
            uint16 tokenId = pendingWithdrawals[i].tokenId;
            address to = pendingWithdrawals[i].to;
            // send fails are ignored hence there is always a direct way to withdraw.
            delete pendingWithdrawals[i];

            uint128 amount = balancesToWithdraw[to][tokenId];
            // amount is zero means funds has been withdrawn with withdrawETH or withdrawERC20
            if (amount != 0) {
                // avoid reentrancy attack by using subtract and not "= 0" and changing local state before external call
                balancesToWithdraw[to][tokenId] -= amount;
                bool sent = false;
                if (tokenId == 0) {
                    address payable toPayable = address(uint160(to));
                    sent = toPayable.send(amount);
                } else {
                    address tokenAddr = governance.tokenAddresses(tokenId);
                    require(tokenAddr != address(0), "cwd11"); // unknown tokenId
                    sent = IERC20(tokenAddr).transfer(to, amount);
                }
                if (!sent) {
                    balancesToWithdraw[to][tokenId] += amount;
                }
            }
        }
    }

    function minU32(uint32 a, uint32 b) internal pure returns (uint32) {
        return a < b ? a : b;
    }

    function minU64(uint64 a, uint64 b) internal pure returns (uint64) {
        return a < b ? a : b;
    }

    /// @notice Accrues users balances from deposit priority requests in Exodus mode
    /// @dev WARNING: Only for Exodus mode
    /// @dev Canceling may take several separate transactions to be completed
    /// @param _requests number of requests to process
    function cancelOutstandingDepositsForExodusMode(uint64 _requests) external nonReentrant {
        require(exodusMode, "coe01"); // exodus mode not active
        require(_requests > 0, "coe02"); // provided zero number of requests
        require(totalOpenPriorityRequests > 0, "coe03"); // no priority requests left
        uint64 toProcess = minU64(totalOpenPriorityRequests, _requests);
        for (uint64 i = 0; i < toProcess; i++) {
            uint64 id = firstPriorityRequestId + i;
            if (priorityRequests[id].opType == Operations.OpType.Deposit) {
                Operations.Deposit memory op = Operations.readDepositPubdata(priorityRequests[id].pubData, 0);
                balancesToWithdraw[op.owner][op.tokenId] += op.amount;
            }
            delete priorityRequests[id];
        }
        firstPriorityRequestId += toProcess;
        totalOpenPriorityRequests -= toProcess;
    }

    // function scheduleMigration(address _migrateTo, uint32 _migrateByBlock) external {
    //     requireGovernor();
    //     require(migrateByBlock == 0, "migration in progress");
    //     migrateTo = _migrateTo;
    //     migrateByBlock = _migrateByBlock;
    // }

    // // Anybody MUST be able to call this function
    // function sealMigration() external {
    //     require(migrateByBlock > 0, "no migration scheduled");
    //     migrationSealed = true;
    //     exodusMode = true;
    // }

    // // Anybody MUST be able to call this function
    // function migrateToken(uint32 _tokenId, uint128 /*_amount*/, bytes calldata /*_proof*/) external {
    //     require(migrationSealed, "migration not sealed");
    //     requireValidToken(_tokenId);
    //     require(tokenMigrated[_tokenId]==false, "token already migrated");
    //     // TODO: check the proof for the amount
    //     // TODO: transfer ERC20 or ETH to the `migrateTo` address
    //     tokenMigrated[_tokenId] = true;

    //     require(false, "unimplemented");
    // }

    /// @notice Deposit ETH to Layer 2 - transfer ether from user into contract, validate it, register deposit
    /// @param _amount Amount to deposit (if user specified msg.value more than this amount + fee - she will receive difference)
    /// @param _franklinAddr The receiver Layer 2 address
    function depositETH(uint128 _amount, address _franklinAddr) external payable nonReentrant {
        requireActive();

        // Fee is:
        //   fee coeff * base tx gas cost * gas price
        uint fee = FEE_GAS_PRICE_MULTIPLIER * BASE_DEPOSIT_ETH_GAS * tx.gasprice;

        uint totalValue = fee + _amount;
        require(totalValue >= _amount, "fdh10");  // integer overflow (fee + amount)

        require(msg.value >= totalValue, "fdh11"); // Not enough ETH provided

        if (msg.value != totalValue) {
            uint refund = msg.value - totalValue;

            // Doublecheck to never refund more than received!
            require(refund < msg.value, "fdh12");
            msg.sender.transfer(refund);
        }

        registerDeposit(0, _amount, fee, _franklinAddr);
    }

    /// @notice Withdraw ETH to Layer 1 - register withdrawal and transfer ether to sender
    /// @param _amount Ether amount to withdraw
    function withdrawETH(uint128 _amount) external nonReentrant {
        registerSingleWithdrawal(0, _amount);
        msg.sender.transfer(_amount);
    }

    /// @notice Deposit ERC20 token to Layer 2 - transfer ERC20 tokens from user into contract, validate it, register deposit
    /// @param _token Token address
    /// @param _amount Token amount
    /// @param _franklinAddr Receiver Layer 2 address
    function depositERC20(IERC20 _token, uint128 _amount, address _franklinAddr) external payable {
        requireActive();

        // Fee is:
        //   fee coeff * base tx gas cost * gas price
        uint256 fee = FEE_GAS_PRICE_MULTIPLIER * BASE_DEPOSIT_ERC_GAS * tx.gasprice;

        // Get token id by its address
        uint16 tokenId = governance.validateTokenAddress(address(_token));

        require(_token.transferFrom(msg.sender, address(this), _amount), "fd012"); // token transfer failed deposit

        registerDeposit(tokenId, _amount, fee, _franklinAddr);

        require(msg.value >= fee, "fd011"); // Not enough ETH provided to pay the fee
        if (msg.value != fee) {
            msg.sender.transfer(msg.value - fee);
        }
    }

    /// @notice Withdraw ERC20 token to Layer 1 - register withdrawal and transfer ERC20 to sender
    /// @param _token Token address
    /// @param _amount amount to withdraw
    function withdrawERC20(IERC20 _token, uint128 _amount) external nonReentrant {
        uint16 tokenId = governance.validateTokenAddress(address(_token));
        registerSingleWithdrawal(tokenId, _amount);
        require(_token.transfer(msg.sender, _amount), "fw011"); // token transfer failed withdraw
    }

    /// @notice Register full exit request - pack pubdata, add priority request
    /// @param _accountId Numerical id of the account
    /// @param _token Token address, 0 address for ether
    function fullExit (uint24 _accountId, address _token) external payable nonReentrant {
        requireActive();

        // Fee is:
        //   fee coeff * base tx gas cost * gas price
        uint256 fee = FEE_GAS_PRICE_MULTIPLIER * BASE_FULL_EXIT_GAS * tx.gasprice;

        uint16 tokenId;
        if (_token == address(0)) {
            tokenId = 0;
        } else {
            tokenId = governance.validateTokenAddress(_token);
        }

        // Priority Queue request
        Operations.FullExit memory op = Operations.FullExit({
            accountId:  _accountId,
            owner:      msg.sender,
            tokenId:    tokenId,
            amount:     0 // unknown at this point
        });
        bytes memory pubData = Operations.writeFullExitPubdata(op);
        addPriorityRequest(Operations.OpType.FullExit, fee, pubData);

        require(msg.value >= fee, "fft11"); // Not enough ETH provided to pay the fee
        if (msg.value != fee) {
            msg.sender.transfer(msg.value-fee);
        }
    }

    /// @notice Register deposit request - pack pubdata, add priority request and emit OnchainDeposit event
    /// @param _token Token by id
    /// @param _amount Token amount
    /// @param _fee Validator fee
    /// @param _owner Receiver
    function registerDeposit(
        uint16 _token,
        uint128 _amount,
        uint256 _fee,
        address _owner
    ) internal {
        require(governance.isValidTokenId(_token), "rgd11"); // invalid token id

        // Priority Queue request
        Operations.Deposit memory op = Operations.Deposit({
            owner:      _owner,
            tokenId:    _token,
            amount:     _amount
        });
        bytes memory pubData = Operations.writeDepositPubdata(op);
        addPriorityRequest(Operations.OpType.Deposit, _fee, pubData);

        emit OnchainDeposit(
            msg.sender,
            _token,
            _amount,
            _fee,
            _owner
        );
    }

    /// @notice Register withdrawal - update user balances and emit OnchainWithdrawal event
    /// @param _token - token by id
    /// @param _amount - token amount
    function registerSingleWithdrawal(uint16 _token, uint128 _amount) internal {
        uint128 balance = balancesToWithdraw[msg.sender][_token];
        require(balance >= _amount, "frw11"); // insufficient balance withdraw
        balancesToWithdraw[msg.sender][_token] = balance - _amount;
        emit OnchainWithdrawal(
            msg.sender,
            _token,
            _amount
        );
    }

    /// @notice Commit block - collect onchain operations, create its commitment, emit BlockCommitted event
    /// @param _blockNumber Block number
    /// @param _feeAccount Account to collect fees
    /// @param _newRoot New tree root
    /// @param _publicData Operations pubdata
    /// @param _ethWitness Data passed to ethereum outside pubdata of the circuit.
    /// @param _ethWitnessSizes Amount of eth witness bytes for the corresponding operation.
    ///
    /// _blockNumber is not necessary but it may help to catch server-side errors.
    function commitBlock(
        uint32 _blockNumber,
        uint24 _feeAccount,
        bytes32 _newRoot,
        bytes calldata _publicData,
        bytes calldata _ethWitness,
        uint32[] calldata _ethWitnessSizes
    ) external nonReentrant {
        bytes memory publicData = _publicData;

        requireActive();
        require(_blockNumber == totalBlocksCommitted + 1, "fck11"); // only commit next block
        governance.requireActiveValidator(msg.sender);
        require(!isBlockCommitmentExpired(), "fck12"); // committed blocks had expired
        if(!triggerExodusIfNeeded()) {
            // Unpack onchain operations and store them.
            // Get onchain operations start id for global onchain operations counter,
            // onchain operations number for this block, priority operations number for this block.
            uint64 firstOnchainOpId = totalOnchainOps;
            uint64 prevTotalCommittedPriorityRequests = totalCommittedPriorityRequests;

            uint64 nOnchainOpsProcessed = collectOnchainOps(publicData, _ethWitness, _ethWitnessSizes);

            uint64 nPriorityRequestProcessed = totalCommittedPriorityRequests - prevTotalCommittedPriorityRequests;

            createCommittedBlock(_blockNumber, _feeAccount, _newRoot, publicData, totalOnchainOps, nPriorityRequestProcessed);
            totalBlocksCommitted++;

            emit BlockCommitted(_blockNumber);
        }
    }

    /// @notice Store committed block structure to the storage.
    /// @param _nCumulativeOnchainOpsProcessed - cumulative number of onchain ops
    /// @param _nCommittedPriorityRequests - number of priority requests in block
    function createCommittedBlock(
        uint32 _blockNumber,
        uint24 _feeAccount,
        bytes32 _newRoot,
        bytes memory _publicData,
        uint64 _nCumulativeOnchainOpsProcessed, uint64 _nCommittedPriorityRequests
    ) internal {
        require(_publicData.length % 8 == 0, "cbb10"); // Public data size is not multiple of 8

        uint32 blockChunks = uint32(_publicData.length / 8);
        require(verifier.isBlockSizeSupported(blockChunks), "ccb11");

        // Create block commitment for verification proof
        bytes32 commitment = createBlockCommitment(
            _blockNumber,
            _feeAccount,
            blocks[_blockNumber - 1].stateRoot,
            _newRoot,
            _publicData
        );

        uint24 validatorId = governance.getValidatorId(msg.sender);

        blocks[_blockNumber] = Block(
            validatorId, // validatorId
            uint32(block.number), // committed at
            _nCumulativeOnchainOpsProcessed, // cumulative number of onchain ops
            _nCommittedPriorityRequests, // number of priority onchain ops in block
            blockChunks,
            commitment, // blocks' commitment
            _newRoot // new root
        );
    }

    /// @notice Gets operations packed in bytes array. Unpacks it and stores onchain operations.
    /// @param _publicData Operations packed in bytes array
    /// @param _ethWitness Eth witness that was posted with commit
    /// @param _ethWitnessSizes Amount of eth witness bytes for the corresponding operation.
    function collectOnchainOps(bytes memory _publicData, bytes memory _ethWitness, uint32[] memory _ethWitnessSizes)
        internal returns (uint64 processedOnchainOperations) {
        require(_publicData.length % 8 == 0, "fcs11"); // pubdata length must be a multiple of 8 because each chunk is 8 bytes

        uint64 currentOnchainOps = 0;

        uint256 pubDataPtr = 0;
        uint256 pubDataStartPtr = 0;
        uint256 pubDataEndPtr = 0;
        assembly {
            pubDataStartPtr := add(_publicData, 0x20)
            pubDataPtr := pubDataStartPtr
            pubDataEndPtr := add(pubDataStartPtr, mload(_publicData))
        }

        uint64 ethWitnessOffset = 0;
        uint16 processedOperationsRequiringEthWitness = 0;

        while (pubDataPtr<pubDataEndPtr) {
            uint8 opType;
            // read operation type from public data (the first byte per each operation)
            assembly {
                opType := shr(0xf8, mload(pubDataPtr))
            }

            // cheap transfer operation processing
            if (opType == uint8(Operations.OpType.Transfer)) {
                pubDataPtr += TRANSFER_BYTES;
            } else {
                // other operations processing

                // calculation of public data offset
                uint256 pubdataOffset;
                assembly {
                    // Number of pubdata bytes processed equal to current pubData memory pointer minus pubData memory start pointer
                    pubdataOffset := sub(pubDataPtr, pubDataStartPtr)
                }

                if (opType == uint8(Operations.OpType.Noop)) {
                    pubDataPtr += NOOP_BYTES;
                } else if (opType == uint8(Operations.OpType.TransferToNew)) {
                    pubDataPtr += TRANSFER_TO_NEW_BYTES;
                } else if (opType == uint8(Operations.OpType.CloseAccount)) {
                    pubDataPtr += CLOSE_ACCOUNT_BYTES;
                } else if (opType == uint8(Operations.OpType.Deposit)) {
                    bytes memory pubData = Bytes.slice(_publicData, pubdataOffset + 1, DEPOSIT_BYTES - 1);
                    onchainOps[totalOnchainOps + currentOnchainOps] = OnchainOperation(
                        Operations.OpType.Deposit,
                        pubData
                    );
                    commitNextPriorityOperation(onchainOps[totalOnchainOps + currentOnchainOps]);
                    currentOnchainOps++;

                    pubDataPtr += DEPOSIT_BYTES;
                } else if (opType == uint8(Operations.OpType.PartialExit)) {
                    bytes memory pubData = Bytes.slice(_publicData, pubdataOffset + 1, PARTIAL_EXIT_BYTES - 1);
                    onchainOps[totalOnchainOps + currentOnchainOps] = OnchainOperation(
                        Operations.OpType.PartialExit,
                        pubData
                    );
                    currentOnchainOps++;

                    pubDataPtr += PARTIAL_EXIT_BYTES;
                } else if (opType == uint8(Operations.OpType.FullExit)) {
                    bytes memory pubData = Bytes.slice(_publicData, pubdataOffset + 1, FULL_EXIT_BYTES - 1);
                    onchainOps[totalOnchainOps + currentOnchainOps] = OnchainOperation(
                        Operations.OpType.FullExit,
                        pubData
                    );
                    commitNextPriorityOperation(onchainOps[totalOnchainOps + currentOnchainOps]);
                    currentOnchainOps++;

                    pubDataPtr += FULL_EXIT_BYTES;
                } else if (opType == uint8(Operations.OpType.ChangePubKey)) {
                    require(processedOperationsRequiringEthWitness < _ethWitnessSizes.length, "fcs13"); // eth witness data malformed
                    Operations.ChangePubKey memory op = Operations.readChangePubKeyPubdata(_publicData, pubdataOffset + 1);

                    if (_ethWitnessSizes[processedOperationsRequiringEthWitness] != 0) {
                        bytes memory currentEthWitness = Bytes.slice(_ethWitness, ethWitnessOffset, _ethWitnessSizes[processedOperationsRequiringEthWitness]);

                        bool valid = verifyChangePubkeySignature(currentEthWitness, op.pubKeyHash, op.nonce, op.owner);
                        require(valid, "fpp15"); // failed to verify change pubkey hash signature
                    } else {
                        bool valid = authFacts[op.owner][op.nonce] == keccak256(abi.encodePacked(op.pubKeyHash));
                        require(valid, "fpp16"); // new pub key hash is not authenticated properly
                    }

                    ethWitnessOffset += _ethWitnessSizes[processedOperationsRequiringEthWitness];
                    processedOperationsRequiringEthWitness++;

                    pubDataPtr += CHANGE_PUBKEY_BYTES;
                } else {
                    revert("fpp14"); // unsupported op
                }
            }
        }
        require(pubDataPtr == pubDataEndPtr, "fcs12"); // last chunk exceeds pubdata
        require(ethWitnessOffset == _ethWitness.length, "fcs14"); // _ethWitness was not used completely
        require(processedOperationsRequiringEthWitness == _ethWitnessSizes.length, "fcs15"); // _ethWitnessSizes was not used completely

        totalOnchainOps += currentOnchainOps;
        return currentOnchainOps;
    }

    /// @notice Recovers signer's address from ethereum signature for given message
    /// @param _signature 65 bytes concatenated. R (32) + S (32) + V (1)
    /// @param _message signed message.
    /// @return address of the signer
    function recoverAddressFromEthSignature(bytes memory _signature, bytes memory _message) internal pure returns (address) {
        require(_signature.length == 2*ETH_SIGN_RS_BYTES + 1, "ves10"); // incorrect signature length

        uint offset = 0;
        bytes32 signR = Bytes.bytesToBytes32(Bytes.slice(_signature, offset, ETH_SIGN_RS_BYTES));
        offset += ETH_SIGN_RS_BYTES;
        bytes32 signS = Bytes.bytesToBytes32(Bytes.slice(_signature, offset, ETH_SIGN_RS_BYTES));
        offset += ETH_SIGN_RS_BYTES;
        uint8 signV = uint8(_signature[offset]);

        return ecrecover(keccak256(_message), signV, signR, signS);
    }

    function verifyChangePubkeySignature(bytes memory _signature, bytes20 _newPkHash, uint32 _nonce, address _ethAddress) internal pure returns (bool) {
        require(_newPkHash.length == 20, "vpk11"); // unexpected hash length

        bytes memory signedMessage = abi.encodePacked(
            "\x19Ethereum Signed Message:\n135",
            "Register ZK Sync pubkey:\n\n",
            "sync:", Bytes.bytesToHexASCIIBytes(abi.encodePacked(_newPkHash)),
            " nonce: 0x", Bytes.bytesToHexASCIIBytes(Bytes.toBytesFromUInt32(_nonce)),
            "\n\n",
            "Only sign this message for a trusted client!"
        );
        address recoveredAddress = recoverAddressFromEthSignature(_signature, signedMessage);
        return recoveredAddress == _ethAddress;
    }

    /// @notice Creates block commitment from its data
    /// @param _blockNumber Block number
    /// @param _feeAccount Account to collect fees
    /// @param _oldRoot Old tree root
    /// @param _newRoot New tree root
    /// @param _publicData Operations pubdata
    /// @return block commitment
    function createBlockCommitment(
        uint32 _blockNumber,
        uint24 _feeAccount,
        bytes32 _oldRoot,
        bytes32 _newRoot,
        bytes memory _publicData
    ) internal view returns (bytes32 commitment) {
        bytes32 hash = sha256(
            abi.encodePacked(uint256(_blockNumber), uint256(_feeAccount))
        );
        hash = sha256(abi.encodePacked(hash, uint256(_oldRoot)));
        hash = sha256(abi.encodePacked(hash, uint256(_newRoot)));

        /// The code below is equivalent to `commitment = sha256(abi.encodePacked(hash, _publicData))`

        /// We use inline assembly instead of this concise and readable code in order to avoid copying of `_publicData` (which saves ~90 gas per transfer operation).

        /// Specifically, we perform the following trick:
        /// First, replace the first 32 bytes of `_publicData` (where normally its length is stored) with the value of `hash`.
        /// Then, we call `sha256` precompile passing the `_publicData` pointer and the length of the concatenated byte buffer.
        /// Finally, we put the `_publicData.length` back to its original location (to the first word of `_publicData`).
        assembly {
            let hashResult := mload(0x40)
            let pubDataLen := mload(_publicData)
            mstore(_publicData, hash)
            // staticcall to the sha256 precompile at address 0x2
            let success := staticcall(
                gas,
                0x2,
                _publicData,
                add(pubDataLen, 0x20),
                hashResult,
                0x20
            )
            mstore(_publicData, pubDataLen)

            // Use "invalid" to make gas estimation work
            switch success case 0 { invalid() }

            commitment := mload(hashResult)
        }
    }

    function commitNextPriorityOperation(OnchainOperation memory _onchainOp) internal {
        uint64 cachedTotalCommitedPriorityRequests = totalCommittedPriorityRequests;
        require(totalOpenPriorityRequests > cachedTotalCommitedPriorityRequests, "vnp11"); // no more priority requests in queue

        uint64 _priorityRequestId = firstPriorityRequestId + cachedTotalCommitedPriorityRequests;
        Operations.OpType priorReqType = priorityRequests[_priorityRequestId].opType;
        bytes memory priorReqPubdata = priorityRequests[_priorityRequestId].pubData;

        require(priorReqType == _onchainOp.opType, "nvp12"); // incorrect priority op type

        if (_onchainOp.opType == Operations.OpType.Deposit) {
            require(Operations.depositPubdataMatch(priorReqPubdata, _onchainOp.pubData), "vnp13");
        } else if (_onchainOp.opType == Operations.OpType.FullExit) {
            require(Operations.fullExitPubdataMatch(priorReqPubdata, _onchainOp.pubData), "vnp14");
        } else {
            revert("vnp15"); // invalid or non-priority operation
        }

        totalCommittedPriorityRequests++;
    }

    /// @notice Block verification.
    /// @notice Verify proof -> consummate onchain ops (accrue balances from withdrawals) -> remove priority requests
    /// @param _blockNumber Block number
    /// @param _proof Block proof
    function verifyBlock(uint32 _blockNumber, uint256[8] calldata _proof)
        external nonReentrant
    {
        requireActive();
        require(_blockNumber == totalBlocksVerified + 1, "fvk11"); // only verify next block
        governance.requireActiveValidator(msg.sender);

        require(verifier.verifyBlockProof(_proof, blocks[_blockNumber].commitment, blocks[_blockNumber].chunks), "fvk13"); // proof verification failed

        completeOnchainOps(_blockNumber);

        uint24 blockValidatorId = blocks[_blockNumber].validatorId;
        address blockValidatorAddress = governance.getValidatorAddress(blockValidatorId);

        collectValidatorsFeeAndDeleteRequests(
            blocks[_blockNumber].priorityOperations,
            blockValidatorAddress
        );

        totalBlocksVerified += 1;

        emit BlockVerified(_blockNumber);
    }

    /// @notice When block with withdrawals is verified we store them and complete in separate tx. Withdrawals can be complete by calling withdrawEth, withdrawERC20 or completeWithdrawals.
    /// @param _to Receiver
    /// @param _tokenId Token id
    /// @param _amount Token amount
    function storeWithdrawalAsPending(address _to, uint16 _tokenId, uint128 _amount) internal {
        uint128 balance = balancesToWithdraw[_to][_tokenId];
        if (balance == 0) {
            pendingWithdrawals[firstPendingWithdrawalIndex + numberOfPendingWithdrawals] = PendingWithdrawal(_to, _tokenId);
            numberOfPendingWithdrawals++;
        }

        balancesToWithdraw[_to][_tokenId] += _amount;
    }

    /// @notice If block is verified the onchain operations from it must be completed
    /// @notice (user must have possibility to withdraw funds if withdrawed)
    /// @param _blockNumber Number of block
    function completeOnchainOps(uint32 _blockNumber) internal {
        uint64 start = 0;
        if (_blockNumber != 0) {
            start = blocks[_blockNumber - 1].cumulativeOnchainOperations;
        }

        uint64 end = blocks[_blockNumber].cumulativeOnchainOperations;

        for (uint64 current = start; current < end; ++current) {
            OnchainOperation memory op = onchainOps[current];
            if (op.opType == Operations.OpType.PartialExit) {
                // partial exit was successful, accrue balance
                Operations.PartialExit memory data = Operations.readPartialExitPubdata(op.pubData);
                storeWithdrawalAsPending(data.owner, data.tokenId, data.amount);
            }
            if (op.opType == Operations.OpType.FullExit) {
                // full exit was successful, accrue balance
                Operations.FullExit memory data = Operations.readFullExitPubdata(op.pubData);
                storeWithdrawalAsPending(data.owner, data.tokenId, data.amount);
            }
            delete onchainOps[current];
        }
    }

    /// @notice Checks whether oldest unverified block has expired
    /// @return bool flag that indicates whether oldest unverified block has expired
    function isBlockCommitmentExpired() internal view returns (bool) {
        return (
            totalBlocksCommitted > totalBlocksVerified &&
            blocks[totalBlocksVerified + 1].committedAtBlock > 0 &&
            block.number > blocks[totalBlocksVerified + 1].committedAtBlock + EXPECT_VERIFICATION_IN
        );
    }

    /// @notice Reverts unverified blocks
    /// @param _maxBlocksToRevert the maximum number blocks that will be reverted (use if can't revert all blocks because of gas limit).
    function revertBlocks(uint32 _maxBlocksToRevert) external nonReentrant {
        // TODO: limit who can call this method

        require(isBlockCommitmentExpired(), "rbs11"); // trying to revert non-expired blocks.

        uint32 blocksCommited = totalBlocksCommitted;
        uint32 blocksToRevert = minU32(_maxBlocksToRevert, blocksCommited - totalBlocksVerified);
        uint64 revertedPriorityRequests = 0;

        for (uint32 i = totalBlocksCommitted - blocksToRevert + 1; i <= blocksCommited; i++) {
            Block memory revertedBlock = blocks[i];
            require(revertedBlock.committedAtBlock > 0, "frk11"); // block not found

            revertedPriorityRequests += revertedBlock.priorityOperations;

            delete blocks[i];
        }

        blocksCommited = blocksToRevert;
        totalBlocksCommitted -= blocksToRevert;

        totalOnchainOps = blocks[blocksCommited].cumulativeOnchainOperations;
        totalCommittedPriorityRequests -= revertedPriorityRequests;

        emit BlocksReverted(totalBlocksVerified, blocksCommited);
    }

    /// @notice Checks that upgrade preparation is active and it is in lock period (period when contract will not add any new priority requests)
    function upgradePreparationLockStatus() public returns (bool) {
        return upgradePreparationActive && now < upgradePreparationActivationTime + UPGRADE_PREPARATION_LOCK_PERIOD;
    }

    /// @notice Checks that current state not is exodus mode
    function requireActive() internal view {
        require(!exodusMode, "fre11"); // exodus mode activated
    }

    /// @notice Checks if Exodus mode must be entered. If true - enters exodus mode and emits ExodusMode event.
    /// @dev Exodus mode must be entered in case of current ethereum block number is higher than the oldest
    /// @dev of existed priority requests expiration block number.
    /// @return bool flag that is true if the Exodus mode must be entered.
    function triggerExodusIfNeeded() public returns (bool) {
        bool trigger = block.number >= priorityRequests[firstPriorityRequestId].expirationBlock &&
            priorityRequests[firstPriorityRequestId].expirationBlock != 0;
        if (trigger) {
            if (!exodusMode) {
                exodusMode = true;
                emit ExodusMode();
            }
            return true;
        } else {
            return false;
        }
    }

    /// @notice Withdraws token from Franklin to root chain in case of exodus mode. User must provide proof that he owns funds
    /// @param _proof Proof
    /// @param _tokenId Verified token id
    /// @param _amount Amount for owner (must be total amount, not part of it)
    function exit(uint16 _tokenId, uint128 _amount, uint256[8] calldata _proof) external nonReentrant {
        require(exodusMode, "fet11"); // must be in exodus mode
        require(!exited[msg.sender][_tokenId], "fet12"); // already exited
        require(verifier.verifyExitProof(blocks[totalBlocksVerified].stateRoot, msg.sender, _tokenId, _amount, _proof), "fet13"); // verification failed

        balancesToWithdraw[msg.sender][_tokenId] += _amount;
        exited[msg.sender][_tokenId] = true;
    }

    function authPubkeyHash(bytes calldata _fact, uint32 _nonce) external nonReentrant {
        require(_fact.length == PUBKEY_HASH_BYTES, "ahf10"); // PubKeyHash should be 20 bytes.
        require(authFacts[msg.sender][_nonce] == bytes32(0), "ahf11"); // auth fact for nonce should be empty

        authFacts[msg.sender][_nonce] = keccak256(_fact);

        emit FactAuth(msg.sender, _nonce, _fact);
    }

    // Priority queue

    /// @notice Saves priority request in storage
    /// @dev Calculates expiration block for request, store this request and emit NewPriorityRequest event
    /// @param _opType Rollup operation type
    /// @param _fee Validators' fee
    /// @param _pubData Operation pubdata
    function addPriorityRequest(
        Operations.OpType _opType,
        uint256 _fee,
        bytes memory _pubData
    ) internal {
        require(!upgradePreparationLockStatus(), "apr11"); // apr11 - priority request can't be added during lock period of preparation of upgrade

        // Expiration block is: current block number + priority expiration delta
        uint256 expirationBlock = block.number + PRIORITY_EXPIRATION;

        uint64 nextPriorityRequestId =  firstPriorityRequestId + totalOpenPriorityRequests;

        priorityRequests[nextPriorityRequestId] = PriorityOperation({
            opType: _opType,
            pubData: _pubData,
            expirationBlock: expirationBlock,
            fee: _fee
        });

        emit NewPriorityRequest(
            msg.sender,
            nextPriorityRequestId,
            _opType,
            _pubData,
            expirationBlock,
            _fee
        );

        totalOpenPriorityRequests++;
    }

    /// @notice Collects fees from provided requests number for the block validator, store it on her
    /// @notice balance to withdraw in Ether and delete this requests
    /// @param _number The number of requests
    /// @param _validator The address to pay fees
    /// @return validators fee
    function collectValidatorsFeeAndDeleteRequests(uint64 _number, address _validator) internal {
        require(_number <= totalOpenPriorityRequests, "pcs21"); // number is higher than total priority requests number

        uint256 totalFee = 0;
        for (uint64 i = firstPriorityRequestId; i < firstPriorityRequestId + _number; i++) {
            totalFee += priorityRequests[i].fee;
            delete priorityRequests[i];
        }
        totalOpenPriorityRequests -= _number;
        firstPriorityRequestId += _number;
        totalCommittedPriorityRequests -= _number;

        balancesToWithdraw[_validator][0] += uint128(totalFee);
    }

}
