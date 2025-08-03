// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IFlashLoan
 * @dev Interface for the Flash Loan contract
 * @author CoreLiquid Protocol
 */
interface IFlashLoan {
    // Events
    event FlashLoanExecuted(
        bytes32 indexed loanId,
        address indexed borrower,
        address indexed asset,
        uint256 amount,
        uint256 fee,
        uint256 timestamp
    );
    
    event FlashLoanRepaid(
        bytes32 indexed loanId,
        address indexed borrower,
        uint256 repayAmount,
        uint256 timestamp
    );
    
    event FlashLoanDefaulted(
        bytes32 indexed loanId,
        address indexed borrower,
        uint256 amount,
        uint256 timestamp
    );
    
    event FlashLoanFeeUpdated(
        address indexed asset,
        uint256 oldFee,
        uint256 newFee,
        uint256 timestamp
    );
    
    event FlashLoanProviderAdded(
        address indexed provider,
        address indexed asset,
        uint256 maxLoanAmount,
        uint256 timestamp
    );
    
    event FlashLoanProviderRemoved(
        address indexed provider,
        address indexed asset,
        uint256 timestamp
    );
    
    event LiquidityAdded(
        address indexed provider,
        address indexed asset,
        uint256 amount,
        uint256 timestamp
    );
    
    event LiquidityRemoved(
        address indexed provider,
        address indexed asset,
        uint256 amount,
        uint256 timestamp
    );
    
    event FlashLoanLimitUpdated(
        address indexed asset,
        uint256 oldLimit,
        uint256 newLimit,
        uint256 timestamp
    );
    
    event FlashLoanPaused(
        address indexed asset,
        string reason,
        uint256 timestamp
    );
    
    event FlashLoanUnpaused(
        address indexed asset,
        uint256 timestamp
    );
    
    event ArbitrageOpportunityDetected(
        bytes32 indexed opportunityId,
        address indexed asset,
        uint256 profitPotential,
        uint256 timestamp
    );
    
    event ArbitrageExecuted(
        bytes32 indexed opportunityId,
        address indexed executor,
        uint256 profit,
        uint256 timestamp
    );
    
    event FlashLoanCallbackFailed(
        bytes32 indexed loanId,
        address indexed borrower,
        string reason,
        uint256 timestamp
    );
    
    event FlashLoanSecurityBreach(
        bytes32 indexed loanId,
        address indexed borrower,
        SecurityBreachType breachType,
        uint256 timestamp
    );

    // Structs
    struct FlashLoan {
        bytes32 loanId;
        address borrower;
        address asset;
        uint256 amount;
        uint256 fee;
        uint256 timestamp;
        uint256 repayDeadline;
        FlashLoanStatus status;
        FlashLoanConfig config;
        FlashLoanMetrics metrics;
        bytes callbackData;
        address initiator;
    }
    
    struct FlashLoanConfig {
        uint256 maxLoanAmount;
        uint256 feeRate;
        uint256 maxDuration;
        bool requiresCollateral;
        uint256 collateralRatio;
        bool allowsReentrancy;
        uint256 gasLimit;
        address[] authorizedCallers;
        bool requiresWhitelist;
    }
    
    struct FlashLoanMetrics {
        uint256 executionTime;
        uint256 gasUsed;
        uint256 profitGenerated;
        uint256 slippage;
        uint256 priceImpact;
        bool wasSuccessful;
        string[] operationsExecuted;
        uint256 riskScore;
    }
    
    struct FlashLoanProvider {
        address provider;
        address asset;
        uint256 availableLiquidity;
        uint256 maxLoanAmount;
        uint256 feeRate;
        uint256 totalLoaned;
        uint256 totalFees;
        bool isActive;
        ProviderConfig config;
        ProviderMetrics metrics;
    }
    
    struct ProviderConfig {
        uint256 minLoanAmount;
        uint256 maxLoanAmount;
        uint256 baseFeeRate;
        uint256 utilizationFeeRate;
        uint256 reserveRatio;
        bool allowsPartialLoans;
        uint256 cooldownPeriod;
        address[] preferredBorrowers;
    }
    
    struct ProviderMetrics {
        uint256 totalLoansProvided;
        uint256 totalVolumeProvided;
        uint256 totalFeesEarned;
        uint256 averageLoanSize;
        uint256 utilizationRate;
        uint256 defaultRate;
        uint256 profitability;
        uint256 lastActivity;
    }
    
    struct LiquidityPool {
        address asset;
        uint256 totalLiquidity;
        uint256 availableLiquidity;
        uint256 utilizedLiquidity;
        uint256 reserveLiquidity;
        PoolConfig config;
        PoolMetrics metrics;
        mapping(address => ProviderPosition) providers;
        address[] providerList;
    }
    
