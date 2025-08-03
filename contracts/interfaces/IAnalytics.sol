// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IAnalytics
 * @dev Interface for the Analytics contract
 * @author CoreLiquid Protocol
 */
interface IAnalytics {
    // Events
    event MetricRecorded(
        bytes32 indexed metricId,
        string metricName,
        MetricType metricType,
        uint256 value,
        address indexed source,
        uint256 timestamp
    );
    
    event DashboardCreated(
        bytes32 indexed dashboardId,
        string dashboardName,
        address indexed creator,
        DashboardType dashboardType,
        uint256 timestamp
    );
    
    event ReportGenerated(
        bytes32 indexed reportId,
        string reportName,
        ReportType reportType,
        address indexed requestedBy,
        uint256 periodStart,
        uint256 periodEnd,
        uint256 timestamp
    );
    
    event AlertTriggered(
        bytes32 indexed alertId,
        string alertName,
        AlertType alertType,
        uint256 threshold,
        uint256 currentValue,
        address indexed source,
        uint256 timestamp
    );
    
    event DataSourceAdded(
        bytes32 indexed sourceId,
        string sourceName,
        DataSourceType sourceType,
        address sourceAddress,
        uint256 timestamp
    );
    
    event AnalyticsModelDeployed(
        bytes32 indexed modelId,
        string modelName,
        ModelType modelType,
        address indexed deployedBy,
        uint256 timestamp
    );
    
    event PredictionGenerated(
        bytes32 indexed predictionId,
        bytes32 indexed modelId,
        string targetMetric,
        uint256 predictedValue,
        uint256 confidence,
        uint256 timestamp
    );
    
    event AnomalyDetected(
        bytes32 indexed anomalyId,
        string metricName,
        uint256 expectedValue,
        uint256 actualValue,
        uint256 deviationScore,
        uint256 timestamp
    );
    
    event KPIUpdated(
        bytes32 indexed kpiId,
        string kpiName,
        uint256 oldValue,
        uint256 newValue,
        uint256 target,
        uint256 timestamp
    );
    
    event BenchmarkSet(
        bytes32 indexed benchmarkId,
        string benchmarkName,
        uint256 value,
        BenchmarkType benchmarkType,
        uint256 timestamp
    );

    // Structs
    struct Metric {
        bytes32 metricId;
        string name;
        string description;
        MetricType metricType;
        DataType dataType;
        string unit;
        uint256 value;
        uint256 previousValue;
        uint256 timestamp;
        uint256 frequency;
        address source;
        MetricConfig config;
        MetricMetadata metadata;
    }
    
    struct MetricConfig {
        uint256 minValue;
        uint256 maxValue;
        uint256 warningThreshold;
        uint256 criticalThreshold;
        bool isActive;
        bool requiresValidation;
        uint256 retentionPeriod;
        string[] tags;
        address[] authorizedUpdaters;
    }
    
    struct MetricMetadata {
        string category;
        string subcategory;
        uint256 priority;
        string[] dependencies;
        string calculationMethod;
        uint256 accuracy;
        uint256 lastValidation;
        bool isCalculated;
        bool isRealTime;
    }
    
    struct Dashboard {
        bytes32 dashboardId;
        string name;
        string description;
        DashboardType dashboardType;
        address creator;
        uint256 createdAt;
        uint256 updatedAt;
        bool isPublic;
        DashboardConfig config;
        DashboardLayout layout;
        bytes32[] widgets;
        address[] authorizedUsers;
    }
    
    struct DashboardConfig {
        uint256 refreshInterval;
        bool autoRefresh;
        string theme;
        bool allowExport;
        bool allowSharing;
        uint256 cacheTimeout;
        string[] filters;
        string timeRange;
    }
    
    struct DashboardLayout {
        uint256 columns;
        uint256 rows;
        WidgetPosition[] positions;
        string layoutType;
        bool isResponsive;
    }
    
    struct WidgetPosition {
        bytes32 widgetId;
        uint256 x;
        uint256 y;
        uint256 width;
        uint256 height;
    }
    
