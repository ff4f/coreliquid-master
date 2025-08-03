// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title RatioCalculator
 * @dev Utility contract for calculating ratios and proportions
 */
library RatioCalculator {
    using Math for uint256;
    
    uint256 public constant PRECISION = 1e18;
    uint256 public constant MAX_RATIO = 1e18; // 100%
    
    /**
     * @dev Calculate ratio between two values
     * @param numerator The numerator value
     * @param denominator The denominator value
     * @return ratio The calculated ratio with PRECISION decimals
     */
    function calculateRatio(uint256 numerator, uint256 denominator) internal pure returns (uint256) {
        require(denominator > 0, "RatioCalculator: denominator cannot be zero");
        return (numerator * PRECISION) / denominator;
    }
    
    /**
     * @dev Apply ratio to a value
     * @param value The value to apply ratio to
     * @param ratio The ratio to apply (with PRECISION decimals)
     * @return result The result after applying ratio
     */
    function applyRatio(uint256 value, uint256 ratio) internal pure returns (uint256) {
        return (value * ratio) / PRECISION;
    }
    
    /**
     * @dev Calculate proportional distribution
     * @param totalAmount Total amount to distribute
     * @param userAmount User's share amount
     * @param totalShares Total shares
     * @return userPortion User's proportional portion
     */
    function calculateProportion(
        uint256 totalAmount,
        uint256 userAmount,
        uint256 totalShares
    ) internal pure returns (uint256) {
        require(totalShares > 0, "RatioCalculator: total shares cannot be zero");
        return (totalAmount * userAmount) / totalShares;
    }
    
    /**
     * @dev Calculate weighted average
     * @param values Array of values
     * @param weights Array of weights
     * @return weightedAvg The weighted average
     */
    function calculateWeightedAverage(
        uint256[] memory values,
        uint256[] memory weights
    ) internal pure returns (uint256) {
        require(values.length == weights.length, "RatioCalculator: arrays length mismatch");
        require(values.length > 0, "RatioCalculator: empty arrays");
        
        uint256 totalWeightedValue = 0;
        uint256 totalWeight = 0;
        
        for (uint256 i = 0; i < values.length; i++) {
            totalWeightedValue += values[i] * weights[i];
            totalWeight += weights[i];
        }
        
        require(totalWeight > 0, "RatioCalculator: total weight cannot be zero");
        return totalWeightedValue / totalWeight;
    }
    
    /**
     * @dev Check if ratio is within valid bounds
     * @param ratio The ratio to check
     * @return valid True if ratio is valid
     */
    function isValidRatio(uint256 ratio) internal pure returns (bool) {
        return ratio <= MAX_RATIO;
    }
    
    /**
     * @dev Calculate percentage change
     * @param oldValue The old value
     * @param newValue The new value
     * @return change The percentage change (can be negative)
     */
    function calculatePercentageChange(
        uint256 oldValue,
        uint256 newValue
    ) internal pure returns (int256) {
        require(oldValue > 0, "RatioCalculator: old value cannot be zero");
        
        if (newValue >= oldValue) {
            uint256 increase = newValue - oldValue;
            return int256((increase * PRECISION) / oldValue);
        } else {
            uint256 decrease = oldValue - newValue;
            return -int256((decrease * PRECISION) / oldValue);
        }
    }
}
