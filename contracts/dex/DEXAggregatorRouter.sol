// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title DEXAggregatorRouter
 * @dev Advanced DEX aggregation and routing system for optimal trade execution
 */
contract DEXAggregatorRouter is AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using Math for uint256;
    
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant ROUTER_ROLE = keccak256("ROUTER_ROLE");
    bytes32 public constant LIQUIDITY_PROVIDER_ROLE = keccak256("LIQUIDITY_PROVIDER_ROLE");
    
    uint256 public constant PRECISION = 1e18;
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant MAX_SLIPPAGE = 1000; // 10%
    
    enum DEXType {
        UNISWAP_V2,
        UNISWAP_V3,
        SUSHISWAP,
        CURVE,
        BALANCER,
        INTERNAL_AMM
    }
    
    enum RouteType {
        DIRECT,
        SINGLE_HOP,
        MULTI_HOP,
        SPLIT_ROUTE
    }
    
    struct DEXInfo {
        address dexAddress;
        DEXType dexType;
        uint256 fee; // Fee in basis points
        uint256 gasEstimate;
        bool isActive;
        uint256 totalVolume;
        uint256 totalTrades;
    }
    
    struct LiquidityPool {
        address poolAddress;
        address token0;
        address token1;
        uint256 reserve0;
        uint256 reserve1;
        uint256 fee;
        DEXType dexType;
        uint256 lastUpdate;
        bool isActive;
    }
    
    struct TradeRoute {
        address[] path;
        address[] pools;
        DEXType[] dexTypes;
        uint256[] fees;
        uint256 expectedOutput;
        uint256 gasEstimate;
        uint256 priceImpact;
        RouteType routeType;
    }
    
    struct SplitRoute {
        TradeRoute[] routes;
        uint256[] allocations; // Percentage allocation for each route
        uint256 totalExpectedOutput;
        uint256 totalGasEstimate;
    }
    
    struct TradeExecution {
        uint256 tradeId;
        address trader;
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 amountOut;
        uint256 minAmountOut;
        TradeRoute route;
        uint256 actualOutput;
        uint256 gasUsed;
        uint256 timestamp;
        bool isCompleted;
    }
    
    struct PriceQuote {
        uint256 amountOut;
        uint256 priceImpact;
        uint256 gasEstimate;
        TradeRoute bestRoute;
        SplitRoute splitRoute;
        uint256 timestamp;
    }
    
    // Storage
    mapping(uint256 => DEXInfo) public dexes;
    mapping(bytes32 => LiquidityPool) public liquidityPools; // keccak256(token0, token1, dexType)
    mapping(uint256 => TradeExecution) public trades;
    mapping(address => mapping(address => TradeRoute[])) public cachedRoutes;
    mapping(address => mapping(address => uint256)) public routeCache; // Last update timestamp
    
    uint256 public dexCounter;
    uint256 public tradeCounter;
    uint256 public totalVolumeUSD;
    uint256 public totalFeesCollected;
    
    // Route optimization parameters
    uint256 public maxHops = 3;
    uint256 public routeCacheExpiry = 300; // 5 minutes
    uint256 public minLiquidityThreshold = 1000 * 1e18; // $1000
    uint256 public maxPriceImpact = 500; // 5%
    
    // Fee structure
    uint256 public protocolFee = 30; // 0.3%
    address public feeRecipient;
    
    event DEXAdded(uint256 indexed dexId, address indexed dexAddress, DEXType dexType);
    event LiquidityPoolAdded(bytes32 indexed poolId, address indexed token0, address indexed token1);
    event TradeExecuted(
        uint256 indexed tradeId,
        address indexed trader,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut
    );
    event RouteOptimized(
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 expectedOutput,
        RouteType routeType
    );
    
    constructor(address _feeRecipient) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(ROUTER_ROLE, msg.sender);
        
        feeRecipient = _feeRecipient;
    }
    
    /**
     * @dev Add a new DEX to the aggregator
     */
    function addDEX(
        address dexAddress,
        DEXType dexType,
        uint256 fee,
        uint256 gasEstimate
    ) external onlyRole(ADMIN_ROLE) {
        uint256 dexId = ++dexCounter;
        
        dexes[dexId] = DEXInfo({
            dexAddress: dexAddress,
            dexType: dexType,
            fee: fee,
            gasEstimate: gasEstimate,
            isActive: true,
            totalVolume: 0,
            totalTrades: 0
        });
        
        emit DEXAdded(dexId, dexAddress, dexType);
    }
    
    /**
     * @dev Add liquidity pool information
     */
    function addLiquidityPool(
        address poolAddress,
        address token0,
        address token1,
        uint256 reserve0,
        uint256 reserve1,
        uint256 fee,
        DEXType dexType
    ) external onlyRole(LIQUIDITY_PROVIDER_ROLE) {
        bytes32 poolId = keccak256(abi.encodePacked(token0, token1, dexType));
        
        liquidityPools[poolId] = LiquidityPool({
            poolAddress: poolAddress,
            token0: token0,
            token1: token1,
            reserve0: reserve0,
            reserve1: reserve1,
            fee: fee,
            dexType: dexType,
            lastUpdate: block.timestamp,
            isActive: true
        });
        
        emit LiquidityPoolAdded(poolId, token0, token1);
    }
    
    /**
     * @dev Get best price quote for a trade
     */
    function getBestQuote(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external view returns (PriceQuote memory) {
        // Try direct route first
        TradeRoute memory directRoute = _findDirectRoute(tokenIn, tokenOut, amountIn);
        
        // Try single hop routes
        TradeRoute memory singleHopRoute = _findBestSingleHopRoute(tokenIn, tokenOut, amountIn);
        
        // Try multi-hop routes
        TradeRoute memory multiHopRoute = _findBestMultiHopRoute(tokenIn, tokenOut, amountIn);
        
        // Find the best route
        TradeRoute memory bestRoute = directRoute;
        if (singleHopRoute.expectedOutput > bestRoute.expectedOutput) {
            bestRoute = singleHopRoute;
        }
        if (multiHopRoute.expectedOutput > bestRoute.expectedOutput) {
            bestRoute = multiHopRoute;
        }
        
        // Calculate split route for large trades
        SplitRoute memory splitRoute = _calculateSplitRoute(tokenIn, tokenOut, amountIn);
        
        return PriceQuote({
            amountOut: bestRoute.expectedOutput,
            priceImpact: bestRoute.priceImpact,
            gasEstimate: bestRoute.gasEstimate,
            bestRoute: bestRoute,
            splitRoute: splitRoute,
            timestamp: block.timestamp
        });
    }
    
    /**
     * @dev Execute optimal trade
     */
    function executeOptimalTrade(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        uint256 deadline
    ) external nonReentrant returns (uint256) {
        require(deadline >= block.timestamp, "Trade expired");
        require(amountIn > 0, "Invalid amount");
        
        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);
        
        PriceQuote memory quote = this.getBestQuote(tokenIn, tokenOut, amountIn);
        require(quote.amountOut >= minAmountOut, "Insufficient output");
        
        uint256 tradeId = ++tradeCounter;
        uint256 startGas = gasleft();
        
        uint256 actualOutput;
        
        // Execute based on best route type
        if (quote.splitRoute.totalExpectedOutput > quote.bestRoute.expectedOutput) {
            actualOutput = _executeSplitTrade(tokenIn, tokenOut, amountIn, quote.splitRoute);
        } else {
            actualOutput = _executeSingleRoute(tokenIn, tokenOut, amountIn, quote.bestRoute);
        }
        
        uint256 gasUsed = startGas - gasleft();
        
        // Deduct protocol fee
        uint256 protocolFeeAmount = (actualOutput * protocolFee) / BASIS_POINTS;
        actualOutput -= protocolFeeAmount;
        
        if (protocolFeeAmount > 0) {
            IERC20(tokenOut).safeTransfer(feeRecipient, protocolFeeAmount);
            totalFeesCollected += protocolFeeAmount;
        }
        
        IERC20(tokenOut).safeTransfer(msg.sender, actualOutput);
        
        trades[tradeId] = TradeExecution({
            tradeId: tradeId,
            trader: msg.sender,
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            amountIn: amountIn,
            amountOut: quote.amountOut,
            minAmountOut: minAmountOut,
            route: quote.bestRoute,
            actualOutput: actualOutput,
            gasUsed: gasUsed,
            timestamp: block.timestamp,
            isCompleted: true
        });
        
        emit TradeExecuted(tradeId, msg.sender, tokenIn, tokenOut, amountIn, actualOutput);
        
        return actualOutput;
    }
    
    /**
     * @dev Find direct route between two tokens
     */
    function _findDirectRoute(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) internal view returns (TradeRoute memory) {
        TradeRoute memory route;
        route.path = new address[](2);
        route.path[0] = tokenIn;
        route.path[1] = tokenOut;
        route.routeType = RouteType.DIRECT;
        
        uint256 bestOutput = 0;
        DEXType bestDex;
        
        // Check all DEXes for direct pair
        for (uint256 i = 1; i <= dexCounter; i++) {
            if (!dexes[i].isActive) continue;
            
            bytes32 poolId = keccak256(abi.encodePacked(tokenIn, tokenOut, dexes[i].dexType));
            LiquidityPool memory pool = liquidityPools[poolId];
            
            if (pool.isActive && pool.poolAddress != address(0)) {
                uint256 output = _calculateOutput(amountIn, pool.reserve0, pool.reserve1, pool.fee);
                
                if (output > bestOutput) {
                    bestOutput = output;
                    bestDex = dexes[i].dexType;
                    route.gasEstimate = dexes[i].gasEstimate;
                }
            }
        }
        
        route.expectedOutput = bestOutput;
        route.dexTypes = new DEXType[](1);
        route.dexTypes[0] = bestDex;
        
        return route;
    }
    
    /**
     * @dev Find best single hop route
     */
    function _findBestSingleHopRoute(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) internal view returns (TradeRoute memory) {
        TradeRoute memory bestRoute;
        bestRoute.routeType = RouteType.SINGLE_HOP;
        
        // Implementation would check common intermediate tokens like WETH, USDC, etc.
        // For brevity, returning empty route
        return bestRoute;
    }
    
    /**
     * @dev Find best multi-hop route
     */
    function _findBestMultiHopRoute(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) internal view returns (TradeRoute memory) {
        TradeRoute memory bestRoute;
        bestRoute.routeType = RouteType.MULTI_HOP;
        
        // Implementation would use pathfinding algorithms
        // For brevity, returning empty route
        return bestRoute;
    }
    
    /**
     * @dev Calculate split route for large trades
     */
    function _calculateSplitRoute(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) internal view returns (SplitRoute memory) {
        SplitRoute memory splitRoute;
        
        // Implementation would split large trades across multiple DEXes
        // to minimize price impact
        return splitRoute;
    }
    
    /**
     * @dev Execute trade using single route
     */
    function _executeSingleRoute(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        TradeRoute memory route
    ) internal returns (uint256) {
        require(route.pools.length > 0, "Invalid route");
        
        uint256 currentAmount = amountIn;
        address currentTokenIn = tokenIn;
        address currentTokenOut;
        
        // Execute trades through each pool in the route
        for (uint256 i = 0; i < route.pools.length; i++) {
            address poolAddress = route.pools[i];
            bytes32 poolId = keccak256(abi.encodePacked(poolAddress, route.dexTypes[i]));
            LiquidityPool storage pool = liquidityPools[poolId];
            require(pool.isActive, "Pool not active");
            
            // Determine output token for this hop
            if (i == route.pools.length - 1) {
                currentTokenOut = tokenOut;
            } else {
                // For multi-hop, determine intermediate token
                currentTokenOut = pool.token0 == currentTokenIn ? pool.token1 : pool.token0;
            }
            
            // Execute swap on the pool
            currentAmount = _executePoolSwap(poolId, currentTokenIn, currentTokenOut, currentAmount);
            currentTokenIn = currentTokenOut;
        }
        
        return currentAmount;
    }
    
    /**
     * @dev Execute split trade across multiple routes
     */
    function _executeSplitTrade(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        SplitRoute memory splitRoute
    ) internal returns (uint256) {
        uint256 totalOutput = 0;
        
        for (uint256 i = 0; i < splitRoute.routes.length; i++) {
            uint256 routeAmountIn = (amountIn * splitRoute.allocations[i]) / BASIS_POINTS;
            uint256 routeOutput = _executeSingleRoute(tokenIn, tokenOut, routeAmountIn, splitRoute.routes[i]);
            totalOutput += routeOutput;
        }
        
        return totalOutput;
    }
    
    /**
     * @dev Calculate output amount using constant product formula
     */
    function _calculateOutput(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut,
        uint256 fee
    ) internal pure returns (uint256) {
        if (reserveIn == 0 || reserveOut == 0) return 0;
        
        uint256 amountInWithFee = amountIn * (BASIS_POINTS - fee);
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * BASIS_POINTS) + amountInWithFee;
        
        return numerator / denominator;
    }
    
    /**
     * @dev Update liquidity pool reserves
     */
    function updatePoolReserves(
        address token0,
        address token1,
        DEXType dexType,
        uint256 reserve0,
        uint256 reserve1
    ) external onlyRole(LIQUIDITY_PROVIDER_ROLE) {
        bytes32 poolId = keccak256(abi.encodePacked(token0, token1, dexType));
        LiquidityPool storage pool = liquidityPools[poolId];
        
        pool.reserve0 = reserve0;
        pool.reserve1 = reserve1;
        pool.lastUpdate = block.timestamp;
    }
    
    /**
     * @dev Get trade history for user
     */
    function getUserTrades(address user) external view returns (uint256[] memory) {
        uint256[] memory userTrades = new uint256[](tradeCounter);
        uint256 count = 0;
        
        for (uint256 i = 1; i <= tradeCounter; i++) {
            if (trades[i].trader == user) {
                userTrades[count] = i;
                count++;
            }
        }
        
        // Resize array
        uint256[] memory result = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            result[i] = userTrades[i];
        }
        
        return result;
    }
    
    /**
     * @dev Get DEX performance statistics
     */
    function getDEXStats(uint256 dexId) external view returns (
        uint256 totalVolume,
        uint256 totalTrades,
        uint256 averageGasUsed,
        bool isActive
    ) {
        DEXInfo memory dex = dexes[dexId];
        return (dex.totalVolume, dex.totalTrades, dex.gasEstimate, dex.isActive);
    }
    
    /**
     * @dev Emergency pause DEX
     */
    function pauseDEX(uint256 dexId) external onlyRole(ADMIN_ROLE) {
        dexes[dexId].isActive = false;
    }
    
    /**
     * @dev Resume DEX
     */
    function resumeDEX(uint256 dexId) external onlyRole(ADMIN_ROLE) {
        dexes[dexId].isActive = true;
    }
    
    /**
     * @dev Update protocol fee
     */
    function updateProtocolFee(uint256 newFee) external onlyRole(ADMIN_ROLE) {
        require(newFee <= 100, "Fee too high"); // Max 1%
        protocolFee = newFee;
    }
    
    /**
     * @dev Update fee recipient
     */
    function updateFeeRecipient(address newRecipient) external onlyRole(ADMIN_ROLE) {
        require(newRecipient != address(0), "Invalid recipient");
        feeRecipient = newRecipient;
    }
    
    /**
     * @dev Execute swap on a specific pool
     */
    function _executePoolSwap(
        bytes32 poolId,
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) internal returns (uint256) {
        LiquidityPool storage pool = liquidityPools[poolId];
        require(pool.isActive, "Pool not active");
        
        // Get pool reserves
        uint256 reserveIn = pool.token0 == tokenIn ? pool.reserve0 : pool.reserve1;
        uint256 reserveOut = pool.token0 == tokenOut ? pool.reserve0 : pool.reserve1;
        
        // Calculate output amount using constant product formula (x * y = k)
        // amountOut = (amountIn * reserveOut) / (reserveIn + amountIn)
        uint256 amountOut = (amountIn * reserveOut) / (reserveIn + amountIn);
        
        // Apply fee (0.3% typical)
        uint256 fee = (amountOut * 3) / 1000;
        amountOut = amountOut - fee;
        
        // Update pool reserves
        if (pool.token0 == tokenIn) {
            pool.reserve0 += amountIn;
            pool.reserve1 -= amountOut;
        } else {
            pool.reserve1 += amountIn;
            pool.reserve0 -= amountOut;
        }
        
        return amountOut;
    }
    
    /**
     * @dev Emergency withdraw tokens
     */
    function emergencyWithdraw(address token, uint256 amount) external onlyRole(ADMIN_ROLE) {
        IERC20(token).safeTransfer(msg.sender, amount);
    }
}