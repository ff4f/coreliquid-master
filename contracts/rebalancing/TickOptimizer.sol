// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";

/**
 * @title TickOptimizer
 * @dev Optimizes tick ranges for Uniswap v3 positions
 */
contract TickOptimizer is AccessControl {
    using Math for uint256;
    using SafeCast for uint256;
    using SafeCast for int256;
    
    bytes32 public constant OPTIMIZER_ROLE = keccak256("OPTIMIZER_ROLE");
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");
    
    struct TickRange {
        int24 tickLower;
        int24 tickUpper;
        uint256 expectedFees;
        uint256 capitalEfficiency;
        uint256 impermanentLossRisk;
        uint256 score;
    }
    
    struct PoolData {
        address token0;
        address token1;
        uint24 fee;
        int24 currentTick;
        uint128 liquidity;
        uint256 sqrtPriceX96;
        uint256 volume24h;
        uint256 volatility;
        uint256 lastUpdated;
    }
    
    struct OptimizationParams {
        address token0;
        address token1;
        uint24 fee;
        uint256 amount0;
        uint256 amount1;
        uint256 riskTolerance; // 0-100
        uint256 timeHorizon; // in seconds
        bool preferCapitalEfficiency;
    }
    
    mapping(bytes32 => PoolData) public poolData; // pool hash -> data
    mapping(bytes32 => TickRange[]) public optimizedRanges; // pool hash -> ranges
    mapping(int24 => uint256) public tickSpacings;
    
    uint256 public constant PRECISION = 1e18;
    int24 public constant MAX_TICK = 887272;
    int24 public constant MIN_TICK = -887272;
    uint256 public constant Q96 = 2**96;
    
    // Volatility-based range multipliers
    mapping(uint256 => uint256) public volatilityMultipliers;
    
    event TickRangeOptimized(
        bytes32 indexed poolHash,
        int24 tickLower,
        int24 tickUpper,
        uint256 score,
        uint256 expectedFees
    );
    
    event PoolDataUpdated(
        bytes32 indexed poolHash,
        int24 currentTick,
        uint256 volatility,
        uint256 volume24h
    );
    
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(OPTIMIZER_ROLE, msg.sender);
        _grantRole(ORACLE_ROLE, msg.sender);
        
        // Initialize tick spacings for different fee tiers
        tickSpacings[500] = 10;   // 0.05%
        tickSpacings[3000] = 60;  // 0.3%
        tickSpacings[10000] = 200; // 1%
        
        // Initialize volatility multipliers
        volatilityMultipliers[0] = 50;   // Low volatility: 0.5x
        volatilityMultipliers[1] = 100;  // Medium volatility: 1x
        volatilityMultipliers[2] = 200;  // High volatility: 2x
        volatilityMultipliers[3] = 400;  // Very high volatility: 4x
    }
    
    function optimizeTickRange(OptimizationParams calldata params)
        external
        view
        returns (TickRange memory bestRange)
    {
        require(params.token0 != address(0) && params.token1 != address(0), "Invalid tokens");
        require(params.riskTolerance <= 100, "Invalid risk tolerance");
        
        bytes32 poolHash = _getPoolHash(params.token0, params.token1, params.fee);
        PoolData memory pool = poolData[poolHash];
        
        require(pool.lastUpdated > 0, "Pool data not available");
        require(block.timestamp - pool.lastUpdated < 1 hours, "Pool data stale");
        
        // Generate candidate ranges
        TickRange[] memory candidates = _generateCandidateRanges(pool, params);
        
        // Evaluate and score each range
        uint256 bestScore = 0;
        for (uint256 i = 0; i < candidates.length; i++) {
            uint256 score = _scoreTickRange(candidates[i], pool, params);
            candidates[i].score = score;
            
            if (score > bestScore) {
                bestScore = score;
                bestRange = candidates[i];
            }
        }
        
        require(bestScore > 0, "No suitable range found");
    }
    
    function updatePoolData(
        address token0,
        address token1,
        uint24 fee,
        int24 currentTick,
        uint128 liquidity,
        uint256 sqrtPriceX96,
        uint256 volume24h,
        uint256 volatility
    ) external onlyRole(ORACLE_ROLE) {
        bytes32 poolHash = _getPoolHash(token0, token1, fee);
        
        poolData[poolHash] = PoolData({
            token0: token0,
            token1: token1,
            fee: fee,
            currentTick: currentTick,
            liquidity: liquidity,
            sqrtPriceX96: sqrtPriceX96,
            volume24h: volume24h,
            volatility: volatility,
            lastUpdated: block.timestamp
        });
        
        emit PoolDataUpdated(poolHash, currentTick, volatility, volume24h);
    }
    
    function getOptimalRanges(address token0, address token1, uint24 fee)
        external
        view
        returns (TickRange[] memory)
    {
        bytes32 poolHash = _getPoolHash(token0, token1, fee);
        return optimizedRanges[poolHash];
    }
    
    function calculateCapitalEfficiency(
        int24 tickLower,
        int24 tickUpper,
        int24 currentTick
    ) external pure returns (uint256 efficiency) {
        if (currentTick < tickLower || currentTick > tickUpper) {
            return 0; // No capital efficiency if out of range
        }
        
        uint256 totalRange = uint256(uint24(tickUpper - tickLower));
        
        // Simple efficiency calculation
        efficiency = (PRECISION * 1000) / (totalRange + 1);
    }
    
    function calculateImpermanentLoss(
        int24 tickLower,
        int24 tickUpper,
        int24 currentTick,
        uint256 volatility
    ) external pure returns (uint256 impermanentLoss) {
        // Calculate potential impermanent loss based on range width and volatility
        uint256 rangeWidth = uint256(int256(tickUpper - tickLower).toUint256());
        
        // Wider ranges have lower IL risk
        uint256 baseIL = (volatility * PRECISION) / (rangeWidth + 1000);
        
        // Adjust based on current position relative to range
        if (currentTick < tickLower || currentTick > tickUpper) {
            baseIL = baseIL * 150 / 100; // 50% penalty for being out of range
        }
        
        impermanentLoss = baseIL;
    }
    
    function _generateCandidateRanges(PoolData memory pool, OptimizationParams memory params)
        internal
        view
        returns (TickRange[] memory candidates)
    {
        int24 tickSpacing = int24(params.fee);
        require(tickSpacing > 0, "Invalid fee tier");
        
        // Generate ranges based on volatility
        uint256 volatilityCategory = _getVolatilityCategory(pool.volatility);
        uint256 baseRange = (volatilityMultipliers[volatilityCategory] * uint256(uint24(tickSpacing))) / 100;
        
        candidates = new TickRange[](5); // Generate 5 candidate ranges
        
        for (uint256 i = 0; i < 5; i++) {
            uint256 multiplier = 50 + (i * 50); // 0.5x to 2.5x
            uint256 rangeSize = (baseRange * multiplier) / 100;
            
            int24 halfRange = int24(uint24(rangeSize / 2));
            int24 tickLower = _roundToTickSpacing(pool.currentTick - halfRange, tickSpacing);
            int24 tickUpper = _roundToTickSpacing(pool.currentTick + halfRange, tickSpacing);
            
            // Ensure valid range
            if (tickLower < MIN_TICK) tickLower = MIN_TICK;
            if (tickUpper > MAX_TICK) tickUpper = MAX_TICK;
            if (tickLower >= tickUpper) continue;
            
            candidates[i] = TickRange({
                tickLower: tickLower,
                tickUpper: tickUpper,
                expectedFees: _calculateExpectedFees(tickLower, tickUpper, pool),
                capitalEfficiency: this.calculateCapitalEfficiency(tickLower, tickUpper, pool.currentTick),
                impermanentLossRisk: this.calculateImpermanentLoss(tickLower, tickUpper, pool.currentTick, pool.volatility),
                score: 0
            });
        }
    }
    
    function _scoreTickRange(
        TickRange memory range,
        PoolData memory /* _pool */,
        OptimizationParams memory params
    ) internal pure returns (uint256 score) {
        // Fee generation weight (40%)
        uint256 feeScore = (range.expectedFees * 40) / 100;
        
        // Capital efficiency weight (30%)
        uint256 efficiencyScore = (range.capitalEfficiency * 30) / 100;
        
        // Risk adjustment weight (30%)
        uint256 riskScore = 0;
        if (range.impermanentLossRisk > 0) {
            // Lower IL risk = higher score
            riskScore = (PRECISION * 30 / 100) / (range.impermanentLossRisk + 1);
        }
        
        score = feeScore + efficiencyScore + riskScore;
        
        // Apply risk tolerance adjustment
        if (params.riskTolerance < 50) {
            // Conservative: prefer lower IL risk
            score = (score * (100 - range.impermanentLossRisk / PRECISION * 100)) / 100;
        } else if (params.riskTolerance > 80) {
            // Aggressive: prefer higher fees
            score = (score * (100 + range.expectedFees / PRECISION * 50)) / 100;
        }
        
        // Time horizon adjustment
        if (params.timeHorizon > 30 days) {
            // Long term: prefer capital efficiency
            score = (score * (100 + range.capitalEfficiency / PRECISION * 20)) / 100;
        }
    }
    
    function _calculateExpectedFees(
        int24 tickLower,
        int24 tickUpper,
        PoolData memory pool
    ) internal pure returns (uint256 expectedFees) {
        // Simple fee calculation based on range and volume
        uint256 rangeWidth = uint256(uint24(tickUpper - tickLower));
        
        // Narrower ranges capture more fees when in range
        uint256 feeMultiplier = (10000 * PRECISION) / (rangeWidth + 1000);
        
        // Base fees from volume
        uint256 baseFees = (pool.volume24h * pool.fee) / 1000000; // fee in basis points
        
        expectedFees = (baseFees * feeMultiplier) / PRECISION;
    }
    
    function _getVolatilityCategory(uint256 volatility) internal pure returns (uint256) {
        if (volatility < 20 * PRECISION / 100) return 0; // Low
        if (volatility < 50 * PRECISION / 100) return 1; // Medium
        if (volatility < 100 * PRECISION / 100) return 2; // High
        return 3; // Very high
    }
    
    function _roundToTickSpacing(int24 tick, int24 tickSpacing) internal pure returns (int24) {
        int24 remainder = tick % tickSpacing;
        if (remainder == 0) return tick;
        
        if (tick > 0) {
            return tick - remainder + (remainder >= tickSpacing / 2 ? int24(tickSpacing) : int24(0));
        } else {
            return tick - remainder - ((-remainder) >= tickSpacing / 2 ? int24(tickSpacing) : int24(0));
        }
    }
    
    function _getPoolHash(address token0, address token1, uint24 fee) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(token0, token1, fee));
    }
    
    function setTickSpacing(uint24 fee, int24 spacing) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(spacing > 0, "Invalid spacing");
        tickSpacings[int24(fee)] = uint256(int256(spacing));
    }
    
    function setVolatilityMultiplier(uint256 category, uint256 multiplier) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        require(category <= 3, "Invalid category");
        require(multiplier > 0 && multiplier <= 1000, "Invalid multiplier");
        volatilityMultipliers[category] = multiplier;
    }
    
    function storeOptimizedRanges(
        address token0,
        address token1,
        uint24 fee,
        TickRange[] calldata ranges
    ) external onlyRole(OPTIMIZER_ROLE) {
        bytes32 poolHash = _getPoolHash(token0, token1, fee);
        
        // Clear existing ranges
        delete optimizedRanges[poolHash];
        
        // Store new ranges
        for (uint256 i = 0; i < ranges.length; i++) {
            optimizedRanges[poolHash].push(ranges[i]);
            
            emit TickRangeOptimized(
                poolHash,
                ranges[i].tickLower,
                ranges[i].tickUpper,
                ranges[i].score,
                ranges[i].expectedFees
            );
        }
    }
    
    function getPoolData(address token0, address token1, uint24 fee)
        external
        view
        returns (PoolData memory)
    {
        bytes32 poolHash = _getPoolHash(token0, token1, fee);
        return poolData[poolHash];
    }
    
    function isPoolDataFresh(address token0, address token1, uint24 fee)
        external
        view
        returns (bool)
    {
        bytes32 poolHash = _getPoolHash(token0, token1, fee);
        PoolData memory pool = poolData[poolHash];
        return pool.lastUpdated > 0 && block.timestamp - pool.lastUpdated < 1 hours;
    }
}
