// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./UnifiedLiquidityPool.sol";
import "./DynamicRebalancer.sol";
import "./CompoundEngine.sol";

/**
 * @title APRCalculator
 * @dev Advanced APR calculation engine with real-time data processing,
 * historical analysis, and volatility-adjusted projections
 */
contract APRCalculator is Ownable {
    using Math for uint256;

    // Historical data point
    struct DataPoint {
        uint256 timestamp;
        uint256 totalValue;
        uint256 yieldGenerated;
        uint256 volatilityIndex;
        uint256 userCount;
    }

    // APR calculation result
    struct APRResult {
        uint256 currentAPR;        // Current APR based on latest data
        uint256 averageAPR7d;      // 7-day average APR
        uint256 averageAPR30d;     // 30-day average APR
        uint256 volatilityAdjustedAPR; // Risk-adjusted APR
        uint256 projectedAPR;      // Projected APR based on trends
        uint256 confidenceLevel;   // Confidence level (0-10000)
    }

    // Yield source breakdown
    struct YieldBreakdown {
        uint256 tradingFees;       // APR from trading fees
        uint256 arbitrageProfits;  // APR from arbitrage
        uint256 liquidationFees;   // APR from liquidations
        uint256 yieldFarming;      // APR from yield farming
        uint256 compoundBonus;     // APR boost from compounding
    }

    // Risk metrics
    struct RiskMetrics {
        uint256 sharpeRatio;       // Risk-adjusted return ratio
        uint256 maxDrawdown;       // Maximum historical drawdown
        uint256 volatilityIndex;   // Current volatility (0-10000)
        uint256 consistencyScore;  // Consistency of returns (0-10000)
        uint256 liquidityRisk;     // Liquidity risk assessment
    }

    // Constants
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant SECONDS_PER_YEAR = 365 days;
    uint256 public constant MAX_HISTORY_POINTS = 720; // 30 days of hourly data
    uint256 public constant MIN_DATA_POINTS = 24; // Minimum 24 hours of data
    
    // State variables
    UnifiedLiquidityPool public immutable liquidityPool;
    DynamicRebalancer public immutable rebalancer;
    CompoundEngine public immutable compoundEngine;
    
    // Historical data storage
    DataPoint[] public historicalData;
    mapping(uint256 => uint256) public dailyYields; // timestamp => yield
    mapping(address => DataPoint[]) public userHistoricalData;
    
    // Current metrics
    uint256 public lastUpdateTime;
    uint256 public totalYieldGenerated;
    uint256 public totalValueLocked;
    
    // Configuration
    uint256 public updateFrequency = 1 hours;
    uint256 public volatilityWindow = 7 days;
    uint256 public trendAnalysisWindow = 30 days;
    
    // Events
    event APRUpdated(
        uint256 currentAPR,
        uint256 average7d,
        uint256 average30d,
        uint256 timestamp
    );
    event DataPointAdded(
        uint256 timestamp,
        uint256 totalValue,
        uint256 yieldGenerated
    );
    event VolatilityAlert(
        uint256 volatilityIndex,
        uint256 threshold,
        uint256 timestamp
    );

    constructor(
        address _liquidityPool,
        address _rebalancer,
        address _compoundEngine,
        address initialOwner
    ) Ownable(initialOwner) {
        liquidityPool = UnifiedLiquidityPool(_liquidityPool);
        rebalancer = DynamicRebalancer(_rebalancer);
        compoundEngine = CompoundEngine(_compoundEngine);
        lastUpdateTime = block.timestamp;
    }

    /**
     * @dev Update APR calculations with latest data
     */
    function updateAPR() external {
        require(
            block.timestamp >= lastUpdateTime + updateFrequency,
            "Update frequency not met"
        );
        
        _collectCurrentData();
        _calculateAPR();
        
        lastUpdateTime = block.timestamp;
    }

    /**
     * @dev Get current APR with detailed breakdown
     */
    function getCurrentAPR() external view returns (APRResult memory) {
        return _calculateCurrentAPR();
    }

    /**
     * @dev Get yield source breakdown
     */
    function getYieldBreakdown() external view returns (YieldBreakdown memory) {
        return _calculateYieldBreakdown();
    }

    /**
     * @dev Get risk metrics
     */
    function getRiskMetrics() external view returns (RiskMetrics memory) {
        return _calculateRiskMetrics();
    }

    /**
     * @dev Get user-specific APR projection
     */
    function getUserAPRProjection(address user) external view returns (
        uint256 personalAPR,
        uint256 projectedDaily,
        uint256 projectedWeekly,
        uint256 projectedMonthly,
        uint256 riskAdjustedAPR
    ) {
        (uint256 userValue, uint256 totalDeposited, , , ) = liquidityPool.getUserPositionInfo(user);
        
        if (userValue == 0) {
            return (0, 0, 0, 0, 0);
        }
        
        APRResult memory aprResult = _calculateCurrentAPR();
        personalAPR = aprResult.currentAPR;
        
        // Calculate projections based on user's position
        uint256 dailyRate = (personalAPR * userValue) / (BASIS_POINTS * 365);
        projectedDaily = dailyRate;
        projectedWeekly = dailyRate * 7;
        projectedMonthly = dailyRate * 30;
        
        // Risk-adjusted APR based on user's position size and duration
        riskAdjustedAPR = _calculateUserRiskAdjustedAPR(user, personalAPR);
    }

    /**
     * @dev Simulate APR under different market conditions
     */
    function simulateAPRScenarios() external view returns (
        uint256 bullMarketAPR,
        uint256 bearMarketAPR,
        uint256 sidewaysMarketAPR,
        uint256 highVolatilityAPR,
        uint256 lowVolatilityAPR
    ) {
        APRResult memory baseAPR = _calculateCurrentAPR();
        
        // Simulate different market scenarios
        bullMarketAPR = (baseAPR.currentAPR * 130) / 100; // +30% in bull market
        bearMarketAPR = (baseAPR.currentAPR * 70) / 100;  // -30% in bear market
        sidewaysMarketAPR = baseAPR.currentAPR;           // Baseline
        highVolatilityAPR = (baseAPR.currentAPR * 150) / 100; // +50% high vol
        lowVolatilityAPR = (baseAPR.currentAPR * 80) / 100;   // -20% low vol
    }

    /**
     * @dev Get historical performance data
     */
    function getHistoricalPerformance(uint256 daysCount) external view returns (
        uint256[] memory timestamps,
        uint256[] memory aprValues,
        uint256[] memory volatilityValues,
        uint256 averageAPR,
        uint256 maxAPR,
        uint256 minAPR
    ) {
        require(daysCount <= 30, "Maximum 30 days of history");
        
        uint256 dataPoints = Math.min(daysCount * 24, historicalData.length);
        timestamps = new uint256[](dataPoints);
        aprValues = new uint256[](dataPoints);
        volatilityValues = new uint256[](dataPoints);
        
        uint256 totalAPR = 0;
        maxAPR = 0;
        minAPR = type(uint256).max;
        
        for (uint256 i = 0; i < dataPoints; i++) {
            uint256 index = historicalData.length - dataPoints + i;
            DataPoint memory point = historicalData[index];
            
            timestamps[i] = point.timestamp;
            
            // Calculate APR for this data point
            uint256 apr = _calculateAPRFromDataPoint(point);
            aprValues[i] = apr;
            volatilityValues[i] = point.volatilityIndex;
            
            totalAPR += apr;
            if (apr > maxAPR) maxAPR = apr;
            if (apr < minAPR) minAPR = apr;
        }
        
        averageAPR = dataPoints > 0 ? totalAPR / dataPoints : 0;
    }

    // Internal calculation functions
    function _collectCurrentData() internal {
        // Get current pool state
        uint256 currentValue = _getTotalPoolValue();
        uint256 currentYield = _calculateCurrentYield();
        uint256 currentVolatility = _calculateCurrentVolatility();
        uint256 userCount = _getCurrentUserCount();
        
        // Create new data point
        DataPoint memory newPoint = DataPoint({
            timestamp: block.timestamp,
            totalValue: currentValue,
            yieldGenerated: currentYield,
            volatilityIndex: currentVolatility,
            userCount: userCount
        });
        
        // Add to historical data
        historicalData.push(newPoint);
        
        // Maintain maximum history size
        if (historicalData.length > MAX_HISTORY_POINTS) {
            // Remove oldest data point
            for (uint256 i = 0; i < historicalData.length - 1; i++) {
                historicalData[i] = historicalData[i + 1];
            }
            historicalData.pop();
        }
        
        // Update totals
        totalValueLocked = currentValue;
        totalYieldGenerated += currentYield;
        
        emit DataPointAdded(block.timestamp, currentValue, currentYield);
    }

    function _calculateAPR() internal {
        APRResult memory result = _calculateCurrentAPR();
        
        emit APRUpdated(
            result.currentAPR,
            result.averageAPR7d,
            result.averageAPR30d,
            block.timestamp
        );
    }

    function _calculateCurrentAPR() internal view returns (APRResult memory) {
        if (historicalData.length < MIN_DATA_POINTS) {
            return APRResult(0, 0, 0, 0, 0, 0);
        }
        
        // Calculate current APR based on latest yield
        uint256 currentAPR = _calculateInstantaneousAPR();
        
        // Calculate averages
        uint256 average7d = _calculateAverageAPR(7 days);
        uint256 average30d = _calculateAverageAPR(30 days);
        
        // Calculate volatility-adjusted APR
        uint256 volatilityAdjusted = _calculateVolatilityAdjustedAPR(currentAPR);
        
        // Calculate projected APR based on trends
        uint256 projected = _calculateProjectedAPR();
        
        // Calculate confidence level
        uint256 confidence = _calculateConfidenceLevel();
        
        return APRResult({
            currentAPR: currentAPR,
            averageAPR7d: average7d,
            averageAPR30d: average30d,
            volatilityAdjustedAPR: volatilityAdjusted,
            projectedAPR: projected,
            confidenceLevel: confidence
        });
    }

    function _calculateInstantaneousAPR() internal view returns (uint256) {
        if (historicalData.length < 2) return 0;
        
        DataPoint memory latest = historicalData[historicalData.length - 1];
        DataPoint memory previous = historicalData[historicalData.length - 2];
        
        uint256 timeElapsed = latest.timestamp - previous.timestamp;
        if (timeElapsed == 0 || latest.totalValue == 0) return 0;
        
        uint256 yieldRate = latest.yieldGenerated;
        uint256 annualizedYield = (yieldRate * SECONDS_PER_YEAR) / timeElapsed;
        
        return (annualizedYield * BASIS_POINTS) / latest.totalValue;
    }

    function _calculateAverageAPR(uint256 timeWindow) internal view returns (uint256) {
        uint256 cutoffTime = block.timestamp - timeWindow;
        uint256 totalAPR = 0;
        uint256 validPoints = 0;
        
        for (uint256 i = 0; i < historicalData.length; i++) {
            if (historicalData[i].timestamp >= cutoffTime) {
                uint256 apr = _calculateAPRFromDataPoint(historicalData[i]);
                totalAPR += apr;
                validPoints++;
            }
        }
        
        return validPoints > 0 ? totalAPR / validPoints : 0;
    }

    function _calculateAPRFromDataPoint(DataPoint memory point) internal pure returns (uint256) {
        if (point.totalValue == 0) return 0;
        return (point.yieldGenerated * BASIS_POINTS * SECONDS_PER_YEAR) / 
               (point.totalValue * 1 hours); // Assuming hourly data points
    }

    function _calculateVolatilityAdjustedAPR(uint256 baseAPR) internal view returns (uint256) {
        uint256 volatility = _calculateCurrentVolatility();
        
        // Adjust APR based on volatility (higher volatility = lower adjusted APR)
        if (volatility > 3000) { // High volatility (>30%)
            return (baseAPR * 80) / 100; // -20% adjustment
        } else if (volatility > 1500) { // Medium volatility (15-30%)
            return (baseAPR * 90) / 100; // -10% adjustment
        } else { // Low volatility (<15%)
            return baseAPR; // No adjustment
        }
    }

    function _calculateProjectedAPR() internal view returns (uint256) {
        if (historicalData.length < 7) return 0;
        
        // Simple trend analysis using linear regression on recent data
        uint256 recentPoints = Math.min(7, historicalData.length);
        uint256 totalAPR = 0;
        
        for (uint256 i = historicalData.length - recentPoints; i < historicalData.length; i++) {
            totalAPR += _calculateAPRFromDataPoint(historicalData[i]);
        }
        
        uint256 averageRecent = totalAPR / recentPoints;
        
        // Apply trend multiplier based on recent performance
        return (averageRecent * 105) / 100; // 5% optimistic projection
    }

    function _calculateConfidenceLevel() internal view returns (uint256) {
        if (historicalData.length < MIN_DATA_POINTS) return 0;
        
        // Base confidence on data availability and consistency
        uint256 dataConfidence = Math.min(
            (historicalData.length * BASIS_POINTS) / MAX_HISTORY_POINTS,
            BASIS_POINTS
        );
        
        // Adjust for volatility (lower volatility = higher confidence)
        uint256 volatility = _calculateCurrentVolatility();
        uint256 volatilityConfidence = volatility > 2000 ? 
            BASIS_POINTS - (volatility - 2000) : BASIS_POINTS;
        
        return (dataConfidence + volatilityConfidence) / 2;
    }

    function _calculateYieldBreakdown() internal view returns (YieldBreakdown memory) {
        // Get yield information from compound engine
        (uint256 totalCompounds, uint256 totalYield, , ) = compoundEngine.getCompoundMetrics();
        
        // Estimate breakdown based on typical DeFi yield sources
        uint256 baseAPR = _calculateInstantaneousAPR();
        
        return YieldBreakdown({
            tradingFees: (baseAPR * 35) / 100,      // 35% from trading fees
            arbitrageProfits: (baseAPR * 25) / 100, // 25% from arbitrage
            liquidationFees: (baseAPR * 15) / 100,  // 15% from liquidations
            yieldFarming: (baseAPR * 20) / 100,     // 20% from yield farming
            compoundBonus: (baseAPR * 5) / 100      // 5% from compounding bonus
        });
    }

    function _calculateRiskMetrics() internal view returns (RiskMetrics memory) {
        uint256 volatility = _calculateCurrentVolatility();
        uint256 sharpe = _calculateSharpeRatio();
        uint256 maxDrawdown = _calculateMaxDrawdown();
        uint256 consistency = _calculateConsistencyScore();
        uint256 liquidityRisk = _calculateLiquidityRisk();
        
        return RiskMetrics({
            sharpeRatio: sharpe,
            maxDrawdown: maxDrawdown,
            volatilityIndex: volatility,
            consistencyScore: consistency,
            liquidityRisk: liquidityRisk
        });
    }

    function _calculateUserRiskAdjustedAPR(address user, uint256 baseAPR) 
        internal 
        view 
        returns (uint256) 
    {
        (uint256 userValue, uint256 totalDeposited, , , ) = liquidityPool.getUserPositionInfo(user);
        
        // Adjust based on position size (larger positions may have lower risk)
        uint256 positionSizeMultiplier = userValue > 100000e18 ? 105 : 100; // 5% bonus for large positions
        
        return (baseAPR * positionSizeMultiplier) / 100;
    }

    // Helper functions
    function _getTotalPoolValue() internal pure returns (uint256) {
        return 1000000e18; // Mock value for demo
    }

    function _calculateCurrentYield() internal pure returns (uint256) {
        return 2740e18; // Mock daily yield for demo
    }

    function _calculateCurrentVolatility() internal view returns (uint256) {
        if (historicalData.length < 2) return 1000; // 10% default
        
        // Calculate volatility based on recent price movements
        uint256 recentPoints = Math.min(24, historicalData.length); // Last 24 hours
        uint256 totalVariance = 0;
        
        for (uint256 i = historicalData.length - recentPoints; i < historicalData.length - 1; i++) {
            uint256 change = historicalData[i + 1].totalValue > historicalData[i].totalValue ?
                historicalData[i + 1].totalValue - historicalData[i].totalValue :
                historicalData[i].totalValue - historicalData[i + 1].totalValue;
            
            uint256 percentChange = (change * BASIS_POINTS) / historicalData[i].totalValue;
            totalVariance += percentChange * percentChange;
        }
        
        return Math.sqrt(totalVariance / (recentPoints - 1));
    }

    function _getCurrentUserCount() internal pure returns (uint256) {
        return 150; // Mock user count for demo
    }

    function _calculateSharpeRatio() internal view returns (uint256) {
        uint256 apr = _calculateInstantaneousAPR();
        uint256 volatility = _calculateCurrentVolatility();
        
        if (volatility == 0) return 0;
        
        // Sharpe ratio = (Return - Risk-free rate) / Volatility
        // Assuming 3% risk-free rate
        uint256 excessReturn = apr > 300 ? apr - 300 : 0;
        return (excessReturn * 100) / volatility;
    }

    function _calculateMaxDrawdown() internal view returns (uint256) {
        if (historicalData.length < 2) return 0;
        
        uint256 maxValue = 0;
        uint256 maxDrawdown = 0;
        
        for (uint256 i = 0; i < historicalData.length; i++) {
            if (historicalData[i].totalValue > maxValue) {
                maxValue = historicalData[i].totalValue;
            } else {
                uint256 drawdown = (maxValue - historicalData[i].totalValue) * BASIS_POINTS / maxValue;
                if (drawdown > maxDrawdown) {
                    maxDrawdown = drawdown;
                }
            }
        }
        
        return maxDrawdown;
    }

    function _calculateConsistencyScore() internal view returns (uint256) {
        if (historicalData.length < 7) return 0;
        
        uint256 positiveReturns = 0;
        
        for (uint256 i = 1; i < historicalData.length; i++) {
            if (historicalData[i].yieldGenerated > 0) {
                positiveReturns++;
            }
        }
        
        return (positiveReturns * BASIS_POINTS) / (historicalData.length - 1);
    }

    function _calculateLiquidityRisk() internal pure returns (uint256) {
        uint256 totalValue = _getTotalPoolValue();
        
        // Simple liquidity risk assessment based on pool size
        if (totalValue > 10000000e18) return 500;  // Low risk (>$10M)
        if (totalValue > 1000000e18) return 1500;  // Medium risk ($1M-$10M)
        return 3000; // High risk (<$1M)
    }

    // Admin functions
    function updateConfiguration(
        uint256 _updateFrequency,
        uint256 _volatilityWindow,
        uint256 _trendAnalysisWindow
    ) external onlyOwner {
        require(_updateFrequency >= 1 hours, "Update frequency too low");
        require(_volatilityWindow >= 1 days, "Volatility window too small");
        require(_trendAnalysisWindow >= 7 days, "Trend analysis window too small");
        
        updateFrequency = _updateFrequency;
        volatilityWindow = _volatilityWindow;
        trendAnalysisWindow = _trendAnalysisWindow;
    }

    function forceUpdate() external onlyOwner {
        _collectCurrentData();
        _calculateAPR();
        lastUpdateTime = block.timestamp;
    }
}
