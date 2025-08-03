// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title ILiquidityAggregator
 * @dev Interface for the Liquidity Aggregator contract
 * @author CoreLiquid Protocol
 */
interface ILiquidityAggregator {
    // Events
    event LiquiditySourceAdded(
        bytes32 indexed sourceId,
        address indexed source,
        SourceType sourceType,
        uint256 priority,
        uint256 timestamp
    );
    
    event LiquiditySourceRemoved(
        bytes32 indexed sourceId,
        address indexed source,
        uint256 timestamp
    );
    
    event LiquidityAggregated(
        bytes32 indexed aggregationId,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        uint256 sourceCount,
        uint256 timestamp
    );
    
    event RouteOptimized(
        bytes32 indexed routeId,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        Route[] routes,
        uint256 expectedOutput,
        uint256 timestamp
    );
    
    event SwapExecuted(
        bytes32 indexed swapId,
        address indexed user,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        uint256 slippage,
        uint256 gasUsed,
        uint256 timestamp
    );
    
    event ArbitrageDetected(
        bytes32 indexed arbitrageId,
        address indexed tokenA,
        address indexed tokenB,
        uint256 profitAmount,
        uint256 profitPercentage,
        bytes32[] sources,
        uint256 timestamp
    );
    
    event ArbitrageExecuted(
        bytes32 indexed arbitrageId,
        uint256 actualProfit,
        uint256 gasUsed,
        bool success,
        uint256 timestamp
    );
    
    event LiquidityPoolCreated(
        bytes32 indexed poolId,
        address indexed tokenA,
        address indexed tokenB,
        uint256 amountA,
        uint256 amountB,
        uint256 liquidity,
        uint256 timestamp
    );
    
    event LiquidityAdded(
        bytes32 indexed poolId,
        address indexed provider,
        uint256 amountA,
        uint256 amountB,
        uint256 liquidity,
        uint256 timestamp
    );
    
    event LiquidityRemoved(
        bytes32 indexed poolId,
        address indexed provider,
        uint256 amountA,
        uint256 amountB,
        uint256 liquidity,
        uint256 timestamp
    );
    
    event PriceUpdated(
        address indexed tokenA,
        address indexed tokenB,
        uint256 price,
        bytes32 indexed source,
        uint256 timestamp
    );
    
    event SlippageExceeded(
        bytes32 indexed swapId,
        uint256 expectedSlippage,
        uint256 actualSlippage,
        uint256 timestamp
    );
    
    event RebalanceExecuted(
        bytes32 indexed poolId,
        uint256 oldRatio,
        uint256 newRatio,
        uint256 rebalanceAmount,
        uint256 timestamp
    );

    // Structs
    struct LiquiditySource {
        bytes32 sourceId;
        string name;
        address sourceAddress;
        SourceType sourceType;
        uint256 priority;
        uint256 weight;
        bool isActive;
        SourceConfig config;
        SourceMetrics metrics;
        uint256 createdAt;
        uint256 lastUpdate;
    }
    
    struct SourceConfig {
        uint256 maxSlippage; // Basis points
        uint256 minLiquidity;
        uint256 maxGasPrice;
        uint256 timeout;
        bool allowPartialFills;
        bool requiresApproval;
        address[] supportedTokens;
        uint256 feeRate; // Basis points
    }
    
    struct SourceMetrics {
        uint256 totalVolume;
        uint256 totalTrades;
        uint256 averageSlippage;
        uint256 averageGasUsed;
        uint256 successRate;
        uint256 averageExecutionTime;
        uint256 liquidityScore;
        uint256 reliabilityScore;
        uint256 lastUpdate;
    }
    
    struct Route {
        bytes32 routeId;
        bytes32 sourceId;
        address[] path;
        uint256[] amounts;
        uint256 expectedOutput;
        uint256 estimatedGas;
        uint256 slippage;
        uint256 fee;
        uint256 impact;
        RouteType routeType;
        bytes routeData;
    }
    
    struct SwapParams {
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 minAmountOut;
        uint256 maxSlippage;
        uint256 deadline;
        address recipient;
        bool useOptimalRoute;
        bytes32[] preferredSources;
        bytes32[] excludedSources;
    }
    
    struct SwapResult {
        bytes32 swapId;
        uint256 amountOut;
        uint256 actualSlippage;
        uint256 gasUsed;
        uint256 fee;
        Route[] routesUsed;
        uint256 executionTime;
        bool success;
    }
    
