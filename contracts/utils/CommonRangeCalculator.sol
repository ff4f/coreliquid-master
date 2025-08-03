// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title RangeCalculator
 * @dev Utility contract for calculating optimal price ranges for liquidity positions
 */
library CommonRangeCalculator {
    using Math for uint256;
    
    struct RangeParams {
        uint256 currentPrice;
        uint256 volatility;
        uint256 timeHorizon;
        uint256 riskTolerance;
    }
    
    struct PriceRange {
        uint256 lowerPrice;
        uint256 upperPrice;
        uint256 optimalPrice;
    }
    
    /**
     * @dev Calculate optimal price range based on current market conditions
     * @param params Range calculation parameters
     * @return range Calculated price range
     */
    function calculateOptimalRange(
        RangeParams memory params
    ) internal pure returns (PriceRange memory range) {
        // Simple range calculation based on volatility
        uint256 volatilityAdjustment = (params.currentPrice * params.volatility) / 10000;
        
        range.lowerPrice = params.currentPrice - volatilityAdjustment;
        range.upperPrice = params.currentPrice + volatilityAdjustment;
        range.optimalPrice = params.currentPrice;
        
        // Ensure minimum range
        if (range.upperPrice - range.lowerPrice < params.currentPrice / 100) {
            uint256 minRange = params.currentPrice / 100;
            range.lowerPrice = params.currentPrice - (minRange / 2);
            range.upperPrice = params.currentPrice + (minRange / 2);
        }
    }
    
    /**
     * @dev Calculate range based on historical volatility
     * @param currentPrice Current asset price
     * @param historicalVolatility Historical volatility (basis points)
     * @return range Calculated price range
     */
    function calculateVolatilityBasedRange(
        uint256 currentPrice,
        uint256 historicalVolatility
    ) internal pure returns (PriceRange memory range) {
        uint256 adjustment = (currentPrice * historicalVolatility) / 10000;
        
        range.lowerPrice = currentPrice - adjustment;
        range.upperPrice = currentPrice + adjustment;
        range.optimalPrice = currentPrice;
    }
}
