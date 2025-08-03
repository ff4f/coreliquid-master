// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IRiskManagementEngine
 * @dev Interface for the Risk Management Engine contract
 * @author CoreLiquid Protocol
 */
interface IRiskManagementEngine {
    // Events
    event RiskAssessmentCompleted(
        address indexed user,
        bytes32 indexed assessmentId,
        uint256 riskScore,
        string riskLevel,
        uint256 timestamp
    );
    
    event RiskLimitExceeded(
        address indexed user,
        string riskType,
        uint256 currentLevel,
        uint256 maxAllowed,
        uint256 timestamp
    );
    
    event RiskMitigationExecuted(
        address indexed user,
        bytes32 indexed mitigationId,
        string mitigationType,
        uint256 reducedRisk,
        uint256 timestamp
    );
    
    event CollateralLiquidated(
        address indexed user,
        address indexed collateralToken,
        uint256 liquidatedAmount,
        uint256 debtCovered,
        uint256 timestamp
    );
    
    event PositionRebalanced(
        address indexed user,
        bytes32 indexed positionId,
        uint256 oldRiskScore,
        uint256 newRiskScore,
        uint256 timestamp
    );
    
    event RiskParametersUpdated(
        string parameterType,
        uint256 oldValue,
        uint256 newValue,
        uint256 timestamp
    );
    
    event EmergencyRiskAction(
        address indexed user,
        string actionType,
        uint256 affectedAmount,
        string reason,
        uint256 timestamp
    );
    
    event RiskModelUpdated(
        string modelName,
        uint256 version,
        uint256 timestamp
    );
    
    event StressTestCompleted(
        bytes32 indexed testId,
        uint256 scenarioCount,
        uint256 failureRate,
        uint256 timestamp
    );
    
    event RiskAlertTriggered(
        address indexed user,
        string alertType,
        uint256 severity,
        string message,
        uint256 timestamp
    );

    // Structs
    struct RiskProfile {
        address user;
        uint256 overallRiskScore;
        uint256 creditRisk;
        uint256 liquidityRisk;
        uint256 marketRisk;
        uint256 concentrationRisk;
        uint256 protocolRisk;
        uint256 operationalRisk;
        RiskLevel riskLevel;
        uint256 riskCapacity;
        uint256 riskTolerance;
        uint256 lastAssessment;
        uint256 assessmentCount;
        bool isHighRisk;
        bool requiresReview;
    }
    
    struct Position {
        bytes32 positionId;
        address user;
        address asset;
        uint256 amount;
        uint256 value;
        PositionType positionType;
        uint256 leverage;
        uint256 collateralRatio;
        uint256 liquidationThreshold;
        uint256 riskScore;
        uint256 healthFactor;
        uint256 createdAt;
        uint256 lastUpdate;
        bool isActive;
        bool isLiquidatable;
    }
    
    struct RiskMetrics {
        uint256 valueAtRisk;
        uint256 expectedShortfall;
        uint256 maxDrawdown;
        uint256 sharpeRatio;
        uint256 volatility;
        uint256 beta;
        uint256 correlation;
        uint256 diversificationRatio;
        uint256 concentrationIndex;
        uint256 liquidityScore;
        uint256 lastCalculation;
    }
    
    struct LiquidationInfo {
        bytes32 liquidationId;
        address user;
        address collateralToken;
        address debtToken;
        uint256 collateralAmount;
        uint256 debtAmount;
        uint256 liquidationPrice;
        uint256 liquidationRatio;
        uint256 penalty;
        uint256 bonus;
        LiquidationStatus status;
        uint256 createdAt;
        uint256 executedAt;
        address liquidator;
    }
    
    struct RiskParameters {
        uint256 maxLeverage;
        uint256 minCollateralRatio;
        uint256 liquidationThreshold;
        uint256 liquidationPenalty;
        uint256 liquidationBonus;
        uint256 maxConcentration;
        uint256 maxPositionSize;
        uint256 riskFreeRate;
        uint256 volatilityThreshold;
        uint256 correlationThreshold;
        uint256 lastUpdate;
    }
    
    struct StressTestScenario {
        bytes32 scenarioId;
        string name;
        string description;
        uint256 marketShock;
        uint256 liquidityShock;
        uint256 volatilityIncrease;
        uint256 correlationIncrease;
        uint256 duration;
        uint256 probability;
        bool isActive;
    }
    
