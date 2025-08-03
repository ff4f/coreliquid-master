// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IMultiChainBridge
 * @dev Interface for the Multi-Chain Bridge contract
 * @author CoreLiquid Protocol
 */
interface IMultiChainBridge {
    // Events
    event BridgeTransferInitiated(
        bytes32 indexed transferId,
        address indexed sender,
        address indexed recipient,
        uint256 sourceChainId,
        uint256 destinationChainId,
        address sourceToken,
        address destinationToken,
        uint256 amount,
        uint256 fee,
        uint256 timestamp
    );
    
    event BridgeTransferCompleted(
        bytes32 indexed transferId,
        address indexed recipient,
        uint256 amount,
        uint256 timestamp
    );
    
    event BridgeTransferFailed(
        bytes32 indexed transferId,
        string reason,
        uint256 timestamp
    );
    
    event ChainAdded(
        uint256 indexed chainId,
        string name,
        address bridgeContract,
        bool isActive,
        uint256 timestamp
    );
    
    event ChainUpdated(
        uint256 indexed chainId,
        address oldBridgeContract,
        address newBridgeContract,
        bool isActive,
        uint256 timestamp
    );
    
    event TokenMappingAdded(
        uint256 indexed sourceChainId,
        uint256 indexed destinationChainId,
        address sourceToken,
        address destinationToken,
        uint256 timestamp
    );
    
    event LiquidityAdded(
        uint256 indexed chainId,
        address indexed token,
        address indexed provider,
        uint256 amount,
        uint256 timestamp
    );
    
    event LiquidityRemoved(
        uint256 indexed chainId,
        address indexed token,
        address indexed provider,
        uint256 amount,
        uint256 timestamp
    );
    
    event FeeUpdated(
        uint256 indexed sourceChainId,
        uint256 indexed destinationChainId,
        uint256 oldFee,
        uint256 newFee,
        uint256 timestamp
    );
    
    event ValidatorAdded(
        address indexed validator,
        uint256 timestamp
    );
    
    event ValidatorRemoved(
        address indexed validator,
        uint256 timestamp
    );
    
    event TransferValidated(
        bytes32 indexed transferId,
        address indexed validator,
        bool approved,
        uint256 timestamp
    );
    
    event EmergencyWithdrawal(
        uint256 indexed chainId,
        address indexed token,
        address indexed recipient,
        uint256 amount,
        string reason,
        uint256 timestamp
    );

    // Structs
    struct BridgeTransfer {
        bytes32 transferId;
        address sender;
        address recipient;
        uint256 sourceChainId;
        uint256 destinationChainId;
        address sourceToken;
        address destinationToken;
        uint256 amount;
        uint256 fee;
        uint256 nonce;
        TransferStatus status;
        uint256 initiatedAt;
        uint256 completedAt;
        uint256 validationsRequired;
        uint256 validationsReceived;
        mapping(address => bool) validatorApprovals;
        bytes32 merkleRoot;
        bytes32[] merkleProof;
        bool isEmergency;
        string failureReason;
    }
    
    struct ChainInfo {
        uint256 chainId;
        string name;
        address bridgeContract;
        bool isActive;
        bool isSupported;
        uint256 blockConfirmations;
        uint256 minTransferAmount;
        uint256 maxTransferAmount;
        uint256 dailyLimit;
        uint256 dailyTransferred;
        uint256 lastResetTime;
        uint256 totalTransferred;
        uint256 totalReceived;
        uint256 addedAt;
        uint256 lastUpdate;
    }
    
    struct TokenMapping {
        uint256 sourceChainId;
        uint256 destinationChainId;
        address sourceToken;
        address destinationToken;
        uint256 conversionRate;
        uint256 minAmount;
        uint256 maxAmount;
        bool isActive;
        bool requiresLiquidity;
        uint256 liquidityThreshold;
        uint256 createdAt;
        uint256 lastUpdate;
    }
    
    struct LiquidityPool {
        uint256 chainId;
        address token;
        uint256 totalLiquidity;
        uint256 availableLiquidity;
        uint256 reservedLiquidity;
        mapping(address => uint256) providerBalances;
        mapping(address => uint256) providerShares;
        uint256 totalShares;
        uint256 rewardRate;
        uint256 lastRewardUpdate;
        bool isActive;
        uint256 createdAt;
    }
    
