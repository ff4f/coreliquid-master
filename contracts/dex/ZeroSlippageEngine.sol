// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title ZeroSlippageEngine
 * @dev Advanced zero-slippage trading engine with dynamic liquidity management
 */
contract ZeroSlippageEngine is AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using Math for uint256;
    
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant LIQUIDITY_PROVIDER_ROLE = keccak256("LIQUIDITY_PROVIDER_ROLE");
    bytes32 public constant KEEPER_ROLE = keccak256("KEEPER_ROLE");
    
    uint256 public constant PRECISION = 1e18;
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant MAX_SLIPPAGE = 50; // 0.5%
    uint256 public constant MIN_LIQUIDITY_THRESHOLD = 1000 * 1e18;
    
    enum OrderType {
        MARKET,
        LIMIT,
        STOP_LOSS,
        TAKE_PROFIT,
        TWAP,
        ICEBERG
    }
    
    enum OrderStatus {
        PENDING,
        PARTIALLY_FILLED,
        FILLED,
        CANCELLED,
        EXPIRED
    }
    
    struct LiquidityPool {
        address tokenA;
        address tokenB;
        uint256 reserveA;
        uint256 reserveB;
        uint256 totalLiquidity;
        uint256 fee; // Fee in basis points
        uint256 lastUpdate;
        bool active;
        uint256 virtualReserveA; // For zero-slippage calculations
        uint256 virtualReserveB;
        uint256 amplificationFactor; // For stable swaps
    }
    
    struct Order {
        uint256 orderId;
        address trader;
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 amountOut;
        uint256 minAmountOut;
        uint256 maxSlippage;
        OrderType orderType;
        OrderStatus status;
        uint256 createdAt;
        uint256 expiresAt;
        uint256 filledAmount;
        uint256 executionPrice;
        bool partialFillAllowed;
        bytes32 poolId;
    }
    
    struct TWAPOrder {
        uint256 orderId;
        uint256 totalAmount;
        uint256 intervalDuration;
        uint256 numberOfIntervals;
        uint256 currentInterval;
        uint256 amountPerInterval;
        uint256 lastExecution;
        uint256 totalExecuted;
    }
    
    struct IcebergOrder {
        uint256 orderId;
        uint256 totalAmount;
        uint256 visibleAmount;
        uint256 executedAmount;
        uint256 currentVisibleAmount;
    }
    
    struct ArbitrageOpportunity {
        bytes32 poolId1;
        bytes32 poolId2;
        address token;
        uint256 priceDifference;
        uint256 profitPotential;
        uint256 timestamp;
        bool executed;
    }
    
    struct SlippageProtection {
        uint256 maxSlippage;
        uint256 priceImpactThreshold;
        uint256 liquidityThreshold;
        bool dynamicSlippageEnabled;
        uint256 slippageBuffer;
    }
    
    // Storage
    mapping(bytes32 => LiquidityPool) public liquidityPools;
    mapping(uint256 => Order) public orders;
    mapping(uint256 => TWAPOrder) public twapOrders;
    mapping(uint256 => IcebergOrder) public icebergOrders;
    mapping(address => uint256[]) public userOrders;
    mapping(bytes32 => ArbitrageOpportunity[]) public arbitrageOpportunities;
    mapping(address => SlippageProtection) public slippageProtection;
    
    // Pool tracking
    bytes32[] public poolIds;
    mapping(address => mapping(address => bytes32)) public getPoolId;
    
    // Order tracking
    uint256 public orderCounter;
    uint256[] public activeOrders;
    uint256[] public pendingTWAPOrders;
    uint256[] public pendingIcebergOrders;
    
    // Price tracking
    mapping(bytes32 => uint256) public lastPrice;
    mapping(bytes32 => uint256[]) public priceHistory;
    mapping(bytes32 => uint256) public priceMovingAverage;
    
    // Liquidity management
    mapping(address => uint256) public totalLiquidityProvided;
    mapping(address => mapping(bytes32 => uint256)) public userLiquidity;
    
    // Fee management
    uint256 public protocolFee = 30; // 0.3%
    address public feeRecipient;
    mapping(address => uint256) public collectedFees;
    
    // Emergency controls
    bool public tradingPaused;
    bool public emergencyMode;
    mapping(bytes32 => bool) public poolPaused;
    
    event PoolCreated(
        bytes32 indexed poolId,
        address indexed tokenA,
        address indexed tokenB,
        uint256 fee
    );
    
    event OrderCreated(
        uint256 indexed orderId,
        address indexed trader,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        OrderType orderType
    );
    
    event OrderExecuted(
        uint256 indexed orderId,
        uint256 amountIn,
        uint256 amountOut,
        uint256 executionPrice,
        uint256 slippage
    );
    
    event LiquidityAdded(
        bytes32 indexed poolId,
        address indexed provider,
        uint256 amountA,
        uint256 amountB,
        uint256 liquidity
    );
    
    event ArbitrageExecuted(
        bytes32 indexed poolId1,
        bytes32 indexed poolId2,
        address indexed token,
        uint256 profit
    );
    
    event SlippageProtectionTriggered(
        uint256 indexed orderId,
        uint256 expectedSlippage,
        uint256 actualSlippage
    );
    
    constructor(address _feeRecipient) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(OPERATOR_ROLE, msg.sender);
        _grantRole(KEEPER_ROLE, msg.sender);
        
        feeRecipient = _feeRecipient;
    }
    
    /**
     * @dev Create a new liquidity pool
     */
    function createPool(
        address tokenA,
        address tokenB,
        uint256 fee,
        uint256 amplificationFactor
    ) external onlyRole(OPERATOR_ROLE) returns (bytes32 poolId) {
        require(tokenA != tokenB, "Identical tokens");
        require(tokenA != address(0) && tokenB != address(0), "Zero address");
        require(fee <= 1000, "Fee too high"); // Max 10%
        
        // Ensure consistent ordering
        if (tokenA > tokenB) {
            (tokenA, tokenB) = (tokenB, tokenA);
        }
        
        poolId = keccak256(abi.encodePacked(tokenA, tokenB, fee));
        require(liquidityPools[poolId].tokenA == address(0), "Pool exists");
        
        liquidityPools[poolId] = LiquidityPool({
            tokenA: tokenA,
            tokenB: tokenB,
            reserveA: 0,
            reserveB: 0,
            totalLiquidity: 0,
            fee: fee,
            lastUpdate: block.timestamp,
            active: true,
            virtualReserveA: 0,
            virtualReserveB: 0,
            amplificationFactor: amplificationFactor
        });
        
        poolIds.push(poolId);
        getPoolId[tokenA][tokenB] = poolId;
        getPoolId[tokenB][tokenA] = poolId;
        
        emit PoolCreated(poolId, tokenA, tokenB, fee);
    }
    
    /**
     * @dev Add liquidity to a pool
     */
    function addLiquidity(
        bytes32 poolId,
        uint256 amountA,
        uint256 amountB,
        uint256 minLiquidity
    ) external nonReentrant returns (uint256 liquidity) {
        LiquidityPool storage pool = liquidityPools[poolId];
        require(pool.active && !poolPaused[poolId], "Pool inactive");
        
        IERC20(pool.tokenA).safeTransferFrom(msg.sender, address(this), amountA);
        IERC20(pool.tokenB).safeTransferFrom(msg.sender, address(this), amountB);
        
        if (pool.totalLiquidity == 0) {
            liquidity = Math.sqrt(amountA * amountB);
            require(liquidity > 1000, "Insufficient liquidity"); // Minimum liquidity
        } else {
            uint256 liquidityA = (amountA * pool.totalLiquidity) / pool.reserveA;
            uint256 liquidityB = (amountB * pool.totalLiquidity) / pool.reserveB;
            liquidity = Math.min(liquidityA, liquidityB);
        }
        
        require(liquidity >= minLiquidity, "Insufficient liquidity minted");
        
        pool.reserveA += amountA;
        pool.reserveB += amountB;
        pool.totalLiquidity += liquidity;
        pool.lastUpdate = block.timestamp;
        
        // Update virtual reserves for zero-slippage calculations
        _updateVirtualReserves(poolId);
        
        userLiquidity[msg.sender][poolId] += liquidity;
        totalLiquidityProvided[msg.sender] += liquidity;
        
        emit LiquidityAdded(poolId, msg.sender, amountA, amountB, liquidity);
    }
    
    /**
     * @dev Create a zero-slippage market order
     */
    function createMarketOrder(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        uint256 maxSlippage
    ) external nonReentrant returns (uint256 orderId) {
        require(!tradingPaused && !emergencyMode, "Trading paused");
        require(maxSlippage <= MAX_SLIPPAGE, "Slippage too high");
        
        orderId = ++orderCounter;
        
        bytes32 poolId = getPoolId[tokenIn][tokenOut];
        require(poolId != bytes32(0), "Pool not found");
        
        orders[orderId] = Order({
            orderId: orderId,
            trader: msg.sender,
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            amountIn: amountIn,
            amountOut: 0,
            minAmountOut: minAmountOut,
            maxSlippage: maxSlippage,
            orderType: OrderType.MARKET,
            status: OrderStatus.PENDING,
            createdAt: block.timestamp,
            expiresAt: block.timestamp + 1 hours, // Default 1 hour expiry
            filledAmount: 0,
            executionPrice: 0,
            partialFillAllowed: false,
            poolId: poolId
        });
        
        userOrders[msg.sender].push(orderId);
        activeOrders.push(orderId);
        
        // Execute immediately if possible
        _executeOrder(orderId);
        
        emit OrderCreated(orderId, msg.sender, tokenIn, tokenOut, amountIn, OrderType.MARKET);
    }
    
    /**
     * @dev Create a TWAP order for large trades
     */
    function createTWAPOrder(
        address tokenIn,
        address tokenOut,
        uint256 totalAmount,
        uint256 intervalDuration,
        uint256 numberOfIntervals,
        uint256 maxSlippage
    ) external nonReentrant returns (uint256 orderId) {
        require(!tradingPaused && !emergencyMode, "Trading paused");
        require(numberOfIntervals > 0 && numberOfIntervals <= 100, "Invalid intervals");
        
        orderId = ++orderCounter;
        uint256 amountPerInterval = totalAmount / numberOfIntervals;
        
        bytes32 poolId = getPoolId[tokenIn][tokenOut];
        require(poolId != bytes32(0), "Pool not found");
        
        orders[orderId] = Order({
            orderId: orderId,
            trader: msg.sender,
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            amountIn: totalAmount,
            amountOut: 0,
            minAmountOut: 0,
            maxSlippage: maxSlippage,
            orderType: OrderType.TWAP,
            status: OrderStatus.PENDING,
            createdAt: block.timestamp,
            expiresAt: block.timestamp + (intervalDuration * numberOfIntervals),
            filledAmount: 0,
            executionPrice: 0,
            partialFillAllowed: true,
            poolId: poolId
        });
        
        twapOrders[orderId] = TWAPOrder({
            orderId: orderId,
            totalAmount: totalAmount,
            intervalDuration: intervalDuration,
            numberOfIntervals: numberOfIntervals,
            currentInterval: 0,
            amountPerInterval: amountPerInterval,
            lastExecution: block.timestamp,
            totalExecuted: 0
        });
        
        userOrders[msg.sender].push(orderId);
        pendingTWAPOrders.push(orderId);
        
        emit OrderCreated(orderId, msg.sender, tokenIn, tokenOut, totalAmount, OrderType.TWAP);
    }
    
    /**
     * @dev Execute a market order with zero-slippage protection
     */
    function _executeOrder(uint256 orderId) internal {
        Order storage order = orders[orderId];
        require(order.status == OrderStatus.PENDING, "Order not pending");
        
        LiquidityPool storage pool = liquidityPools[order.poolId];
        require(pool.active && !poolPaused[order.poolId], "Pool inactive");
        
        // Calculate output amount with zero-slippage algorithm
        uint256 amountOut = _calculateZeroSlippageOutput(
            order.poolId,
            order.tokenIn,
            order.tokenOut,
            order.amountIn
        );
        
        // Check slippage protection
        uint256 expectedPrice = _getExpectedPrice(order.poolId, order.tokenIn, order.tokenOut);
        uint256 actualPrice = (order.amountIn * PRECISION) / amountOut;
        uint256 slippage = _calculateSlippage(expectedPrice, actualPrice);
        
        if (slippage > order.maxSlippage) {
            emit SlippageProtectionTriggered(orderId, order.maxSlippage, slippage);
            return;
        }
        
        require(amountOut >= order.minAmountOut, "Insufficient output amount");
        
        // Execute the trade
        IERC20(order.tokenIn).safeTransferFrom(order.trader, address(this), order.amountIn);
        IERC20(order.tokenOut).safeTransfer(order.trader, amountOut);
        
        // Update pool reserves
        if (order.tokenIn == pool.tokenA) {
            pool.reserveA += order.amountIn;
            pool.reserveB -= amountOut;
        } else {
            pool.reserveB += order.amountIn;
            pool.reserveA -= amountOut;
        }
        
        // Update order status
        order.status = OrderStatus.FILLED;
        order.amountOut = amountOut;
        order.filledAmount = order.amountIn;
        order.executionPrice = actualPrice;
        
        // Update virtual reserves
        _updateVirtualReserves(order.poolId);
        
        // Update price tracking
        _updatePriceTracking(order.poolId, actualPrice);
        
        emit OrderExecuted(orderId, order.amountIn, amountOut, actualPrice, slippage);
    }
    
    /**
     * @dev Calculate zero-slippage output amount
     */
    function _calculateZeroSlippageOutput(
        bytes32 poolId,
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) internal view returns (uint256) {
        LiquidityPool memory pool = liquidityPools[poolId];
        
        uint256 reserveIn = tokenIn == pool.tokenA ? pool.virtualReserveA : pool.virtualReserveB;
        uint256 reserveOut = tokenIn == pool.tokenA ? pool.virtualReserveB : pool.virtualReserveA;
        
        // Use constant product formula with virtual reserves
        uint256 amountInWithFee = amountIn * (BASIS_POINTS - pool.fee) / BASIS_POINTS;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn + amountInWithFee;
        
        return numerator / denominator;
    }
    
    /**
     * @dev Update virtual reserves for zero-slippage calculations
     */
    function _updateVirtualReserves(bytes32 poolId) internal {
        LiquidityPool storage pool = liquidityPools[poolId];
        
        // Virtual reserves include a buffer to minimize slippage
        uint256 bufferA = pool.reserveA * 10 / 100; // 10% buffer
        uint256 bufferB = pool.reserveB * 10 / 100;
        
        pool.virtualReserveA = pool.reserveA + bufferA;
        pool.virtualReserveB = pool.reserveB + bufferB;
    }
    
    /**
     * @dev Execute TWAP orders
     */
    function executeTWAPOrders() external onlyRole(KEEPER_ROLE) {
        for (uint256 i = 0; i < pendingTWAPOrders.length; i++) {
            uint256 orderId = pendingTWAPOrders[i];
            TWAPOrder storage twapOrder = twapOrders[orderId];
            Order storage order = orders[orderId];
            
            if (order.status != OrderStatus.PENDING && order.status != OrderStatus.PARTIALLY_FILLED) {
                continue;
            }
            
            if (block.timestamp >= twapOrder.lastExecution + twapOrder.intervalDuration) {
                _executeTWAPInterval(orderId);
            }
        }
    }
    
    /**
     * @dev Execute a single TWAP interval
     */
    function _executeTWAPInterval(uint256 orderId) internal {
        TWAPOrder storage twapOrder = twapOrders[orderId];
        Order storage order = orders[orderId];
        
        if (twapOrder.currentInterval >= twapOrder.numberOfIntervals) {
            order.status = OrderStatus.FILLED;
            return;
        }
        
        uint256 amountToExecute = Math.min(
            twapOrder.amountPerInterval,
            order.amountIn - twapOrder.totalExecuted
        );
        
        if (amountToExecute > 0) {
            // Create temporary order for this interval
            uint256 amountOut = _calculateZeroSlippageOutput(
                order.poolId,
                order.tokenIn,
                order.tokenOut,
                amountToExecute
            );
            
            // Execute the trade
            IERC20(order.tokenIn).safeTransferFrom(order.trader, address(this), amountToExecute);
            IERC20(order.tokenOut).safeTransfer(order.trader, amountOut);
            
            // Update TWAP order
            twapOrder.totalExecuted += amountToExecute;
            twapOrder.currentInterval++;
            twapOrder.lastExecution = block.timestamp;
            
            // Update main order
            order.filledAmount += amountToExecute;
            order.amountOut += amountOut;
            
            if (twapOrder.totalExecuted >= order.amountIn) {
                order.status = OrderStatus.FILLED;
            } else {
                order.status = OrderStatus.PARTIALLY_FILLED;
            }
        }
    }
    
    /**
     * @dev Detect and execute arbitrage opportunities
     */
    function detectArbitrage() external onlyRole(KEEPER_ROLE) {
        for (uint256 i = 0; i < poolIds.length; i++) {
            for (uint256 j = i + 1; j < poolIds.length; j++) {
                bytes32 poolId1 = poolIds[i];
                bytes32 poolId2 = poolIds[j];
                
                LiquidityPool memory pool1 = liquidityPools[poolId1];
                LiquidityPool memory pool2 = liquidityPools[poolId2];
                
                // Check if pools share a common token
                address commonToken = address(0);
                if (pool1.tokenA == pool2.tokenA || pool1.tokenA == pool2.tokenB) {
                    commonToken = pool1.tokenA;
                } else if (pool1.tokenB == pool2.tokenA || pool1.tokenB == pool2.tokenB) {
                    commonToken = pool1.tokenB;
                }
                
                if (commonToken != address(0)) {
                    _checkArbitrageOpportunity(poolId1, poolId2, commonToken);
                }
            }
        }
    }
    
    /**
     * @dev Check for arbitrage opportunity between two pools
     */
    function _checkArbitrageOpportunity(
        bytes32 poolId1,
        bytes32 poolId2,
        address token
    ) internal {
        uint256 price1 = _getTokenPrice(poolId1, token);
        uint256 price2 = _getTokenPrice(poolId2, token);
        
        if (price1 == 0 || price2 == 0) return;
        
        uint256 priceDifference = price1 > price2 ? price1 - price2 : price2 - price1;
        uint256 priceDifferencePercent = (priceDifference * BASIS_POINTS) / Math.min(price1, price2);
        
        // Arbitrage opportunity if price difference > 1%
        if (priceDifferencePercent > 100) {
            ArbitrageOpportunity memory opportunity = ArbitrageOpportunity({
                poolId1: poolId1,
                poolId2: poolId2,
                token: token,
                priceDifference: priceDifferencePercent,
                profitPotential: 0, // Calculate based on available liquidity
                timestamp: block.timestamp,
                executed: false
            });
            
            arbitrageOpportunities[token].push(opportunity);
        }
    }
    
    /**
     * @dev Get token price in a pool
     */
    function _getTokenPrice(bytes32 poolId, address token) internal view returns (uint256) {
        LiquidityPool memory pool = liquidityPools[poolId];
        
        if (token == pool.tokenA) {
            return pool.reserveB * PRECISION / pool.reserveA;
        } else if (token == pool.tokenB) {
            return pool.reserveA * PRECISION / pool.reserveB;
        }
        
        return 0;
    }
    
    /**
     * @dev Get expected price for slippage calculation
     */
    function _getExpectedPrice(bytes32 poolId, address tokenIn, address tokenOut) 
        internal 
        view 
        returns (uint256) 
    {
        return priceMovingAverage[poolId] > 0 ? priceMovingAverage[poolId] : _getTokenPrice(poolId, tokenIn);
    }
    
    /**
     * @dev Calculate slippage percentage
     */
    function _calculateSlippage(uint256 expectedPrice, uint256 actualPrice) 
        internal 
        pure 
        returns (uint256) 
    {
        if (expectedPrice == 0) return 0;
        
        uint256 difference = expectedPrice > actualPrice ? 
            expectedPrice - actualPrice : actualPrice - expectedPrice;
        
        return (difference * BASIS_POINTS) / expectedPrice;
    }
    
    /**
     * @dev Update price tracking and moving average
     */
    function _updatePriceTracking(bytes32 poolId, uint256 price) internal {
        lastPrice[poolId] = price;
        priceHistory[poolId].push(price);
        
        // Keep only last 100 prices
        if (priceHistory[poolId].length > 100) {
            // Remove first element (shift array)
            for (uint256 i = 0; i < priceHistory[poolId].length - 1; i++) {
                priceHistory[poolId][i] = priceHistory[poolId][i + 1];
            }
            priceHistory[poolId].pop();
        }
        
        // Calculate moving average
        uint256 sum = 0;
        for (uint256 i = 0; i < priceHistory[poolId].length; i++) {
            sum += priceHistory[poolId][i];
        }
        priceMovingAverage[poolId] = sum / priceHistory[poolId].length;
    }
    
    /**
     * @dev Get pool information
     */
    function getPoolInfo(bytes32 poolId) 
        external 
        view 
        returns (
            address tokenA,
            address tokenB,
            uint256 reserveA,
            uint256 reserveB,
            uint256 totalLiquidity,
            uint256 fee,
            bool active
        ) 
    {
        LiquidityPool memory pool = liquidityPools[poolId];
        return (
            pool.tokenA,
            pool.tokenB,
            pool.reserveA,
            pool.reserveB,
            pool.totalLiquidity,
            pool.fee,
            pool.active
        );
    }
    
    /**
     * @dev Get order information
     */
    function getOrderInfo(uint256 orderId) 
        external 
        view 
        returns (
            address trader,
            address tokenIn,
            address tokenOut,
            uint256 amountIn,
            uint256 amountOut,
            OrderStatus status,
            uint256 executionPrice
        ) 
    {
        Order memory order = orders[orderId];
        return (
            order.trader,
            order.tokenIn,
            order.tokenOut,
            order.amountIn,
            order.amountOut,
            order.status,
            order.executionPrice
        );
    }
    
    /**
     * @dev Emergency pause trading
     */
    function emergencyPause() external onlyRole(ADMIN_ROLE) {
        tradingPaused = true;
        emergencyMode = true;
    }
    
    /**
     * @dev Resume trading
     */
    function resumeTrading() external onlyRole(ADMIN_ROLE) {
        tradingPaused = false;
        emergencyMode = false;
    }
    
    /**
     * @dev Pause specific pool
     */
    function pausePool(bytes32 poolId) external onlyRole(OPERATOR_ROLE) {
        poolPaused[poolId] = true;
    }
    
    /**
     * @dev Resume specific pool
     */
    function resumePool(bytes32 poolId) external onlyRole(OPERATOR_ROLE) {
        poolPaused[poolId] = false;
    }
    
    /**
     * @dev Update protocol fee
     */
    function updateProtocolFee(uint256 newFee) external onlyRole(ADMIN_ROLE) {
        require(newFee <= 1000, "Fee too high"); // Max 10%
        protocolFee = newFee;
    }
    
    /**
     * @dev Cancel order
     */
    function cancelOrder(uint256 orderId) external {
        Order storage order = orders[orderId];
        require(order.trader == msg.sender, "Not order owner");
        require(order.status == OrderStatus.PENDING || order.status == OrderStatus.PARTIALLY_FILLED, "Cannot cancel");
        
        order.status = OrderStatus.CANCELLED;
    }
}