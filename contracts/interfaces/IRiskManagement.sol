// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IRiskManagement
 * @dev Interface for the Risk Management contract
 * @author CoreLiquid Protocol
 */
interface IRiskManagement {
    // Events
    event RiskAssessmentCompleted(
        bytes32 indexed assessmentId,
        address indexed subject,
        RiskType riskType,
        uint256 riskScore,
        RiskLevel riskLevel,
        uint256 timestamp
    );
    
    event RiskThresholdExceeded(
        bytes32 indexed alertId,
        address indexed subject,
        RiskType riskType,
        uint256 currentRisk,
        uint256 threshold,
        uint256 timestamp
    );
    
    event RiskMitigationExecuted(
        bytes32 indexed mitigationId,
        address indexed subject,
        MitigationType mitigationType,
        uint256 riskReduction,
        uint256 timestamp
    );
    
    event RiskParametersUpdated(
        RiskType riskType,
        uint256[] oldParameters,
        uint256[] newParameters,
        uint256 timestamp
    );
    
    event CollateralLiquidated(
        bytes32 indexed liquidationId,
        address indexed user,
        address indexed asset,
        uint256 amount,
        uint256 liquidationPrice,
        uint256 timestamp
    );
    
    event PositionLimitUpdated(
        address indexed user,
        address indexed asset,
        uint256 oldLimit,
        uint256 newLimit,
        uint256 timestamp
    );
    
    event EmergencyActionTriggered(
        bytes32 indexed actionId,
        EmergencyActionType actionType,
        address indexed target,
        string reason,
        uint256 timestamp
    );
    
    event RiskModelUpdated(
        bytes32 indexed modelId,
        string modelName,
        uint256 version,
        uint256 timestamp
    );
    
    event StressTestCompleted(
        bytes32 indexed testId,
        StressTestType testType,
        uint256 scenarioCount,
        uint256 failureRate,
        uint256 timestamp
    );
    
    event VaRCalculated(
        bytes32 indexed calculationId,
        address indexed portfolio,
        uint256 valueAtRisk,
        uint256 confidence,
        uint256 timeHorizon,
        uint256 timestamp
    );
    
    event ExposureUpdated(
        address indexed user,
        address indexed asset,
        uint256 amount,
        ExposureType exposureType,
        uint256 timestamp
    );
    
    event RiskLimitSet(
        address indexed user,
        address indexed asset,
        uint256 maxExposure,
        uint256 maxLeverage,
        uint256 timestamp
    );
    
    event CollateralRiskUpdated(
        address indexed asset,
        uint256 liquidationThreshold,
        uint256 liquidationBonus,
        uint256 riskWeight,
        uint256 timestamp
    );
    
    event PortfolioRiskCalculated(
        address indexed user,
        uint256 overallRiskScore,
        uint256 timestamp
    );
    
    event RiskAlertResolved(
        address indexed user,
        address indexed resolvedBy,
        uint256 timestamp
    );
    
    event EmergencyLiquidation(
        address indexed user,
        uint256 timestamp
    );
    
    event EmergencyModeEnabled(
        uint256 timestamp
    );
    
    event EmergencyModeDisabled(
        uint256 timestamp
    );
    
    event RiskConfigUpdated(
        uint256 timestamp
    );
    
    event RiskAlertCreated(
        address indexed user,
        string message,
        AlertSeverity severity,
        uint256 timestamp
    );
    
    event RiskAssessed(
        address indexed user,
        address indexed asset,
        uint256 amount,
        uint256 riskScore,
        RiskType riskType,
        uint256 timestamp
    );
    
    event HealthFactorCalculated(
        address indexed user,
        uint256 healthFactor,
        uint256 timestamp
    );
    
    event PositionLiquidated(
        address indexed user,
        address indexed liquidator,
        address indexed collateralAsset,
        address debtAsset,
        uint256 debtCovered,
        uint256 collateralLiquidated,
        uint256 liquidationBonus,
        uint256 timestamp
    );

    // Structs
    struct RiskAssessment {
        bytes32 assessmentId;
        address subject;
        RiskType riskType;
        uint256 riskScore;
        RiskLevel riskLevel;
        uint256 confidence;
        uint256 timestamp;
        uint256 expiresAt;
        RiskFactors factors;
        RiskMetrics metrics;
        string[] recommendations;
        bool isValid;
    }
    
