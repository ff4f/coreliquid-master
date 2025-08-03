// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IAdvancedAnalytics
 * @dev Interface for the Advanced Analytics contract
 * @author CoreLiquid Protocol
 */
interface IAdvancedAnalytics {
    // Events
    event MetricCalculated(
        bytes32 indexed metricId,
        MetricType metricType,
        uint256 value,
        uint256 timestamp,
        address calculator
    );
    
    event AnalyticsReportGenerated(
        bytes32 indexed reportId,
        ReportType reportType,
        address indexed user,
        uint256 fromTimestamp,
        uint256 toTimestamp,
        uint256 timestamp
    );
    
    event AlertTriggered(
        bytes32 indexed alertId,
        AlertType alertType,
        uint256 threshold,
        uint256 actualValue,
        address indexed user,
        uint256 timestamp
    );
    
    event DataPointAdded(
        bytes32 indexed seriesId,
        uint256 value,
        uint256 timestamp,
        address source
    );
    
    event TrendAnalysisCompleted(
        bytes32 indexed analysisId,
        TrendDirection direction,
        uint256 confidence,
        uint256 duration,
        uint256 timestamp
    );
    
    event PredictionGenerated(
        bytes32 indexed predictionId,
        PredictionType predictionType,
        uint256 predictedValue,
        uint256 confidence,
        uint256 timeHorizon,
        uint256 timestamp
    );
    
    event AnomalyDetected(
        bytes32 indexed anomalyId,
        AnomalyType anomalyType,
        uint256 severity,
        string description,
        uint256 timestamp
    );
    
    event BenchmarkUpdated(
        bytes32 indexed benchmarkId,
        uint256 oldValue,
        uint256 newValue,
        uint256 timestamp
    );
    
    event PerformanceScoreCalculated(
        address indexed user,
        uint256 score,
        uint256 rank,
        uint256 timestamp
    );
    
    event RiskMetricUpdated(
        bytes32 indexed metricId,
        RiskLevel oldLevel,
        RiskLevel newLevel,
        uint256 timestamp
    );

    // Structs
    struct AnalyticsMetric {
        bytes32 metricId;
        string name;
        MetricType metricType;
        uint256 value;
        uint256 previousValue;
        uint256 changePercent;
        uint256 lastUpdate;
        uint256 updateFrequency;
        bool isActive;
        address[] dataSources;
        uint256 confidence;
        uint256 accuracy;
        uint256 createdAt;
    }
    
    struct TimeSeries {
        bytes32 seriesId;
        string name;
        DataPoint[] dataPoints;
        uint256 startTime;
        uint256 endTime;
        uint256 interval;
        uint256 maxPoints;
        bool isRealTime;
        AggregationType aggregationType;
        uint256 lastUpdate;
    }
    
    struct DataPoint {
        uint256 timestamp;
        uint256 value;
        uint256 volume;
        address source;
        bool isValid;
        uint256 confidence;
    }
    
    struct AnalyticsReport {
        bytes32 reportId;
        ReportType reportType;
        address user;
        uint256 fromTimestamp;
        uint256 toTimestamp;
        bytes32[] includedMetrics;
        ReportData data;
        uint256 generatedAt;
        bool isPublic;
        string summary;
        uint256 confidence;
    }
    
    struct ReportData {
        uint256[] values;
        string[] labels;
        uint256[] timestamps;
        ChartData[] charts;
        StatisticalSummary summary;
        Insight[] insights;
    }
    
    struct ChartData {
        ChartType chartType;
        string title;
        string[] labels;
        uint256[][] datasets;
        string[] colors;
        ChartConfig config;
    }
    
    struct StatisticalSummary {
        uint256 mean;
        uint256 median;
        uint256 mode;
        uint256 standardDeviation;
        uint256 variance;
        uint256 min;
        uint256 max;
        uint256 range;
        uint256 skewness;
        uint256 kurtosis;
    }
    
