// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IIdleCapitalManager
 * @dev Interface for the Idle Capital Manager contract
 * @author CoreLiquid Protocol
 */
interface IIdleCapitalManager {
    // Events
    event IdleCapitalDeployed(
        address indexed asset,
        address indexed strategy,
        uint256 amount,
        uint256 expectedYield,
        uint256 timestamp
    );
    
    event IdleCapitalRecalled(
        address indexed asset,
        address indexed strategy,
        uint256 amount,
        uint256 actualYield,
        uint256 timestamp
    );
    
    event StrategyAdded(
        address indexed strategy,
        address indexed asset,
        uint256 riskLevel,
        uint256 expectedAPY,
        uint256 timestamp
    );
    
    event StrategyRemoved(
        address indexed strategy,
        address indexed asset,
        uint256 timestamp
    );
    
    event YieldHarvested(
        address indexed asset,
        uint256 totalYield,
        uint256 fee,
        uint256 timestamp
    );
    
    event OptimizationExecuted(
        address indexed asset,
        uint256 totalOptimized,
        uint256 yieldImprovement,
        uint256 timestamp
    );
    
    event EmergencyRecall(
        address indexed asset,
        address indexed strategy,
        uint256 amount,
        string reason,
        uint256 timestamp
    );

    // Structs
    struct IdleCapitalInfo {
        address asset;
        uint256 totalIdle;
        uint256 totalDeployed;
        uint256 totalYieldEarned;
        uint256 utilizationRate;
        uint256 averageAPY;
        uint256 lastOptimization;
        bool isActive;
    }
    
    struct StrategyInfo {
        address strategyAddress;
        address asset;
        string name;
        uint256 riskLevel;
        uint256 expectedAPY;
        uint256 actualAPY;
        uint256 totalDeployed;
        uint256 totalYield;
        uint256 maxCapacity;
        uint256 minDeployment;
        uint256 lastUpdate;
        bool isActive;
        bool isVerified;
    }
    
    struct DeploymentInfo {
        bytes32 deploymentId;
        address asset;
        address strategy;
        uint256 amount;
        uint256 deployedAt;
        uint256 expectedYield;
        uint256 actualYield;
        uint256 duration;
        bool isActive;
        bool isMatured;
    }
    
    struct OptimizationConfig {
        address asset;
        uint256 minIdleThreshold;
        uint256 maxRiskLevel;
        uint256 targetAPY;
        uint256 rebalanceFrequency;
        uint256 lastRebalance;
        bool autoOptimize;
        bool emergencyMode;
    }
    
    struct YieldMetrics {
        uint256 totalYieldGenerated;
        uint256 totalFeesCollected;
        uint256 averageAPY;
        uint256 bestAPY;
        uint256 worstAPY;
        uint256 totalDeployments;
        uint256 successfulDeployments;
        uint256 lastMetricsUpdate;
    }

    // Core functions
    function deployIdleCapital(
        address asset,
        uint256 amount,
        address strategy
    ) external returns (bytes32 deploymentId);
    
    function recallCapital(
        bytes32 deploymentId,
        uint256 amount
    ) external returns (uint256 recalled, uint256 yield);
    
    function harvestYield(
        address asset
    ) external returns (uint256 totalYield);
    
    function optimizeCapitalAllocation(
        address asset
    ) external returns (uint256 optimizedAmount);
    
    function rebalanceStrategies(
        address asset
    ) external returns (uint256 totalRebalanced);
    
    // Strategy management
    function addStrategy(
        address strategy,
        address asset,
        string calldata name,
        uint256 riskLevel,
        uint256 expectedAPY,
        uint256 maxCapacity,
        uint256 minDeployment
    ) external;
    
    function removeStrategy(
        address strategy,
        address asset
    ) external;
    
    function updateStrategyAPY(
        address strategy,
        address asset,
        uint256 newAPY
    ) external;
    
    function pauseStrategy(
        address strategy,
        address asset
    ) external;
    
    function unpauseStrategy(
        address strategy,
        address asset
    ) external;
    
    function verifyStrategy(
        address strategy,
        address asset
    ) external;
    
    // Configuration management
    function setOptimizationConfig(
        address asset,
        uint256 minIdleThreshold,
        uint256 maxRiskLevel,
        uint256 targetAPY,
        uint256 rebalanceFrequency,
        bool autoOptimize
    ) external;
    