    struct RiskFactors {
        uint256 creditRisk;
        uint256 liquidityRisk;
        uint256 marketRisk;
        uint256 operationalRisk;
        uint256 counterpartyRisk;
        uint256 concentrationRisk;
        uint256 volatilityRisk;
        uint256 correlationRisk;
        uint256 systemicRisk;
        uint256 regulatoryRisk;
    }
    
    struct RiskMetrics {
        uint256 valueAtRisk; // VaR at 95% confidence
        uint256 conditionalVaR; // Expected Shortfall
        uint256 maxDrawdown;
        uint256 sharpeRatio;
        uint256 beta;
        uint256 alpha;
        uint256 volatility;
        uint256 correlation;
        uint256 trackingError;
        uint256 informationRatio;
    }
    
    struct HealthFactor {
        address user;
        uint256 currentHealthFactor;
        uint256 lastUpdate;
        bool isHealthy;
        uint256 liquidationThreshold;
        uint256 warningThreshold;
        uint256 criticalThreshold;
        uint256 historicalLow;
        uint256 historicalHigh;
        uint256 averageHealthFactor;
    }
    
    struct LiquidationData {
        address user;
        address liquidator;
        address collateralAsset;
        address debtAsset;
        uint256 debtCovered;
        uint256 collateralLiquidated;
        uint256 liquidationBonus;
        uint256 timestamp;
        uint256 healthFactorBefore;
        uint256 healthFactorAfter;
        bool isCompleted;
        uint256 liquidationId;
    }
    
    struct ExposureData {
        address user;
        address asset;
        uint256 longExposure;
        uint256 shortExposure;
        uint256 netExposure;
        uint256 totalExposure;
        uint256 exposureRatio;
        uint256 lastUpdate;
        ExposureType exposureType;
        bool isActive;
        uint256 maxExposure;
        uint256 warningThreshold;
    }
    
    struct RiskProfile {
        address user;
        uint256 overallRiskScore;
        RiskLevel riskTolerance;
        uint256 maxPositionSize;
        uint256 maxLeverage;
        uint256 maxConcentration;
        uint256 liquidityRequirement;
        bool isHighRisk;
        uint256 lastAssessment;
        RiskLimits limits;
        RiskPreferences preferences;
    }
    
    struct RiskLimits {
        uint256 maxDailyLoss;
        uint256 maxWeeklyLoss;
        uint256 maxMonthlyLoss;
        uint256 maxPortfolioRisk;
        uint256 maxSingleAssetExposure;
        uint256 maxCorrelatedExposure;
        uint256 minLiquidityRatio;
        uint256 maxLeverageRatio;
        uint256 stopLossThreshold;
        uint256 marginCallThreshold;
    }
    
    struct RiskPreferences {
        bool autoLiquidation;
        bool riskAlerts;
        bool autoRebalancing;
        uint256 alertThreshold;
        uint256 rebalanceThreshold;
        bool emergencyMode;
        uint256 riskBudget;
        RiskStrategy strategy;
    }
    
    struct PortfolioRisk {
        address portfolio;
        uint256 totalValue;
        uint256 totalRisk;
        uint256 diversificationRatio;
        uint256 concentrationIndex;
        uint256 liquidityScore;
        uint256 volatilityScore;
        AssetRisk[] assetRisks;
        CorrelationMatrix correlations;
        uint256 lastUpdate;
    }
    
    struct AssetRisk {
        address asset;
        uint256 exposure;
        uint256 weight;
        uint256 riskContribution;
        uint256 volatility;
        uint256 beta;
        uint256 liquidityRisk;
        uint256 creditRisk;
        uint256 marginRequirement;
        bool isHighRisk;
    }
    
    struct CorrelationMatrix {
        address[] assets;
        uint256[][] correlations; // Correlation coefficients * 10000
        uint256 lastUpdate;
        uint256 confidence;
    }
    
    struct LiquidationEvent {
        bytes32 liquidationId;
        address user;
        address asset;
        uint256 amount;
        uint256 liquidationPrice;
        uint256 marketPrice;
        uint256 slippage;
        uint256 penalty;
        uint256 timestamp;
        LiquidationReason reason;
        bool isPartial;
        uint256 remainingCollateral;
    }
    
