// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IYieldOptimizer
 * @dev Interface for the Yield Optimizer contract
 * @author CoreLiquid Protocol
 */
interface IYieldOptimizer {
    // Events
    event YieldStrategyCreated(
        bytes32 indexed strategyId,
        address indexed creator,
        StrategyType strategyType,
        address[] protocols,
        uint256[] allocations,
        uint256 timestamp
    );
    
    event YieldOptimizationExecuted(
        bytes32 indexed optimizationId,
        address indexed user,
        uint256 totalAmount,
        uint256 expectedYield,
        uint256 actualYield,
        uint256 timestamp
    );
    
    event ProtocolAdded(
        address indexed protocol,
        ProtocolType protocolType,
        uint256 riskScore,
        uint256 expectedAPY,
        uint256 timestamp
    );
    
    event ProtocolRemoved(
        address indexed protocol,
        string reason,
        uint256 timestamp
    );
    
    event AllocationRebalanced(
        bytes32 indexed strategyId,
        uint256[] oldAllocations,
        uint256[] newAllocations,
        uint256 gasCost,
        uint256 timestamp
    );
    
    event YieldHarvested(
        bytes32 indexed harvestId,
        address indexed user,
        address[] protocols,
        uint256[] amounts,
        uint256 totalYield,
        uint256 timestamp
    );
    
    event CompoundingExecuted(
        bytes32 indexed compoundId,
        address indexed user,
        uint256 yieldAmount,
        uint256 compoundedAmount,
        uint256 newTotalStaked,
        uint256 timestamp
    );
    
    event RiskParametersUpdated(
        bytes32 indexed strategyId,
        uint256 oldRiskTolerance,
        uint256 newRiskTolerance,
        uint256 timestamp
    );
    
    event YieldForecastUpdated(
        address indexed protocol,
        uint256 oldForecast,
        uint256 newForecast,
        uint256 confidence,
        uint256 timestamp
    );
    
    event EmergencyWithdrawal(
        bytes32 indexed withdrawalId,
        address indexed user,
        address[] protocols,
        uint256[] amounts,
        uint256 totalWithdrawn,
        uint256 timestamp
    );

    // Structs
    struct YieldStrategy {
        bytes32 strategyId;
        string name;
        StrategyType strategyType;
        address creator;
        address[] protocols;
        uint256[] allocations; // Percentage allocations (basis points)
        uint256 totalAllocated;
        uint256 minInvestment;
        uint256 maxInvestment;
        uint256 riskTolerance;
        uint256 expectedAPY;
        uint256 actualAPY;
        uint256 totalValueLocked;
        uint256 totalUsers;
        bool isActive;
        bool isPublic;
        uint256 createdAt;
        uint256 lastRebalance;
        StrategyConfig config;
        PerformanceMetrics performance;
    }
    
    struct StrategyConfig {
        uint256 rebalanceThreshold; // Basis points
        uint256 rebalanceFrequency; // Seconds
        uint256 maxSlippage; // Basis points
        uint256 gasLimit;
        bool autoCompound;
        uint256 compoundFrequency;
        bool emergencyMode;
        uint256 maxDrawdown; // Basis points
        uint256 stopLossThreshold; // Basis points
        bool dynamicAllocation;
    }
    
    struct PerformanceMetrics {
        uint256 totalReturn;
        uint256 annualizedReturn;
        uint256 volatility;
        uint256 sharpeRatio;
        uint256 maxDrawdown;
        uint256 winRate;
        uint256 averageAPY;
        uint256 bestAPY;
        uint256 worstAPY;
        uint256 totalFees;
        uint256 lastUpdate;
    }
    
    struct YieldProtocol {
        address protocolAddress;
        string name;
        ProtocolType protocolType;
        uint256 currentAPY;
        uint256 historicalAPY;
        uint256 predictedAPY;
        uint256 tvl;
        uint256 riskScore;
        uint256 liquidityScore;
        uint256 reliabilityScore;
        bool isActive;
        bool isVerified;
        uint256 minDeposit;
        uint256 maxDeposit;
        uint256 lockPeriod;
        uint256 withdrawalFee;
        uint256 performanceFee;
        uint256 lastUpdate;
        ProtocolMetrics metrics;
    }
    
    struct ProtocolMetrics {
        uint256 totalDeposits;
        uint256 totalWithdrawals;
        uint256 totalYieldGenerated;
        uint256 averageDepositSize;
        uint256 activeUsers;
        uint256 uptime;
        uint256 slashingEvents;
        uint256 lastSlashing;
        uint256 insuranceCoverage;
        uint256 auditScore;
    }
    
