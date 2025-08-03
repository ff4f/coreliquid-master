// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IRiskManager
 * @dev Interface for the Risk Manager contract
 * @author CoreLiquid Protocol
 */
interface IRiskManager {
    // Events
    event RiskAssessmentCompleted(
        address indexed asset,
        address indexed user,
        RiskLevel riskLevel,
        uint256 riskScore,
        uint256 timestamp
    );
    
    event RiskLimitSet(
        address indexed asset,
        address indexed user,
        RiskType riskType,
        uint256 limit,
        uint256 timestamp
    );
    
    event RiskLimitExceeded(
        address indexed asset,
        address indexed user,
        RiskType riskType,
        uint256 currentValue,
        uint256 limit,
        uint256 timestamp
    );
    
    event RiskAlertTriggered(
        bytes32 indexed alertId,
        address indexed asset,
        address indexed user,
        AlertType alertType,
        AlertSeverity severity,
        string message,
        uint256 timestamp
    );
    
    event RiskModelUpdated(
        bytes32 indexed modelId,
        string modelName,
        uint256 version,
        address updatedBy,
        uint256 timestamp
    );
    
    event StressTestExecuted(
        bytes32 indexed testId,
        string scenario,
        uint256 portfolioValue,
        uint256 stressedValue,
        uint256 loss,
        uint256 timestamp
    );
    
    event VaRCalculated(
        address indexed portfolio,
        uint256 timeHorizon,
        uint256 confidenceLevel,
        uint256 varAmount,
        uint256 timestamp
    );
    
    event RiskParameterUpdated(
        bytes32 indexed parameterId,
        string parameterName,
        uint256 oldValue,
        uint256 newValue,
        address updatedBy,
        uint256 timestamp
    );
    
    event EmergencyRiskAction(
        address indexed asset,
        address indexed user,
        EmergencyActionType actionType,
        string reason,
        uint256 timestamp
    );
    
    event RiskReportGenerated(
        bytes32 indexed reportId,
        address indexed user,
        ReportType reportType,
        uint256 timestamp
    );

    // Structs
    struct RiskAssessment {
        address asset;
        address user;
        uint256 riskScore;
        RiskLevel riskLevel;
        uint256 volatility;
        uint256 liquidity;
        uint256 correlation;
        uint256 concentration;
        uint256 creditRisk;
        uint256 marketRisk;
        uint256 operationalRisk;
        uint256 assessmentTime;
        uint256 validUntil;
        RiskFactors factors;
        RiskMetrics metrics;
    }
    
    struct RiskFactors {
        uint256 priceVolatility;
        uint256 liquidityRisk;
        uint256 counterpartyRisk;
        uint256 concentrationRisk;
        uint256 correlationRisk;
        uint256 leverageRisk;
        uint256 durationRisk;
        uint256 currencyRisk;
        uint256 regulatoryRisk;
        uint256 technologyRisk;
    }
    
    struct RiskMetrics {
        uint256 valueAtRisk;
        uint256 conditionalVaR;
        uint256 expectedShortfall;
        uint256 maximumDrawdown;
        uint256 sharpeRatio;
        uint256 sortinoRatio;
        uint256 beta;
        uint256 alpha;
        uint256 trackingError;
        uint256 informationRatio;
    }
    
    struct RiskLimit {
        address asset;
        address user;
        RiskType riskType;
        uint256 limit;
        uint256 currentValue;
        bool isActive;
        bool isBreached;
        uint256 breachCount;
        uint256 lastBreach;
        uint256 createdAt;
        uint256 updatedAt;
        LimitConfig config;
    }
    
    struct LimitConfig {
        uint256 warningThreshold;
        uint256 breachThreshold;
        uint256 autoActionThreshold;
        bool autoEnforce;
        bool allowOverride;
        uint256 cooldownPeriod;
        address[] authorizedOverriders;
        EmergencyActionType autoAction;
    }
    
    struct RiskModel {
        bytes32 modelId;
        string name;
        string description;
        uint256 version;
        ModelType modelType;
        bool isActive;
        uint256 accuracy;
        uint256 lastCalibration;
        ModelParameters parameters;
        ModelMetrics metrics;
        address[] authorizedUsers;
    }
    
