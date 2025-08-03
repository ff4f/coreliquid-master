// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IFlashLoanAggregator
 * @dev Interface for the Flash Loan Aggregator contract
 * @author CoreLiquid Protocol
 */
interface IFlashLoanAggregator {
    // Events
    event FlashLoanExecuted(
        bytes32 indexed loanId,
        address indexed borrower,
        address indexed token,
        uint256 amount,
        uint256 fee,
        string provider,
        uint256 timestamp
    );
    
    event FlashLoanRepaid(
        bytes32 indexed loanId,
        address indexed borrower,
        uint256 repaidAmount,
        uint256 profit,
        uint256 timestamp
    );
    
    event ProviderAdded(
        string indexed providerName,
        address indexed providerAddress,
        address indexed adapter,
        uint256 timestamp
    );
    
    event ProviderRemoved(
        string indexed providerName,
        address indexed providerAddress,
        uint256 timestamp
    );
    
    event LiquidityUpdated(
        string indexed providerName,
        address indexed token,
        uint256 newLiquidity,
        uint256 newFee,
        uint256 timestamp
    );
    
    event ArbitrageExecuted(
        bytes32 indexed arbitrageId,
        address indexed executor,
        address indexed token,
        uint256 amount,
        uint256 profit,
        uint256 timestamp
    );
    
    event BatchFlashLoanExecuted(
        bytes32 indexed batchId,
        address indexed borrower,
        uint256 loanCount,
        uint256 totalAmount,
        uint256 totalFee,
        uint256 timestamp
    );
    
    event FlashLoanFailed(
        bytes32 indexed loanId,
        address indexed borrower,
        string reason,
        uint256 timestamp
    );
    
    event OptimalProviderSelected(
        address indexed token,
        uint256 amount,
        string selectedProvider,
        uint256 fee,
        uint256 timestamp
    );
    
    event FlashLoanRouteOptimized(
        bytes32 indexed routeId,
        address[] tokens,
        uint256[] amounts,
        string[] providers,
        uint256 totalSavings,
        uint256 timestamp
    );
    
    event EmergencyFlashLoanExecuted(
        bytes32 indexed loanId,
        address indexed borrower,
        string reason,
        uint256 amount,
        uint256 timestamp
    );
    
    event FlashLoanLimitUpdated(
        address indexed token,
        uint256 oldLimit,
        uint256 newLimit,
        uint256 timestamp
    );

    // Structs
    struct FlashLoan {
        bytes32 loanId;
        address borrower;
        address token;
        uint256 amount;
        uint256 fee;
        uint256 totalRepayment;
        string provider;
        FlashLoanStatus status;
        uint256 initiatedAt;
        uint256 executedAt;
        uint256 repaidAt;
        bytes callData;
        bool isArbitrage;
        uint256 expectedProfit;
        uint256 actualProfit;
    }
    
    struct FlashLoanProvider {
        string name;
        address providerAddress;
        address adapterAddress;
        uint256 totalLiquidity;
        uint256 availableLiquidity;
        uint256 baseFee;
        uint256 utilizationRate;
        uint256 maxLoanAmount;
        uint256 minLoanAmount;
        bool isActive;
        bool isVerified;
        string[] supportedTokens;
        uint256 successRate;
        uint256 averageExecutionTime;
        uint256 totalLoansExecuted;
        uint256 lastUpdate;
    }
    
    struct FlashLoanOpportunity {
        bytes32 opportunityId;
        address token;
        uint256 amount;
        string bestProvider;
        uint256 lowestFee;
        uint256 availableLiquidity;
        uint256 estimatedProfit;
        uint256 gasEstimate;
        uint256 detectedAt;
        uint256 expiresAt;
        bool isArbitrage;
        bool isProfitable;
    }
    
    struct BatchFlashLoan {
        bytes32 batchId;
        address borrower;
        FlashLoanRequest[] requests;
        uint256 totalAmount;
        uint256 totalFee;
        uint256 expectedProfit;
        uint256 actualProfit;
        BatchStatus status;
        uint256 initiatedAt;
        uint256 executedAt;
        uint256 completedAt;
    }
    
    struct FlashLoanRequest {
        address token;
        uint256 amount;
        string preferredProvider;
        uint256 maxFee;
        bytes callData;
        bool isArbitrage;
    }
    
