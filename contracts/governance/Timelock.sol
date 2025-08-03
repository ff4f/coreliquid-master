// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "../interfaces/ITimelock.sol";

/**
 * @title Timelock
 * @dev Timelock controller for CoreLiquid Protocol governance operations
 * @author CoreLiquid Protocol
 */
contract Timelock is ITimelock, AccessControl, ReentrancyGuard, Pausable, EIP712 {
    using ECDSA for bytes32;

    // Roles
    bytes32 public constant TIMELOCK_ADMIN_ROLE = keccak256("TIMELOCK_ADMIN_ROLE");
    bytes32 public constant PROPOSER_ROLE = keccak256("PROPOSER_ROLE");
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");
    bytes32 public constant CANCELLER_ROLE = keccak256("CANCELLER_ROLE");
    bytes32 public constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");

    // Constants
    uint256 public constant MINIMUM_DELAY = 1 hours;
    uint256 public constant MAXIMUM_DELAY = 30 days;
    uint256 public constant GRACE_PERIOD = 14 days;
    uint256 public constant MAX_OPERATIONS_PER_BATCH = 100;
    uint256 public constant MAX_PENDING_OPERATIONS = 1000;
    bytes32 public constant DOMAIN_SEPARATOR = keccak256("CoreLiquid Timelock");

    // Storage mappings
    mapping(bytes32 => Operation) public operations;
    mapping(bytes32 => bool) public _isOperationPending;
    mapping(bytes32 => bool) public _isOperationReady;
    mapping(bytes32 => bool) public _isOperationDone;
    mapping(bytes32 => bool) public isOperationCancelled;
    mapping(address => uint256) public proposerNonces;
    mapping(bytes32 => ExecutionResult) public executionResults;
    mapping(address => bytes32[]) public proposerOperations;
    mapping(bytes32 => Signature[]) public operationSignatures;
    mapping(bytes32 => uint256) public operationVotes;
    mapping(bytes32 => mapping(address => bool)) public hasVoted;
    mapping(bytes32 => BatchOperation) public batchOperations;
    mapping(address => bool) public isAuthorizedExecutor;
    mapping(bytes32 => uint256) public operationPriority;
    mapping(bytes32 => bytes32[]) public operationDependencies;
    mapping(bytes32 => bool) public isEmergencyOperation;
    
    // Global arrays
    bytes32[] public allOperations;
    bytes32[] public pendingOperations;
    bytes32[] public readyOperations;
    bytes32[] public executedOperations;
    bytes32[] public cancelledOperations;
    bytes32[] public emergencyOperations;
    address[] public allProposers;
    address[] public allExecutors;
    
    // Timelock configuration
    TimelockConfig public config;
    
    // Counters
    uint256 public totalOperations;
    uint256 public totalExecutions;
    uint256 public totalCancellations;
    uint256 public operationCounter;
    uint256 public batchCounter;
    
    // State variables
    bool public emergencyMode;
    uint256 public lastConfigUpdate;
    mapping(address => uint256) public lastProposalTime;
    mapping(bytes32 => uint256) public operationDeadline;
    mapping(bytes32 => bool) public requiresMultiSig;
    mapping(bytes32 => uint256) public requiredSignatures;
    
    // Events for EIP712
    bytes32 private constant OPERATION_TYPEHASH = keccak256(
        "Operation(bytes32 id,address target,uint256 value,bytes data,bytes32 predecessor,uint256 delay,uint256 nonce)"
    );

    constructor(
        uint256 _minDelay,
        address[] memory _proposers,
        address[] memory _executors,
        address _admin
    ) EIP712("CoreLiquid Timelock", "1") {
        require(_minDelay >= MINIMUM_DELAY, "Delay too short");
        require(_minDelay <= MAXIMUM_DELAY, "Delay too long");
        require(_admin != address(0), "Invalid admin");
        
        config = TimelockConfig({
            minDelay: _minDelay,
            maxDelay: MAXIMUM_DELAY,
            gracePeriod: GRACE_PERIOD,
            maxOperationsPerBatch: MAX_OPERATIONS_PER_BATCH,
            requiresMultiSig: false,
            multiSigThreshold: 2,
            emergencyDelay: 1 hours,
            isActive: true
        });
        
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(TIMELOCK_ADMIN_ROLE, _admin);
        _grantRole(GUARDIAN_ROLE, _admin);
        _grantRole(EMERGENCY_ROLE, _admin);
        
        // Grant proposer role
        for (uint256 i = 0; i < _proposers.length; i++) {
            require(_proposers[i] != address(0), "Invalid proposer");
            _grantRole(PROPOSER_ROLE, _proposers[i]);
            allProposers.push(_proposers[i]);
        }
        
        // Grant executor role
        for (uint256 i = 0; i < _executors.length; i++) {
            require(_executors[i] != address(0), "Invalid executor");
            _grantRole(EXECUTOR_ROLE, _executors[i]);
            allExecutors.push(_executors[i]);
            isAuthorizedExecutor[_executors[i]] = true;
        }
        
        lastConfigUpdate = block.timestamp;
    }

    // Core timelock functions
    function schedule(
        address target,
        uint256 value,
        bytes calldata data,
        bytes32 predecessor,
        bytes32 salt,
        uint256 delay
    ) external override onlyRole(PROPOSER_ROLE) returns (bytes32) {
        require(target != address(0), "Invalid target");
        require(delay >= config.minDelay, "Delay too short");
        require(delay <= config.maxDelay, "Delay too long");
        require(pendingOperations.length < MAX_PENDING_OPERATIONS, "Too many pending operations");
        
        bytes32 id = hashOperation(target, value, data, predecessor, salt);
        require(!_isOperationPending[id] && !_isOperationDone[id], "Operation already exists");
        
        // Check predecessor dependency
        if (predecessor != bytes32(0)) {
            require(_isOperationDone[predecessor], "Predecessor not executed");
        }
        
        uint256 executionTime = block.timestamp + delay;
        
        Operation storage operation = operations[id];
        operation.id = id;
        operation.target = target;
        operation.value = value;
        operation.data = data;
        operation.predecessor = predecessor;
        operation.salt = salt;
        operation.delay = delay;
        operation.scheduledAt = block.timestamp;
        operation.executionTime = executionTime;
        operation.proposer = msg.sender;
        operation.status = OperationStatus.PENDING;
        
        // Set deadline
        operationDeadline[id] = executionTime + config.gracePeriod;
        
        // Update tracking
        allOperations.push(id);
        pendingOperations.push(id);
        proposerOperations[msg.sender].push(id);
        _isOperationPending[id] = true;
        totalOperations++;
        operationCounter++;
        lastProposalTime[msg.sender] = block.timestamp;
        
        emit OperationScheduled(
            id,
            target,
            value,
            data,
            predecessor,
            delay,
            executionTime,
            msg.sender,
            block.timestamp
        );
        
        return id;
    }

    function scheduleBatch(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata payloads,
        bytes32 predecessor,
        bytes32 salt,
        uint256 delay
    ) external override onlyRole(PROPOSER_ROLE) returns (bytes32) {
        require(targets.length > 0, "Empty batch");
        require(targets.length <= config.maxOperationsPerBatch, "Batch too large");
        require(targets.length == values.length, "Length mismatch");
        require(targets.length == payloads.length, "Length mismatch");
        require(delay >= config.minDelay, "Delay too short");
        
        bytes32 batchId = keccak256(abi.encode(
            targets,
            values,
            payloads,
            predecessor,
            salt,
            block.timestamp,
            ++batchCounter
        ));
        
        BatchOperation storage batch = batchOperations[batchId];
        batch.batchId = batchId;
        batch.targets = targets;
        batch.values = values;
        batch.payloads = payloads;
        batch.predecessor = predecessor;
        batch.salt = salt;
        batch.delay = delay;
        batch.scheduledAt = block.timestamp;
        batch.executionTime = block.timestamp + delay;
        batch.proposer = msg.sender;
        batch.operationCount = targets.length;
        batch.status = OperationStatus.PENDING;
        
        // Schedule individual operations
        for (uint256 i = 0; i < targets.length; i++) {
            bytes32 operationId = this.schedule(
                targets[i],
                values[i],
                payloads[i],
                predecessor,
                keccak256(abi.encodePacked(salt, i)),
                delay
            );
            batch.operationIds.push(operationId);
        }
        
        emit BatchScheduled(
            batchId,
            targets.length,
            delay,
            batch.executionTime,
            msg.sender,
            block.timestamp
        );
        
        return batchId;
    }

    function execute(
        address target,
        uint256 value,
        bytes calldata data,
        bytes32 predecessor,
        bytes32 salt
    ) external payable override onlyRole(EXECUTOR_ROLE) nonReentrant returns (bytes memory) {
        bytes32 id = hashOperation(target, value, data, predecessor, salt);
        require(_isOperationReady[id], "Operation not ready");
        require(!_isOperationDone[id], "Operation already executed");
        require(!isOperationCancelled[id], "Operation cancelled");
        require(block.timestamp <= operationDeadline[id], "Operation expired");
        
        Operation storage operation = operations[id];
        require(block.timestamp >= operation.executionTime, "Too early");
        
        // Check multi-signature requirement
        if (requiresMultiSig[id]) {
            require(operationVotes[id] >= requiredSignatures[id], "Insufficient signatures");
        }
        
        // Update status
        operation.status = OperationStatus.EXECUTING;
        operation.executor = msg.sender;
        operation.executedAt = block.timestamp;
        
        // Execute the operation
        bytes memory result;
        bool success;
        
        if (target == address(this)) {
            // Self-call for timelock configuration updates
            (success, result) = target.call{value: value}(data);
        } else {
            // External call
            (success, result) = target.call{value: value}(data);
        }
        
        // Store execution result
        ExecutionResult storage execResult = executionResults[id];
        execResult.operationId = id;
        execResult.success = success;
        execResult.returnData = result;
        execResult.executor = msg.sender;
        execResult.executedAt = block.timestamp;
        execResult.gasUsed = gasleft();
        
        if (success) {
            // Mark as done
            operation.status = OperationStatus.EXECUTED;
            _isOperationDone[id] = true;
        _isOperationReady[id] = false;
        _isOperationPending[id] = false;
            
            // Update tracking arrays
            _removeFromPendingOperations(id);
            _removeFromReadyOperations(id);
            executedOperations.push(id);
            totalExecutions++;
            
            emit OperationExecuted(
                id,
                target,
                value,
                data,
                msg.sender,
                block.timestamp
            );
        } else {
            // Mark as failed
            operation.status = OperationStatus.FAILED;
            
            emit OperationFailed(
                id,
                target,
                value,
                data,
                msg.sender,
                block.timestamp
            );
            
            revert("Operation execution failed");
        }
        
        return result;
    }

    function executeBatch(
        bytes32 batchId
    ) external override onlyRole(EXECUTOR_ROLE) nonReentrant {
        BatchOperation storage batch = batchOperations[batchId];
        require(batch.batchId != bytes32(0), "Batch not found");
        require(batch.status == OperationStatus.PENDING, "Batch not pending");
        require(block.timestamp >= batch.executionTime, "Too early");
        
        batch.status = OperationStatus.EXECUTING;
        batch.executor = msg.sender;
        batch.executedAt = block.timestamp;
        
        uint256 successCount = 0;
        
        // Execute all operations in batch
        for (uint256 i = 0; i < batch.operationIds.length; i++) {
            bytes32 operationId = batch.operationIds[i];
            Operation storage operation = operations[operationId];
            
            if (_isOperationReady[operationId] && !_isOperationDone[operationId]) {
                try this.execute(
                    operation.target,
                    operation.value,
                    operation.data,
                    operation.predecessor,
                    operation.salt
                ) {
                    successCount++;
                } catch {
                    // Continue with next operation
                }
            }
        }
        
        batch.status = successCount == batch.operationCount ? 
            OperationStatus.EXECUTED : OperationStatus.PARTIALLY_EXECUTED;
        batch.successCount = successCount;
        
        emit BatchExecuted(
            batchId,
            successCount,
            batch.operationCount,
            msg.sender,
            block.timestamp
        );
    }

    function cancel(bytes32 id) external override onlyRole(CANCELLER_ROLE) {
        require(_isOperationPending[id], "Operation not pending");
        require(!_isOperationDone[id], "Operation already executed");
        require(!isOperationCancelled[id], "Operation already cancelled");
        
        Operation storage operation = operations[id];
        operation.status = OperationStatus.CANCELLED;
        operation.cancelledAt = block.timestamp;
        operation.cancelledBy = msg.sender;
        
        // Update tracking
        isOperationCancelled[id] = true;
        _isOperationPending[id] = false;
        _isOperationReady[id] = false;
        
        _removeFromPendingOperations(id);
        _removeFromReadyOperations(id);
        cancelledOperations.push(id);
        totalCancellations++;
        
        emit OperationCancelled(id, msg.sender, block.timestamp);
    }

    function updateDelay(uint256 newDelay) external override onlyRole(TIMELOCK_ADMIN_ROLE) {
        require(newDelay >= MINIMUM_DELAY, "Delay too short");
        require(newDelay <= MAXIMUM_DELAY, "Delay too long");
        
        uint256 oldDelay = config.minDelay;
        config.minDelay = newDelay;
        lastConfigUpdate = block.timestamp;
        
        emit DelayUpdated(oldDelay, newDelay, block.timestamp);
    }

    function grantRole(
        bytes32 role,
        address account
    ) public override onlyRole(getRoleAdmin(role)) {
        super.grantRole(role, account);
        
        if (role == PROPOSER_ROLE) {
            _addToProposers(account);
        } else if (role == EXECUTOR_ROLE) {
            _addToExecutors(account);
            isAuthorizedExecutor[account] = true;
        }
    }

    function revokeRole(
        bytes32 role,
        address account
    ) public override onlyRole(getRoleAdmin(role)) {
        super.revokeRole(role, account);
        
        if (role == EXECUTOR_ROLE) {
            isAuthorizedExecutor[account] = false;
        }
    }

    function scheduleEmergencyOperation(
        address target,
        uint256 value,
        bytes calldata data,
        bytes32 salt
    ) external override onlyRole(EMERGENCY_ROLE) returns (bytes32) {
        require(emergencyMode, "Not in emergency mode");
        
        bytes32 id = hashOperation(target, value, data, bytes32(0), salt);
        require(!_isOperationPending[id] && !_isOperationDone[id], "Operation already exists");
        
        uint256 executionTime = block.timestamp + config.emergencyDelay;
        
        Operation storage operation = operations[id];
        operation.id = id;
        operation.target = target;
        operation.value = value;
        operation.data = data;
        operation.predecessor = bytes32(0);
        operation.salt = salt;
        operation.delay = config.emergencyDelay;
        operation.scheduledAt = block.timestamp;
        operation.executionTime = executionTime;
        operation.proposer = msg.sender;
        operation.status = OperationStatus.PENDING;
        
        // Mark as emergency operation
        isEmergencyOperation[id] = true;
        operationDeadline[id] = executionTime + (config.gracePeriod / 2); // Shorter grace period
        
        // Update tracking
        allOperations.push(id);
        pendingOperations.push(id);
        emergencyOperations.push(id);
        _isOperationPending[id] = true;
        totalOperations++;
        
        emit EmergencyOperationScheduled(
            id,
            target,
            value,
            data,
            executionTime,
            msg.sender,
            block.timestamp
        );
        
        return id;
    }

    function enableEmergencyMode() external override onlyRole(GUARDIAN_ROLE) {
        emergencyMode = true;
        _pause();
        
        emit EmergencyModeEnabled(msg.sender, block.timestamp);
    }

    function disableEmergencyMode() external override onlyRole(GUARDIAN_ROLE) {
        emergencyMode = false;
        _unpause();
        
        emit EmergencyModeDisabled(msg.sender, block.timestamp);
    }

    // Multi-signature functions
    function signOperation(
        bytes32 operationId,
        bytes calldata signature
    ) external override {
        require(_isOperationPending[operationId], "Operation not pending");
        require(hasRole(EXECUTOR_ROLE, msg.sender), "Not authorized");
        require(!hasVoted[operationId][msg.sender], "Already signed");
        
        // Verify signature
        bytes32 digest = _hashTypedDataV4(keccak256(abi.encode(
            OPERATION_TYPEHASH,
            operationId,
            operations[operationId].target,
            operations[operationId].value,
            keccak256(operations[operationId].data),
            operations[operationId].predecessor,
            operations[operationId].delay,
            proposerNonces[operations[operationId].proposer]++
        )));
        
        address signer = digest.recover(signature);
        require(signer == msg.sender, "Invalid signature");
        
        // Record signature
        operationSignatures[operationId].push(Signature({
            signer: msg.sender,
            signature: signature,
            timestamp: block.timestamp
        }));
        
        hasVoted[operationId][msg.sender] = true;
        operationVotes[operationId]++;
        
        emit OperationSigned(operationId, msg.sender, block.timestamp);
    }

    // View functions
    function hashOperation(
        address target,
        uint256 value,
        bytes calldata data,
        bytes32 predecessor,
        bytes32 salt
    ) public pure override returns (bytes32) {
        return keccak256(abi.encode(target, value, data, predecessor, salt));
    }

    function hashOperationBatch(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata payloads,
        bytes32 predecessor,
        bytes32 salt
    ) external pure override returns (bytes32) {
        return keccak256(abi.encode(targets, values, payloads, predecessor, salt));
    }

    function isOperation(bytes32 id) external view override returns (bool) {
        return operations[id].id == id;
    }

    function isOperationPending(bytes32 id) external view override returns (bool) {
        return _isOperationPending[id];
    }

    function isOperationReady(bytes32 id) external view override returns (bool) {
        return _isOperationReady[id] && block.timestamp >= operations[id].executionTime;
    }

    function isOperationDone(bytes32 id) external view override returns (bool) {
        return _isOperationDone[id];
    }

    function getTimestamp(bytes32 id) external view override returns (uint256) {
        return operations[id].executionTime;
    }

    function getMinDelay() external view override returns (uint256) {
        return config.minDelay;
    }

    function getOperation(bytes32 id) external view override returns (Operation memory) {
        return operations[id];
    }

    function getBatchOperation(bytes32 batchId) external view override returns (BatchOperation memory) {
        return batchOperations[batchId];
    }

    function getExecutionResult(bytes32 id) external view override returns (ExecutionResult memory) {
        return executionResults[id];
    }

    function getTimelockConfig() external view override returns (TimelockConfig memory) {
        return config;
    }

    function getAllOperations() external view override returns (bytes32[] memory) {
        return allOperations;
    }

    function getPendingOperations() external view override returns (bytes32[] memory) {
        return pendingOperations;
    }

    function getReadyOperations() external view override returns (bytes32[] memory) {
        return readyOperations;
    }

    function getExecutedOperations() external view override returns (bytes32[] memory) {
        return executedOperations;
    }

    function getCancelledOperations() external view override returns (bytes32[] memory) {
        return cancelledOperations;
    }

    function getProposerOperations(address proposer) external view override returns (bytes32[] memory) {
        return proposerOperations[proposer];
    }

    function getOperationSignatures(bytes32 operationId) external view override returns (Signature[] memory) {
        return operationSignatures[operationId];
    }

    function getTimelockMetrics() external view override returns (TimelockMetrics memory) {
        return TimelockMetrics({
            totalOperations: totalOperations,
            pendingOperations: pendingOperations.length,
            readyOperations: readyOperations.length,
            executedOperations: executedOperations.length,
            cancelledOperations: cancelledOperations.length,
            totalExecutions: totalExecutions,
            totalCancellations: totalCancellations,
            emergencyOperations: emergencyOperations.length,
            lastUpdate: block.timestamp
        });
    }

    // Internal functions
    function _removeFromPendingOperations(bytes32 id) internal {
        for (uint256 i = 0; i < pendingOperations.length; i++) {
            if (pendingOperations[i] == id) {
                pendingOperations[i] = pendingOperations[pendingOperations.length - 1];
                pendingOperations.pop();
                break;
            }
        }
    }

    function _removeFromReadyOperations(bytes32 id) internal {
        for (uint256 i = 0; i < readyOperations.length; i++) {
            if (readyOperations[i] == id) {
                readyOperations[i] = readyOperations[readyOperations.length - 1];
                readyOperations.pop();
                break;
            }
        }
    }

    function _addToProposers(address account) internal {
        for (uint256 i = 0; i < allProposers.length; i++) {
            if (allProposers[i] == account) {
                return; // Already in list
            }
        }
        allProposers.push(account);
    }

    function _addToExecutors(address account) internal {
        for (uint256 i = 0; i < allExecutors.length; i++) {
            if (allExecutors[i] == account) {
                return; // Already in list
            }
        }
        allExecutors.push(account);
    }

    // Update ready operations (should be called periodically)
    function updateReadyOperations() external {
        for (uint256 i = 0; i < pendingOperations.length; i++) {
            bytes32 id = pendingOperations[i];
            Operation storage operation = operations[id];
            
            if (block.timestamp >= operation.executionTime && !_isOperationReady[id]) {
            _isOperationReady[id] = true;
                readyOperations.push(id);
                
                emit OperationReady(id, block.timestamp);
            }
        }
    }

    // Configuration update functions
    function updateTimelockConfig(
        TimelockConfig calldata newConfig
    ) external onlyRole(TIMELOCK_ADMIN_ROLE) {
        require(newConfig.minDelay >= MINIMUM_DELAY, "Min delay too short");
        require(newConfig.maxDelay <= MAXIMUM_DELAY, "Max delay too long");
        require(newConfig.gracePeriod > 0, "Invalid grace period");
        require(newConfig.maxOperationsPerBatch > 0, "Invalid max operations per batch");
        require(newConfig.multiSigThreshold > 0, "Invalid multi-sig threshold");
        require(newConfig.emergencyDelay >= MINIMUM_DELAY / 2, "Emergency delay too short");
        
        config = newConfig;
        lastConfigUpdate = block.timestamp;
        
        emit TimelockConfigUpdated(block.timestamp);
    }

    // Admin functions
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    // Receive function to accept ETH
    receive() external payable {
        emit EthReceived(msg.sender, msg.value, block.timestamp);
    }

    // Fallback function
    fallback() external payable {
        emit EthReceived(msg.sender, msg.value, block.timestamp);
    }
}
