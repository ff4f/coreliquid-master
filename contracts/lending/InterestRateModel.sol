// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title InterestRateModel
 * @dev Advanced interest rate model with dynamic rate calculations and multi-tier rate structures
 * @author CoreLiquid Protocol
 */
contract InterestRateModel is AccessControl {
    using Math for uint256;
    
    bytes32 public constant RATE_ADMIN_ROLE = keccak256("RATE_ADMIN_ROLE");
    bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");
    
    struct RateParams {
        uint256 baseRate; // Base interest rate (annual, in basis points)
        uint256 multiplier; // Rate multiplier (slope of interest rate curve)
        uint256 jumpMultiplier; // Jump rate multiplier after optimal utilization
        uint256 optimalUtilization; // Optimal utilization rate (basis points)
        uint256 reserveFactor; // Reserve factor (basis points)
        uint256 maxRate; // Maximum interest rate cap
        uint256 minRate; // Minimum interest rate floor
        bool isActive; // Whether this rate model is active
        uint256 lastUpdateTime; // Last time parameters were updated
    }
    
    struct MarketRates {
        uint256 borrowRate;
        uint256 supplyRate;
        uint256 utilizationRate;
        uint256 lastUpdateTime;
        uint256 totalBorrows;
        uint256 totalSupply;
        uint256 totalReserves;
        uint256 rateIndex; // Cumulative rate index
    }
    
    struct RateHistory {
        uint256 timestamp;
        uint256 borrowRate;
        uint256 supplyRate;
        uint256 utilizationRate;
        uint256 totalBorrows;
        uint256 totalSupply;
    }
    
    struct VolatilityMetrics {
        uint256 rateVolatility; // Rate volatility measure
        uint256 utilizationVolatility; // Utilization volatility measure
        uint256 smoothingFactor; // Smoothing factor for rate changes
        uint256 lastVolatilityUpdate;
    }
    
    // Constants
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant SECONDS_PER_YEAR = 365 days;
    uint256 public constant MAX_RATE = 10000; // 100% APR
    uint256 public constant MIN_RATE = 0; // 0% APR
    uint256 public constant PRECISION = 1e18;
    uint256 public constant MAX_UTILIZATION = 100e16; // 100%
    uint256 public constant DEFAULT_OPTIMAL_UTILIZATION = 80e16; // 80%
    uint256 public constant DEFAULT_BASE_RATE = 2e16; // 2%
    uint256 public constant DEFAULT_MULTIPLIER = 18e16; // 18%
    uint256 public constant DEFAULT_JUMP_MULTIPLIER = 109e16; // 109%
    
    // State variables
    mapping(address => RateParams) public rateParams;
    mapping(address => MarketRates) public marketRates;
    mapping(address => RateHistory[]) public rateHistory;
    mapping(address => VolatilityMetrics) public volatilityMetrics;
    mapping(address => uint256) public lastRateUpdate;
    mapping(address => bool) public isMarketSupported;
    
    address[] public supportedMarkets;
    uint256 public globalRateMultiplier = PRECISION; // Global rate adjustment
    uint256 public maxHistoryLength = 100; // Maximum history entries per market
    bool public dynamicRatesEnabled = true;
    
    // Events
    event RateParamsUpdated(address indexed market, RateParams params);
    event RatesCalculated(address indexed market, uint256 borrowRate, uint256 supplyRate, uint256 utilization);
    event MarketAdded(address indexed market);
    event MarketRemoved(address indexed market);
    event GlobalRateMultiplierUpdated(uint256 oldMultiplier, uint256 newMultiplier);
    event VolatilityUpdated(address indexed market, uint256 rateVolatility, uint256 utilizationVolatility);
    
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(RATE_ADMIN_ROLE, msg.sender);
        _grantRole(GOVERNOR_ROLE, msg.sender);
    }
    
    /**
     * @dev Calculate interest rate based on utilization
     * @param utilization The current utilization rate (scaled by PRECISION)
     * @return The calculated interest rate (scaled by PRECISION)
     */
    function calculateInterestRate(uint256 utilization) external pure returns (uint256) {
        require(utilization <= PRECISION, "Invalid utilization rate");
        
        // Use default parameters for pure calculation
        uint256 baseRate = DEFAULT_BASE_RATE;
        uint256 multiplier = DEFAULT_MULTIPLIER;
        uint256 jumpMultiplier = DEFAULT_JUMP_MULTIPLIER;
        uint256 optimalUtilization = DEFAULT_OPTIMAL_UTILIZATION;
        
        if (utilization <= optimalUtilization) {
            // Normal rate: baseRate + (utilization * multiplier)
            return baseRate + utilization.mulDiv(multiplier, PRECISION);
        } else {
            // Jump rate: baseRate + (optimalUtilization * multiplier) + (excessUtilization * jumpMultiplier)
            uint256 normalRate = baseRate + optimalUtilization.mulDiv(multiplier, PRECISION);
            uint256 excessUtilization = utilization - optimalUtilization;
            uint256 jumpRate = excessUtilization.mulDiv(jumpMultiplier, PRECISION);
            
            return normalRate + jumpRate;
        }
    }
    
    /**
     * @dev Calculate interest rate for a specific market
     * @param market The market address
     * @param utilization The current utilization rate
     * @return borrowRate The calculated borrow rate
     * @return supplyRate The calculated supply rate
     */
    function calculateMarketRates(
        address market,
        uint256 utilization
    ) external view returns (uint256 borrowRate, uint256 supplyRate) {
        require(isMarketSupported[market], "Market not supported");
        
        RateParams storage params = rateParams[market];
        require(params.isActive, "Rate model not active");
        
        borrowRate = _calculateBorrowRate(params, utilization);
        supplyRate = _calculateSupplyRate(borrowRate, utilization, params.reserveFactor);
        
        // Apply global rate multiplier
        borrowRate = borrowRate.mulDiv(globalRateMultiplier, PRECISION);
        supplyRate = supplyRate.mulDiv(globalRateMultiplier, PRECISION);
        
        // Apply volatility adjustments if dynamic rates are enabled
        if (dynamicRatesEnabled) {
            (borrowRate, supplyRate) = _applyVolatilityAdjustments(market, borrowRate, supplyRate);
        }
    }
    
    /**
     * @dev Get optimal utilization rate
     * @return The optimal utilization rate (scaled by PRECISION)
     */
    function getOptimalUtilization() external pure returns (uint256) {
        return DEFAULT_OPTIMAL_UTILIZATION;
    }
    
    /**
     * @dev Get optimal utilization for a specific market
     * @param market The market address
     * @return The optimal utilization rate for the market
     */
    function getMarketOptimalUtilization(address market) external view returns (uint256) {
        if (!isMarketSupported[market]) {
            return DEFAULT_OPTIMAL_UTILIZATION;
        }
        return rateParams[market].optimalUtilization;
    }
    
    /**
     * @dev Update rates for a market
     * @param market The market address
     * @param totalBorrows Current total borrows
     * @param totalSupply Current total supply
     * @param totalReserves Current total reserves
     */
    function updateMarketRates(
        address market,
        uint256 totalBorrows,
        uint256 totalSupply,
        uint256 totalReserves
    ) external {
        require(isMarketSupported[market], "Market not supported");
        
        uint256 utilization = totalSupply == 0 ? 0 : totalBorrows.mulDiv(PRECISION, totalSupply);
        
        (uint256 borrowRate, uint256 supplyRate) = this.calculateMarketRates(market, utilization);
        
        MarketRates storage rates = marketRates[market];
        rates.borrowRate = borrowRate;
        rates.supplyRate = supplyRate;
        rates.utilizationRate = utilization;
        rates.lastUpdateTime = block.timestamp;
        rates.totalBorrows = totalBorrows;
        rates.totalSupply = totalSupply;
        rates.totalReserves = totalReserves;
        
        // Update rate history
        _updateRateHistory(market, borrowRate, supplyRate, utilization, totalBorrows, totalSupply);
        
        // Update volatility metrics
        _updateVolatilityMetrics(market, borrowRate, utilization);
        
        emit RatesCalculated(market, borrowRate, supplyRate, utilization);
    }
    
    /**
     * @dev Add a new market
     * @param market The market address
     * @param baseRate Base interest rate
     * @param multiplier Rate multiplier
     * @param jumpMultiplier Jump rate multiplier
     * @param optimalUtilization Optimal utilization rate
     * @param reserveFactor Reserve factor
     * @param maxRate Maximum rate cap
     * @param minRate Minimum rate floor
     */
    function addMarket(
        address market,
        uint256 baseRate,
        uint256 multiplier,
        uint256 jumpMultiplier,
        uint256 optimalUtilization,
        uint256 reserveFactor,
        uint256 maxRate,
        uint256 minRate
    ) external onlyRole(RATE_ADMIN_ROLE) {
        require(!isMarketSupported[market], "Market already supported");
        require(baseRate <= MAX_RATE, "Base rate too high");
        require(maxRate <= MAX_RATE, "Max rate too high");
        require(minRate >= MIN_RATE, "Min rate too low");
        require(optimalUtilization <= PRECISION, "Invalid optimal utilization");
        require(reserveFactor <= PRECISION, "Invalid reserve factor");
        
        rateParams[market] = RateParams({
            baseRate: baseRate,
            multiplier: multiplier,
            jumpMultiplier: jumpMultiplier,
            optimalUtilization: optimalUtilization,
            reserveFactor: reserveFactor,
            maxRate: maxRate,
            minRate: minRate,
            isActive: true,
            lastUpdateTime: block.timestamp
        });
        
        marketRates[market] = MarketRates({
            borrowRate: baseRate,
            supplyRate: 0,
            utilizationRate: 0,
            lastUpdateTime: block.timestamp,
            totalBorrows: 0,
            totalSupply: 0,
            totalReserves: 0,
            rateIndex: PRECISION
        });
        
        volatilityMetrics[market] = VolatilityMetrics({
            rateVolatility: 0,
            utilizationVolatility: 0,
            smoothingFactor: PRECISION / 10, // 10% smoothing
            lastVolatilityUpdate: block.timestamp
        });
        
        isMarketSupported[market] = true;
        supportedMarkets.push(market);
        
        emit MarketAdded(market);
        emit RateParamsUpdated(market, rateParams[market]);
    }
    
    /**
     * @dev Update rate parameters for a market
     */
    function updateRateParams(
        address market,
        uint256 baseRate,
        uint256 multiplier,
        uint256 jumpMultiplier,
        uint256 optimalUtilization,
        uint256 reserveFactor,
        uint256 maxRate,
        uint256 minRate
    ) external onlyRole(RATE_ADMIN_ROLE) {
        require(isMarketSupported[market], "Market not supported");
        require(baseRate <= MAX_RATE, "Base rate too high");
        require(maxRate <= MAX_RATE, "Max rate too high");
        require(minRate >= MIN_RATE, "Min rate too low");
        require(optimalUtilization <= PRECISION, "Invalid optimal utilization");
        require(reserveFactor <= PRECISION, "Invalid reserve factor");
        
        RateParams storage params = rateParams[market];
        params.baseRate = baseRate;
        params.multiplier = multiplier;
        params.jumpMultiplier = jumpMultiplier;
        params.optimalUtilization = optimalUtilization;
        params.reserveFactor = reserveFactor;
        params.maxRate = maxRate;
        params.minRate = minRate;
        params.lastUpdateTime = block.timestamp;
        
        emit RateParamsUpdated(market, params);
    }
    
    /**
     * @dev Get rate history for a market
     * @param market The market address
     * @param count Number of recent entries to return
     * @return history Array of rate history entries
     */
    function getRateHistory(
        address market,
        uint256 count
    ) external view returns (RateHistory[] memory history) {
        RateHistory[] storage marketHistory = rateHistory[market];
        uint256 length = marketHistory.length;
        
        if (count > length) {
            count = length;
        }
        
        history = new RateHistory[](count);
        
        for (uint256 i = 0; i < count; i++) {
            history[i] = marketHistory[length - count + i];
        }
    }
    
    /**
     * @dev Get all supported markets
     */
    function getSupportedMarkets() external view returns (address[] memory) {
        return supportedMarkets;
    }
    
    /**
     * @dev Set global rate multiplier
     * @param multiplier New global rate multiplier
     */
    function setGlobalRateMultiplier(uint256 multiplier) external onlyRole(GOVERNOR_ROLE) {
        require(multiplier > 0 && multiplier <= 2 * PRECISION, "Invalid multiplier");
        
        uint256 oldMultiplier = globalRateMultiplier;
        globalRateMultiplier = multiplier;
        
        emit GlobalRateMultiplierUpdated(oldMultiplier, multiplier);
    }
    
    /**
     * @dev Toggle dynamic rates
     * @param enabled Whether to enable dynamic rates
     */
    function setDynamicRatesEnabled(bool enabled) external onlyRole(RATE_ADMIN_ROLE) {
        dynamicRatesEnabled = enabled;
    }
    
    /**
     * @dev Set maximum history length
     * @param length New maximum history length
     */
    function setMaxHistoryLength(uint256 length) external onlyRole(RATE_ADMIN_ROLE) {
        require(length > 0 && length <= 1000, "Invalid history length");
        maxHistoryLength = length;
    }
    
    // Internal functions
    function _calculateBorrowRate(
        RateParams storage params,
        uint256 utilization
    ) internal view returns (uint256) {
        uint256 rate;
        
        if (utilization <= params.optimalUtilization) {
            // Normal rate calculation
            rate = params.baseRate + utilization.mulDiv(params.multiplier, PRECISION);
        } else {
            // Jump rate calculation
            uint256 normalRate = params.baseRate + params.optimalUtilization.mulDiv(params.multiplier, PRECISION);
            uint256 excessUtilization = utilization - params.optimalUtilization;
            uint256 jumpRate = excessUtilization.mulDiv(params.jumpMultiplier, PRECISION);
            rate = normalRate + jumpRate;
        }
        
        // Apply rate bounds
        if (rate > params.maxRate) {
            rate = params.maxRate;
        } else if (rate < params.minRate) {
            rate = params.minRate;
        }
        
        return rate;
    }
    
    function _calculateSupplyRate(
        uint256 borrowRate,
        uint256 utilization,
        uint256 reserveFactor
    ) internal pure returns (uint256) {
        uint256 rateToPool = borrowRate.mulDiv(PRECISION - reserveFactor, PRECISION);
        return utilization.mulDiv(rateToPool, PRECISION);
    }
    
    function _updateRateHistory(
        address market,
        uint256 borrowRate,
        uint256 supplyRate,
        uint256 utilization,
        uint256 totalBorrows,
        uint256 totalSupply
    ) internal {
        RateHistory[] storage history = rateHistory[market];
        
        // Add new entry
        history.push(RateHistory({
            timestamp: block.timestamp,
            borrowRate: borrowRate,
            supplyRate: supplyRate,
            utilizationRate: utilization,
            totalBorrows: totalBorrows,
            totalSupply: totalSupply
        }));
        
        // Remove old entries if exceeding max length
        while (history.length > maxHistoryLength) {
            // Shift array left
            for (uint256 i = 0; i < history.length - 1; i++) {
                history[i] = history[i + 1];
            }
            history.pop();
        }
    }
    
    function _updateVolatilityMetrics(
        address market,
        uint256 currentBorrowRate,
        uint256 currentUtilization
    ) internal {
        VolatilityMetrics storage metrics = volatilityMetrics[market];
        MarketRates storage rates = marketRates[market];
        
        if (rates.lastUpdateTime == 0) {
            return; // First update, no previous data
        }
        
        uint256 timeDelta = block.timestamp - metrics.lastVolatilityUpdate;
        if (timeDelta < 1 hours) {
            return; // Update at most once per hour
        }
        
        // Calculate rate volatility (absolute difference)
        uint256 rateDiff = currentBorrowRate > rates.borrowRate
            ? currentBorrowRate - rates.borrowRate
            : rates.borrowRate - currentBorrowRate;
        
        // Calculate utilization volatility
        uint256 utilizationDiff = currentUtilization > rates.utilizationRate
            ? currentUtilization - rates.utilizationRate
            : rates.utilizationRate - currentUtilization;
        
        // Apply exponential smoothing
        uint256 alpha = metrics.smoothingFactor;
        metrics.rateVolatility = alpha.mulDiv(rateDiff, PRECISION) + 
            (PRECISION - alpha).mulDiv(metrics.rateVolatility, PRECISION);
        
        metrics.utilizationVolatility = alpha.mulDiv(utilizationDiff, PRECISION) + 
            (PRECISION - alpha).mulDiv(metrics.utilizationVolatility, PRECISION);
        
        metrics.lastVolatilityUpdate = block.timestamp;
        
        emit VolatilityUpdated(market, metrics.rateVolatility, metrics.utilizationVolatility);
    }
    
    function _applyVolatilityAdjustments(
        address market,
        uint256 borrowRate,
        uint256 supplyRate
    ) internal view returns (uint256 adjustedBorrowRate, uint256 adjustedSupplyRate) {
        VolatilityMetrics storage metrics = volatilityMetrics[market];
        
        // Apply volatility-based adjustments (simplified)
        // Higher volatility = slightly higher rates to compensate for risk
        uint256 volatilityAdjustment = metrics.rateVolatility.mulDiv(5e15, PRECISION); // Max 0.5% adjustment
        
        adjustedBorrowRate = borrowRate + volatilityAdjustment;
        adjustedSupplyRate = supplyRate + volatilityAdjustment.mulDiv(8e17, PRECISION); // 80% of borrow adjustment
        
        // Ensure rates don't exceed maximum
        RateParams storage params = rateParams[market];
        if (adjustedBorrowRate > params.maxRate) {
            adjustedBorrowRate = params.maxRate;
        }
        if (adjustedSupplyRate > params.maxRate) {
            adjustedSupplyRate = params.maxRate;
        }
    }
    
    // Admin functions
    function removeMarket(address market) external onlyRole(RATE_ADMIN_ROLE) {
        require(isMarketSupported[market], "Market not supported");
        
        isMarketSupported[market] = false;
        rateParams[market].isActive = false;
        
        // Remove from supported markets array
        for (uint256 i = 0; i < supportedMarkets.length; i++) {
            if (supportedMarkets[i] == market) {
                supportedMarkets[i] = supportedMarkets[supportedMarkets.length - 1];
                supportedMarkets.pop();
                break;
            }
        }
        
        emit MarketRemoved(market);
    }
    
    function emergencyPause(address market) external onlyRole(GOVERNOR_ROLE) {
        require(isMarketSupported[market], "Market not supported");
        rateParams[market].isActive = false;
    }
    
    function emergencyUnpause(address market) external onlyRole(GOVERNOR_ROLE) {
        require(isMarketSupported[market], "Market not supported");
        rateParams[market].isActive = true;
    }
}