// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IFlashLoanProvider
 * @dev Interface for the Flash Loan Provider contract
 * @author CoreLiquid Protocol
 */
interface IFlashLoanProvider {
    // Events
    event FlashLoanExecuted(
        bytes32 indexed loanId,
        address indexed borrower,
        address indexed asset,
        uint256 amount,
        uint256 fee,
        uint256 timestamp
    );
    
    event FlashLoanInitiated(
        bytes32 indexed loanId,
        address indexed borrower,
        address indexed asset,
        uint256 amount,
        uint256 fee,
        address target,
        bytes data
    );
    
    event FlashLoanRepaid(
        bytes32 indexed loanId,
        address indexed borrower,
        uint256 amountRepaid,
        uint256 feesPaid,
        uint256 timestamp
    );
    
    event FlashLoanDefaulted(
        bytes32 indexed loanId,
        address indexed borrower,
        uint256 amountOwed,
        uint256 timestamp
    );
    
    event LiquidityAdded(
        address indexed provider,
        address indexed asset,
        uint256 amount,
        uint256 shares,
        uint256 timestamp
    );
    
    event LiquidityRemoved(
        address indexed provider,
        address indexed asset,
        uint256 amount,
        uint256 shares,
        uint256 timestamp
    );
    
    event FeeUpdated(
        address indexed asset,
        uint256 oldFee,
        uint256 newFee,
        uint256 timestamp
    );
    
    event AssetAdded(
        address indexed asset,
        uint256 maxLoanAmount,
        uint256 fee,
        uint256 timestamp
    );
    
    event AssetRemoved(
        address indexed asset,
        uint256 timestamp
    );
    
    event UtilizationThresholdUpdated(
        address indexed asset,
        uint256 oldThreshold,
        uint256 newThreshold,
        uint256 timestamp
    );
    
    event EmergencyPause(
        address indexed asset,
        string reason,
        uint256 timestamp
    );
    
    event EmergencyUnpause(
        address indexed asset,
        uint256 timestamp
    );
    
    event FlashLoanReceiverWhitelisted(
        address indexed receiver,
        bool whitelisted,
        uint256 timestamp
    );
    
    event BatchFlashLoanExecuted(
        bytes32 indexed batchId,
        address indexed borrower,
        address[] assets,
        uint256[] amounts,
        uint256 totalFees,
        uint256 timestamp
    );

    // Structs
    struct FlashLoan {
        bytes32 loanId;
        address borrower;
        address asset;
        uint256 amount;
        uint256 fee;
        uint256 totalRepayment;
        uint256 initiatedAt;
        uint256 deadline;
        address target;
        bytes data;
        LoanStatus status;
        uint256 gasUsed;
        uint256 executionTime;
        bool isRepaid;
        uint256 repaidAt;
    }
    
    struct LiquidityPool {
        address asset;
        uint256 totalLiquidity;
        uint256 availableLiquidity;
        uint256 utilizationRate;
        uint256 totalBorrowed;
        uint256 totalFees;
        uint256 maxLoanAmount;
        uint256 baseFee;
        uint256 utilizationFee;
        uint256 lastUpdate;
        bool isActive;
        bool isPaused;
        PoolConfig config;
        PoolMetrics metrics;
    }
    
    struct PoolConfig {
        uint256 maxUtilizationRate; // Basis points (e.g., 8000 = 80%)
        uint256 optimalUtilizationRate; // Basis points
        uint256 baseFeeRate; // Basis points
        uint256 utilizationFeeMultiplier; // Multiplier for utilization-based fees
        uint256 maxLoanDuration; // Maximum loan duration in seconds
        uint256 minLoanAmount; // Minimum loan amount
        uint256 reserveRatio; // Percentage of liquidity to keep as reserve
        bool requiresWhitelist; // Whether borrowers need to be whitelisted
        uint256 cooldownPeriod; // Cooldown between loans for same user
    }
    