    struct LiquidityPool {
        bytes32 poolId;
        address tokenA;
        address tokenB;
        uint256 reserveA;
        uint256 reserveB;
        uint256 totalLiquidity;
        uint256 feeRate;
        PoolType poolType;
        PoolConfig config;
        PoolMetrics metrics;
        uint256 createdAt;
        uint256 lastUpdate;
        bool isActive;
    }
    
    struct PoolConfig {
        uint256 minLiquidity;
        uint256 maxSlippage;
        uint256 rebalanceThreshold;
        uint256 feeRate;
        bool autoRebalance;
        bool allowFlashLoans;
        uint256 flashLoanFee;
        address[] authorizedRebalancers;
    }
    
    struct PoolMetrics {
        uint256 volume24h;
        uint256 volume7d;
        uint256 volume30d;
        uint256 trades24h;
        uint256 averageTradeSize;
        uint256 totalFees;
        uint256 impermanentLoss;
        uint256 apy;
        uint256 utilization;
        uint256 lastUpdate;
    }
    
    struct LiquidityPosition {
        bytes32 positionId;
        bytes32 poolId;
        address provider;
        uint256 liquidity;
        uint256 amountA;
        uint256 amountB;
        uint256 shares;
        uint256 entryPrice;
        uint256 unrealizedPnL;
        uint256 feesEarned;
        uint256 createdAt;
        uint256 lastUpdate;
    }
    
    struct ArbitrageOpportunity {
        bytes32 opportunityId;
        address tokenA;
        address tokenB;
        bytes32 sourceIdBuy;
        bytes32 sourceIdSell;
        uint256 priceBuy;
        uint256 priceSell;
        uint256 profitAmount;
        uint256 profitPercentage;
        uint256 requiredCapital;
        uint256 estimatedGas;
        uint256 confidence;
        uint256 expiresAt;
        bool isExecutable;
    }
    
    struct PriceQuote {
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 amountOut;
        uint256 price;
        uint256 slippage;
        uint256 impact;
        bytes32 sourceId;
        uint256 timestamp;
        uint256 confidence;
    }
    
    struct AggregationStrategy {
        bytes32 strategyId;
        string name;
        StrategyType strategyType;
        StrategyParams params;
        bool isActive;
        uint256 createdAt;
        address creator;
    }
    
    struct StrategyParams {
        uint256 maxSources;
        uint256 minLiquidity;
        uint256 maxSlippage;
        uint256 gasOptimization;
        bool prioritizeSpeed;
        bool prioritizeCost;
        uint256[] sourceWeights;
        bytes32[] preferredSources;
    }
    
    struct RebalanceParams {
        bytes32 poolId;
        uint256 targetRatio;
        uint256 tolerance;
        uint256 maxSlippage;
        bool useFlashLoan;
        address[] rebalanceTokens;
        uint256[] rebalanceAmounts;
    }
    
    struct FlashLoanParams {
        address asset;
        uint256 amount;
        bytes params;
        address receiver;
        uint256 fee;
    }
    
    struct GasOptimization {
        uint256 maxGasPrice;
        uint256 gasLimit;
        uint256 priorityFee;
        bool useGasToken;
        bool batchTransactions;
        uint256 gasEstimate;
    }

    // Enums
    enum SourceType {
        DEX,
        CEX,
        AMM,
        ORDER_BOOK,
        AGGREGATOR,
        BRIDGE,
        LENDING_POOL,
        FLASH_LOAN_PROVIDER
    }
    
    enum RouteType {
        DIRECT,
        MULTI_HOP,
        SPLIT,
        BRIDGE,
        FLASH_SWAP
    }
    
    enum PoolType {
        CONSTANT_PRODUCT,
        CONSTANT_SUM,
        WEIGHTED,
        STABLE,
        CONCENTRATED,
        CUSTOM
    }
    
    enum StrategyType {
        BEST_PRICE,
        LOWEST_SLIPPAGE,
        FASTEST_EXECUTION,
        LOWEST_GAS,
        BALANCED,
        CUSTOM
    }
    
    enum SwapType {
        EXACT_INPUT,
        EXACT_OUTPUT,
        LIMIT_ORDER,
        MARKET_ORDER
    }

    // Core aggregation functions
    function addLiquiditySource(
        string calldata name,
        address sourceAddress,
        SourceType sourceType,
        uint256 priority,
        SourceConfig calldata config
    ) external returns (bytes32 sourceId);
    
    function removeLiquiditySource(
        bytes32 sourceId
    ) external;
    
