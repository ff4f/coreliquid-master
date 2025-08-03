// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IOracle
 * @dev Interface for the Oracle contract
 * @author CoreLiquid Protocol
 */
interface IOracle {
    // Events
    event PriceUpdated(
        address indexed asset,
        uint256 oldPrice,
        uint256 newPrice,
        uint256 timestamp,
        address indexed oracle
    );
    
    event OracleAdded(
        address indexed oracle,
        OracleType oracleType,
        address indexed asset,
        uint256 weight,
        uint256 timestamp
    );
    
    event OracleRemoved(
        address indexed oracle,
        address indexed asset,
        string reason,
        uint256 timestamp
    );
    
    event OracleWeightUpdated(
        address indexed oracle,
        address indexed asset,
        uint256 oldWeight,
        uint256 newWeight,
        uint256 timestamp
    );
    
    event PriceFeedCreated(
        bytes32 indexed feedId,
        address indexed asset,
        string symbol,
        uint8 decimals,
        FeedConfig config,
        uint256 timestamp
    );
    
    event PriceFeedUpdated(
        bytes32 indexed feedId,
        uint256 price,
        uint256 confidence,
        uint256 timestamp,
        address indexed updater
    );
    
    event PriceFeedPaused(
        bytes32 indexed feedId,
        string reason,
        uint256 timestamp
    );
    
    event PriceFeedUnpaused(
        bytes32 indexed feedId,
        uint256 timestamp
    );
    
    event AggregationMethodUpdated(
        address indexed asset,
        AggregationMethod oldMethod,
        AggregationMethod newMethod,
        uint256 timestamp
    );
    
    event DeviationThresholdUpdated(
        address indexed asset,
        uint256 oldThreshold,
        uint256 newThreshold,
        uint256 timestamp
    );
    
    event HeartbeatUpdated(
        address indexed asset,
        uint256 oldHeartbeat,
        uint256 newHeartbeat,
        uint256 timestamp
    );
    
    event PriceValidationFailed(
        address indexed asset,
        uint256 proposedPrice,
        uint256 currentPrice,
        string reason,
        uint256 timestamp
    );
    
    event OracleFailover(
        address indexed failedOracle,
        address indexed backupOracle,
        address indexed asset,
        string reason,
        uint256 timestamp
    );
    
    event CircuitBreakerTriggered(
        address indexed asset,
        uint256 price,
        uint256 threshold,
        uint256 timestamp
    );
    
    event EmergencyPriceSet(
        address indexed asset,
        uint256 emergencyPrice,
        address indexed setter,
        string reason,
        uint256 timestamp
    );
    
    event TwapUpdated(
        address indexed asset,
        uint256 twapPrice,
        uint256 period,
        uint256 timestamp
    );
    
    event VolatilityUpdated(
        address indexed asset,
        uint256 volatility,
        uint256 period,
        uint256 timestamp
    );

    event PriceSourceAdded(
        address indexed asset,
        address indexed source,
        uint256 weight,
        SourceType sourceType,
        uint256 timestamp
    );

    event PriceSourceRemoved(
        address indexed asset,
        address indexed source,
        uint256 timestamp
    );

    event AggregationConfigUpdated(
        address indexed asset,
        uint256 timestamp
    );

    event PriceAggregated(
        address indexed asset,
        uint256 aggregatedPrice,
        uint256 sourceCount,
        uint256 timestamp
    );

    event ValidationRuleAdded(
        address indexed asset,
        ValidationType ruleType,
        uint256 timestamp
    );

    event ValidationRuleRemoved(
        address indexed asset,
        uint256 ruleIndex,
        uint256 timestamp
    );

    event EmergencyPriceCleared(
        address indexed asset,
        uint256 timestamp
    );

    event EmergencyModeEnabled(
        uint256 timestamp
    );

    event EmergencyModeDisabled(
        uint256 timestamp
    );

    event OracleConfigUpdated(
        uint256 timestamp
    );

    event AssetAdded(
        address indexed asset,
        uint256 timestamp
    );

    event AssetRemoved(
        address indexed asset,
        uint256 timestamp
    );

    event PriceValidated(
        address indexed asset,
        uint256 price,
        bool isValid,
        address indexed validator,
        uint256 timestamp
    );