    struct PoolMetrics {
        uint256 totalLoans;
        uint256 totalVolume;
        uint256 totalFeesCollected;
        uint256 averageLoanSize;
        uint256 averageLoanDuration;
        uint256 defaultRate;
        uint256 utilizationHistory;
        uint256 peakUtilization;
        uint256 lastLoanTimestamp;
        uint256 activeLoans;
    }
    
    struct LiquidityProvider {
        address provider;
        address asset;
        uint256 totalProvided;
        uint256 currentBalance;
        uint256 shares;
        uint256 feesEarned;
        uint256 lastDeposit;
        uint256 lastWithdrawal;
        uint256 joinedAt;
        bool isActive;
        ProviderMetrics metrics;
    }
    
    struct ProviderMetrics {
        uint256 totalDeposits;
        uint256 totalWithdrawals;
        uint256 totalFeesEarned;
        uint256 averageBalance;
        uint256 utilizationContribution;
        uint256 loyaltyScore;
        uint256 riskScore;
    }
    
    struct FlashLoanParams {
        address asset;
        uint256 amount;
        address target;
        bytes data;
        uint256 maxFee;
        uint256 deadline;
        bytes32 referenceId;
    }
    
    struct BatchFlashLoanParams {
        address[] assets;
        uint256[] amounts;
        address target;
        bytes data;
        uint256 maxTotalFee;
        uint256 deadline;
        bytes32 referenceId;
    }
    
    struct FlashLoanFee {
        uint256 baseFee; // Fixed fee in basis points
        uint256 utilizationFee; // Variable fee based on utilization
        uint256 totalFee; // Total fee to be paid
        uint256 protocolFee; // Fee for protocol
        uint256 liquidityProviderFee; // Fee for liquidity providers
        uint256 calculatedAt;
    }
    
    struct ArbitrageOpportunity {
        bytes32 opportunityId;
        address[] assets;
        uint256[] amounts;
        address[] exchanges;
        uint256 expectedProfit;
        uint256 requiredCapital;
        uint256 riskScore;
        uint256 confidence;
        uint256 expiresAt;
        bool isExecutable;
    }
    
    struct LoanUtilization {
        address asset;
        uint256 currentUtilization;
        uint256 optimalUtilization;
        uint256 maxUtilization;
        uint256 utilizationTrend;
        uint256 demandScore;
        uint256 supplyScore;
        uint256 lastUpdate;
    }
    
    struct RiskAssessment {
        address borrower;
        uint256 creditScore;
        uint256 defaultProbability;
        uint256 maxLoanAmount;
        uint256 riskPremium;
        bool isEligible;
        uint256 lastAssessment;
        RiskFactors factors;
    }
    
    struct RiskFactors {
        uint256 historicalPerformance;
        uint256 portfolioRisk;
        uint256 liquidityRisk;
        uint256 counterpartyRisk;
        uint256 marketRisk;
        uint256 operationalRisk;
    }

    // Enums
    enum LoanStatus {
        PENDING,
        ACTIVE,
        REPAID,
        DEFAULTED,
        CANCELLED
    }
    
    enum PoolStatus {
        ACTIVE,
        PAUSED,
        DEPRECATED,
        EMERGENCY
    }
    
    enum FeeType {
        FIXED,
        VARIABLE,
        DYNAMIC,
        TIERED
    }

    // Core flash loan functions
    function flashLoan(
        FlashLoanParams calldata params
    ) external returns (bytes32 loanId);
    
    function batchFlashLoan(
        BatchFlashLoanParams calldata params
    ) external returns (bytes32 batchId);
    
    function repayFlashLoan(
        bytes32 loanId
    ) external payable returns (bool success);
    
    function executeFlashLoan(
        address asset,
        uint256 amount,
        address target,
        bytes calldata data
    ) external returns (bool success);
    
    function simpleFlashLoan(
        address asset,
        uint256 amount,
        address receiver
    ) external returns (bytes32 loanId);
    
    // Advanced flash loan functions
    function flashLoanWithCallback(
        address asset,
        uint256 amount,
        address receiver,
        bytes calldata params,
        uint256 maxFee
    ) external returns (bytes32 loanId);
    