    function updateSourceConfig(
        bytes32 sourceId,
        SourceConfig calldata newConfig
    ) external;
    
    function aggregateLiquidity(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external returns (uint256 totalLiquidity, bytes32[] memory sources);
    
    function findOptimalRoute(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 maxSlippage
    ) external returns (Route[] memory routes);
    
    // Swap functions
    function executeSwap(
        SwapParams calldata params
    ) external returns (SwapResult memory result);
    
    function executeMultiSourceSwap(
        SwapParams calldata params,
        bytes32[] calldata sources,
        uint256[] calldata amounts
    ) external returns (SwapResult memory result);
    
    function executeBatchSwap(
        SwapParams[] calldata swaps
    ) external returns (SwapResult[] memory results);
    
    function executeFlashSwap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        bytes calldata data
    ) external returns (uint256 amountOut);
    
    // Quote functions
    function getQuote(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external view returns (PriceQuote memory quote);
    
    function getMultiSourceQuote(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        bytes32[] calldata sources
    ) external view returns (PriceQuote[] memory quotes);
    
    function getBestQuote(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        StrategyType strategy
    ) external view returns (PriceQuote memory bestQuote);
    
    function getAggregatedQuote(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 maxSources
    ) external view returns (PriceQuote memory aggregatedQuote);
    
    // Liquidity pool functions
    function createPool(
        address tokenA,
        address tokenB,
        uint256 amountA,
        uint256 amountB,
        PoolType poolType,
        PoolConfig calldata config
    ) external returns (bytes32 poolId);
    
    function addLiquidity(
        bytes32 poolId,
        uint256 amountA,
        uint256 amountB,
        uint256 minLiquidity
    ) external returns (uint256 liquidity);
    
    function removeLiquidity(
        bytes32 poolId,
        uint256 liquidity,
        uint256 minAmountA,
        uint256 minAmountB
    ) external returns (uint256 amountA, uint256 amountB);
    
    function rebalancePool(
        bytes32 poolId,
        RebalanceParams calldata params
    ) external returns (bool success);
    
    // Arbitrage functions
    function findArbitrageOpportunities(
        address tokenA,
        address tokenB,
        uint256 minProfit
    ) external view returns (ArbitrageOpportunity[] memory opportunities);
    
    function executeArbitrage(
        bytes32 opportunityId,
        uint256 amount,
        uint256 maxSlippage
    ) external returns (uint256 profit);
    
    function simulateArbitrage(
        bytes32 opportunityId,
        uint256 amount
    ) external view returns (uint256 expectedProfit, uint256 risk);
    
    function batchArbitrage(
        bytes32[] calldata opportunityIds,
        uint256[] calldata amounts
    ) external returns (uint256 totalProfit);
    
    // Flash loan functions
    function flashLoan(
        FlashLoanParams calldata params
    ) external returns (bool success);
    
    function getFlashLoanFee(
        address asset,
        uint256 amount
    ) external view returns (uint256 fee);
    
    function getMaxFlashLoan(
        address asset
    ) external view returns (uint256 maxAmount);
    
    // Strategy functions
    function createStrategy(
        string calldata name,
        StrategyType strategyType,
        StrategyParams calldata params
    ) external returns (bytes32 strategyId);
    
    function updateStrategy(
        bytes32 strategyId,
        StrategyParams calldata params
    ) external;
    
    function executeStrategy(
        bytes32 strategyId,
        SwapParams calldata swapParams
    ) external returns (SwapResult memory result);
    
    function optimizeStrategy(
        bytes32 strategyId
    ) external returns (bool success);
    
    // Price oracle functions
    function updatePrice(
        address tokenA,
        address tokenB,
        uint256 price,
        bytes32 sourceId
    ) external;
    
    function getPrice(
        address tokenA,
        address tokenB
    ) external view returns (uint256 price, uint256 timestamp);
    
    function getWeightedPrice(
        address tokenA,
        address tokenB,
        bytes32[] calldata sources
    ) external view returns (uint256 weightedPrice);
    
    function getTWAP(
        address tokenA,
        address tokenB,
        uint256 timeWindow
    ) external view returns (uint256 twap);
    
    // Gas optimization functions
    function optimizeGas(
        SwapParams calldata params
    ) external view returns (GasOptimization memory optimization);
    
    function batchOptimize(
        SwapParams[] calldata swaps
    ) external view returns (SwapParams[] memory optimizedSwaps);
    
    function estimateGas(
        SwapParams calldata params
    ) external view returns (uint256 gasEstimate);
    
    // Configuration functions
    function setGlobalSlippageTolerance(
        uint256 slippage
    ) external;
    
    function setGlobalGasLimit(
        uint256 gasLimit
    ) external;
    
    function setSourceWeight(
        bytes32 sourceId,
        uint256 weight
    ) external;
    
    function setSourcePriority(
        bytes32 sourceId,
        uint256 priority
    ) external;
    
    function pauseSource(
        bytes32 sourceId
    ) external;
    
    function unpauseSource(
        bytes32 sourceId
    ) external;
    
    // Emergency functions
    function emergencyPause() external;
    
    function emergencyUnpause() external;
    
    function emergencyWithdraw(
        address token,
        uint256 amount
    ) external;
    
    function forceRebalance(
        bytes32 poolId
    ) external;
    
    function emergencyStopArbitrage() external;
    
    // View functions - Sources
    function getLiquiditySource(
        bytes32 sourceId
    ) external view returns (LiquiditySource memory);
    
    function getAllSources() external view returns (bytes32[] memory);
    
    function getActiveSources() external view returns (bytes32[] memory);
    
    function getSourcesByType(
        SourceType sourceType
    ) external view returns (bytes32[] memory);
    
    function getSourceMetrics(
        bytes32 sourceId
    ) external view returns (SourceMetrics memory);
    
    function getSourceLiquidity(
        bytes32 sourceId,
        address tokenA,
        address tokenB
    ) external view returns (uint256 liquidity);
    
    // View functions - Pools
    function getPool(
        bytes32 poolId
    ) external view returns (LiquidityPool memory);
    
    function getAllPools() external view returns (bytes32[] memory);
    
    function getPoolsByTokens(
        address tokenA,
        address tokenB
    ) external view returns (bytes32[] memory);
    
    function getPoolMetrics(
        bytes32 poolId
    ) external view returns (PoolMetrics memory);
    
    function getPoolReserves(
        bytes32 poolId
    ) external view returns (uint256 reserveA, uint256 reserveB);
    
    function getPoolPrice(
        bytes32 poolId
    ) external view returns (uint256 price);
    
    function getUserLiquidityPositions(
        address user
    ) external view returns (bytes32[] memory);
    
    function getLiquidityPosition(
        bytes32 positionId
    ) external view returns (LiquidityPosition memory);
    
    // View functions - Routes and swaps
    function getRoute(
        bytes32 routeId
    ) external view returns (Route memory);
    
    function getSwapHistory(
        address user,
        uint256 limit
    ) external view returns (bytes32[] memory);
    
    function getSwapResult(
        bytes32 swapId
    ) external view returns (SwapResult memory);
    
    function getOptimalRoutes(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 maxRoutes
    ) external view returns (Route[] memory);
    
    // View functions - Arbitrage
    function getArbitrageOpportunity(
        bytes32 opportunityId
    ) external view returns (ArbitrageOpportunity memory);
    
    function getActiveArbitrageOpportunities(
        uint256 limit
    ) external view returns (bytes32[] memory);
    
    function getArbitrageHistory(
        uint256 limit
    ) external view returns (bytes32[] memory);
    
    function getArbitrageProfitability(
        address tokenA,
        address tokenB
    ) external view returns (uint256 maxProfit, uint256 confidence);
    
    // View functions - Strategies
    function getStrategy(
        bytes32 strategyId
    ) external view returns (AggregationStrategy memory);
    
    function getAllStrategies() external view returns (bytes32[] memory);
    
    function getStrategyPerformance(
        bytes32 strategyId
    ) external view returns (uint256 totalVolume, uint256 averageSlippage, uint256 successRate);
    
    // View functions - Analytics
    function getTotalVolume(
        uint256 timeframe
    ) external view returns (uint256 volume);
    
    function getTotalLiquidity() external view returns (uint256 liquidity);
    
    function getAverageSlippage(
        uint256 timeframe
    ) external view returns (uint256 slippage);
    
    function getSourceDistribution() external view returns (
        bytes32[] memory sources,
        uint256[] memory volumes
    );
    
    function getTokenPairVolume(
        address tokenA,
        address tokenB,
        uint256 timeframe
    ) external view returns (uint256 volume);
    
    function getSystemHealth() external view returns (
        bool isHealthy,
        uint256 activeSources,
        uint256 totalLiquidity,
        uint256 averageSlippage
    );
    
    function getGasMetrics() external view returns (
        uint256 averageGasUsed,
        uint256 averageGasPrice,
        uint256 totalGasOptimized
    );
}
