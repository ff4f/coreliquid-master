// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title RangeCalculator
 * @dev Utility library for calculating price ranges and tick positions for Uniswap V3
 */
library RangeCalculator {
    using Math for uint256;
    
    uint256 public constant Q96 = 2**96;
    int24 public constant MIN_TICK = -887272;
    int24 public constant MAX_TICK = 887272;
    
    /**
     * @dev Calculate tick from price
     * @param price The price as a Q64.96 fixed point number
     * @return tick The corresponding tick
     */
    function getTickFromPrice(uint160 price) internal pure returns (int24 tick) {
        require(price > 0, "RangeCalculator: price must be greater than 0");
        
        // Simplified tick calculation - in production, use Uniswap's TickMath library
        // This is a basic approximation
        uint256 ratio = uint256(price) * uint256(price) / Q96;
        
        if (ratio >= Q96) {
            tick = int24(int256(Math.log2(ratio / Q96) * 10000));
        } else {
            tick = -int24(int256(Math.log2(Q96 / ratio) * 10000));
        }
        
        // Ensure tick is within bounds
        if (tick < MIN_TICK) tick = MIN_TICK;
        if (tick > MAX_TICK) tick = MAX_TICK;
    }
    
    /**
     * @dev Calculate price from tick
     * @param tick The tick value
     * @return price The corresponding price as Q64.96
     */
    function getPriceFromTick(int24 tick) internal pure returns (uint160 price) {
        require(tick >= MIN_TICK && tick <= MAX_TICK, "RangeCalculator: tick out of range");
        
        // Simplified price calculation - in production, use Uniswap's TickMath library
        if (tick >= 0) {
            uint256 ratio = Q96 * (2 ** uint256(int256(tick / 10000)));
            price = uint160(Math.sqrt(ratio));
        } else {
            uint256 ratio = Q96 / (2 ** uint256(int256(-tick / 10000)));
            price = uint160(Math.sqrt(ratio));
        }
    }
    
    /**
     * @dev Calculate optimal range around current price
     * @param currentPrice Current price as Q64.96
     * @param rangePercent Range percentage (e.g., 10 for ±10%)
     * @return tickLower Lower tick boundary
     * @return tickUpper Upper tick boundary
     */
    function calculateOptimalRange(
        uint160 currentPrice,
        uint256 rangePercent
    ) internal pure returns (int24 tickLower, int24 tickUpper) {
        require(rangePercent > 0 && rangePercent <= 100, "RangeCalculator: invalid range percent");
        
        int24 currentTick = getTickFromPrice(currentPrice);
        
        // Calculate tick spacing based on range percentage
        int24 tickSpacing = int24(int256(rangePercent * 100)); // Simplified spacing
        
        tickLower = currentTick - tickSpacing;
        tickUpper = currentTick + tickSpacing;
        
        // Ensure ticks are within bounds
        if (tickLower < MIN_TICK) tickLower = MIN_TICK;
        if (tickUpper > MAX_TICK) tickUpper = MAX_TICK;
        
        // Ensure tickLower < tickUpper
        require(tickLower < tickUpper, "RangeCalculator: invalid tick range");
    }
    
    /**
     * @dev Calculate range based on volatility
     * @param currentPrice Current price as Q64.96
     * @param volatility Historical volatility (basis points)
     * @param timeHorizon Time horizon in seconds
     * @return tickLower Lower tick boundary
     * @return tickUpper Upper tick boundary
     */
    function calculateVolatilityBasedRange(
        uint160 currentPrice,
        uint256 volatility,
        uint256 timeHorizon
    ) internal pure returns (int24 tickLower, int24 tickUpper) {
        require(volatility > 0, "RangeCalculator: volatility must be positive");
        require(timeHorizon > 0, "RangeCalculator: time horizon must be positive");
        
        int24 currentTick = getTickFromPrice(currentPrice);
        
        // Calculate expected price movement based on volatility and time
        // Simplified calculation: volatility * sqrt(timeHorizon / 1 year)
        uint256 timeAdjustment = Math.sqrt(timeHorizon * 1e18 / (365 * 86400));
        uint256 expectedMovement = volatility * timeAdjustment / 1e9; // Convert from basis points
        
        int24 tickMovement = int24(int256(expectedMovement));
        
        tickLower = currentTick - tickMovement;
        tickUpper = currentTick + tickMovement;
        
        // Ensure ticks are within bounds
        if (tickLower < MIN_TICK) tickLower = MIN_TICK;
        if (tickUpper > MAX_TICK) tickUpper = MAX_TICK;
        
        require(tickLower < tickUpper, "RangeCalculator: invalid tick range");
    }
    
    /**
     * @dev Calculate concentrated liquidity range
     * @param currentPrice Current price as Q64.96
     * @param concentrationFactor Concentration factor (1-100, higher = more concentrated)
     * @return tickLower Lower tick boundary
     * @return tickUpper Upper tick boundary
     */
    function calculateConcentratedRange(
        uint160 currentPrice,
        uint256 concentrationFactor
    ) internal pure returns (int24 tickLower, int24 tickUpper) {
        require(
            concentrationFactor >= 1 && concentrationFactor <= 100,
            "RangeCalculator: invalid concentration factor"
        );
        
        int24 currentTick = getTickFromPrice(currentPrice);
        
        // Higher concentration factor = smaller range
        int24 tickSpacing = int24(int256(10000 / concentrationFactor));
        
        tickLower = currentTick - tickSpacing;
        tickUpper = currentTick + tickSpacing;
        
        // Ensure ticks are within bounds
        if (tickLower < MIN_TICK) tickLower = MIN_TICK;
        if (tickUpper > MAX_TICK) tickUpper = MAX_TICK;
        
        require(tickLower < tickUpper, "RangeCalculator: invalid tick range");
    }
    
    /**
     * @dev Calculate range for maximum fee collection
     * @param currentPrice Current price as Q64.96
     * @param feeGrowthRate Expected fee growth rate (basis points per day)
     * @param targetDuration Target duration for position (days)
     * @return tickLower Lower tick boundary
     * @return tickUpper Upper tick boundary
     */
    function calculateFeeOptimizedRange(
        uint160 currentPrice,
        uint256 feeGrowthRate,
        uint256 targetDuration
    ) internal pure returns (int24 tickLower, int24 tickUpper) {
        require(feeGrowthRate > 0, "RangeCalculator: fee growth rate must be positive");
        require(targetDuration > 0, "RangeCalculator: target duration must be positive");
        
        int24 currentTick = getTickFromPrice(currentPrice);
        
        // Calculate optimal range based on fee collection vs. impermanent loss trade-off
        // Higher fee growth rate allows for tighter ranges
        uint256 rangeMultiplier = 10000 / (feeGrowthRate * targetDuration / 365);
        int24 tickSpacing = int24(int256(rangeMultiplier));
        
        // Ensure minimum range
        if (tickSpacing < 100) tickSpacing = 100;
        if (tickSpacing > 5000) tickSpacing = 5000;
        
        tickLower = currentTick - tickSpacing;
        tickUpper = currentTick + tickSpacing;
        
        // Ensure ticks are within bounds
        if (tickLower < MIN_TICK) tickLower = MIN_TICK;
        if (tickUpper > MAX_TICK) tickUpper = MAX_TICK;
        
        require(tickLower < tickUpper, "RangeCalculator: invalid tick range");
    }
    
    /**
     * @dev Check if current price is within range
     * @param currentPrice Current price as Q64.96
     * @param tickLower Lower tick boundary
     * @param tickUpper Upper tick boundary
     * @return inRange True if price is within range
     */
    function isPriceInRange(
        uint160 currentPrice,
        int24 tickLower,
        int24 tickUpper
    ) internal pure returns (bool inRange) {
        int24 currentTick = getTickFromPrice(currentPrice);
        return currentTick >= tickLower && currentTick <= tickUpper;
    }
    
    /**
     * @dev Calculate distance from current price to range boundaries
     * @param currentPrice Current price as Q64.96
     * @param tickLower Lower tick boundary
     * @param tickUpper Upper tick boundary
     * @return distanceToLower Distance to lower boundary (negative if below)
     * @return distanceToUpper Distance to upper boundary (negative if above)
     */
    function calculateDistanceToRange(
        uint160 currentPrice,
        int24 tickLower,
        int24 tickUpper
    ) internal pure returns (int24 distanceToLower, int24 distanceToUpper) {
        int24 currentTick = getTickFromPrice(currentPrice);
        
        distanceToLower = currentTick - tickLower;
        distanceToUpper = tickUpper - currentTick;
    }
    
    /**
     * @dev Calculate range utilization percentage
     * @param currentPrice Current price as Q64.96
     * @param tickLower Lower tick boundary
     * @param tickUpper Upper tick boundary
     * @return utilization Utilization percentage (0-100)
     */
    function calculateRangeUtilization(
        uint160 currentPrice,
        int24 tickLower,
        int24 tickUpper
    ) internal pure returns (uint256 utilization) {
        if (!isPriceInRange(currentPrice, tickLower, tickUpper)) {
            return 0;
        }
        
        int24 currentTick = getTickFromPrice(currentPrice);
        int24 rangeSize = tickUpper - tickLower;
        int24 positionInRange = currentTick - tickLower;
        
        utilization = uint256(int256(positionInRange)) * 100 / uint256(int256(rangeSize));
    }
}