    function recursiveFlashLoan(
        address[] calldata assets,
        uint256[] calldata amounts,
        address receiver,
        bytes calldata data,
        uint256 depth
    ) external returns (bytes32[] memory loanIds);
    
    function conditionalFlashLoan(
        address asset,
        uint256 amount,
        address receiver,
        bytes calldata condition,
        bytes calldata data
    ) external returns (bytes32 loanId);
    
    function scheduledFlashLoan(
        address asset,
        uint256 amount,
        address receiver,
        uint256 executeAt,
        bytes calldata data
    ) external returns (bytes32 loanId);
    
    // Liquidity management functions
    function addLiquidity(
        address asset,
        uint256 amount
    ) external returns (uint256 shares);
    
    function removeLiquidity(
        address asset,
        uint256 shares
    ) external returns (uint256 amount);
    
    function emergencyWithdraw(
        address asset
    ) external returns (uint256 amount);
    
    function rebalanceLiquidity(
        address fromAsset,
        address toAsset,
        uint256 amount
    ) external returns (bool success);
    
    function optimizeLiquidity(
        address asset
    ) external returns (uint256 newOptimalAmount);
    
    // Pool management functions
    function createPool(
        address asset,
        PoolConfig calldata config
    ) external returns (bool success);
    
    function updatePoolConfig(
        address asset,
        PoolConfig calldata newConfig
    ) external;
    
    function pausePool(
        address asset,
        string calldata reason
    ) external;
    
    function unpausePool(
        address asset
    ) external;
    
    function deprecatePool(
        address asset
    ) external;
    
    // Fee management functions
    function updateBaseFee(
        address asset,
        uint256 newFee
    ) external;
    
    function updateUtilizationFee(
        address asset,
        uint256 newMultiplier
    ) external;
    
    function setDynamicFees(
        address asset,
        bool enabled
    ) external;
    
    function calculateFee(
        address asset,
        uint256 amount
    ) external view returns (FlashLoanFee memory fee);
    
    function updateFeeModel(
        address asset,
        FeeType feeType,
        uint256[] calldata parameters
    ) external;
    
    // Risk management functions
    function assessRisk(
        address borrower,
        address asset,
        uint256 amount
    ) external returns (RiskAssessment memory assessment);
    
    function updateRiskParameters(
        address asset,
        uint256 maxUtilization,
        uint256 reserveRatio
    ) external;
    
    function blacklistBorrower(
        address borrower
    ) external;
    
    function whitelistBorrower(
        address borrower
    ) external;
    
    function setMaxLoanAmount(
        address asset,
        uint256 maxAmount
    ) external;
    
    // Arbitrage functions
    function findArbitrageOpportunities(
        address[] calldata assets,
        uint256[] calldata amounts
    ) external view returns (ArbitrageOpportunity[] memory opportunities);
    
    function executeArbitrage(
        bytes32 opportunityId,
        uint256 maxSlippage
    ) external returns (uint256 profit);
    
    function simulateArbitrage(
        ArbitrageOpportunity calldata opportunity
    ) external view returns (
        uint256 expectedProfit,
        uint256 requiredGas,
        uint256 successProbability
    );
    
    // Analytics functions
    function getUtilizationMetrics(
        address asset
    ) external view returns (LoanUtilization memory utilization);
    
    function getPoolAnalytics(
        address asset,
        uint256 timeframe
    ) external view returns (
        uint256 totalVolume,
        uint256 averageUtilization,
        uint256 totalFees,
        uint256 uniqueBorrowers
    );
    
    function getLiquidityTrends(
        address asset,
        uint256 timeframe
    ) external view returns (
        uint256[] memory timestamps,
        uint256[] memory liquidityLevels,
        uint256[] memory utilizationRates
    );
    
    // Emergency functions
    function emergencyPause() external;
    
    function emergencyUnpause() external;
    
    function emergencyWithdrawAll(
        address asset
    ) external;
    
    function forceRepayment(
        bytes32 loanId
    ) external;
    
    function liquidateDefaultedLoan(
        bytes32 loanId
    ) external;
    
