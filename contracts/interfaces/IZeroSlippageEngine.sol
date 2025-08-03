// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IZeroSlippageEngine
 * @dev Interface for the Zero Slippage Engine contract
 * @author CoreLiquid Protocol
 */
interface IZeroSlippageEngine {
    // Events
    event ZeroSlippageTradeExecuted(
        bytes32 indexed tradeId,
        address indexed user,
        address indexed tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        uint256 guaranteedRate,
        uint256 timestamp
    );
    
    event SlippageProtectionActivated(
        bytes32 indexed tradeId,
        address indexed user,
        uint256 protectedAmount,
        uint256 compensationPaid,
        uint256 timestamp
    );
    
    event LiquidityBufferUpdated(
        address indexed token,
        uint256 oldBuffer,
        uint256 newBuffer,
        uint256 timestamp
    );
    
    event PriceOracleUpdated(
        address indexed token,
        address indexed oldOracle,
        address indexed newOracle,
        uint256 timestamp
    );
    
    event ArbitrageOpportunityDetected(
        address indexed tokenA,
        address indexed tokenB,
        uint256 priceDifference,
        uint256 potentialProfit,
        uint256 timestamp
    );
    
    event ArbitrageExecuted(
        bytes32 indexed arbitrageId,
        address indexed tokenA,
        address indexed tokenB,
        uint256 profit,
        uint256 timestamp
    );
    
    event EmergencySlippageProtection(
        address indexed token,
        uint256 maxSlippage,
        string reason,
        uint256 timestamp
    );
    
    event RebalanceExecuted(
        address indexed token,
        uint256 rebalancedAmount,
        uint256 newBufferLevel,
        uint256 timestamp
    );

    // Structs
    struct TradeRequest {
        bytes32 tradeId;
        address user;
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 minAmountOut;
        uint256 guaranteedRate;
        uint256 deadline;
        bool useSlippageProtection;
        bytes routeData;
    }
    
    struct TradeExecution {
        bytes32 tradeId;
        uint256 amountIn;
        uint256 amountOut;
        uint256 actualRate;
        uint256 guaranteedRate;
        uint256 slippage;
        uint256 protectionUsed;
        uint256 gasUsed;
        uint256 executedAt;
        bool isSuccessful;
        string failureReason;
    }
    
    struct SlippageProtection {
        address token;
        uint256 maxSlippage;
        uint256 bufferAmount;
        uint256 protectionFee;
        uint256 compensationPool;
        uint256 lastUpdate;
        bool isActive;
        bool emergencyMode;
    }
    
    struct LiquidityBuffer {
        address token;
        uint256 totalBuffer;
        uint256 availableBuffer;
        uint256 utilizedBuffer;
        uint256 targetBuffer;
        uint256 minBuffer;
        uint256 maxBuffer;
        uint256 rebalanceThreshold;
        uint256 lastRebalance;
        bool isActive;
    }
    
    struct PriceOracle {
        address token;
        address oracleAddress;
        uint256 price;
        uint256 lastUpdate;
        uint256 updateFrequency;
        uint256 priceDeviation;
        bool isActive;
        bool isReliable;
    }
    
    struct ArbitrageOpportunity {
        bytes32 opportunityId;
        address tokenA;
        address tokenB;
        uint256 priceA;
        uint256 priceB;
        uint256 priceDifference;
        uint256 potentialProfit;
        uint256 requiredCapital;
        uint256 detectedAt;
        uint256 expiresAt;
        bool isActive;
        bool isExecuted;
    }
    
    struct ZeroSlippageConfig {
        uint256 maxSlippageTolerance;
        uint256 bufferUtilizationLimit;
        uint256 rebalanceFrequency;
        uint256 protectionFeeRate;
        uint256 emergencyThreshold;
        bool autoRebalance;
        bool emergencyMode;
        uint256 lastConfigUpdate;
    }
    
    struct TradeMetrics {
        uint256 totalTrades;
        uint256 successfulTrades;
        uint256 totalVolume;
        uint256 totalSlippageSaved;
        uint256 totalProtectionUsed;
        uint256 averageSlippage;
        uint256 averageExecutionTime;
        uint256 lastMetricsUpdate;
    }

    // Core trading functions
    function executeZeroSlippageTrade(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        uint256 deadline
    ) external returns (bytes32 tradeId, uint256 amountOut);
    
    function executeTradeWithProtection(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 guaranteedRate,
        uint256 deadline
    ) external returns (bytes32 tradeId, uint256 amountOut);
    