    struct StressTest {
        bytes32 testId;
        string name;
        StressTestType testType;
        StressScenario[] scenarios;
        uint256 createdAt;
        uint256 lastRun;
        StressTestResults results;
        bool isActive;
    }
    
    struct StressScenario {
        string name;
        ScenarioType scenarioType;
        uint256 severity; // 1-10 scale
        uint256 probability; // Basis points
        MarketShock[] shocks;
        uint256 duration;
        string description;
    }
    
    struct MarketShock {
        address asset;
        int256 priceChange; // Percentage change (can be negative)
        uint256 volatilityMultiplier;
        uint256 liquidityReduction;
        uint256 correlationIncrease;
    }
    
    struct StressTestResults {
        uint256 totalScenarios;
        uint256 failedScenarios;
        uint256 averageLoss;
        uint256 maxLoss;
        uint256 worstCaseVaR;
        uint256 expectedShortfall;
        uint256 liquidityGap;
        uint256 capitalAdequacy;
        ScenarioResult[] scenarioResults;
    }
    
    struct CollateralData {
        address asset;
        uint256 liquidationThreshold;
        uint256 liquidationBonus;
        uint256 riskWeight;
        uint256 lastUpdate;
        bool isActive;
        uint256 totalDeposited;
        uint256 totalLocked;
        uint256 utilizationRate;
        uint256 maxUtilization;
    }
    
    struct RiskConfig {
        uint256 maxLeverage;
        uint256 liquidationThreshold;
        uint256 healthFactorThreshold;
        uint256 maxExposureRatio;
        uint256 riskFreeRate;
        uint256 volatilityThreshold;
        uint256 correlationThreshold;
        uint256 stressTestFrequency;
        bool isActive;
    }

    struct RiskLimit {
        address asset;
        address user;
        RiskType riskType;
        uint256 maxExposure;
        uint256 maxLeverage;
        uint256 currentValue;
        bool isActive;
        bool isBreached;
        uint256 breachCount;
        uint256 lastBreach;
        uint256 createdAt;
        uint256 updatedAt;
    }

    struct StressTestScenario {
        string name;
        ScenarioType scenarioType;
        uint256 severity;
        uint256 maxAcceptableDrawdown;
        uint256 duration;
        uint256 probability;
        string description;
        bool isActive;
    }
    
    struct StressTestResult {
        bytes32 testId;
        address user;
        StressTestScenario scenario;
        uint256 timestamp;
        uint256 portfolioValueBefore;
        uint256 portfolioValueAfter;
        uint256 maxDrawdown;
        RiskMetrics riskMetrics;
        bool passed;
        uint256 executedAt;
        uint256 duration;
        string[] recommendations;
    }
    
    struct ScenarioResult {
        string scenarioName;
        uint256 portfolioLoss;
        uint256 liquidityImpact;
        uint256 marginCall;
        bool requiresLiquidation;
        uint256 recoveryTime;
        string impact;
    }
    
    struct RiskModel {
        bytes32 modelId;
        string name;
        ModelType modelType;
        uint256 version;
        uint256[] parameters;
        uint256 accuracy;
        uint256 lastCalibration;
        bool isActive;
        ModelConfig config;
    }
    
    struct ModelConfig {
        uint256 lookbackPeriod;
        uint256 confidenceLevel;
        uint256 decayFactor;
        bool useVolatilityClustering;
        bool useJumpDiffusion;
        uint256 calibrationFrequency;
        uint256 validationThreshold;
    }
    
    struct RiskAlert {
        bytes32 alertId;
        address subject;
        AlertType alertType;
        RiskType riskType;
        uint256 currentValue;
        uint256 threshold;
        uint256 severity;
        uint256 timestamp;
        bool isAcknowledged;
        bool isResolved;
        string message;
        string[] actions;
    }
    
    struct EmergencyAction {
        bytes32 actionId;
        EmergencyActionType actionType;
        address target;
        uint256 timestamp;
        string reason;
        uint256 impact;
        bool isExecuted;
        bool isReversible;
        uint256 expiresAt;
        bytes actionData;
    }