    struct ModelParameters {
        uint256 lookbackPeriod;
        uint256 confidenceLevel;
        uint256 decayFactor;
        uint256 correlationThreshold;
        uint256 volatilityAdjustment;
        uint256 liquidityAdjustment;
        uint256[] weights;
        uint256[] thresholds;
        bool useHistoricalData;
        bool useMonteCarloSimulation;
    }
    
    struct ModelMetrics {
        uint256 totalPredictions;
        uint256 accuratePredictions;
        uint256 falsePositives;
        uint256 falseNegatives;
        uint256 averageError;
        uint256 maxError;
        uint256 lastUpdate;
        uint256 calibrationFrequency;
    }
    
    struct StressTest {
        bytes32 testId;
        string name;
        string description;
        StressScenario scenario;
        uint256 portfolioValue;
        uint256 stressedValue;
        uint256 absoluteLoss;
        uint256 percentageLoss;
        uint256 executedAt;
        StressTestConfig config;
        StressTestResults results;
    }
    
    struct StressScenario {
        string name;
        ScenarioType scenarioType;
        uint256 severity;
        uint256 duration;
        mapping(address => uint256) assetShocks;
        mapping(string => uint256) marketShocks;
        bool includeCorrelationBreakdown;
        bool includeLiquidityStress;
    }
    
    struct StressTestConfig {
        uint256 shockMagnitude;
        uint256 correlationAdjustment;
        uint256 liquidityAdjustment;
        bool includeSecondOrderEffects;
        bool includeNonLinearEffects;
        uint256 timeHorizon;
        uint256 confidenceLevel;
    }
    
    struct StressTestResults {
        uint256 worstCaseLoss;
        uint256 expectedLoss;
        uint256 probabilityOfLoss;
        uint256 timeToRecovery;
        mapping(address => uint256) assetContributions;
        mapping(RiskType => uint256) riskContributions;
        string[] recommendations;
    }
    
    struct VaRCalculation {
        address portfolio;
        uint256 timeHorizon;
        uint256 confidenceLevel;
        uint256 varAmount;
        uint256 conditionalVaR;
        uint256 expectedShortfall;
        VaRMethod method;
        uint256 calculatedAt;
        VaRComponents components;
        bool isValid;
    }
    
    struct VaRComponents {
        uint256 marketRiskVaR;
        uint256 creditRiskVaR;
        uint256 operationalRiskVaR;
        uint256 liquidityRiskVaR;
        uint256 concentrationRiskVaR;
        uint256 correlationAdjustment;
        uint256 diversificationBenefit;
    }
    
    struct RiskAlert {
        bytes32 alertId;
        address asset;
        address user;
        AlertType alertType;
        AlertSeverity severity;
        string message;
        string description;
        uint256 triggeredAt;
        uint256 acknowledgedAt;
        uint256 resolvedAt;
        bool isActive;
        bool isAcknowledged;
        bool isResolved;
        AlertConfig config;
        address[] notifiedUsers;
    }
    
    struct AlertConfig {
        uint256 threshold;
        uint256 cooldownPeriod;
        bool autoResolve;
        uint256 autoResolveTime;
        bool requiresAcknowledgment;
        bool escalate;
        uint256 escalationTime;
        address[] escalationUsers;
    }
    
    struct RiskProfile {
        address user;
        RiskTolerance tolerance;
        uint256 maxLeverage;
        uint256 maxConcentration;
        uint256 maxVolatility;
        uint256 maxDrawdown;
        uint256 investmentHorizon;
        bool allowHighRiskAssets;
        bool allowLeveragedProducts;
        ProfileConfig config;
        ProfileMetrics metrics;
    }
    
    struct ProfileConfig {
        uint256 riskCapacity;
        uint256 liquidityNeeds;
        uint256 returnObjective;
        bool isInstitutional;
        bool isAccredited;
        string[] restrictions;
        string[] preferences;
    }
    
    struct ProfileMetrics {
        uint256 currentRiskLevel;
        uint256 portfolioVolatility;
        uint256 portfolioVaR;
        uint256 maxDrawdownExperienced;
        uint256 averageReturn;
        uint256 sharpeRatio;
        uint256 lastUpdate;
    }
    
    struct RiskReport {
        bytes32 reportId;
        address user;
        ReportType reportType;
        uint256 generatedAt;
        uint256 periodStart;
        uint256 periodEnd;
        ReportData data;
        string[] recommendations;
        bool isPublic;
    }
    
