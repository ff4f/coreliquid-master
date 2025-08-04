// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title ComprehensiveRiskEngine
 * @dev Advanced risk management system with real-time monitoring and dynamic adjustments
 */
contract ComprehensiveRiskEngine is AccessControl, ReentrancyGuard {
    using Math for uint256;
    
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant RISK_MANAGER_ROLE = keccak256("RISK_MANAGER_ROLE");
    bytes32 public constant LIQUIDATOR_ROLE = keccak256("LIQUIDATOR_ROLE");
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");
    
    uint256 public constant PRECISION = 1e18;
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant MAX_LTV = 9500; // 95%
    uint256 public constant MIN_HEALTH_FACTOR = 1e18; // 1.0
    
    enum RiskLevel {
        LOW,
        MEDIUM,
        HIGH,
        CRITICAL,
        EMERGENCY
    }
    
    enum AlertType {
        HEALTH_FACTOR_WARNING,
        LIQUIDATION_THRESHOLD,
        CONCENTRATION_RISK,
        VOLATILITY_SPIKE,
        LIQUIDITY_SHORTAGE,
        ORACLE_DEVIATION,
        SYSTEM_STRESS
    }
    
    struct AssetRiskParams {
        uint256 liquidationThreshold; // LTV at which liquidation can occur
        uint256 liquidationBonus; // Bonus for liquidators
        uint256 reserveFactor; // Percentage of interest going to reserves
        uint256 maxLTV; // Maximum loan-to-value ratio
        uint256 volatilityThreshold; // Price volatility threshold
        uint256 concentrationLimit; // Max concentration in protocol
        bool isActive;
        bool borrowingEnabled;
        bool liquidationEnabled;
    }
    
    struct UserRiskProfile {
        uint256 totalCollateralValue;
        uint256 totalDebtValue;
        uint256 healthFactor;
        uint256 liquidationThreshold;
        uint256 maxBorrowCapacity;
        uint256 concentrationRisk;
        RiskLevel riskLevel;
        uint256 lastUpdate;
        bool isAtRisk;
    }
    
    struct MarketRiskMetrics {
        uint256 totalSupply;
        uint256 totalBorrow;
        uint256 utilizationRate;
        uint256 averageHealthFactor;
        uint256 liquidationsLast24h;
        uint256 volatilityIndex;
        uint256 liquidityIndex;
        RiskLevel marketRiskLevel;
        uint256 lastUpdate;
    }
    
    struct RiskAlert {
        uint256 alertId;
        AlertType alertType;
        address user;
        address asset;
        uint256 severity; // 1-10 scale
        string message;
        uint256 timestamp;
        bool isResolved;
        uint256 resolvedAt;
    }
    
    struct LiquidationData {
        address user;
        address asset;
        uint256 debtToCover;
        uint256 collateralToLiquidate;
        uint256 healthFactorBefore;
        uint256 healthFactorAfter;
        uint256 liquidationBonus;
        uint256 timestamp;
    }
    
    struct StressTestScenario {
        uint256 scenarioId;
        string name;
        mapping(address => uint256) priceShocks; // Asset -> price change percentage
        uint256 liquidityShock; // Liquidity reduction percentage
        uint256 demandShock; // Demand change percentage
        uint256 expectedLiquidations;
        uint256 expectedLosses;
        bool isActive;
    }
    
    // Storage
    mapping(address => AssetRiskParams) public assetRiskParams;
    mapping(address => UserRiskProfile) public userRiskProfiles;
    mapping(address => MarketRiskMetrics) public marketMetrics;
    mapping(uint256 => RiskAlert) public riskAlerts;
    mapping(address => uint256[]) public userAlerts;
    mapping(uint256 => LiquidationData) public liquidationHistory;
    mapping(uint256 => StressTestScenario) stressTestScenarios;
    
    // Risk monitoring
    mapping(address => uint256) public assetPrices;
    mapping(address => uint256) public priceVolatility;
    mapping(address => uint256) public liquidityDepth;
    mapping(address => uint256) public lastPriceUpdate;
    
    // System-wide risk parameters
    uint256 public globalRiskMultiplier = PRECISION;
    uint256 public systemUtilizationCap = 8500; // 85%
    uint256 public emergencyLiquidationThreshold = 9000; // 90%
    uint256 public maxConcentrationRisk = 2000; // 20%
    
    // Counters
    uint256 public alertCounter;
    uint256 public liquidationCounter;
    uint256 public stressTestCounter;
    
    // Emergency controls
    bool public emergencyMode;
    bool public liquidationsPaused;
    bool public borrowingPaused;
    
    event RiskParametersUpdated(address indexed asset, uint256 liquidationThreshold, uint256 maxLTV);
    event RiskAlertTriggered(uint256 indexed alertId, AlertType alertType, address indexed user, uint256 severity);
    event UserRiskProfileUpdated(address indexed user, uint256 healthFactor, RiskLevel riskLevel);
    event LiquidationExecuted(address indexed user, address indexed asset, uint256 debtCovered, uint256 collateralLiquidated);
    event EmergencyModeActivated(string reason);
    event StressTestCompleted(uint256 indexed scenarioId, uint256 expectedLiquidations, uint256 expectedLosses);
    
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(RISK_MANAGER_ROLE, msg.sender);
    }
    
    /**
     * @dev Initialize risk parameters for an asset
     */
    function initializeAssetRisk(
        address asset,
        uint256 liquidationThreshold,
        uint256 liquidationBonus,
        uint256 reserveFactor,
        uint256 maxLTV,
        uint256 volatilityThreshold,
        uint256 concentrationLimit
    ) external onlyRole(ADMIN_ROLE) {
        require(asset != address(0), "Invalid asset");
        require(liquidationThreshold <= MAX_LTV, "Invalid liquidation threshold");
        require(maxLTV <= MAX_LTV, "Invalid max LTV");
        
        assetRiskParams[asset] = AssetRiskParams({
            liquidationThreshold: liquidationThreshold,
            liquidationBonus: liquidationBonus,
            reserveFactor: reserveFactor,
            maxLTV: maxLTV,
            volatilityThreshold: volatilityThreshold,
            concentrationLimit: concentrationLimit,
            isActive: true,
            borrowingEnabled: true,
            liquidationEnabled: true
        });
        
        emit RiskParametersUpdated(asset, liquidationThreshold, maxLTV);
    }
    
    /**
     * @dev Calculate user's health factor and risk profile
     */
    function calculateUserRisk(address user) external onlyRole(RISK_MANAGER_ROLE) returns (UserRiskProfile memory) {
        uint256 totalCollateralValue = 0;
        uint256 totalDebtValue = 0;
        uint256 weightedLiquidationThreshold = 0;
        uint256 concentrationRisk = 0;
        
        // Get user positions from accounting system
        address[] memory collateralAssets = accountingSystem.getUserCollateralAssets(user);
        address[] memory debtAssets = accountingSystem.getUserDebtAssets(user);
        
        // Calculate total collateral value
        for (uint256 i = 0; i < collateralAssets.length; i++) {
            address asset = collateralAssets[i];
            uint256 balance = accountingSystem.getUserCollateralBalance(user, asset);
            if (balance > 0) {
                uint256 price = priceOracle.getPrice(asset);
                uint256 assetValue = (balance * price) / PRECISION;
                totalCollateralValue += assetValue;
                
                AssetRiskConfig memory config = assetRiskConfigs[asset];
                weightedLiquidationThreshold += assetValue * config.liquidationThreshold;
            }
        }
        
        // Calculate total debt value
        for (uint256 i = 0; i < debtAssets.length; i++) {
            address asset = debtAssets[i];
            uint256 balance = accountingSystem.getUserDebtBalance(user, asset);
            if (balance > 0) {
                uint256 price = priceOracle.getPrice(asset);
                totalDebtValue += (balance * price) / PRECISION;
            }
        }
        
        // Calculate concentration risk
        concentrationRisk = _calculateConcentrationRisk(user, collateralAssets, totalCollateralValue);
        
        // Finalize weighted liquidation threshold
        if (totalCollateralValue > 0) {
            weightedLiquidationThreshold = weightedLiquidationThreshold / totalCollateralValue;
        }
        
        uint256 healthFactor = totalDebtValue > 0 ? 
            (totalCollateralValue * weightedLiquidationThreshold) / (totalDebtValue * BASIS_POINTS) : 
            type(uint256).max;
        
        uint256 maxBorrowCapacity = (totalCollateralValue * weightedLiquidationThreshold) / BASIS_POINTS;
        
        RiskLevel riskLevel = _determineRiskLevel(healthFactor, concentrationRisk);
        
        UserRiskProfile memory profile = UserRiskProfile({
            totalCollateralValue: totalCollateralValue,
            totalDebtValue: totalDebtValue,
            healthFactor: healthFactor,
            liquidationThreshold: weightedLiquidationThreshold,
            maxBorrowCapacity: maxBorrowCapacity,
            concentrationRisk: concentrationRisk,
            riskLevel: riskLevel,
            lastUpdate: block.timestamp,
            isAtRisk: healthFactor < MIN_HEALTH_FACTOR * 120 / 100 // 1.2 threshold
        });
        
        userRiskProfiles[user] = profile;
        
        // Trigger alerts if necessary
        if (profile.isAtRisk) {
            _triggerRiskAlert(AlertType.HEALTH_FACTOR_WARNING, user, address(0), 7, "Health factor below safe threshold");
        }
        
        emit UserRiskProfileUpdated(user, healthFactor, riskLevel);
        
        return profile;
    }
    
    /**
     * @dev Check if liquidation is allowed for a user
     */
    function isLiquidationAllowed(address user, address asset) external view returns (bool, uint256, uint256) {
        if (liquidationsPaused || emergencyMode) {
            return (false, 0, 0);
        }
        
        UserRiskProfile memory profile = userRiskProfiles[user];
        AssetRiskParams memory params = assetRiskParams[asset];
        
        if (!params.liquidationEnabled || profile.healthFactor >= MIN_HEALTH_FACTOR) {
            return (false, 0, 0);
        }
        
        // Calculate liquidation amounts
        uint256 maxDebtToCover = profile.totalDebtValue / 2; // Max 50% of debt
        uint256 collateralToLiquidate = (maxDebtToCover * (BASIS_POINTS + params.liquidationBonus)) / BASIS_POINTS;
        
        return (true, maxDebtToCover, collateralToLiquidate);
    }
    
    /**
     * @dev Execute liquidation with risk checks
     */
    function executeLiquidation(
        address user,
        address debtAsset,
        address collateralAsset,
        uint256 debtToCover
    ) external onlyRole(LIQUIDATOR_ROLE) nonReentrant {
        require(!liquidationsPaused, "Liquidations paused");
        
        UserRiskProfile memory profileBefore = userRiskProfiles[user];
        require(profileBefore.healthFactor < MIN_HEALTH_FACTOR, "User not liquidatable");
        
        AssetRiskParams memory collateralParams = assetRiskParams[collateralAsset];
        require(collateralParams.liquidationEnabled, "Liquidation disabled for asset");
        
        uint256 collateralToLiquidate = (debtToCover * (BASIS_POINTS + collateralParams.liquidationBonus)) / BASIS_POINTS;
        
        // Record liquidation
        uint256 liquidationId = ++liquidationCounter;
        liquidationHistory[liquidationId] = LiquidationData({
            user: user,
            asset: collateralAsset,
            debtToCover: debtToCover,
            collateralToLiquidate: collateralToLiquidate,
            healthFactorBefore: profileBefore.healthFactor,
            healthFactorAfter: 0, // Will be updated after liquidation
            liquidationBonus: collateralParams.liquidationBonus,
            timestamp: block.timestamp
        });
        
        // Update market metrics
        marketMetrics[collateralAsset].liquidationsLast24h++;
        
        emit LiquidationExecuted(user, collateralAsset, debtToCover, collateralToLiquidate);
        
        // Recalculate user risk after liquidation
        this.calculateUserRisk(user);
    }
    
    /**
     * @dev Update market risk metrics
     */
    function updateMarketMetrics(address asset) external onlyRole(RISK_MANAGER_ROLE) {
        // This would integrate with lending pools to get actual data
        MarketRiskMetrics storage metrics = marketMetrics[asset];
        
        uint256 utilizationRate = metrics.totalSupply > 0 ? 
            (metrics.totalBorrow * PRECISION) / metrics.totalSupply : 0;
        
        metrics.utilizationRate = utilizationRate;
        metrics.lastUpdate = block.timestamp;
        
        // Determine market risk level
        if (utilizationRate > emergencyLiquidationThreshold) {
            metrics.marketRiskLevel = RiskLevel.EMERGENCY;
            _triggerRiskAlert(AlertType.SYSTEM_STRESS, address(0), asset, 10, "Market utilization critical");
        } else if (utilizationRate > systemUtilizationCap) {
            metrics.marketRiskLevel = RiskLevel.HIGH;
        } else if (utilizationRate > 7000) {
            metrics.marketRiskLevel = RiskLevel.MEDIUM;
        } else {
            metrics.marketRiskLevel = RiskLevel.LOW;
        }
    }
    
    /**
     * @dev Update asset price and volatility
     */
    function updateAssetPrice(address asset, uint256 newPrice) external onlyRole(ORACLE_ROLE) {
        uint256 oldPrice = assetPrices[asset];
        assetPrices[asset] = newPrice;
        lastPriceUpdate[asset] = block.timestamp;
        
        if (oldPrice > 0) {
            uint256 priceChange = oldPrice > newPrice ? 
                ((oldPrice - newPrice) * BASIS_POINTS) / oldPrice :
                ((newPrice - oldPrice) * BASIS_POINTS) / oldPrice;
            
            // Update volatility (simple moving average)
            priceVolatility[asset] = (priceVolatility[asset] * 9 + priceChange) / 10;
            
            // Check for volatility alerts
            AssetRiskParams memory params = assetRiskParams[asset];
            if (priceChange > params.volatilityThreshold) {
                _triggerRiskAlert(AlertType.VOLATILITY_SPIKE, address(0), asset, 8, "High price volatility detected");
            }
        }
    }
    
    /**
     * @dev Run stress test scenario
     */
    function runStressTest(uint256 scenarioId) external onlyRole(RISK_MANAGER_ROLE) {
        StressTestScenario storage scenario = stressTestScenarios[scenarioId];
        require(scenario.isActive, "Scenario not active");
        
        // Simulate the stress scenario
        uint256 expectedLiquidations = 0;
        uint256 expectedLosses = 0;
        
        // Iterate through all users and calculate stress test impact
        address[] memory allUsers = accountingSystem.getAllUsers();
        
        for (uint256 i = 0; i < allUsers.length; i++) {
            address user = allUsers[i];
            UserRiskProfile memory profile = userRiskProfiles[user];
            
            if (profile.totalDebtValue > 0) {
                // Apply stress scenario to user's portfolio
                uint256 stressedCollateralValue = _applyStressToCollateral(user, scenario);
                uint256 stressedDebtValue = _applyStressToDebt(user, scenario);
                
                // Calculate stressed health factor
                uint256 stressedHealthFactor = stressedDebtValue > 0 ? 
                    (stressedCollateralValue * profile.liquidationThreshold) / (stressedDebtValue * BASIS_POINTS) : 
                    type(uint256).max;
                
                // Check if user would be liquidated
                if (stressedHealthFactor < PRECISION) {
                    expectedLiquidations++;
                    
                    // Calculate potential loss
                    uint256 shortfall = stressedDebtValue > stressedCollateralValue ? 
                        stressedDebtValue - stressedCollateralValue : 0;
                    expectedLosses += shortfall;
                }
            }
        }
        
        scenario.expectedLiquidations = expectedLiquidations;
        scenario.expectedLosses = expectedLosses;
        
        emit StressTestCompleted(scenarioId, expectedLiquidations, expectedLosses);
    }
    
    /**
     * @dev Trigger risk alert
     */
    function _triggerRiskAlert(
        AlertType alertType,
        address user,
        address asset,
        uint256 severity,
        string memory message
    ) internal {
        uint256 alertId = ++alertCounter;
        
        riskAlerts[alertId] = RiskAlert({
            alertId: alertId,
            alertType: alertType,
            user: user,
            asset: asset,
            severity: severity,
            message: message,
            timestamp: block.timestamp,
            isResolved: false,
            resolvedAt: 0
        });
        
        if (user != address(0)) {
            userAlerts[user].push(alertId);
        }
        
        emit RiskAlertTriggered(alertId, alertType, user, severity);
        
        // Auto-trigger emergency mode for critical alerts
        if (severity >= 9 && !emergencyMode) {
            _activateEmergencyMode("Critical risk alert triggered");
        }
    }
    
    /**
     * @dev Determine risk level based on health factor and concentration
     */
    function _determineRiskLevel(uint256 healthFactor, uint256 concentrationRisk) internal pure returns (RiskLevel) {
        if (healthFactor < PRECISION) {
            return RiskLevel.EMERGENCY;
        } else if (healthFactor < PRECISION * 110 / 100) {
            return RiskLevel.CRITICAL;
        } else if (healthFactor < PRECISION * 130 / 100 || concentrationRisk > 5000) {
            return RiskLevel.HIGH;
        } else if (healthFactor < PRECISION * 150 / 100 || concentrationRisk > 3000) {
            return RiskLevel.MEDIUM;
        } else {
            return RiskLevel.LOW;
        }
    }
    
    /**
     * @dev Activate emergency mode
     */
    function _activateEmergencyMode(string memory reason) internal {
        emergencyMode = true;
        liquidationsPaused = true;
        borrowingPaused = true;
        
        emit EmergencyModeActivated(reason);
    }
    
    /**
     * @dev Get user's risk alerts
     */
    function getUserAlerts(address user) external view returns (uint256[] memory) {
        return userAlerts[user];
    }
    
    /**
     * @dev Get market risk summary
     */
    function getMarketRiskSummary() external view returns (
        uint256 totalAssets,
        uint256 totalDebt,
        uint256 averageUtilization,
        RiskLevel overallRisk,
        uint256 activeAlerts
    ) {
        // Implementation would aggregate across all markets
        return (0, 0, 0, RiskLevel.LOW, alertCounter);
    }
    
    /**
     * @dev Emergency functions
     */
    function emergencyPauseLiquidations() external onlyRole(ADMIN_ROLE) {
        liquidationsPaused = true;
    }
    
    function emergencyPauseBorrowing() external onlyRole(ADMIN_ROLE) {
        borrowingPaused = true;
    }
    
    function emergencyResume() external onlyRole(ADMIN_ROLE) {
        emergencyMode = false;
        liquidationsPaused = false;
        borrowingPaused = false;
    }
    
    /**
     * @dev Resolve risk alert
     */
    function resolveAlert(uint256 alertId) external onlyRole(RISK_MANAGER_ROLE) {
        riskAlerts[alertId].isResolved = true;
        riskAlerts[alertId].resolvedAt = block.timestamp;
    }
    
    /**
     * @dev Update global risk parameters
     */
    function updateGlobalRiskParams(
        uint256 newRiskMultiplier,
        uint256 newUtilizationCap,
        uint256 newEmergencyThreshold
    ) external onlyRole(ADMIN_ROLE) {
        globalRiskMultiplier = newRiskMultiplier;
        systemUtilizationCap = newUtilizationCap;
        emergencyLiquidationThreshold = newEmergencyThreshold;
    }
}