    // Enums
    enum RiskType {
        CREDIT_RISK,
        MARKET_RISK,
        LIQUIDITY_RISK,
        OPERATIONAL_RISK,
        COUNTERPARTY_RISK,
        CONCENTRATION_RISK,
        SYSTEMIC_RISK,
        REGULATORY_RISK
    }
    
    enum RiskLevel {
        VERY_LOW,
        LOW,
        MEDIUM,
        HIGH,
        VERY_HIGH,
        CRITICAL
    }
    
    enum MitigationType {
        POSITION_REDUCTION,
        HEDGING,
        DIVERSIFICATION,
        LIQUIDATION,
        MARGIN_INCREASE,
        EXPOSURE_LIMIT,
        CIRCUIT_BREAKER
    }
    
    enum LiquidationReason {
        MARGIN_CALL,
        STOP_LOSS,
        RISK_LIMIT,
        EMERGENCY,
        REGULATORY,
        VOLUNTARY
    }
    
    enum StressTestType {
        HISTORICAL,
        MONTE_CARLO,
        SCENARIO_BASED,
        REGULATORY,
        CUSTOM
    }
    
    enum ScenarioType {
        MARKET_CRASH,
        LIQUIDITY_CRISIS,
        INTEREST_RATE_SHOCK,
        CREDIT_EVENT,
        OPERATIONAL_FAILURE,
        REGULATORY_CHANGE,
        BLACK_SWAN
    }
    
    enum ModelType {
        PARAMETRIC,
        HISTORICAL_SIMULATION,
        MONTE_CARLO,
        MACHINE_LEARNING,
        HYBRID
    }
    
    enum AlertType {
        THRESHOLD_BREACH,
        TREND_ALERT,
        ANOMALY_DETECTION,
        CORRELATION_BREAK,
        LIQUIDITY_WARNING,
        MARGIN_ALERT
    }
    
    enum EmergencyActionType {
        PAUSE_TRADING,
        FORCE_LIQUIDATION,
        CIRCUIT_BREAKER,
        MARGIN_INCREASE,
        POSITION_FREEZE,
        SYSTEM_SHUTDOWN
    }
    
    enum RiskStrategy {
        CONSERVATIVE,
        MODERATE,
        AGGRESSIVE,
        DYNAMIC,
        CUSTOM
    }
    
    enum ExposureType {
        LONG,
        SHORT,
        NET,
        GROSS,
        DELTA,
        GAMMA,
        VEGA,
        THETA
    }
    
    enum AlertSeverity {
        INFO,
        WARNING,
        CRITICAL,
        EMERGENCY
    }
    
    struct SystemRiskMetrics {
        uint256 totalUsers;
        uint256 highRiskUsers;
        uint256 liquidatablePositions;
        uint256 totalRiskAssessments;
        uint256 totalLiquidations;
        uint256 totalStressTests;
        uint256 averageRiskScore;
        uint256 systemHealthFactor;
    }

    // Core risk assessment functions
    function assessRisk(
        address subject,
        RiskType riskType
    ) external returns (RiskAssessment memory assessment);
    
    function calculatePortfolioRisk(
        address portfolio
    ) external returns (PortfolioRisk memory risk);
    
    function updateRiskProfile(
        address user,
        RiskProfile calldata profile
    ) external;
    
    function performStressTest(
        bytes32 testId,
        address portfolio
    ) external returns (StressTestResults memory results);
    
    function calculateVaR(
        address portfolio,
        uint256 confidence,
        uint256 timeHorizon
    ) external returns (uint256 valueAtRisk);
    
    // Advanced risk functions
    function calculateConditionalVaR(
        address portfolio,
        uint256 confidence,
        uint256 timeHorizon
    ) external returns (uint256 conditionalVaR);
    
    function assessConcentrationRisk(
        address portfolio
    ) external returns (uint256 concentrationIndex);
    
    function calculateLiquidityRisk(
        address portfolio
    ) external returns (uint256 liquidityScore);
    
    function assessCounterpartyRisk(
        address counterparty
    ) external returns (uint256 riskScore);
    
    function calculateCorrelationRisk(
        address[] calldata assets,
        uint256 timeWindow
    ) external returns (CorrelationMatrix memory matrix);
    