    struct StressTestResult {
        bytes32 testId;
        bytes32 scenarioId;
        address user;
        uint256 initialValue;
        uint256 stressedValue;
        uint256 loss;
        uint256 lossPercentage;
        bool passedTest;
        uint256 executedAt;
    }
    
    struct RiskAlert {
        bytes32 alertId;
        address user;
        AlertType alertType;
        AlertSeverity severity;
        string message;
        uint256 threshold;
        uint256 currentValue;
        bool isActive;
        bool isAcknowledged;
        uint256 createdAt;
        uint256 acknowledgedAt;
    }
    
    struct RiskMitigation {
        bytes32 mitigationId;
        address user;
        MitigationType mitigationType;
        string description;
        uint256 targetRiskReduction;
        uint256 actualRiskReduction;
        uint256 cost;
        MitigationStatus status;
        uint256 createdAt;
        uint256 executedAt;
        uint256 expiresAt;
    }

    // Enums
    enum RiskLevel {
        VERY_LOW,
        LOW,
        MEDIUM,
        HIGH,
        VERY_HIGH,
        CRITICAL
    }
    
    enum PositionType {
        LONG,
        SHORT,
        LEVERAGED_LONG,
        LEVERAGED_SHORT,
        COLLATERALIZED,
        DERIVATIVE
    }
    
    enum LiquidationStatus {
        PENDING,
        PARTIAL,
        COMPLETE,
        FAILED,
        CANCELLED
    }
    
    enum AlertType {
        RISK_LIMIT_EXCEEDED,
        LIQUIDATION_WARNING,
        CONCENTRATION_RISK,
        MARKET_VOLATILITY,
        LIQUIDITY_SHORTAGE,
        PROTOCOL_RISK,
        CORRELATION_SPIKE
    }
    
    enum AlertSeverity {
        INFO,
        WARNING,
        CRITICAL,
        EMERGENCY
    }
    
    enum MitigationType {
        POSITION_REDUCTION,
        DIVERSIFICATION,
        HEDGING,
        COLLATERAL_INCREASE,
        LEVERAGE_REDUCTION,
        STOP_LOSS,
        REBALANCING
    }
    
    enum MitigationStatus {
        PROPOSED,
        APPROVED,
        EXECUTING,
        COMPLETED,
        FAILED,
        CANCELLED
    }

    // Core risk assessment functions
    function assessUserRisk(
        address user
    ) external returns (RiskProfile memory riskProfile);
    
    function assessPositionRisk(
        bytes32 positionId
    ) external returns (uint256 riskScore, uint256 healthFactor);
    
    function calculatePortfolioRisk(
        address user
    ) external view returns (RiskMetrics memory metrics);
    
    function updateRiskProfile(
        address user
    ) external returns (RiskProfile memory updatedProfile);
    
    function validateRiskLimits(
        address user,
        bytes32 positionId,
        uint256 additionalAmount
    ) external view returns (bool isValid, string memory reason);
    
    function checkLiquidationEligibility(
        address user,
        bytes32 positionId
    ) external view returns (bool isEligible, uint256 liquidationAmount);
    
    // Position management
    function registerPosition(
        address user,
        address asset,
        uint256 amount,
        PositionType positionType,
        uint256 leverage
    ) external returns (bytes32 positionId);
    
    function updatePosition(
        bytes32 positionId,
        uint256 newAmount,
        uint256 newLeverage
    ) external;
    
    function closePosition(
        bytes32 positionId
    ) external;
    
    function rebalancePosition(
        bytes32 positionId,
        uint256 targetRiskScore
    ) external returns (uint256 newRiskScore);
    
    function liquidatePosition(
        bytes32 positionId,
        uint256 liquidationAmount
    ) external returns (uint256 liquidatedValue);
    
    // Liquidation functions
    function initiateLiquidation(
        address user,
        address collateralToken,
        uint256 debtAmount
    ) external returns (bytes32 liquidationId);
    
    function executeLiquidation(
        bytes32 liquidationId
    ) external returns (uint256 liquidatedAmount, uint256 debtCovered);
    
    function calculateLiquidationAmount(
        address user,
        address collateralToken,
        uint256 debtAmount
    ) external view returns (uint256 liquidationAmount, uint256 penalty);
    