    struct ReportData {
        uint256 totalRiskScore;
        uint256 portfolioValue;
        uint256 portfolioVaR;
        uint256 maxDrawdown;
        uint256 volatility;
        RiskBreakdown breakdown;
        PerformanceMetrics performance;
        ComplianceStatus compliance;
    }
    
    struct RiskBreakdown {
        uint256 marketRisk;
        uint256 creditRisk;
        uint256 liquidityRisk;
        uint256 operationalRisk;
        uint256 concentrationRisk;
        uint256 correlationRisk;
        mapping(address => uint256) assetRisks;
    }
    
    struct PerformanceMetrics {
        uint256 totalReturn;
        uint256 volatility;
        uint256 sharpeRatio;
        uint256 maxDrawdown;
        uint256 calmarRatio;
        uint256 sortinoRatio;
        uint256 informationRatio;
    }
    
    struct ComplianceStatus {
        bool isCompliant;
        uint256 violationCount;
        string[] violations;
        string[] warnings;
        uint256 lastCheck;
    }

    // Enums
    enum RiskLevel {
        VERY_LOW,
        LOW,
        MEDIUM,
        HIGH,
        VERY_HIGH,
        EXTREME
    }
    
    enum RiskType {
        MARKET_RISK,
        CREDIT_RISK,
        LIQUIDITY_RISK,
        OPERATIONAL_RISK,
        CONCENTRATION_RISK,
        CORRELATION_RISK,
        LEVERAGE_RISK,
        DURATION_RISK,
        CURRENCY_RISK,
        REGULATORY_RISK
    }
    
    enum AlertType {
        RISK_LIMIT_BREACH,
        VAR_EXCEEDED,
        VOLATILITY_SPIKE,
        LIQUIDITY_SHORTAGE,
        CONCENTRATION_RISK,
        CORRELATION_BREAKDOWN,
        STRESS_TEST_FAILURE,
        MODEL_DEGRADATION,
        COMPLIANCE_VIOLATION,
        EMERGENCY_SITUATION
    }
    
    enum AlertSeverity {
        INFO,
        WARNING,
        CRITICAL,
        EMERGENCY
    }
    
    enum EmergencyActionType {
        FREEZE_TRADING,
        REDUCE_POSITION,
        LIQUIDATE_POSITION,
        HEDGE_POSITION,
        NOTIFY_ADMIN,
        PAUSE_STRATEGY,
        FORCE_REBALANCE,
        EMERGENCY_WITHDRAWAL
    }
    
    enum ModelType {
        PARAMETRIC,
        HISTORICAL_SIMULATION,
        MONTE_CARLO,
        MACHINE_LEARNING,
        HYBRID,
        CUSTOM
    }
    
    enum VaRMethod {
        PARAMETRIC,
        HISTORICAL,
        MONTE_CARLO,
        FILTERED_HISTORICAL,
        EXTREME_VALUE
    }
    
    enum ScenarioType {
        HISTORICAL,
        HYPOTHETICAL,
        REGULATORY,
        CUSTOM,
        MONTE_CARLO
    }
    
    enum RiskTolerance {
        CONSERVATIVE,
        MODERATE,
        AGGRESSIVE,
        VERY_AGGRESSIVE,
        CUSTOM
    }
    
    enum ReportType {
        DAILY_RISK,
        WEEKLY_RISK,
        MONTHLY_RISK,
        STRESS_TEST,
        VAR_REPORT,
        COMPLIANCE_REPORT,
        CUSTOM_REPORT
    }

    // Core risk assessment functions
    function assessRisk(
        address asset,
        address user,
        uint256 amount
    ) external returns (RiskAssessment memory);
    
    function calculatePortfolioRisk(
        address user
    ) external returns (uint256 riskScore, RiskLevel riskLevel);
    
    function updateRiskAssessment(
        address asset,
        address user
    ) external;
    
    function batchAssessRisk(
        address[] calldata assets,
        address user,
        uint256[] calldata amounts
    ) external returns (RiskAssessment[] memory);
    
    // Risk limit functions
    function setRiskLimit(
        address asset,
        address user,
        RiskType riskType,
        uint256 limit,
        LimitConfig calldata config
    ) external;
    
    function updateRiskLimit(
        address asset,
        address user,
        RiskType riskType,
        uint256 newLimit
    ) external;
    
    function removeRiskLimit(
        address asset,
        address user,
        RiskType riskType
    ) external;
    