    struct Insight {
        InsightType insightType;
        string title;
        string description;
        uint256 importance;
        uint256 confidence;
        string[] recommendations;
        uint256 timestamp;
    }
    
    struct TrendAnalysis {
        bytes32 analysisId;
        bytes32 seriesId;
        TrendDirection direction;
        uint256 strength;
        uint256 confidence;
        uint256 duration;
        uint256 startTime;
        uint256 endTime;
        TrendPattern pattern;
        uint256[] supportLevels;
        uint256[] resistanceLevels;
        uint256 volatility;
    }
    
    struct Prediction {
        bytes32 predictionId;
        PredictionType predictionType;
        bytes32 targetMetric;
        uint256 predictedValue;
        uint256 confidence;
        uint256 timeHorizon;
        uint256 createdAt;
        uint256 targetTime;
        PredictionModel model;
        uint256[] inputFeatures;
        bool isRealized;
        uint256 actualValue;
        uint256 accuracy;
    }
    
    struct Anomaly {
        bytes32 anomalyId;
        AnomalyType anomalyType;
        bytes32 affectedMetric;
        uint256 severity;
        uint256 detectedAt;
        uint256 startTime;
        uint256 endTime;
        string description;
        uint256 expectedValue;
        uint256 actualValue;
        uint256 deviation;
        bool isResolved;
        uint256 resolvedAt;
    }
    
    struct PerformanceMetrics {
        address user;
        uint256 totalReturn;
        uint256 annualizedReturn;
        uint256 volatility;
        uint256 sharpeRatio;
        uint256 maxDrawdown;
        uint256 winRate;
        uint256 profitFactor;
        uint256 averageWin;
        uint256 averageLoss;
        uint256 totalTrades;
        uint256 rank;
        uint256 score;
        uint256 lastUpdate;
    }
    
    struct RiskMetrics {
        bytes32 metricId;
        RiskLevel riskLevel;
        uint256 valueAtRisk;
        uint256 conditionalVaR;
        uint256 beta;
        uint256 alpha;
        uint256 correlation;
        uint256 volatility;
        uint256 downside_deviation;
        uint256 calmarRatio;
        uint256 sortinoRatio;
        uint256 lastUpdate;
    }
    
    struct Benchmark {
        bytes32 benchmarkId;
        string name;
        BenchmarkType benchmarkType;
        uint256 value;
        uint256 previousValue;
        uint256 changePercent;
        uint256 lastUpdate;
        bool isActive;
        address[] components;
        uint256[] weights;
    }

    // Enums
    enum MetricType {
        PRICE,
        VOLUME,
        LIQUIDITY,
        VOLATILITY,
        RETURN,
        RATIO,
        INDEX,
        CUSTOM
    }
    
    enum ReportType {
        DAILY,
        WEEKLY,
        MONTHLY,
        QUARTERLY,
        ANNUAL,
        CUSTOM,
        REAL_TIME
    }
    
    enum AlertType {
        PRICE_THRESHOLD,
        VOLUME_SPIKE,
        VOLATILITY_CHANGE,
        ANOMALY_DETECTED,
        PERFORMANCE_ALERT,
        RISK_ALERT,
        CUSTOM_ALERT
    }
    
    enum TrendDirection {
        UPWARD,
        DOWNWARD,
        SIDEWAYS,
        VOLATILE,
        UNKNOWN
    }
    
    enum TrendPattern {
        LINEAR,
        EXPONENTIAL,
        LOGARITHMIC,
        CYCLICAL,
        SEASONAL,
        RANDOM_WALK
    }
    
    enum PredictionType {
        PRICE_PREDICTION,
        VOLUME_PREDICTION,
        VOLATILITY_PREDICTION,
        TREND_PREDICTION,
        RISK_PREDICTION,
        PERFORMANCE_PREDICTION
    }
    