    event BatchPriceUpdated(
        address[] assets,
        uint256[] prices,
        uint256 timestamp
    );

    // Structs
    struct PriceData {
        uint256 price;
        uint256 timestamp;
        uint256 confidence;
        uint256 roundId;
        address oracle;
        bool isValid;
        PriceMetadata metadata;
    }
    
    struct PriceMetadata {
        uint256 volume;
        uint256 liquidity;
        uint256 spread;
        uint256 volatility;
        string source;
        bytes32 dataHash;
        uint256 blockNumber;
        bool isStale;
    }
    
    struct PriceFeed {
        bytes32 feedId;
        address asset;
        string symbol;
        uint8 decimals;
        FeedConfig config;
        FeedStatus status;
        FeedMetrics metrics;
        PriceHistory history;
        address[] oracles;
    }
    
    struct FeedConfig {
        uint256 heartbeat;
        uint256 deviationThreshold;
        uint256 minConfidence;
        uint256 maxStaleness;
        AggregationMethod aggregationMethod;
        bool enableCircuitBreaker;
        uint256 circuitBreakerThreshold;
        uint256 minOracles;
        uint256 maxPriceAge;
        bool requiresValidation;
    }
    
    struct FeedStatus {
        bool isActive;
        bool isPaused;
        bool isEmergency;
        uint256 lastUpdate;
        uint256 updateCount;
        uint256 failureCount;
        uint256 lastFailure;
        string statusMessage;
    }
    
    struct FeedMetrics {
        uint256 totalUpdates;
        uint256 averageDeviation;
        uint256 maxDeviation;
        uint256 averageConfidence;
        uint256 uptime;
        uint256 responseTime;
        uint256 accuracy;
        uint256 reliability;
    }
    
    struct PriceHistory {
        uint256[] prices;
        uint256[] timestamps;
        uint256[] confidences;
        uint256 currentIndex;
        uint256 maxHistory;
        bool isFull;
    }
    
    struct OracleInfo {
        address oracle;
        OracleType oracleType;
        uint256 weight;
        bool isActive;
        OracleConfig config;
        OracleMetrics metrics;
        OracleStatus status;
    }
    
    struct OracleConfig {
        uint256 updateFrequency;
        uint256 timeout;
        uint256 maxDeviation;
        uint256 minConfidence;
        bool requiresSignature;
        address[] authorizedUpdaters;
        string endpoint;
        bytes32 apiKey;
    }
    
    struct OracleMetrics {
        uint256 totalUpdates;
        uint256 successfulUpdates;
        uint256 failedUpdates;
        uint256 averageResponseTime;
        uint256 lastUpdate;
        uint256 uptime;
        uint256 accuracy;
        uint256 deviation;
    }
    
    struct OracleStatus {
        bool isOnline;
        bool isHealthy;
        uint256 lastHeartbeat;
        uint256 consecutiveFailures;
        string lastError;
        uint256 lastErrorTime;
    }
    
    struct AggregatedPrice {
        uint256 price;
        uint256 confidence;
        uint256 timestamp;
        uint256 oracleCount;
        uint256 totalWeight;
        AggregationMethod method;
        AggregationMetrics metrics;
    }
    
    struct AggregationMetrics {
        uint256 median;
        uint256 mean;
        uint256 standardDeviation;
        uint256 variance;
        uint256 minPrice;
        uint256 maxPrice;
        uint256 priceRange;
        uint256 weightedAverage;
    }
    
    struct TWAP {
        address asset;
        uint256 price;
        uint256 period;
        uint256 startTime;
        uint256 endTime;
        uint256 observations;
        uint256 totalVolume;
        TWAPConfig config;
    }
    
    struct TWAPConfig {
        uint256 windowSize;
        uint256 updateInterval;
        uint256 minObservations;
        bool volumeWeighted;
        bool outlierFiltering;
        uint256 outlierThreshold;
    }
    
    struct VolatilityData {
        address asset;
        uint256 volatility;
        uint256 period;
        uint256 timestamp;
        VolatilityMetrics metrics;
        VolatilityConfig config;
    }
    
    struct VolatilityMetrics {
        uint256 historicalVolatility;
        uint256 impliedVolatility;
        uint256 realizedVolatility;
        uint256 averageVolatility;
        uint256 volatilityTrend;
        uint256 volatilityRank;
    }
    