    struct UserPosition {
        address user;
        bytes32 strategyId;
        uint256 totalInvested;
        uint256 currentValue;
        uint256 totalYieldEarned;
        uint256 lastYieldHarvest;
        uint256 lastCompound;
        uint256 entryTimestamp;
        uint256 exitTimestamp;
        bool isActive;
        PositionAllocation[] allocations;
        UserPreferences preferences;
    }
    
    struct PositionAllocation {
        address protocol;
        uint256 amount;
        uint256 shares;
        uint256 entryPrice;
        uint256 currentPrice;
        uint256 yieldEarned;
        uint256 lastUpdate;
    }
    
    struct UserPreferences {
        uint256 riskTolerance; // 1-10 scale
        uint256 yieldTarget; // Basis points
        bool autoRebalance;
        bool autoCompound;
        uint256 rebalanceThreshold;
        uint256 maxGasPrice;
        bool emergencyNotifications;
        uint256[] preferredProtocols;
        uint256[] blacklistedProtocols;
    }
    
    struct OptimizationResult {
        bytes32 optimizationId;
        address user;
        uint256 inputAmount;
        address[] recommendedProtocols;
        uint256[] recommendedAllocations;
        uint256 expectedYield;
        uint256 expectedAPY;
        uint256 riskScore;
        uint256 confidence;
        uint256 gasCost;
        uint256 timestamp;
        OptimizationMetrics metrics;
    }
    
    struct OptimizationMetrics {
        uint256 diversificationScore;
        uint256 liquidityScore;
        uint256 riskAdjustedReturn;
        uint256 efficiencyRatio;
        uint256 opportunityCost;
        uint256 correlationRisk;
        uint256 concentrationRisk;
        uint256 protocolRisk;
    }
    
    struct YieldForecast {
        address protocol;
        uint256 shortTermAPY; // 7 days
        uint256 mediumTermAPY; // 30 days
        uint256 longTermAPY; // 365 days
        uint256 confidence;
        uint256 volatility;
        uint256 trendDirection; // 1=up, 0=stable, -1=down
        uint256 lastUpdate;
        ForecastFactors factors;
    }
    
    struct ForecastFactors {
        uint256 marketSentiment;
        uint256 liquidityTrend;
        uint256 competitionLevel;
        uint256 protocolHealth;
        uint256 externalFactors;
        uint256 seasonality;
        uint256 volatilityIndex;
    }
    
    struct RebalanceProposal {
        bytes32 proposalId;
        bytes32 strategyId;
        uint256[] currentAllocations;
        uint256[] proposedAllocations;
        uint256 expectedImprovement;
        uint256 gasCost;
        uint256 slippage;
        uint256 confidence;
        uint256 createdAt;
        uint256 expiresAt;
        bool isExecuted;
        RebalanceReason reason;
    }
    
    struct HarvestOpportunity {
        bytes32 opportunityId;
        address user;
        address[] protocols;
        uint256[] pendingYields;
        uint256 totalPendingYield;
        uint256 gasCost;
        uint256 netYield;
        uint256 urgency; // 1-10 scale
        uint256 expiresAt;
        bool isOptimal;
    }

    // Enums
    enum StrategyType {
        CONSERVATIVE,
        MODERATE,
        AGGRESSIVE,
        BALANCED,
        CUSTOM,
        DYNAMIC
    }
    
    enum ProtocolType {
        LENDING,
        LIQUIDITY_MINING,
        STAKING,
        YIELD_FARMING,
        SYNTHETIC,
        DERIVATIVES,
        INSURANCE
    }
    
    enum RebalanceReason {
        THRESHOLD_EXCEEDED,
        BETTER_OPPORTUNITY,
        RISK_MANAGEMENT,
        SCHEDULED_REBALANCE,
        EMERGENCY_REBALANCE,
        USER_REQUESTED
    }
    
    enum OptimizationObjective {
        MAXIMIZE_YIELD,
        MINIMIZE_RISK,
        BALANCED_APPROACH,
        MAXIMIZE_LIQUIDITY,
        MINIMIZE_GAS,
        CUSTOM_OBJECTIVE
    }

    // Core yield optimization functions
    function createStrategy(
        string calldata name,
        StrategyType strategyType,
        address[] calldata protocols,
        uint256[] calldata allocations,
        StrategyConfig calldata config
    ) external returns (bytes32 strategyId);
    
    function optimizeYield(
        uint256 amount,
        uint256 riskTolerance,
        OptimizationObjective objective
    ) external returns (OptimizationResult memory result);
    