    struct PoolConfig {
        uint256 maxUtilizationRate;
        uint256 reserveRatio;
        uint256 baseFeeRate;
        uint256 utilizationMultiplier;
        uint256 optimalUtilization;
        uint256 maxFeeRate;
        bool isDynamic;
        uint256 rebalanceThreshold;
    }
    
    struct PoolMetrics {
        uint256 totalLoansExecuted;
        uint256 totalVolumeLoaned;
        uint256 totalFeesCollected;
        uint256 averageLoanSize;
        uint256 peakUtilization;
        uint256 averageUtilization;
        uint256 totalProviders;
        uint256 lastUpdate;
    }
    
    struct ProviderPosition {
        address provider;
        uint256 liquidityProvided;
        uint256 shares;
        uint256 feesEarned;
        uint256 lastDeposit;
        uint256 lockupEnd;
        bool isActive;
        PositionMetrics metrics;
    }
    
    struct PositionMetrics {
        uint256 totalDeposited;
        uint256 totalWithdrawn;
        uint256 totalFeesEarned;
        uint256 averageAPY;
        uint256 impermanentLoss;
        uint256 riskAdjustedReturn;
    }
    
    struct ArbitrageOpportunity {
        bytes32 opportunityId;
        address asset;
        uint256 amount;
        uint256 profitPotential;
        uint256 riskLevel;
        uint256 expiryTime;
        ArbitrageStrategy strategy;
        ArbitrageConfig config;
        bool isActive;
    }
    
    struct ArbitrageStrategy {
        string name;
        address[] exchanges;
        uint256[] prices;
        uint256 expectedProfit;
        uint256 maxSlippage;
        uint256 gasEstimate;
        bytes executionData;
        StrategyType strategyType;
    }
    
    struct ArbitrageConfig {
        uint256 minProfitThreshold;
        uint256 maxRiskLevel;
        uint256 maxGasPrice;
        uint256 slippageTolerance;
        bool autoExecute;
        address[] authorizedExecutors;
        uint256 executionDelay;
    }
    
    struct FlashLoanSecurity {
        bool isSecure;
        SecurityLevel securityLevel;
        SecurityCheck[] checks;
        SecurityMetrics metrics;
        SecurityConfig config;
    }
    
    struct SecurityCheck {
        string checkName;
        bool passed;
        uint256 riskScore;
        string description;
        uint256 timestamp;
    }
    
    struct SecurityMetrics {
        uint256 totalChecks;
        uint256 passedChecks;
        uint256 failedChecks;
        uint256 averageRiskScore;
        uint256 securityScore;
        uint256 lastSecurityUpdate;
    }
    
    struct SecurityConfig {
        bool enableReentrancyGuard;
        bool enableFlashLoanGuard;
        bool enablePriceManipulationGuard;
        bool enableGasLimitGuard;
        uint256 maxGasLimit;
        uint256 maxPriceDeviation;
        address[] trustedContracts;
    }
    
    struct FlashLoanAnalytics {
        uint256 totalLoansExecuted;
        uint256 totalVolumeLoaned;
        uint256 totalFeesCollected;
        uint256 averageLoanSize;
        uint256 successRate;
        uint256 averageExecutionTime;
        uint256 totalProviders;
        uint256 totalLiquidity;
        uint256 utilizationRate;
        uint256 lastUpdate;
    }
    
    struct RiskAssessment {
        bytes32 assessmentId;
        address borrower;
        uint256 riskScore;
        RiskLevel riskLevel;
        RiskFactors factors;
        RiskMetrics metrics;
        uint256 assessmentTime;
        bool isValid;
    }
    
    struct RiskFactors {
        uint256 creditRisk;
        uint256 liquidityRisk;
        uint256 marketRisk;
        uint256 operationalRisk;
        uint256 reputationRisk;
        uint256 technicalRisk;
        uint256 regulatoryRisk;
        uint256 counterpartyRisk;
    }
    
    struct RiskMetrics {
        uint256 probabilityOfDefault;
        uint256 lossGivenDefault;
        uint256 exposureAtDefault;
        uint256 expectedLoss;
        uint256 valueAtRisk;
        uint256 conditionalValueAtRisk;
        uint256 riskAdjustedReturn;
    }

    // Enums
    enum FlashLoanStatus {
        PENDING,
        ACTIVE,
        REPAID,
        DEFAULTED,
        CANCELLED,
        EXPIRED
    }
    