    struct ArbitrageStrategy {
        bytes32 strategyId;
        string name;
        address[] tokens;
        string[] protocols;
        uint256 minProfitThreshold;
        uint256 maxGasCost;
        uint256 successRate;
        uint256 averageProfit;
        bool isActive;
        uint256 lastExecution;
    }
    
    struct FlashLoanMetrics {
        uint256 totalLoans;
        uint256 successfulLoans;
        uint256 totalVolume;
        uint256 totalFees;
        uint256 totalProfits;
        uint256 averageLoanSize;
        uint256 averageFee;
        uint256 successRate;
        uint256 averageExecutionTime;
        uint256 lastUpdate;
    }
    
    struct ProviderComparison {
        string providerName;
        uint256 fee;
        uint256 availableLiquidity;
        uint256 executionTime;
        uint256 successRate;
        uint256 gasEstimate;
        uint256 score;
        bool isRecommended;
    }
    
    struct FlashLoanRoute {
        bytes32 routeId;
        address[] tokens;
        uint256[] amounts;
        string[] providers;
        uint256[] fees;
        uint256 totalFee;
        uint256 estimatedGas;
        uint256 estimatedProfit;
        bool isOptimal;
        uint256 createdAt;
    }

    // Enums
    enum FlashLoanStatus {
        PENDING,
        EXECUTING,
        COMPLETED,
        FAILED,
        CANCELLED
    }
    
    enum BatchStatus {
        PENDING,
        EXECUTING,
        PARTIALLY_COMPLETED,
        COMPLETED,
        FAILED,
        CANCELLED
    }

    // Core flash loan functions
    function executeFlashLoan(
        address token,
        uint256 amount,
        bytes calldata data
    ) external returns (bytes32 loanId);
    
    function executeFlashLoanWithProvider(
        address token,
        uint256 amount,
        string calldata provider,
        bytes calldata data
    ) external returns (bytes32 loanId);
    
    function repayFlashLoan(
        bytes32 loanId
    ) external returns (bool success);
    
    function cancelFlashLoan(
        bytes32 loanId
    ) external;
    
    function executeOptimalFlashLoan(
        address token,
        uint256 amount,
        uint256 maxFee,
        bytes calldata data
    ) external returns (bytes32 loanId, string memory selectedProvider);
    
    // Batch flash loan functions
    function executeBatchFlashLoan(
        FlashLoanRequest[] calldata requests
    ) external returns (bytes32 batchId);
    
    function executeBatchFlashLoanOptimal(
        FlashLoanRequest[] calldata requests,
        uint256 maxTotalFee
    ) external returns (bytes32 batchId, uint256 totalSavings);
    
    function cancelBatchFlashLoan(
        bytes32 batchId
    ) external;
    
    function repayBatchFlashLoan(
        bytes32 batchId
    ) external returns (bool success);
    
    // Arbitrage functions
    function executeArbitrageFlashLoan(
        address token,
        uint256 amount,
        bytes calldata arbitrageData
    ) external returns (bytes32 loanId, uint256 profit);
    
    function executeMultiTokenArbitrage(
        address[] calldata tokens,
        uint256[] calldata amounts,
        bytes calldata arbitrageData
    ) external returns (bytes32 batchId, uint256 totalProfit);
    
    function findArbitrageOpportunity(
        address tokenA,
        address tokenB,
        uint256 amount
    ) external view returns (
        bool exists,
        uint256 expectedProfit,
        string memory bestProvider
    );
    
    function executeAutoArbitrage(
        bytes32 strategyId,
        uint256 maxAmount
    ) external returns (uint256 profit);
    
    function createArbitrageStrategy(
        string calldata name,
        address[] calldata tokens,
        string[] calldata protocols,
        uint256 minProfitThreshold
    ) external returns (bytes32 strategyId);
    
    // Provider management
    function addProvider(
        string calldata name,
        address providerAddress,
        address adapterAddress,
        string[] calldata supportedTokens
    ) external;
    
    function removeProvider(
        string calldata name
    ) external;
    
    function updateProviderAdapter(
        string calldata name,
        address newAdapterAddress
    ) external;
    
    function pauseProvider(
        string calldata name
    ) external;
    