    struct Widget {
        bytes32 widgetId;
        string name;
        WidgetType widgetType;
        bytes32[] metricIds;
        WidgetConfig config;
        WidgetData data;
        uint256 createdAt;
        uint256 updatedAt;
    }
    
    struct WidgetConfig {
        string title;
        string chartType;
        string[] colors;
        bool showLegend;
        bool showGrid;
        string timeRange;
        uint256 dataPoints;
        string aggregation;
        VisualizationOptions visualization;
    }
    
    struct VisualizationOptions {
        bool showTrend;
        bool showComparison;
        bool showTargets;
        bool showAlerts;
        string displayFormat;
        uint256 precision;
        bool useLogScale;
        string[] annotations;
    }
    
    struct WidgetData {
        uint256[] values;
        uint256[] timestamps;
        string[] labels;
        uint256 lastUpdate;
        bool isLoading;
        string errorMessage;
    }
    
    struct Report {
        bytes32 reportId;
        string name;
        string description;
        ReportType reportType;
        address requestedBy;
        uint256 generatedAt;
        uint256 periodStart;
        uint256 periodEnd;
        ReportConfig config;
        ReportData data;
        ReportMetrics metrics;
        string[] attachments;
    }
    
    struct ReportConfig {
        string[] includedMetrics;
        string[] excludedMetrics;
        string format;
        bool includeCharts;
        bool includeRawData;
        string aggregationLevel;
        string[] filters;
        bool isScheduled;
        uint256 scheduleFrequency;
    }
    
    struct ReportData {
        string[] metricNames;
        uint256[] summaryMetrics;
        string[] timeSeriesNames;
        uint256[][] timeSeriesData;
        string[] textualDataKeys;
        string[] textualDataValues;
        bytes[] chartData;
        string[] insights;
        string[] recommendations;
    }
    
    struct ReportMetrics {
        uint256 totalDataPoints;
        uint256 processingTime;
        uint256 fileSize;
        uint256 accuracy;
        string[] dataQualityIssues;
        uint256 completeness;
    }
    
    struct Alert {
        bytes32 alertId;
        string name;
        string description;
        AlertType alertType;
        bytes32 metricId;
        uint256 threshold;
        ComparisonOperator operator;
        uint256 currentValue;
        AlertSeverity severity;
        uint256 triggeredAt;
        uint256 acknowledgedAt;
        uint256 resolvedAt;
        bool isActive;
        AlertConfig config;
        address[] notificationRecipients;
    }
    
    struct AlertConfig {
        uint256 cooldownPeriod;
        uint256 evaluationWindow;
        uint256 consecutiveBreaches;
        bool autoResolve;
        uint256 autoResolveTime;
        bool escalate;
        uint256 escalationTime;
        address[] escalationRecipients;
        string[] actions;
    }
    
    struct DataSource {
        bytes32 sourceId;
        string name;
        string description;
        DataSourceType sourceType;
        address sourceAddress;
        string endpoint;
        uint256 lastUpdate;
        bool isActive;
        SourceConfig config;
        SourceMetrics metrics;
        string[] supportedMetrics;
    }
    
    struct SourceConfig {
        uint256 updateFrequency;
        uint256 timeout;
        bool requiresAuthentication;
        string authMethod;
        uint256 retryAttempts;
        uint256 batchSize;
        string[] headers;
        // Removed mapping - use array of key-value pairs instead
        string[] parameterKeys;
        string[] parameterValues;
    }
    
    struct SourceMetrics {
        uint256 totalRequests;
        uint256 successfulRequests;
        uint256 failedRequests;
        uint256 averageResponseTime;
        uint256 lastSuccessfulUpdate;
        uint256 uptime;
        string[] recentErrors;
    }
    
    struct AnalyticsModel {
        bytes32 modelId;
        string name;
        string description;
        ModelType modelType;
        address deployedBy;
        uint256 deployedAt;
        uint256 lastTrained;
        bool isActive;
        ModelConfig config;
        ModelPerformance performance;
        bytes32[] inputMetrics;
        bytes32[] outputMetrics;
    }
    
