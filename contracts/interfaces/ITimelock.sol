// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title ITimelock
 * @dev Interface for timelock controller used in governance
 */
interface ITimelock {
    /**
     * @dev Operation states
     */
    enum OperationState {
        Unset,
        Waiting,
        Ready,
        Done
    }

    /**
     * @dev Events
     */
    event CallScheduled(
        bytes32 indexed id,
        uint256 indexed index,
        address target,
        uint256 value,
        bytes data,
        bytes32 predecessor,
        uint256 delay
    );

    event CallExecuted(
        bytes32 indexed id,
        uint256 indexed index,
        address target,
        uint256 value,
        bytes data
    );

    event CallSalt(
        bytes32 indexed id,
        bytes32 salt
    );

    event Cancelled(bytes32 indexed id);

    event MinDelayChange(uint256 oldDuration, uint256 newDuration);

    event RoleAdminChanged(
        bytes32 indexed role,
        bytes32 indexed previousAdminRole,
        bytes32 indexed newAdminRole
    );

    event RoleGranted(
        bytes32 indexed role,
        address indexed account,
        address indexed sender
    );

    event RoleRevoked(
        bytes32 indexed role,
        address indexed account,
        address indexed sender
    );

    /**
     * @dev Role constants
     */
    function TIMELOCK_ADMIN_ROLE() external view returns (bytes32);
    function PROPOSER_ROLE() external view returns (bytes32);
    function EXECUTOR_ROLE() external view returns (bytes32);
    function CANCELLER_ROLE() external view returns (bytes32);
    function DEFAULT_ADMIN_ROLE() external view returns (bytes32);

    /**
     * @dev Core timelock functions
     */
    function schedule(
        address target,
        uint256 value,
        bytes calldata data,
        bytes32 predecessor,
        bytes32 salt,
        uint256 delay
    ) external;

    function scheduleBatch(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata payloads,
        bytes32 predecessor,
        bytes32 salt,
        uint256 delay
    ) external;

    function execute(
        address target,
        uint256 value,
        bytes calldata payload,
        bytes32 predecessor,
        bytes32 salt
    ) external payable;

    function executeBatch(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata payloads,
        bytes32 predecessor,
        bytes32 salt
    ) external payable;

    function cancel(bytes32 id) external;

    /**
     * @dev Query functions
     */
    function getMinDelay() external view returns (uint256);

    function getTimestamp(bytes32 id) external view returns (uint256);

    function getOperationState(bytes32 id) external view returns (OperationState);

    function isOperation(bytes32 id) external view returns (bool);

    function isOperationPending(bytes32 id) external view returns (bool);

    function isOperationReady(bytes32 id) external view returns (bool);

    function isOperationDone(bytes32 id) external view returns (bool);

    /**
     * @dev Hash functions
     */
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

    /**
     * @dev Role management functions
     */
    function hasRole(bytes32 role, address account) external view returns (bool);

    function getRoleAdmin(bytes32 role) external view returns (bytes32);

    function grantRole(bytes32 role, address account) external;

    function revokeRole(bytes32 role, address account) external;

    function renounceRole(bytes32 role, address account) external;

    /**
     * @dev Administrative functions
     */
    function updateDelay(uint256 newDelay) external;

    /**
     * @dev Batch operations
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);

    /**
     * @dev Emergency functions
     */
    function emergencyExecute(
        address target,
        uint256 value,
        bytes calldata data
    ) external payable;

    function setEmergencyAdmin(address newEmergencyAdmin) external;

    function emergencyAdmin() external view returns (address);

    /**
     * @dev Proposal management
     */
    function getProposalCount() external view returns (uint256);

    function getProposal(bytes32 id) external view returns (
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory data,
        bytes32 predecessor,
        bytes32 salt,
        uint256 timestamp
    );

    /**
     * @dev Delay management
     */
    function setMinDelay(uint256 newDelay) external;

    function getMaxDelay() external view returns (uint256);

    function setMaxDelay(uint256 newMaxDelay) external;

    /**
     * @dev Grace period functions
     */
    function getGracePeriod() external view returns (uint256);

    function setGracePeriod(uint256 newGracePeriod) external;

    /**
     * @dev Queue management
     */
    function queuedTransactions(bytes32 txHash) external view returns (bool);

    function queueTransaction(
        address target,
        uint256 value,
        string calldata signature,
        bytes calldata data,
        uint256 eta
    ) external returns (bytes32);

    function cancelTransaction(
        address target,
        uint256 value,
        string calldata signature,
        bytes calldata data,
        uint256 eta
    ) external;

    function executeTransaction(
        address target,
        uint256 value,
        string calldata signature,
        bytes calldata data,
        uint256 eta
    ) external payable returns (bytes memory);

    /**
     * @dev Access control helpers
     */
    function onlyRole(bytes32 role) external view;

    function checkRole(bytes32 role) external view;

    function checkRole(bytes32 role, address account) external view;

    /**
     * @dev Pausable functions
     */
    function pause() external;

    function unpause() external;

    function paused() external view returns (bool);

    /**
     * @dev Upgrade functions
     */
    function upgradeTo(address newImplementation) external;

    function upgradeToAndCall(
        address newImplementation,
        bytes calldata data
    ) external payable;

    /**
     * @dev Version and compatibility
     */
    function version() external view returns (string memory);

    /**
     * @dev Receive and fallback
     */
    receive() external payable;

    fallback() external payable;
}