    enum SecurityBreachType {
        REENTRANCY_ATTACK,
        PRICE_MANIPULATION,
        FLASH_LOAN_ATTACK,
        UNAUTHORIZED_ACCESS,
        GAS_LIMIT_EXCEEDED,
        CALLBACK_FAILURE,
        INSUFFICIENT_REPAYMENT
    }
    
    enum StrategyType {
        DEX_ARBITRAGE,
        LENDING_ARBITRAGE,
        LIQUIDATION,
        YIELD_FARMING,
        COLLATERAL_SWAP,
        DEBT_REFINANCING,
        CUSTOM
    }
    
    enum SecurityLevel {
        LOW,
        MEDIUM,
        HIGH,
        CRITICAL
    }
    
    enum RiskLevel {
        VERY_LOW,
        LOW,
        MEDIUM,
        HIGH,
        VERY_HIGH,
        EXTREME
    }

    // Core flash loan functions
    function flashLoan(
        address asset,
        uint256 amount,
        bytes calldata data
    ) external returns (bytes32 loanId);
    
    function flashLoanMultiple(
        address[] calldata assets,
        uint256[] calldata amounts,
        bytes calldata data
    ) external returns (bytes32 loanId);
    
    function repayFlashLoan(
        bytes32 loanId
    ) external;
    
