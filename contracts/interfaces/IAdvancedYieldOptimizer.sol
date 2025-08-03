// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IAdvancedYieldOptimizer
 * @dev Interface for the Advanced Yield Optimizer contract
 * @author CoreLiquid Protocol
 */
interface IAdvancedYieldOptimizer {
    // Events
    event YieldStrategyCreated(
        bytes32 indexed strategyId,
        address indexed creator,
        string strategyName,
        address[] tokens,
        uint256 expectedAPY,
        uint256 timestamp
    );
    
    event YieldStrategyExecuted(
        bytes32 indexed strategyId,
        address indexed user,
        uint256 amount,
        uint256 expectedYield,
        uint256 timestamp
    );
    
    event YieldHarvested(
        bytes32 indexed strategyId,
        address indexed user,
        uint256 yieldAmount,
        uint256 fees,
        uint256 timestamp
    );
    
    event StrategyRebalanced(
        bytes32 indexed strategyId,
        uint256 oldAllocation,
        uint256 newAllocation,
        uint256 newAPY,
        uint256 timestamp
    );
    
    event CompoundExecuted(
        bytes32 indexed strategyId,
        address indexed user,
        uint256 compoundedAmount,
        uint256 newBalance,
        uint256 timestamp
    );
    
    event RiskAssessmentUpdated(
        bytes32 indexed strategyId,
        uint256 oldRiskScore,
        uint256 newRiskScore,
        string riskLevel,
        uint256 timestamp
    );
    
    event ProtocolIntegrated(
        string indexed protocolName,
        address indexed protocolAddress,
        address indexed adapter,
        uint256 timestamp
    );
    
    event EmergencyWithdrawal(
        bytes32 indexed strategyId,
        address indexed user,
        uint256 amount,
        string reason,
        uint256 timestamp
    );
    
    event YieldOptimizationCompleted(
        address indexed user,
        uint256 totalYield,
        uint256 optimizationGain,
        uint256 timestamp
    );
    
    event AutoCompoundEnabled(
        bytes32 indexed strategyId,
        address indexed user,
        uint256 frequency,
        uint256 threshold,
        uint256 timestamp
    );

    // Structs
    struct YieldStrategy {
        bytes32 strategyId;
        string name;
        string description;
        address creator;
        address[] tokens;
        uint256[] allocations;
        string[] protocols;
        uint256 totalDeposited;
        uint256 totalYield;
        uint256 expectedAPY;
        uint256 actualAPY;
        uint256 riskScore;
        RiskLevel riskLevel;
        StrategyStatus status;
        uint256 minDeposit;
        uint256 maxDeposit;
        uint256 lockPeriod;
        uint256 performanceFee;
        uint256 managementFee;
        uint256 createdAt;
        uint256 lastRebalance;
        uint256 lastHarvest;
        bool isActive;
        bool isPublic;
        bool autoCompound;
        bool emergencyMode;
    }
    
    struct UserPosition {
        bytes32 strategyId;
        address user;
        uint256 depositedAmount;
        uint256 shares;
        uint256 accruedYield;
        uint256 lastHarvest;
        uint256 lastCompound;
        uint256 depositedAt;
        uint256 lockUntil;
        bool autoCompoundEnabled;
        uint256 autoCompoundThreshold;
        uint256 autoCompoundFrequency;
        uint256 totalHarvested;
        uint256 totalCompounded;
    }
    
    struct ProtocolAdapter {
        string protocolName;
        address protocolAddress;
        address adapterAddress;
        uint256 currentAPY;
        uint256 averageAPY;
        uint256 totalLiquidity;
        uint256 maxCapacity;
        uint256 utilizationRate;
        uint256 riskScore;
        uint256 reliability;
        uint256 gasEfficiency;
        bool isActive;
        bool isVerified;
        string[] supportedTokens;
        uint256 lastUpdate;
    }
    
    struct YieldOpportunity {
        bytes32 opportunityId;
        string protocolName;
        address token;
        uint256 apy;
        uint256 tvl;
        uint256 capacity;
        uint256 minDeposit;
        uint256 lockPeriod;
        uint256 riskScore;
        RiskLevel riskLevel;
        uint256 detectedAt;
        uint256 expiresAt;
        bool isActive;
        bool isVerified;
    }
    
    struct OptimizationConfig {
        uint256 rebalanceThreshold;
        uint256 harvestThreshold;
        uint256 maxRiskScore;
        uint256 minAPYDifference;
        uint256 gasOptimizationLevel;
        uint256 slippageTolerance;
        bool autoRebalance;
        bool autoHarvest;
        bool riskManagement;
        uint256 lastUpdate;
    }
    
