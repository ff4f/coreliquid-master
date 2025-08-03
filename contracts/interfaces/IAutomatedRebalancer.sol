// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IAutomatedRebalancer
 * @dev Interface for the Automated Rebalancer contract
 * @author CoreLiquid Protocol
 */
interface IAutomatedRebalancer {
    // Events
    event RebalanceStrategyCreated(
        bytes32 indexed strategyId,
        address indexed creator,
        StrategyType strategyType,
        address[] tokens,
        uint256[] targetAllocations,
        uint256 timestamp
    );
    
    event RebalanceExecuted(
        bytes32 indexed strategyId,
        address indexed executor,
        uint256[] oldAllocations,
        uint256[] newAllocations,
        uint256 totalValue,
        uint256 gasCost,
        uint256 timestamp
    );
    
    event ThresholdTriggered(
        bytes32 indexed strategyId,
        address indexed token,
        uint256 currentAllocation,
        uint256 targetAllocation,
        uint256 deviation,
        uint256 timestamp
    );
    
    event AutomationEnabled(
        bytes32 indexed strategyId,
        uint256 checkInterval,
        uint256 maxGasPrice,
        uint256 timestamp
    );
    
    event AutomationDisabled(
        bytes32 indexed strategyId,
        string reason,
        uint256 timestamp
    );
    
    event RebalanceConditionMet(
        bytes32 indexed strategyId,
        ConditionType conditionType,
        uint256 value,
        uint256 threshold,
        uint256 timestamp
    );
    
    event StrategyUpdated(
        bytes32 indexed strategyId,
        uint256[] oldTargets,
        uint256[] newTargets,
        uint256 timestamp
    );
    
    event EmergencyRebalance(
        bytes32 indexed strategyId,
        address indexed trigger,
        string reason,
        uint256 timestamp
    );
    
    event RebalanceFailed(
        bytes32 indexed strategyId,
        string reason,
        uint256 timestamp
    );
    
    event GasOptimizationApplied(
        bytes32 indexed strategyId,
        uint256 oldGasCost,
        uint256 newGasCost,
        uint256 savings,
        uint256 timestamp
    );
    
    event SlippageProtectionTriggered(
        bytes32 indexed strategyId,
        address token,
        uint256 expectedAmount,
        uint256 actualAmount,
        uint256 slippage,
        uint256 timestamp
    );

    // Structs
    struct RebalanceStrategy {
        bytes32 strategyId;
        address owner;
        string name;
        StrategyType strategyType;
        address[] tokens;
        uint256[] targetAllocations;
        uint256[] currentAllocations;
        uint256 totalValue;
        uint256 deviationThreshold;
        uint256 timeThreshold;
        uint256 lastRebalance;
        uint256 rebalanceCount;
        bool isActive;
        bool automationEnabled;
        uint256 checkInterval;
        uint256 maxGasPrice;
        uint256 maxSlippage;
        RebalanceCondition[] conditions;
        uint256 createdAt;
        uint256 lastUpdate;
    }
    
    struct RebalanceCondition {
        ConditionType conditionType;
        uint256 threshold;
        uint256 value;
        bool isActive;
        uint256 lastCheck;
        uint256 triggerCount;
    }
    
    struct RebalanceExecution {
        bytes32 executionId;
        bytes32 strategyId;
        address executor;
        uint256[] preAllocations;
        uint256[] postAllocations;
        uint256[] swapAmounts;
        address[] swapPaths;
        uint256 totalGasCost;
        uint256 totalSlippage;
        uint256 executionTime;
        bool wasSuccessful;
        string failureReason;
        uint256 timestamp;
    }
    
    struct AutomationConfig {
        bool enabled;
        uint256 checkInterval;
        uint256 maxGasPrice;
        uint256 gasLimit;
        address keeper;
        bool useChainlink;
        bool useGelato;
        uint256 lastExecution;
        uint256 executionCount;
        uint256 failureCount;
    }
    
