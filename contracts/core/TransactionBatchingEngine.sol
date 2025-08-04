// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

/**
 * @title TransactionBatchingEngine
 * @dev Advanced transaction batching and gas optimization system
 */
contract TransactionBatchingEngine is AccessControl, ReentrancyGuard, EIP712 {
    using ECDSA for bytes32;
    
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");
    bytes32 public constant BATCH_MANAGER_ROLE = keccak256("BATCH_MANAGER_ROLE");
    
    bytes32 private constant BATCH_TYPEHASH = keccak256(
        "BatchOperation(address target,bytes data,uint256 value,uint256 nonce,uint256 deadline)"
    );
    
    enum OperationType {
        DEPOSIT,
        WITHDRAW,
        BORROW,
        REPAY,
        SWAP,
        STAKE,
        UNSTAKE,
        LIQUIDATE,
        REBALANCE
    }
    
    enum BatchStatus {
        PENDING,
        EXECUTING,
        COMPLETED,
        FAILED,
        CANCELLED
    }
    
    struct BatchOperation {
        uint256 operationId;
        address user;
        address target;
        bytes data;
        uint256 value;
        OperationType opType;
        uint256 gasLimit;
        uint256 gasPrice;
        uint256 deadline;
        uint256 nonce;
        bytes signature;
        bool isExecuted;
    }
    
    struct BatchExecution {
        uint256 batchId;
        uint256[] operationIds;
        address executor;
        uint256 totalGasUsed;
        uint256 totalGasSaved;
        uint256 executionTime;
        BatchStatus status;
        uint256 timestamp;
        string failureReason;
    }
    
    struct GasOptimization {
        uint256 baseGasLimit;
        uint256 gasPerOperation;
        uint256 batchDiscount; // Percentage discount for batching
        uint256 priorityFee;
        uint256 maxGasPrice;
        bool dynamicPricing;
    }
    
    struct UserBatchPreferences {
        uint256 maxBatchSize;
        uint256 maxWaitTime;
        uint256 minGasSavings;
        bool autoExecute;
        uint256 slippageTolerance;
    }
    
    // Storage
    mapping(uint256 => BatchOperation) public operations;
    mapping(uint256 => BatchExecution) public batches;
    mapping(address => uint256[]) public userOperations;
    mapping(address => uint256) public userNonces;
    mapping(address => UserBatchPreferences) public userPreferences;
    mapping(OperationType => GasOptimization) public gasOptimizations;
    
    uint256 public operationCounter;
    uint256 public batchCounter;
    uint256 public maxBatchSize = 50;
    uint256 public minBatchSize = 2;
    uint256 public batchTimeout = 300; // 5 minutes
    uint256 public totalGasSaved;
    
    // Pending operations queue
    uint256[] public pendingOperations;
    mapping(OperationType => uint256[]) public operationsByType;
    
    event OperationQueued(
        uint256 indexed operationId,
        address indexed user,
        OperationType opType,
        uint256 gasLimit
    );
    
    event BatchExecuted(
        uint256 indexed batchId,
        uint256 operationsCount,
        uint256 totalGasUsed,
        uint256 gasSaved
    );
    
    event GasOptimizationUpdated(
        OperationType indexed opType,
        uint256 baseGasLimit,
        uint256 batchDiscount
    );
    
    constructor() EIP712("TransactionBatchingEngine", "1") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(EXECUTOR_ROLE, msg.sender);
        _grantRole(BATCH_MANAGER_ROLE, msg.sender);
        
        _initializeGasOptimizations();
    }
    
    /**
     * @dev Queue an operation for batching
     */
    function queueOperation(
        address target,
        bytes calldata data,
        uint256 value,
        OperationType opType,
        uint256 gasLimit,
        uint256 deadline,
        bytes calldata signature
    ) external returns (uint256) {
        require(deadline > block.timestamp, "Operation expired");
        require(gasLimit > 0, "Invalid gas limit");
        
        uint256 operationId = ++operationCounter;
        uint256 nonce = userNonces[msg.sender]++;
        
        // Verify signature
        bytes32 structHash = keccak256(abi.encode(
            BATCH_TYPEHASH,
            target,
            keccak256(data),
            value,
            nonce,
            deadline
        ));
        
        bytes32 hash = _hashTypedDataV4(structHash);
        address signer = hash.recover(signature);
        require(signer == msg.sender, "Invalid signature");
        
        operations[operationId] = BatchOperation({
            operationId: operationId,
            user: msg.sender,
            target: target,
            data: data,
            value: value,
            opType: opType,
            gasLimit: gasLimit,
            gasPrice: tx.gasprice,
            deadline: deadline,
            nonce: nonce,
            signature: signature,
            isExecuted: false
        });
        
        userOperations[msg.sender].push(operationId);
        pendingOperations.push(operationId);
        operationsByType[opType].push(operationId);
        
        emit OperationQueued(operationId, msg.sender, opType, gasLimit);
        
        // Auto-execute if conditions are met
        _checkAutoExecution(opType);
        
        return operationId;
    }
    
    /**
     * @dev Execute a batch of operations
     */
    function executeBatch(uint256[] calldata operationIds) external onlyRole(EXECUTOR_ROLE) nonReentrant {
        require(operationIds.length >= minBatchSize, "Batch too small");
        require(operationIds.length <= maxBatchSize, "Batch too large");
        
        uint256 batchId = ++batchCounter;
        uint256 startGas = gasleft();
        
        batches[batchId] = BatchExecution({
            batchId: batchId,
            operationIds: operationIds,
            executor: msg.sender,
            totalGasUsed: 0,
            totalGasSaved: 0,
            executionTime: block.timestamp,
            status: BatchStatus.EXECUTING,
            timestamp: block.timestamp,
            failureReason: ""
        });
        
        uint256 successCount = 0;
        uint256 totalIndividualGas = 0;
        
        for (uint256 i = 0; i < operationIds.length; i++) {
            uint256 opId = operationIds[i];
            BatchOperation storage op = operations[opId];
            
            if (op.isExecuted || op.deadline < block.timestamp) {
                continue;
            }
            
            uint256 gasBeforeOp = gasleft();
            
            try this.executeOperation(opId) {
                op.isExecuted = true;
                successCount++;
                
                uint256 gasUsedForOp = gasBeforeOp - gasleft();
                totalIndividualGas += op.gasLimit;
                
                _removeFromPending(opId);
            } catch Error(string memory reason) {
                batches[batchId].failureReason = reason;
            }
        }
        
        uint256 totalGasUsed = startGas - gasleft();
        uint256 gasSaved = totalIndividualGas > totalGasUsed ? totalIndividualGas - totalGasUsed : 0;
        
        batches[batchId].totalGasUsed = totalGasUsed;
        batches[batchId].totalGasSaved = gasSaved;
        batches[batchId].status = successCount > 0 ? BatchStatus.COMPLETED : BatchStatus.FAILED;
        
        totalGasSaved += gasSaved;
        
        emit BatchExecuted(batchId, successCount, totalGasUsed, gasSaved);
    }
    
    /**
     * @dev Execute a single operation (internal)
     */
    function executeOperation(uint256 operationId) external {
        require(msg.sender == address(this), "Only internal calls");
        
        BatchOperation storage op = operations[operationId];
        require(!op.isExecuted, "Already executed");
        require(op.deadline >= block.timestamp, "Operation expired");
        
        (bool success, bytes memory result) = op.target.call{value: op.value}(op.data);
        require(success, string(result));
    }
    
    /**
     * @dev Optimize batch by grouping similar operations
     */
    function optimizeBatch(OperationType opType) external onlyRole(BATCH_MANAGER_ROLE) returns (uint256[] memory) {
        uint256[] storage typeOperations = operationsByType[opType];
        uint256[] memory optimizedBatch = new uint256[](maxBatchSize);
        uint256 batchSize = 0;
        
        for (uint256 i = 0; i < typeOperations.length && batchSize < maxBatchSize; i++) {
            uint256 opId = typeOperations[i];
            BatchOperation storage op = operations[opId];
            
            if (!op.isExecuted && op.deadline >= block.timestamp) {
                optimizedBatch[batchSize] = opId;
                batchSize++;
            }
        }
        
        // Resize array to actual size
        uint256[] memory finalBatch = new uint256[](batchSize);
        for (uint256 i = 0; i < batchSize; i++) {
            finalBatch[i] = optimizedBatch[i];
        }
        
        return finalBatch;
    }
    
    /**
     * @dev Calculate gas savings for a potential batch
     */
    function calculateGasSavings(uint256[] calldata operationIds) external view returns (uint256) {
        uint256 totalIndividualGas = 0;
        uint256 batchOverhead = 21000; // Base transaction cost
        
        for (uint256 i = 0; i < operationIds.length; i++) {
            BatchOperation storage op = operations[operationIds[i]];
            totalIndividualGas += op.gasLimit;
        }
        
        uint256 estimatedBatchGas = batchOverhead + (totalIndividualGas * 85) / 100; // 15% savings estimate
        
        return totalIndividualGas > estimatedBatchGas ? totalIndividualGas - estimatedBatchGas : 0;
    }
    
    /**
     * @dev Set user batch preferences
     */
    function setUserPreferences(
        uint256 maxBatchSize_,
        uint256 maxWaitTime,
        uint256 minGasSavings,
        bool autoExecute,
        uint256 slippageTolerance
    ) external {
        userPreferences[msg.sender] = UserBatchPreferences({
            maxBatchSize: maxBatchSize_,
            maxWaitTime: maxWaitTime,
            minGasSavings: minGasSavings,
            autoExecute: autoExecute,
            slippageTolerance: slippageTolerance
        });
    }
    
    /**
     * @dev Update gas optimization parameters
     */
    function updateGasOptimization(
        OperationType opType,
        uint256 baseGasLimit,
        uint256 gasPerOperation,
        uint256 batchDiscount,
        uint256 priorityFee
    ) external onlyRole(ADMIN_ROLE) {
        gasOptimizations[opType] = GasOptimization({
            baseGasLimit: baseGasLimit,
            gasPerOperation: gasPerOperation,
            batchDiscount: batchDiscount,
            priorityFee: priorityFee,
            maxGasPrice: gasOptimizations[opType].maxGasPrice,
            dynamicPricing: gasOptimizations[opType].dynamicPricing
        });
        
        emit GasOptimizationUpdated(opType, baseGasLimit, batchDiscount);
    }
    
    /**
     * @dev Check if auto-execution conditions are met
     */
    function _checkAutoExecution(OperationType opType) internal {
        uint256[] storage typeOps = operationsByType[opType];
        uint256 validOps = 0;
        
        for (uint256 i = 0; i < typeOps.length; i++) {
            BatchOperation storage op = operations[typeOps[i]];
            if (!op.isExecuted && op.deadline >= block.timestamp) {
                validOps++;
            }
        }
        
        if (validOps >= minBatchSize) {
            // Trigger auto-execution
            _executeAutoBatch()
        }
    }
    
    /**
     * @dev Remove operation from pending queue
     */
    function _removeFromPending(uint256 operationId) internal {
        for (uint256 i = 0; i < pendingOperations.length; i++) {
            if (pendingOperations[i] == operationId) {
                pendingOperations[i] = pendingOperations[pendingOperations.length - 1];
                pendingOperations.pop();
                break;
            }
        }
    }
    
    /**
     * @dev Initialize default gas optimizations
     */
    function _initializeGasOptimizations() internal {
        gasOptimizations[OperationType.DEPOSIT] = GasOptimization(50000, 30000, 1500, 0, 100 gwei, true);
        gasOptimizations[OperationType.WITHDRAW] = GasOptimization(60000, 35000, 1500, 0, 100 gwei, true);
        gasOptimizations[OperationType.BORROW] = GasOptimization(80000, 40000, 2000, 0, 100 gwei, true);
        gasOptimizations[OperationType.REPAY] = GasOptimization(70000, 35000, 1500, 0, 100 gwei, true);
        gasOptimizations[OperationType.SWAP] = GasOptimization(100000, 50000, 2500, 0, 100 gwei, true);
        gasOptimizations[OperationType.STAKE] = GasOptimization(90000, 45000, 2000, 0, 100 gwei, true);
        gasOptimizations[OperationType.UNSTAKE] = GasOptimization(95000, 45000, 2000, 0, 100 gwei, true);
        gasOptimizations[OperationType.LIQUIDATE] = GasOptimization(150000, 75000, 3000, 0, 100 gwei, true);
        gasOptimizations[OperationType.REBALANCE] = GasOptimization(120000, 60000, 2500, 0, 100 gwei, true);
    }
    
    /**
     * @dev Get pending operations count
     */
    function getPendingOperationsCount() external view returns (uint256) {
        return pendingOperations.length;
    }
    
    /**
     * @dev Get user operations
     */
    function getUserOperations(address user) external view returns (uint256[] memory) {
        return userOperations[user];
    }
    
    /**
     * @dev Get operations by type
     */
    function getOperationsByType(OperationType opType) external view returns (uint256[] memory) {
        return operationsByType[opType];
    }
    
    /**
     * @dev Emergency cancel operation
     */
    function emergencyCancelOperation(uint256 operationId) external onlyRole(ADMIN_ROLE) {
        operations[operationId].isExecuted = true;
        _removeFromPending(operationId);
    }
    
    /**
     * @dev Update batch parameters
     */
    function updateBatchParameters(
        uint256 newMaxBatchSize,
        uint256 newMinBatchSize,
        uint256 newBatchTimeout
    ) external onlyRole(ADMIN_ROLE) {
        require(newMaxBatchSize > newMinBatchSize, "Invalid batch sizes");
        
        maxBatchSize = newMaxBatchSize;
        minBatchSize = newMinBatchSize;
        batchTimeout = newBatchTimeout;
    }

    /**
     * @dev Execute auto batch when conditions are met
     */
    function _executeAutoBatch() internal {
        // Create a new batch with pending operations
        uint256[] memory operationsToExecute = new uint256[](pendingOperations.length);
        uint256 validCount = 0;
        
        // Filter valid operations
        for (uint256 i = 0; i < pendingOperations.length; i++) {
            uint256 opId = pendingOperations[i];
            BatchOperation storage op = batchOperations[opId];
            
            if (op.status == OperationStatus.PENDING && 
                block.timestamp >= op.earliestExecution &&
                block.timestamp <= op.deadline) {
                operationsToExecute[validCount] = opId;
                validCount++;
                
                if (validCount >= maxBatchSize) {
                    break;
                }
            }
        }
        
        // Execute the batch if we have enough operations
        if (validCount >= minBatchSize) {
            // Resize array to actual count
            uint256[] memory finalOperations = new uint256[](validCount);
            for (uint256 i = 0; i < validCount; i++) {
                finalOperations[i] = operationsToExecute[i];
            }
            
            // Execute the batch
            executeBatch(finalOperations);
        }
    }
}