    enum PredictionModel {
        LINEAR_REGRESSION,
        POLYNOMIAL_REGRESSION,
        MOVING_AVERAGE,
        EXPONENTIAL_SMOOTHING,
        ARIMA,
        NEURAL_NETWORK,
        ENSEMBLE
    }
    
    enum AnomalyType {
        STATISTICAL_OUTLIER,
        PATTERN_BREAK,
        VOLUME_ANOMALY,
        PRICE_ANOMALY,
        CORRELATION_BREAK,
        SEASONAL_ANOMALY
    }
    
    enum InsightType {
        TREND_INSIGHT,
        PATTERN_INSIGHT,
        CORRELATION_INSIGHT,
        PERFORMANCE_INSIGHT,
        RISK_INSIGHT,
        OPPORTUNITY_INSIGHT
    }
    
    enum ChartType {
        LINE_CHART,
        BAR_CHART,
        CANDLESTICK,
        HISTOGRAM,
        SCATTER_PLOT,
        PIE_CHART,
        HEATMAP
    }
    
    enum AggregationType {
        SUM,
        AVERAGE,
        MEDIAN,
        MIN,
        MAX,
        COUNT,
        WEIGHTED_AVERAGE
    }
    
    enum RiskLevel {
        LOW,
        MEDIUM,
        HIGH,
        CRITICAL
    }
    
    enum BenchmarkType {
        MARKET_INDEX,
        PEER_GROUP,
        CUSTOM_BASKET,
        RISK_FREE_RATE,
        INFLATION_RATE
    }
    
    struct ChartConfig {
        bool showLegend;
        bool showGrid;
        string timeFormat;
        uint256 maxDataPoints;
        bool enableZoom;
        bool enableTooltips;
    }

    // Core analytics functions
    function calculateMetric(
        bytes32 metricId,
        uint256 fromTimestamp,
        uint256 toTimestamp
    ) external returns (uint256 value);
    
    function addDataPoint(
        bytes32 seriesId,
        uint256 value,
        uint256 timestamp
    ) external;
    
    function generateReport(
        ReportType reportType,
        uint256 fromTimestamp,
        uint256 toTimestamp,
        bytes32[] calldata metrics
    ) external returns (bytes32 reportId);
    
    function createTimeSeries(
        string calldata name,
        uint256 interval,
        uint256 maxPoints,
        AggregationType aggregationType
    ) external returns (bytes32 seriesId);
    
    function updateMetric(
        bytes32 metricId,
        uint256 newValue
    ) external;
    
    // Advanced analytics functions
    function performTrendAnalysis(
        bytes32 seriesId,
        uint256 timeWindow
    ) external returns (TrendAnalysis memory analysis);
    
    function generatePrediction(
        bytes32 metricId,
        PredictionType predictionType,
        uint256 timeHorizon,
        PredictionModel model
    ) external returns (Prediction memory prediction);
    
    function detectAnomalies(
        bytes32 seriesId,
        uint256 sensitivityLevel
    ) external returns (Anomaly[] memory anomalies);
    
    function calculateCorrelation(
        bytes32 seriesId1,
        bytes32 seriesId2,
        uint256 timeWindow
    ) external view returns (uint256 correlation);
    
    function performStatisticalAnalysis(
        bytes32 seriesId,
        uint256 timeWindow
    ) external view returns (StatisticalSummary memory summary);
    
    // Performance analytics functions
    function calculatePerformanceMetrics(
        address user,
        uint256 fromTimestamp,
        uint256 toTimestamp
    ) external returns (PerformanceMetrics memory metrics);
    
    function calculateRiskMetrics(
        address user,
        uint256 timeWindow
    ) external returns (RiskMetrics memory metrics);
    
    function comparePerformance(
        address user1,
        address user2,
        uint256 timeWindow
    ) external view returns (
        uint256 user1Performance,
        uint256 user2Performance,
        uint256 outperformance
    );
    