    function checkRiskLimits(
        address user
    ) external returns (bool[] memory breached, RiskType[] memory types);
    
    function enforceRiskLimits(
        address user
    ) external;
    
    // VaR calculation functions
    function calculateVaR(
        address portfolio,
        uint256 timeHorizon,
        uint256 confidenceLevel,
        VaRMethod method
    ) external returns (VaRCalculation memory);
    
    function calculateConditionalVaR(
        address portfolio,
        uint256 timeHorizon,
        uint256 confidenceLevel
    ) external returns (uint256 cvar);
    
    function calculateExpectedShortfall(
        address portfolio,
        uint256 timeHorizon,
        uint256 confidenceLevel
    ) external returns (uint256 es);
    
    function updateVaRParameters(
        VaRMethod method,
        ModelParameters calldata parameters
    ) external;
    
    // Stress testing functions
    function executeStressTest(
        address portfolio,
        string calldata scenarioName,
        StressTestConfig calldata config
    ) external returns (bytes32 testId);
    
    function createStressScenario(
        string calldata name,
        ScenarioType scenarioType,
        address[] calldata assets,
        uint256[] calldata shocks
    ) external returns (bytes32 scenarioId);
    
    function runBatchStressTests(
        address portfolio,
        bytes32[] calldata scenarioIds
    ) external returns (bytes32[] memory testIds);
    
    function getStressTestResults(
        bytes32 testId
    ) external view returns (StressTest memory);
    
    // Risk model functions
    function createRiskModel(
        string calldata name,
        ModelType modelType,
        ModelParameters calldata parameters
    ) external returns (bytes32 modelId);
    
    function updateRiskModel(
        bytes32 modelId,
        ModelParameters calldata parameters
    ) external;
    
    function calibrateRiskModel(
        bytes32 modelId
    ) external;
    
    function activateRiskModel(
        bytes32 modelId
    ) external;
    
    function deactivateRiskModel(
        bytes32 modelId
    ) external;
    
    // Alert management functions
    function createRiskAlert(
        address asset,
        address user,
        AlertType alertType,
        AlertSeverity severity,
        string calldata message,
        AlertConfig calldata config
    ) external returns (bytes32 alertId);
    
    function acknowledgeAlert(
        bytes32 alertId
    ) external;
    
    function resolveAlert(
        bytes32 alertId,
        string calldata resolution
    ) external;
    
    function escalateAlert(
        bytes32 alertId
    ) external;
    
    function getActiveAlerts(
        address user
    ) external view returns (bytes32[] memory);
    
    // Risk profile functions
    function createRiskProfile(
        address user,
        RiskTolerance tolerance,
        ProfileConfig calldata config
    ) external;
    
    function updateRiskProfile(
        address user,
        ProfileConfig calldata config
    ) external;
    
    function assessProfileCompliance(
        address user
    ) external returns (bool isCompliant, string[] memory violations);
    
    function recommendPortfolioAdjustments(
        address user
    ) external view returns (string[] memory recommendations);
    
    // Emergency functions
    function triggerEmergencyAction(
        address asset,
        address user,
        EmergencyActionType actionType,
        string calldata reason
    ) external;
    
    function freezeUserTrading(
        address user,
        string calldata reason
    ) external;
    
    function unfreezeUserTrading(
        address user
    ) external;
    
    function emergencyLiquidation(
        address user,
        address[] calldata assets,
        uint256[] calldata amounts
    ) external;
    
    function pauseRiskSystem(
        string calldata reason
    ) external;
    
    function unpauseRiskSystem() external;
    
    // Reporting functions
    function generateRiskReport(
        address user,
        ReportType reportType,
        uint256 periodStart,
        uint256 periodEnd
    ) external returns (bytes32 reportId);
    
    function schedulePeriodicReport(
        address user,
        ReportType reportType,
        uint256 frequency
    ) external;
    
    function exportRiskData(
        address user,
        uint256 periodStart,
        uint256 periodEnd
    ) external view returns (bytes memory data);
    
    // Configuration functions
    function updateGlobalRiskParameters(
        string calldata parameterName,
        uint256 value
    ) external;
    
    function setRiskToleranceDefaults(
        RiskTolerance tolerance,
        ProfileConfig calldata defaults
    ) external;
    
    function updateModelWeights(
        bytes32 modelId,
        uint256[] calldata weights
    ) external;
    