    struct PerformanceMetrics {
        uint256 totalStrategies;
        uint256 activeStrategies;
        uint256 totalValueLocked;
        uint256 totalYieldGenerated;
        uint256 averageAPY;
        uint256 totalUsers;
        uint256 totalHarvests;
        uint256 totalCompounds;
        uint256 totalRebalances;
        uint256 lastUpdate;
    }
    
    struct RiskMetrics {
        uint256 portfolioRisk;
        uint256 concentrationRisk;
        uint256 liquidityRisk;
        uint256 protocolRisk;
        uint256 marketRisk;
        uint256 overallRisk;
        string riskAssessment;
        uint256 lastAssessment;
    }

    // Enums
    enum RiskLevel {
        VERY_LOW,
        LOW,
        MEDIUM,
        HIGH,
        VERY_HIGH
    }
    
    enum StrategyStatus {
        ACTIVE,
        PAUSED,
        DEPRECATED,
        EMERGENCY
    }

    // Core yield optimization functions
    function createYieldStrategy(
        string calldata name,
        string calldata description,
        address[] calldata tokens,
        uint256[] calldata allocations,
        string[] calldata protocols,
        uint256 minDeposit,
        uint256 maxDeposit,
        uint256 lockPeriod,
        bool isPublic
    ) external returns (bytes32 strategyId);
    
    function depositToStrategy(
        bytes32 strategyId,
        uint256 amount
    ) external returns (uint256 shares);
    
    function withdrawFromStrategy(
        bytes32 strategyId,
        uint256 shares
    ) external returns (uint256 amount);
    
    function harvestYield(
        bytes32 strategyId
    ) external returns (uint256 yieldAmount);
    
    function compoundYield(
        bytes32 strategyId
    ) external returns (uint256 compoundedAmount);
    
    function rebalanceStrategy(
        bytes32 strategyId
    ) external returns (uint256 newAPY);
    
    // Advanced optimization functions
    function optimizePortfolio(
        address user
    ) external returns (uint256 totalOptimizationGain);
    
    function findOptimalStrategy(
        address token,
        uint256 amount,
        uint256 lockPeriod,
        RiskLevel maxRiskLevel
    ) external view returns (bytes32 optimalStrategyId, uint256 expectedAPY);
    
    function executeOptimalAllocation(
        address[] calldata tokens,
        uint256[] calldata amounts,
        RiskLevel maxRiskLevel
    ) external returns (bytes32[] memory strategyIds, uint256[] memory allocatedAmounts);
    
    function autoOptimizeYield(
        address user,
        uint256 optimizationBudget
    ) external returns (uint256 optimizationGain);
    
    function batchHarvest(
        bytes32[] calldata strategyIds
    ) external returns (uint256[] memory yieldAmounts);
    
    function batchCompound(
        bytes32[] calldata strategyIds
    ) external returns (uint256[] memory compoundedAmounts);
    
    // Strategy management
    function updateStrategy(
        bytes32 strategyId,
        uint256[] calldata newAllocations,
        string[] calldata newProtocols
    ) external;
    
    function pauseStrategy(
        bytes32 strategyId
    ) external;
    
    function unpauseStrategy(
        bytes32 strategyId
    ) external;
    
    function deprecateStrategy(
        bytes32 strategyId,
        bytes32 migrationStrategyId
    ) external;
    
    function emergencyPauseStrategy(
        bytes32 strategyId,
        string calldata reason
    ) external;
    
    function migrateStrategy(
        bytes32 oldStrategyId,
        bytes32 newStrategyId
    ) external returns (uint256 migratedAmount);
    
    // Auto-compound functions
    function enableAutoCompound(
        bytes32 strategyId,
        uint256 threshold,
        uint256 frequency
    ) external;
    
    function disableAutoCompound(
        bytes32 strategyId
    ) external;
    
    function executeAutoCompound(
        bytes32 strategyId,
        address user
    ) external returns (uint256 compoundedAmount);
    
    function updateAutoCompoundSettings(
        bytes32 strategyId,
        uint256 newThreshold,
        uint256 newFrequency
    ) external;
    
    function getAutoCompoundQueue() external view returns (
        bytes32[] memory strategyIds,
        address[] memory users
    );
    