    function getLiquidationPrice(
        address collateralToken,
        address debtToken,
        uint256 collateralAmount,
        uint256 debtAmount
    ) external view returns (uint256 liquidationPrice);
    
    function cancelLiquidation(
        bytes32 liquidationId
    ) external;
    
    // Stress testing
    function createStressTestScenario(
        string calldata name,
        string calldata description,
        uint256 marketShock,
        uint256 liquidityShock,
        uint256 volatilityIncrease
    ) external returns (bytes32 scenarioId);
    
    function executeStressTest(
        address user,
        bytes32 scenarioId
    ) external returns (StressTestResult memory result);
    
    function runPortfolioStressTest(
        address user,
        bytes32[] calldata scenarioIds
    ) external returns (StressTestResult[] memory results);
    
    function runSystemWideStressTest(
        bytes32 scenarioId
    ) external returns (uint256 systemRisk, uint256 failureRate);
    
    function updateStressTestScenario(
        bytes32 scenarioId,
        uint256 marketShock,
        uint256 liquidityShock,
        uint256 volatilityIncrease
    ) external;
    
    // Risk mitigation
    function proposeMitigation(
        address user,
        MitigationType mitigationType,
        string calldata description,
        uint256 targetRiskReduction
    ) external returns (bytes32 mitigationId);
    
    function executeMitigation(
        bytes32 mitigationId
    ) external returns (uint256 actualRiskReduction);
    
    function autoMitigateRisk(
        address user,
        uint256 targetRiskLevel
    ) external returns (bytes32[] memory mitigationIds);
    
    function calculateMitigationCost(
        address user,
        MitigationType mitigationType,
        uint256 targetRiskReduction
    ) external view returns (uint256 cost, uint256 effectiveness);
    
    function approveMitigation(
        bytes32 mitigationId
    ) external;
    
    function cancelMitigation(
        bytes32 mitigationId
    ) external;
    
    // Alert system
    function createRiskAlert(
        address user,
        AlertType alertType,
        AlertSeverity severity,
        string calldata message,
        uint256 threshold
    ) external returns (bytes32 alertId);
    
    function acknowledgeAlert(
        bytes32 alertId
    ) external;
    
    function resolveAlert(
        bytes32 alertId
    ) external;
    
    function getActiveAlerts(
        address user
    ) external view returns (RiskAlert[] memory alerts);
    
    function getCriticalAlerts() external view returns (RiskAlert[] memory alerts);
    
    // Risk parameter management
    function setRiskParameters(
        uint256 maxLeverage,
        uint256 minCollateralRatio,
        uint256 liquidationThreshold,
        uint256 liquidationPenalty,
        uint256 maxConcentration
    ) external;
    
    function updateLeverageLimit(
        uint256 newMaxLeverage
    ) external;
    
    function updateCollateralRequirements(
        uint256 newMinCollateralRatio,
        uint256 newLiquidationThreshold
    ) external;
    
    function updateLiquidationParameters(
        uint256 newPenalty,
        uint256 newBonus
    ) external;
    
    function setConcentrationLimits(
        uint256 maxConcentration,
        uint256 maxPositionSize
    ) external;
    
    function updateRiskModel(
        string calldata modelName,
        uint256 version
    ) external;
    
    // Emergency functions
    function emergencyPause() external;
    
    function emergencyUnpause() external;
    
    function emergencyLiquidateUser(
        address user,
        string calldata reason
    ) external;
    
    function emergencyReducePosition(
        bytes32 positionId,
        uint256 reductionPercentage
    ) external;
    
    function emergencyStopTrading(
        address user
    ) external;
    
    function emergencyWithdrawCollateral(
        address user,
        address token,
        uint256 amount
    ) external;
    
    // View functions - Risk profiles
    function getRiskProfile(
        address user
    ) external view returns (RiskProfile memory);
    
    function getUserRiskScore(
        address user
    ) external view returns (uint256 riskScore, RiskLevel riskLevel);
    
    function getUserRiskCapacity(
        address user
    ) external view returns (uint256 capacity, uint256 utilized);
    
    function isHighRiskUser(
        address user
    ) external view returns (bool);
    
    function getUsersRequiringReview() external view returns (address[] memory);
    
    // View functions - Positions
    function getPosition(
        bytes32 positionId
    ) external view returns (Position memory);
    
    function getUserPositions(
        address user
    ) external view returns (bytes32[] memory);
    