    function setSystemRiskLimits(
        RiskType riskType,
        uint256 limit
    ) external;
    
    // View functions - Risk assessments
    function getRiskAssessment(
        address asset,
        address user
    ) external view returns (RiskAssessment memory);
    
    function getPortfolioRiskScore(
        address user
    ) external view returns (uint256 riskScore, RiskLevel riskLevel);
    
    function getRiskFactors(
        address asset,
        address user
    ) external view returns (RiskFactors memory);
    
    function getRiskMetrics(
        address user
    ) external view returns (RiskMetrics memory);
    
    function getAssetRiskRanking(
        address[] calldata assets
    ) external view returns (address[] memory rankedAssets, uint256[] memory scores);
    
    // View functions - Risk limits
    function getRiskLimit(
        address asset,
        address user,
        RiskType riskType
    ) external view returns (RiskLimit memory);
    
    function getAllRiskLimits(
        address user
    ) external view returns (RiskLimit[] memory);
    
    function getRiskLimitUtilization(
        address asset,
        address user,
        RiskType riskType
    ) external view returns (uint256 utilization);
    
    function isRiskLimitBreached(
        address asset,
        address user,
        RiskType riskType
    ) external view returns (bool breached);
    
    // View functions - VaR
    function getLatestVaR(
        address portfolio
    ) external view returns (VaRCalculation memory);
    
    function getVaRHistory(
        address portfolio,
        uint256 limit
    ) external view returns (VaRCalculation[] memory);
    
    function getVaRComponents(
        address portfolio
    ) external view returns (VaRComponents memory);
    
    // View functions - Stress tests
    function getStressTest(
        bytes32 testId
    ) external view returns (StressTest memory);
    
    function getStressTestHistory(
        address portfolio,
        uint256 limit
    ) external view returns (bytes32[] memory);
    
    function getAvailableScenarios() external view returns (bytes32[] memory);
    
    function getScenarioDetails(
        bytes32 scenarioId
    ) external view returns (StressScenario memory);
    
    // View functions - Models
    function getRiskModel(
        bytes32 modelId
    ) external view returns (RiskModel memory);
    
    function getAllRiskModels() external view returns (bytes32[] memory);
    
    function getActiveRiskModels() external view returns (bytes32[] memory);
    
    function getModelAccuracy(
        bytes32 modelId
    ) external view returns (uint256 accuracy);
    
    function getModelMetrics(
        bytes32 modelId
    ) external view returns (ModelMetrics memory);
    
    // View functions - Alerts
    function getRiskAlert(
        bytes32 alertId
    ) external view returns (RiskAlert memory);
    
    function getUserAlerts(
        address user,
        bool activeOnly
    ) external view returns (bytes32[] memory);
    
    function getSystemAlerts(
        AlertSeverity minSeverity
    ) external view returns (bytes32[] memory);
    
    function getAlertStatistics(
        uint256 timeframe
    ) external view returns (
        uint256 totalAlerts,
        uint256 criticalAlerts,
        uint256 resolvedAlerts,
        uint256 averageResolutionTime
    );
    
    // View functions - Profiles
    function getRiskProfile(
        address user
    ) external view returns (RiskProfile memory);
    
    function getProfileMetrics(
        address user
    ) external view returns (ProfileMetrics memory);
    
    function isProfileCompliant(
        address user
    ) external view returns (bool compliant);
    
    // View functions - Reports
    function getRiskReport(
        bytes32 reportId
    ) external view returns (RiskReport memory);
    
    function getUserReports(
        address user,
        ReportType reportType
    ) external view returns (bytes32[] memory);
    
    function getSystemRiskSummary() external view returns (
        uint256 totalUsers,
        uint256 averageRiskScore,
        uint256 highRiskUsers,
        uint256 activeAlerts,
        uint256 systemHealth
    );
    
    // View functions - Analytics
    function getRiskTrends(
        address user,
        uint256 timeframe
    ) external view returns (
        uint256[] memory timestamps,
        uint256[] memory riskScores,
        RiskLevel[] memory riskLevels
    );
    
    function getMarketRiskIndicators() external view returns (
        uint256 marketVolatility,
        uint256 correlationIndex,
        uint256 liquidityIndex,
        uint256 stressLevel
    );
    
    function getSystemUtilization() external view returns (
        uint256 activeAssessments,
        uint256 activeLimits,
        uint256 activeModels,
        uint256 systemLoad
    );
}
