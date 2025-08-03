// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IIntelligentLiquidityRouter
 * @dev Interface for the Intelligent Liquidity Router contract
 * @author CoreLiquid Protocol
 */
interface IIntelligentLiquidityRouter {
    // Events
    event RouteOptimized(
        bytes32 indexed routeId,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 expectedAmountOut,
        uint256 gasEstimate,
        uint256 timestamp
    );
    
    event RouteExecuted(
        bytes32 indexed routeId,
        address indexed user,
        uint256 amountIn,
        uint256 amountOut,
        uint256 gasUsed,
        uint256 slippage,
        uint256 timestamp
    );
    
    event ProtocolAdded(
        string indexed protocolName,
        address indexed protocolAddress,
        address indexed adapter,
        uint256 timestamp
    );
    
    event ProtocolRemoved(
        string indexed protocolName,
        address indexed protocolAddress,
        uint256 timestamp
    );
    
    event LiquiditySourceUpdated(
        string indexed protocolName,
        address indexed tokenPair,
        uint256 liquidity,
        uint256 price,
        uint256 timestamp
    );
    
    event ArbitrageOpportunityDetected(
        address indexed tokenA,
        address indexed tokenB,
        string protocolA,
        string protocolB,
        uint256 priceDifference,
        uint256 timestamp
    );
    
    event SmartOrderExecuted(
        bytes32 indexed orderId,
        address indexed user,
        address indexed tokenIn,
        address tokenOut,
        uint256 totalAmount,
        uint256 averagePrice,
        uint256 timestamp
    );
    
    event RebalanceExecuted(
        address indexed tokenPair,
        uint256 rebalancedAmount,
        uint256 newEfficiency,
        uint256 timestamp
    );

    // Structs
    struct Route {
        bytes32 routeId;
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 expectedAmountOut;
        uint256 minAmountOut;
        uint256 gasEstimate;
        uint256 priceImpact;
        uint256 slippageTolerance;
        RouteStep[] steps;
        uint256 createdAt;
        uint256 expiresAt;
        bool isOptimal;
        bool isExecuted;
    }
    
    struct RouteStep {
        string protocolName;
        address protocolAddress;
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 expectedAmountOut;
        uint256 fee;
        uint256 gasEstimate;
        bytes swapData;
    }
    
    struct LiquiditySource {
        string protocolName;
        address protocolAddress;
        address adapter;
        address tokenA;
        address tokenB;
        uint256 reserveA;
        uint256 reserveB;
        uint256 liquidity;
        uint256 fee;
        uint256 price;
        uint256 priceImpact;
        uint256 lastUpdate;
        bool isActive;
        bool isVerified;
    }
    
    struct ProtocolInfo {
        string name;
        address protocolAddress;
        address adapter;
        uint256 totalLiquidity;
        uint256 totalVolume;
        uint256 averageFee;
        uint256 averageSlippage;
        uint256 reliability;
        uint256 gasEfficiency;
        bool isActive;
        bool isVerified;
        string[] supportedTokens;
        uint256 lastUpdate;
    }
    
    struct SmartOrder {
        bytes32 orderId;
        address user;
        address tokenIn;
        address tokenOut;
        uint256 totalAmount;
        uint256 executedAmount;
        uint256 remainingAmount;
        uint256 averagePrice;
        uint256 maxSlippage;
        uint256 deadline;
        OrderType orderType;
        OrderStatus status;
        RouteStep[] executionSteps;
        uint256 createdAt;
        uint256 lastExecutionAt;
    }
    
    struct ArbitrageOpportunity {
        bytes32 opportunityId;
        address tokenA;
        address tokenB;
        string protocolA;
        string protocolB;
        uint256 priceA;
        uint256 priceB;
        uint256 priceDifference;
        uint256 potentialProfit;
        uint256 requiredCapital;
        uint256 gasEstimate;
        uint256 detectedAt;
        uint256 expiresAt;
        bool isActive;
        bool isProfitable;
    }
    
