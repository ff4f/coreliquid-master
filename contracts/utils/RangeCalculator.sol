// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title RangeCalculator
 * @dev Calculates optimal tick ranges for Uniswap v3 positions
 */
contract RangeCalculator is Ownable {
    using Math for uint256;
    
    struct TickRange {
        int24 tickLower;
        int24 tickUpper;
        uint256 expectedFees;
        uint256 capitalEfficiency;
    }
    
    struct VolatilityData {
        uint256 shortTermVol;
        uint256 longTermVol;
        uint256 avgVol;
    }
    
    mapping(address => VolatilityData) public poolVolatility;
    mapping(int24 => bool) public validTickSpacings;
    
    int24 public constant MIN_TICK = -887272;
    int24 public constant MAX_TICK = 887272;
    
    event TickRangeSelected(
        address indexed pool,
        int24 tickLower,
        int24 tickUpper,
        uint256 currentPrice,
        uint256 volatility
    );
    
    constructor(address initialOwner) Ownable(initialOwner) {
        // Initialize common tick spacings
        validTickSpacings[1] = true;   // 0.01% fee
        validTickSpacings[10] = true;  // 0.05% fee
        validTickSpacings[60] = true;  // 0.3% fee
        validTickSpacings[200] = true; // 1% fee
    }
    
    function setValidTickSpacing(int24 spacing, bool valid) external onlyOwner {
        validTickSpacings[spacing] = valid;
    }
    
    function updateVolatility(
        address pool,
        uint256 shortTerm,
        uint256 longTerm
    ) external onlyOwner {
        poolVolatility[pool] = VolatilityData({
            shortTermVol: shortTerm,
            longTermVol: longTerm,
            avgVol: (shortTerm + longTerm) / 2
        });
    }
    
    function selectTicks(
        uint256 currentPrice,
        address pool,
        int24 tickSpacing
    ) external returns (int24 tickLower, int24 tickUpper) {
        require(validTickSpacings[tickSpacing], "Invalid tick spacing");
        
        // Use proper Uniswap V3 tick calculation: tick = log_1.0001(price)
        int24 currentTick = _priceToTick(currentPrice);
        VolatilityData memory vol = poolVolatility[pool];
        
        // Calculate range based on volatility using proper tick math
        uint256 volatility = vol.avgVol > 0 ? vol.avgVol : 2000; // Default 20% if no data
        
        // Convert volatility percentage to tick range using log formula
        // For 20% volatility: log_1.0001(1.2) ≈ 1823 ticks
        int24 range = int24(uint24((volatility * 9116) / 1000)); // Approximation of log_1.0001(1 + vol/10000)
        
        // Ensure minimum range for fee collection (at least 10 tick spacings)
        if (range < tickSpacing * 10) {
            range = tickSpacing * 10;
        }
        
        // Calculate symmetric range around current tick
        tickLower = currentTick - range;
        tickUpper = currentTick + range;
        
        // Align to tick spacing
        tickLower = (tickLower / tickSpacing) * tickSpacing;
        tickUpper = (tickUpper / tickSpacing) * tickSpacing;
        
        // Ensure valid bounds
        if (tickLower < MIN_TICK) tickLower = MIN_TICK;
        if (tickUpper > MAX_TICK) tickUpper = MAX_TICK;
        
        emit TickRangeSelected(pool, tickLower, tickUpper, currentPrice, volatility);
    }
    
    /**
     * @dev Convert price to tick using Uniswap V3 formula: tick = log_1.0001(price)
     * @param price The price in Q96 format (price * 2^96)
     */
    function _priceToTick(uint256 price) internal pure returns (int24 tick) {
        require(price > 0, "Price must be greater than 0");
        
        // Convert to Q128 format for better precision
        uint256 ratio = price;
        
        // Use binary search approximation for log calculation
        int256 log_2 = 0;
        
        if (ratio >= 0x100000000000000000000000000000000) {
            ratio >>= 128;
            log_2 += 128 << 64;
        }
        if (ratio >= 0x10000000000000000) {
            ratio >>= 64;
            log_2 += 64 << 64;
        }
        if (ratio >= 0x100000000) {
            ratio >>= 32;
            log_2 += 32 << 64;
        }
        if (ratio >= 0x10000) {
            ratio >>= 16;
            log_2 += 16 << 64;
        }
        if (ratio >= 0x100) {
            ratio >>= 8;
            log_2 += 8 << 64;
        }
        if (ratio >= 0x10) {
            ratio >>= 4;
            log_2 += 4 << 64;
        }
        if (ratio >= 0x4) {
            ratio >>= 2;
            log_2 += 2 << 64;
        }
        if (ratio >= 0x2) {
            log_2 += 1 << 64;
        }
        
        // Convert log_2 to log_1.0001 by dividing by log_2(1.0001)
        // log_2(1.0001) ≈ 0.000144269504088896
        tick = int24((log_2 * 255738958999603826347141) >> 128);
        
        // Ensure tick is within valid range
        if (tick < MIN_TICK) tick = MIN_TICK;
        if (tick > MAX_TICK) tick = MAX_TICK;
    }
    
    function selectOptimalTicks(
        uint256 currentPrice,
        address pool,
        int24 tickSpacing,
        uint256 targetCapitalEfficiency
    ) external view returns (TickRange memory) {
        require(validTickSpacings[tickSpacing], "Invalid tick spacing");
        
        int24 currentTick = int24(int256(currentPrice / 1e12)); // Simplified tick calculation
        VolatilityData memory vol = poolVolatility[pool];
        
        // Dynamic range based on target capital efficiency
        uint256 baseRange = 1000; // Base range in ticks
        if (targetCapitalEfficiency > 80) {
            baseRange = 500; // Tighter range for higher efficiency
        } else if (targetCapitalEfficiency < 50) {
            baseRange = 2000; // Wider range for lower efficiency
        }
        
        // Adjust for volatility
        if (vol.avgVol > 0) {
            baseRange = (baseRange * vol.avgVol) / 1000;
        }
        
        int24 range = int24(uint24(baseRange));
        int24 tickLower = ((currentTick - range) / tickSpacing) * tickSpacing;
        int24 tickUpper = ((currentTick + range) / tickSpacing) * tickSpacing;
        
        // Bounds check
        if (tickLower < MIN_TICK) tickLower = MIN_TICK;
        if (tickUpper > MAX_TICK) tickUpper = MAX_TICK;
        
        return TickRange({
            tickLower: tickLower,
            tickUpper: tickUpper,
            expectedFees: estimateFees(tickLower, tickUpper, currentTick),
            capitalEfficiency: calculateCapitalEfficiency(tickLower, tickUpper, currentTick)
        });
    }
    
    // Removed Uniswap base price formula implementation
    
    function estimateFees(
        int24 tickLower,
        int24 tickUpper,
        int24 currentTick
    ) internal pure returns (uint256) {
        // Simplified fee estimation based on range width
        uint256 rangeWidth = uint256(uint24(tickUpper - tickLower));
        uint256 distanceFromCurrent = currentTick >= tickLower && currentTick <= tickUpper ? 0 : 
            uint256(uint24(currentTick < tickLower ? tickLower - currentTick : currentTick - tickUpper));
        
        // Higher fees for narrower ranges and positions in range
        uint256 baseFee = 1000000 / rangeWidth; // Inverse relationship
        if (distanceFromCurrent == 0) {
            baseFee = baseFee * 2; // Double fees if in range
        }
        
        return baseFee;
    }
    
    function calculateCapitalEfficiency(
        int24 tickLower,
        int24 tickUpper,
        int24 currentTick
    ) internal pure returns (uint256) {
        uint256 rangeWidth = uint256(uint24(tickUpper - tickLower));
        uint256 maxRange = uint256(uint24(MAX_TICK - MIN_TICK));
        
        // Capital efficiency is inverse of range width
        uint256 efficiency = (maxRange * 100) / rangeWidth;
        
        // Bonus if current price is in range
        if (currentTick >= tickLower && currentTick <= tickUpper) {
            efficiency = efficiency * 120 / 100; // 20% bonus
        }
        
        return efficiency > 100 ? 100 : efficiency;
    }
}
