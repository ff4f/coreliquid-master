// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IDecentralizedOracle
 * @dev Interface for the Decentralized Oracle contract
 * @author CoreLiquid Protocol
 */
interface IDecentralizedOracle {
    // Events
    event PriceUpdated(
        bytes32 indexed priceId,
        address indexed token,
        uint256 price,
        uint256 confidence,
        uint256 timestamp,
        address updater
    );
    
    event PriceFeedAdded(
        bytes32 indexed feedId,
        address indexed token,
        string source,
        uint256 heartbeat,
        uint256 deviation,
        uint256 timestamp
    );
    
    event OracleNodeAdded(
        address indexed node,
        string endpoint,
        uint256 stake,
        uint256 reputation,
        uint256 timestamp
    );
    
    event OracleNodeRemoved(
        address indexed node,
        string reason,
        uint256 timestamp
    );
    
    event DataSubmitted(
        bytes32 indexed requestId,
        address indexed node,
        bytes32 dataHash,
        uint256 timestamp
    );
    
    event DataAggregated(
        bytes32 indexed requestId,
        bytes result,
        uint256 confidence,
        uint256 timestamp
    );
    
    event SlashingExecuted(
        address indexed node,
        uint256 amount,
        string reason,
        uint256 timestamp
    );
    
    event RewardDistributed(
        address indexed node,
        uint256 amount,
        bytes32 indexed requestId,
        uint256 timestamp
    );
    
    event EmergencyPriceSet(
        address indexed token,
        uint256 price,
        address setter,
        string reason,
        uint256 timestamp
    );
    
