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
abstract contract RiskManagement is IRiskManagement, AccessControl, ReentrancyGuard, Pausable {
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
    mapping(address => RiskAlert) public riskAlerts;
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
        RiskAlert storage alert = riskAlerts[user];
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
            // Emergency liquidation logic
            liquidatedAmount += 1000e18; // Placeholder amount
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

    function getRiskAlert(address user) external view returns (RiskAlert memory) {
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

    // Abstract functions that must be implemented by derived contracts
    function assessRisk(address subject, RiskType riskType) external virtual returns (RiskAssessment memory assessment);
    function updateRiskProfile(address user, RiskProfile calldata profile) external virtual;
    function performStressTest(bytes32 testId, address portfolio) external virtual returns (StressTestResults memory results);
    function calculateVaR(address portfolio, uint256 confidence, uint256 timeHorizon) external virtual returns (uint256 valueAtRisk);

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
        // Calculate user's total collateral and debt
        // This would integrate with lending/borrowing contracts
        return (0, 0); // Placeholder
    }

    function _getWeightedLiquidationThreshold(address user) internal view returns (uint256) {
        // Calculate weighted liquidation threshold based on user's collateral
        return config.liquidationThreshold; // Placeholder
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
        // Calculate exposure ratio
        return 0; // Placeholder
    }

    function _createRiskAlert(address user, string memory message, AlertSeverity severity) internal {
        RiskAlert storage alert = riskAlerts[user];
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
        // Simulate stress test scenario
        return (0, 0); // Placeholder
    }

    function _calculateMaxDrawdown(uint256 valueBefore, uint256 valueAfter) internal pure returns (uint256) {
        if (valueBefore == 0) return 0;
        return valueBefore > valueAfter ? ((valueBefore - valueAfter) * BASIS_POINTS) / valueBefore : 0;
    }

    function _calculateStressRiskMetrics(
        address user,
        StressTestScenario memory scenario
    ) internal view returns (RiskMetrics memory) {
        // Calculate stress test risk metrics
        return riskMetrics[user]; // Placeholder
    }

    function _calculateDiversificationScore(address user) internal view returns (uint256) {
        // Calculate portfolio diversification score
        return 500; // Placeholder
    }

    function _calculateConcentrationRisk(address user) internal view returns (uint256) {
        // Calculate concentration risk
        return 300; // Placeholder
    }

    function _calculateLiquidityRisk(address user) internal view returns (uint256) {
        // Calculate liquidity risk
        return 200; // Placeholder
    }

    function _calculateMarketRisk(address user) internal view returns (uint256) {
        // Calculate market risk
        return 400; // Placeholder
    }

    function _calculateCreditRisk(address user) internal view returns (uint256) {
        // Calculate credit risk
        return 250; // Placeholder
    }

    function _calculateOverallRiskScore(PortfolioRisk memory portfolio) internal pure returns (uint256) {
        // Calculate overall risk score
        return (portfolio.concentrationRisk + portfolio.liquidityRisk + portfolio.marketRisk + portfolio.creditRisk) / 4;
    }

    function _getAssetVolatility(address asset) internal view returns (uint256) {
        // Get asset volatility from oracle or historical data
        return 1000; // Placeholder: 10%
    }

    function _isHighVolatilityPeriod() internal view returns (bool) {
        // Check if current period has high volatility
        return false; // Placeholder
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

    // Emergency functions
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
}
