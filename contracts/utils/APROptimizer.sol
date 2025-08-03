// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
// import "./APRCalculator.sol"; // APRCalculator functionality integrated into core contracts

/**
 * @title APROptimizer
 * @dev Automatically optimizes APR by finding best strategies
 */
contract APROptimizer is AccessControl, ReentrancyGuard {
    using Math for uint256;
    
    bytes32 public constant OPTIMIZER_ROLE = keccak256("OPTIMIZER_ROLE");
    bytes32 public constant STRATEGY_ROLE = keccak256("STRATEGY_ROLE");
    
    struct OptimizationParams {
        address token0;
        address token1;
        uint256 amount0;
        uint256 amount1;
        uint256 minAPR;
        uint256 maxSlippage;
        uint32 timeHorizon; // in seconds
        bool allowRebalancing;
    }
    
    struct StrategyOption {
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint256 expectedAPR;
        uint256 riskScore;
        uint256 liquidityRequirement;
        bool isActive;
    }
    
    struct OptimizationResult {
        StrategyOption bestStrategy;
        uint256 projectedReturns;
        uint256 confidenceScore;
        uint256 timestamp;
    }
    
    // APRCalculator public immutable aprCalculator; // Functionality integrated into core contracts
    
    mapping(bytes32 => StrategyOption[]) public strategyOptions; // pool hash -> strategies
    mapping(bytes32 => OptimizationResult) public optimizationResults;
    mapping(address => mapping(address => uint256)) public poolWeights;
    
    uint256 public constant PRECISION = 1e18;
    uint256 public constant MAX_STRATEGIES_PER_POOL = 10;
    uint256 public optimizationInterval = 1 hours;
    uint256 public minConfidenceScore = 70 * PRECISION / 100; // 70%
    
    event StrategyOptimized(
        bytes32 indexed poolHash,
        uint24 fee,
        int24 tickLower,
        int24 tickUpper,
        uint256 expectedAPR,
        uint256 confidenceScore
    );
    
    event StrategyAdded(
        bytes32 indexed poolHash,
        uint24 fee,
        int24 tickLower,
        int24 tickUpper,
        uint256 expectedAPR
    );
    
    event OptimizationParametersUpdated(
        uint256 interval,
        uint256 minConfidence
    );
    
    constructor(address /* _aprCalculator */) {
        // require(_aprCalculator != address(0), "Invalid APR calculator"); // Functionality integrated
        // aprCalculator = APRCalculator(_aprCalculator); // Functionality integrated
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(OPTIMIZER_ROLE, msg.sender);
        _grantRole(STRATEGY_ROLE, msg.sender);
    }
    
    function optimizeStrategy(OptimizationParams calldata params)
        external
        onlyRole(OPTIMIZER_ROLE)
        nonReentrant
        returns (OptimizationResult memory result)
    {
        require(params.token0 != address(0) && params.token1 != address(0), "Invalid tokens");
        require(params.amount0 > 0 || params.amount1 > 0, "Invalid amounts");
        
        bytes32 poolHash = _getPoolHash(params.token0, params.token1);
        StrategyOption[] storage strategies = strategyOptions[poolHash];
        
        require(strategies.length > 0, "No strategies available");
        
        StrategyOption memory bestStrategy;
        uint256 bestScore = 0;
        
        // Evaluate all strategies
        for (uint256 i = 0; i < strategies.length; i++) {
            if (!strategies[i].isActive) continue;
            
            uint256 score = _evaluateStrategy(strategies[i], params);
            
            if (score > bestScore && score >= minConfidenceScore) {
                bestScore = score;
                bestStrategy = strategies[i];
            }
        }
        
        require(bestScore > 0, "No suitable strategy found");
        
        // Calculate projected returns
        uint256 projectedReturns = _calculateProjectedReturns(
            bestStrategy,
            params.amount0 + params.amount1,
            params.timeHorizon
        );
        
        result = OptimizationResult({
            bestStrategy: bestStrategy,
            projectedReturns: projectedReturns,
            confidenceScore: bestScore,
            timestamp: block.timestamp
        });
        
        optimizationResults[poolHash] = result;
        
        emit StrategyOptimized(
            poolHash,
            bestStrategy.fee,
            bestStrategy.tickLower,
            bestStrategy.tickUpper,
            bestStrategy.expectedAPR,
            bestScore
        );
    }
    
    function addStrategy(
        address token0,
        address token1,
        uint24 fee,
        int24 tickLower,
        int24 tickUpper,
        uint256 riskScore
    ) external onlyRole(STRATEGY_ROLE) {
        require(token0 != address(0) && token1 != address(0), "Invalid tokens");
        require(tickLower < tickUpper, "Invalid tick range");
        require(riskScore <= 100 * PRECISION / 100, "Invalid risk score");
        
        bytes32 poolHash = _getPoolHash(token0, token1);
        StrategyOption[] storage strategies = strategyOptions[poolHash];
        
        require(strategies.length < MAX_STRATEGIES_PER_POOL, "Too many strategies");
        
        // Calculate expected APR using real-time data
        uint256 expectedAPR = _calculateRealTimeAPR(
            token0,
            token1,
            fee,
            1e18, // 1 unit of liquidity for calculation
            tickLower,
            tickUpper
        );
        
        strategies.push(StrategyOption({
            fee: fee,
            tickLower: tickLower,
            tickUpper: tickUpper,
            expectedAPR: expectedAPR,
            riskScore: riskScore,
            liquidityRequirement: _calculateLiquidityRequirement(tickLower, tickUpper),
            isActive: true
        }));
        
        emit StrategyAdded(poolHash, fee, tickLower, tickUpper, expectedAPR);
    }
    
    function updateStrategy(
        address token0,
        address token1,
        uint256 strategyIndex,
        uint256 newRiskScore,
        bool isActive
    ) external onlyRole(STRATEGY_ROLE) {
        bytes32 poolHash = _getPoolHash(token0, token1);
        StrategyOption[] storage strategies = strategyOptions[poolHash];
        
        require(strategyIndex < strategies.length, "Invalid strategy index");
        require(newRiskScore <= 100 * PRECISION / 100, "Invalid risk score");
        
        StrategyOption storage strategy = strategies[strategyIndex];
        strategy.riskScore = newRiskScore;
        strategy.isActive = isActive;
        
        // Recalculate APR if strategy is reactivated
        if (isActive) {
            strategy.expectedAPR = _calculateRealTimeAPR(
                token0,
                token1,
                strategy.fee,
                1e18,
                strategy.tickLower,
                strategy.tickUpper
            );
        }
    }
    
    /**
     * @dev Calculate real-time APR based on current market conditions
     */
    function _calculateRealTimeAPR(
        address token0,
        address token1,
        uint24 fee,
        uint256 /* _liquidity */,
        int24 tickLower,
        int24 tickUpper
    ) internal pure returns (uint256) {
        // Get current pool data
        uint256 volume24h = _getPoolVolume24h(token0, token1, fee);
        uint256 tvl = _getPoolTVL(token0, token1, fee);
        uint256 utilization = _getPoolUtilization(token0, token1, fee);
        
        // Calculate base fee APR: (volume * fee_rate * 365) / tvl
        uint256 baseFeeAPR = 0;
        if (tvl > 0) {
            baseFeeAPR = (volume24h * fee * 365 * PRECISION) / (tvl * 1000000); // fee is in hundredths of bps
        }
        
        // Calculate position efficiency based on tick range
        uint256 rangeEfficiency = _calculateRangeEfficiency(tickLower, tickUpper);
        
        // Apply range efficiency multiplier
        uint256 adjustedAPR = (baseFeeAPR * rangeEfficiency) / PRECISION;
        
        // Apply utilization bonus (higher utilization = higher fees)
        uint256 utilizationBonus = (adjustedAPR * utilization) / (100 * PRECISION);
        
        // Add yield farming rewards if applicable
        uint256 farmingRewards = _calculateFarmingRewards(token0, token1, fee);
        
        return adjustedAPR + utilizationBonus + farmingRewards;
    }
    
    /**
     * @dev Get 24h trading volume for a pool
     */
    function _getPoolVolume24h(address token0, address token1, uint24 fee) internal pure returns (uint256) {
        // In production, this would query Uniswap V3 subgraph or oracle
        // For now, return mock data based on pool characteristics
        uint256 baseVolume = 1000000e18; // $1M base volume
        
        // Adjust based on fee tier (lower fees = higher volume typically)
        if (fee == 500) baseVolume = baseVolume * 3; // 0.05% pools have higher volume
        else if (fee == 3000) baseVolume = baseVolume * 2; // 0.3% pools
        else if (fee == 10000) baseVolume = baseVolume / 2; // 1% pools have lower volume
        
        return baseVolume;
    }
    
    /**
     * @dev Get total value locked in a pool
     */
    function _getPoolTVL(address /* _token0 */, address /* _token1 */, uint24 /* _fee */) internal pure returns (uint256) {
        // In production, this would query actual pool reserves
        // For now, return mock data
        return 10000000e18; // $10M TVL
    }
    
    /**
     * @dev Get pool utilization rate
     */
    function _getPoolUtilization(address /* _token0 */, address /* _token1 */, uint24 /* _fee */) internal pure returns (uint256) {
        // Calculate utilization as borrowed / (supplied + borrowed)
        // For now, return mock data between 50-90%
        return 75 * PRECISION / 100; // 75% utilization
    }
    
    /**
     * @dev Calculate range efficiency based on tick width
     */
    function _calculateRangeEfficiency(int24 tickLower, int24 tickUpper) internal pure returns (uint256) {
        uint256 tickRange = uint256(uint24(tickUpper - tickLower));
        uint256 maxRange = uint256(uint24(887272 - (-887272))); // Full range
        
        // Narrower ranges are more efficient but riskier
        // Efficiency = (maxRange / tickRange) but capped at 10x
        uint256 efficiency = (maxRange * PRECISION) / tickRange;
        
        // Cap efficiency at 10x to prevent extreme values
        if (efficiency > 10 * PRECISION) {
            efficiency = 10 * PRECISION;
        }
        
        // Minimum efficiency of 0.1x for very wide ranges
        if (efficiency < PRECISION / 10) {
            efficiency = PRECISION / 10;
        }
        
        return efficiency;
    }
    
    /**
     * @dev Calculate additional farming rewards
     */
    function _calculateFarmingRewards(address /* _token0 */, address /* _token1 */, uint24 /* _fee */) internal pure returns (uint256) {
        // In production, this would check for active liquidity mining programs
        // For now, return base farming rewards
        return 2 * PRECISION / 100; // 2% additional APR from farming
    }
    
    /**
     * @dev Calculate liquidity requirement for a position
     */
    function _calculateLiquidityRequirement(int24 tickLower, int24 tickUpper) internal pure returns (uint256) {
        uint256 tickRange = uint256(uint24(tickUpper - tickLower));
        
        // Wider ranges require more liquidity to be effective
        // Base requirement of 1000 USD, scaled by range
        uint256 baseRequirement = 1000e18;
        uint256 rangeMultiplier = tickRange / 1000; // Every 1000 ticks adds 1x
        
        return baseRequirement * (1 + rangeMultiplier);
    }
    
    /**
     * @dev Evaluate strategy based on parameters and market conditions
     */
    function _evaluateStrategy(
        StrategyOption memory strategy,
        OptimizationParams memory params
    ) internal pure returns (uint256 score) {
        // Base score from expected APR (0-100)
        score = (strategy.expectedAPR * 100) / (50 * PRECISION / 100); // Normalize to 50% APR = 100 points
        if (score > 100) score = 100;
        
        // Penalize if APR is below minimum
        if (strategy.expectedAPR < params.minAPR) {
            score = score / 2; // 50% penalty
        }
        
        // Risk adjustment (lower risk = higher score)
        uint256 riskPenalty = (strategy.riskScore * 30) / (100 * PRECISION / 100); // Max 30 point penalty
        if (score > riskPenalty) {
            score -= riskPenalty;
        } else {
            score = 0;
        }
        
        // Liquidity requirement check
        uint256 totalValue = params.amount0 + params.amount1; // Simplified USD value
        if (totalValue < strategy.liquidityRequirement) {
            score = score / 3; // Major penalty for insufficient liquidity
        }
        
        // Time horizon bonus (longer = better for concentrated liquidity)
        if (params.timeHorizon > 7 days) {
            score = (score * 110) / 100; // 10% bonus
        }
        
        // Convert to precision format
        return score * PRECISION / 100;
    }
    
    /**
     * @dev Calculate projected returns for a strategy
     */
    function _calculateProjectedReturns(
        StrategyOption memory strategy,
        uint256 principal,
        uint32 timeHorizon
    ) internal pure returns (uint256) {
        // Simple compound interest calculation
        // Returns = Principal * (1 + APR/365)^days - Principal
        uint256 dailyRate = strategy.expectedAPR / 365;
        uint256 daysCount = timeHorizon / 86400; // 1 day = 86400 seconds
        
        // Simplified compound calculation (avoiding complex exponentiation)
        uint256 totalReturn = (principal * dailyRate * daysCount) / PRECISION;
        
        // Add compounding effect (approximation)
        uint256 compoundingBonus = (totalReturn * totalReturn) / (principal * 2);
        
        return totalReturn + compoundingBonus;
    }
    
    /**
     * @dev Generate pool hash for mapping
     */
    function _getPoolHash(address token0, address token1) internal pure returns (bytes32) {
        // Ensure consistent ordering
        if (token0 > token1) {
            (token0, token1) = (token1, token0);
        }
        return keccak256(abi.encodePacked(token0, token1));
    }
    
    /**
     * @dev Update optimization parameters
     */
    function updateOptimizationParameters(
        uint256 _optimizationInterval,
        uint256 _minConfidenceScore
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_optimizationInterval >= 10 minutes, "Interval too short");
        require(_minConfidenceScore <= PRECISION, "Invalid confidence score");
        
        optimizationInterval = _optimizationInterval;
        minConfidenceScore = _minConfidenceScore;
        
        emit OptimizationParametersUpdated(_optimizationInterval, _minConfidenceScore);
    }
    
    /**
     * @dev Get strategy options for a pool
     */
    function getStrategyOptions(address token0, address token1) 
        external 
        view 
        returns (StrategyOption[] memory) 
    {
        bytes32 poolHash = _getPoolHash(token0, token1);
        return strategyOptions[poolHash];
    }
    
    /**
     * @dev Get latest optimization result
     */
    function getOptimizationResult(address token0, address token1) 
        external 
        view 
        returns (OptimizationResult memory) 
    {
        bytes32 poolHash = _getPoolHash(token0, token1);
        return optimizationResults[poolHash];
    }
    
    function getOptimalStrategy(
        address token0,
        address token1,
        uint256 amount0,
        uint256 amount1,
        uint256 riskTolerance
    ) external view returns (StrategyOption memory optimalStrategy, uint256 confidenceScore) {
        bytes32 poolHash = _getPoolHash(token0, token1);
        StrategyOption[] storage strategies = strategyOptions[poolHash];
        
        uint256 bestScore = 0;
        
        for (uint256 i = 0; i < strategies.length; i++) {
            if (!strategies[i].isActive) continue;
            if (strategies[i].riskScore > riskTolerance) continue;
            
            OptimizationParams memory params = OptimizationParams({
                token0: token0,
                token1: token1,
                amount0: amount0,
                amount1: amount1,
                minAPR: 0,
                maxSlippage: 500, // 5%
                timeHorizon: 30 days,
                allowRebalancing: true
            });
            
            uint256 score = _evaluateStrategy(strategies[i], params);
            
            if (score > bestScore) {
                bestScore = score;
                optimalStrategy = strategies[i];
            }
        }
        
        confidenceScore = bestScore;
    }
    
    function getStrategies(address token0, address token1)
        external
        view
        returns (StrategyOption[] memory)
    {
        bytes32 poolHash = _getPoolHash(token0, token1);
        return strategyOptions[poolHash];
    }
    
    function _calculateLiquidityEfficiency(StrategyOption memory strategy, uint256 totalAmount)
        internal
        pure
        returns (uint256)
    {
        if (strategy.liquidityRequirement == 0) return PRECISION;
        
        uint256 efficiency = (totalAmount * PRECISION) / strategy.liquidityRequirement;
        return efficiency > PRECISION ? PRECISION : efficiency;
    }
    
    function _calculateTimeScore(StrategyOption memory strategy, uint32 timeHorizon)
        internal
        pure
        returns (uint256)
    {
        // Longer time horizons favor higher APR strategies
        if (timeHorizon >= 365 days) {
            return PRECISION;
        } else if (timeHorizon >= 30 days) {
            return 80 * PRECISION / 100;
        } else if (timeHorizon >= 7 days) {
            return 60 * PRECISION / 100;
        } else {
            return 40 * PRECISION / 100;
        }
    }
    
    function setOptimizationParameters(
        uint256 _interval,
        uint256 _minConfidence
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_interval >= 10 minutes, "Interval too short");
        require(_minConfidence <= PRECISION, "Invalid confidence score");
        
        optimizationInterval = _interval;
        minConfidenceScore = _minConfidence;
        
        emit OptimizationParametersUpdated(_interval, _minConfidence);
    }
    
    function setPoolWeight(
        address token0,
        address token1,
        uint256 weight
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(weight <= PRECISION, "Invalid weight");
        poolWeights[token0][token1] = weight;
    }
    
    function removeStrategy(
        address token0,
        address token1,
        uint256 strategyIndex
    ) external onlyRole(STRATEGY_ROLE) {
        bytes32 poolHash = _getPoolHash(token0, token1);
        StrategyOption[] storage strategies = strategyOptions[poolHash];
        
        require(strategyIndex < strategies.length, "Invalid strategy index");
        
        // Move last element to deleted spot and remove last element
        strategies[strategyIndex] = strategies[strategies.length - 1];
        strategies.pop();
    }
    
    /**
     * @dev Integrated APR calculation to replace APRCalculator functionality
     */
    function _calculateIntegratedAPR(
        address token0,
        address token1,
        uint24 fee,
        uint256 liquidity,
        int24 tickLower,
        int24 tickUpper
    ) internal pure returns (uint256) {
        // Simple APR calculation based on fee tier and range
        uint256 baseAPR;
        
        // Base APR based on fee tier
        if (fee == 500) {
            baseAPR = 5 * PRECISION / 100; // 5% for 0.05% fee
        } else if (fee == 3000) {
            baseAPR = 12 * PRECISION / 100; // 12% for 0.3% fee
        } else if (fee == 10000) {
            baseAPR = 25 * PRECISION / 100; // 25% for 1% fee
        } else {
            baseAPR = 8 * PRECISION / 100; // Default 8%
        }
        
        // Adjust based on range width (narrower range = higher APR potential)
        uint256 range = uint256(uint24(tickUpper - tickLower));
        uint256 rangeMultiplier = range < 1000 ? 150 : (range < 5000 ? 120 : 100);
        
        return (baseAPR * rangeMultiplier) / 100;
    }
}