    struct ModelConfig {
        string algorithm;
        // Removed mapping - use array of key-value pairs instead
        string[] hyperparameterKeys;
        uint256[] hyperparameterValues;
        uint256 trainingDataSize;
        uint256 validationDataSize;
        uint256 retrainingFrequency;
        bool autoRetrain;
        uint256 confidenceThreshold;
        string[] features;
    }
    
    struct ModelPerformance {
        uint256 accuracy;
        uint256 precision;
        uint256 recall;
        uint256 f1Score;
        uint256 mse;
        uint256 mae;
        uint256 r2Score;
        uint256 lastEvaluation;
        string[] performanceMetrics;
    }
    
    struct Prediction {
        bytes32 predictionId;
        bytes32 modelId;
        string targetMetric;
        uint256 predictedValue;
        uint256 confidence;
        uint256 timestamp;
        uint256 horizon;
        PredictionMetadata metadata;
        uint256[] inputValues;
        string[] assumptions;
    }
    
    struct PredictionMetadata {
        string methodology;
        uint256 dataQuality;
        string[] uncertaintyFactors;
        uint256 validUntil;
        bool isBacktested;
        uint256 backtestAccuracy;
        string[] limitations;
    }
    
    struct Anomaly {
        bytes32 anomalyId;
        bytes32 metricId;
        string metricName;
        uint256 expectedValue;
        uint256 actualValue;
        uint256 deviationScore;
        AnomalyType anomalyType;
        AnomalySeverity severity;
        uint256 detectedAt;
        uint256 resolvedAt;
        bool isResolved;
        AnomalyContext context;
        string[] possibleCauses;
    }
    
    struct AnomalyContext {
        uint256 windowSize;
        string detectionMethod;
        uint256 threshold;
        uint256[] historicalValues;
        string[] correlatedMetrics;
        string[] externalFactors;
    }
    
    struct KPI {
        bytes32 kpiId;
        string name;
        string description;
        uint256 currentValue;
        uint256 targetValue;
        uint256 previousValue;
        KPIType kpiType;
        string unit;
        uint256 lastUpdate;
        KPIConfig config;
        KPITrend trend;
        bytes32[] contributingMetrics;
    }
    
    struct KPIConfig {
        uint256 updateFrequency;
        string calculationFormula;
        uint256 warningThreshold;
        uint256 criticalThreshold;
        bool isPublic;
        string[] stakeholders;
        uint256 reviewFrequency;
    }
    
    struct KPITrend {
        TrendDirection direction;
        uint256 changeRate;
        uint256 volatility;
        uint256 momentum;
        string trendStrength;
        uint256 trendDuration;
    }
    
    struct Benchmark {
        bytes32 benchmarkId;
        string name;
        string description;
        BenchmarkType benchmarkType;
        uint256 value;
        string source;
        uint256 lastUpdate;
        BenchmarkConfig config;
        bytes32[] comparedMetrics;
        BenchmarkPerformance performance;
    }
    
    struct BenchmarkConfig {
        uint256 updateFrequency;
        bool isExternal;
        string dataSource;
        uint256 validityPeriod;
        string[] adjustmentFactors;
        bool autoUpdate;
    }
    
    struct BenchmarkPerformance {
        uint256 correlation;
        uint256 tracking;
        uint256 outperformance;
        uint256 volatility;
        string[] performanceMetrics;
        uint256 lastComparison;
    }

    // Enums
    enum MetricType {
        COUNTER,
        GAUGE,
        HISTOGRAM,
        SUMMARY,
        RATE,
        PERCENTAGE,
        RATIO,
        INDEX
    }
    
    enum DataType {
        INTEGER,
        DECIMAL,
        PERCENTAGE,
        CURRENCY,
        TIME,
        BOOLEAN,
        STRING,
        ARRAY
    }
    