    function unpauseProvider(
        string calldata name
    ) external;
    
    function verifyProvider(
        string calldata name
    ) external;
    
    function updateProviderLiquidity(
        string calldata name,
        address token,
        uint256 newLiquidity,
        uint256 newFee
    ) external;
    
    // Route optimization
    function findOptimalRoute(
        address[] calldata tokens,
        uint256[] calldata amounts
    ) external view returns (FlashLoanRoute memory optimalRoute);
    
    function executeOptimalRoute(
        bytes32 routeId,
        bytes calldata data
    ) external returns (uint256 totalSavings);
    
    function compareProviders(
        address token,
        uint256 amount
    ) external view returns (ProviderComparison[] memory comparisons);
    
    function optimizeFlashLoanCosts(
        FlashLoanRequest[] calldata requests
    ) external view returns (
        string[] memory optimalProviders,
        uint256 totalOptimizedFee,
        uint256 savings
    );
    
    // Liquidity management
    function refreshProviderLiquidity(
        string calldata providerName
    ) external;
    
    function refreshAllLiquidity() external;
    
    function addLiquiditySource(
        string calldata providerName,
        address token,
        uint256 amount
    ) external;
    
    function removeLiquiditySource(
        string calldata providerName,
        address token,
        uint256 amount
    ) external;
    
    function rebalanceLiquidity(
        address token
    ) external;
    
    // Configuration functions
    function setFlashLoanLimits(
        address token,
        uint256 maxAmount,
        uint256 minAmount
    ) external;
    
    function setGlobalFeeLimit(
        uint256 maxFeePercentage
    ) external;
    
    function setArbitrageEnabled(
        bool enabled
    ) external;
    
    function setAutoOptimization(
        bool enabled
    ) external;
    
    function setEmergencyMode(
        bool enabled
    ) external;
    
    // Emergency functions
    function emergencyPause() external;
    
    function emergencyUnpause() external;
    
    function emergencyRepayLoan(
        bytes32 loanId,
        address repayer
    ) external;
    
    function emergencyWithdraw(
        address token,
        uint256 amount,
        address to
    ) external;
    
    function emergencyStopArbitrage() external;
    
    // View functions - Flash loan information
    function getFlashLoan(
        bytes32 loanId
    ) external view returns (FlashLoan memory);
    
    function getBatchFlashLoan(
        bytes32 batchId
    ) external view returns (BatchFlashLoan memory);
    
    function getUserFlashLoans(
        address user
    ) external view returns (bytes32[] memory);
    
    function getActiveFlashLoans() external view returns (bytes32[] memory);
    
    function getFlashLoanStatus(
        bytes32 loanId
    ) external view returns (FlashLoanStatus);
    
    // View functions - Provider information
    function getProvider(
        string calldata name
    ) external view returns (FlashLoanProvider memory);
    
    function getAllProviders() external view returns (string[] memory);
    
    function getActiveProviders() external view returns (string[] memory);
    
    function getProviderLiquidity(
        string calldata name,
        address token
    ) external view returns (uint256 available, uint256 total);
    
    function getBestProvider(
        address token,
        uint256 amount
    ) external view returns (string memory providerName, uint256 fee);
    
    // View functions - Fee calculations
    function calculateFlashLoanFee(
        address token,
        uint256 amount,
        string calldata provider
    ) external view returns (uint256 fee);
    
    function getLowestFee(
        address token,
        uint256 amount
    ) external view returns (uint256 lowestFee, string memory provider);
    
    function calculateBatchFee(
        FlashLoanRequest[] calldata requests
    ) external view returns (uint256 totalFee, string[] memory providers);
    
    function estimateArbitrageFee(
        address[] calldata tokens,
        uint256[] calldata amounts
    ) external view returns (uint256 totalFee, uint256 estimatedProfit);
    
    function compareAllFees(
        address token,
        uint256 amount
    ) external view returns (
        string[] memory providers,
        uint256[] memory fees
    );
    
    // View functions - Liquidity information
    function getTotalLiquidity(
        address token
    ) external view returns (uint256 totalLiquidity);
    
    function getAvailableLiquidity(
        address token
    ) external view returns (uint256 availableLiquidity);
    