    function executeOptimization(
        bytes32 optimizationId
    ) external returns (bool success);
    
    function investInStrategy(
        bytes32 strategyId,
        uint256 amount
    ) external returns (bool success);
    
    function withdrawFromStrategy(
        bytes32 strategyId,
        uint256 amount
    ) external returns (bool success);
    
    // Advanced optimization functions
    function optimizePortfolio(
        address user,
        uint256 additionalAmount
    ) external returns (OptimizationResult memory result);
    
    function rebalanceStrategy(
        bytes32 strategyId
    ) external returns (bool success);
    
    function autoRebalanceCheck(
        bytes32 strategyId
    ) external returns (bool needsRebalance, RebalanceProposal memory proposal);
    
    function batchOptimize(
        address[] calldata users,
        uint256[] calldata amounts
    ) external returns (bytes32[] memory optimizationIds);
    
    function dynamicAllocation(
        bytes32 strategyId,
        uint256 marketCondition
    ) external returns (uint256[] memory newAllocations);
    
    // Yield harvesting functions
    function harvestYield(
        address user
    ) external returns (uint256 totalHarvested);
    
    function harvestFromProtocol(
        address user,
        address protocol
    ) external returns (uint256 harvested);
    
    function batchHarvest(
        address[] calldata users
    ) external returns (uint256[] memory harvested);
    
    function getHarvestOpportunities(
        address user
    ) external view returns (HarvestOpportunity[] memory opportunities);
    
    function autoHarvestCheck(
        address user
    ) external view returns (bool shouldHarvest, uint256 expectedYield);
    
    // Compounding functions
    function compoundYield(
        address user
    ) external returns (uint256 compoundedAmount);
    
    function autoCompound(
        address user
    ) external returns (bool success);
    
    function setCompoundingPreferences(
        bool autoCompound,
        uint256 frequency,
        uint256 minAmount
    ) external;
    
    function calculateCompoundingBenefit(
        address user,
        uint256 timeHorizon
    ) external view returns (uint256 benefit);
    
    // Protocol management functions
    function addProtocol(
        address protocol,
        ProtocolType protocolType,
        uint256 riskScore
    ) external;
    
    function removeProtocol(
        address protocol,
        string calldata reason
    ) external;
    
    function updateProtocolMetrics(
        address protocol,
        uint256 newAPY,
        uint256 newRiskScore
    ) external;
    
    function verifyProtocol(
        address protocol
    ) external;
    
    function pauseProtocol(
        address protocol
    ) external;
    
    function unpauseProtocol(
        address protocol
    ) external;
    
    // Forecasting functions
    function updateYieldForecast(
        address protocol,
        uint256 shortTermAPY,
        uint256 mediumTermAPY,
        uint256 longTermAPY,
        uint256 confidence
    ) external;
    
    function generateYieldForecast(
        address protocol,
        uint256 timeHorizon
    ) external returns (YieldForecast memory forecast);
    
    function getMarketTrends() external view returns (
        uint256 overallTrend,
        uint256 averageAPY,
        uint256 marketVolatility
    );
    
    function predictOptimalAllocation(
        uint256 amount,
        uint256 timeHorizon,
        uint256 riskTolerance
    ) external view returns (
        address[] memory protocols,
        uint256[] memory allocations,
        uint256 expectedReturn
    );
    
    // Risk management functions
    function assessRisk(
        bytes32 strategyId
    ) external view returns (uint256 riskScore, string memory riskLevel);
    
    function calculateVaR(
        bytes32 strategyId,
        uint256 confidence,
        uint256 timeHorizon
    ) external view returns (uint256 valueAtRisk);
    
    function setRiskLimits(
        bytes32 strategyId,
        uint256 maxDrawdown,
        uint256 stopLoss
    ) external;
    
    function checkRiskLimits(
        bytes32 strategyId
    ) external view returns (bool withinLimits, string memory violations);
    
    function emergencyWithdraw(
        bytes32 strategyId
    ) external returns (uint256 withdrawnAmount);
    
    // User preference functions
    function setUserPreferences(
        UserPreferences calldata preferences
    ) external;
    
    function updateRiskTolerance(
        uint256 newRiskTolerance
    ) external;
    
    function setYieldTarget(
        uint256 targetAPY
    ) external;
    
    function setPreferredProtocols(
        uint256[] calldata protocolIds
    ) external;
    
    function blacklistProtocol(
        uint256 protocolId
    ) external;
    
    // Configuration functions
    function setGlobalRebalanceThreshold(
        uint256 threshold
    ) external;
    
    function setMaxSlippage(
        uint256 maxSlippage
    ) external;
    