    // Risk monitoring functions
    function monitorRiskLimits(
        address user
    ) external returns (bool withinLimits, RiskAlert[] memory alerts);
    
    function checkMarginRequirements(
        address user
    ) external returns (bool adequate, uint256 marginCall);
    
    function detectRiskAnomalies(
        address subject,
        uint256 lookbackPeriod
    ) external returns (RiskAlert[] memory anomalies);
    
    function validateRiskModel(
        bytes32 modelId,
        uint256 testPeriod
    ) external returns (uint256 accuracy, bool isValid);
    
    function backtestRiskModel(
        bytes32 modelId,
        uint256 startTime,
        uint256 endTime
    ) external returns (uint256 accuracy, uint256[] memory errors);
    
    // Risk mitigation functions
    function executeMitigation(
        address subject,
        MitigationType mitigationType,
        uint256 amount
    ) external returns (bytes32 mitigationId);
    
    function liquidatePosition(
        address user,
        address asset,
        uint256 amount,
        LiquidationReason reason
    ) external returns (bytes32 liquidationId);
    
    function hedgePosition(
        address user,
        address asset,
        uint256 amount,
        address hedgeInstrument
    ) external returns (bool success);
    
    function rebalancePortfolio(
        address portfolio,
        uint256[] calldata targetWeights
    ) external returns (bool success);
    
    function implementCircuitBreaker(
        address asset,
        uint256 duration
    ) external;
    
    // Emergency functions
    function triggerEmergencyAction(
        EmergencyActionType actionType,
        address target,
        string calldata reason
    ) external returns (bytes32 actionId);
    
    function pauseRiskAssessment(
        RiskType riskType
    ) external;
    
    function resumeRiskAssessment(
        RiskType riskType
    ) external;
    
    function emergencyLiquidation(
        address user
    ) external returns (uint256 totalLiquidated);
    
    function systemShutdown(
        string calldata reason
    ) external;
    
    // Configuration functions
    function setRiskParameters(
        RiskType riskType,
        uint256[] calldata parameters
    ) external;
    
    function updateRiskModel(
        bytes32 modelId,
        uint256[] calldata newParameters
    ) external;
    
    function setRiskThresholds(
        address user,
        RiskLimits calldata limits
    ) external;
    
    function setGlobalRiskLimits(
        RiskLimits calldata limits
    ) external;
    
    function calibrateRiskModel(
        bytes32 modelId
    ) external;
    
    // Stress testing functions
    function createStressTest(
        string calldata name,
        StressTestType testType,
        StressScenario[] calldata scenarios
    ) external returns (bytes32 testId);
    
    function runStressTest(
        bytes32 testId,
        address[] calldata portfolios
    ) external returns (StressTestResults[] memory results);
    
    function addStressScenario(
        bytes32 testId,
        StressScenario calldata scenario
    ) external;
    
    function updateStressScenario(
        bytes32 testId,
        uint256 scenarioIndex,
        StressScenario calldata scenario
    ) external;
    
    function simulateMarketShock(
        MarketShock[] calldata shocks,
        address portfolio
    ) external returns (uint256 portfolioImpact);
    
    // Alert management functions
    function createRiskAlert(
        address subject,
        AlertType alertType,
        RiskType riskType,
        uint256 threshold
    ) external returns (bytes32 alertId);
    
    function acknowledgeAlert(
        bytes32 alertId
    ) external;
    
    function resolveAlert(
        bytes32 alertId,
        string calldata resolution
    ) external;
    
    function updateAlertThreshold(
        bytes32 alertId,
        uint256 newThreshold
    ) external;
    
    function disableAlert(
        bytes32 alertId
    ) external;
    
    // View functions - Risk assessments
    function getRiskAssessment(
        bytes32 assessmentId
    ) external view returns (RiskAssessment memory);
    
    function getLatestRiskAssessment(
        address subject,
        RiskType riskType
    ) external view returns (RiskAssessment memory);
    
    function getRiskScore(
        address subject,
        RiskType riskType
    ) external view returns (uint256 score);
    
    function getRiskLevel(
        address subject
    ) external view returns (RiskLevel level);
    
    function isHighRisk(
        address subject
    ) external view returns (bool);
    
