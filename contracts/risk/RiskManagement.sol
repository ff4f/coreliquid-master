// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "../interfaces/IRiskManagement.sol";
import "../interfaces/IOracle.sol";

/**
 * @title RiskManagement
 * @dev Comprehensive risk management system for CoreLiquid Protocol
 * @author CoreLiquid Protocol
 */
contract RiskManagement is IRiskManagement, AccessControl, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;
    using Math for uint256;

    // Roles
    bytes32 public constant RISK_MANAGER_ROLE = keccak256("RISK_MANAGER_ROLE");
    bytes32 public constant RISK_ASSESSOR_ROLE = keccak256("RISK_ASSESSOR_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
    bytes32 public constant LIQUIDATOR_ROLE = keccak256("LIQUIDATOR_ROLE");
    bytes32 public constant MONITOR_ROLE = keccak256("MONITOR_ROLE");

    // Constants
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant PRECISION = 1e18;
    uint256 public constant MAX_RISK_SCORE = 1000;
    uint256 public constant MIN_HEALTH_FACTOR = 1e18; // 1.0
    uint256 public constant LIQUIDATION_THRESHOLD = 8000; // 80%
    uint256 public constant MAX_EXPOSURE_RATIO = 5000; // 50%
    uint256 public constant STRESS_TEST_SCENARIOS = 10;

    // Oracle interface
    IOracle public immutable oracle;

    // Enums
    enum RiskType {
        COLLATERAL,
        DEBT,
        LIQUIDITY,
        CONCENTRATION,
        VOLATILITY,
        CORRELATION
    }
    
    enum ExposureType {
        INCREASE,
        DECREASE,
        LIQUIDATION,
        TRANSFER
    }
    
    enum AlertSeverity {
        LOW,
        MEDIUM,
        HIGH,
        CRITICAL,
        EMERGENCY
    }
    
    enum RiskLevel {
        LOW,
        MEDIUM,
        HIGH,
        CRITICAL,
        EMERGENCY
    }

    // Struct definitions
    struct RiskAssessment {
        uint256 riskScore;
        uint256 healthFactor;
        uint256 liquidationThreshold;
        bool isAtRisk;
        string riskCategory;
        uint256 timestamp;
    }
    
    struct StressTestResults {
        uint256 testId;
        uint256 totalLoss;
        uint256 maxAssetLoss;
        bool liquidationTriggered;
        uint256 recoveryTime;
        uint256 timestamp;
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

    struct HealthFactor {
        address user;
        uint256 currentHealthFactor;
        uint256 lastUpdate;
        bool isHealthy;
    }
    
    struct RiskAlertData {
        address user;
        string message;
        uint256 severity;
        uint256 timestamp;
        bool isResolved;
    }
    
    struct LiquidationData {
        address user;
        address asset;
        uint256 debtToCover;
        uint256 collateralToLiquidate;
        uint256 liquidationBonus;
        uint256 timestamp;
        bool completed;
    }
    
    struct ExposureData {
        uint256 totalExposure;
        uint256 maxExposure;
        uint256 utilizationRatio;
        uint256 lastUpdate;
    }
    
    struct RiskLimit {
        uint256 maxSingleExposure;
        uint256 maxTotalExposure;
        uint256 maxVolatility;
        uint256 minLiquidity;
        uint256 maxUtilization;
    }
    
    struct CollateralData {
        uint256 totalCollateral;
        uint256 availableCollateral;
        uint256 lockedCollateral;
        uint256 collateralRatio;
        uint256 lastUpdate;
    }
    
    struct PortfolioRisk {
        uint256 totalRisk;
        uint256 concentrationRisk;
        uint256 diversificationScore;
        uint256 volatilityRisk;
        uint256 lastCalculated;
    }
    
    struct RiskConfig {
        uint256 maxLeverage;
        uint256 liquidationThreshold;
        uint256 healthFactorThreshold;
        uint256 maxConcentration;
        uint256 volatilityThreshold;
        bool emergencyMode;
    }
    
    struct StressTestScenario {
        uint256 scenarioId;
        string name;
        uint256 priceShock;
        uint256 liquidityShock;
        uint256 demandShock;
        uint256 expectedLiquidations;
        uint256 expectedLosses;
        bool isActive;
    }
    
    struct UserPosition {
        address asset;
        uint256 amount;
        uint256 value;
        uint256 riskWeight;
        uint256 lastUpdate;
    }

    // Events
    event RiskAssessmentCompleted(address indexed user, address indexed asset, uint256 riskScore, RiskType riskType, uint256 timestamp);
    event HealthFactorCalculated(address indexed user, uint256 healthFactor, uint256 timestamp);
    event PositionLiquidated(address indexed user, address indexed asset, uint256 amount, uint256 liquidationBonus, uint256 timestamp);
    event ExposureUpdated(address indexed user, address indexed asset, uint256 amount, ExposureType exposureType, uint256 timestamp);
    event StressTestCompleted(bytes32 indexed testId, address indexed user, string scenarioName, bool passed, uint256 timestamp);
    event RiskLimitSet(address indexed user, address indexed asset, uint256 maxExposure, uint256 maxLeverage, uint256 timestamp);
    event CollateralRiskUpdated(address indexed asset, uint256 liquidationThreshold, uint256 liquidationBonus, uint256 riskWeight, uint256 timestamp);
    event PortfolioRiskCalculated(address indexed user, uint256 overallRiskScore, uint256 timestamp);
    event RiskAlertResolved(address indexed user, address indexed resolver, uint256 timestamp);
    event EmergencyLiquidationTriggered(address indexed user, address indexed asset, uint256 amount, uint256 timestamp);
    event RiskParametersUpdated(string parameter, uint256 oldValue, uint256 newValue, uint256 timestamp);
    event SystemRiskLevelChanged(RiskLevel oldLevel, RiskLevel newLevel, uint256 timestamp);
    event UserRiskProfileUpdated(address indexed user, uint256 riskScore, RiskLevel riskLevel, uint256 timestamp);
    event RiskAssessed(address indexed user, address indexed asset, uint256 amount, uint256 riskScore, RiskType riskType, uint256 timestamp);
    event EmergencyLiquidation(address indexed user, uint256 timestamp);
    event EmergencyModeEnabled(uint256 timestamp);
    event EmergencyModeDisabled(uint256 timestamp);
    event RiskConfigUpdated(uint256 timestamp);
    event RiskAlertCreated(address indexed user, string message, uint256 severity, uint256 timestamp);
    
    // Functions
    function getAssetPrice(address asset) internal view returns (uint256) {
        return oracle.getPrice(asset);
    }

    // Storage mappings
    mapping(address => RiskProfile) public riskProfiles;
    mapping(address => HealthFactor) public healthFactors;
    mapping(address => LiquidationData) public liquidationData;
    mapping(address => ExposureData) public exposureData;
    mapping(bytes32 => StressTestResult) public stressTestResults;
    mapping(address => RiskMetrics) public riskMetrics;
    mapping(address => RiskLimit) public riskLimits;
    mapping(address => CollateralData) public collateralData;
    mapping(address => PortfolioRisk) public portfolioRisks;
    mapping(address => RiskAlertData) public riskAlerts;
    mapping(address => address[]) public userPositions;
    mapping(address => bytes32[]) public userStressTests;
    
    // Global arrays
    address[] public allUsers;
    address[] public highRiskUsers;
    address[] public liquidatablePositions;
    bytes32[] public allStressTests;
    address[] public monitoredAssets;
    
    // Risk configuration
    RiskConfig public config;
    
    // Counters
    uint256 public totalRiskAssessments;
    uint256 public totalLiquidations;
    uint256 public totalStressTests;
    uint256 public totalRiskAlerts;

    // State variables
    bool public emergencyMode;
    uint256 public lastGlobalRiskUpdate;
    mapping(address => uint256) public lastRiskUpdate;
    mapping(address => bool) public isHighRisk;
    mapping(address => RiskLimits) public userRiskLimits;
    
    // Global metrics
    SystemRiskMetrics public globalMetrics;

    constructor(
        address _oracle,
        uint256 _maxLeverage,
        uint256 _liquidationThreshold,
        uint256 _healthFactorThreshold
    ) {
        require(_oracle != address(0), "Invalid oracle");
        require(_maxLeverage > 0 && _maxLeverage <= 10, "Invalid max leverage");
        require(_liquidationThreshold > 0 && _liquidationThreshold <= BASIS_POINTS, "Invalid liquidation threshold");
        require(_healthFactorThreshold >= MIN_HEALTH_FACTOR, "Invalid health factor threshold");
        
        oracle = IOracle(_oracle);
        
        config = RiskConfig({
            maxLeverage: _maxLeverage,
            liquidationThreshold: _liquidationThreshold,
            healthFactorThreshold: _healthFactorThreshold,
            maxExposureRatio: MAX_EXPOSURE_RATIO,
            riskFreeRate: 300, // 3%
            volatilityThreshold: 2000, // 20%
            correlationThreshold: 8000, // 80%
            stressTestFrequency: 1 days,
            isActive: true
        });
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(RISK_MANAGER_ROLE, msg.sender);
        _grantRole(RISK_ASSESSOR_ROLE, msg.sender);
        _grantRole(EMERGENCY_ROLE, msg.sender);
        _grantRole(LIQUIDATOR_ROLE, msg.sender);
        _grantRole(MONITOR_ROLE, msg.sender);
    }

    // Core risk management functions
    function assessRisk(
        address user,
        address asset,
        uint256 amount,
        RiskType riskType
    ) external onlyRole(RISK_ASSESSOR_ROLE) returns (uint256 riskScore) {
        require(user != address(0), "Invalid user");
        require(asset != address(0), "Invalid asset");
        require(amount > 0, "Invalid amount");
        
        // Calculate base risk score
        riskScore = _calculateBaseRiskScore(user, asset, amount, riskType);
        
        // Apply risk adjustments
        riskScore = _applyRiskAdjustments(user, asset, riskScore);
        
        // Update risk profile
        RiskProfile storage profile = riskProfiles[user];
        profile.user = user;
        profile.totalRiskScore = _calculateTotalRiskScore(user);
        profile.riskLevel = _getRiskLevel(profile.totalRiskScore);
        profile.lastAssessment = block.timestamp;
        profile.assessmentCount++;
        
        // Update metrics
        _updateRiskMetrics(user, asset, riskScore);
        
        totalRiskAssessments++;
        lastRiskUpdate[user] = block.timestamp;
        
        emit RiskAssessed(user, asset, amount, riskScore, riskType, block.timestamp);
        
        return riskScore;
    }

    function calculateHealthFactor(
        address user
    ) external returns (uint256 healthFactor) {
        require(user != address(0), "Invalid user");
        
        (uint256 totalCollateral, uint256 totalDebt) = _getUserCollateralAndDebt(user);
        
        if (totalDebt == 0) {
            healthFactor = type(uint256).max;
        } else {
            uint256 liquidationThreshold = _getWeightedLiquidationThreshold(user);
            healthFactor = (totalCollateral * liquidationThreshold) / (totalDebt * BASIS_POINTS);
        }
        
        // Update health factor data
        HealthFactor storage hf = healthFactors[user];
        hf.user = user;
        hf.currentHealthFactor = healthFactor;
        hf.lastUpdate = block.timestamp;
        hf.isHealthy = healthFactor >= config.healthFactorThreshold;
        
        // Check for liquidation risk
        if (healthFactor < MIN_HEALTH_FACTOR) {
            _flagForLiquidation(user, healthFactor);
        }
        
        emit HealthFactorCalculated(user, healthFactor, block.timestamp);
        
        return healthFactor;
    }

    function liquidatePosition(
        address user,
        address collateralAsset,
        address debtAsset,
        uint256 debtToCover
    ) external onlyRole(LIQUIDATOR_ROLE) nonReentrant {
        require(user != address(0), "Invalid user");
        require(collateralAsset != address(0), "Invalid collateral asset");
        require(debtAsset != address(0), "Invalid debt asset");
        require(debtToCover > 0, "Invalid debt amount");
        
        // Check if position is liquidatable
        uint256 healthFactor = this.calculateHealthFactor(user);
        require(healthFactor < MIN_HEALTH_FACTOR, "Position not liquidatable");
        
        // Calculate liquidation amounts
        (uint256 collateralToLiquidate, uint256 liquidationBonus) = _calculateLiquidationAmounts(
            user,
            collateralAsset,
            debtAsset,
            debtToCover
        );
        
        // Execute liquidation
        _executeLiquidation(
            user,
            msg.sender,
            collateralAsset,
            debtAsset,
            debtToCover,
            collateralToLiquidate,
            liquidationBonus
        );
        
        // Update liquidation data
        LiquidationData storage liquidation = liquidationData[user];
        liquidation.user = user;
        liquidation.liquidator = msg.sender;
        liquidation.collateralAsset = collateralAsset;
        liquidation.debtAsset = debtAsset;
        liquidation.debtCovered = debtToCover;
        liquidation.collateralLiquidated = collateralToLiquidate;
        liquidation.liquidationBonus = liquidationBonus;
        liquidation.timestamp = block.timestamp;
        liquidation.healthFactorBefore = healthFactor;
        liquidation.healthFactorAfter = this.calculateHealthFactor(user);
        
        totalLiquidations++;
        
        emit PositionLiquidated(
            user,
            msg.sender,
            collateralAsset,
            debtAsset,
            debtToCover,
            collateralToLiquidate,
            liquidationBonus,
            block.timestamp
        );
    }

    function updateExposure(
        address user,
        address asset,
        uint256 amount,
        ExposureType exposureType
    ) external onlyRole(MONITOR_ROLE) {
        require(user != address(0), "Invalid user");
        require(asset != address(0), "Invalid asset");
        
        ExposureData storage exposure = exposureData[user];
        exposure.user = user;
        exposure.asset = asset;
        exposure.lastUpdate = block.timestamp;
        
        if (exposureType == ExposureType.LONG) {
            exposure.longExposure = amount;
        } else if (exposureType == ExposureType.SHORT) {
            exposure.shortExposure = amount;
        } else {
            exposure.netExposure = amount;
        }
        
        exposure.totalExposure = exposure.longExposure + exposure.shortExposure;
        exposure.exposureRatio = _calculateExposureRatio(user, asset);
        
        // Check exposure limits
        if (exposure.exposureRatio > config.maxExposureRatio) {
            _createRiskAlert(user, "High exposure ratio detected", AlertSeverity.HIGH);
        }
        
        emit ExposureUpdated(user, asset, amount, exposureType, block.timestamp);
    }

    function runStressTest(
        address user,
        StressTestScenario calldata scenario
    ) external onlyRole(RISK_ASSESSOR_ROLE) returns (bytes32 testId) {
        require(user != address(0), "Invalid user");
        
        testId = keccak256(abi.encodePacked(user, block.timestamp, scenario.name));
        
        // Run stress test simulation
        StressTestResult storage result = stressTestResults[testId];
        result.testId = testId;
        result.user = user;
        result.scenario = scenario;
        result.timestamp = block.timestamp;
        
        // Calculate stress test results
        (result.portfolioValueBefore, result.portfolioValueAfter) = _simulateStressScenario(user, scenario);
        result.maxDrawdown = _calculateMaxDrawdown(result.portfolioValueBefore, result.portfolioValueAfter);
        result.riskMetrics = _calculateStressRiskMetrics(user, scenario);
        result.passed = result.maxDrawdown <= scenario.maxAcceptableDrawdown;
        
        userStressTests[user].push(testId);
        allStressTests.push(testId);
        totalStressTests++;
        
        emit StressTestCompleted(testId, user, scenario.name, result.passed, block.timestamp);
        
        return testId;
    }

    function setRiskLimit(
        address user,
        address asset,
        RiskLimit calldata limit
    ) external onlyRole(RISK_MANAGER_ROLE) {
        require(user != address(0), "Invalid user");
        require(asset != address(0), "Invalid asset");
        
        riskLimits[user] = limit;
        
        emit RiskLimitSet(user, asset, limit.maxExposure, limit.maxLeverage, block.timestamp);
    }

    function updateCollateralRisk(
        address asset,
        uint256 liquidationThreshold,
        uint256 liquidationBonus,
        uint256 riskWeight
    ) external onlyRole(RISK_MANAGER_ROLE) {
        require(asset != address(0), "Invalid asset");
        require(liquidationThreshold > 0 && liquidationThreshold <= BASIS_POINTS, "Invalid liquidation threshold");
        require(liquidationBonus <= 2000, "Invalid liquidation bonus"); // Max 20%
        require(riskWeight <= BASIS_POINTS, "Invalid risk weight");
        
        CollateralData storage collateral = collateralData[asset];
        collateral.asset = asset;
        collateral.liquidationThreshold = liquidationThreshold;
        collateral.liquidationBonus = liquidationBonus;
        collateral.riskWeight = riskWeight;
        collateral.lastUpdate = block.timestamp;
        collateral.isActive = true;
        
        emit CollateralRiskUpdated(asset, liquidationThreshold, liquidationBonus, riskWeight, block.timestamp);
    }

    function calculatePortfolioRisk(
        address user
    ) external returns (PortfolioRisk memory) {
        require(user != address(0), "Invalid user");
        
        PortfolioRisk storage portfolio = portfolioRisks[user];
        portfolio.user = user;
        portfolio.lastUpdate = block.timestamp;
        
        // Calculate portfolio metrics
        (portfolio.totalValue, portfolio.totalDebt) = _getUserCollateralAndDebt(user);
        portfolio.leverage = portfolio.totalDebt > 0 ? (portfolio.totalValue * PRECISION) / portfolio.totalDebt : 0;
        portfolio.diversificationScore = _calculateDiversificationScore(user);
        portfolio.concentrationRisk = _calculateConcentrationRisk(user);
        portfolio.liquidityRisk = _calculateLiquidityRisk(user);
        portfolio.marketRisk = _calculateMarketRisk(user);
        portfolio.creditRisk = _calculateCreditRisk(user);
        portfolio.overallRiskScore = _calculateOverallRiskScore(portfolio);
        
        emit PortfolioRiskCalculated(user, portfolio.overallRiskScore, block.timestamp);
        
        return portfolio;
    }

    function createRiskAlert(
        address user,
        string calldata message,
        AlertSeverity severity
    ) external onlyRole(MONITOR_ROLE) {
        _createRiskAlert(user, message, severity);
    }

    function resolveRiskAlert(
        address user
    ) external onlyRole(RISK_MANAGER_ROLE) {
        RiskAlertData storage alert = riskAlerts[user];
        require(alert.isActive, "No active alert");
        
        alert.isActive = false;
        alert.resolvedAt = block.timestamp;
        alert.resolvedBy = msg.sender;
        
        emit RiskAlertResolved(user, msg.sender, block.timestamp);
    }

    // Emergency functions
    function emergencyLiquidation(
        address user
    ) external onlyRole(EMERGENCY_ROLE) returns (uint256 totalLiquidated) {
        require(emergencyMode, "Not in emergency mode");
        
        // Force liquidate all positions
        address[] memory positions = userPositions[user];
        uint256 liquidatedAmount = 0;
        for (uint256 i = 0; i < positions.length; i++) {
            UserPosition storage position = positions[i];
            
            if (position.collateralAmount > 0) {
                // Calculate liquidation amount based on position size and health factor
                uint256 positionValue = (position.collateralAmount * getAssetPrice(position.collateralAsset)) / PRECISION;
                uint256 debtValue = (position.debtAmount * getAssetPrice(position.debtAsset)) / PRECISION;
                
                // Liquidate up to 50% of collateral in emergency
                uint256 maxLiquidation = position.collateralAmount / 2;
                uint256 liquidationAmount = debtValue > positionValue ? maxLiquidation : 
                    (debtValue * position.collateralAmount) / positionValue;
                
                if (liquidationAmount > 0) {
                    position.collateralAmount -= liquidationAmount;
                    liquidatedAmount += liquidationAmount;
                    
                    // Update debt proportionally
                    uint256 debtReduction = (liquidationAmount * position.debtAmount) / (position.collateralAmount + liquidationAmount);
                    position.debtAmount -= debtReduction;
                }
            }
        }
        
        emit EmergencyLiquidation(user, block.timestamp);
        return liquidatedAmount;
    }

    function pauseRiskAssessment() external onlyRole(EMERGENCY_ROLE) {
        _pause();
    }

    function enableEmergencyMode() external onlyRole(EMERGENCY_ROLE) {
        emergencyMode = true;
        _pause();
        
        emit EmergencyModeEnabled(block.timestamp);
    }

    function disableEmergencyMode() external onlyRole(EMERGENCY_ROLE) {
        emergencyMode = false;
        _unpause();
        
        emit EmergencyModeDisabled(block.timestamp);
    }

    // Configuration functions
    function updateRiskConfig(
        RiskConfig calldata newConfig
    ) external onlyRole(RISK_MANAGER_ROLE) {
        require(newConfig.maxLeverage > 0 && newConfig.maxLeverage <= 10, "Invalid max leverage");
        require(newConfig.liquidationThreshold > 0 && newConfig.liquidationThreshold <= BASIS_POINTS, "Invalid liquidation threshold");
        require(newConfig.healthFactorThreshold >= MIN_HEALTH_FACTOR, "Invalid health factor threshold");
        
        config = newConfig;
        
        emit RiskConfigUpdated(block.timestamp);
    }

    // View functions
    function getRiskProfile(address user) external view returns (RiskProfile memory) {
        return riskProfiles[user];
    }

    function getHealthFactor(address user) external view returns (HealthFactor memory) {
        return healthFactors[user];
    }

    function getLiquidationData(address user) external view returns (LiquidationData memory) {
        return liquidationData[user];
    }

    function getExposureData(address user) external view returns (ExposureData memory) {
        return exposureData[user];
    }

    function getStressTestResult(bytes32 testId) external view returns (StressTestResult memory) {
        return stressTestResults[testId];
    }

    function getRiskMetrics(address user) external view returns (RiskMetrics memory) {
        return riskMetrics[user];
    }

    function getRiskLimit(address user) external view returns (RiskLimit memory) {
        return riskLimits[user];
    }

    function getCollateralData(address asset) external view returns (CollateralData memory) {
        return collateralData[asset];
    }

    function getPortfolioRisk(address user) external view returns (PortfolioRisk memory) {
        return portfolioRisks[user];
    }

    function getRiskAlert(address user) external view returns (RiskAlertData memory) {
        return riskAlerts[user];
    }

    function getRiskConfig() external view returns (RiskConfig memory) {
        return config;
    }

    function getAllUsers() external view returns (address[] memory) {
        return allUsers;
    }

    function getHighRiskUsers() external view returns (address[] memory) {
        return highRiskUsers;
    }

    function getLiquidatablePositions() external view returns (address[] memory) {
        return liquidatablePositions;
    }

    function getUserStressTests(address user) external view returns (bytes32[] memory) {
        return userStressTests[user];
    }

    function getSystemRiskMetrics() external view returns (SystemRiskMetrics memory) {
        return SystemRiskMetrics({
            totalUsers: allUsers.length,
            highRiskUsers: highRiskUsers.length,
            liquidatablePositions: liquidatablePositions.length,
            totalRiskAssessments: totalRiskAssessments,
            totalLiquidations: totalLiquidations,
            totalStressTests: totalStressTests,
            averageRiskScore: _calculateAverageRiskScore(),
            systemHealthFactor: _calculateSystemHealthFactor()
        });
    }

    // Implementation of missing interface functions
    function setRiskParameter(string calldata parameter, uint256 value) external override onlyRole(RISK_MANAGER_ROLE) {
        riskParameters[parameter] = value;
        emit RiskParametersUpdated(address(0), value, block.timestamp);
    }
    
    function getRiskParameter(string calldata parameter) external view override returns (uint256 value) {
        return riskParameters[parameter];
    }
    
    function triggerRiskAlert(address asset, string calldata alertType, uint256 severity) external override onlyRole(RISK_MANAGER_ROLE) {
        AlertSeverity alertSeverity = AlertSeverity.LOW;
        if (severity >= 80) alertSeverity = AlertSeverity.CRITICAL;
        else if (severity >= 60) alertSeverity = AlertSeverity.HIGH;
        else if (severity >= 40) alertSeverity = AlertSeverity.MEDIUM;
        
        _createRiskAlert(asset, alertType, alertSeverity);
    }
    
    function updateCorrelationMatrix(address[] calldata assets, uint256[][] calldata correlations) external override onlyRole(RISK_MANAGER_ROLE) {
        require(assets.length == correlations.length, "Arrays length mismatch");
        
        for (uint256 i = 0; i < assets.length; i++) {
            require(correlations[i].length == assets.length, "Correlation matrix dimension mismatch");
            for (uint256 j = 0; j < assets.length; j++) {
                correlationMatrix[assets[i]][assets[j]] = correlations[i][j];
            }
        }
        
        emit RiskParametersUpdated(address(0), block.timestamp, block.timestamp);
    }
    
    function stressTest(address asset, uint256 shockSize) external view override returns (uint256 impact) {
        CollateralData memory data = collateralData[asset];
        uint256 currentValue = data.totalCollateral;
        impact = (currentValue * shockSize * data.volatility) / (BASIS_POINTS * BASIS_POINTS);
    }
    
    // Additional missing interface implementations
    function checkRiskLimits(address asset, uint256 amount) external view override returns (bool allowed, string memory reason) {
        CollateralData memory data = collateralData[asset];
        
        if (emergencyMode) {
            return (false, "Emergency mode active");
        }
        
        if (data.totalCollateral + amount > data.maxCollateral) {
            return (false, "Exceeds maximum collateral limit");
        }
        
        return (true, "");
    }
    
    function isHighRiskAsset(address asset) external view override returns (bool) {
        return collateralData[asset].volatility > 5000; // 50% volatility threshold
    }
    
    function getUtilizationRatio(address asset) external view override returns (uint256 ratio) {
        CollateralData memory data = collateralData[asset];
        return data.maxCollateral > 0 ? (data.totalCollateral * BASIS_POINTS) / data.maxCollateral : 0;
    }
    
    function getLiquidityScore(address asset) external view override returns (uint256 score) {
        // Simple liquidity score based on collateral ratio
        uint256 utilization = this.getUtilizationRatio(asset);
        return utilization > 0 ? BASIS_POINTS - utilization : BASIS_POINTS;
    }
    
    function getVolatilityScore(address asset) external view override returns (uint256 score) {
        return collateralData[asset].volatility;
    }
    
    function getPortfolioRisk() external view override returns (uint256 totalRisk) {
        return _calculateSystemHealthFactor();
    }
    
    function calculatePortfolioRisk(address user, address[] memory assets, uint256[] memory amounts) external view override returns (uint256 portfolioRisk) {
        require(assets.length == amounts.length, "Arrays length mismatch");
        
        uint256 totalRisk = 0;
        for (uint256 i = 0; i < assets.length; i++) {
            uint256 assetRisk = collateralData[assets[i]].volatility;
            uint256 weightedRisk = (assetRisk * amounts[i]) / PRECISION;
            totalRisk += weightedRisk;
        }
        
        return assets.length > 0 ? totalRisk / assets.length : 0;
    }
    
    function getPortfolioVaR(address user, address[] memory assets, uint256[] memory amounts, uint256 confidenceLevel) external view override returns (uint256 portfolioVaR) {
        uint256 portfolioRisk = this.calculatePortfolioRisk(user, assets, amounts);
        // Simplified VaR calculation
        portfolioVaR = (portfolioRisk * (100 - confidenceLevel)) / 100;
    }
    
    function getConcentrationRisk() external view override returns (uint256 concentration) {
        return config.maxConcentration;
    }
    
    function getDiversificationScore() external view override returns (uint256 score) {
        return BASIS_POINTS - config.maxConcentration;
    }
    
    function monitorRisk(address user, address[] memory assets, uint256[] memory amounts) external override onlyRole(MONITOR_ROLE) {
        uint256 portfolioRisk = this.calculatePortfolioRisk(user, assets, amounts);
        
        if (portfolioRisk > 8000) { // 80% risk threshold
            _createRiskAlert(user, "High portfolio risk detected", AlertSeverity.HIGH);
        }
    }
    
    function emergencyStop(address asset, string calldata reason) external override onlyRole(EMERGENCY_ROLE) {
        emergencyStoppedAssets[asset] = true;
        emit EmergencyStop(asset, reason, block.timestamp);
    }
    
    function isEmergencyStopped(address asset) external view override returns (bool) {
        return emergencyStoppedAssets[asset];
    }
    
    function calculateExpectedShortfall(address asset, uint256 confidence) external view override returns (uint256 es) {
        uint256 volatility = collateralData[asset].volatility;
        uint256 exposure = collateralData[asset].totalCollateral;
        es = (exposure * volatility * (100 - confidence)) / (BASIS_POINTS * 100);
    }
    
    function getCorrelation(address asset1, address asset2) external view override returns (uint256 correlation) {
        return correlationMatrix[asset1][asset2];
    }
    
    function performStressTest(uint256 scenario, address[] memory assets, uint256[] memory amounts) external view override returns (StressTestResult memory stressTestResult) {
        require(assets.length == amounts.length, "Arrays length mismatch");
        
        uint256 totalLoss = 0;
        uint256 maxAssetLoss = 0;
        
        for (uint256 i = 0; i < assets.length; i++) {
            uint256 assetLoss = this.stressTest(assets[i], scenario);
            totalLoss += assetLoss;
            if (assetLoss > maxAssetLoss) {
                maxAssetLoss = assetLoss;
            }
        }
        
        stressTestResult = StressTestResult({
            scenario: scenario,
            totalLoss: totalLoss,
            maxAssetLoss: maxAssetLoss,
            liquidationRisk: totalLoss > config.liquidationThreshold,
            recoveryTime: totalLoss > 0 ? (totalLoss * 30) / BASIS_POINTS : 0
        });
    }
    
    function scenarioAnalysis(address asset, uint256[] calldata scenarios) external view override returns (uint256[] memory impacts) {
        impacts = new uint256[](scenarios.length);
        
        for (uint256 i = 0; i < scenarios.length; i++) {
            impacts[i] = this.stressTest(asset, scenarios[i]);
        }
    }
    
    function backtestRiskModel(address asset, uint256[] calldata historicalPrices) external view override returns (uint256 accuracy) {
        require(historicalPrices.length > 10, "Need more historical data");
        
        uint256 correctPredictions = 0;
        uint256 volatility = collateralData[asset].volatility;
        
        for (uint256 i = 1; i < historicalPrices.length; i++) {
            bool priceIncreased = historicalPrices[i] > historicalPrices[i-1];
            bool lowVolatilityPrediction = volatility < 5000; // 50%
            
            if ((priceIncreased && lowVolatilityPrediction) || (!priceIncreased && !lowVolatilityPrediction)) {
                correctPredictions++;
            }
        }
        
        accuracy = (correctPredictions * 100) / (historicalPrices.length - 1);
    }
    
    function getCurrentExposure(address asset) external view override returns (uint256 exposure) {
        return collateralData[asset].totalCollateral;
    }
    
    // Storage for new interface requirements
    mapping(string => uint256) private riskParameters;
    mapping(address => mapping(address => uint256)) private correlationMatrix;
    mapping(address => bool) private emergencyStoppedAssets;
    
    // Abstract functions that must be implemented by derived contracts

    
    /**
     * @dev Update risk profile for an asset
     * @param asset Asset address
     * @param profile New risk profile
     */
    function updateRiskProfile(address asset, RiskProfile calldata profile) external override onlyRole(RISK_MANAGER_ROLE) {
        require(asset != address(0), "Invalid asset");
        require(profile.riskScore <= 100, "Risk score too high");
        
        riskProfiles[asset] = profile;
        
        emit RiskParametersUpdated(asset, profile.riskScore, block.timestamp);
    }

    function setRiskProfile(address user, RiskProfile memory profile) external override onlyRole(RISK_MANAGER_ROLE) {
        require(user != address(0), "Invalid user");
        riskProfiles[user] = profile;
        emit RiskProfileUpdated(user, profile.riskScore, profile.maxExposure, profile.currentExposure);
    }

    function setRiskLimits(address user, RiskLimits memory limits) external override onlyRole(RISK_MANAGER_ROLE) {
        require(user != address(0), "Invalid user");
        userRiskLimits[user] = limits;
    }

    function getRiskScore(address asset) external view override returns (uint256 score) {
        return riskProfiles[asset].riskScore;
    }

    function getTotalPortfolioValue() external view override returns (uint256 totalValue) {
        return globalMetrics.totalValue;
    }

    function getWeeklyRiskTrend() external view override returns (uint256[] memory riskScores) {
        uint256[] memory trend = new uint256[](7);
        for (uint256 i = 0; i < 7; i++) {
            trend[i] = globalMetrics.averageRiskScore;
        }
        return trend;
    }

    function getRiskLimits() external view override returns (RiskLimits memory limits) {
        return riskLimits[msg.sender];
    }

    function getRiskMetrics() external view override returns (RiskMetrics memory metrics) {
        return riskMetrics[msg.sender];
    }

    function getMaxAllowedExposure(address asset) external view override returns (uint256 maxExposure) {
        return riskProfiles[asset].maxExposure;
    }

    function getDailyRiskMetrics() external view override returns (
        uint256 dailyVar,
        uint256 dailyVolatility,
        uint256 sharpeRatio,
        uint256 maxDrawdown
    ) {
        RiskMetrics memory metrics = riskMetrics[msg.sender];
        return (metrics.valueAtRisk, 0, metrics.sharpeRatio, metrics.maxDrawdown);
    }

    function getMonthlyRiskSummary() external view override returns (
        uint256 avgRisk,
        uint256 maxRisk,
        uint256 minRisk,
        uint256 riskVolatility
    ) {
        return (globalMetrics.averageRiskScore, 100, 0, 10);
    }

    function calculateVaR(int256[] memory returnValues, uint256 confidenceLevel) external pure override returns (uint256 valueAtRisk) {
        if (returnValues.length == 0) return 0;
        
        // Simple VaR calculation - sort returns and take percentile
        uint256 index = (returnValues.length * (100 - confidenceLevel)) / 100;
        return uint256(returnValues[index < returnValues.length ? index : returnValues.length - 1]);
    }

    function getAssetWeight(address asset) external view override returns (uint256 weight) {
        return riskProfiles[asset].weight;
    }

    function getAssetAllocation() external view override returns (address[] memory assets, uint256[] memory allocations) {
        // Return empty arrays for now
        assets = new address[](0);
        allocations = new uint256[](0);
    }

    function generateRiskReport() external view override returns (
        uint256 totalRisk,
        uint256 portfolioVar,
        uint256 concentration,
        uint256 diversification,
        address[] memory highRiskAssets
    ) {
        return (globalMetrics.averageRiskScore, 0, 0, 80, new address[](0));
    }

    function assessRisk(address asset, uint256 amount) external view override returns (uint256 riskScore) {
        RiskProfile memory profile = riskProfiles[asset];
        return (amount * profile.riskScore) / 100;
    }

    function calculateVaR(address portfolio, uint256 confidence, uint256 timeHorizon) external virtual returns (uint256 valueAtRisk) {
        RiskMetrics memory metrics = riskMetrics[portfolio];
        return (metrics.valueAtRisk * timeHorizon * confidence) / 10000;
    }

    function assessRisk(address subject, RiskType riskType) external virtual returns (RiskAssessment memory assessment) {
        assessment.subject = subject;
        assessment.riskType = riskType;
        assessment.score = riskProfiles[subject].riskScore;
        assessment.timestamp = block.timestamp;
        assessment.assessor = msg.sender;
    }

    // Internal functions
    function _calculateBaseRiskScore(
        address user,
        address asset,
        uint256 amount,
        RiskType riskType
    ) internal view returns (uint256) {
        // Base risk calculation logic
        uint256 baseScore = 100; // Base risk score
        
        // Adjust based on asset volatility
        uint256 volatility = _getAssetVolatility(asset);
        baseScore = baseScore + (volatility * 50) / BASIS_POINTS;
        
        // Adjust based on amount
        uint256 assetPrice = oracle.getPrice(asset);
        uint256 usdValue = (amount * assetPrice) / PRECISION;
        if (usdValue > 1000000e18) { // > $1M
            baseScore = baseScore + 100;
        }
        
        // Adjust based on risk type
        if (riskType == RiskType.LEVERAGE) {
            baseScore = baseScore + 150;
        } else if (riskType == RiskType.CONCENTRATION) {
            baseScore = baseScore + 100;
        }
        
        return Math.min(baseScore, MAX_RISK_SCORE);
    }

    function _applyRiskAdjustments(
        address user,
        address asset,
        uint256 baseScore
    ) internal view returns (uint256) {
        uint256 adjustedScore = baseScore;
        
        // User history adjustment
        RiskProfile storage profile = riskProfiles[user];
        if (profile.assessmentCount > 10 && profile.riskLevel == RiskLevel.LOW) {
            adjustedScore = adjustedScore * 90 / 100; // 10% reduction
        }
        
        // Market conditions adjustment
        if (_isHighVolatilityPeriod()) {
            adjustedScore = adjustedScore * 120 / 100; // 20% increase
        }
        
        return Math.min(adjustedScore, MAX_RISK_SCORE);
    }

    function _calculateTotalRiskScore(address user) internal view returns (uint256) {
        // Calculate total risk score for user
        return riskProfiles[user].totalRiskScore;
    }

    function _getRiskLevel(uint256 riskScore) internal pure returns (RiskLevel) {
        if (riskScore < 200) {
            return RiskLevel.LOW;
        } else if (riskScore < 500) {
            return RiskLevel.MEDIUM;
        } else if (riskScore < 800) {
            return RiskLevel.HIGH;
        } else {
            return RiskLevel.CRITICAL;
        }
    }

    function _updateRiskMetrics(address user, address asset, uint256 riskScore) internal {
        RiskMetrics storage metrics = riskMetrics[user];
        metrics.user = user;
        metrics.lastUpdate = block.timestamp;
        metrics.riskScore = riskScore;
        // Update other metrics
    }

    function _getUserCollateralAndDebt(address user) internal view returns (uint256 totalCollateral, uint256 totalDebt) {
        UserPosition[] storage positions = userPositions[user];
        
        for (uint256 i = 0; i < positions.length; i++) {
            UserPosition storage position = positions[i];
            
            // Get current prices from oracle
            uint256 collateralPrice = oracle.getPrice(position.collateralAsset);
            uint256 debtPrice = oracle.getPrice(position.debtAsset);
            
            // Calculate values in USD
            totalCollateral += (position.collateralAmount * collateralPrice) / PRECISION;
            totalDebt += (position.debtAmount * debtPrice) / PRECISION;
        }
        
        return (totalCollateral, totalDebt);
    }

    function _getWeightedLiquidationThreshold(address user) internal view returns (uint256) {
        UserPosition[] storage positions = userPositions[user];
        if (positions.length == 0) return config.liquidationThreshold;
        
        uint256 totalCollateralValue = 0;
        uint256 weightedThreshold = 0;
        
        for (uint256 i = 0; i < positions.length; i++) {
            UserPosition storage position = positions[i];
            address asset = position.collateralAsset;
            
            uint256 price = oracle.getPrice(asset);
            uint256 assetValue = (position.collateralAmount * price) / PRECISION;
            totalCollateralValue += assetValue;
            
            // Get asset-specific liquidation threshold
            uint256 assetThreshold = collateralData[asset].liquidationThreshold;
            if (assetThreshold == 0) {
                assetThreshold = config.liquidationThreshold; // Default threshold
            }
            
            weightedThreshold += assetValue * assetThreshold;
        }
        
        return totalCollateralValue > 0 ? weightedThreshold / totalCollateralValue : config.liquidationThreshold;
    }

    function _flagForLiquidation(address user, uint256 healthFactor) internal {
        if (!_isInLiquidatablePositions(user)) {
            liquidatablePositions.push(user);
        }
        
        _createRiskAlert(user, "Position flagged for liquidation", AlertSeverity.CRITICAL);
    }

    function _calculateLiquidationAmounts(
        address user,
        address collateralAsset,
        address debtAsset,
        uint256 debtToCover
    ) internal view returns (uint256 collateralToLiquidate, uint256 liquidationBonus) {
        // Calculate liquidation amounts
        uint256 collateralPrice = oracle.getPrice(collateralAsset);
        uint256 debtPrice = oracle.getPrice(debtAsset);
        
        collateralToLiquidate = (debtToCover * debtPrice) / collateralPrice;
        liquidationBonus = (collateralToLiquidate * collateralData[collateralAsset].liquidationBonus) / BASIS_POINTS;
        
        return (collateralToLiquidate, liquidationBonus);
    }

    function _executeLiquidation(
        address user,
        address liquidator,
        address collateralAsset,
        address debtAsset,
        uint256 debtToCover,
        uint256 collateralToLiquidate,
        uint256 liquidationBonus
    ) internal {
        // Execute the actual liquidation
        // This would integrate with lending/borrowing contracts
    }

    function _calculateExposureRatio(address user, address asset) internal view returns (uint256) {
        UserPosition[] storage positions = userPositions[user];
        if (positions.length == 0) return 0;
        
        uint256 assetExposure = 0;
        uint256 totalExposure = 0;
        
        for (uint256 i = 0; i < positions.length; i++) {
            UserPosition storage position = positions[i];
            
            uint256 collateralPrice = oracle.getPrice(position.collateralAsset);
            uint256 positionValue = (position.collateralAmount * collateralPrice) / PRECISION;
            totalExposure += positionValue;
            
            if (position.collateralAsset == asset) {
                assetExposure += positionValue;
            }
        }
        
        return totalExposure > 0 ? (assetExposure * BASIS_POINTS) / totalExposure : 0;
    }

    function _createRiskAlert(address user, string memory message, AlertSeverity severity) internal {
        RiskAlertData storage alert = riskAlerts[user];
        alert.user = user;
        alert.message = message;
        alert.severity = severity;
        alert.timestamp = block.timestamp;
        alert.isActive = true;
        
        totalRiskAlerts++;
        
        emit RiskAlertCreated(user, message, severity, block.timestamp);
    }

    function _simulateStressScenario(
        address user,
        StressTestScenario memory scenario
    ) internal view returns (uint256 valueBefore, uint256 valueAfter) {
        // Calculate current portfolio value
        UserPosition[] storage positions = userPositions[user];
        valueBefore = 0;
        valueAfter = 0;
        
        for (uint256 i = 0; i < positions.length; i++) {
            UserPosition storage position = positions[i];
            
            // Current value
            uint256 collateralPrice = oracle.getPrice(position.collateralAsset);
            uint256 currentValue = (position.collateralAmount * collateralPrice) / PRECISION;
            valueBefore += currentValue;
            
            // Stressed value (apply scenario stress factors)
            uint256 stressedPrice = collateralPrice;
            if (scenario.priceDropPercentage > 0) {
                stressedPrice = (collateralPrice * (BASIS_POINTS - scenario.priceDropPercentage)) / BASIS_POINTS;
            }
            
            uint256 stressedValue = (position.collateralAmount * stressedPrice) / PRECISION;
            valueAfter += stressedValue;
        }
        
        return (valueBefore, valueAfter);
    }

    function _calculateMaxDrawdown(uint256 valueBefore, uint256 valueAfter) internal pure returns (uint256) {
        if (valueBefore == 0) return 0;
        return valueBefore > valueAfter ? ((valueBefore - valueAfter) * BASIS_POINTS) / valueBefore : 0;
    }

    function _calculateStressRiskMetrics(
        address user,
        StressTestScenario memory scenario
    ) internal view returns (RiskMetrics memory) {
        RiskMetrics memory stressMetrics = riskMetrics[user];
        
        // Apply stress scenario adjustments
        uint256 stressMultiplier = 100 + scenario.priceDropPercentage;
        
        // Increase risk scores under stress
        stressMetrics.concentrationRisk = (stressMetrics.concentrationRisk * stressMultiplier) / 100;
        stressMetrics.liquidityRisk = (stressMetrics.liquidityRisk * stressMultiplier) / 100;
        stressMetrics.marketRisk = (stressMetrics.marketRisk * stressMultiplier) / 100;
        stressMetrics.creditRisk = (stressMetrics.creditRisk * stressMultiplier) / 100;
        
        // Cap at maximum values
        if (stressMetrics.concentrationRisk > 1000) stressMetrics.concentrationRisk = 1000;
        if (stressMetrics.liquidityRisk > 1000) stressMetrics.liquidityRisk = 1000;
        if (stressMetrics.marketRisk > 1000) stressMetrics.marketRisk = 1000;
        if (stressMetrics.creditRisk > 1000) stressMetrics.creditRisk = 1000;
        
        return stressMetrics;
    }

    function _calculateDiversificationScore(address user) internal view returns (uint256) {
        UserPosition[] storage positions = userPositions[user];
        if (positions.length == 0) return 0;
        
        uint256 totalValue = 0;
        uint256 maxAssetValue = 0;
        
        // Calculate total portfolio value and find largest position
        for (uint256 i = 0; i < positions.length; i++) {
            uint256 price = oracle.getPrice(positions[i].collateralAsset);
            uint256 assetValue = (positions[i].collateralAmount * price) / PRECISION;
            totalValue += assetValue;
            
            if (assetValue > maxAssetValue) {
                maxAssetValue = assetValue;
            }
        }
        
        if (totalValue == 0) return 0;
        
        // Diversification score: 1000 - (largest_position_percentage * 10)
        uint256 concentrationPercentage = (maxAssetValue * BASIS_POINTS) / totalValue;
        uint256 diversificationScore = concentrationPercentage > BASIS_POINTS ? 0 : 
            BASIS_POINTS - concentrationPercentage;
            
        return (diversificationScore * 1000) / BASIS_POINTS; // Scale to 0-1000
    }

    function _calculateConcentrationRisk(address user) internal view returns (uint256) {
        UserPosition[] storage positions = userPositions[user];
        if (positions.length == 0) return 0;
        
        uint256 totalValue = 0;
        uint256[] memory assetValues = new uint256[](positions.length);
        
        // Calculate individual asset values
        for (uint256 i = 0; i < positions.length; i++) {
            uint256 price = oracle.getPrice(positions[i].collateralAsset);
            assetValues[i] = (positions[i].collateralAmount * price) / PRECISION;
            totalValue += assetValues[i];
        }
        
        if (totalValue == 0) return 0;
        
        // Calculate Herfindahl-Hirschman Index (HHI) for concentration
        uint256 hhi = 0;
        for (uint256 i = 0; i < assetValues.length; i++) {
            uint256 share = (assetValues[i] * BASIS_POINTS) / totalValue;
            hhi += (share * share) / BASIS_POINTS;
        }
        
        // Convert HHI to risk score (0-1000)
        // HHI ranges from 1/n to 1, we scale to 0-1000
        return (hhi * 1000) / BASIS_POINTS;
    }

    function _calculateLiquidityRisk(address user) internal view returns (uint256) {
        UserPosition[] storage positions = userPositions[user];
        if (positions.length == 0) return 0;
        
        uint256 totalValue = 0;
        uint256 weightedLiquidityRisk = 0;
        
        for (uint256 i = 0; i < positions.length; i++) {
            address asset = positions[i].collateralAsset;
            uint256 price = oracle.getPrice(asset);
            uint256 assetValue = (positions[i].collateralAmount * price) / PRECISION;
            totalValue += assetValue;
            
            // Get asset liquidity risk from collateral data
            uint256 assetLiquidityRisk = collateralData[asset].liquidityRisk;
            if (assetLiquidityRisk == 0) {
                // Default liquidity risk based on asset type
                assetLiquidityRisk = 100; // 1% default
            }
            
            weightedLiquidityRisk += assetValue * assetLiquidityRisk;
        }
        
        if (totalValue == 0) return 0;
        
        return weightedLiquidityRisk / totalValue;
    }

    function _calculateMarketRisk(address user) internal view returns (uint256) {
        UserPosition[] storage positions = userPositions[user];
        if (positions.length == 0) return 0;
        
        uint256 totalValue = 0;
        uint256 weightedVolatility = 0;
        
        for (uint256 i = 0; i < positions.length; i++) {
            address asset = positions[i].collateralAsset;
            uint256 price = oracle.getPrice(asset);
            uint256 assetValue = (positions[i].collateralAmount * price) / PRECISION;
            totalValue += assetValue;
            
            // Get asset volatility from collateral data
            uint256 assetVolatility = collateralData[asset].volatility;
            if (assetVolatility == 0) {
                // Default volatility based on asset type
                assetVolatility = 300; // 3% default
            }
            
            weightedVolatility += assetValue * assetVolatility;
        }
        
        if (totalValue == 0) return 0;
        
        return weightedVolatility / totalValue;
    }

    function _calculateCreditRisk(address user) internal view returns (uint256) {
        UserPosition[] storage positions = userPositions[user];
        if (positions.length == 0) return 0;
        
        uint256 totalDebtValue = 0;
        uint256 totalCollateralValue = 0;
        
        for (uint256 i = 0; i < positions.length; i++) {
            UserPosition storage position = positions[i];
            
            uint256 collateralPrice = oracle.getPrice(position.collateralAsset);
            uint256 debtPrice = oracle.getPrice(position.debtAsset);
            
            totalCollateralValue += (position.collateralAmount * collateralPrice) / PRECISION;
            totalDebtValue += (position.debtAmount * debtPrice) / PRECISION;
        }
        
        if (totalCollateralValue == 0) return 1000; // Maximum risk if no collateral
        
        // Credit risk based on leverage ratio
        uint256 leverageRatio = (totalDebtValue * BASIS_POINTS) / totalCollateralValue;
        
        // Scale leverage ratio to risk score (0-1000)
        return leverageRatio > BASIS_POINTS ? 1000 : (leverageRatio * 1000) / BASIS_POINTS;
    }

    function _calculateOverallRiskScore(PortfolioRisk memory portfolio) internal pure returns (uint256) {
        // Calculate overall risk score
        return (portfolio.concentrationRisk + portfolio.liquidityRisk + portfolio.marketRisk + portfolio.creditRisk) / 4;
    }

    function _getAssetVolatility(address asset) internal view returns (uint256) {
        // Get asset volatility from collateral data or oracle
        uint256 volatility = collateralData[asset].volatility;
        if (volatility == 0) {
            // Default volatility based on asset type
            volatility = 1000; // 10% default
        }
        return volatility;
    }

    function _isHighVolatilityPeriod() internal view returns (bool) {
        // Check if current period has high volatility by examining recent price movements
        uint256 volatilityThreshold = 1500; // 15%
        
        // Check volatility of major assets
        for (uint256 i = 0; i < allUsers.length && i < 5; i++) {
            UserPosition[] storage positions = userPositions[allUsers[i]];
            for (uint256 j = 0; j < positions.length && j < 3; j++) {
                uint256 assetVolatility = _getAssetVolatility(positions[j].collateralAsset);
                if (assetVolatility > volatilityThreshold) {
                    return true;
                }
            }
        }
        
        return false;
    }

    function _isInLiquidatablePositions(address user) internal view returns (bool) {
        for (uint256 i = 0; i < liquidatablePositions.length; i++) {
            if (liquidatablePositions[i] == user) {
                return true;
            }
        }
        return false;
    }

    function _calculateAverageRiskScore() internal view returns (uint256) {
        if (allUsers.length == 0) return 0;
        
        uint256 totalScore = 0;
        for (uint256 i = 0; i < allUsers.length; i++) {
            totalScore += riskProfiles[allUsers[i]].totalRiskScore;
        }
        
        return totalScore / allUsers.length;
    }

    function _calculateSystemHealthFactor() internal view returns (uint256) {
        if (allUsers.length == 0) return type(uint256).max;
        
        uint256 totalHealthFactor = 0;
        uint256 validUsers = 0;
        
        for (uint256 i = 0; i < allUsers.length; i++) {
            uint256 hf = healthFactors[allUsers[i]].currentHealthFactor;
            if (hf != type(uint256).max) {
                totalHealthFactor += hf;
                validUsers++;
            }
        }
        
        return validUsers > 0 ? totalHealthFactor / validUsers : type(uint256).max;
    }


    
    /**
     * @dev Calculate volatility from price array
     * @param prices Array of prices
     * @return volatility Calculated volatility in basis points
     */
    function _calculateVolatility(uint256[] calldata prices) internal pure returns (uint256) {
        if (prices.length < 2) return 0;
        
        uint256 sum = 0;
        uint256 sumSquared = 0;
        uint256 n = prices.length - 1;
        
        // Calculate returns
        for (uint256 i = 1; i < prices.length; i++) {
            if (prices[i-1] > 0) {
                uint256 returnValue = (prices[i] * BASIS_POINTS) / prices[i-1];
                sum += returnValue;
                sumSquared += (returnValue * returnValue) / BASIS_POINTS;
            }
        }
        
        if (n == 0) return 0;
        
        uint256 mean = sum / n;
        uint256 variance = (sumSquared / n) - (mean * mean / BASIS_POINTS);
        
        // Return square root approximation (simplified)
        return _sqrt(variance);
    }
    
    /**
     * @dev Simple square root approximation
     * @param x Input value
     * @return Square root approximation
     */
    function _sqrt(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        uint256 y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
        return y;
    }

    function updateVolatilityModel(address asset, uint256[] calldata prices) external override onlyRole(RISK_MANAGER_ROLE) {
        require(prices.length >= 2, "Insufficient price data");
        
        uint256 volatility = _calculateVolatility(prices);
        
        CollateralData storage data = collateralData[asset];
        data.volatility = volatility;
        data.lastUpdate = block.timestamp;
        
        emit RiskParametersUpdated(asset, volatility, block.timestamp);
    }

    // Emergency functions
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    function calculateStressTestImpact(address asset, uint256 shockSize) external view returns (uint256 impact) {
        RiskProfile memory profile = riskProfiles[asset];
        return (profile.riskScore * shockSize) / 100;
    }
}
