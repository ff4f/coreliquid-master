// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title RatioCalculator
 * @dev Advanced ratio calculations for liquidity pools, yield farming, and risk management
 */
contract RatioCalculator is Ownable, ReentrancyGuard {
    using Math for uint256;

    struct PoolRatio {
        uint256 token0Reserve;
        uint256 token1Reserve;
        uint256 totalLiquidity;
        uint256 lastUpdateTime;
        uint256 priceRatio; // token1/token0 * PRECISION
        uint256 volatility;
    }

    struct RiskMetrics {
        uint256 sharpeRatio;
        uint256 volatility;
        uint256 maxDrawdown;
        uint256 valueAtRisk; // VaR at 95% confidence
        uint256 expectedReturn;
        uint256 riskScore; // 0-100 scale
    }

    struct YieldMetrics {
        uint256 apy;
        uint256 apr;
        uint256 totalRewards;
        uint256 compoundFrequency;
        uint256 timeWeightedReturn;
        uint256 feeYield;
    }

    mapping(address => PoolRatio) public poolRatios;
    mapping(address => RiskMetrics) public riskMetrics;
    mapping(address => YieldMetrics) public yieldMetrics;
    mapping(address => uint256[]) public priceHistory; // Last 30 days
    mapping(address => bool) public authorizedUpdaters;
    
    uint256 public constant PRECISION = 1e18;
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant SECONDS_PER_DAY = 86400;
    uint256 public constant DAYS_PER_YEAR = 365;
    uint256 public constant MAX_HISTORY_LENGTH = 30;
    
    uint256 public riskFreeRate = 200; // 2% in basis points
    uint256 public confidenceLevel = 9500; // 95% in basis points

    event PoolRatioUpdated(
        address indexed pool,
        uint256 token0Reserve,
        uint256 token1Reserve,
        uint256 priceRatio
    );

    event RiskMetricsUpdated(
        address indexed pool,
        uint256 sharpeRatio,
        uint256 volatility,
        uint256 riskScore
    );

    event YieldMetricsUpdated(
        address indexed pool,
        uint256 apy,
        uint256 apr,
        uint256 timeWeightedReturn
    );

    modifier onlyAuthorized() {
        require(authorizedUpdaters[msg.sender] || msg.sender == owner(), "Not authorized");
        _;
    }

    constructor() Ownable(msg.sender) {}

    /**
     * @dev Calculate optimal liquidity ratio for a pool
     * @param token0Amount Amount of token0
     * @param token1Amount Amount of token1
     * @param currentRatio Current price ratio
     * @return optimalToken0 Optimal token0 amount
     * @return optimalToken1 Optimal token1 amount
     */
    function calculateOptimalRatio(
        uint256 token0Amount,
        uint256 token1Amount,
        uint256 currentRatio
    ) external pure returns (uint256 optimalToken0, uint256 optimalToken1) {
        require(currentRatio > 0, "Invalid ratio");
        
        // Calculate total value in token0 terms
        uint256 totalValueInToken0 = token0Amount + (token1Amount * PRECISION / currentRatio);
        
        // Optimal split: 50/50 value
        optimalToken0 = totalValueInToken0 / 2;
        optimalToken1 = (totalValueInToken0 / 2) * currentRatio / PRECISION;
        
        return (optimalToken0, optimalToken1);
    }

    /**
     * @dev Calculate impermanent loss
     * @param initialRatio Initial price ratio
     * @param currentRatio Current price ratio
     * @return impermanentLoss Impermanent loss percentage (basis points)
     */
    function calculateImpermanentLoss(
        uint256 initialRatio,
        uint256 currentRatio
    ) external pure returns (uint256 impermanentLoss) {
        require(initialRatio > 0 && currentRatio > 0, "Invalid ratios");
        
        // IL = 2 * sqrt(r) / (1 + r) - 1
        // where r = currentRatio / initialRatio
        uint256 r = currentRatio * PRECISION / initialRatio;
        uint256 sqrtR = Math.sqrt(r);
        
        uint256 numerator = 2 * sqrtR;
        uint256 denominator = PRECISION + r;
        
        if (numerator >= denominator) {
            return 0; // No impermanent loss
        }
        
        impermanentLoss = (denominator - numerator) * BASIS_POINTS / denominator;
        return impermanentLoss;
    }

    /**
     * @dev Calculate Sharpe ratio
     * @param returnValues Array of historical returns
     * @param riskFreeReturn Risk-free return rate
     * @return sharpeRatio Sharpe ratio * PRECISION
     */
    function calculateSharpeRatio(
        uint256[] calldata returnValues,
        uint256 riskFreeReturn
    ) external pure returns (uint256 sharpeRatio) {
        require(returnValues.length > 1, "Insufficient data");
        
        // Calculate mean return
        uint256 totalReturn = 0;
        for (uint256 i = 0; i < returnValues.length; i++) {
            totalReturn += returnValues[i];
        }
        uint256 meanReturn = totalReturn / returnValues.length;
        
        // Calculate standard deviation
        uint256 variance = 0;
        for (uint256 i = 0; i < returnValues.length; i++) {
            uint256 diff = returnValues[i] > meanReturn ? 
                returnValues[i] - meanReturn : meanReturn - returnValues[i];
            variance += diff * diff;
        }
        variance = variance / returnValues.length;
        uint256 stdDev = Math.sqrt(variance);
        
        if (stdDev == 0) return 0;
        
        // Sharpe ratio = (mean return - risk free rate) / standard deviation
        if (meanReturn <= riskFreeReturn) return 0;
        
        sharpeRatio = (meanReturn - riskFreeReturn) * PRECISION / stdDev;
        return sharpeRatio;
    }

    /**
     * @dev Calculate volatility from price history
     * @param prices Array of historical prices
     * @return volatility Annualized volatility * PRECISION
     */
    function calculateVolatility(uint256[] calldata prices) external pure returns (uint256 volatility) {
        require(prices.length > 1, "Insufficient data");
        
        // Calculate daily returns
        uint256[] memory dailyReturns = new uint256[](prices.length - 1);
        for (uint256 i = 1; i < prices.length; i++) {
            if (prices[i-1] > 0) {
                dailyReturns[i-1] = prices[i] * PRECISION / prices[i-1];
            }
        }
        
        // Calculate mean return
        uint256 totalReturn = 0;
        for (uint256 i = 0; i < dailyReturns.length; i++) {
            totalReturn += dailyReturns[i];
        }
        uint256 meanReturn = totalReturn / dailyReturns.length;
        
        // Calculate variance
        uint256 variance = 0;
        for (uint256 i = 0; i < dailyReturns.length; i++) {
            uint256 diff = dailyReturns[i] > meanReturn ? 
                dailyReturns[i] - meanReturn : meanReturn - dailyReturns[i];
            variance += diff * diff;
        }
        variance = variance / dailyReturns.length;
        
        // Annualize volatility (daily to yearly)
        volatility = Math.sqrt(variance * DAYS_PER_YEAR);
        return volatility;
    }

    /**
     * @dev Calculate APY from APR
     * @param apr Annual percentage rate (basis points)
     * @param compoundFrequency Compounding frequency per year
     * @return apy Annual percentage yield (basis points)
     */
    function calculateAPY(uint256 apr, uint256 compoundFrequency) external pure returns (uint256 apy) {
        require(compoundFrequency > 0, "Invalid frequency");
        
        // APY = (1 + APR/n)^n - 1
        // Simplified calculation for reasonable ranges
        uint256 ratePerPeriod = apr / compoundFrequency;
        uint256 compoundedRate = PRECISION;
        
        // Calculate (1 + rate)^n using repeated multiplication
        for (uint256 i = 0; i < compoundFrequency; i++) {
            compoundedRate = compoundedRate * (PRECISION + ratePerPeriod * PRECISION / BASIS_POINTS) / PRECISION;
        }
        
        apy = (compoundedRate - PRECISION) * BASIS_POINTS / PRECISION;
        return apy;
    }

    /**
     * @dev Calculate Value at Risk (VaR)
     * @param returnValues Array of historical returns
     * @param confidence Confidence level (basis points)
     * @return valueAtRisk Value at Risk
     */
    function calculateVaR(
        uint256[] calldata returnValues,
        uint256 confidence
    ) external pure returns (uint256 valueAtRisk) {
        require(returnValues.length > 0, "No data");
        require(confidence <= BASIS_POINTS, "Invalid confidence");
        
        // Sort returns (simplified bubble sort for small arrays)
        uint256[] memory sortedReturns = new uint256[](returnValues.length);
        for (uint256 i = 0; i < returnValues.length; i++) {
            sortedReturns[i] = returnValues[i];
        }
        
        // Simple sorting
        for (uint256 i = 0; i < sortedReturns.length - 1; i++) {
            for (uint256 j = 0; j < sortedReturns.length - i - 1; j++) {
                if (sortedReturns[j] > sortedReturns[j + 1]) {
                    uint256 temp = sortedReturns[j];
                    sortedReturns[j] = sortedReturns[j + 1];
                    sortedReturns[j + 1] = temp;
                }
            }
        }
        
        // Find percentile
        uint256 index = (BASIS_POINTS - confidence) * sortedReturns.length / BASIS_POINTS;
        if (index >= sortedReturns.length) index = sortedReturns.length - 1;
        
        valueAtRisk = sortedReturns[index];
        return valueAtRisk;
    }

    /**
     * @dev Update pool ratio data
     * @param pool Pool address
     * @param token0Reserve Token0 reserve amount
     * @param token1Reserve Token1 reserve amount
     * @param totalLiquidity Total liquidity
     */
    function updatePoolRatio(
        address pool,
        uint256 token0Reserve,
        uint256 token1Reserve,
        uint256 totalLiquidity
    ) external onlyAuthorized {
        require(pool != address(0), "Invalid pool");
        require(token0Reserve > 0 && token1Reserve > 0, "Invalid reserves");
        
        uint256 priceRatio = token1Reserve * PRECISION / token0Reserve;
        
        poolRatios[pool] = PoolRatio({
            token0Reserve: token0Reserve,
            token1Reserve: token1Reserve,
            totalLiquidity: totalLiquidity,
            lastUpdateTime: block.timestamp,
            priceRatio: priceRatio,
            volatility: 0 // Will be calculated separately
        });
        
        // Update price history
        priceHistory[pool].push(priceRatio);
        if (priceHistory[pool].length > MAX_HISTORY_LENGTH) {
            // Remove oldest entry
            for (uint256 i = 0; i < priceHistory[pool].length - 1; i++) {
                priceHistory[pool][i] = priceHistory[pool][i + 1];
            }
            priceHistory[pool].pop();
        }
        
        emit PoolRatioUpdated(pool, token0Reserve, token1Reserve, priceRatio);
    }

    /**
     * @dev Update risk metrics for a pool
     * @param pool Pool address
     * @param metrics Risk metrics struct
     */
    function updateRiskMetrics(address pool, RiskMetrics calldata metrics) external onlyAuthorized {
        require(pool != address(0), "Invalid pool");
        require(metrics.riskScore <= 100, "Invalid risk score");
        
        riskMetrics[pool] = metrics;
        emit RiskMetricsUpdated(pool, metrics.sharpeRatio, metrics.volatility, metrics.riskScore);
    }

    /**
     * @dev Update yield metrics for a pool
     * @param pool Pool address
     * @param metrics Yield metrics struct
     */
    function updateYieldMetrics(address pool, YieldMetrics calldata metrics) external onlyAuthorized {
        require(pool != address(0), "Invalid pool");
        
        yieldMetrics[pool] = metrics;
        emit YieldMetricsUpdated(pool, metrics.apy, metrics.apr, metrics.timeWeightedReturn);
    }

    /**
     * @dev Set authorized updater status
     * @param updater Updater address
     * @param authorized Authorization status
     */
    function setAuthorizedUpdater(address updater, bool authorized) external onlyOwner {
        authorizedUpdaters[updater] = authorized;
    }

    /**
     * @dev Update global parameters
     * @param _riskFreeRate New risk-free rate (basis points)
     * @param _confidenceLevel New confidence level (basis points)
     */
    function updateGlobalParams(uint256 _riskFreeRate, uint256 _confidenceLevel) external onlyOwner {
        require(_riskFreeRate <= 2000, "Risk-free rate too high"); // Max 20%
        require(_confidenceLevel <= BASIS_POINTS, "Invalid confidence level");
        
        riskFreeRate = _riskFreeRate;
        confidenceLevel = _confidenceLevel;
    }

    /**
     * @dev Get pool ratio data
     * @param pool Pool address
     * @return ratio Pool ratio struct
     */
    function getPoolRatio(address pool) external view returns (PoolRatio memory ratio) {
        return poolRatios[pool];
    }

    /**
     * @dev Get risk metrics
     * @param pool Pool address
     * @return metrics Risk metrics struct
     */
    function getRiskMetrics(address pool) external view returns (RiskMetrics memory metrics) {
        return riskMetrics[pool];
    }

    /**
     * @dev Get yield metrics
     * @param pool Pool address
     * @return metrics Yield metrics struct
     */
    function getYieldMetrics(address pool) external view returns (YieldMetrics memory metrics) {
        return yieldMetrics[pool];
    }

    /**
     * @dev Get price history
     * @param pool Pool address
     * @return prices Array of historical prices
     */
    function getPriceHistory(address pool) external view returns (uint256[] memory prices) {
        return priceHistory[pool];
    }

    /**
     * @dev Calculate risk-adjusted return
     * @param pool Pool address
     * @return riskAdjustedReturn Risk-adjusted return
     */
    function getRiskAdjustedReturn(address pool) external view returns (uint256 riskAdjustedReturn) {
        RiskMetrics memory metrics = riskMetrics[pool];
        YieldMetrics memory yields = yieldMetrics[pool];
        
        if (metrics.riskScore == 0) return yields.expectedReturn;
        
        // Adjust return based on risk score (higher risk = lower adjusted return)
        riskAdjustedReturn = yields.apy * (100 - metrics.riskScore) / 100;
        return riskAdjustedReturn;
    }
}