    // Protocol integration
    function integrateProtocol(
        string calldata protocolName,
        address protocolAddress,
        address adapterAddress,
        string[] calldata supportedTokens
    ) external;
    
    function removeProtocol(
        string calldata protocolName
    ) external;
    
    function updateProtocolAdapter(
        string calldata protocolName,
        address newAdapterAddress
    ) external;
    
    function pauseProtocol(
        string calldata protocolName
    ) external;
    
    function unpauseProtocol(
        string calldata protocolName
    ) external;
    
    function verifyProtocol(
        string calldata protocolName
    ) external;
    
    // Yield opportunity detection
    function scanYieldOpportunities(
        address token
    ) external returns (YieldOpportunity[] memory opportunities);
    
    function detectArbitrageYield(
        address tokenA,
        address tokenB
    ) external view returns (
        uint256 potentialYield,
        string memory bestProtocol
    );
    
    function findHighestYield(
        address token,
        uint256 amount
    ) external view returns (
        string memory protocolName,
        uint256 apy,
        uint256 capacity
    );
    
    function compareYieldOpportunities(
        address token,
        uint256 amount,
        string[] calldata protocols
    ) external view returns (
        uint256[] memory apys,
        uint256[] memory capacities,
        uint256[] memory riskScores
    );
    
    // Risk management
    function assessStrategyRisk(
        bytes32 strategyId
    ) external view returns (RiskMetrics memory);
    
    function calculatePortfolioRisk(
        address user
    ) external view returns (RiskMetrics memory);
    
    function updateRiskParameters(
        bytes32 strategyId,
        uint256 newRiskScore,
        RiskLevel newRiskLevel
    ) external;
    
    function setRiskLimits(
        uint256 maxPortfolioRisk,
        uint256 maxConcentrationRisk,
        uint256 maxProtocolRisk
    ) external;
    
    function checkRiskCompliance(
        bytes32 strategyId
    ) external view returns (bool isCompliant, string memory reason);
    
    // Configuration functions
    function setOptimizationConfig(
        uint256 rebalanceThreshold,
        uint256 harvestThreshold,
        uint256 maxRiskScore,
        uint256 minAPYDifference,
        bool autoRebalance,
        bool autoHarvest
    ) external;
    
    function setPerformanceFees(
        uint256 performanceFee,
        uint256 managementFee
    ) external;
    
    function setGasOptimization(
        uint256 optimizationLevel
    ) external;
    
    function setSlippageTolerance(
        uint256 slippageTolerance
    ) external;
    
    function setEmergencyMode(
        bool enabled
    ) external;
    
    // Emergency functions
    function emergencyWithdraw(
        bytes32 strategyId,
        address user
    ) external returns (uint256 amount);
    
    function emergencyPauseAll() external;
    
    function emergencyUnpauseAll() external;
    
    function emergencyRebalance(
        bytes32 strategyId
    ) external;
    
    function emergencyMigrate(
        bytes32 strategyId,
        address emergencyRecipient
    ) external;
    
    // View functions - Strategy information
    function getStrategy(
        bytes32 strategyId
    ) external view returns (YieldStrategy memory);
    
    function getUserPosition(
        bytes32 strategyId,
        address user
    ) external view returns (UserPosition memory);
    
    function getUserStrategies(
        address user
    ) external view returns (bytes32[] memory);
    
    function getActiveStrategies() external view returns (bytes32[] memory);
    
    function getPublicStrategies() external view returns (bytes32[] memory);
    
    function getStrategyPerformance(
        bytes32 strategyId
    ) external view returns (
        uint256 totalReturn,
        uint256 apy,
        uint256 sharpeRatio,
        uint256 maxDrawdown
    );
    
    // View functions - Protocol information
    function getProtocolAdapter(
        string calldata protocolName
    ) external view returns (ProtocolAdapter memory);
    
    function getSupportedProtocols() external view returns (string[] memory);
    
    function getActiveProtocols() external view returns (string[] memory);
    
    function getProtocolAPY(
        string calldata protocolName,
        address token
    ) external view returns (uint256 apy);
    
    function getProtocolCapacity(
        string calldata protocolName,
        address token
    ) external view returns (uint256 capacity, uint256 utilized);
    
    // View functions - Yield calculations
    function calculateExpectedYield(
        bytes32 strategyId,
        uint256 amount,
        uint256 duration
    ) external view returns (uint256 expectedYield);
    
    function calculateCompoundYield(
        bytes32 strategyId,
        uint256 amount,
        uint256 duration,
        uint256 compoundFrequency
    ) external view returns (uint256 compoundYield);
    