    struct VolatilityConfig {
        uint256 lookbackPeriod;
        uint256 updateFrequency;
        VolatilityModel model;
        bool useGarch;
        uint256 smoothingFactor;
    }
    
    struct CircuitBreaker {
        address asset;
        bool isTriggered;
        uint256 triggerPrice;
        uint256 threshold;
        uint256 triggerTime;
        uint256 cooldownPeriod;
        uint256 resetTime;
        CircuitBreakerConfig config;
    }
    
    struct CircuitBreakerConfig {
        uint256 priceChangeThreshold;
        uint256 volumeThreshold;
        uint256 timeWindow;
        uint256 cooldownDuration;
        bool autoReset;
        address[] authorizedResetters;
    }
    
    struct EmergencyPrice {
        address asset;
        uint256 price;
        uint256 setTime;
        uint256 expiryTime;
        address setter;
        string reason;
        bool isActive;
        EmergencyPriceConfig config;
    }
    
    struct EmergencyPriceConfig {
        uint256 maxDuration;
        uint256 priceValidityPeriod;
        address[] authorizedSetters;
        bool requiresMultiSig;
        uint256 requiredSignatures;
    }
    
    struct OracleRegistry {
        mapping(address => bool) isRegistered;
        mapping(address => OracleType) oracleTypes;
        mapping(address => address[]) assetOracles;
        mapping(address => mapping(address => bool)) isOracleForAsset;
        address[] allOracles;
        uint256 totalOracles;
    }
    
    struct PriceValidation {
        bool isValid;
        string[] validationErrors;
        uint256 confidence;
        ValidationMetrics metrics;
        ValidationConfig config;
    }
    
    struct ValidationMetrics {
        uint256 deviationFromMedian;
        uint256 deviationFromMean;
        uint256 zScore;
        uint256 confidenceInterval;
        bool isOutlier;
        uint256 validationScore;
    }
    
    struct ValidationConfig {
        uint256 maxDeviation;
        uint256 minConfidence;
        uint256 outlierThreshold;
        bool enableStatisticalValidation;
        bool enableCrossValidation;
        uint256 validationWindow;
    }
    
    struct PriceSource {
        address source;
        uint256 weight;
        SourceType sourceType;
        bool isActive;
        uint256 lastUpdate;
        uint256 reliability;
    }
    
    struct AggregationConfig {
        AggregationMethod method;
        uint256 minSources;
        uint256 maxDeviation;
        bool isActive;
    }
    
    struct ValidationRule {
        ValidationType ruleType;
        uint256 threshold;
        bool isActive;
    }

    struct PriceUpdate {
        bytes32 updateId;
        address asset;
        uint256 price;
        uint256 timestamp;
        address source;
        uint256 confidence;
        bytes data;
    }

    struct SystemMetrics {
        uint256 totalAssets;
        uint256 totalSources;
        uint256 totalUpdates;
        uint256 totalValidations;
        uint256 emergencyOverrides;
        uint256 lastGlobalUpdate;
        uint256 systemHealth;
        uint256 averageConfidence;
    }

    // Enums
    enum ValidationType {
        MIN_PRICE,
        MAX_PRICE,
        MAX_DEVIATION
    }
    enum OracleType {
        CHAINLINK,
        UNISWAP_V3,
        PYTH,
        BAND,
        CUSTOM,
        INTERNAL,
        EXTERNAL_API,
        CONSENSUS
    }
    
    enum AggregationMethod {
        MEDIAN,
        MEAN,
        WEIGHTED_AVERAGE,
        TRIMMED_MEAN,
        VOLUME_WEIGHTED,
        CONFIDENCE_WEIGHTED,
        STAKE_WEIGHTED,
        HYBRID
    }
    
    enum VolatilityModel {
        SIMPLE,
        EXPONENTIAL,
        GARCH,
        EWMA,
        PARKINSON,
        GARMAN_KLASS
    }
    
    enum PriceStatus {
        VALID,
        STALE,
        INVALID,
        EMERGENCY,
        CIRCUIT_BREAKER,
        INSUFFICIENT_DATA
    }
    
    enum SourceType {
        CHAINLINK,
        UNISWAP_V3,
        PYTH,
        BAND,
        CUSTOM,
        INTERNAL,
        EXTERNAL_API,
        CONSENSUS
    }