    function updateMinIdleThreshold(
        address asset,
        uint256 newThreshold
    ) external;
    
    function setAutoOptimization(
        address asset,
        bool enabled
    ) external;
    
    function setEmergencyMode(
        address asset,
        bool enabled
    ) external;
    
    // Emergency functions
    function emergencyRecallAll(
        address asset,
        string calldata reason
    ) external;
    
    function emergencyRecallStrategy(
        address strategy,
        address asset,
        string calldata reason
    ) external;
    
    function emergencyPause(
        address asset
    ) external;
    
    function emergencyUnpause(
        address asset
    ) external;
    
    // View functions
    function getIdleCapitalInfo(
        address asset
    ) external view returns (IdleCapitalInfo memory);
    
    function getStrategyInfo(
        address strategy,
        address asset
    ) external view returns (StrategyInfo memory);
    
    function getDeploymentInfo(
        bytes32 deploymentId
    ) external view returns (DeploymentInfo memory);
    
    function getOptimizationConfig(
        address asset
    ) external view returns (OptimizationConfig memory);
    
    function getYieldMetrics(
        address asset
    ) external view returns (YieldMetrics memory);
    
    function getAvailableStrategies(
        address asset
    ) external view returns (address[] memory);
    
    function getActiveDeployments(
        address asset
    ) external view returns (bytes32[] memory);
    
    function getUserDeployments(
        address user,
        address asset
    ) external view returns (bytes32[] memory);
    
    function getSupportedAssets() external view returns (address[] memory);
    
    // Capital calculations
    function getIdleAmount(
        address asset
    ) external view returns (uint256 idleAmount);
    
    function getDeployedAmount(
        address asset
    ) external view returns (uint256 deployedAmount);
    
    function getTotalCapital(
        address asset
    ) external view returns (uint256 totalCapital);
    
    function getUtilizationRate(
        address asset
    ) external view returns (uint256 utilizationRate);
    
    function getOptimalAllocation(
        address asset,
        uint256 amount
    ) external view returns (
        address[] memory strategies,
        uint256[] memory allocations
    );
    
    // Yield calculations
    function getExpectedYield(
        address asset,
        address strategy,
        uint256 amount,
        uint256 duration
    ) external view returns (uint256 expectedYield);
    
    function getCurrentAPY(
        address asset,
        address strategy
    ) external view returns (uint256 apy);
    
    function getAverageAPY(
        address asset
    ) external view returns (uint256 averageAPY);
    
    function getBestStrategy(
        address asset,
        uint256 amount
    ) external view returns (address strategy, uint256 expectedAPY);
    
    function getYieldProjection(
        address asset,
        uint256 amount,
        uint256 duration
    ) external view returns (uint256 projectedYield);
    
    // Risk assessment
    function getStrategyRisk(
        address strategy,
        address asset
    ) external view returns (uint256 riskLevel);
    
    function isStrategyHealthy(
        address strategy,
        address asset
    ) external view returns (bool);
    
    function getRiskAdjustedReturn(
        address strategy,
        address asset
    ) external view returns (uint256 riskAdjustedReturn);
    
    // Optimization checks
    function needsOptimization(
        address asset
    ) external view returns (bool);
    
    function canDeploy(
        address asset,
        address strategy,
        uint256 amount
    ) external view returns (bool);
    
    function getOptimizationOpportunity(
        address asset
    ) external view returns (uint256 potentialYieldIncrease);
    
    function isRebalanceNeeded(
        address asset
    ) external view returns (bool);
    
    // Performance metrics
    function getPerformanceMetrics(
        address asset,
        uint256 period
    ) external view returns (
        uint256 totalReturn,
        uint256 averageAPY,
        uint256 volatility,
        uint256 sharpeRatio
    );
    
    function getStrategyPerformance(
        address strategy,
        address asset,
        uint256 period
    ) external view returns (
        uint256 totalReturn,
        uint256 apy,
        uint256 successRate
    );
    
    // Global statistics
    function getTotalIdleCapital() external view returns (uint256);
    
    function getTotalDeployedCapital() external view returns (uint256);
    
    function getTotalYieldGenerated() external view returns (uint256);
    
    function getGlobalUtilizationRate() external view returns (uint256);
    
    function getGlobalAPY() external view returns (uint256);
    
    function getTotalActiveStrategies() external view returns (uint256);
    
    function getTotalDeployments() external view returns (uint256);
}