    struct BridgeValidator {
        address validator;
        bool isActive;
        uint256 validationsCount;
        uint256 successfulValidations;
        uint256 reputation;
        uint256 stake;
        uint256 addedAt;
        uint256 lastValidation;
        bool isSlashed;
        uint256 slashAmount;
    }
    
    struct BridgeFee {
        uint256 sourceChainId;
        uint256 destinationChainId;
        uint256 baseFee;
        uint256 percentageFee;
        uint256 minFee;
        uint256 maxFee;
        bool isDynamic;
        uint256 lastUpdate;
    }
    
    struct BridgeMetrics {
        uint256 totalTransfers;
        uint256 successfulTransfers;
        uint256 failedTransfers;
        uint256 totalVolume;
        uint256 totalFees;
        uint256 averageTransferTime;
        uint256 activeChains;
        uint256 totalLiquidity;
        uint256 lastUpdate;
    }
    
    struct CrossChainMessage {
        bytes32 messageId;
        uint256 sourceChainId;
        uint256 destinationChainId;
        address sender;
        address recipient;
        bytes payload;
        uint256 gasLimit;
        uint256 gasPrice;
        MessageStatus status;
        uint256 timestamp;
        uint256 executedAt;
        bytes32 txHash;
    }

    // Enums
    enum TransferStatus {
        PENDING,
        VALIDATED,
        COMPLETED,
        FAILED,
        CANCELLED,
        EXPIRED
    }
    
    enum MessageStatus {
        PENDING,
        RELAYED,
        EXECUTED,
        FAILED
    }

    // Core bridge functions
    function initiateBridgeTransfer(
        uint256 destinationChainId,
        address recipient,
        address token,
        uint256 amount
    ) external payable returns (bytes32 transferId);
    
    function completeBridgeTransfer(
        bytes32 transferId,
        bytes32[] calldata merkleProof
    ) external returns (bool success);
    
    function validateTransfer(
        bytes32 transferId,
        bool approved
    ) external;
    
    function cancelTransfer(
        bytes32 transferId
    ) external;
    
    function retryFailedTransfer(
        bytes32 transferId
    ) external returns (bool success);
    
    // Advanced bridge functions
    function batchBridgeTransfer(
        uint256[] calldata destinationChainIds,
        address[] calldata recipients,
        address[] calldata tokens,
        uint256[] calldata amounts
    ) external payable returns (bytes32[] memory transferIds);
    
    function bridgeWithMessage(
        uint256 destinationChainId,
        address recipient,
        address token,
        uint256 amount,
        bytes calldata message,
        uint256 gasLimit
    ) external payable returns (bytes32 transferId, bytes32 messageId);
    
    function emergencyBridgeTransfer(
        uint256 destinationChainId,
        address recipient,
        address token,
        uint256 amount,
        string calldata justification
    ) external payable returns (bytes32 transferId);
    
    function bridgeWithCallback(
        uint256 destinationChainId,
        address recipient,
        address token,
        uint256 amount,
        address callbackContract,
        bytes calldata callbackData
    ) external payable returns (bytes32 transferId);
    
    // Chain management functions
    function addSupportedChain(
        uint256 chainId,
        string calldata name,
        address bridgeContract,
        uint256 blockConfirmations
    ) external;
    
    function updateChainInfo(
        uint256 chainId,
        address newBridgeContract,
        uint256 blockConfirmations,
        bool isActive
    ) external;
    
    function setChainLimits(
        uint256 chainId,
        uint256 minTransferAmount,
        uint256 maxTransferAmount,
        uint256 dailyLimit
    ) external;
    
    function pauseChain(
        uint256 chainId
    ) external;
    
    function unpauseChain(
        uint256 chainId
    ) external;
    
    // Token mapping functions
    function addTokenMapping(
        uint256 sourceChainId,
        uint256 destinationChainId,
        address sourceToken,
        address destinationToken,
        uint256 conversionRate
    ) external;
    
    function updateTokenMapping(
        uint256 sourceChainId,
        uint256 destinationChainId,
        address sourceToken,
        uint256 newConversionRate,
        bool isActive
    ) external;
    
    function setTokenLimits(
        uint256 sourceChainId,
        uint256 destinationChainId,
        address sourceToken,
        uint256 minAmount,
        uint256 maxAmount
    ) external;
    
    function removeTokenMapping(
        uint256 sourceChainId,
        uint256 destinationChainId,
        address sourceToken
    ) external;
    
    // Liquidity management functions
    function addLiquidity(
        uint256 chainId,
        address token,
        uint256 amount
    ) external returns (uint256 shares);
    
