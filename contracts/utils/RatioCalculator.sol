// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title RatioCalculator
 * @dev Calculates optimal token amounts for liquidity provision
 */
contract RatioCalculator is Ownable {
    using Math for uint256;
    
    uint256 public constant PRECISION = 1e18;
    uint256 public slippageTolerance = 50; // 0.5% default
    
    struct OptimalAmounts {
        uint256 optimalA;
        uint256 optimalB;
        uint256 ratio;
        uint256 priceImpact;
    }
    
    event OptimalAmountsCalculated(
        uint256 inputA,
        uint256 inputB,
        uint256 optimalA,
        uint256 optimalB,
        uint256 ratio
    );
    
    constructor(address initialOwner) Ownable(initialOwner) {}
    
    function setSlippageTolerance(uint256 _tolerance) external onlyOwner {
        require(_tolerance <= 1000, "Max 10% slippage"); // Max 10%
        slippageTolerance = _tolerance;
    }
    
    function computeOptimalAmounts(
        uint256 amtA,
        uint256 amtB,
        uint256 reserveA,
        uint256 reserveB
    ) external returns (uint256 optA, uint256 optB) {
        require(amtA > 0 || amtB > 0, "Invalid amounts");
        require(reserveA > 0 && reserveB > 0, "Invalid reserves");
        
        // Calculate current pool ratio
        uint256 poolRatio = (reserveB * PRECISION) / reserveA;
        
        if (amtA > 0 && amtB > 0) {
            // Both tokens provided - optimize based on pool ratio
            uint256 requiredB = (amtA * poolRatio) / PRECISION;
            uint256 requiredA = (amtB * PRECISION) / poolRatio;
            
            if (requiredB <= amtB) {
                // Use all of token A
                optA = amtA;
                optB = requiredB;
            } else {
                // Use all of token B
                optA = requiredA;
                optB = amtB;
            }
        } else if (amtA > 0) {
            // Only token A provided
            optA = amtA;
            optB = (amtA * poolRatio) / PRECISION;
        } else {
            // Only token B provided
            optB = amtB;
            optA = (amtB * PRECISION) / poolRatio;
        }
        
        emit OptimalAmountsCalculated(amtA, amtB, optA, optB, poolRatio);
    }
    
    function calculatePriceImpact(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) external pure returns (uint256 priceImpact) {
        require(amountIn > 0 && reserveIn > 0 && reserveOut > 0, "Invalid inputs");
        
        uint256 amountInWithFee = amountIn * 997; // 0.3% fee
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 1000) + amountInWithFee;
        uint256 amountOut = numerator / denominator;
        
        uint256 priceBeforeSwap = (reserveOut * PRECISION) / reserveIn;
        uint256 priceAfterSwap = ((reserveOut - amountOut) * PRECISION) / (reserveIn + amountIn);
        
        if (priceAfterSwap < priceBeforeSwap) {
            priceImpact = ((priceBeforeSwap - priceAfterSwap) * 10000) / priceBeforeSwap;
        }
    }
    
    function getOptimalRatio(uint256 reserveA, uint256 reserveB) external pure returns (uint256) {
        require(reserveA > 0 && reserveB > 0, "Invalid reserves");
        return (reserveB * PRECISION) / reserveA;
    }
}