    function executeFlashLoanCallback(
        address borrower,
        address asset,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external;
    
    function cancelFlashLoan(
        bytes32 loanId,
        string calldata reason
    ) external;
    
    // Liquidity provider functions
    function addLiquidity(
        address asset,
        uint256 amount
    ) external returns (uint256 shares);
    
    function removeLiquidity(
        address asset,
        uint256 shares
    ) external returns (uint256 amount);
    
    function addLiquidityProvider(
        address provider,
        address asset,
        ProviderConfig calldata config
    ) external;
    
    function removeLiquidityProvider(
        address provider,
        address asset
    ) external;
    
    function updateProviderConfig(
        address provider,
        address asset,
        ProviderConfig calldata newConfig
    ) external;
    
    function claimProviderFees(
        address asset
    ) external;
    
    function rebalanceLiquidity(
        address asset
    ) external;
    
    // Pool management functions
    function createLiquidityPool(
        address asset,
        PoolConfig calldata config
    ) external;
    
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
    
    function emergencyWithdraw(
        address asset,
        uint256 amount
    ) external;
    
    // Fee management functions
    function updateFlashLoanFee(
        address asset,
        uint256 newFeeRate
    ) external;
    
    function updateDynamicFees(
        address asset
    ) external;
    
    function calculateFlashLoanFee(
        address asset,
        uint256 amount
    ) external view returns (uint256 fee);
    
    function distributeFees(
        address asset
    ) external;
    
    // Arbitrage functions
    function detectArbitrageOpportunity(
        address asset,
        address[] calldata exchanges
    ) external returns (bytes32 opportunityId);
    
    function executeArbitrage(
        bytes32 opportunityId,
        ArbitrageStrategy calldata strategy
    ) external;
    
    function calculateArbitrageProfit(
        address asset,
        uint256 amount,
        address[] calldata exchanges
    ) external view returns (uint256 profit);
    
    function updateArbitrageConfig(
        ArbitrageConfig calldata newConfig
    ) external;
    
    // Security functions
    function performSecurityCheck(
        address borrower,
        address asset,
        uint256 amount
    ) external returns (FlashLoanSecurity memory);
    
    function updateSecurityConfig(
        SecurityConfig calldata newConfig
    ) external;
    
    function reportSecurityBreach(
        bytes32 loanId,
        SecurityBreachType breachType,
        string calldata description
    ) external;
    
    function blacklistAddress(
        address account,
        string calldata reason
    ) external;
    
    function removeFromBlacklist(
        address account
    ) external;
    
    // Risk assessment functions
    function assessRisk(
        address borrower,
        address asset,
        uint256 amount
    ) external returns (bytes32 assessmentId);
    
    function updateRiskParameters(
        string calldata parameter,
        uint256 value
    ) external;
    
    function calculateRiskScore(
        address borrower,
        address asset,
        uint256 amount
    ) external view returns (uint256 riskScore);
    
    // Configuration functions
    function setFlashLoanLimit(
        address asset,
        uint256 newLimit
    ) external;
    
    function updateGlobalConfig(
        string calldata parameter,
        uint256 value
    ) external;
    
    function setAuthorizedCaller(
        address caller,
        bool authorized
    ) external;
    
    function pauseFlashLoans(
        string calldata reason
    ) external;
    
    function unpauseFlashLoans() external;
    
    // Emergency functions
    function emergencyPause(
        string calldata reason
    ) external;
    
    function emergencyRepay(
        bytes32 loanId,
        uint256 amount
    ) external;
    
    function forceRepayment(
        bytes32 loanId,
        string calldata reason
    ) external;
    
    function recoverFunds(
        address asset,
        uint256 amount
    ) external;
    
    // View functions - Flash loans
    function getFlashLoan(
        bytes32 loanId
    ) external view returns (FlashLoan memory);
    
    function getActiveFlashLoans(
        address borrower
    ) external view returns (bytes32[] memory);
    
    function getAllFlashLoans() external view returns (bytes32[] memory);
    
    function getFlashLoansByStatus(
        FlashLoanStatus status
    ) external view returns (bytes32[] memory);
    
    function isFlashLoanActive(
        bytes32 loanId
    ) external view returns (bool active);
    
    function getFlashLoanConfig(
        address asset
    ) external view returns (FlashLoanConfig memory);
    
    function getMaxFlashLoanAmount(
        address asset
    ) external view returns (uint256 maxAmount);
    
    function getFlashLoanFee(
        address asset,
        uint256 amount
    ) external view returns (uint256 fee);
    
    // View functions - Liquidity
    function getLiquidityPool(
        address asset
    ) external view returns (LiquidityPool memory);
    
    function getAvailableLiquidity(
        address asset
    ) external view returns (uint256 available);
    
    function getTotalLiquidity(
        address asset
    ) external view returns (uint256 total);
    
    function getUtilizationRate(
        address asset
    ) external view returns (uint256 rate);
    
    function getProviderPosition(
        address provider,
        address asset
    ) external view returns (ProviderPosition memory);
    
    function getProviderShares(
        address provider,
        address asset
    ) external view returns (uint256 shares);
    
    function getProviderFees(
        address provider,
        address asset
    ) external view returns (uint256 fees);
    
    // View functions - Providers
    function getFlashLoanProvider(
        address provider,
        address asset
    ) external view returns (FlashLoanProvider memory);
    
    function getAllProviders(
        address asset
    ) external view returns (address[] memory);
    
    function getActiveProviders(
        address asset
    ) external view returns (address[] memory);
    
    function getProviderMetrics(
        address provider,
        address asset
    ) external view returns (ProviderMetrics memory);
    
    function isProviderActive(
        address provider,
        address asset
    ) external view returns (bool active);
    
    // View functions - Arbitrage
    function getArbitrageOpportunity(
        bytes32 opportunityId
    ) external view returns (ArbitrageOpportunity memory);
    
    function getActiveOpportunities(
        address asset
    ) external view returns (bytes32[] memory);
    
    function getArbitrageProfit(
        bytes32 opportunityId
    ) external view returns (uint256 profit);
    
    function isArbitrageOpportunityValid(
        bytes32 opportunityId
    ) external view returns (bool valid);
    
    // View functions - Security
    function getSecurityStatus(
        address borrower
    ) external view returns (FlashLoanSecurity memory);
    
    function isAddressBlacklisted(
        address account
    ) external view returns (bool blacklisted);
    
    function getSecurityConfig() external view returns (SecurityConfig memory);
    
    function getLastSecurityBreach(
        address borrower
    ) external view returns (SecurityBreachType breachType, uint256 timestamp);
    
    // View functions - Risk
    function getRiskAssessment(
        bytes32 assessmentId
    ) external view returns (RiskAssessment memory);
    
    function getBorrowerRiskScore(
        address borrower
    ) external view returns (uint256 riskScore, RiskLevel riskLevel);
    
    function getRiskFactors(
        address borrower,
        address asset
    ) external view returns (RiskFactors memory);
    
    function getRiskMetrics(
        address borrower
    ) external view returns (RiskMetrics memory);
    
    // View functions - Analytics
    function getFlashLoanAnalytics() external view returns (FlashLoanAnalytics memory);
    
    function getAssetAnalytics(
        address asset,
        uint256 timeframe
    ) external view returns (
        uint256 totalLoans,
        uint256 totalVolume,
        uint256 averageLoanSize,
        uint256 utilizationRate
    );
    
    function getProviderAnalytics(
        address provider,
        uint256 timeframe
    ) external view returns (
        uint256 liquidityProvided,
        uint256 feesEarned,
        uint256 averageAPY,
        uint256 riskAdjustedReturn
    );
    
    function getSystemHealth() external view returns (
        uint256 totalLiquidity,
        uint256 averageUtilization,
        uint256 totalProviders,
        uint256 securityScore
    );
}