    function removeLiquidity(
        uint256 chainId,
        address token,
        uint256 shares
    ) external returns (uint256 amount);
    
    function rebalanceLiquidity(
        uint256 sourceChainId,
        uint256 destinationChainId,
        address token,
        uint256 amount
    ) external;
    
    function claimLiquidityRewards(
        uint256 chainId,
        address token
    ) external returns (uint256 rewards);
    
    function updateLiquidityRewards(
        uint256 chainId,
        address token
    ) external;
    
    // Validator functions
    function addValidator(
        address validator,
        uint256 stake
    ) external;
    
    function removeValidator(
        address validator
    ) external;
    
    function slashValidator(
        address validator,
        uint256 amount,
        string calldata reason
    ) external;
    
    function updateValidatorStake(
        address validator,
        uint256 newStake
    ) external;
    
    function setValidationThreshold(
        uint256 newThreshold
    ) external;
    
    // Fee management functions
    function updateBridgeFee(
        uint256 sourceChainId,
        uint256 destinationChainId,
        uint256 baseFee,
        uint256 percentageFee
    ) external;
    
    function setDynamicFees(
        uint256 sourceChainId,
        uint256 destinationChainId,
        bool enabled
    ) external;
    
    function updateFeeRecipient(
        address newRecipient
    ) external;
    
    function withdrawFees(
        address token,
        uint256 amount
    ) external;
    
    // Cross-chain messaging functions
    function sendCrossChainMessage(
        uint256 destinationChainId,
        address recipient,
        bytes calldata payload,
        uint256 gasLimit
    ) external payable returns (bytes32 messageId);
    
    function relayCrossChainMessage(
        bytes32 messageId,
        bytes calldata proof
    ) external returns (bool success);
    
    function executeCrossChainMessage(
        bytes32 messageId
    ) external returns (bool success);
    
    function retryCrossChainMessage(
        bytes32 messageId,
        uint256 newGasLimit
    ) external payable returns (bool success);
    
    // Emergency functions
    function emergencyPause() external;
    
    function emergencyUnpause() external;
    
    function emergencyWithdraw(
        uint256 chainId,
        address token,
        uint256 amount,
        string calldata reason
    ) external;
    
    function emergencyStopTransfers(
        uint256 chainId
    ) external;
    
    function emergencyResumeTransfers(
        uint256 chainId
    ) external;
    
    // Configuration functions
    function setMinValidations(
        uint256 newMinValidations
    ) external;
    
    function setTransferTimeout(
        uint256 newTimeout
    ) external;
    
    function setMaxTransferAmount(
        uint256 newMaxAmount
    ) external;
    
    function updateBridgeAdmin(
        address newAdmin
    ) external;
    
    function setRelayerReward(
        uint256 newReward
    ) external;
    
    // View functions - Transfer information
    function getTransfer(
        bytes32 transferId
    ) external view returns (
        address sender,
        address recipient,
        uint256 sourceChainId,
        uint256 destinationChainId,
        address sourceToken,
        address destinationToken,
        uint256 amount,
        TransferStatus status
    );
    
    function getTransferStatus(
        bytes32 transferId
    ) external view returns (TransferStatus);
    
    function getUserTransfers(
        address user
    ) external view returns (bytes32[] memory);
    
    function getPendingTransfers(
        uint256 chainId
    ) external view returns (bytes32[] memory);
    
    function getTransferValidations(
        bytes32 transferId
    ) external view returns (uint256 required, uint256 received);
    
    function isTransferValidated(
        bytes32 transferId
    ) external view returns (bool);
    
    function canCompleteTransfer(
        bytes32 transferId
    ) external view returns (bool);
    
    function getTransferFee(
        uint256 sourceChainId,
        uint256 destinationChainId,
        uint256 amount
    ) external view returns (uint256 fee);
    
    // View functions - Chain information
    function getChainInfo(
        uint256 chainId
    ) external view returns (ChainInfo memory);
    
    function getSupportedChains() external view returns (uint256[] memory);
    
    function isChainSupported(
        uint256 chainId
    ) external view returns (bool);
    
    function isChainActive(
        uint256 chainId
    ) external view returns (bool);
    
    function getChainLimits(
        uint256 chainId
    ) external view returns (
        uint256 minTransferAmount,
        uint256 maxTransferAmount,
        uint256 dailyLimit,
        uint256 dailyTransferred
    );
    