    function getProviderUtilization(
        string calldata providerName
    ) external view returns (uint256 utilizationRate);
    
    function getLiquidityDistribution(
        address token
    ) external view returns (
        string[] memory providers,
        uint256[] memory liquidities
    );
    
    function getMaxFlashLoanAmount(
        address token
    ) external view returns (uint256 maxAmount);
    
    // View functions - Arbitrage information
    function getArbitrageStrategy(
        bytes32 strategyId
    ) external view returns (ArbitrageStrategy memory);
    
    function getUserArbitrageStrategies(
        address user
    ) external view returns (bytes32[] memory);
    
    function getActiveArbitrageOpportunities() external view returns (
        FlashLoanOpportunity[] memory opportunities
    );
    
    function getProfitableOpportunities(
        uint256 minProfit
    ) external view returns (FlashLoanOpportunity[] memory);
    
    function calculateArbitrageProfit(
        address tokenA,
        address tokenB,
        uint256 amount,
        string calldata protocolA,
        string calldata protocolB
    ) external view returns (uint256 profit, uint256 gasEstimate);
    
    // View functions - Route optimization
    function getFlashLoanRoute(
        bytes32 routeId
    ) external view returns (FlashLoanRoute memory);
    
    function getOptimalRoutes(
        address[] calldata tokens,
        uint256[] calldata amounts
    ) external view returns (FlashLoanRoute[] memory routes);
    
    function calculateRouteSavings(
        bytes32 routeId,
        FlashLoanRequest[] calldata requests
    ) external view returns (uint256 savings);
    
    function isRouteOptimal(
        bytes32 routeId
    ) external view returns (bool);
    
    // View functions - Performance metrics
    function getFlashLoanMetrics() external view returns (FlashLoanMetrics memory);
    
    function getProviderMetrics(
        string calldata providerName
    ) external view returns (
        uint256 totalLoans,
        uint256 totalVolume,
        uint256 successRate,
        uint256 averageFee
    );
    
    function getUserMetrics(
        address user
    ) external view returns (
        uint256 totalLoans,
        uint256 totalVolume,
        uint256 totalProfits,
        uint256 successRate
    );
    
    function getArbitrageMetrics() external view returns (
        uint256 totalArbitrages,
        uint256 totalProfits,
        uint256 successRate,
        uint256 averageProfit
    );
    
    function getTokenMetrics(
        address token
    ) external view returns (
        uint256 totalLoans,
        uint256 totalVolume,
        uint256 averageFee,
        uint256 totalLiquidity
    );
    
    // View functions - Capacity and limits
    function canExecuteFlashLoan(
        address token,
        uint256 amount
    ) external view returns (bool);
    
    function getFlashLoanLimits(
        address token
    ) external view returns (uint256 maxAmount, uint256 minAmount);
    
    function getRemainingCapacity(
        address token,
        string calldata provider
    ) external view returns (uint256 capacity);
    
    function isAmountSupported(
        address token,
        uint256 amount,
        string calldata provider
    ) external view returns (bool);
    
    function getGlobalLimits() external view returns (
        uint256 maxFeePercentage,
        uint256 maxLoanAmount,
        uint256 maxBatchSize
    );
    
    // View functions - Supported tokens
    function getSupportedTokens() external view returns (address[] memory);
    
    function getProviderSupportedTokens(
        string calldata providerName
    ) external view returns (address[] memory);
    
    function isTokenSupported(
        address token
    ) external view returns (bool);
    
    function isTokenSupportedByProvider(
        address token,
        string calldata providerName
    ) external view returns (bool);
    
    function getTokenProviders(
        address token
    ) external view returns (string[] memory);
    
    // View functions - System health
    function isSystemHealthy() external view returns (bool);
    
    function getSystemHealth() external view returns (
        bool isHealthy,
        uint256 liquidityHealth,
        uint256 providerHealth,
        uint256 performanceHealth
    );
    
    function getProviderHealth(
        string calldata providerName
    ) external view returns (
        bool isHealthy,
        uint256 liquidityLevel,
        uint256 successRate,
        uint256 responseTime
    );
    
    function isArbitrageEnabled() external view returns (bool);
    
    function isAutoOptimizationEnabled() external view returns (bool);
    
    function isEmergencyMode() external view returns (bool);
}