    function batchExecuteTrades(
        TradeRequest[] calldata trades
    ) external returns (bytes32[] memory tradeIds, uint256[] memory amountsOut);
    
    function cancelTrade(
        bytes32 tradeId,
        string calldata reason
    ) external;
    
    function retryFailedTrade(
        bytes32 tradeId
    ) external returns (bool success);
    
    // Advanced trading functions
    function executeArbitrageTrade(
        address tokenA,
        address tokenB,
        uint256 amount,
        bytes calldata arbitrageData
    ) external returns (uint256 profit);
    
    function executeFlashSwap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        bytes calldata swapData
    ) external returns (uint256 amountOut);
    
    function executeCrossProtocolSwap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        string calldata sourceProtocol,
        string calldata targetProtocol
    ) external returns (uint256 amountOut);
    
    // Slippage protection functions
    function activateSlippageProtection(
        address token,
        uint256 maxSlippage,
        uint256 bufferAmount
    ) external;
    
    function deactivateSlippageProtection(
        address token
    ) external;
    
    function updateSlippageProtection(
        address token,
        uint256 newMaxSlippage,
        uint256 newBufferAmount
    ) external;
    
    function claimSlippageCompensation(
        bytes32 tradeId
    ) external returns (uint256 compensation);
    
    function addToCompensationPool(
        address token,
        uint256 amount
    ) external;
    
    // Buffer management
    function addLiquidityBuffer(
        address token,
        uint256 amount
    ) external;
    
    function removeLiquidityBuffer(
        address token,
        uint256 amount
    ) external;
    
    function rebalanceBuffer(
        address token
    ) external returns (uint256 rebalancedAmount);
    
    function rebalanceAllBuffers() external returns (uint256 totalRebalanced);
    
    function setBufferTargets(
        address token,
        uint256 targetBuffer,
        uint256 minBuffer,
        uint256 maxBuffer
    ) external;
    
    // Oracle management
    function addPriceOracle(
        address token,
        address oracle,
        uint256 updateFrequency
    ) external;
    
    function removePriceOracle(
        address token
    ) external;
    
    function updatePriceOracle(
        address token,
        address newOracle
    ) external;
    
    function updatePrice(
        address token
    ) external returns (uint256 newPrice);
    
    function updateAllPrices() external;
    
    // Arbitrage functions
    function detectArbitrageOpportunities() external returns (bytes32[] memory opportunityIds);
    
    function executeArbitrageOpportunity(
        bytes32 opportunityId
    ) external returns (uint256 profit);
    
    function addArbitrageStrategy(
        address tokenA,
        address tokenB,
        uint256 minProfitThreshold,
        bytes calldata strategyData
    ) external;
    
    function removeArbitrageStrategy(
        address tokenA,
        address tokenB
    ) external;
    
    // Configuration functions
    function setZeroSlippageConfig(
        uint256 maxSlippageTolerance,
        uint256 bufferUtilizationLimit,
        uint256 rebalanceFrequency,
        uint256 protectionFeeRate,
        bool autoRebalance
    ) external;
    
    function setEmergencyMode(
        bool enabled,
        string calldata reason
    ) external;
    
    function setProtectionFee(
        uint256 newFeeRate
    ) external;
    
    function setRebalanceThreshold(
        address token,
        uint256 threshold
    ) external;
    
    // Emergency functions
    function emergencyPause(
        string calldata reason
    ) external;
    
    function emergencyUnpause() external;
    
    function emergencyWithdrawBuffer(
        address token,
        uint256 amount,
        address to
    ) external;
    
    function emergencySetSlippage(
        address token,
        uint256 maxSlippage,
        string calldata reason
    ) external;
    
    // View functions - Trade information
    function getTradeRequest(
        bytes32 tradeId
    ) external view returns (TradeRequest memory);
    
    function getTradeExecution(
        bytes32 tradeId
    ) external view returns (TradeExecution memory);
    
    function getTradeStatus(
        bytes32 tradeId
    ) external view returns (string memory status);
    
    function getUserTrades(
        address user
    ) external view returns (bytes32[] memory);
    
    function getPendingTrades(
        address user
    ) external view returns (bytes32[] memory);
    
    // View functions - Slippage protection
    function getSlippageProtection(
        address token
    ) external view returns (SlippageProtection memory);
    
    function isSlippageProtectionActive(
        address token
    ) external view returns (bool);
    
    function getProtectionCoverage(
        address token,
        uint256 amount
    ) external view returns (uint256 coverage);
    
    function getCompensationPool(
        address token
    ) external view returns (uint256 poolSize);
    
    // View functions - Buffer information
    function getLiquidityBuffer(
        address token
    ) external view returns (LiquidityBuffer memory);
    
    function getBufferUtilization(
        address token
    ) external view returns (uint256 utilization);
    
    function getAvailableBuffer(
        address token
    ) external view returns (uint256 available);
    
    function needsRebalancing(
        address token
    ) external view returns (bool);
    
    function getAllBuffers() external view returns (LiquidityBuffer[] memory);
    
    // View functions - Price and oracle
    function getPriceOracle(
        address token
    ) external view returns (PriceOracle memory);
    
    function getCurrentPrice(
        address token
    ) external view returns (uint256 price);
    
    function getPriceDeviation(
        address token
    ) external view returns (uint256 deviation);
    
    function isPriceReliable(
        address token
    ) external view returns (bool);
    
    function getExchangeRate(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external view returns (uint256 amountOut);
    
    // View functions - Arbitrage
    function getArbitrageOpportunity(
        bytes32 opportunityId
    ) external view returns (ArbitrageOpportunity memory);
    
    function getActiveOpportunities() external view returns (ArbitrageOpportunity[] memory);
    
    function getArbitragePotential(
        address tokenA,
        address tokenB
    ) external view returns (uint256 potential);
    
    function isArbitrageOpportunity(
        address tokenA,
        address tokenB,
        uint256 minProfit
    ) external view returns (bool);
    
    // View functions - Calculations
    function calculateZeroSlippageOutput(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external view returns (uint256 amountOut, uint256 guaranteedRate);
    
    function calculateSlippageProtectionCost(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 guaranteedRate
    ) external view returns (uint256 protectionCost);
    
    function calculateOptimalRoute(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external view returns (
        address[] memory path,
        uint256 expectedOutput,
        uint256 slippage
    );
    
    function estimateGasCost(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external view returns (uint256 gasCost);
    
    // View functions - Metrics and statistics
    function getTradeMetrics() external view returns (TradeMetrics memory);
    
    function getTokenMetrics(
        address token
    ) external view returns (
        uint256 totalVolume,
        uint256 totalTrades,
        uint256 averageSlippage,
        uint256 protectionUsage
    );
    
    function getUserMetrics(
        address user
    ) external view returns (
        uint256 totalTrades,
        uint256 totalVolume,
        uint256 slippageSaved,
        uint256 protectionUsed
    );
    
    function getGlobalMetrics() external view returns (
        uint256 totalVolume,
        uint256 totalTrades,
        uint256 totalSlippageSaved,
        uint256 averageExecutionTime
    );
    
    // View functions - Configuration
    function getZeroSlippageConfig() external view returns (ZeroSlippageConfig memory);
    
    function getProtectionFeeRate() external view returns (uint256);
    
    function getMaxSlippageTolerance() external view returns (uint256);
    
    function isEmergencyMode() external view returns (bool);
    
    function isAutoRebalanceEnabled() external view returns (bool);
    
    // View functions - Capacity and limits
    function canExecuteTrade(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external view returns (bool);
    
    function getMaxTradeSize(
        address tokenIn,
        address tokenOut
    ) external view returns (uint256);
    
    function getMinTradeSize(
        address tokenIn,
        address tokenOut
    ) external view returns (uint256);
    
    function hasEnoughBuffer(
        address token,
        uint256 amount
    ) external view returns (bool);
    
    // View functions - Supported tokens
    function getSupportedTokens() external view returns (address[] memory);
    
    function isTokenSupported(
        address token
    ) external view returns (bool);
    
    function getTokenPairs() external view returns (
        address[] memory tokensIn,
        address[] memory tokensOut
    );
    
    function isPairSupported(
        address tokenIn,
        address tokenOut
    ) external view returns (bool);
    
    // View functions - Health checks
    function isSystemHealthy() external view returns (bool);
    
    function getSystemHealth() external view returns (
        bool isHealthy,
        uint256 bufferHealth,
        uint256 oracleHealth,
        uint256 liquidityHealth
    );
    
    function isTokenHealthy(
        address token
    ) external view returns (bool);
    
    function getTokenHealth(
        address token
    ) external view returns (
        bool isHealthy,
        uint256 bufferLevel,
        uint256 priceStability,
        uint256 liquidityDepth
    );
}