    struct RebalanceMetrics {
        bytes32 strategyId;
        uint256 totalRebalances;
        uint256 successfulRebalances;
        uint256 failedRebalances;
        uint256 totalGasCost;
        uint256 totalSlippage;
        uint256 averageExecutionTime;
        uint256 totalValueRebalanced;
        uint256 performanceScore;
        uint256 lastUpdate;
    }
    
    struct PortfolioAnalysis {
        bytes32 strategyId;
        uint256[] currentAllocations;
        uint256[] targetAllocations;
        uint256[] deviations;
        uint256 maxDeviation;
        uint256 totalDeviation;
        bool needsRebalance;
        uint256 estimatedGasCost;
        uint256 estimatedSlippage;
        uint256 analysisTime;
    }
    
    struct GasOptimization {
        uint256 baseGasCost;
        uint256 optimizedGasCost;
        uint256 savings;
        string[] optimizations;
        bool batchingEnabled;
        bool routeOptimization;
        bool timingOptimization;
        uint256 lastOptimization;
    }
    
    struct SlippageProtection {
        uint256 maxSlippage;
        uint256 actualSlippage;
        bool protectionTriggered;
        uint256 protectedAmount;
        string protectionMethod;
        uint256 lastProtection;
    }

    // Enums
    enum StrategyType {
        EQUAL_WEIGHT,
        MARKET_CAP_WEIGHT,
        VOLATILITY_WEIGHT,
        MOMENTUM_WEIGHT,
        CUSTOM_WEIGHT,
        DYNAMIC_WEIGHT
    }
    
    enum ConditionType {
        DEVIATION_THRESHOLD,
        TIME_THRESHOLD,
        PRICE_CHANGE,
        VOLATILITY_CHANGE,
        VOLUME_CHANGE,
        MARKET_CONDITION,
        CUSTOM_CONDITION
    }
    
    enum RebalanceStatus {
        PENDING,
        EXECUTING,
        COMPLETED,
        FAILED,
        CANCELLED
    }

    // Core rebalancing functions
    function createStrategy(
        string calldata name,
        StrategyType strategyType,
        address[] calldata tokens,
        uint256[] calldata targetAllocations,
        uint256 deviationThreshold
    ) external returns (bytes32 strategyId);
    
    function executeRebalance(
        bytes32 strategyId
    ) external returns (bool success);
    
    function updateStrategy(
        bytes32 strategyId,
        uint256[] calldata newTargetAllocations
    ) external;
    
    function pauseStrategy(
        bytes32 strategyId
    ) external;
    
    function resumeStrategy(
        bytes32 strategyId
    ) external;
    
    function deleteStrategy(
        bytes32 strategyId
    ) external;
    
    // Automation functions
    function enableAutomation(
        bytes32 strategyId,
        uint256 checkInterval,
        uint256 maxGasPrice
    ) external;
    
    function disableAutomation(
        bytes32 strategyId
    ) external;
    
    function updateAutomationConfig(
        bytes32 strategyId,
        uint256 checkInterval,
        uint256 maxGasPrice,
        uint256 gasLimit
    ) external;
    
    function checkUpkeep(
        bytes32 strategyId
    ) external view returns (bool upkeepNeeded, bytes memory performData);
    
    function performUpkeep(
        bytes32 strategyId,
        bytes calldata performData
    ) external;
    
    // Advanced rebalancing functions
    function batchRebalance(
        bytes32[] calldata strategyIds
    ) external returns (bool[] memory successes);
    
    function emergencyRebalance(
        bytes32 strategyId,
        string calldata reason
    ) external returns (bool success);
    
    function partialRebalance(
        bytes32 strategyId,
        address[] calldata tokensToRebalance
    ) external returns (bool success);
    
    function simulateRebalance(
        bytes32 strategyId
    ) external view returns (
        uint256[] memory swapAmounts,
        uint256 estimatedGasCost,
        uint256 estimatedSlippage
    );
    