    function getPositionHealthFactor(
        bytes32 positionId
    ) external view returns (uint256 healthFactor);
    
    function getLiquidatablePositions() external view returns (bytes32[] memory);
    
    function getPositionValue(
        bytes32 positionId
    ) external view returns (uint256 currentValue, uint256 collateralValue);
    
    // View functions - Risk metrics
    function getPortfolioMetrics(
        address user
    ) external view returns (RiskMetrics memory);
    
    function getSystemRiskMetrics() external view returns (RiskMetrics memory);
    
    function calculateVaR(
        address user,
        uint256 confidenceLevel,
        uint256 timeHorizon
    ) external view returns (uint256 valueAtRisk);
    
    function calculateExpectedShortfall(
        address user,
        uint256 confidenceLevel
    ) external view returns (uint256 expectedShortfall);
    
    function getCorrelationMatrix(
        address[] calldata assets
    ) external view returns (uint256[][] memory correlations);
    
    // View functions - Liquidations
    function getLiquidationInfo(
        bytes32 liquidationId
    ) external view returns (LiquidationInfo memory);
    
    function getPendingLiquidations() external view returns (bytes32[] memory);
    
    function getUserLiquidations(
        address user
    ) external view returns (bytes32[] memory);
    
    function getLiquidationHistory(
        address user,
        uint256 fromTimestamp,
        uint256 toTimestamp
    ) external view returns (LiquidationInfo[] memory);
    
    function canLiquidate(
        address user,
        bytes32 positionId
    ) external view returns (bool);
    
    // View functions - Stress testing
    function getStressTestScenario(
        bytes32 scenarioId
    ) external view returns (StressTestScenario memory);
    
    function getStressTestResult(
        bytes32 testId
    ) external view returns (StressTestResult memory);
    
    function getStressTestHistory(
        address user
    ) external view returns (StressTestResult[] memory);
    
    function getActiveScenarios() external view returns (bytes32[] memory);
    
    function getSystemStressTestResults() external view returns (
        uint256 averageRisk,
        uint256 maxRisk,
        uint256 failureRate
    );
    
    // View functions - Risk mitigation
    function getMitigation(
        bytes32 mitigationId
    ) external view returns (RiskMitigation memory);
    
    function getUserMitigations(
        address user
    ) external view returns (bytes32[] memory);
    
    function getPendingMitigations(
        address user
    ) external view returns (bytes32[] memory);
    
    function getMitigationEffectiveness(
        bytes32 mitigationId
    ) external view returns (uint256 effectiveness, uint256 cost);
    
    function getOptimalMitigation(
        address user,
        uint256 targetRiskReduction
    ) external view returns (MitigationType mitigationType, uint256 cost);
    
    // View functions - Alerts
    function getAlert(
        bytes32 alertId
    ) external view returns (RiskAlert memory);
    
    function getUserAlerts(
        address user
    ) external view returns (RiskAlert[] memory);
    
    function getUnacknowledgedAlerts(
        address user
    ) external view returns (RiskAlert[] memory);
    
    function getSystemAlerts() external view returns (RiskAlert[] memory);
    
    function getAlertsByType(
        AlertType alertType
    ) external view returns (RiskAlert[] memory);
    
    // View functions - Risk parameters
    function getRiskParameters() external view returns (RiskParameters memory);
    
    function getMaxLeverage() external view returns (uint256);
    
    function getMinCollateralRatio() external view returns (uint256);
    
    function getLiquidationThreshold() external view returns (uint256);
    
    function getLiquidationPenalty() external view returns (uint256);
    
    function getConcentrationLimits() external view returns (
        uint256 maxConcentration,
        uint256 maxPositionSize
    );
    
    // View functions - System health
    function isSystemHealthy() external view returns (bool);
    
    function getSystemHealth() external view returns (
        bool isHealthy,
        uint256 overallRisk,
        uint256 liquidityRisk,
        uint256 concentrationRisk
    );
    
    function getRiskDistribution() external view returns (
        uint256 veryLowRisk,
        uint256 lowRisk,
        uint256 mediumRisk,
        uint256 highRisk,
        uint256 veryHighRisk,
        uint256 criticalRisk
    );
    
    function getSystemUtilization() external view returns (
        uint256 totalPositions,
        uint256 totalValue,
        uint256 averageLeverage,
        uint256 averageCollateralRatio
    );
}
