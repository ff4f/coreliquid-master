// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./interfaces/IOracle.sol";
import "./BorrowingEngine.sol";
import "./LendingMarket.sol";

/**
 * @title HealthFactorCalculator
 * @dev Advanced health factor calculation with risk assessment and liquidation prediction
 * @author CoreLiquid Protocol
 */
contract HealthFactorCalculator is AccessControl {
    using Math for uint256;
    
    bytes32 public constant CALCULATOR_ROLE = keccak256("CALCULATOR_ROLE");
    bytes32 public constant RISK_MANAGER_ROLE = keccak256("RISK_MANAGER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    
    uint256 public constant PRECISION = 1e18;
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant MIN_HEALTH_FACTOR = 1e18; // 1.0
    uint256 public constant LIQUIDATION_THRESHOLD = 80e16; // 80%
    uint256 public constant LIQUIDATION_BONUS = 5e16; // 5%
    uint256 public constant CRITICAL_HEALTH_FACTOR = 105e16; // 1.05
    uint256 public constant WARNING_HEALTH_FACTOR = 120e16; // 1.20
    uint256 public constant SAFE_HEALTH_FACTOR = 150e16; // 1.50
    
    struct HealthFactorData {
        uint256 healthFactor;
        uint256 totalCollateralValue;
        uint256 totalBorrowValue;
        uint256 liquidationPrice;
        uint256 safetyMargin;
        uint256 riskLevel; // 0-100 scale
        bool isLiquidatable;
        bool isAtRisk;
        uint256 lastUpdate;
    }
    
    struct AssetRiskData {
        uint256 collateralFactor;
        uint256 liquidationThreshold;
        uint256 volatilityScore; // 0-100 scale
        uint256 liquidityScore; // 0-100 scale
        uint256 correlationRisk; // Risk from correlation with other assets
        uint256 concentrationRisk; // Risk from concentration in this asset
        bool isHighRisk;
        uint256 lastRiskUpdate;
    }
    
    struct RiskMetrics {
        uint256 portfolioRisk; // Overall portfolio risk score
        uint256 concentrationRisk; // Risk from asset concentration
        uint256 correlationRisk; // Risk from asset correlation
        uint256 liquidityRisk; // Risk from illiquid assets
        uint256 volatilityRisk; // Risk from volatile assets
        uint256 leverageRisk; // Risk from high leverage
        uint256 compositeRisk; // Combined risk score
    }
    
    struct LiquidationPrediction {
        uint256 timeToLiquidation; // Estimated time until liquidation (seconds)
        uint256 priceDropRequired; // Price drop % required for liquidation
        address mostRiskyAsset; // Asset most likely to trigger liquidation
        uint256 liquidationProbability; // 0-100 probability score
        uint256 expectedLoss; // Expected loss in liquidation
        bool isImminentRisk; // Liquidation risk within 24 hours
    }
    
    struct HealthFactorHistory {
        uint256 timestamp;
        uint256 healthFactor;
        uint256 totalCollateral;
        uint256 totalBorrow;
        uint256 riskLevel;
    }
    
    // State variables
    mapping(address => HealthFactorData) public userHealthData;
    mapping(address => AssetRiskData) public assetRiskData;
    mapping(address => RiskMetrics) public userRiskMetrics;
    mapping(address => LiquidationPrediction) public liquidationPredictions;
    mapping(address => HealthFactorHistory[]) public healthFactorHistory;
    mapping(address => mapping(address => uint256)) public assetWeights; // User -> Asset -> Weight
    
    // External contracts
    IOracle public priceOracle;
    BorrowingEngine public borrowingEngine;
    LendingMarket public lendingMarket;
    
    // Risk parameters
    uint256 public maxHistoryLength = 100;
    uint256 public riskUpdateInterval = 1 hours;
    uint256 public volatilityWindow = 24 hours;
    uint256 public correlationThreshold = 70e16; // 70% correlation threshold
    
    // Risk weights for composite calculation
    uint256 public concentrationWeight = 25e16; // 25%
    uint256 public correlationWeight = 20e16; // 20%
    uint256 public liquidityWeight = 15e16; // 15%
    uint256 public volatilityWeight = 25e16; // 25%
    uint256 public leverageWeight = 15e16; // 15%
    
    // Events
    event HealthFactorCalculated(address indexed user, uint256 healthFactor, uint256 riskLevel);
    event RiskLevelChanged(address indexed user, uint256 oldRisk, uint256 newRisk);
    event LiquidationRiskWarning(address indexed user, uint256 healthFactor, uint256 timeToLiquidation);
    event AssetRiskUpdated(address indexed asset, uint256 volatilityScore, uint256 liquidityScore);
    event HealthFactorImproved(address indexed user, uint256 oldFactor, uint256 newFactor);
    event HealthFactorDeteriorated(address indexed user, uint256 oldFactor, uint256 newFactor);
    event CriticalHealthFactor(address indexed user, uint256 healthFactor);
    
    constructor(
        address _priceOracle,
        address _borrowingEngine,
        address _lendingMarket
    ) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(CALCULATOR_ROLE, msg.sender);
        _grantRole(RISK_MANAGER_ROLE, msg.sender);
        
        priceOracle = IOracle(_priceOracle);
        borrowingEngine = BorrowingEngine(_borrowingEngine);
        lendingMarket = LendingMarket(_lendingMarket);
    }
    
    /**
     * @dev Calculate health factor for a user
     * @param user The user address
     * @return healthFactor The calculated health factor
     */
    function calculateHealthFactor(address user) public view returns (uint256 healthFactor) {
        (uint256 totalCollateral, uint256 totalBorrow) = _getUserTotalValues(user);
        
        if (totalBorrow == 0) {
            return type(uint256).max; // No debt = infinite health factor
        }
        
        // Apply risk-adjusted collateral value
        uint256 riskAdjustedCollateral = _calculateRiskAdjustedCollateral(user, totalCollateral);
        
        healthFactor = riskAdjustedCollateral.mulDiv(PRECISION, totalBorrow);
        
        return healthFactor;
    }
    
    /**
     * @dev Check if a user is liquidatable
     * @param user The user address
     * @return isLiquidatable Whether the user can be liquidated
     */
    function isLiquidatable(address user) public view returns (bool isLiquidatable) {
        uint256 healthFactor = calculateHealthFactor(user);
        return healthFactor < MIN_HEALTH_FACTOR;
    }
    
    /**
     * @dev Get comprehensive health factor data for a user
     * @param user The user address
     * @return data Complete health factor data structure
     */
    function getHealthFactorData(address user) external view returns (HealthFactorData memory data) {
        (uint256 totalCollateral, uint256 totalBorrow) = _getUserTotalValues(user);
        
        uint256 healthFactor = calculateHealthFactor(user);
        uint256 liquidationPrice = _calculateLiquidationPrice(user);
        uint256 safetyMargin = _calculateSafetyMargin(healthFactor);
        uint256 riskLevel = _calculateRiskLevel(user);
        
        return HealthFactorData({
            healthFactor: healthFactor,
            totalCollateralValue: totalCollateral,
            totalBorrowValue: totalBorrow,
            liquidationPrice: liquidationPrice,
            safetyMargin: safetyMargin,
            riskLevel: riskLevel,
            isLiquidatable: healthFactor < MIN_HEALTH_FACTOR,
            isAtRisk: healthFactor < WARNING_HEALTH_FACTOR,
            lastUpdate: block.timestamp
        });
    }
    
    /**
     * @dev Get risk metrics for a user
     * @param user The user address
     * @return metrics Comprehensive risk metrics
     */
    function getRiskMetrics(address user) external view returns (RiskMetrics memory metrics) {
        return RiskMetrics({
            portfolioRisk: _calculatePortfolioRisk(user),
            concentrationRisk: _calculateConcentrationRisk(user),
            correlationRisk: _calculateCorrelationRisk(user),
            liquidityRisk: _calculateLiquidityRisk(user),
            volatilityRisk: _calculateVolatilityRisk(user),
            leverageRisk: _calculateLeverageRisk(user),
            compositeRisk: _calculateCompositeRisk(user)
        });
    }
    
    /**
     * @dev Get liquidation prediction for a user
     * @param user The user address
     * @return prediction Liquidation prediction data
     */
    function getLiquidationPrediction(address user) external view returns (LiquidationPrediction memory prediction) {
        uint256 healthFactor = calculateHealthFactor(user);
        
        if (healthFactor >= SAFE_HEALTH_FACTOR) {
            return LiquidationPrediction({
                timeToLiquidation: type(uint256).max,
                priceDropRequired: type(uint256).max,
                mostRiskyAsset: address(0),
                liquidationProbability: 0,
                expectedLoss: 0,
                isImminentRisk: false
            });
        }
        
        return LiquidationPrediction({
            timeToLiquidation: _estimateTimeToLiquidation(user),
            priceDropRequired: _calculatePriceDropForLiquidation(user),
            mostRiskyAsset: _findMostRiskyAsset(user),
            liquidationProbability: _calculateLiquidationProbability(user),
            expectedLoss: _calculateExpectedLiquidationLoss(user),
            isImminentRisk: healthFactor < CRITICAL_HEALTH_FACTOR
        });
    }
    
    /**
     * @dev Update health factor and risk metrics for a user
     * @param user The user address
     */
    function updateHealthFactor(address user) external {
        HealthFactorData storage data = userHealthData[user];
        uint256 oldHealthFactor = data.healthFactor;
        
        // Calculate new health factor
        (uint256 totalCollateral, uint256 totalBorrow) = _getUserTotalValues(user);
        uint256 newHealthFactor = calculateHealthFactor(user);
        
        // Update data
        data.healthFactor = newHealthFactor;
        data.totalCollateralValue = totalCollateral;
        data.totalBorrowValue = totalBorrow;
        data.liquidationPrice = _calculateLiquidationPrice(user);
        data.safetyMargin = _calculateSafetyMargin(newHealthFactor);
        data.riskLevel = _calculateRiskLevel(user);
        data.isLiquidatable = newHealthFactor < MIN_HEALTH_FACTOR;
        data.isAtRisk = newHealthFactor < WARNING_HEALTH_FACTOR;
        data.lastUpdate = block.timestamp;
        
        // Update risk metrics
        _updateRiskMetrics(user);
        
        // Add to history
        _addToHistory(user, newHealthFactor, totalCollateral, totalBorrow, data.riskLevel);
        
        // Emit events
        emit HealthFactorCalculated(user, newHealthFactor, data.riskLevel);
        
        if (newHealthFactor < CRITICAL_HEALTH_FACTOR) {
            emit CriticalHealthFactor(user, newHealthFactor);
        }
        
        if (oldHealthFactor != 0) {
            if (newHealthFactor > oldHealthFactor) {
                emit HealthFactorImproved(user, oldHealthFactor, newHealthFactor);
            } else if (newHealthFactor < oldHealthFactor) {
                emit HealthFactorDeteriorated(user, oldHealthFactor, newHealthFactor);
            }
        }
        
        // Check for liquidation risk
        if (data.isAtRisk) {
            uint256 timeToLiquidation = _estimateTimeToLiquidation(user);
            emit LiquidationRiskWarning(user, newHealthFactor, timeToLiquidation);
        }
    }
    
    /**
     * @dev Batch update health factors for multiple users
     * @param users Array of user addresses
     */
    function batchUpdateHealthFactors(address[] calldata users) external {
        for (uint256 i = 0; i < users.length; i++) {
            this.updateHealthFactor(users[i]);
        }
    }
    
    /**
     * @dev Get health factor history for a user
     * @param user The user address
     * @param count Number of recent entries to return
     * @return history Array of health factor history entries
     */
    function getHealthFactorHistory(
        address user,
        uint256 count
    ) external view returns (HealthFactorHistory[] memory history) {
        HealthFactorHistory[] storage userHistory = healthFactorHistory[user];
        uint256 length = userHistory.length;
        
        if (count > length) count = length;
        
        history = new HealthFactorHistory[](count);
        for (uint256 i = 0; i < count; i++) {
            history[i] = userHistory[length - count + i];
        }
    }
    
    /**
     * @dev Simulate health factor after a hypothetical action
     * @param user The user address
     * @param collateralChange Change in collateral value (can be negative)
     * @param borrowChange Change in borrow value (can be negative)
     * @return newHealthFactor The simulated health factor
     */
    function simulateHealthFactor(
        address user,
        int256 collateralChange,
        int256 borrowChange
    ) external view returns (uint256 newHealthFactor) {
        (uint256 totalCollateral, uint256 totalBorrow) = _getUserTotalValues(user);
        
        // Apply changes
        if (collateralChange >= 0) {
            totalCollateral += uint256(collateralChange);
        } else {
            uint256 decrease = uint256(-collateralChange);
            totalCollateral = totalCollateral > decrease ? totalCollateral - decrease : 0;
        }
        
        if (borrowChange >= 0) {
            totalBorrow += uint256(borrowChange);
        } else {
            uint256 decrease = uint256(-borrowChange);
            totalBorrow = totalBorrow > decrease ? totalBorrow - decrease : 0;
        }
        
        if (totalBorrow == 0) {
            return type(uint256).max;
        }
        
        uint256 riskAdjustedCollateral = _calculateRiskAdjustedCollateral(user, totalCollateral);
        return riskAdjustedCollateral.mulDiv(PRECISION, totalBorrow);
    }
    
    // Internal functions
    function _getUserTotalValues(address user) internal view returns (uint256 totalCollateral, uint256 totalBorrow) {
        // Get data from BorrowingEngine
        (totalBorrow, totalCollateral,,,) = borrowingEngine.getUserBorrowData(user);
        
        // Convert to USD values using oracle prices
        // This is a simplified implementation
        return (totalCollateral, totalBorrow);
    }
    
    function _calculateRiskAdjustedCollateral(
        address user,
        uint256 totalCollateral
    ) internal view returns (uint256 riskAdjustedCollateral) {
        // Apply risk adjustments based on asset composition
        uint256 riskMultiplier = PRECISION - _calculateCompositeRisk(user);
        return totalCollateral.mulDiv(riskMultiplier, PRECISION);
    }
    
    function _calculateLiquidationPrice(address user) internal view returns (uint256) {
        // Calculate the price at which liquidation would occur
        // This is a simplified calculation
        uint256 healthFactor = calculateHealthFactor(user);
        if (healthFactor >= MIN_HEALTH_FACTOR) {
            uint256 priceDropNeeded = (healthFactor - MIN_HEALTH_FACTOR).mulDiv(100e16, healthFactor);
            return priceDropNeeded;
        }
        return 0;
    }
    
    function _calculateSafetyMargin(uint256 healthFactor) internal pure returns (uint256) {
        if (healthFactor <= MIN_HEALTH_FACTOR) {
            return 0;
        }
        return ((healthFactor - MIN_HEALTH_FACTOR).mulDiv(100e16, MIN_HEALTH_FACTOR));
    }
    
    function _calculateRiskLevel(address user) internal view returns (uint256) {
        uint256 healthFactor = calculateHealthFactor(user);
        
        if (healthFactor < MIN_HEALTH_FACTOR) {
            return 100; // Maximum risk
        } else if (healthFactor < CRITICAL_HEALTH_FACTOR) {
            return 90;
        } else if (healthFactor < WARNING_HEALTH_FACTOR) {
            return 70;
        } else if (healthFactor < SAFE_HEALTH_FACTOR) {
            return 40;
        } else {
            return 10; // Low risk
        }
    }
    
    function _calculatePortfolioRisk(address user) internal view returns (uint256) {
        // Calculate overall portfolio risk
        return _calculateCompositeRisk(user);
    }
    
    function _calculateConcentrationRisk(address user) internal view returns (uint256) {
        // Calculate risk from asset concentration
        // Higher concentration = higher risk
        return 20e16; // Simplified: 20% risk
    }
    
    function _calculateCorrelationRisk(address user) internal view returns (uint256) {
        // Calculate risk from asset correlation
        return 15e16; // Simplified: 15% risk
    }
    
    function _calculateLiquidityRisk(address user) internal view returns (uint256) {
        // Calculate risk from illiquid assets
        return 10e16; // Simplified: 10% risk
    }
    
    function _calculateVolatilityRisk(address user) internal view returns (uint256) {
        // Calculate risk from volatile assets
        return 25e16; // Simplified: 25% risk
    }
    
    function _calculateLeverageRisk(address user) internal view returns (uint256) {
        // Calculate risk from high leverage
        uint256 healthFactor = calculateHealthFactor(user);
        if (healthFactor > SAFE_HEALTH_FACTOR) {
            return 5e16; // Low leverage risk
        } else if (healthFactor > WARNING_HEALTH_FACTOR) {
            return 15e16; // Medium leverage risk
        } else {
            return 30e16; // High leverage risk
        }
    }
    
    function _calculateCompositeRisk(address user) internal view returns (uint256) {
        uint256 concentrationRisk = _calculateConcentrationRisk(user);
        uint256 correlationRisk = _calculateCorrelationRisk(user);
        uint256 liquidityRisk = _calculateLiquidityRisk(user);
        uint256 volatilityRisk = _calculateVolatilityRisk(user);
        uint256 leverageRisk = _calculateLeverageRisk(user);
        
        uint256 compositeRisk = 
            concentrationRisk.mulDiv(concentrationWeight, PRECISION) +
            correlationRisk.mulDiv(correlationWeight, PRECISION) +
            liquidityRisk.mulDiv(liquidityWeight, PRECISION) +
            volatilityRisk.mulDiv(volatilityWeight, PRECISION) +
            leverageRisk.mulDiv(leverageWeight, PRECISION);
        
        return compositeRisk;
    }
    
    function _estimateTimeToLiquidation(address user) internal view returns (uint256) {
        uint256 healthFactor = calculateHealthFactor(user);
        
        if (healthFactor >= MIN_HEALTH_FACTOR) {
            // Estimate based on current trend and volatility
            return 7 days; // Simplified estimation
        }
        
        return 0; // Already liquidatable
    }
    
    function _calculatePriceDropForLiquidation(address user) internal view returns (uint256) {
        uint256 healthFactor = calculateHealthFactor(user);
        
        if (healthFactor <= MIN_HEALTH_FACTOR) {
            return 0; // Already at liquidation
        }
        
        // Calculate required price drop percentage
        return ((healthFactor - MIN_HEALTH_FACTOR).mulDiv(100e16, healthFactor));
    }
    
    function _findMostRiskyAsset(address user) internal view returns (address) {
        // Find the asset most likely to trigger liquidation
        // This would analyze each asset's volatility and weight
        return address(0); // Simplified
    }
    
    function _calculateLiquidationProbability(address user) internal view returns (uint256) {
        uint256 healthFactor = calculateHealthFactor(user);
        
        if (healthFactor < MIN_HEALTH_FACTOR) {
            return 100e16; // 100% probability
        } else if (healthFactor < CRITICAL_HEALTH_FACTOR) {
            return 80e16; // 80% probability
        } else if (healthFactor < WARNING_HEALTH_FACTOR) {
            return 40e16; // 40% probability
        } else {
            return 5e16; // 5% probability
        }
    }
    
    function _calculateExpectedLiquidationLoss(address user) internal view returns (uint256) {
        // Calculate expected loss in case of liquidation
        (uint256 totalCollateral,) = _getUserTotalValues(user);
        return totalCollateral.mulDiv(LIQUIDATION_BONUS, PRECISION);
    }
    
    function _updateRiskMetrics(address user) internal {
        userRiskMetrics[user] = RiskMetrics({
            portfolioRisk: _calculatePortfolioRisk(user),
            concentrationRisk: _calculateConcentrationRisk(user),
            correlationRisk: _calculateCorrelationRisk(user),
            liquidityRisk: _calculateLiquidityRisk(user),
            volatilityRisk: _calculateVolatilityRisk(user),
            leverageRisk: _calculateLeverageRisk(user),
            compositeRisk: _calculateCompositeRisk(user)
        });
    }
    
    function _addToHistory(
        address user,
        uint256 healthFactor,
        uint256 totalCollateral,
        uint256 totalBorrow,
        uint256 riskLevel
    ) internal {
        HealthFactorHistory[] storage history = healthFactorHistory[user];
        
        history.push(HealthFactorHistory({
            timestamp: block.timestamp,
            healthFactor: healthFactor,
            totalCollateral: totalCollateral,
            totalBorrow: totalBorrow,
            riskLevel: riskLevel
        }));
        
        // Remove old entries if exceeding max length
        while (history.length > maxHistoryLength) {
            for (uint256 i = 0; i < history.length - 1; i++) {
                history[i] = history[i + 1];
            }
            history.pop();
        }
    }
    
    // Admin functions
    function updateAssetRiskData(
        address asset,
        uint256 volatilityScore,
        uint256 liquidityScore,
        bool isHighRisk
    ) external onlyRole(RISK_MANAGER_ROLE) {
        AssetRiskData storage riskData = assetRiskData[asset];
        riskData.volatilityScore = volatilityScore;
        riskData.liquidityScore = liquidityScore;
        riskData.isHighRisk = isHighRisk;
        riskData.lastRiskUpdate = block.timestamp;
        
        emit AssetRiskUpdated(asset, volatilityScore, liquidityScore);
    }
    
    function setRiskWeights(
        uint256 _concentrationWeight,
        uint256 _correlationWeight,
        uint256 _liquidityWeight,
        uint256 _volatilityWeight,
        uint256 _leverageWeight
    ) external onlyRole(ADMIN_ROLE) {
        require(
            _concentrationWeight + _correlationWeight + _liquidityWeight + 
            _volatilityWeight + _leverageWeight == PRECISION,
            "Weights must sum to 100%"
        );
        
        concentrationWeight = _concentrationWeight;
        correlationWeight = _correlationWeight;
        liquidityWeight = _liquidityWeight;
        volatilityWeight = _volatilityWeight;
        leverageWeight = _leverageWeight;
    }
    
    function setMaxHistoryLength(uint256 _maxHistoryLength) external onlyRole(ADMIN_ROLE) {
        require(_maxHistoryLength > 0 && _maxHistoryLength <= 1000, "Invalid history length");
        maxHistoryLength = _maxHistoryLength;
    }
    
    function setPriceOracle(address _priceOracle) external onlyRole(ADMIN_ROLE) {
        priceOracle = IOracle(_priceOracle);
    }
    
    function setBorrowingEngine(address _borrowingEngine) external onlyRole(ADMIN_ROLE) {
        borrowingEngine = BorrowingEngine(_borrowingEngine);
    }
    
    function setLendingMarket(address _lendingMarket) external onlyRole(ADMIN_ROLE) {
        lendingMarket = LendingMarket(_lendingMarket);
    }
}