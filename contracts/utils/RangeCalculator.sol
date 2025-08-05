// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title RangeCalculator
 * @dev Utility contract for calculating price ranges and liquidity positions
 */
contract RangeCalculator {
    using Math for uint256;

    uint256 public constant PRECISION = 1e18;
    uint256 public constant BASIS_POINTS = 10000;

    struct PriceRange {
        uint256 lowerBound;
        uint256 upperBound;
        uint256 currentPrice;
        uint256 volatility;
    }

    /**
     * @dev Calculate optimal price range based on volatility
     * @param currentPrice Current asset price
     * @param volatility Volatility factor (basis points)
     * @return range Calculated price range
     */
    function calculateOptimalRange(
        uint256 currentPrice,
        uint256 volatility
    ) external pure returns (PriceRange memory range) {
        require(currentPrice > 0, "Invalid price");
        require(volatility <= BASIS_POINTS, "Invalid volatility");

        uint256 deviation = currentPrice * volatility / BASIS_POINTS;
        
        range = PriceRange({
            lowerBound: currentPrice - deviation,
            upperBound: currentPrice + deviation,
            currentPrice: currentPrice,
            volatility: volatility
        });
    }

    /**
     * @dev Calculate liquidity distribution
     * @param totalLiquidity Total liquidity amount
     * @param range Price range
     * @return distribution Liquidity distribution array
     */
    function calculateLiquidityDistribution(
        uint256 totalLiquidity,
        PriceRange memory range
    ) external pure returns (uint256[] memory distribution) {
        distribution = new uint256[](3);
        
        // Simple equal distribution for now
        distribution[0] = totalLiquidity / 3; // Lower range
        distribution[1] = totalLiquidity / 3; // Middle range
        distribution[2] = totalLiquidity - distribution[0] - distribution[1]; // Upper range
    }

    /**
     * @dev Check if price is within range
     * @param price Price to check
     * @param range Price range
     * @return inRange True if price is within range
     */
    function isPriceInRange(
        uint256 price,
        PriceRange memory range
    ) external pure returns (bool inRange) {
        return price >= range.lowerBound && price <= range.upperBound;
    }
}