    function canTransferToChain(
        uint256 chainId,
        uint256 amount
    ) external view returns (bool);
    
    // View functions - Token mapping
    function getTokenMapping(
        uint256 sourceChainId,
        uint256 destinationChainId,
        address sourceToken
    ) external view returns (TokenMapping memory);
    
    function getDestinationToken(
        uint256 sourceChainId,
        uint256 destinationChainId,
        address sourceToken
    ) external view returns (address destinationToken);
    
    function isTokenSupported(
        uint256 sourceChainId,
        uint256 destinationChainId,
        address token
    ) external view returns (bool);
    
    function getConversionRate(
        uint256 sourceChainId,
        uint256 destinationChainId,
        address sourceToken
    ) external view returns (uint256 rate);
    
    function getSupportedTokens(
        uint256 chainId
    ) external view returns (address[] memory);
    
    // View functions - Liquidity information
    function getLiquidityPool(
        uint256 chainId,
        address token
    ) external view returns (
        uint256 totalLiquidity,
        uint256 availableLiquidity,
        uint256 reservedLiquidity,
        bool isActive
    );
    
    function getUserLiquidity(
        address user,
        uint256 chainId,
        address token
    ) external view returns (uint256 balance, uint256 shares);
    
    function getLiquidityRewards(
        address user,
        uint256 chainId,
        address token
    ) external view returns (uint256 rewards);
    
    function getTotalLiquidity(
        uint256 chainId
    ) external view returns (uint256 totalLiquidity);
    
    function isLiquidityAvailable(
        uint256 chainId,
        address token,
        uint256 amount
    ) external view returns (bool);
    
    // View functions - Validator information
    function getValidator(
        address validator
    ) external view returns (BridgeValidator memory);
    
    function getAllValidators() external view returns (address[] memory);
    
    function getActiveValidators() external view returns (address[] memory);
    
    function isValidator(
        address account
    ) external view returns (bool);
    
    function getValidatorReputation(
        address validator
    ) external view returns (uint256 reputation);
    
    function getValidationThreshold() external view returns (uint256 threshold);
    
    // View functions - Fee information
    function getBridgeFee(
        uint256 sourceChainId,
        uint256 destinationChainId
    ) external view returns (BridgeFee memory);
    
    function calculateTransferFee(
        uint256 sourceChainId,
        uint256 destinationChainId,
        uint256 amount
    ) external view returns (uint256 fee);
    
    function getFeeRecipient() external view returns (address);
    
    function getCollectedFees(
        address token
    ) external view returns (uint256 amount);
    
    // View functions - Cross-chain messaging
    function getCrossChainMessage(
        bytes32 messageId
    ) external view returns (CrossChainMessage memory);
    
    function getMessageStatus(
        bytes32 messageId
    ) external view returns (MessageStatus);
    
    function getPendingMessages(
        uint256 chainId
    ) external view returns (bytes32[] memory);
    
    function canExecuteMessage(
        bytes32 messageId
    ) external view returns (bool);
    
    // View functions - Metrics and analytics
    function getBridgeMetrics() external view returns (BridgeMetrics memory);
    
    function getChainMetrics(
        uint256 chainId
    ) external view returns (
        uint256 totalTransfers,
        uint256 totalVolume,
        uint256 successRate
    );
    
    function getTokenMetrics(
        address token
    ) external view returns (
        uint256 totalTransfers,
        uint256 totalVolume,
        uint256 averageAmount
    );
    
    function getValidatorMetrics(
        address validator
    ) external view returns (
        uint256 validationsCount,
        uint256 successRate,
        uint256 reputation
    );
    
    function getTransferSuccessRate() external view returns (uint256 successRate);
    
    function getAverageTransferTime() external view returns (uint256 averageTime);
    
    // View functions - System health
    function isSystemHealthy() external view returns (bool);
    
    function getSystemHealth() external view returns (
        bool isHealthy,
        uint256 liquidityHealth,
        uint256 validatorHealth,
        uint256 transferHealth
    );
    
    function getChainHealth(
        uint256 chainId
    ) external view returns (
        bool isHealthy,
        uint256 liquidityHealth,
        uint256 transferHealth
    );
    
    function isPaused() external view returns (bool);
    
    function getLastActivity() external view returns (uint256 lastActivityTime);
    
    function getMinimumLiquidity(
        uint256 chainId,
        address token
    ) external view returns (uint256 minimumLiquidity);
}