    event AggregationMethodUpdated(
        bytes32 indexed feedId,
        AggregationMethod oldMethod,
        AggregationMethod newMethod,
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

    // Structs
    struct PriceFeed {
        bytes32 feedId;
        address token;
        string symbol;
        string source;
        uint256 price;
        uint256 previousPrice;
        uint256 confidence;
        uint256 lastUpdate;
        uint256 heartbeat;
        uint256 deviation;
        AggregationMethod aggregationMethod;
        bool isActive;
        bool isEmergency;
        uint256 emergencyPrice;
        uint256 emergencyTimestamp;
        address[] authorizedUpdaters;
        uint256 minNodes;
        uint256 maxNodes;
        uint256 createdAt;
    }
    
    struct OracleNode {
        address nodeAddress;
        string endpoint;
        uint256 stake;
        uint256 reputation;
        uint256 totalSubmissions;
        uint256 successfulSubmissions;
        uint256 totalRewards;
        uint256 totalSlashed;
        bool isActive;
        bool isSlashed;
        uint256 lastSubmission;
        uint256 joinedAt;
        bytes32[] assignedFeeds;
        mapping(bytes32 => uint256) feedSubmissions;
        mapping(bytes32 => uint256) feedAccuracy;
    }
    
    struct DataRequest {
        bytes32 requestId;
        bytes32 feedId;
        address requester;
        bytes parameters;
        uint256 reward;
        uint256 deadline;
        uint256 minNodes;
        RequestStatus status;
        uint256 submissionsCount;
        uint256 createdAt;
        uint256 completedAt;
        bytes result;
        uint256 confidence;
        mapping(address => DataSubmission) submissions;
        address[] submitters;
    }
    
    struct DataSubmission {
        address node;
        bytes data;
        bytes32 dataHash;
        uint256 timestamp;
        bool isValid;
        uint256 weight;
        string source;
    }
    
    struct PriceData {
        uint256 price;
        uint256 confidence;
        uint256 timestamp;
        uint256 roundId;
        address[] contributors;
        uint256[] weights;
        bool isValid;
        uint256 deviation;
    }
    
    struct AggregationConfig {
        AggregationMethod method;
        uint256 minSubmissions;
        uint256 maxSubmissions;
        uint256 deviationThreshold;
        uint256 confidenceThreshold;
        uint256 timeWindow;
        bool enableOutlierDetection;
        uint256 outlierThreshold;
        bool enableWeighting;
        uint256 reputationWeight;
    }
    
    struct OracleMetrics {
        uint256 totalFeeds;
        uint256 activeFeeds;
        uint256 totalNodes;
        uint256 activeNodes;
        uint256 totalRequests;
        uint256 completedRequests;
        uint256 averageResponseTime;
        uint256 averageConfidence;
        uint256 totalRewards;
        uint256 totalSlashed;
        uint256 lastUpdate;
    }
    
    struct NodePerformance {
        address node;
        uint256 accuracy;
        uint256 responseTime;
        uint256 uptime;
        uint256 reputation;
        uint256 totalSubmissions;
        uint256 successfulSubmissions;
        uint256 rewardsEarned;
        uint256 slashingEvents;
        uint256 lastActivity;
    }
    
    struct PriceHistory {
        uint256[] prices;
        uint256[] timestamps;
        uint256[] confidences;
        uint256 startIndex;
        uint256 endIndex;
        uint256 maxEntries;
    }

    // Enums
    enum AggregationMethod {
        MEDIAN,
        MEAN,
        WEIGHTED_AVERAGE,
        TRIMMED_MEAN,
        MODE,
        CUSTOM
    }
    
    enum RequestStatus {
        PENDING,
        ACTIVE,
        COMPLETED,
        EXPIRED,
        CANCELLED
    }
    
    enum NodeStatus {
        ACTIVE,
        INACTIVE,
        SLASHED,
        SUSPENDED
    }

    // Core oracle functions
    function getPrice(
        address token
    ) external view returns (uint256 price, uint256 confidence, uint256 timestamp);
    
    function getLatestPrice(
        bytes32 feedId
    ) external view returns (uint256 price, uint256 confidence, uint256 timestamp);
    
    function updatePrice(
        bytes32 feedId,
        uint256 price,
        uint256 confidence
    ) external;
    
    function requestData(
        bytes32 feedId,
        bytes calldata parameters,
        uint256 reward,
        uint256 deadline
    ) external payable returns (bytes32 requestId);
    
    function submitData(
        bytes32 requestId,
        bytes calldata data,
        string calldata source
    ) external;
    
    function aggregateData(
        bytes32 requestId
    ) external returns (bytes memory result, uint256 confidence);
    
    // Price feed management
    function addPriceFeed(
        address token,
        string calldata symbol,
        string calldata source,
        uint256 heartbeat,
        uint256 deviation,
        AggregationMethod method
    ) external returns (bytes32 feedId);
    
    function updatePriceFeed(
        bytes32 feedId,
        uint256 heartbeat,
        uint256 deviation,
        AggregationMethod method
    ) external;
    
    function pausePriceFeed(
        bytes32 feedId
    ) external;
    
    function unpausePriceFeed(
        bytes32 feedId
    ) external;
    
    function removePriceFeed(
        bytes32 feedId
    ) external;
    
    // Oracle node management
    function addOracleNode(
        address node,
        string calldata endpoint,
        uint256 stake
    ) external;
    
    function removeOracleNode(
        address node,
        string calldata reason
    ) external;
    
    function updateNodeStake(
        address node,
        uint256 newStake
    ) external;
    
    function slashNode(
        address node,
        uint256 amount,
        string calldata reason
    ) external;
    
    function suspendNode(
        address node,
        uint256 duration
    ) external;
    
    function reactivateNode(
        address node
    ) external;
    
    // Advanced oracle functions
    function batchUpdatePrices(
        bytes32[] calldata feedIds,
        uint256[] calldata prices,
        uint256[] calldata confidences
    ) external;
    
    function getHistoricalPrice(
        bytes32 feedId,
        uint256 timestamp
    ) external view returns (uint256 price, uint256 confidence);
    
    function getPriceAtRound(
        bytes32 feedId,
        uint256 roundId
    ) external view returns (uint256 price, uint256 confidence, uint256 timestamp);
    
    function getTWAP(
        bytes32 feedId,
        uint256 timeWindow
    ) external view returns (uint256 twap);
    
    function getVWAP(
        bytes32 feedId,
        uint256 timeWindow
    ) external view returns (uint256 vwap);
    
    // Aggregation functions
    function setAggregationConfig(
        bytes32 feedId,
        AggregationConfig calldata config
    ) external;
    
    function customAggregation(
        bytes32 feedId,
        bytes calldata aggregationLogic
    ) external returns (uint256 result, uint256 confidence);
    
    function validateSubmission(
        bytes32 requestId,
        address node,
        bytes calldata data
    ) external view returns (bool isValid, string memory reason);
    
    function calculateConfidence(
        bytes32 requestId
    ) external view returns (uint256 confidence);
    
    // Emergency functions
    function setEmergencyPrice(
        address token,
        uint256 price,
        string calldata reason
    ) external;
    
    function clearEmergencyPrice(
        address token
    ) external;
    
    function emergencyPause() external;
    
    function emergencyUnpause() external;
    
    function emergencyWithdraw(
        address token,
        uint256 amount
    ) external;
    
    // Validator functions
    function addValidator(
        address validator
    ) external;
    
    function removeValidator(
        address validator
    ) external;
    
    function validatePriceUpdate(
        bytes32 feedId,
        uint256 price,
        uint256 confidence
    ) external view returns (bool isValid, string memory reason);
    
    function validateDataSubmission(
        bytes32 requestId,
        bytes calldata data
    ) external view returns (bool isValid, string memory reason);
    
    // Reward and slashing functions
    function distributeRewards(
        bytes32 requestId
    ) external;
    
    function claimRewards(
        address node
    ) external returns (uint256 amount);
    
    function calculateReward(
        address node,
        bytes32 requestId
    ) external view returns (uint256 reward);
    
    function updateReputationScore(
        address node
    ) external;
    
    function penalizeNode(
        address node,
        uint256 penalty,
        string calldata reason
    ) external;
    
    // Configuration functions
    function setMinimumStake(
        uint256 minimumStake
    ) external;
    
    function setReputationThreshold(
        uint256 threshold
    ) external;
    
    function setSlashingParameters(
        uint256 slashingRate,
        uint256 maxSlashing
    ) external;
    
    function setRewardParameters(
        uint256 baseReward,
        uint256 bonusMultiplier
    ) external;
    
    function updateAggregationMethod(
        bytes32 feedId,
        AggregationMethod method
    ) external;
    
    // View functions - Price information
    function getPriceFeed(
        bytes32 feedId
    ) external view returns (PriceFeed memory);
    
    function getAllPriceFeeds() external view returns (bytes32[] memory);
    
    function getActivePriceFeeds() external view returns (bytes32[] memory);
    
    function getFeedByToken(
        address token
    ) external view returns (bytes32 feedId);
    
    function isPriceFeedActive(
        bytes32 feedId
    ) external view returns (bool);
    
    function getPriceAge(
        bytes32 feedId
    ) external view returns (uint256 age);
    
    function isPriceStale(
        bytes32 feedId
    ) external view returns (bool);
    
    function getPriceDeviation(
        bytes32 feedId
    ) external view returns (uint256 deviation);
    
    // View functions - Oracle node information
    function getOracleNode(
        address node
    ) external view returns (
        string memory endpoint,
        uint256 stake,
        uint256 reputation,
        bool isActive,
        uint256 totalSubmissions
    );
    
    function getAllOracleNodes() external view returns (address[] memory);
    
    function getActiveOracleNodes() external view returns (address[] memory);
    
    function getNodesByFeed(
        bytes32 feedId
    ) external view returns (address[] memory);
    
    function isOracleNode(
        address node
    ) external view returns (bool);
    
    function getNodeStake(
        address node
    ) external view returns (uint256 stake);
    
    function getNodeReputation(
        address node
    ) external view returns (uint256 reputation);
    
    function getNodePerformance(
        address node
    ) external view returns (NodePerformance memory);
    
    // View functions - Data request information
    function getDataRequest(
        bytes32 requestId
    ) external view returns (
        bytes32 feedId,
        address requester,
        uint256 reward,
        uint256 deadline,
        RequestStatus status
    );
    
    function getRequestSubmissions(
        bytes32 requestId
    ) external view returns (address[] memory submitters);
    
    function getSubmission(
        bytes32 requestId,
        address node
    ) external view returns (DataSubmission memory);
    
    function isRequestCompleted(
        bytes32 requestId
    ) external view returns (bool);
    
    function getRequestResult(
        bytes32 requestId
    ) external view returns (bytes memory result, uint256 confidence);
    
    // View functions - Historical data
    function getPriceHistory(
        bytes32 feedId,
        uint256 fromTimestamp,
        uint256 toTimestamp
    ) external view returns (PriceHistory memory);
    
    function getLatestRound(
        bytes32 feedId
    ) external view returns (uint256 roundId);
    
    function getRoundData(
        bytes32 feedId,
        uint256 roundId
    ) external view returns (PriceData memory);
    
    function getPriceRange(
        bytes32 feedId,
        uint256 timeWindow
    ) external view returns (uint256 minPrice, uint256 maxPrice);
    
    function getPriceVolatility(
        bytes32 feedId,
        uint256 timeWindow
    ) external view returns (uint256 volatility);
    
    // View functions - Aggregation information
    function getAggregationConfig(
        bytes32 feedId
    ) external view returns (AggregationConfig memory);
    
    function getAggregationMethod(
        bytes32 feedId
    ) external view returns (AggregationMethod);
    
    function getMinSubmissions(
        bytes32 feedId
    ) external view returns (uint256 minSubmissions);
    
    function getConfidenceThreshold(
        bytes32 feedId
    ) external view returns (uint256 threshold);
    
    // View functions - Metrics and analytics
    function getOracleMetrics() external view returns (OracleMetrics memory);
    
    function getFeedMetrics(
        bytes32 feedId
    ) external view returns (
        uint256 totalUpdates,
        uint256 averageConfidence,
        uint256 averageDeviation,
        uint256 uptime
    );
    
    function getNodeMetrics(
        address node
    ) external view returns (
        uint256 accuracy,
        uint256 responseTime,
        uint256 uptime,
        uint256 rewardsEarned
    );
    
    function getSystemAccuracy() external view returns (uint256 accuracy);
    
    function getAverageResponseTime() external view returns (uint256 responseTime);
    
    function getTotalRewardsDistributed() external view returns (uint256 totalRewards);
    
    function getTotalSlashed() external view returns (uint256 totalSlashed);
    
    // View functions - Validation and health
    function isSystemHealthy() external view returns (bool);
    
    function getSystemHealth() external view returns (
        bool isHealthy,
        uint256 nodeHealth,
        uint256 dataHealth,
        uint256 priceHealth
    );
    
    function getFeedHealth(
        bytes32 feedId
    ) external view returns (
        bool isHealthy,
        uint256 freshnessHealth,
        uint256 accuracyHealth,
        uint256 consensusHealth
    );
    
    function getNodeHealth(
        address node
    ) external view returns (
        bool isHealthy,
        uint256 performanceHealth,
        uint256 reputationHealth,
        uint256 stakeHealth
    );
    
    function canSubmitData(
        address node,
        bytes32 requestId
    ) external view returns (bool);
    
    function isValidPrice(
        bytes32 feedId,
        uint256 price
    ) external view returns (bool);
    
    function getMinimumNodes(
        bytes32 feedId
    ) external view returns (uint256 minNodes);
    
    function hasEnoughSubmissions(
        bytes32 requestId
    ) external view returns (bool);
    
    // View functions - Emergency and configuration
    function isEmergencyMode() external view returns (bool);
    
    function getEmergencyPrice(
        address token
    ) external view returns (uint256 price, uint256 timestamp);
    
    function getMinimumStake() external view returns (uint256 minimumStake);
    
    function getReputationThreshold() external view returns (uint256 threshold);
    
    function getSlashingParameters() external view returns (
        uint256 slashingRate,
        uint256 maxSlashing
    );
    
    function getRewardParameters() external view returns (
        uint256 baseReward,
        uint256 bonusMultiplier
    );
    
    function getValidators() external view returns (address[] memory);
    
    function isValidator(
        address account
    ) external view returns (bool);
}