    function calculateSharpeRatio(
        address user,
        uint256 timeWindow
    ) external view returns (uint256 sharpeRatio);
    
    function calculateMaxDrawdown(
        address user,
        uint256 timeWindow
    ) external view returns (uint256 maxDrawdown);
    
    // Benchmark functions
    function createBenchmark(
        string calldata name,
        BenchmarkType benchmarkType,
        address[] calldata components,
        uint256[] calldata weights
    ) external returns (bytes32 benchmarkId);
    
    function updateBenchmark(
        bytes32 benchmarkId,
        uint256 newValue
    ) external;
    
    function compareToBenchmark(
        address user,
        bytes32 benchmarkId,
        uint256 timeWindow
    ) external view returns (
        uint256 userPerformance,
        uint256 benchmarkPerformance,
        uint256 alpha,
        uint256 beta
    );
    
    function calculateTrackingError(
        address user,
        bytes32 benchmarkId,
        uint256 timeWindow
    ) external view returns (uint256 trackingError);
    
    // Alert functions
    function createAlert(
        AlertType alertType,
        bytes32 metricId,
        uint256 threshold,
        bool isAbove
    ) external returns (bytes32 alertId);
    
    function updateAlert(
        bytes32 alertId,
        uint256 newThreshold
    ) external;
    
    function deleteAlert(
        bytes32 alertId
    ) external;
    
    function checkAlerts(
        address user
    ) external returns (bytes32[] memory triggeredAlerts);
    
    function acknowledgeAlert(
        bytes32 alertId
    ) external;
    
    // Insight generation functions
    function generateInsights(
        address user,
        uint256 timeWindow
    ) external returns (Insight[] memory insights);
    
    function getMarketInsights(
        uint256 timeWindow
    ) external view returns (Insight[] memory insights);
    
    function getPersonalizedInsights(
        address user
    ) external view returns (Insight[] memory insights);
    
    function generateRecommendations(
        address user
    ) external view returns (string[] memory recommendations);
    
    // Data aggregation functions
    function aggregateData(
        bytes32 seriesId,
        uint256 fromTimestamp,
        uint256 toTimestamp,
        AggregationType aggregationType
    ) external view returns (uint256 aggregatedValue);
    
    function resampleTimeSeries(
        bytes32 seriesId,
        uint256 newInterval,
        AggregationType aggregationType
    ) external returns (bytes32 newSeriesId);
    
    function mergeTimeSeries(
        bytes32[] calldata seriesIds,
        string calldata name
    ) external returns (bytes32 mergedSeriesId);
    
    function filterTimeSeries(
        bytes32 seriesId,
        uint256 minValue,
        uint256 maxValue
    ) external returns (bytes32 filteredSeriesId);
    
    // Configuration functions
    function setMetricUpdateFrequency(
        bytes32 metricId,
        uint256 frequency
    ) external;
    
    function setAnomalyDetectionSensitivity(
        uint256 sensitivity
    ) external;
    
    function setPredictionAccuracyThreshold(
        uint256 threshold
    ) external;
    
    function setReportRetentionPeriod(
        uint256 period
    ) external;
    
    function enableRealTimeUpdates(
        bytes32 seriesId,
        bool enabled
    ) external;
    
    // View functions - Metrics
    function getMetric(
        bytes32 metricId
    ) external view returns (AnalyticsMetric memory);
    
    function getAllMetrics() external view returns (bytes32[] memory);
    
    function getUserMetrics(
        address user
    ) external view returns (bytes32[] memory);
    
    function getMetricValue(
        bytes32 metricId
    ) external view returns (uint256 value, uint256 timestamp);
    
    function getMetricHistory(
        bytes32 metricId,
        uint256 fromTimestamp,
        uint256 toTimestamp
    ) external view returns (DataPoint[] memory history);
    
    // View functions - Time series
    function getTimeSeries(
        bytes32 seriesId
    ) external view returns (TimeSeries memory);
    