    struct RoutingConfig {
        uint256 maxHops;
        uint256 maxSlippage;
        uint256 gasLimit;
        uint256 priceImpactThreshold;
        uint256 routeExpiryTime;
        uint256 minLiquidityThreshold;
        bool enableArbitrage;
        bool enableSmartOrders;
        uint256 lastUpdate;
    }
    
    struct PerformanceMetrics {
        uint256 totalRoutes;
        uint256 successfulRoutes;
        uint256 totalVolume;
        uint256 totalGasSaved;
        uint256 averageSlippage;
        uint256 averageExecutionTime;
        uint256 arbitrageProfits;
        uint256 lastUpdate;
    }

    // Enums
    enum OrderType {
        MARKET,
        LIMIT,
        STOP_LOSS,
        TAKE_PROFIT,
        TWAP,
        VWAP
    }
    
    enum OrderStatus {
        PENDING,
        PARTIALLY_FILLED,
        FILLED,
        CANCELLED,
        EXPIRED
    }

    // Core routing functions
    function findOptimalRoute(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 maxSlippage
    ) external view returns (Route memory optimalRoute);
    
    function executeRoute(
        bytes32 routeId
    ) external returns (uint256 amountOut);
    
    function executeSwap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        uint256 deadline
    ) external returns (uint256 amountOut);
    
    function batchExecuteRoutes(
        bytes32[] calldata routeIds
    ) external returns (uint256[] memory amountsOut);
    
    function cancelRoute(
        bytes32 routeId
    ) external;
    
    // Advanced routing functions
    function findMultiHopRoute(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 maxHops,
        uint256 maxSlippage
    ) external view returns (Route memory);
    
    function findArbitrageRoute(
        address tokenA,
        address tokenB,
        uint256 amount
    ) external view returns (Route memory arbitrageRoute, uint256 expectedProfit);
    
    function executeCrossProtocolSwap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        string[] calldata protocols,
        uint256[] calldata allocations
    ) external returns (uint256 totalAmountOut);
    
    function executeFlashArbitrage(
        address tokenA,
        address tokenB,
        uint256 amount,
        bytes calldata arbitrageData
    ) external returns (uint256 profit);
    
    // Smart order functions
    function createSmartOrder(
        address tokenIn,
        address tokenOut,
        uint256 amount,
        OrderType orderType,
        uint256 targetPrice,
        uint256 maxSlippage,
        uint256 deadline
    ) external returns (bytes32 orderId);
    
    function executeSmartOrder(
        bytes32 orderId,
        uint256 executionAmount
    ) external returns (uint256 amountOut);
    
    function cancelSmartOrder(
        bytes32 orderId
    ) external;
    
    function updateSmartOrder(
        bytes32 orderId,
        uint256 newTargetPrice,
        uint256 newMaxSlippage
    ) external;
    
    // Protocol management
    function addProtocol(
        string calldata protocolName,
        address protocolAddress,
        address adapter,
        string[] calldata supportedTokens
    ) external;
    
    function removeProtocol(
        string calldata protocolName
    ) external;
    
    function updateProtocolAdapter(
        string calldata protocolName,
        address newAdapter
    ) external;
    
    function pauseProtocol(
        string calldata protocolName
    ) external;
    
    function unpauseProtocol(
        string calldata protocolName
    ) external;
    
    function verifyProtocol(
        string calldata protocolName
    ) external;
    
    // Liquidity source management
    function updateLiquiditySource(
        string calldata protocolName,
        address tokenA,
        address tokenB,
        uint256 reserveA,
        uint256 reserveB,
        uint256 fee
    ) external;
    
    function refreshLiquiditySources() external;
    
    function refreshProtocolLiquidity(
        string calldata protocolName
    ) external;
    
    function addLiquiditySource(
        string calldata protocolName,
        address tokenA,
        address tokenB,
        uint256 fee
    ) external;
    
    function removeLiquiditySource(
        string calldata protocolName,
        address tokenA,
        address tokenB
    ) external;
    
    // Arbitrage functions
    function detectArbitrageOpportunities(
        address tokenA,
        address tokenB
    ) external view returns (ArbitrageOpportunity[] memory opportunities);
    
    function executeArbitrageOpportunity(
        bytes32 opportunityId
    ) external returns (uint256 profit);
    
    function calculateArbitrageProfit(
        address tokenA,
        address tokenB,
        uint256 amount,
        string calldata protocolA,
        string calldata protocolB
    ) external view returns (uint256 profit, uint256 gasEstimate);
    
    function isArbitrageProfitable(
        bytes32 opportunityId,
        uint256 minProfitThreshold
    ) external view returns (bool);
    
    // Configuration functions
    function setRoutingConfig(
        uint256 maxHops,
        uint256 maxSlippage,
        uint256 gasLimit,
        uint256 priceImpactThreshold,
        uint256 routeExpiryTime
    ) external;
    
    function setProtocolWeights(
        string[] calldata protocolNames,
        uint256[] calldata weights
    ) external;
    
    function setGasOptimization(
        bool enabled
    ) external;
    
    function setArbitrageEnabled(
        bool enabled
    ) external;
    
    function setMinLiquidityThreshold(
        uint256 threshold
    ) external;
    
    // Emergency functions
    function emergencyPause() external;
    
    function emergencyUnpause() external;
    
    function emergencyWithdraw(
        address token,
        uint256 amount,
        address to
    ) external;
    
    function emergencyStopArbitrage() external;
    
    // View functions - Route information
    function getRoute(
        bytes32 routeId
    ) external view returns (Route memory);
    
    function getRouteStatus(
        bytes32 routeId
    ) external view returns (string memory status);
    
    function getUserRoutes(
        address user
    ) external view returns (bytes32[] memory);
    
    function getActiveRoutes() external view returns (bytes32[] memory);
    
    function isRouteValid(
        bytes32 routeId
    ) external view returns (bool);
    
    // View functions - Protocol information
    function getProtocolInfo(
        string calldata protocolName
    ) external view returns (ProtocolInfo memory);
    
    function getSupportedProtocols() external view returns (string[] memory);
    
    function getActiveProtocols() external view returns (string[] memory);
    
    function isProtocolSupported(
        string calldata protocolName
    ) external view returns (bool);
    
    function getProtocolLiquidity(
        string calldata protocolName,
        address tokenA,
        address tokenB
    ) external view returns (uint256 liquidity);
    
    // View functions - Liquidity sources
    function getLiquiditySource(
        string calldata protocolName,
        address tokenA,
        address tokenB
    ) external view returns (LiquiditySource memory);
    
    function getAllLiquiditySources(
        address tokenA,
        address tokenB
    ) external view returns (LiquiditySource[] memory);
    
    function getBestLiquiditySource(
        address tokenA,
        address tokenB,
        uint256 amount
    ) external view returns (LiquiditySource memory);
    
    function getTotalLiquidity(
        address tokenA,
        address tokenB
    ) external view returns (uint256);
    
    // View functions - Smart orders
    function getSmartOrder(
        bytes32 orderId
    ) external view returns (SmartOrder memory);
    
    function getUserSmartOrders(
        address user
    ) external view returns (bytes32[] memory);
    
    function getPendingSmartOrders(
        address user
    ) external view returns (bytes32[] memory);
    
    function getExecutableOrders() external view returns (bytes32[] memory);
    
    function isOrderExecutable(
        bytes32 orderId
    ) external view returns (bool);
    
    // View functions - Arbitrage
    function getArbitrageOpportunity(
        bytes32 opportunityId
    ) external view returns (ArbitrageOpportunity memory);
    
    function getActiveArbitrageOpportunities() external view returns (ArbitrageOpportunity[] memory);
    
    function getProfitableOpportunities(
        uint256 minProfitThreshold
    ) external view returns (ArbitrageOpportunity[] memory);
    
    function getArbitragePotential(
        address tokenA,
        address tokenB
    ) external view returns (uint256 maxProfit);
    
    // View functions - Price calculations
    function getPrice(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        string calldata protocol
    ) external view returns (uint256 amountOut);
    
    function getBestPrice(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external view returns (uint256 bestAmountOut, string memory bestProtocol);
    
    function calculatePriceImpact(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        string calldata protocol
    ) external view returns (uint256 priceImpact);
    
    function getAveragePrice(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external view returns (uint256 averagePrice);
    
    // View functions - Gas and fees
    function estimateGasCost(
        bytes32 routeId
    ) external view returns (uint256 gasEstimate);
    
    function calculateTotalFees(
        bytes32 routeId
    ) external view returns (uint256 totalFees);
    
    function getOptimalGasPrice() external view returns (uint256 gasPrice);
    
    function compareGasEfficiency(
        bytes32[] calldata routeIds
    ) external view returns (bytes32 mostEfficientRoute);
    
    // View functions - Performance metrics
    function getPerformanceMetrics() external view returns (PerformanceMetrics memory);
    
    function getProtocolPerformance(
        string calldata protocolName
    ) external view returns (
        uint256 totalVolume,
        uint256 averageSlippage,
        uint256 successRate,
        uint256 gasEfficiency
    );
    
    function getUserPerformance(
        address user
    ) external view returns (
        uint256 totalTrades,
        uint256 totalVolume,
        uint256 averageSlippage,
        uint256 totalGasSaved
    );
    
    function getTokenPairPerformance(
        address tokenA,
        address tokenB
    ) external view returns (
        uint256 totalVolume,
        uint256 averagePrice,
        uint256 priceVolatility,
        uint256 liquidityDepth
    );
    
    // View functions - Configuration
    function getRoutingConfig() external view returns (RoutingConfig memory);
    
    function getProtocolWeights() external view returns (
        string[] memory protocols,
        uint256[] memory weights
    );
    
    function isGasOptimizationEnabled() external view returns (bool);
    
    function isArbitrageEnabled() external view returns (bool);
    
    function getMinLiquidityThreshold() external view returns (uint256);
    
    // View functions - Market analysis
    function getMarketDepth(
        address tokenA,
        address tokenB
    ) external view returns (
        uint256[] memory buyLevels,
        uint256[] memory sellLevels,
        uint256[] memory buyVolumes,
        uint256[] memory sellVolumes
    );
    
    function getSpreadAnalysis(
        address tokenA,
        address tokenB
    ) external view returns (
        uint256 averageSpread,
        uint256 minSpread,
        uint256 maxSpread,
        string memory bestProtocol
    );
    
    function getLiquidityAnalysis(
        address tokenA,
        address tokenB
    ) external view returns (
        uint256 totalLiquidity,
        uint256 averageLiquidity,
        uint256 liquidityConcentration,
        string[] memory topProtocols
    );
    
    // View functions - Capacity and limits
    function getMaxSwapAmount(
        address tokenIn,
        address tokenOut
    ) external view returns (uint256 maxAmount);
    
    function getMinSwapAmount(
        address tokenIn,
        address tokenOut
    ) external view returns (uint256 minAmount);
    
    function canExecuteSwap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external view returns (bool);
    
    function getSwapCapacity(
        address tokenIn,
        address tokenOut,
        string calldata protocol
    ) external view returns (uint256 capacity);
    
    // View functions - Supported tokens
    function getSupportedTokens() external view returns (address[] memory);
    
    function getSupportedTokenPairs() external view returns (
        address[] memory tokensA,
        address[] memory tokensB
    );
    
    function isTokenSupported(
        address token
    ) external view returns (bool);
    
    function isPairSupported(
        address tokenA,
        address tokenB
    ) external view returns (bool);
    
    // View functions - System health
    function isSystemHealthy() external view returns (bool);
    
    function getSystemHealth() external view returns (
        bool isHealthy,
        uint256 liquidityHealth,
        uint256 protocolHealth,
        uint256 performanceHealth
    );
    
    function getProtocolHealth(
        string calldata protocolName
    ) external view returns (
        bool isHealthy,
        uint256 liquidityLevel,
        uint256 reliability,
        uint256 performance
    );
}