    enum DashboardType {
        EXECUTIVE,
        OPERATIONAL,
        ANALYTICAL,
        REAL_TIME,
        COMPLIANCE,
        RISK,
        PERFORMANCE,
        CUSTOM
    }
    
    enum WidgetType {
        LINE_CHART,
        BAR_CHART,
        PIE_CHART,
        GAUGE,
        TABLE,
        HEATMAP,
        SCATTER_PLOT,
        HISTOGRAM,
        CANDLESTICK,
        TREEMAP
    }
    
    enum ReportType {
        DAILY,
        WEEKLY,
        MONTHLY,
        QUARTERLY,
        ANNUAL,
        CUSTOM,
        REAL_TIME,
        REGULATORY
    }
    
    enum AlertType {
        THRESHOLD,
        TREND,
        ANOMALY,
        PATTERN,
        CORRELATION,
        FORECAST,
        SYSTEM,
        BUSINESS
    }
    
    enum AlertSeverity {
        INFO,
        WARNING,
        CRITICAL,
        EMERGENCY
    }
    
    enum ComparisonOperator {
        GREATER_THAN,
        LESS_THAN,
        EQUAL_TO,
        NOT_EQUAL_TO,
        GREATER_THAN_OR_EQUAL,
        LESS_THAN_OR_EQUAL,
        BETWEEN,
        NOT_BETWEEN
    }
    
    enum DataSourceType {
        BLOCKCHAIN,
        API,
        DATABASE,
        FILE,
        STREAM,
        ORACLE,
        MANUAL,
        CALCULATED
    }
    
    enum ModelType {
        LINEAR_REGRESSION,
        LOGISTIC_REGRESSION,
        DECISION_TREE,
        RANDOM_FOREST,
        NEURAL_NETWORK,
        TIME_SERIES,
        CLUSTERING,
        ANOMALY_DETECTION
    }
    
    enum AnomalyType {
        POINT_ANOMALY,
        CONTEXTUAL_ANOMALY,
        COLLECTIVE_ANOMALY,
        TREND_ANOMALY,
        SEASONAL_ANOMALY
    }
    
    enum AnomalySeverity {
        LOW,
        MEDIUM,
        HIGH,
        CRITICAL
    }
    
    enum KPIType {
        FINANCIAL,
        OPERATIONAL,
        STRATEGIC,
        CUSTOMER,
        PROCESS,
        QUALITY,
        RISK,
        COMPLIANCE
    }
    
    enum TrendDirection {
        UP,
        DOWN,
        STABLE,
        VOLATILE,
        UNKNOWN
    }
    
    enum BenchmarkType {
        INTERNAL,
        EXTERNAL,
        INDUSTRY,
        REGULATORY,
        HISTORICAL,
        TARGET,
        PEER,
        MARKET
    }

    // Core analytics functions
    function recordMetric(
        string calldata metricName,
        uint256 value,
        MetricType metricType,
        string calldata unit
    ) external returns (bytes32 metricId);
    
    function updateMetric(
        bytes32 metricId,
        uint256 value
    ) external;
    
    function batchRecordMetrics(
        string[] calldata metricNames,
        uint256[] calldata values,
        MetricType[] calldata metricTypes
    ) external returns (bytes32[] memory metricIds);
    
    function calculateMetric(
        string calldata metricName,
        string calldata formula,
        bytes32[] calldata inputMetrics
    ) external returns (uint256 value);
    
    // Dashboard functions
    function createDashboard(
        string calldata name,
        string calldata description,
        DashboardType dashboardType,
        DashboardConfig calldata config
    ) external returns (bytes32 dashboardId);
    
    function updateDashboard(
        bytes32 dashboardId,
        DashboardConfig calldata config,
        DashboardLayout calldata layout
    ) external;
    
    function addWidgetToDashboard(
        bytes32 dashboardId,
        bytes32 widgetId,
        WidgetPosition calldata position
    ) external;
    
    function removeWidgetFromDashboard(
        bytes32 dashboardId,
        bytes32 widgetId
    ) external;
    
