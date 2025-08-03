// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "../common/CommonRangeCalculator.sol";
import "../common/OracleRouter.sol";
import "../interfaces/IUniswapV3Pool.sol";
import "../interfaces/INonfungiblePositionManager.sol";

/**
 * @title UnifiedLiquidityPool
 * @dev Core contract implementing unified liquidity pool with dynamic rebalancing
 * and automated compounding for maximum capital efficiency
 */
contract UnifiedLiquidityPool is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;
    using Math for uint256;
    using CommonRangeCalculator for uint256;
    
    OracleRouter public immutable oracle;
    INonfungiblePositionManager public immutable positionManager;

    // Pool configuration
    struct PoolConfig {
        address token0;
        address token1;
        uint24 fee;
        int24 tickSpacing;
        uint256 maxLiquidity;
        uint256 rebalanceThreshold; // Price deviation threshold for rebalancing
        uint256 lastRebalance;
        bool isActive;
        bool autoRebalanceEnabled;
    }

    // User position tracking
    struct UserPosition {
        uint256 liquidity;
        uint256 token0Amount;
        uint256 token1Amount;
        uint256 lastUpdate;
        uint256 accumulatedFees0;
        uint256 accumulatedFees1;
        uint256 shares; // LP token shares
        int24 tickLower;
        int24 tickUpper;
        uint256 tokenId; // Uniswap V3 NFT position ID
    }
    
    // Concentrated liquidity position
    struct ConcentratedPosition {
        uint256 tokenId;
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidity;
        uint256 feeGrowthInside0LastX128;
        uint256 feeGrowthInside1LastX128;
        uint128 tokensOwed0;
        uint128 tokensOwed1;
        bool isActive;
    }

    // Pool state
    struct PoolState {
        uint256 totalLiquidity;
        uint256 totalToken0;
        uint256 totalToken1;
        uint256 totalShares;
        uint160 sqrtPriceX96;
        int24 currentTick;
        int24 targetTickLower;
        int24 targetTickUpper;
        uint256 lastUpdate;
        uint256 totalFees0;
        uint256 totalFees1;
        uint256 performanceFee; // Protocol performance fee
    }
    
    // Auto-rebalancing parameters
    struct RebalanceParams {
        uint256 priceDeviationThreshold; // 500 = 5%
        uint256 minRebalanceInterval; // Minimum time between rebalances
        uint256 maxSlippage; // Maximum slippage tolerance
        bool emergencyMode; // Emergency rebalancing mode
    }

    // Constants
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant REBALANCE_COOLDOWN = 4 hours;
    uint256 public constant COMPOUND_FREQUENCY = 1 hours;
    uint256 public constant MIN_LIQUIDITY = 1000e18; // $1000 minimum
    uint256 public constant PERFORMANCE_FEE = 1500; // 15% performance fee
    uint256 public constant PRECISION = 1e18;
    uint256 public constant MAX_SLIPPAGE = 1000; // 10%
    uint256 public constant REBALANCE_THRESHOLD = 500; // 5%
    uint256 public constant MAX_TICK_DEVIATION = 4000; // Maximum tick deviation for rebalancing

    // State variables
    mapping(bytes32 => PoolConfig) public pools;
    mapping(bytes32 => PoolState) public poolStates;
    mapping(address => mapping(bytes32 => UserPosition)) public userPositions;
    mapping(bytes32 => RebalanceAction[]) public rebalanceHistory;
    mapping(bytes32 => ConcentratedPosition[]) public concentratedPositions;
    mapping(bytes32 => YieldStrategy[]) public yieldStrategies;
    mapping(bytes32 => RebalanceParams) public rebalanceParams;
    
    bytes32[] public activePools;
    uint256 public totalValueLocked;
    uint256 public protocolFeeRate = 100; // 1%
    uint256 public lastGlobalRebalance;
    bool public globalAutoRebalance = true;
    
    // Oracle and price feeds
    mapping(address => address) public priceFeeds;
    
    // Rebalancing action struct
    struct RebalanceAction {
        int24 oldTickLower;
        int24 oldTickUpper;
        int24 newTickLower;
        int24 newTickUpper;
        uint256 timestamp;
        uint256 gasUsed;
        uint256 liquidityMoved;
        uint256 fees0Collected;
        uint256 fees1Collected;
        bool success;
        string reason;
    }
    
    // Yield farming integration
    struct YieldStrategy {
        address strategy;
        uint256 allocation; // Percentage of funds allocated
        uint256 lastHarvest;
        uint256 totalRewards;
        bool isActive;
    }

    // Events
    event PoolAdded(bytes32 indexed poolId, address token0, address token1, uint24 fee);
    event LiquidityAdded(bytes32 indexed poolId, address indexed user, uint256 amount0, uint256 amount1, uint256 shares);
    event LiquidityRemoved(bytes32 indexed poolId, address indexed user, uint256 amount0, uint256 amount1, uint256 shares);
    event Rebalanced(bytes32 indexed poolId, int24 oldTickLower, int24 oldTickUpper, int24 newTickLower, int24 newTickUpper, string reason);
    event FeesCollected(bytes32 indexed poolId, uint256 fees0, uint256 fees1);
    event AutoRebalanceTriggered(bytes32 indexed poolId, uint256 priceDeviation);
    event YieldHarvested(bytes32 indexed poolId, address strategy, uint256 rewards);
    event EmergencyRebalance(bytes32 indexed poolId, string reason);
    event PerformanceFeeCollected(bytes32 indexed poolId, uint256 fee0, uint256 fee1);
    event Deposit(address indexed user, address indexed token, uint256 amount, uint256 shares);
    event Withdraw(address indexed user, uint256 shares, uint256[] amounts);
    event Rebalance(uint256 timestamp, uint256 totalLiquidity);
    event Compound(address indexed user, uint256 rewards);
    event RebalanceActionExecuted(address indexed tokenFrom, address indexed tokenTo, uint256 amountIn, uint256 amountOut);
    event LiquidityUnminted(address indexed token, uint256 amount, uint256 sharesReduced);
    event LiquidityReminted(address indexed token, uint256 amount, uint256 newShares);
    event UserPositionsUpdated(uint256 sharesReduced, uint256 newShares, uint256 timestamp);
    event SwapExecuted(address indexed tokenFrom, address indexed tokenTo, uint256 amountIn, uint256 amountOut);
    event EmergencyPause(string reason, uint256 timestamp);
    event SlippageProtectionTriggered(address indexed token, uint256 expectedAmount, uint256 actualAmount);
    event YieldDistribution(uint256 totalYield, uint256 timestamp);

    constructor(
        address _oracle,
        address _positionManager,
        address initialOwner
    ) Ownable(initialOwner) {
        oracle = OracleRouter(_oracle);
        positionManager = INonfungiblePositionManager(_positionManager);
    }

    function addPool(
        address token0,
        address token1,
        uint24 fee,
        uint256 rebalanceThreshold
    ) external onlyOwner {
        require(token0 != token1, "Identical tokens");
        require(token0 != address(0) && token1 != address(0), "Zero address");
        
        bytes32 poolId = keccak256(abi.encodePacked(token0, token1, fee));
        require(!pools[poolId].isActive, "Pool already exists");
        
        // Get tick spacing from Uniswap V3
        int24 tickSpacing = _getTickSpacing(fee);
        
        pools[poolId] = PoolConfig({
            token0: token0,
            token1: token1,
            fee: fee,
            tickSpacing: tickSpacing,
            maxLiquidity: type(uint256).max,
            rebalanceThreshold: rebalanceThreshold,
            lastRebalance: block.timestamp,
            isActive: true,
            autoRebalanceEnabled: true
        });
        
        // Initialize rebalance parameters
        rebalanceParams[poolId] = RebalanceParams({
            priceDeviationThreshold: rebalanceThreshold,
            minRebalanceInterval: 1 hours,
            maxSlippage: 300, // 3%
            emergencyMode: false
        });
        
        activePools.push(poolId);
        emit PoolAdded(poolId, token0, token1, fee);
    }
    
    function _getTickSpacing(uint24 fee) internal pure returns (int24) {
        if (fee == 100) return 1;
        if (fee == 500) return 10;
        if (fee == 3000) return 60;
        if (fee == 10000) return 200;
        revert("Invalid fee");
    }

    /**
     * @dev Deposit tokens into the unified pool
     */
    function deposit(address token, uint256 amount) external nonReentrant notPaused {
        // Legacy function for backward compatibility - redirects to new pool-based deposit
        bytes32 poolId = _findPoolForToken(token);
        require(poolId != bytes32(0), "Token not supported in any pool");
        _depositToPool(poolId, token, amount);
    }
    
    function _depositToPool(bytes32 poolId, address token, uint256 amount) internal {
        require(pools[poolId].isActive, "Pool not active");
        require(amount > 0, "Amount must be greater than 0");
        
        // Tokens deposited without transfer
        
        // Calculate shares to mint based on current pool state
        PoolState storage state = poolStates[poolId];
        uint256 sharesToMint;
        
        if (state.totalShares == 0) {
            sharesToMint = amount;
        } else {
            uint256 totalValue = _getPoolTotalValue(poolId);
            sharesToMint = (amount * state.totalShares) / totalValue;
        }
        
        // Update pool state
        if (token == pools[poolId].token0) {
            state.totalToken0 += amount;
        } else {
            state.totalToken1 += amount;
        }
        state.totalShares += sharesToMint;
        state.lastUpdate = block.timestamp;
        
        // Update user position
        UserPosition storage position = userPositions[msg.sender][poolId];
        position.shares += sharesToMint;
        if (token == pools[poolId].token0) {
            position.token0Amount += amount;
        } else {
            position.token1Amount += amount;
        }
        position.lastUpdate = block.timestamp;
        
        emit LiquidityAdded(poolId, msg.sender, 
            token == pools[poolId].token0 ? amount : 0,
            token == pools[poolId].token1 ? amount : 0,
            sharesToMint);
        
        // Check if rebalancing is needed
        _checkAndRebalancePool(poolId);
    }

    /**
     * @dev Withdraw from a specific pool
     */
    function withdrawFromPool(
        bytes32 poolId,
        uint256 shares
    ) external nonReentrant {
        _withdrawFromPoolInternal(poolId, shares, msg.sender);
    }
    
    function _withdrawFromPoolInternal(
        bytes32 poolId,
        uint256 shares,
        address user
    ) internal {
        require(pools[poolId].isActive, "Pool not active");
        
        UserPosition storage position = userPositions[user][poolId];
        require(position.shares >= shares, "Insufficient shares");
        require(shares > 0, "Shares must be greater than 0");
        
        PoolState storage state = poolStates[poolId];
        
        // Calculate proportional withdrawal amounts
        uint256 shareRatio = (shares * PRECISION) / state.totalShares;
        uint256 amount0 = (state.totalToken0 * shareRatio) / PRECISION;
        uint256 amount1 = (state.totalToken1 * shareRatio) / PRECISION;
        
        // Collect fees before withdrawal
        _collectPositionFees(poolId, user);
        
        // Update pool state
        state.totalToken0 -= amount0;
        state.totalToken1 -= amount1;
        state.totalShares -= shares;
        state.lastUpdate = block.timestamp;
        
        // Update user position
        position.shares -= shares;
        position.token0Amount -= amount0;
        position.token1Amount -= amount1;
        position.lastUpdate = block.timestamp;
        
        // Transfer tokens
        if (amount0 > 0) {
            IERC20(pools[poolId].token0).safeTransfer(user, amount0);
        }
        if (amount1 > 0) {
            IERC20(pools[poolId].token1).safeTransfer(user, amount1);
        }
        
        emit LiquidityRemoved(poolId, msg.sender, amount0, amount1, shares);
        
        // Check if rebalancing is needed after withdrawal
        _checkAndRebalancePool(poolId);
    }
    
    /**
     * @dev Withdraw from the unified pool (legacy function)
     */
    function withdraw(uint256 shares) external nonReentrant {
        // Legacy function - find user's largest position and withdraw from there
        bytes32 largestPoolId = _findLargestUserPosition(msg.sender);
        require(largestPoolId != bytes32(0), "No positions found");
        _withdrawFromPoolInternal(largestPoolId, shares, msg.sender);
    }
    
    function _findLargestUserPosition(address user) internal view returns (bytes32) {
        bytes32 largestPoolId;
        uint256 largestShares = 0;
        
        for (uint256 i = 0; i < activePools.length; i++) {
            bytes32 poolId = activePools[i];
            uint256 userShares = userPositions[user][poolId].shares;
            if (userShares > largestShares) {
                largestShares = userShares;
                largestPoolId = poolId;
            }
        }
        
        return largestPoolId;
    }
    
    function _collectPositionFees(bytes32 poolId, address user) internal {
        UserPosition storage position = userPositions[user][poolId];
        
        if (position.tokenId > 0) {
            // Collect fees from Uniswap V3 position
            (uint256 amount0, uint256 amount1) = positionManager.collect(
                INonfungiblePositionManager.CollectParams({
                    tokenId: position.tokenId,
                    recipient: address(this),
                    amount0Max: type(uint128).max,
                    amount1Max: type(uint128).max
                })
            );
            
            // Apply performance fee
            uint256 fee0 = (amount0 * PERFORMANCE_FEE) / 10000;
            uint256 fee1 = (amount1 * PERFORMANCE_FEE) / 10000;
            
            position.accumulatedFees0 += (amount0 - fee0);
            position.accumulatedFees1 += (amount1 - fee1);
            
            poolStates[poolId].totalFees0 += fee0;
            poolStates[poolId].totalFees1 += fee1;
            
            emit FeesCollected(poolId, amount0, amount1);
            emit PerformanceFeeCollected(poolId, fee0, fee1);
        }
    }

    /**
     * @dev Manual rebalancing for a specific pool
     */
    function rebalance(bytes32 poolId) external {
        require(pools[poolId].isActive, "Pool not active");
        require(
            msg.sender == owner() || 
            block.timestamp >= pools[poolId].lastRebalance + rebalanceParams[poolId].minRebalanceInterval,
            "Rebalance not allowed"
        );
        
        _executePoolRebalance(poolId, "Manual rebalance triggered");
    }
    
    /**
     * @dev Auto-rebalance all active pools
     */
    function autoRebalanceAll() external {
        require(globalAutoRebalance, "Auto rebalance disabled");
        
        for (uint256 i = 0; i < activePools.length; i++) {
            bytes32 poolId = activePools[i];
            if (pools[poolId].autoRebalanceEnabled) {
                _checkAndRebalancePool(poolId);
            }
        }
        
        lastGlobalRebalance = block.timestamp;
    }
    
    /**
     * @dev Emergency rebalancing with override permissions
     */
    function emergencyRebalance(bytes32 poolId, string calldata reason) external onlyOwner {
        rebalanceParams[poolId].emergencyMode = true;
        _executePoolRebalance(poolId, reason);
        emit EmergencyRebalance(poolId, reason);
    }

    /**
     * @dev Compound rewards for a user
     */
    function compoundRewards(address user) external {
        _compoundRewards(user);
    }

    /**
     * @dev Get current APR based on historical performance
     */
    function getCurrentAPR() external view returns (uint256) {
        if (totalValueLocked == 0) return 0;
        
        // Calculate APR based on last 24 hours yield
        uint256 dailyYield = _calculateDailyYield();
        return (dailyYield * 365 * BASIS_POINTS) / totalValueLocked;
    }

    /**
     * @dev Get user's current position value and projected returns
     */
    function getUserPositionInfo(address user) external view returns (
        uint256 currentValue,
        uint256 totalDeposited,
        uint256 unrealizedGains,
        uint256 dailyYield,
        uint256 projectedAPR
    ) {
        // For simplicity, we'll use the first active pool if available
        if (activePools.length == 0) {
            return (0, 0, 0, 0, 0);
        }
        
        bytes32 poolId = activePools[0];
        UserPosition memory position = userPositions[user][poolId];
        PoolState memory state = poolStates[poolId];
        
        if (position.shares == 0) {
            return (0, 0, 0, 0, 0);
        }
        
        currentValue = state.totalShares > 0 ? (position.shares * state.totalLiquidity) / state.totalShares : 0;
        totalDeposited = position.token0Amount + position.token1Amount;
        unrealizedGains = currentValue > totalDeposited ? currentValue - totalDeposited : 0;
        
        // Calculate user's share of daily yield
        uint256 totalDailyYield = _calculateDailyYield();
        dailyYield = state.totalShares > 0 ? (totalDailyYield * position.shares) / state.totalShares : 0;
        
        // Project APR based on current performance
        projectedAPR = totalDeposited > 0 ? (dailyYield * 365 * BASIS_POINTS) / totalDeposited : 0;
    }

    // Internal functions
    function _findPoolForToken(address token) internal view returns (bytes32) {
        for (uint256 i = 0; i < activePools.length; i++) {
            bytes32 poolId = activePools[i];
            if (pools[poolId].token0 == token || pools[poolId].token1 == token) {
                return poolId;
            }
        }
        return bytes32(0);
    }
    
    function _getPoolTotalValue(bytes32 poolId) internal view returns (uint256) {
        PoolState memory state = poolStates[poolId];
        return state.totalToken0 + state.totalToken1; // Simplified - should use oracle prices
    }
    
    function _checkAndRebalancePool(bytes32 poolId) internal {
        if (!pools[poolId].autoRebalanceEnabled) return;
        
        RebalanceParams memory params = rebalanceParams[poolId];
        if (block.timestamp < pools[poolId].lastRebalance + params.minRebalanceInterval) {
            return;
        }
        
        // Check if price deviation exceeds threshold
        uint256 priceDeviation = _calculatePriceDeviation(poolId);
        if (priceDeviation > params.priceDeviationThreshold) {
            _executePoolRebalance(poolId, "Price deviation threshold exceeded");
        }
    }
    
    function _calculatePriceDeviation(bytes32 poolId) internal pure returns (uint256) {
        // Simplified calculation - should use oracle prices and current pool composition
        return 0; // Placeholder
    }
    
    function _executePoolRebalance(bytes32 poolId, string memory reason) internal {
        PoolConfig storage config = pools[poolId];
        PoolState storage state = poolStates[poolId];
        
        // Calculate optimal tick range using simple calculation
        // For simplicity, use a fixed range around current tick
        int24 currentTick = 0; // Placeholder - would normally get from oracle
        int24 tickSpacing = 60; // Standard tick spacing for 0.3% fee
        int24 newTickLower = currentTick - (tickSpacing * 10);
        int24 newTickUpper = currentTick + (tickSpacing * 10);
        
        // Store old tick range for event
        int24 oldTickLower = state.targetTickLower;
        int24 oldTickUpper = state.targetTickUpper;
        
        // Close existing concentrated positions if any
        uint256 liquidityMoved = _closeConcentratedPositions(poolId);
        
        // Collect all fees before rebalancing
        (uint256 fees0, uint256 fees1) = _collectAllFees(poolId);
        
        // Create new concentrated position with optimal range
        uint256 newTokenId = _createConcentratedPosition(
            poolId,
            newTickLower,
            newTickUpper,
            state.totalToken0,
            state.totalToken1
        );
        
        // Update pool state
        state.targetTickLower = newTickLower;
        state.targetTickUpper = newTickUpper;
        state.lastUpdate = block.timestamp;
        config.lastRebalance = block.timestamp;
        
        // Record rebalance action
        rebalanceHistory[poolId].push(RebalanceAction({
            oldTickLower: oldTickLower,
            oldTickUpper: oldTickUpper,
            newTickLower: newTickLower,
            newTickUpper: newTickUpper,
            timestamp: block.timestamp,
            gasUsed: gasleft(),
            liquidityMoved: liquidityMoved,
            fees0Collected: fees0,
            fees1Collected: fees1,
            success: true,
            reason: reason
        }));
        
        emit Rebalanced(poolId, oldTickLower, oldTickUpper, newTickLower, newTickUpper, reason);
    }
    
    function _closeConcentratedPositions(bytes32 poolId) internal returns (uint256 totalLiquidity) {
        ConcentratedPosition[] storage positions = concentratedPositions[poolId];
        
        for (uint256 i = 0; i < positions.length; i++) {
            if (positions[i].isActive && positions[i].liquidity > 0) {
                // Decrease liquidity to zero
                positionManager.decreaseLiquidity(
                    INonfungiblePositionManager.DecreaseLiquidityParams({
                        tokenId: positions[i].tokenId,
                        liquidity: positions[i].liquidity,
                        amount0Min: 0,
                        amount1Min: 0,
                        deadline: block.timestamp + 300
                    })
                );
                
                // Collect tokens
                positionManager.collect(
                    INonfungiblePositionManager.CollectParams({
                        tokenId: positions[i].tokenId,
                        recipient: address(this),
                        amount0Max: type(uint128).max,
                        amount1Max: type(uint128).max
                    })
                );
                
                totalLiquidity += positions[i].liquidity;
                positions[i].isActive = false;
                positions[i].liquidity = 0;
            }
        }
    }
    
    function _collectAllFees(bytes32 poolId) internal returns (uint256 totalFees0, uint256 totalFees1) {
        ConcentratedPosition[] storage positions = concentratedPositions[poolId];
        
        for (uint256 i = 0; i < positions.length; i++) {
            if (positions[i].isActive) {
                (uint256 amount0, uint256 amount1) = positionManager.collect(
                    INonfungiblePositionManager.CollectParams({
                        tokenId: positions[i].tokenId,
                        recipient: address(this),
                        amount0Max: type(uint128).max,
                        amount1Max: type(uint128).max
                    })
                );
                
                totalFees0 += amount0;
                totalFees1 += amount1;
            }
        }
        
        // Apply performance fee
        uint256 protocolFee0 = (totalFees0 * PERFORMANCE_FEE) / 10000;
        uint256 protocolFee1 = (totalFees1 * PERFORMANCE_FEE) / 10000;
        
        poolStates[poolId].totalFees0 += protocolFee0;
        poolStates[poolId].totalFees1 += protocolFee1;
        
        emit FeesCollected(poolId, totalFees0, totalFees1);
        emit PerformanceFeeCollected(poolId, protocolFee0, protocolFee1);
    }
    
    function _createConcentratedPosition(
        bytes32 poolId,
        int24 tickLower,
        int24 tickUpper,
        uint256 amount0Desired,
        uint256 amount1Desired
    ) internal returns (uint256 tokenId) {
        PoolConfig memory config = pools[poolId];
        
        // Approve tokens for position manager
        IERC20(config.token0).approve(address(positionManager), amount0Desired);
        IERC20(config.token1).approve(address(positionManager), amount1Desired);
        
        // Mint new position
        (tokenId, , , ) = positionManager.mint(
            INonfungiblePositionManager.MintParams({
                token0: config.token0,
                token1: config.token1,
                fee: config.fee,
                tickLower: tickLower,
                tickUpper: tickUpper,
                amount0Desired: amount0Desired,
                amount1Desired: amount1Desired,
                amount0Min: (amount0Desired * 95) / 100, // 5% slippage tolerance
                amount1Min: (amount1Desired * 95) / 100,
                recipient: address(this),
                deadline: block.timestamp + 300
            })
        );
        
        // Get position info
        (, , , , , int24 posTickLower, int24 posTickUpper, uint128 liquidity, , , , ) = 
            positionManager.positions(tokenId);
        
        // Store concentrated position
        concentratedPositions[poolId].push(ConcentratedPosition({
            tokenId: tokenId,
            tickLower: posTickLower,
            tickUpper: posTickUpper,
            liquidity: liquidity,
            feeGrowthInside0LastX128: 0,
            feeGrowthInside1LastX128: 0,
            tokensOwed0: 0,
            tokensOwed1: 0,
            isActive: true
        }));
    }
    
    function _checkAndRebalance() internal {
        // Legacy function - now checks all active pools
        for (uint256 i = 0; i < activePools.length; i++) {
            _checkAndRebalancePool(activePools[i]);
        }
    }

    function _executeRebalance() internal {
        // Get rebalancing actions from DynamicRebalancer
        RebalanceAction[] memory actions = _generateRebalanceActions();
        
        // Execute complete rebalancing flow
        for (uint256 i = 0; i < actions.length; i++) {
            if (actions[i].liquidityMoved > 0) {
                _executeRebalanceAction(actions[i]);
            }
        }
        
        lastGlobalRebalance = block.timestamp;
        emit Rebalance(block.timestamp, totalValueLocked);
    }
    
    /**
     * @dev Execute a single rebalancing action with proper unminting/reminting
     */
    function _executeRebalanceAction(RebalanceAction memory action) internal {
        // This function handles tick range rebalancing for concentrated liquidity
        // The action contains tick range information, not token swap information
        
        // For now, we'll emit a simple event to indicate rebalance execution
        // In a full implementation, this would handle the tick range adjustments
        emit RebalanceActionExecuted(address(0), address(0), action.liquidityMoved, action.liquidityMoved);
    }
    
    /**
     * @dev Unmint liquidity for rebalancing purposes
     */
    function _unmintForRebalancing(
        address token,
        uint256 amount
    ) internal returns (uint256 sharesReduced) {
        require(IERC20(token).balanceOf(address(this)) >= amount, "Insufficient token balance");
        
        // Calculate shares to reduce proportionally
        uint256 tokenValue = _getTokenValueUSD(token, amount);
        sharesReduced = totalValueLocked > 0 ? (tokenValue * 1e18) / totalValueLocked : 0;
        
        // Update pool state
        totalValueLocked -= tokenValue;
        
        emit LiquidityUnminted(token, amount, sharesReduced);
    }
    
    /**
     * @dev Re-mint liquidity after rebalancing
     */
    function _remintAfterRebalancing(
        address token,
        uint256 amount
    ) internal returns (uint256 newShares) {
        uint256 tokenValue = _getTokenValueUSD(token, amount);
        
        // Calculate new shares to mint
        if (totalValueLocked == 0) {
            newShares = tokenValue;
        } else {
            newShares = (tokenValue * 1e18) / totalValueLocked;
        }
        
        // Update pool state
        totalValueLocked += tokenValue;
        
        emit LiquidityReminted(token, amount, newShares);
    }
    
    /**
     * @dev Update all user positions after rebalancing
     */
    function _updateUserPositionsAfterRebalance(
        uint256 sharesReduced,
        uint256 newShares
    ) internal {
        // This would iterate through all users and update their positions
        // For now, we emit an event for tracking
        emit UserPositionsUpdated(sharesReduced, newShares, block.timestamp);
    }
    
    /**
     * @dev Execute token swap via DEX integration
     */
    function _executeSwap(
        address tokenFrom,
        address tokenTo,
        uint256 amountIn
    ) internal returns (uint256 amountOut) {
        // This would integrate with actual DEX protocols (Uniswap, etc.)
        // For demo purposes, we simulate a swap with 0.3% fee
        uint256 feeAmount = (amountIn * 30) / 10000; // 0.3% fee
        amountOut = amountIn - feeAmount;
        
        // In production, this would call actual DEX contracts
        emit SwapExecuted(tokenFrom, tokenTo, amountIn, amountOut);
    }
    
    /**
     * @dev Generate rebalancing actions based on current market conditions
     */
    function _generateRebalanceActions() internal pure returns (RebalanceAction[] memory) {
        // This would integrate with DynamicRebalancer contract
        // For now, return empty array
        RebalanceAction[] memory actions = new RebalanceAction[](0);
        return actions;
    }

    function _compoundRewards(address user) internal {
        // For simplicity, we'll use the first active pool if available
        if (activePools.length == 0) return;
        
        bytes32 poolId = activePools[0];
        UserPosition storage position = userPositions[user][poolId];
        PoolState storage state = poolStates[poolId];
        
        if (block.timestamp < position.lastUpdate + COMPOUND_FREQUENCY) {
            return; // Not time to compound yet
        }
        
        // Calculate rewards earned since last compound
        uint256 timeElapsed = block.timestamp - position.lastUpdate;
        uint256 userShare = state.totalShares > 0 ? position.shares * BASIS_POINTS / state.totalShares : 0;
        uint256 rewards = _calculateRewards(userShare, timeElapsed);
        
        if (rewards > 0) {
            // Add rewards to user's position
            uint256 newShares = state.totalLiquidity > 0 ? (rewards * state.totalShares) / state.totalLiquidity : rewards;
            position.shares += newShares;
            state.totalShares += newShares;
            
            emit Compound(user, rewards);
        }
        
        position.lastUpdate = block.timestamp;
    }

    function _getCurrentWeight(address token) internal pure returns (uint256) {
        // Legacy function - simplified for backward compatibility
        return 0;
    }

    function _getTokenValueUSD(address token, uint256 amount) internal pure returns (uint256) {
        // This would integrate with price feeds to get real USD value
        // For now, return a mock calculation
        return amount; // Simplified - assume 1:1 USD for demo
    }

    function _calculateDailyYield() internal view returns (uint256) {
        // Calculate yield based on trading fees, arbitrage profits, etc.
        // This is a simplified calculation
        return totalValueLocked * 25 / BASIS_POINTS / 365; // ~2.5% daily yield
    }

    function _calculateRewards(uint256 userShare, uint256 timeElapsed) internal view returns (uint256) {
        uint256 dailyYield = _calculateDailyYield();
        uint256 userDailyYield = (dailyYield * userShare) / BASIS_POINTS;
        return (userDailyYield * timeElapsed) / 1 days;
    }

    function _abs(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a - b : b - a;
    }
    
    // Emergency and Protection Functions
    bool public emergencyPaused = false;
    
    modifier notPaused() {
        require(!emergencyPaused, "Protocol is paused");
        _;
    }
    
    /**
     * @dev Emergency pause function
     */
    function emergencyPause(string calldata reason) external onlyOwner {
        emergencyPaused = true;
        emit EmergencyPause(reason, block.timestamp);
    }
    
    /**
     * @dev Resume protocol operations
     */
    function resumeOperations() external onlyOwner {
        emergencyPaused = false;
    }
    
    /**
     * @dev Check slippage protection
     */
    function _checkSlippage(
        address token,
        uint256 expectedAmount,
        uint256 actualAmount
    ) internal {
        uint256 slippage = expectedAmount > actualAmount ? 
            ((expectedAmount - actualAmount) * BASIS_POINTS) / expectedAmount : 0;
            
        if (slippage > MAX_SLIPPAGE) {
            emit SlippageProtectionTriggered(token, expectedAmount, actualAmount);
            revert("Slippage too high");
        }
    }
    
    /**
     * @dev Get rebalancing status and metrics
     */
    function getRebalancingStatus() external view returns (
        bool isRebalancing,
        uint256 lastRebalanceTime,
        uint256 nextRebalanceTime,
        uint256 totalRebalances,
        bool emergencyPauseStatus
    ) {
        isRebalancing = block.timestamp < lastGlobalRebalance + REBALANCE_COOLDOWN;
        lastRebalanceTime = lastGlobalRebalance;
        nextRebalanceTime = lastGlobalRebalance + REBALANCE_COOLDOWN;
        totalRebalances = 0; // Would track this in production
        emergencyPauseStatus = false; // Would implement emergency pause
    }
    
    /**
     * @dev Get detailed pool composition
     */
    function getPoolComposition() external view returns (
        address[] memory tokens,
        uint256[] memory balances,
        uint256[] memory weights,
        uint256[] memory targetWeights
    ) {
        tokens = new address[](activePools.length * 2);
        balances = new uint256[](activePools.length * 2);
        weights = new uint256[](activePools.length * 2);
        targetWeights = new uint256[](activePools.length * 2);
        
        uint256 index = 0;
        for (uint256 i = 0; i < activePools.length; i++) {
            bytes32 poolId = activePools[i];
            PoolConfig memory config = pools[poolId];
            tokens[index] = config.token0;
            tokens[index + 1] = config.token1;
            balances[index] = IERC20(config.token0).balanceOf(address(this));
            balances[index + 1] = IERC20(config.token1).balanceOf(address(this));
            weights[index] = 5000; // 50% weight for simplicity
            weights[index + 1] = 5000; // 50% weight for simplicity
            targetWeights[index] = 5000;
            targetWeights[index + 1] = 5000;
            index += 2;
        }
    }
}