    function setPerformanceFee(
        uint256 fee
    ) external;
    
    function setMinInvestment(
        uint256 minAmount
    ) external;
    
    function setMaxInvestment(
        uint256 maxAmount
    ) external;
    
    // Emergency functions
    function pauseStrategy(
        bytes32 strategyId
    ) external;
    
    function unpauseStrategy(
        bytes32 strategyId
    ) external;
    
    function emergencyPause() external;
    
    function emergencyUnpause() external;
    
    function forceRebalance(
        bytes32 strategyId
    ) external;
    
    // View functions - Strategies
    function getStrategy(
        bytes32 strategyId
    ) external view returns (YieldStrategy memory);
    
    function getAllStrategies() external view returns (bytes32[] memory);
    
    function getUserStrategies(
        address user
    ) external view returns (bytes32[] memory);
    
    function getPublicStrategies() external view returns (bytes32[] memory);
    
    function getStrategyPerformance(
        bytes32 strategyId
    ) external view returns (PerformanceMetrics memory);
    
    function getStrategyAPY(
        bytes32 strategyId
    ) external view returns (uint256 currentAPY, uint256 historicalAPY);
    
    function getStrategyRisk(
        bytes32 strategyId
    ) external view returns (uint256 riskScore);
    
    function getStrategyTVL(
        bytes32 strategyId
    ) external view returns (uint256 tvl);
    
    // View functions - Protocols
    function getProtocol(
        address protocol
    ) external view returns (YieldProtocol memory);
    
    function getAllProtocols() external view returns (address[] memory);
    
    function getActiveProtocols() external view returns (address[] memory);
    
    function getProtocolsByType(
        ProtocolType protocolType
    ) external view returns (address[] memory);
    
    function getProtocolAPY(
        address protocol
    ) external view returns (uint256 currentAPY);
    
    function getProtocolRisk(
        address protocol
    ) external view returns (uint256 riskScore);
    
    function getProtocolTVL(
        address protocol
    ) external view returns (uint256 tvl);
    
    function getBestProtocols(
        uint256 count,
        ProtocolType protocolType
    ) external view returns (address[] memory protocols, uint256[] memory apys);
    
    // View functions - User positions
    function getUserPosition(
        address user,
        bytes32 strategyId
    ) external view returns (UserPosition memory);
    
    function getUserPositions(
        address user
    ) external view returns (UserPosition[] memory);
    
    function getUserTotalValue(
        address user
    ) external view returns (uint256 totalValue);
    
    function getUserTotalYield(
        address user
    ) external view returns (uint256 totalYield);
    
    function getUserAPY(
        address user
    ) external view returns (uint256 weightedAPY);
    
    function getUserPreferences(
        address user
    ) external view returns (UserPreferences memory);
    
    // View functions - Optimization
    function getOptimizationResult(
        bytes32 optimizationId
    ) external view returns (OptimizationResult memory);
    
    function getOptimalAllocation(
        uint256 amount,
        uint256 riskTolerance
    ) external view returns (
        address[] memory protocols,
        uint256[] memory allocations,
        uint256 expectedAPY
    );
    
    function simulateInvestment(
        bytes32 strategyId,
        uint256 amount
    ) external view returns (
        uint256 expectedValue,
        uint256 expectedYield,
        uint256 riskScore
    );
    
    function compareStrategies(
        bytes32[] calldata strategyIds
    ) external view returns (
        uint256[] memory apys,
        uint256[] memory risks,
        uint256[] memory tvls
    );
    
    // View functions - Forecasts
    function getYieldForecast(
        address protocol
    ) external view returns (YieldForecast memory);
    
    function getMarketForecast(
        uint256 timeHorizon
    ) external view returns (
        uint256 expectedAPY,
        uint256 confidence,
        uint256 volatility
    );
    
    function getForecastAccuracy(
        address protocol
    ) external view returns (uint256 accuracy);
    
    // View functions - Analytics
    function getTotalValueLocked() external view returns (uint256 tvl);
    
    function getTotalYieldGenerated() external view returns (uint256 totalYield);
    
    function getAverageAPY() external view returns (uint256 averageAPY);
    
    function getTotalUsers() external view returns (uint256 totalUsers);
    
    function getActiveStrategies() external view returns (uint256 activeCount);
    
    function getSystemHealth() external view returns (
        bool isHealthy,
        uint256 protocolHealth,
        uint256 liquidityHealth,
        uint256 performanceHealth
    );
    
    function getGasOptimization() external view returns (
        uint256 averageGasCost,
        uint256 gasEfficiency,
        uint256 totalGasSaved
    );
}