    function shareDashboard(
        bytes32 dashboardId,
        address[] calldata users,
        bool isPublic
    ) external;
    
    // Widget functions
    function createWidget(
        string calldata name,
        WidgetType widgetType,
        bytes32[] calldata metricIds,
        WidgetConfig calldata config
    ) external returns (bytes32 widgetId);
    
    function updateWidget(
        bytes32 widgetId,
        WidgetConfig calldata config
    ) external;
    
    function refreshWidget(
        bytes32 widgetId
    ) external returns (WidgetData memory data);
    
    function cloneWidget(
        bytes32 widgetId,
        string calldata newName
    ) external returns (bytes32 newWidgetId);
    
    // Report functions
    function generateReport(
        string calldata name,
        ReportType reportType,
        uint256 periodStart,
        uint256 periodEnd,
        ReportConfig calldata config
    ) external returns (bytes32 reportId);
    
    function scheduleReport(
        string calldata name,
        ReportType reportType,
        uint256 frequency,
        ReportConfig calldata config,
        address[] calldata recipients
    ) external returns (bytes32 scheduleId);
    
    function exportReport(
        bytes32 reportId,
        string calldata format
    ) external returns (bytes memory data);
    
    function shareReport(
        bytes32 reportId,
        address[] calldata recipients
    ) external;
    
    // Alert functions
    function createAlert(
        string calldata name,
        bytes32 metricId,
        uint256 threshold,
        ComparisonOperator operator,
        AlertSeverity severity,
        AlertConfig calldata config
    ) external returns (bytes32 alertId);
    
    function updateAlert(
        bytes32 alertId,
        uint256 threshold,
        AlertConfig calldata config
    ) external;
    
    function acknowledgeAlert(
        bytes32 alertId
    ) external;
    
    function resolveAlert(
        bytes32 alertId,
        string calldata resolution
    ) external;
    
    function pauseAlert(
        bytes32 alertId
    ) external;
    
    function resumeAlert(
        bytes32 alertId
    ) external;
    
    // Data source functions
    function addDataSource(
        string calldata name,
        DataSourceType sourceType,
        address sourceAddress,
        string calldata endpoint,
        SourceConfig calldata config
    ) external returns (bytes32 sourceId);
    
    function updateDataSource(
        bytes32 sourceId,
        SourceConfig calldata config
    ) external;
    
    function refreshDataSource(
        bytes32 sourceId
    ) external;
    
    function validateDataSource(
        bytes32 sourceId
    ) external returns (bool isValid, string[] memory errors);
    
    function pauseDataSource(
        bytes32 sourceId
    ) external;
    
    function resumeDataSource(
        bytes32 sourceId
    ) external;
    
    // Analytics model functions
    function deployModel(
        string calldata name,
        ModelType modelType,
        bytes32[] calldata inputMetrics,
        bytes32[] calldata outputMetrics,
        ModelConfig calldata config
    ) external returns (bytes32 modelId);
    
    function trainModel(
        bytes32 modelId,
        uint256 trainingDataStart,
        uint256 trainingDataEnd
    ) external;
    
    function generatePrediction(
        bytes32 modelId,
        uint256 horizon,
        uint256[] calldata inputValues
    ) external returns (bytes32 predictionId);
    
    function evaluateModel(
        bytes32 modelId,
        uint256 testDataStart,
        uint256 testDataEnd
    ) external returns (ModelPerformance memory performance);
    
    function updateModelConfig(
        bytes32 modelId,
        ModelConfig calldata config
    ) external;
    
    // Anomaly detection functions
    function detectAnomalies(
        bytes32 metricId,
        uint256 windowSize,
        string calldata method
    ) external returns (bytes32[] memory anomalyIds);
    
    function investigateAnomaly(
        bytes32 anomalyId,
        string calldata notes
    ) external;
    
    function resolveAnomaly(
        bytes32 anomalyId,
        string calldata resolution
    ) external;
    