    function getTimeSeriesData(
        bytes32 seriesId,
        uint256 fromTimestamp,
        uint256 toTimestamp
    ) external view returns (DataPoint[] memory data);
    
    function getLatestDataPoint(
        bytes32 seriesId
    ) external view returns (DataPoint memory);
    
    function getTimeSeriesLength(
        bytes32 seriesId
    ) external view returns (uint256 length);
    
    // View functions - Reports
    function getReport(
        bytes32 reportId
    ) external view returns (AnalyticsReport memory);
    
    function getUserReports(
        address user
    ) external view returns (bytes32[] memory);
    
    function getPublicReports() external view returns (bytes32[] memory);
    
    function getReportData(
        bytes32 reportId
    ) external view returns (ReportData memory);
    
    // View functions - Trends and predictions
    function getTrendAnalysis(
        bytes32 analysisId
    ) external view returns (TrendAnalysis memory);
    
    function getPrediction(
        bytes32 predictionId
    ) external view returns (Prediction memory);
    
    function getActivePredictions(
        bytes32 metricId
    ) external view returns (bytes32[] memory);
    
    function getPredictionAccuracy(
        bytes32 predictionId
    ) external view returns (uint256 accuracy);
    
    // View functions - Anomalies
    function getAnomaly(
        bytes32 anomalyId
    ) external view returns (Anomaly memory);
    
    function getActiveAnomalies() external view returns (bytes32[] memory);
    
    function getAnomaliesByMetric(
        bytes32 metricId
    ) external view returns (bytes32[] memory);
    
    function getAnomalySeverity(
        bytes32 anomalyId
    ) external view returns (uint256 severity);
    
    // View functions - Performance
    function getPerformanceMetrics(
        address user
    ) external view returns (PerformanceMetrics memory);
    
    function getRiskMetrics(
        address user
    ) external view returns (RiskMetrics memory);
    
    function getUserRank(
        address user
    ) external view returns (uint256 rank, uint256 totalUsers);
    
    function getTopPerformers(
        uint256 count
    ) external view returns (address[] memory users, uint256[] memory scores);
    
    function getPerformanceScore(
        address user
    ) external view returns (uint256 score);
    
    // View functions - Benchmarks
    function getBenchmark(
        bytes32 benchmarkId
    ) external view returns (Benchmark memory);
    
    function getAllBenchmarks() external view returns (bytes32[] memory);
    
    function getBenchmarkValue(
        bytes32 benchmarkId
    ) external view returns (uint256 value, uint256 timestamp);
    
    function getBenchmarkPerformance(
        bytes32 benchmarkId,
        uint256 timeWindow
    ) external view returns (uint256 performance);
    
    // View functions - Alerts
    function getUserAlerts(
        address user
    ) external view returns (bytes32[] memory);
    
    function getActiveAlerts(
        address user
    ) external view returns (bytes32[] memory);
    
    function getTriggeredAlerts(
        address user
    ) external view returns (bytes32[] memory);
    
    function isAlertTriggered(
        bytes32 alertId
    ) external view returns (bool);
    
    // View functions - Insights
    function getInsights(
        address user
    ) external view returns (Insight[] memory);
    
    function getLatestInsights(
        uint256 count
    ) external view returns (Insight[] memory);
    
    function getInsightsByType(
        InsightType insightType
    ) external view returns (Insight[] memory);
    
    // View functions - System health
    function isSystemHealthy() external view returns (bool);
    
    function getSystemHealth() external view returns (
        bool isHealthy,
        uint256 dataHealth,
        uint256 computationHealth,
        uint256 predictionHealth
    );
    
    function getDataQuality(
        bytes32 seriesId
    ) external view returns (uint256 quality);
    
    function getLastUpdate() external view returns (uint256 timestamp);
    
    function getTotalDataPoints() external view returns (uint256 total);
}
