// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IRiskManagement
 * @dev Interface for risk management functionality
 */
interface IRiskManagement {
    
    struct RiskProfile {
        uint256 riskScore; // 0-100 scale
        uint256 maxExposure;
        uint256 currentExposure;
        uint256 utilizationRatio;
        uint256 volatilityScore;
        uint256 liquidityScore;
        bool isHighRisk;
        uint256 lastUpdated;
    }

    struct RiskLimits {
        uint256 maxSingleExposure;
        uint256 maxTotalExposure;
        uint256 maxVolatility;
        uint256 minLiquidity;
        uint256 maxUtilization;
        uint256 concentrationLimit;
    }

    struct RiskMetrics {
        uint256 valueAtRisk; // VaR at 95% confidence
        uint256 expectedShortfall; // ES at 95% confidence
        uint256 sharpeRatio;
        uint256 maxDrawdown;
        uint256 beta;
        uint256 correlationScore;
        uint256 totalRisk;
        uint256 lastUpdate;
    }

    struct StressTestResult {
        uint256 scenario;
        uint256 totalLoss;
        uint256 maxAssetLoss;
        bool liquidationRisk;
        uint256 recoveryTime;
    }

    // Events
    event RiskProfileUpdated(
        address indexed asset,
        uint256 riskScore,
        uint256 maxExposure,
        uint256 currentExposure
    );

    event RiskLimitExceeded(
        address indexed asset,
        string limitType,
        uint256 currentValue,
        uint256 limitValue
    );

    event RiskAlert(
        address indexed asset,
        string alertType,
        uint256 severity,
        string message
    );

    event EmergencyStop(
        address indexed asset,
        string reason,
        uint256 timestamp
    );

    // Core risk management functions
    function assessRisk(address asset, uint256 amount) external view returns (uint256 riskScore);
    
    function checkRiskLimits(address asset, uint256 amount) external view returns (bool allowed, string memory reason);
    
    function updateRiskProfile(address asset, RiskProfile calldata profile) external;
    
    function setRiskProfile(address user, RiskProfile memory profile) external;
    
    function setRiskLimits(address user, RiskLimits memory limits) external;
    
    function calculateVaR(int256[] memory returnValues, uint256 confidenceLevel) external pure returns (uint256 valueAtRisk);
    
    function calculateExpectedShortfall(address asset, uint256 confidence) external view returns (uint256 es);
    
    function getCorrelation(address asset1, address asset2) external view returns (uint256 correlation);
    
    function isHighRiskAsset(address asset) external view returns (bool);
    
    function getUtilizationRatio(address asset) external view returns (uint256 ratio);
    
    function getLiquidityScore(address asset) external view returns (uint256 score);
    
    function getVolatilityScore(address asset) external view returns (uint256 score);
    
    // Portfolio risk functions
    function getPortfolioRisk() external view returns (uint256 totalRisk);
    
    function calculatePortfolioRisk(address user, address[] memory assets, uint256[] memory amounts) external view returns (uint256 portfolioRisk);
    
    function getPortfolioVaR(address user, address[] memory assets, uint256[] memory amounts, uint256 confidenceLevel) external view returns (uint256 portfolioVaR);
    
    function getConcentrationRisk() external view returns (uint256 concentration);
    
    function getDiversificationScore() external view returns (uint256 score);
    
    // Risk monitoring functions
    function monitorRisk(address user, address[] memory assets, uint256[] memory amounts) external;
    
    function triggerRiskAlert(address asset, string calldata alertType, uint256 severity) external;
    
    function emergencyStop(address asset, string calldata reason) external;
    
    function isEmergencyStopped(address asset) external view returns (bool);
    
    // Risk parameter functions
    function setRiskParameter(string calldata parameter, uint256 value) external;
    
    function getRiskParameter(string calldata parameter) external view returns (uint256 value);
    
    function updateVolatilityModel(address asset, uint256[] calldata prices) external;
    
    function updateCorrelationMatrix(address[] calldata assets, uint256[][] calldata correlations) external;
    
    // Stress testing functions
    function performStressTest(uint256 scenario, address[] memory assets, uint256[] memory amounts) external view returns (StressTestResult memory stressTestResult);
    
    function stressTest(address asset, uint256 shockSize) external view returns (uint256 impact);
    
    function scenarioAnalysis(address asset, uint256[] calldata scenarios) external view returns (uint256[] memory impacts);
    
    function backtestRiskModel(address asset, uint256[] calldata historicalPrices) external view returns (uint256 accuracy);
    
    // Getter functions
    function getRiskProfile(address asset) external view returns (RiskProfile memory profile);
    
    function getRiskLimits() external view returns (RiskLimits memory limits);
    
    function getRiskMetrics() external view returns (RiskMetrics memory metrics);
    
    function getRiskMetrics(address asset) external view returns (RiskMetrics memory metrics);
    
    function getCurrentExposure(address asset) external view returns (uint256 exposure);
    
    function getMaxAllowedExposure(address asset) external view returns (uint256 maxExposure);
    
    function getRiskScore(address asset) external view returns (uint256 score);
    
    function getTotalPortfolioValue() external view returns (uint256 totalValue);
    
    function getAssetWeight(address asset) external view returns (uint256 weight);
    
    function getAssetAllocation() external view returns (address[] memory assets, uint256[] memory allocations);
    
    // Risk reporting functions
    function generateRiskReport() external view returns (
        uint256 totalRisk,
        uint256 portfolioVar,
        uint256 concentration,
        uint256 diversification,
        address[] memory highRiskAssets
    );
    
    function getDailyRiskMetrics() external view returns (
        uint256 dailyVar,
        uint256 dailyVolatility,
        uint256 sharpeRatio,
        uint256 maxDrawdown
    );
    
    function getWeeklyRiskTrend() external view returns (uint256[] memory riskScores);
    
    function getMonthlyRiskSummary() external view returns (
        uint256 avgRisk,
        uint256 maxRisk,
        uint256 minRisk,
        uint256 riskVolatility
    );
}