    function optimizedRebalance(
        bytes32 strategyId,
        bool enableGasOptimization,
        bool enableSlippageProtection
    ) external returns (bool success);
    
    // Condition management functions
    function addRebalanceCondition(
        bytes32 strategyId,
        ConditionType conditionType,
        uint256 threshold
    ) external;
    
    function removeRebalanceCondition(
        bytes32 strategyId,
        ConditionType conditionType
    ) external;
    
    function updateConditionThreshold(
        bytes32 strategyId,
        ConditionType conditionType,
        uint256 newThreshold
    ) external;
    
    function checkConditions(
        bytes32 strategyId
    ) external view returns (bool[] memory conditionsMet);
    
    function evaluateCondition(
        bytes32 strategyId,
        ConditionType conditionType
    ) external view returns (bool isMet, uint256 currentValue);
    
    // Portfolio analysis functions
    function analyzePortfolio(
        bytes32 strategyId
    ) external view returns (PortfolioAnalysis memory analysis);
    
    function calculateDeviations(
        bytes32 strategyId
    ) external view returns (uint256[] memory deviations);
    
    function needsRebalance(
        bytes32 strategyId
    ) external view returns (bool needs, string memory reason);
    
    function getOptimalRebalancePath(
        bytes32 strategyId
    ) external view returns (
        address[] memory swapPath,
        uint256[] memory swapAmounts,
        uint256 estimatedGasCost
    );
    
    function calculateRebalanceCost(
        bytes32 strategyId
    ) external view returns (uint256 gasCost, uint256 slippageCost);
    
    // Gas optimization functions
    function optimizeGasUsage(
        bytes32 strategyId
    ) external returns (GasOptimization memory optimization);
    
    function enableBatching(
        bytes32 strategyId,
        bool enabled
    ) external;
    
    function setGasOptimizationLevel(
        bytes32 strategyId,
        uint256 level
    ) external;
    
    function estimateOptimizedGasCost(
        bytes32 strategyId
    ) external view returns (uint256 optimizedCost, uint256 savings);
    
    // Slippage protection functions
    function enableSlippageProtection(
        bytes32 strategyId,
        uint256 maxSlippage
    ) external;
    
    function disableSlippageProtection(
        bytes32 strategyId
    ) external;
    
    function updateSlippageThreshold(
        bytes32 strategyId,
        uint256 newThreshold
    ) external;
    
    function calculateSlippage(
        bytes32 strategyId
    ) external view returns (uint256 estimatedSlippage);
    
    // Emergency functions
    function emergencyPause() external;
    
    function emergencyUnpause() external;
    
    function emergencyWithdraw(
        bytes32 strategyId,
        address token,
        uint256 amount
    ) external;
    
    function forceRebalance(
        bytes32 strategyId,
        uint256[] calldata manualAllocations
    ) external;
    
    // Configuration functions
    function setGlobalDeviationThreshold(
        uint256 threshold
    ) external;
    
    function setGlobalMaxGasPrice(
        uint256 maxGasPrice
    ) external;
    
    function setGlobalMaxSlippage(
        uint256 maxSlippage
    ) external;
    
    function updateKeeperAddress(
        address newKeeper
    ) external;
    
    function setRebalanceDelay(
        uint256 delay
    ) external;
    
    // View functions - Strategy information
    function getStrategy(
        bytes32 strategyId
    ) external view returns (RebalanceStrategy memory);
    
    function getUserStrategies(
        address user
    ) external view returns (bytes32[] memory);
    
    function getAllStrategies() external view returns (bytes32[] memory);
    
    function getActiveStrategies() external view returns (bytes32[] memory);
    
    function isStrategyActive(
        bytes32 strategyId
    ) external view returns (bool);
    
    function getStrategyTokens(
        bytes32 strategyId
    ) external view returns (address[] memory tokens);
    
    function getTargetAllocations(
        bytes32 strategyId
    ) external view returns (uint256[] memory allocations);
    