    function calculateOptimalCompoundFrequency(
        bytes32 strategyId,
        uint256 amount
    ) external view returns (uint256 optimalFrequency, uint256 maxYield);
    
    function estimateGasCosts(
        bytes32 strategyId,
        string calldata operation
    ) external view returns (uint256 gasCost);
    
    function calculateNetYield(
        bytes32 strategyId,
        uint256 grossYield
    ) external view returns (uint256 netYield, uint256 fees);
    
    // View functions - Opportunities
    function getYieldOpportunity(
        bytes32 opportunityId
    ) external view returns (YieldOpportunity memory);
    
    function getActiveOpportunities(
        address token
    ) external view returns (YieldOpportunity[] memory);
    
    function getBestOpportunities(
        address token,
        uint256 amount,
        RiskLevel maxRiskLevel
    ) external view returns (YieldOpportunity[] memory);
    
    function getOpportunityRanking(
        address token,
        uint256 amount
    ) external view returns (
        bytes32[] memory opportunityIds,
        uint256[] memory scores
    );
    
    // View functions - Performance metrics
    function getPerformanceMetrics() external view returns (PerformanceMetrics memory);
    
    function getStrategyMetrics(
        bytes32 strategyId
    ) external view returns (
        uint256 totalDeposits,
        uint256 totalWithdrawals,
        uint256 totalYield,
        uint256 averageAPY,
        uint256 userCount
    );
    
    function getUserMetrics(
        address user
    ) external view returns (
        uint256 totalDeposited,
        uint256 totalYield,
        uint256 averageAPY,
        uint256 activeStrategies,
        uint256 totalHarvested
    );
    
    function getProtocolMetrics(
        string calldata protocolName
    ) external view returns (
        uint256 totalLiquidity,
        uint256 averageAPY,
        uint256 utilizationRate,
        uint256 reliability
    );
    
    // View functions - Risk assessment
    function getStrategyRisk(
        bytes32 strategyId
    ) external view returns (RiskMetrics memory);
    
    function getPortfolioRisk(
        address user
    ) external view returns (RiskMetrics memory);
    
    function getProtocolRisk(
        string calldata protocolName
    ) external view returns (uint256 riskScore, RiskLevel riskLevel);
    
    function getRiskLimits() external view returns (
        uint256 maxPortfolioRisk,
        uint256 maxConcentrationRisk,
        uint256 maxProtocolRisk
    );
    
    // View functions - Configuration
    function getOptimizationConfig() external view returns (OptimizationConfig memory);
    
    function getPerformanceFees() external view returns (
        uint256 performanceFee,
        uint256 managementFee
    );
    
    function getGasOptimizationLevel() external view returns (uint256);
    
    function getSlippageTolerance() external view returns (uint256);
    
    function isEmergencyMode() external view returns (bool);
    
    // View functions - Capacity and limits
    function getStrategyCapacity(
        bytes32 strategyId
    ) external view returns (uint256 maxCapacity, uint256 currentUtilization);
    
    function getMaxDeposit(
        bytes32 strategyId,
        address user
    ) external view returns (uint256 maxAmount);
    
    function getMinDeposit(
        bytes32 strategyId
    ) external view returns (uint256 minAmount);
    
    function canDeposit(
        bytes32 strategyId,
        address user,
        uint256 amount
    ) external view returns (bool);
    
    function canWithdraw(
        bytes32 strategyId,
        address user,
        uint256 shares
    ) external view returns (bool);
    
    // View functions - Auto-compound
    function getAutoCompoundSettings(
        bytes32 strategyId,
        address user
    ) external view returns (
        bool enabled,
        uint256 threshold,
        uint256 frequency,
        uint256 lastExecution
    );
    
    function isAutoCompoundDue(
        bytes32 strategyId,
        address user
    ) external view returns (bool);
    
    function getAutoCompoundEstimate(
        bytes32 strategyId,
        address user
    ) external view returns (uint256 estimatedCompound, uint256 gasCost);
    
    // View functions - System health
    function isSystemHealthy() external view returns (bool);
    
    function getSystemHealth() external view returns (
        bool isHealthy,
        uint256 liquidityHealth,
        uint256 protocolHealth,
        uint256 riskHealth
    );
    
    function getStrategyHealth(
        bytes32 strategyId
    ) external view returns (
        bool isHealthy,
        uint256 performanceHealth,
        uint256 riskHealth,
        uint256 liquidityHealth
    );
}