    function setAnomalyThreshold(
        bytes32 metricId,
        uint256 threshold,
        string calldata method
    ) external;
    
    // KPI functions
    function createKPI(
        string calldata name,
        string calldata description,
        uint256 targetValue,
        KPIType kpiType,
        string calldata unit,
        KPIConfig calldata config
    ) external returns (bytes32 kpiId);
    
    function updateKPI(
        bytes32 kpiId,
        uint256 currentValue
    ) external;
    
    function setKPITarget(
        bytes32 kpiId,
        uint256 targetValue
    ) external;
    
    function calculateKPITrend(
        bytes32 kpiId,
        uint256 windowSize
    ) external returns (KPITrend memory trend);
    
    function compareKPIs(
        bytes32[] calldata kpiIds,
        uint256 periodStart,
        uint256 periodEnd
    ) external view returns (uint256[] memory values, TrendDirection[] memory trends);
    
    // Benchmark functions
    function createBenchmark(
        string calldata name,
        BenchmarkType benchmarkType,
        uint256 value,
        string calldata source,
        BenchmarkConfig calldata config
    ) external returns (bytes32 benchmarkId);
    
    function updateBenchmark(
        bytes32 benchmarkId,
        uint256 value
    ) external;
    
    function compareToBenchmark(
        bytes32 metricId,
        bytes32 benchmarkId
    ) external view returns (uint256 difference, uint256 percentage);
    
    function setBenchmarkTarget(
        bytes32 metricId,
        bytes32 benchmarkId
    ) external;
    
    // Query and aggregation functions
    function queryMetrics(
        string[] calldata metricNames,
        uint256 startTime,
        uint256 endTime,
        string calldata aggregation
    ) external view returns (uint256[] memory values, uint256[] memory timestamps);
    
    function aggregateMetrics(
        bytes32[] calldata metricIds,
        uint256 startTime,
        uint256 endTime,
        string calldata aggregationType
    ) external view returns (uint256 result);
    
    function correlateMetrics(
        bytes32 metricId1,
        bytes32 metricId2,
        uint256 windowSize
    ) external view returns (uint256 correlation);
    
    function calculateMovingAverage(
        bytes32 metricId,
        uint256 windowSize
    ) external view returns (uint256 average);
    
    function calculateVolatility(
        bytes32 metricId,
        uint256 windowSize
    ) external view returns (uint256 volatility);
    
    // View functions - Metrics
    function getMetric(
        bytes32 metricId
    ) external view returns (Metric memory);
    
    function getMetricByName(
        string calldata metricName
    ) external view returns (Metric memory);
    
    function getAllMetrics() external view returns (bytes32[] memory);
    
    function getMetricsByType(
        MetricType metricType
    ) external view returns (bytes32[] memory);
    
    function getMetricsByCategory(
        string calldata category
    ) external view returns (bytes32[] memory);
    
    function getMetricHistory(
        bytes32 metricId,
        uint256 startTime,
        uint256 endTime
    ) external view returns (uint256[] memory values, uint256[] memory timestamps);
    
    // View functions - Dashboards
    function getDashboard(
        bytes32 dashboardId
    ) external view returns (Dashboard memory);
    
    function getUserDashboards(
        address user
    ) external view returns (bytes32[] memory);
    
    function getPublicDashboards() external view returns (bytes32[] memory);
    
    function getDashboardsByType(
        DashboardType dashboardType
    ) external view returns (bytes32[] memory);
    
    // View functions - Widgets
    function getWidget(
        bytes32 widgetId
    ) external view returns (Widget memory);
    
    function getDashboardWidgets(
        bytes32 dashboardId
    ) external view returns (bytes32[] memory);
    
    function getWidgetData(
        bytes32 widgetId
    ) external view returns (WidgetData memory);
    
    // View functions - Reports
    function getReport(
        bytes32 reportId
    ) external view returns (Report memory);
    
    function getUserReports(
        address user,
        ReportType reportType
    ) external view returns (bytes32[] memory);
    