    // View functions - Risk profiles
    function getRiskProfile(
        address user
    ) external view returns (RiskProfile memory);
    
    function getRiskLimits(
        address user
    ) external view returns (RiskLimits memory);
    
    function getRiskPreferences(
        address user
    ) external view returns (RiskPreferences memory);
    
    function getMaxPositionSize(
        address user,
        address asset
    ) external view returns (uint256 maxSize);
    
    function getMaxLeverage(
        address user
    ) external view returns (uint256 maxLeverage);
    
    // View functions - Portfolio risk
    function getPortfolioRisk(
        address portfolio
    ) external view returns (PortfolioRisk memory);
    
    function getAssetRisk(
        address portfolio,
        address asset
    ) external view returns (AssetRisk memory);
    
    function getCorrelationMatrix(
        address[] calldata assets
    ) external view returns (CorrelationMatrix memory);
    
    function getDiversificationRatio(
        address portfolio
    ) external view returns (uint256 ratio);
    
    function getConcentrationIndex(
        address portfolio
    ) external view returns (uint256 index);
    
    // View functions - Risk metrics
    function getVaR(
        address portfolio,
        uint256 confidence
    ) external view returns (uint256 valueAtRisk);
    
    function getConditionalVaR(
        address portfolio,
        uint256 confidence
    ) external view returns (uint256 conditionalVaR);
    
    function getMaxDrawdown(
        address portfolio
    ) external view returns (uint256 maxDrawdown);
    
    function getSharpeRatio(
        address portfolio
    ) external view returns (uint256 sharpeRatio);
    
    function getBeta(
        address asset,
        address benchmark
    ) external view returns (uint256 beta);
    
    function getVolatility(
        address asset,
        uint256 timeWindow
    ) external view returns (uint256 volatility);
    
    // View functions - Stress tests
    function getStressTest(
        bytes32 testId
    ) external view returns (StressTest memory);
    
    function getStressTestResults(
        bytes32 testId
    ) external view returns (StressTestResults memory);
    
    function getAllStressTests() external view returns (bytes32[] memory);
    
    function getActiveStressTests() external view returns (bytes32[] memory);
    
    // View functions - Liquidations
    function getLiquidationEvent(
        bytes32 liquidationId
    ) external view returns (LiquidationEvent memory);
    
    function getUserLiquidations(
        address user
    ) external view returns (bytes32[] memory);
    
    function getRecentLiquidations(
        uint256 timeWindow
    ) external view returns (bytes32[] memory);
    
    function getTotalLiquidations() external view returns (uint256 total);
    
    function getLiquidationVolume(
        uint256 timeWindow
    ) external view returns (uint256 volume);
    
    // View functions - Alerts
    function getRiskAlert(
        bytes32 alertId
    ) external view returns (RiskAlert memory);
    
    function getUserAlerts(
        address user
    ) external view returns (bytes32[] memory);
    
    function getActiveAlerts() external view returns (bytes32[] memory);
    
    function getUnacknowledgedAlerts(
        address user
    ) external view returns (bytes32[] memory);
    
    function getAlertsByType(
        AlertType alertType
    ) external view returns (bytes32[] memory);
    
    // View functions - Models
    function getRiskModel(
        bytes32 modelId
    ) external view returns (RiskModel memory);
    
    function getAllRiskModels() external view returns (bytes32[] memory);
    
    function getActiveRiskModels() external view returns (bytes32[] memory);
    
    function getModelAccuracy(
        bytes32 modelId
    ) external view returns (uint256 accuracy);
    
    function getModelParameters(
        bytes32 modelId
    ) external view returns (uint256[] memory parameters);
    
    // View functions - System health
    function isSystemHealthy() external view returns (bool);
    
    function getSystemRiskLevel() external view returns (RiskLevel);
    
    function getSystemHealth() external view returns (
        bool isHealthy,
        uint256 overallRisk,
        uint256 liquidityHealth,
        uint256 capitalAdequacy
    );
    
    function getTotalRiskExposure() external view returns (uint256 exposure);
    
    function getAverageRiskScore() external view returns (uint256 averageScore);
    
    function getRiskDistribution() external view returns (
        uint256[] memory riskLevels,
        uint256[] memory counts
    );
}