    function getCurrentAllocations(
        bytes32 strategyId
    ) external view returns (uint256[] memory allocations);
    
    // View functions - Execution information
    function getRebalanceExecution(
        bytes32 executionId
    ) external view returns (RebalanceExecution memory);
    
    function getStrategyExecutions(
        bytes32 strategyId
    ) external view returns (bytes32[] memory executionIds);
    
    function getLastExecution(
        bytes32 strategyId
    ) external view returns (RebalanceExecution memory);
    
    function getExecutionHistory(
        bytes32 strategyId,
        uint256 limit
    ) external view returns (RebalanceExecution[] memory);
    
    // View functions - Automation information
    function getAutomationConfig(
        bytes32 strategyId
    ) external view returns (AutomationConfig memory);
    
    function isAutomationEnabled(
        bytes32 strategyId
    ) external view returns (bool);
    
    function getNextExecutionTime(
        bytes32 strategyId
    ) external view returns (uint256 nextTime);
    
    function canExecuteAutomation(
        bytes32 strategyId
    ) external view returns (bool canExecute, string memory reason);
    
    // View functions - Conditions
    function getStrategyConditions(
        bytes32 strategyId
    ) external view returns (RebalanceCondition[] memory);
    
    function getCondition(
        bytes32 strategyId,
        ConditionType conditionType
    ) external view returns (RebalanceCondition memory);
    
    function areConditionsMet(
        bytes32 strategyId
    ) external view returns (bool allMet, bool[] memory individualResults);
    
    // View functions - Metrics and analytics
    function getRebalanceMetrics(
        bytes32 strategyId
    ) external view returns (RebalanceMetrics memory);
    
    function getStrategyPerformance(
        bytes32 strategyId
    ) external view returns (
        uint256 successRate,
        uint256 averageGasCost,
        uint256 averageSlippage,
        uint256 totalValueRebalanced
    );
    
    function getGlobalMetrics() external view returns (
        uint256 totalStrategies,
        uint256 activeStrategies,
        uint256 totalRebalances,
        uint256 totalGasSaved
    );
    
    function getTopPerformingStrategies(
        uint256 count
    ) external view returns (bytes32[] memory strategyIds, uint256[] memory scores);
    
    // View functions - Cost analysis
    function getRebalanceCostBreakdown(
        bytes32 strategyId
    ) external view returns (
        uint256 gasCost,
        uint256 slippageCost,
        uint256 protocolFee,
        uint256 totalCost
    );
    
    function getGasOptimizationSavings(
        bytes32 strategyId
    ) external view returns (uint256 totalSavings, uint256 percentageSaved);
    
    function estimateRebalanceProfitability(
        bytes32 strategyId
    ) external view returns (bool isProfitable, uint256 netBenefit);
    
    // View functions - Risk analysis
    function getSlippageRisk(
        bytes32 strategyId
    ) external view returns (uint256 riskLevel, uint256 maxPotentialSlippage);
    
    function getRebalanceRisk(
        bytes32 strategyId
    ) external view returns (
        uint256 executionRisk,
        uint256 marketRisk,
        uint256 liquidityRisk
    );
    
    function getOptimalRebalanceTime(
        bytes32 strategyId
    ) external view returns (uint256 optimalTime, string memory reason);
    
    // View functions - System health
    function isSystemHealthy() external view returns (bool);
    
    function getSystemHealth() external view returns (
        bool isHealthy,
        uint256 automationHealth,
        uint256 executionHealth,
        uint256 gasHealth
    );
    
    function getStrategyHealth(
        bytes32 strategyId
    ) external view returns (
        bool isHealthy,
        uint256 allocationHealth,
        uint256 executionHealth,
        uint256 automationHealth
    );
    
    function getLastActivity() external view returns (uint256 lastActivityTime);
    
    function getTotalValueManaged() external view returns (uint256 totalValue);
}