    function getScheduledReports() external view returns (bytes32[] memory);
    
    function getReportData(
        bytes32 reportId
    ) external view returns (ReportData memory);
    
    // View functions - Alerts
    function getAlert(
        bytes32 alertId
    ) external view returns (Alert memory);
    
    function getActiveAlerts() external view returns (bytes32[] memory);
    
    function getUserAlerts(
        address user
    ) external view returns (bytes32[] memory);
    
    function getAlertsByMetric(
        bytes32 metricId
    ) external view returns (bytes32[] memory);
    
    function getAlertsBySeverity(
        AlertSeverity severity
    ) external view returns (bytes32[] memory);
    
    // View functions - Data sources
    function getDataSource(
        bytes32 sourceId
    ) external view returns (DataSource memory);
    
    function getAllDataSources() external view returns (bytes32[] memory);
    
    function getActiveDataSources() external view returns (bytes32[] memory);
    
    function getDataSourcesByType(
        DataSourceType sourceType
    ) external view returns (bytes32[] memory);
    
    function getDataSourceMetrics(
        bytes32 sourceId
    ) external view returns (SourceMetrics memory);
    
    // View functions - Models
    function getAnalyticsModel(
        bytes32 modelId
    ) external view returns (AnalyticsModel memory);
    
    function getAllModels() external view returns (bytes32[] memory);
    
    function getActiveModels() external view returns (bytes32[] memory);
    
    function getModelsByType(
        ModelType modelType
    ) external view returns (bytes32[] memory);
    
    function getModelPerformance(
        bytes32 modelId
    ) external view returns (ModelPerformance memory);
    
    function getPrediction(
        bytes32 predictionId
    ) external view returns (Prediction memory);
    
    function getModelPredictions(
        bytes32 modelId,
        uint256 limit
    ) external view returns (bytes32[] memory);
    
    // View functions - Anomalies
    function getAnomaly(
        bytes32 anomalyId
    ) external view returns (Anomaly memory);
    
    function getMetricAnomalies(
        bytes32 metricId
    ) external view returns (bytes32[] memory);
    
    function getActiveAnomalies() external view returns (bytes32[] memory);
    
    function getAnomaliesByType(
        AnomalyType anomalyType
    ) external view returns (bytes32[] memory);
    
    function getAnomaliesBySeverity(
        AnomalySeverity severity
    ) external view returns (bytes32[] memory);
    
    // View functions - KPIs
    function getKPI(
        bytes32 kpiId
    ) external view returns (KPI memory);
    
    function getAllKPIs() external view returns (bytes32[] memory);
    
    function getKPIsByType(
        KPIType kpiType
    ) external view returns (bytes32[] memory);
    
    function getKPITrend(
        bytes32 kpiId
    ) external view returns (KPITrend memory);
    
    function getKPIProgress(
        bytes32 kpiId
    ) external view returns (uint256 progress, bool isOnTrack);
    
    // View functions - Benchmarks
    function getBenchmark(
        bytes32 benchmarkId
    ) external view returns (Benchmark memory);
    
    function getAllBenchmarks() external view returns (bytes32[] memory);
    
    function getBenchmarksByType(
        BenchmarkType benchmarkType
    ) external view returns (bytes32[] memory);
    
    function getBenchmarkPerformance(
        bytes32 benchmarkId
    ) external view returns (BenchmarkPerformance memory);
    
    // View functions - Analytics
    function getSystemHealth() external view returns (
        uint256 totalMetrics,
        uint256 activeDataSources,
        uint256 activeAlerts,
        uint256 systemLoad
    );
    
    function getAnalyticsSummary(
        uint256 timeframe
    ) external view returns (
        uint256 totalDataPoints,
        uint256 totalReports,
        uint256 totalPredictions,
        uint256 totalAnomalies
    );
    
    function getPerformanceMetrics() external view returns (
        uint256 averageQueryTime,
        uint256 dataFreshness,
        uint256 systemUptime,
        uint256 errorRate
    );
}
