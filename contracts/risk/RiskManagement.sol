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

    // Emergency functions
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
}
