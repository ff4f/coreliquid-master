// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title ITimelock
 * @dev Interface for CoreLiquid Protocol Timelock controller
 * @author CoreLiquid Protocol
 */
interface ITimelock {
    // Enums
    enum OperationStatus {
        PENDING,
        READY,
        EXECUTING,
        EXECUTED,
        CANCELLED,
        FAILED,
        PARTIALLY_EXECUTED
    }

    // Structs
    struct Operation {
        bytes32 id;
        address target;
        uint256 value;
        bytes data;
        bytes32 predecessor;
        bytes32 salt;
        uint256 delay;
        uint256 scheduledAt;
        uint256 executionTime;
        uint256 executedAt;
        uint256 cancelledAt;
        address proposer;
        address executor;
        address cancelledBy;
        OperationStatus status;
    }

    struct BatchOperation {
        bytes32 batchId;
        address[] targets;
        uint256[] values;
        bytes[] payloads;
        bytes32 predecessor;
        bytes32 salt;
        uint256 delay;
        uint256 scheduledAt;
        uint256 executionTime;
        uint256 executedAt;
        address proposer;
        address executor;
        uint256 operationCount;
        uint256 successCount;
        bytes32[] operationIds;
        OperationStatus status;
    }

    struct ExecutionResult {
        bytes32 operationId;
        bool success;
        bytes returnData;
        address executor;
        uint256 executedAt;
        uint256 gasUsed;
    }

    struct TimelockConfig {
        uint256 minDelay;
        uint256 maxDelay;
        uint256 gracePeriod;
        uint256 maxOperationsPerBatch;
        bool requiresMultiSig;
        uint256 multiSigThreshold;
        uint256 emergencyDelay;
        bool isActive;
    }

    struct TimelockMetrics {
        uint256 totalOperations;
        uint256 pendingOperations;
        uint256 readyOperations;
        uint256 executedOperations;
        uint256 cancelledOperations;
        uint256 totalExecutions;
        uint256 totalCancellations;
        uint256 emergencyOperations;
        uint256 lastUpdate;
    }

    struct Signature {
        address signer;
        bytes signature;
        uint256 timestamp;
    }

    // Events
    event OperationScheduled(
        bytes32 indexed id,
        address indexed target,
        uint256 value,
        bytes data,
        bytes32 predecessor,
        uint256 delay,
        uint256 executionTime,
        address indexed proposer,
        uint256 timestamp
    );

    event BatchScheduled(
        bytes32 indexed batchId,
        uint256 operationCount,
        uint256 delay,
        uint256 executionTime,
        address indexed proposer,
        uint256 timestamp
    );

    event OperationExecuted(
        bytes32 indexed id,
        address indexed target,
        uint256 value,
        bytes data,
        address indexed executor,
        uint256 timestamp
    );

    event BatchExecuted(
        bytes32 indexed batchId,
        uint256 successCount,
        uint256 totalCount,
        address indexed executor,
        uint256 timestamp
    );

    event OperationCancelled(
        bytes32 indexed id,
        address indexed canceller,
        uint256 timestamp
    );

    event OperationFailed(
        bytes32 indexed id,
        address indexed target,
        uint256 value,
        bytes data,
        address indexed executor,
        uint256 timestamp
    );

    event OperationReady(
        bytes32 indexed id,
        uint256 timestamp
    );

    event OperationSigned(
        bytes32 indexed operationId,
        address indexed signer,
        uint256 timestamp
    );

    event DelayUpdated(
        uint256 oldDelay,
        uint256 newDelay,
        uint256 timestamp
    );

    event EmergencyOperationScheduled(
        bytes32 indexed id,
        address indexed target,
        uint256 value,
        bytes data,
        uint256 executionTime,
        address indexed proposer,
        uint256 timestamp
    );

    event EmergencyModeEnabled(
        address indexed enabler,
        uint256 timestamp
    );

    event EmergencyModeDisabled(
        address indexed disabler,
        uint256 timestamp
    );

    event TimelockConfigUpdated(
        uint256 timestamp
    );

    event EthReceived(
        address indexed sender,
        uint256 amount,
        uint256 timestamp
    );

    // Core timelock functions
    function schedule(
        address target,
        uint256 value,
        bytes calldata data,
        bytes32 predecessor,
        bytes32 salt,
        uint256 delay
    ) external returns (bytes32);

    function scheduleBatch(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata payloads,
        bytes32 predecessor,
        bytes32 salt,
        uint256 delay
    ) external returns (bytes32);

    function execute(
        address target,
        uint256 value,
        bytes calldata data,
        bytes32 predecessor,
        bytes32 salt
    ) external payable returns (bytes memory);

    function executeBatch(
        bytes32 batchId
    ) external;

    function cancel(bytes32 id) external;

    function updateDelay(uint256 newDelay) external;

    // Emergency functions
    function scheduleEmergencyOperation(
        address target,
        uint256 value,
        bytes calldata data,
        bytes32 salt
    ) external returns (bytes32);

    function enableEmergencyMode() external;

    function disableEmergencyMode() external;

    // Multi-signature functions
    function signOperation(
        bytes32 operationId,
        bytes calldata signature
    ) external;

    // View functions
    function hashOperation(
        address target,
        uint256 value,
        bytes calldata data,
        bytes32 predecessor,
        bytes32 salt
    ) external pure returns (bytes32);

    function hashOperationBatch(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata payloads,
        bytes32 predecessor,
        bytes32 salt
    ) external pure returns (bytes32);

    function isOperation(bytes32 id) external view returns (bool);

    function isOperationPending(bytes32 id) external view returns (bool);

    function isOperationReady(bytes32 id) external view returns (bool);

    function isOperationDone(bytes32 id) external view returns (bool);

    function getTimestamp(bytes32 id) external view returns (uint256);

    function getMinDelay() external view returns (uint256);

    function getOperation(bytes32 id) external view returns (Operation memory);

    function getBatchOperation(bytes32 batchId) external view returns (BatchOperation memory);

    function getExecutionResult(bytes32 id) external view returns (ExecutionResult memory);

    function getTimelockConfig() external view returns (TimelockConfig memory);

    function getAllOperations() external view returns (bytes32[] memory);

    function getPendingOperations() external view returns (bytes32[] memory);

    function getReadyOperations() external view returns (bytes32[] memory);

    function getExecutedOperations() external view returns (bytes32[] memory);

    function getCancelledOperations() external view returns (bytes32[] memory);

    function getProposerOperations(address proposer) external view returns (bytes32[] memory);

    function getOperationSignatures(bytes32 operationId) external view returns (Signature[] memory);

    function getTimelockMetrics() external view returns (TimelockMetrics memory);
}