    // Core price functions
    function getPrice(
        address asset
    ) external view returns (uint256 price, uint256 timestamp);
    
    function getPriceWithConfidence(
        address asset
    ) external view returns (uint256 price, uint256 confidence, uint256 timestamp);
    
    function getLatestPrice(
        address asset
    ) external view returns (PriceData memory);
    
    function getPriceAtTimestamp(
        address asset,
        uint256 timestamp
    ) external view returns (uint256 price);
    
    function getPriceAtBlock(
        address asset,
        uint256 blockNumber
    ) external view returns (uint256 price);
    
    function getMultiplePrices(
        address[] calldata assets
    ) external view returns (uint256[] memory prices, uint256[] memory timestamps);
    
    function isPriceValid(
        address asset
    ) external view returns (bool valid, PriceStatus status);
    
    function getPriceAge(
        address asset
    ) external view returns (uint256 age);
    
    // Price feed management
    function createPriceFeed(
        address asset,
        string calldata symbol,
        uint8 decimals,
        FeedConfig calldata config
    ) external returns (bytes32 feedId);
    
    function updatePriceFeed(
        bytes32 feedId,
        uint256 price,
        uint256 confidence
    ) external;
    
    function pausePriceFeed(
        bytes32 feedId,
        string calldata reason
    ) external;
    
    function unpausePriceFeed(
        bytes32 feedId
    ) external;
    
    function updateFeedConfig(
        bytes32 feedId,
        FeedConfig calldata newConfig
    ) external;
    
    function removePriceFeed(
        bytes32 feedId,
        string calldata reason
    ) external;
    
    // Oracle management
    function addOracle(
        address oracle,
        OracleType oracleType,
        address asset,
        uint256 weight,
        OracleConfig calldata config
    ) external;
    
    function removeOracle(
        address oracle,
        address asset,
        string calldata reason
    ) external;
    
    function updateOracleWeight(
        address oracle,
        address asset,
        uint256 newWeight
    ) external;
    
    function updateOracleConfig(
        address oracle,
        OracleConfig calldata newConfig
    ) external;
    
    function activateOracle(
        address oracle,
        address asset
    ) external;
    
    function deactivateOracle(
        address oracle,
        address asset,
        string calldata reason
    ) external;
    
    function setOracleFailover(
        address primaryOracle,
        address backupOracle,
        address asset
    ) external;
    
    // Aggregation functions
    function updateAggregationMethod(
        address asset,
        AggregationMethod method
    ) external;
    
    function getAggregatedPrice(
        address asset
    ) external view returns (AggregatedPrice memory);
    
    function calculateWeightedPrice(
        address asset,
        uint256[] calldata prices,
        uint256[] calldata weights
    ) external pure returns (uint256 weightedPrice);
    
    function calculateMedianPrice(
        uint256[] calldata prices
    ) external pure returns (uint256 median);
    
    function calculateTrimmedMean(
        uint256[] calldata prices,
        uint256 trimPercentage
    ) external pure returns (uint256 trimmedMean);
    
    // TWAP functions
    function updateTWAP(
        address asset,
        uint256 period
    ) external;
    
    function getTWAP(
        address asset,
        uint256 period
    ) external view returns (uint256 twapPrice);
    
    function getTWAPWithConfig(
        address asset,
        TWAPConfig calldata config
    ) external view returns (TWAP memory);
    
    function calculateTWAP(
        address asset,
        uint256 startTime,
        uint256 endTime
    ) external view returns (uint256 twapPrice);
    
    // Volatility functions
    function updateVolatility(
        address asset,
        uint256 period
    ) external;
    
    function getVolatility(
        address asset,
        uint256 period
    ) external view returns (uint256 volatility);
    
    function getVolatilityData(
        address asset
    ) external view returns (VolatilityData memory);
    
    function calculateHistoricalVolatility(
        address asset,
        uint256 period
    ) external view returns (uint256 volatility);
    
    function calculateRealizedVolatility(
        address asset,
        uint256 period
    ) external view returns (uint256 volatility);
    
    // Circuit breaker functions
    function triggerCircuitBreaker(
        address asset,
        string calldata reason
    ) external;
    
    function resetCircuitBreaker(
        address asset
    ) external;
    
