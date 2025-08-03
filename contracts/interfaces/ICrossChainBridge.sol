// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title ICrossChainBridge
 * @dev Interface for the Cross Chain Bridge contract
 * @author CoreLiquid Protocol
 */
interface ICrossChainBridge {
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
        uint256 actualAmount,
        uint256 executionTime,
        uint256 timestamp
    );
    
    event BridgeTransferFailed(
        bytes32 indexed transferId,
        FailureReason reason,
        string errorMessage,
        uint256 timestamp
    );
    
    event ChainAdded(
        uint256 indexed chainId,
        string chainName,
        address bridgeContract,
        bool isActive,
        uint256 timestamp
    );
    
    event ChainRemoved(
        uint256 indexed chainId,
        string reason,
        uint256 timestamp
    );
    
    event EmergencyPause(
        uint256 indexed chainId,
        string reason,
        uint256 timestamp
    );
    
    event TransactionValidated(
        bytes32 indexed transactionId,
        address indexed validator,
        bool isValid,
        uint256 timestamp
    );
    
    event TransactionExecuted(
        bytes32 indexed transactionId,
        address indexed executor,
        uint256 timestamp
    );
    
    event TransactionChallenged(
        bytes32 indexed transactionId,
        address indexed challenger,
        string reason,
        uint256 timestamp
    );
    
    event ChallengeResolved(
        bytes32 indexed transactionId,
        bool upholdChallenge,
        string resolution,
        address indexed resolver,
        uint256 timestamp
    );
    
    event TokenAdded(
        address indexed token,
        string name,
        string symbol,
        BridgeType bridgeType,
        uint256 timestamp
    );
    
    event SecurityConfigSet(
        bytes32 indexed configId,
        uint256 maxAmount,
        uint256 dailyLimit,
        uint256 validationThreshold,
        uint256 timestamp
    );
    
    event EmergencyWithdraw(
        address indexed token,
        uint256 amount,
        address indexed recipient,
        address indexed admin,
        uint256 timestamp
    );
    
    event TransactionValidationComplete(
        bytes32 indexed transactionId,
        uint256 validCount,
        uint256 totalValidations,
        uint256 timestamp
    );
    
    event BridgeConfigUpdated(
        uint256 timestamp
    );
    
    event BridgeInitiated(
        bytes32 indexed transactionId,
        address indexed sender,
        address indexed recipient,
        uint256 sourceChain,
        uint256 targetChain,
        address token,
        uint256 amount,
        uint256 fee,
        uint256 timestamp
    );
    
    event TokenMappingAdded(
        uint256 indexed sourceChainId,
        uint256 indexed destinationChainId,
        address sourceToken,
        address destinationToken,
        uint256 conversionRate,
        uint256 timestamp
    );
    
    event TokenMappingUpdated(
        uint256 indexed sourceChainId,
        uint256 indexed destinationChainId,
        address sourceToken,
        address destinationToken,
        uint256 oldRate,
        uint256 newRate,
        uint256 timestamp
    );
    
    event ValidatorAdded(
        address indexed validator,
        uint256 stake,
        uint256 timestamp
    );
    
    event ValidatorRemoved(
        address indexed validator,
        uint256 returnedStake,
        string reason,
        uint256 timestamp
    );
    
    event TransferValidated(
        bytes32 indexed transferId,
        address indexed validator,
        bool isValid,
        uint256 timestamp
    );
    
    event LiquidityAdded(
        uint256 indexed chainId,
        address indexed token,
        address indexed provider,
        uint256 amount,
        uint256 shares,
        uint256 timestamp
    );
    
    event LiquidityRemoved(
        uint256 indexed chainId,
        address indexed token,
        address indexed provider,
        uint256 amount,
        uint256 shares,
        uint256 timestamp
    );
    
    event FeeUpdated(
        uint256 indexed sourceChainId,
        uint256 indexed destinationChainId,
        uint256 oldFee,
        uint256 newFee,
        uint256 timestamp
    );
    
    event EmergencyPause(
        uint256 indexed chainId,
        address indexed initiator,
        string reason,
        uint256 timestamp
    );
    
    event EmergencyUnpause(
        uint256 indexed chainId,
        address indexed initiator,
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
        uint256 actualAmount;
        TransferStatus status;
        uint256 initiatedAt;
        uint256 completedAt;
        uint256 validations;
        uint256 requiredValidations;
        bytes32 sourceTransactionHash;
        bytes32 destinationTransactionHash;
        TransferMetrics metrics;
        bytes additionalData;
    }
    
    struct TransferMetrics {
        uint256 processingTime;
        uint256 validationTime;
        uint256 executionTime;
        uint256 gasUsed;
        uint256 slippage;
        uint256 priceImpact;
        uint256 retryCount;
        uint256 lastRetry;
    }
    
    struct SupportedChain {
        uint256 chainId;
        string chainName;
        string rpcUrl;
        address bridgeContract;
        address tokenFactory;
        uint256 blockConfirmations;
        uint256 minTransferAmount;
        uint256 maxTransferAmount;
        uint256 dailyLimit;
        uint256 baseFee;
        uint256 feeRate; // Basis points
        bool isActive;
        bool isTestnet;
        ChainConfig config;
        ChainMetrics metrics;
    }
    
    struct ChainConfig {
        uint256 validationThreshold;
        uint256 timeoutPeriod;
        uint256 retryLimit;
        uint256 gasLimit;
        uint256 gasPrice;
        bool autoRetry;
        bool requiresKYC;
        address[] authorizedRelayers;
        uint256[] supportedTokenTypes;
    }
    
    struct ChainMetrics {
        uint256 totalTransfers;
        uint256 totalVolume;
        uint256 successRate;
        uint256 averageProcessingTime;
        uint256 totalFees;
        uint256 liquidityUtilization;
        uint256 lastTransfer;
        uint256 uptime;
        uint256 lastUpdate;
    }
    
    struct TokenMapping {
        uint256 sourceChainId;
        uint256 destinationChainId;
        address sourceToken;
        address destinationToken;
        uint256 conversionRate;
        uint256 decimalsAdjustment;
        bool isActive;
        bool isNative;
        MappingType mappingType;
        TokenConfig config;
        uint256 createdAt;
        uint256 lastUpdate;
    }
    
    struct TokenConfig {
        uint256 minTransferAmount;
        uint256 maxTransferAmount;
        uint256 dailyLimit;
        uint256 transferFee;
        bool requiresApproval;
        bool isMintable;
        bool isBurnable;
        address custodian;
        uint256 reserveRatio;
    }
    
    struct Validator {
        address validatorAddress;
        uint256 stake;
        uint256 validationCount;
        uint256 successfulValidations;
        uint256 reputation;
        bool isActive;
        bool isSlashed;
        uint256 joinedAt;
        uint256 lastValidation;
        ValidatorMetrics metrics;
        uint256[] supportedChains;
    }
    
    struct ValidatorMetrics {
        uint256 totalValidations;
        uint256 successRate;
        uint256 averageResponseTime;
        uint256 totalRewards;
        uint256 totalSlashes;
        uint256 uptime;
        uint256 lastReward;
        uint256 lastSlash;
    }
    
    struct LiquidityPool {
        uint256 chainId;
        address token;
        uint256 totalLiquidity;
        uint256 availableLiquidity;
        uint256 utilizedLiquidity;
        uint256 totalShares;
        uint256 rewardRate;
        uint256 feeRate;
        bool isActive;
        PoolConfig config;
        PoolMetrics metrics;
    }
    
    struct PoolConfig {
        uint256 minDeposit;
        uint256 maxDeposit;
        uint256 withdrawalFee;
        uint256 lockupPeriod;
        bool autoRebalance;
        uint256 rebalanceThreshold;
        uint256 maxUtilization;
        address[] authorizedRebalancers;
    }
    
    struct PoolMetrics {
        uint256 totalDeposits;
        uint256 totalWithdrawals;
        uint256 totalFees;
        uint256 totalRewards;
        uint256 averageAPY;
        uint256 utilizationRate;
        uint256 lastRebalance;
        uint256 providerCount;
    }
    
    struct LiquidityPosition {
        address provider;
        uint256 amount;
        uint256 shares;
        uint256 entryTime;
        uint256 lastReward;
        uint256 accruedRewards;
        uint256 lockupEnd;
        bool isActive;
    }
    
    struct BridgeRoute {
        bytes32 routeId;
        uint256 sourceChainId;
        uint256 destinationChainId;
        address[] intermediateChains;
        uint256 totalFee;
        uint256 estimatedTime;
        uint256 reliability;
        bool isActive;
        RouteMetrics metrics;
    }
    
    struct RouteMetrics {
        uint256 totalTransfers;
        uint256 successRate;
        uint256 averageTime;
        uint256 averageFee;
        uint256 lastUsed;
        uint256 totalVolume;
    }
    
    struct RelayerInfo {
        address relayer;
        uint256[] supportedChains;
        uint256 stake;
        uint256 reputation;
        bool isActive;
        RelayerConfig config;
        RelayerMetrics metrics;
    }
    
    struct RelayerConfig {
        uint256 maxTransferAmount;
        uint256 feeRate;
        uint256 responseTimeout;
        bool autoExecute;
        uint256[] priorityChains;
        address[] authorizedTokens;
    }
    
    struct RelayerMetrics {
        uint256 totalRelays;
        uint256 successfulRelays;
        uint256 averageResponseTime;
        uint256 totalFees;
        uint256 totalRewards;
        uint256 lastRelay;
        uint256 uptime;
    }
    
    struct SecurityConfig {
        uint256 maxDailyVolume;
        uint256 maxSingleTransfer;
        uint256 validationThreshold;
        uint256 timeoutPeriod;
        bool requiresMultiSig;
        uint256 multiSigThreshold;
        address[] guardians;
        bool emergencyMode;
    }
    
    struct BridgeTransaction {
        bytes32 transactionId;
        uint256 sourceChain;
        uint256 targetChain;
        address token;
        uint256 amount;
        address sender;
        address recipient;
        uint256 fee;
        uint256 timestamp;
        TransactionStatus status;
        bytes data;
        uint256 validatedAt;
        uint256 executedAt;
        address executor;
        address challenger;
        string challengeReason;
        bytes challengeEvidence;
        uint256 challengedAt;
        string resolution;
        uint256 resolvedAt;
        address resolver;
    }
    
    enum TransactionStatus {
        PENDING,
        VALIDATED,
        EXECUTED,
        FAILED,
        CHALLENGED
    }
    
    struct BridgeConfig {
        uint256 baseFee;
        uint256 validationThreshold;
        uint256 challengePeriod;
        uint256 maxTransactionAmount;
        uint256 minTransactionAmount;
        uint256 emergencyWithdrawDelay;
        uint256 relayerReward;
        uint256 validatorReward;
        bool isActive;
    }
    
    struct ValidatorInfo {
        address validator;
        bool isActive;
        uint256 stake;
        uint256 totalValidations;
        uint256 successfulValidations;
        uint256 reputation;
        uint256 nonce;
        uint256 lastValidation;
        uint256 joinedAt;
        uint256 totalExecutions;
        uint256 lastExecution;
    }
    
    struct BridgeValidationResult {
        bytes32 validationId;
        bytes32 transactionId;
        address validator;
        bool isValid;
        uint256 timestamp;
        bytes signature;
    }
    
    struct FeeStructure {
        uint256 baseFee;
        uint256 percentageFee;
        uint256 minFee;
        uint256 maxFee;
        bool isDynamic;
        uint256 lastUpdate;
    }
    
    enum BridgeType {
        LOCK_MINT,
        BURN_MINT,
        LIQUIDITY_POOL
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
    
    struct SystemMetrics {
        uint256 totalChains;
        uint256 totalTokens;
        uint256 totalValidators;
        uint256 totalTransactions;
        uint256 totalVolume;
        uint256 pendingTransactions;
        uint256 systemHealth;
        uint256 lastUpdate;
    }

    // Enums
    enum TransferStatus {
        INITIATED,
        VALIDATING,
        VALIDATED,
        EXECUTING,
        COMPLETED,
        FAILED,
        CANCELLED,
        EXPIRED
    }
    
    enum FailureReason {
        INSUFFICIENT_LIQUIDITY,
        VALIDATION_FAILED,
        EXECUTION_FAILED,
        TIMEOUT,
        INVALID_RECIPIENT,
        UNSUPPORTED_TOKEN,
        AMOUNT_TOO_LOW,
        AMOUNT_TOO_HIGH,
        DAILY_LIMIT_EXCEEDED,
        CHAIN_NOT_SUPPORTED
    }
    
    enum MappingType {
        NATIVE_TO_WRAPPED,
        WRAPPED_TO_NATIVE,
        WRAPPED_TO_WRAPPED,
        SYNTHETIC,
        PEGGED
    }
    
    enum ValidationResult {
        PENDING,
        APPROVED,
        REJECTED,
        EXPIRED
    }

    // Core bridge functions
    function initiateBridgeTransfer(
        uint256 destinationChainId,
        address destinationToken,
        address recipient,
        uint256 amount,
        bytes calldata additionalData
    ) external payable returns (bytes32 transferId);
    
    function completeBridgeTransfer(
        bytes32 transferId,
        bytes calldata proof
    ) external returns (bool success);
    
    function validateTransfer(
        bytes32 transferId,
        bool isValid
    ) external;
    
    function retryTransfer(
        bytes32 transferId
    ) external returns (bool success);
    
    function cancelTransfer(
        bytes32 transferId
    ) external;
    
    // Chain management functions
    function addSupportedChain(
        uint256 chainId,
        string calldata chainName,
        string calldata rpcUrl,
        address bridgeContract,
        ChainConfig calldata config
    ) external;
    
    function removeSupportedChain(
        uint256 chainId,
        string calldata reason
    ) external;
    
    function updateChainConfig(
        uint256 chainId,
        ChainConfig calldata config
    ) external;
    
    function pauseChain(
        uint256 chainId,
        string calldata reason
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
        uint256 conversionRate,
        MappingType mappingType,
        TokenConfig calldata config
    ) external;
    
    function updateTokenMapping(
        uint256 sourceChainId,
        uint256 destinationChainId,
        address sourceToken,
        address destinationToken,
        uint256 newConversionRate
    ) external;
    
    function removeTokenMapping(
        uint256 sourceChainId,
        uint256 destinationChainId,
        address sourceToken,
        address destinationToken
    ) external;
    
    // Validator functions
    function addValidator(
        address validator,
        uint256[] calldata supportedChains
    ) external;
    
    function removeValidator(
        address validator,
        string calldata reason
    ) external;
    
    function stakeAsValidator(
        uint256 amount,
        uint256[] calldata supportedChains
    ) external;
    
    function unstakeValidator(
        uint256 amount
    ) external;
    
    function slashValidator(
        address validator,
        uint256 amount,
        string calldata reason
    ) external;
    
    // Liquidity functions
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
    
    // Relayer functions
    function registerRelayer(
        uint256[] calldata supportedChains,
        RelayerConfig calldata config
    ) external;
    
    function updateRelayerConfig(
        RelayerConfig calldata config
    ) external;
    
    function executeRelay(
        bytes32 transferId,
        bytes calldata proof
    ) external;
    
    function claimRelayerRewards() external returns (uint256 rewards);
    
    // Fee management functions
    function updateBridgeFee(
        uint256 sourceChainId,
        uint256 destinationChainId,
        uint256 newFee
    ) external;
    
    function updateTokenFee(
        uint256 chainId,
        address token,
        uint256 newFee
    ) external;
    
    function calculateBridgeFee(
        uint256 sourceChainId,
        uint256 destinationChainId,
        address token,
        uint256 amount
    ) external view returns (uint256 fee);
    
    function withdrawFees(
        uint256 chainId,
        address token,
        uint256 amount
    ) external;
    
    // Route optimization functions
    function findOptimalRoute(
        uint256 sourceChainId,
        uint256 destinationChainId,
        address token,
        uint256 amount
    ) external view returns (BridgeRoute memory route);
    
    function addBridgeRoute(
        uint256 sourceChainId,
        uint256 destinationChainId,
        address[] calldata intermediateChains
    ) external returns (bytes32 routeId);
    
    function updateRouteMetrics(
        bytes32 routeId,
        uint256 transferTime,
        bool success
    ) external;
    
    // Security functions
    function updateSecurityConfig(
        SecurityConfig calldata config
    ) external;
    
    function emergencyPause(
        uint256 chainId,
        string calldata reason
    ) external;
    
    function emergencyUnpause(
        uint256 chainId
    ) external;
    
    function emergencyWithdraw(
        uint256 chainId,
        address token,
        uint256 amount
    ) external;
    
    function blacklistAddress(
        address account,
        string calldata reason
    ) external;
    
    function whitelistAddress(
        address account
    ) external;
    
    // View functions - Transfers
    function getTransfer(
        bytes32 transferId
    ) external view returns (BridgeTransfer memory);
    
    function getTransferStatus(
        bytes32 transferId
    ) external view returns (TransferStatus);
    
    function getUserTransfers(
        address user,
        uint256 limit
    ) external view returns (bytes32[] memory);
    
    function getPendingTransfers(
        uint256 chainId
    ) external view returns (bytes32[] memory);
    
    function getTransferHistory(
        uint256 chainId,
        uint256 limit
    ) external view returns (bytes32[] memory);
    
    function estimateTransferTime(
        uint256 sourceChainId,
        uint256 destinationChainId,
        address token,
        uint256 amount
    ) external view returns (uint256 estimatedTime);
    
    // View functions - Chains
    function getSupportedChain(
        uint256 chainId
    ) external view returns (SupportedChain memory);
    
    function getAllSupportedChains() external view returns (uint256[] memory);
    
    function getActiveSupportedChains() external view returns (uint256[] memory);
    
    function isChainSupported(
        uint256 chainId
    ) external view returns (bool);
    
    function getChainMetrics(
        uint256 chainId
    ) external view returns (ChainMetrics memory);
    
    function getChainLimits(
        uint256 chainId
    ) external view returns (uint256 minAmount, uint256 maxAmount, uint256 dailyLimit);
    
    // View functions - Token mappings
    function getTokenMapping(
        uint256 sourceChainId,
        uint256 destinationChainId,
        address sourceToken
    ) external view returns (TokenMapping memory);
    
    function getAllTokenMappings(
        uint256 sourceChainId,
        uint256 destinationChainId
    ) external view returns (TokenMapping[] memory);
    
    function isTokenSupported(
        uint256 chainId,
        address token
    ) external view returns (bool);
    
    function getConversionRate(
        uint256 sourceChainId,
        uint256 destinationChainId,
        address sourceToken,
        address destinationToken
    ) external view returns (uint256 rate);
    
    // View functions - Validators
    function getValidator(
        address validator
    ) external view returns (Validator memory);
    
    function getAllValidators() external view returns (address[] memory);
    
    function getActiveValidators() external view returns (address[] memory);
    
    function getValidatorsByChain(
        uint256 chainId
    ) external view returns (address[] memory);
    
    function isValidator(
        address account
    ) external view returns (bool);
    
    function getValidatorStake(
        address validator
    ) external view returns (uint256);
    
    function getValidatorReputation(
        address validator
    ) external view returns (uint256);
    
    // View functions - Liquidity
    function getLiquidityPool(
        uint256 chainId,
        address token
    ) external view returns (LiquidityPool memory);
    
    function getLiquidityPosition(
        uint256 chainId,
        address token,
        address provider
    ) external view returns (LiquidityPosition memory);
    
    function getAvailableLiquidity(
        uint256 chainId,
        address token
    ) external view returns (uint256);
    
    function getTotalLiquidity(
        uint256 chainId,
        address token
    ) external view returns (uint256);
    
    function getLiquidityUtilization(
        uint256 chainId,
        address token
    ) external view returns (uint256);
    
    function getUserLiquidityPositions(
        address user
    ) external view returns (LiquidityPosition[] memory);
    
    // View functions - Routes
    function getBridgeRoute(
        bytes32 routeId
    ) external view returns (BridgeRoute memory);
    
    function getAllRoutes(
        uint256 sourceChainId,
        uint256 destinationChainId
    ) external view returns (bytes32[] memory);
    
    function getRouteMetrics(
        bytes32 routeId
    ) external view returns (RouteMetrics memory);
    
    // View functions - Relayers
    function getRelayer(
        address relayer
    ) external view returns (RelayerInfo memory);
    
    function getAllRelayers() external view returns (address[] memory);
    
    function getActiveRelayers() external view returns (address[] memory);
    
    function getRelayersByChain(
        uint256 chainId
    ) external view returns (address[] memory);
    
    function isRelayer(
        address account
    ) external view returns (bool);
    
    // View functions - Analytics
    function getTotalVolume(
        uint256 timeframe
    ) external view returns (uint256);
    
    function getChainVolume(
        uint256 chainId,
        uint256 timeframe
    ) external view returns (uint256);
    
    function getTokenVolume(
        address token,
        uint256 timeframe
    ) external view returns (uint256);
    
    function getSuccessRate(
        uint256 chainId,
        uint256 timeframe
    ) external view returns (uint256);
    
    function getAverageTransferTime(
        uint256 sourceChainId,
        uint256 destinationChainId
    ) external view returns (uint256);
    
    function getTotalFees(
        uint256 timeframe
    ) external view returns (uint256);
    
    function getSystemHealth() external view returns (
        bool isHealthy,
        uint256 activeChainsCount,
        uint256 totalLiquidity,
        uint256 averageSuccessRate
    );
}