    // Configuration functions
    function setGlobalMaxLoanDuration(
        uint256 duration
    ) external;
    
    function setGlobalCooldownPeriod(
        uint256 period
    ) external;
    
    function setProtocolFeeRecipient(
        address recipient
    ) external;
    
    function setMinLiquidityThreshold(
        address asset,
        uint256 threshold
    ) external;
    
    // View functions - Loans
    function getFlashLoan(
        bytes32 loanId
    ) external view returns (FlashLoan memory);
    
    function getUserLoans(
        address user
    ) external view returns (bytes32[] memory);
    
    function getActiveLoans() external view returns (bytes32[] memory);
    
    function getLoanStatus(
        bytes32 loanId
    ) external view returns (LoanStatus);
    
    function isLoanRepaid(
        bytes32 loanId
    ) external view returns (bool);
    
    function getLoanDeadline(
        bytes32 loanId
    ) external view returns (uint256);
    
    function getTotalLoansCount() external view returns (uint256);
    
    function getUserLoanHistory(
        address user,
        uint256 limit
    ) external view returns (FlashLoan[] memory);
    
    // View functions - Pools
    function getPool(
        address asset
    ) external view returns (LiquidityPool memory);
    
    function getAllPools() external view returns (address[] memory);
    
    function getActivePools() external view returns (address[] memory);
    
    function getPoolLiquidity(
        address asset
    ) external view returns (uint256 total, uint256 available);
    
    function getPoolUtilization(
        address asset
    ) external view returns (uint256 utilizationRate);
    
    function getPoolMetrics(
        address asset
    ) external view returns (PoolMetrics memory);
    
    function isPoolActive(
        address asset
    ) external view returns (bool);
    
    function getMaxLoanAmount(
        address asset
    ) external view returns (uint256);
    
    // View functions - Liquidity providers
    function getLiquidityProvider(
        address provider,
        address asset
    ) external view returns (LiquidityProvider memory);
    
    function getProviderShares(
        address provider,
        address asset
    ) external view returns (uint256 shares);
    
    function getProviderBalance(
        address provider,
        address asset
    ) external view returns (uint256 balance);
    
    function getProviderFeesEarned(
        address provider,
        address asset
    ) external view returns (uint256 fees);
    
    function getAllProviders(
        address asset
    ) external view returns (address[] memory);
    
    function getTopProviders(
        address asset,
        uint256 count
    ) external view returns (address[] memory, uint256[] memory);
    
    // View functions - Fees
    function getCurrentFee(
        address asset,
        uint256 amount
    ) external view returns (uint256 fee);
    
    function getBaseFee(
        address asset
    ) external view returns (uint256 fee);
    
    function getUtilizationFee(
        address asset
    ) external view returns (uint256 fee);
    
    function getTotalFeesCollected(
        address asset
    ) external view returns (uint256 totalFees);
    
    function getProtocolRevenue() external view returns (uint256 revenue);
    
    // View functions - Risk
    function getBorrowerRisk(
        address borrower
    ) external view returns (uint256 riskScore);
    
    function isWhitelisted(
        address borrower
    ) external view returns (bool);
    
    function isBlacklisted(
        address borrower
    ) external view returns (bool);
    
    function getMaxBorrowAmount(
        address borrower,
        address asset
    ) external view returns (uint256 maxAmount);
    
    function getRiskAssessment(
        address borrower,
        address asset
    ) external view returns (RiskAssessment memory);
    
    // View functions - System health
    function isSystemHealthy() external view returns (bool);
    
    function getSystemHealth() external view returns (
        bool isHealthy,
        uint256 totalLiquidity,
        uint256 totalUtilization,
        uint256 averageUtilization
    );
    
    function getTotalValueLocked() external view returns (uint256 tvl);
    
    function getTotalBorrowed() external view returns (uint256 totalBorrowed);
    
    function getGlobalUtilization() external view returns (uint256 utilization);
    
    function getSystemMetrics() external view returns (
        uint256 totalLoans,
        uint256 totalVolume,
        uint256 totalFees,
        uint256 activeUsers
    );
}