    function updateCircuitBreakerThreshold(
        address asset,
        uint256 newThreshold
    ) external;
    
    function isCircuitBreakerTriggered(
        address asset
    ) external view returns (bool triggered);
    
    function getCircuitBreaker(
        address asset
    ) external view returns (CircuitBreaker memory);
    
    // Emergency functions
    function setEmergencyPrice(
        address asset,
        uint256 price,
        string calldata reason
    ) external;
    
    function removeEmergencyPrice(
        address asset
    ) external;
    
    function getEmergencyPrice(
        address asset
    ) external view returns (EmergencyPrice memory);
    
    function isEmergencyPriceActive(
        address asset
    ) external view returns (bool active);
    
    function pauseOracle(
        string calldata reason
    ) external;
    
    function unpauseOracle() external;
    
    // Validation functions
    function validatePrice(
        address asset,
        uint256 price
    ) external view returns (PriceValidation memory);
    
    function validatePriceUpdate(
        address asset,
        uint256 newPrice,
        uint256 currentPrice
    ) external view returns (bool valid, string memory reason);
    
    function crossValidatePrice(
        address asset,
        uint256 price,
        address[] calldata oracles
    ) external view returns (bool valid, uint256 confidence);
    
    function updateValidationConfig(
        address asset,
        ValidationConfig calldata config
    ) external;
    
    // Configuration functions
    function setDeviationThreshold(
        address asset,
        uint256 threshold
    ) external;
    
    function setHeartbeat(
        address asset,
        uint256 heartbeat
    ) external;
    
    function setMinConfidence(
        address asset,
        uint256 minConfidence
    ) external;
    
    function setMaxStaleness(
        address asset,
        uint256 maxStaleness
    ) external;
    
    function updateGlobalConfig(
        string calldata parameter,
        uint256 value
    ) external;
    
    // View functions - Price Feeds
    function getPriceFeed(
        bytes32 feedId
    ) external view returns (PriceFeed memory);
    
    function getFeedByAsset(
        address asset
    ) external view returns (bytes32 feedId);
    
    function getAllPriceFeeds() external view returns (bytes32[] memory);
    
    function getActivePriceFeeds() external view returns (bytes32[] memory);
    
    function getFeedConfig(
        bytes32 feedId
    ) external view returns (FeedConfig memory);
    
    function getFeedStatus(
        bytes32 feedId
    ) external view returns (FeedStatus memory);
    
    function getFeedMetrics(
        bytes32 feedId
    ) external view returns (FeedMetrics memory);
    
    function getPriceHistory(
        bytes32 feedId,
        uint256 count
    ) external view returns (uint256[] memory prices, uint256[] memory timestamps);
    
    // View functions - Oracles
    function getOracleInfo(
        address oracle,
        address asset
    ) external view returns (OracleInfo memory);
    
    function getAssetOracles(
        address asset
    ) external view returns (address[] memory oracles, uint256[] memory weights);
    
    function getAllOracles() external view returns (address[] memory);
    
    function getActiveOracles(
        address asset
    ) external view returns (address[] memory);
    
    function getOracleMetrics(
        address oracle
    ) external view returns (OracleMetrics memory);
    
    function getOracleStatus(
        address oracle
    ) external view returns (OracleStatus memory);
    
    function isOracleActive(
        address oracle,
        address asset
    ) external view returns (bool active);
    
    function getOracleWeight(
        address oracle,
        address asset
    ) external view returns (uint256 weight);
    
    // View functions - Analytics
    function getPriceStatistics(
        address asset,
        uint256 period
    ) external view returns (
        uint256 minPrice,
        uint256 maxPrice,
        uint256 averagePrice,
        uint256 volatility
    );
    
    function getOraclePerformance(
        address oracle,
        uint256 period
    ) external view returns (
        uint256 uptime,
        uint256 accuracy,
        uint256 responseTime,
        uint256 reliability
    );
    
    function getSystemHealth() external view returns (
        uint256 totalFeeds,
        uint256 activeFeeds,
        uint256 healthyOracles,
        uint256 averageConfidence
    );
    
    function getMarketData(
        address asset
    ) external view returns (
        uint256 price,
        uint256 volume,
        uint256 liquidity,
        uint256 volatility,
        uint256 confidence
    );
}
