// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IBorrowEngine
 * @dev Interface for the Borrow Engine contract
 * @author CoreLiquid Protocol
 */
interface IBorrowEngine {
    // Events
    event LoanCreated(
        bytes32 indexed loanId,
        address indexed borrower,
        address indexed asset,
        uint256 amount,
        uint256 interestRate,
        uint256 duration,
        uint256 timestamp
    );
    
    event LoanRepaid(
        bytes32 indexed loanId,
        address indexed borrower,
        uint256 principalRepaid,
        uint256 interestRepaid,
        uint256 timestamp
    );
    
    event CollateralDeposited(
        bytes32 indexed loanId,
        address indexed borrower,
        address indexed collateralAsset,
        uint256 amount,
        uint256 timestamp
    );
    
    event CollateralWithdrawn(
        bytes32 indexed loanId,
        address indexed borrower,
        address indexed collateralAsset,
        uint256 amount,
        uint256 timestamp
    );
    
    event LoanLiquidated(
        bytes32 indexed loanId,
        address indexed borrower,
        address indexed liquidator,
        uint256 liquidatedAmount,
        uint256 liquidationBonus,
        uint256 timestamp
    );
    
    event InterestRateUpdated(
        address indexed asset,
        uint256 oldRate,
        uint256 newRate,
        uint256 timestamp
    );
    
    event CreditScoreUpdated(
        address indexed user,
        uint256 oldScore,
        uint256 newScore,
        uint256 timestamp
    );
    
    event FlashLoanExecuted(
        bytes32 indexed flashLoanId,
        address indexed borrower,
        address indexed asset,
        uint256 amount,
        uint256 fee,
        uint256 timestamp
    );

    // Structs
    struct Loan {
        bytes32 loanId;
        address borrower;
        address asset;
        uint256 principal;
        uint256 interestRate;
        uint256 accruedInterest;
        uint256 totalDebt;
        uint256 duration;
        uint256 startTime;
        uint256 lastUpdate;
        uint256 maturityTime;
        bool isActive;
        bool isDefaulted;
        LoanStatus status;
    }
    
    struct Collateral {
        address asset;
        uint256 amount;
        uint256 value;
        uint256 ltv;
        uint256 liquidationThreshold;
        uint256 liquidationBonus;
        uint256 depositTime;
        bool isActive;
    }
    
    struct BorrowPosition {
        address borrower;
        bytes32[] activeLoans;
        uint256 totalBorrowed;
        uint256 totalCollateral;
        uint256 healthFactor;
        uint256 creditScore;
        uint256 borrowingPower;
        uint256 utilizationRate;
        mapping(address => Collateral) collaterals;
        mapping(address => uint256) assetBorrowLimits;
    }
    
    struct InterestRateModel {
        address asset;
        uint256 baseRate;
        uint256 multiplier;
        uint256 jumpMultiplier;
        uint256 kink;
        uint256 utilizationRate;
        uint256 currentRate;
        uint256 lastUpdate;
        bool isActive;
    }
    
    struct LendingPool {
        address asset;
        uint256 totalSupply;
        uint256 totalBorrowed;
        uint256 availableLiquidity;
        uint256 utilizationRate;
        uint256 supplyRate;
        uint256 borrowRate;
        uint256 reserveFactor;
        uint256 lastUpdate;
        bool isActive;
        bool isPaused;
    }
    
    struct FlashLoan {
        bytes32 flashLoanId;
        address borrower;
        address asset;
        uint256 amount;
        uint256 fee;
        uint256 deadline;
        uint256 executedAt;
        bool isRepaid;
        bool isActive;
    }
    
    struct CreditProfile {
        address user;
        uint256 creditScore;
        uint256 totalBorrowHistory;
        uint256 totalRepayHistory;
        uint256 defaultCount;
        uint256 onTimePayments;
        uint256 latePayments;
        uint256 averageLoanDuration;
        uint256 lastActivity;
        bool isVerified;
    }
    
    struct RiskParameters {
        address asset;
        uint256 maxLTV;
        uint256 liquidationThreshold;
        uint256 liquidationBonus;
        uint256 reserveFactor;
        uint256 borrowCap;
        uint256 supplyCap;
        bool isCollateralEnabled;
        bool isBorrowEnabled;
    }

    // Enums
    enum LoanStatus {
        PENDING,
        ACTIVE,
        REPAID,
        DEFAULTED,
        LIQUIDATED
    }

    // Core borrowing functions
    function borrow(
        address asset,
        uint256 amount,
        uint256 duration,
        address collateralAsset,
        uint256 collateralAmount
    ) external returns (bytes32 loanId);
    
    function repay(
        bytes32 loanId,
        uint256 amount
    ) external returns (uint256 principalRepaid, uint256 interestRepaid);
    
    function repayFull(
        bytes32 loanId
    ) external returns (uint256 totalRepaid);
    
    function extendLoan(
        bytes32 loanId,
        uint256 additionalDuration
    ) external returns (uint256 newMaturityTime);
    
    function refinanceLoan(
        bytes32 loanId,
        uint256 newInterestRate,
        uint256 newDuration
    ) external returns (bytes32 newLoanId);
    
    // Collateral management
    function depositCollateral(
        bytes32 loanId,
        address collateralAsset,
        uint256 amount
    ) external;
    
    function withdrawCollateral(
        bytes32 loanId,
        address collateralAsset,
        uint256 amount
    ) external;
    
    function swapCollateral(
        bytes32 loanId,
        address fromAsset,
        address toAsset,
        uint256 amount
    ) external;
    
    function liquidateCollateral(
        bytes32 loanId,
        address collateralAsset,
        uint256 amount
    ) external returns (uint256 liquidationBonus);
    
    // Flash loan functions
    function flashLoan(
        address asset,
        uint256 amount,
        bytes calldata data
    ) external returns (bytes32 flashLoanId);
    
    function repayFlashLoan(
        bytes32 flashLoanId
    ) external;
    
    function calculateFlashLoanFee(
        address asset,
        uint256 amount
    ) external view returns (uint256 fee);
    
    function getMaxFlashLoanAmount(
        address asset
    ) external view returns (uint256 maxAmount);
    
    // Interest rate management
    function updateInterestRates(
        address asset
    ) external;
    
    function setInterestRateModel(
        address asset,
        uint256 baseRate,
        uint256 multiplier,
        uint256 jumpMultiplier,
        uint256 kink
    ) external;
    
    function accrueInterest(
        bytes32 loanId
    ) external returns (uint256 accruedAmount);
    
    function accrueAllInterest(
        address borrower
    ) external returns (uint256 totalAccrued);
    
    // Credit scoring
    function updateCreditScore(
        address user
    ) external returns (uint256 newScore);
    
    function calculateCreditScore(
        address user
    ) external view returns (uint256 score);
    
    function verifyCreditProfile(
        address user
    ) external;
    
    function reportPayment(
        address user,
        bool isOnTime,
        uint256 amount
    ) external;
    
    // Risk management
    function calculateHealthFactor(
        address borrower
    ) external view returns (uint256 healthFactor);
    
    function calculateBorrowingPower(
        address borrower
    ) external view returns (uint256 borrowingPower);
    
    function isLiquidatable(
        bytes32 loanId
    ) external view returns (bool);
    
    function liquidate(
        bytes32 loanId,
        address collateralAsset,
        uint256 amount
    ) external returns (uint256 liquidationBonus);
    
    // Pool management
    function addLendingPool(
        address asset,
        uint256 reserveFactor,
        bool isCollateralEnabled,
        bool isBorrowEnabled
    ) external;
    
    function removeLendingPool(
        address asset
    ) external;
    
    function pausePool(
        address asset
    ) external;
    
    function unpausePool(
        address asset
    ) external;
    
    function setPoolParameters(
        address asset,
        uint256 borrowCap,
        uint256 supplyCap,
        uint256 reserveFactor
    ) external;
    
    // Risk parameter management
    function setRiskParameters(
        address asset,
        uint256 maxLTV,
        uint256 liquidationThreshold,
        uint256 liquidationBonus
    ) external;
    
    function updateCollateralFactor(
        address asset,
        uint256 newFactor
    ) external;
    
    function setLiquidationIncentive(
        address asset,
        uint256 incentive
    ) external;
    
    function enableAssetAsCollateral(
        address asset
    ) external;
    
    function disableAssetAsCollateral(
        address asset
    ) external;
    
    // Emergency functions
    function emergencyPause() external;
    
    function emergencyUnpause() external;
    
    function emergencyLiquidate(
        bytes32 loanId,
        string calldata reason
    ) external;
    
    function emergencyWithdraw(
        address asset,
        uint256 amount,
        address to
    ) external;
    
    // View functions - Loan information
    function getLoan(
        bytes32 loanId
    ) external view returns (Loan memory);
    
    function getUserLoans(
        address borrower
    ) external view returns (bytes32[] memory);
    
    function getActiveLoans(
        address borrower
    ) external view returns (bytes32[] memory);
    
    function getLoanStatus(
        bytes32 loanId
    ) external view returns (LoanStatus);
    
    function getLoanDebt(
        bytes32 loanId
    ) external view returns (uint256 totalDebt, uint256 principal, uint256 interest);
    
    // View functions - Collateral information
    function getCollateral(
        bytes32 loanId,
        address collateralAsset
    ) external view returns (Collateral memory);
    
    function getAllCollateral(
        bytes32 loanId
    ) external view returns (address[] memory assets, uint256[] memory amounts);
    
    function getCollateralValue(
        bytes32 loanId
    ) external view returns (uint256 totalValue);
    
    function getCollateralRatio(
        bytes32 loanId
    ) external view returns (uint256 ratio);
    
    // View functions - Position information
    function getBorrowPosition(
        address borrower
    ) external view returns (
        uint256 totalBorrowed,
        uint256 totalCollateral,
        uint256 healthFactor,
        uint256 borrowingPower
    );
    
    function getUserUtilization(
        address borrower
    ) external view returns (uint256 utilizationRate);
    
    function getMaxBorrowAmount(
        address borrower,
        address asset
    ) external view returns (uint256 maxAmount);
    
    function canBorrow(
        address borrower,
        address asset,
        uint256 amount
    ) external view returns (bool);
    
    // View functions - Interest rates
    function getInterestRateModel(
        address asset
    ) external view returns (InterestRateModel memory);
    
    function getCurrentBorrowRate(
        address asset
    ) external view returns (uint256 rate);
    
    function getCurrentSupplyRate(
        address asset
    ) external view returns (uint256 rate);
    
    function calculateInterestRate(
        address asset,
        uint256 utilizationRate
    ) external view returns (uint256 borrowRate, uint256 supplyRate);
    
    // View functions - Pool information
    function getLendingPool(
        address asset
    ) external view returns (LendingPool memory);
    
    function getPoolUtilization(
        address asset
    ) external view returns (uint256 utilizationRate);
    
    function getAvailableLiquidity(
        address asset
    ) external view returns (uint256 liquidity);
    
    function getTotalBorrowed(
        address asset
    ) external view returns (uint256 totalBorrowed);
    
    function getTotalSupplied(
        address asset
    ) external view returns (uint256 totalSupplied);
    
    // View functions - Credit information
    function getCreditProfile(
        address user
    ) external view returns (CreditProfile memory);
    
    function getCreditScore(
        address user
    ) external view returns (uint256 score);
    
    function getCreditLimit(
        address user,
        address asset
    ) external view returns (uint256 limit);
    
    function isCreditWorthy(
        address user,
        uint256 amount
    ) external view returns (bool);
    
    // View functions - Risk parameters
    function getRiskParameters(
        address asset
    ) external view returns (RiskParameters memory);
    
    function getLiquidationThreshold(
        address asset
    ) external view returns (uint256 threshold);
    
    function getLiquidationBonus(
        address asset
    ) external view returns (uint256 bonus);
    
    function getMaxLTV(
        address asset
    ) external view returns (uint256 ltv);
    
    // View functions - Flash loans
    function getFlashLoan(
        bytes32 flashLoanId
    ) external view returns (FlashLoan memory);
    
    function getActiveFlashLoans(
        address borrower
    ) external view returns (bytes32[] memory);
    
    function isFlashLoanAvailable(
        address asset,
        uint256 amount
    ) external view returns (bool);
    
    function getFlashLoanCapacity(
        address asset
    ) external view returns (uint256 capacity);
    
    // View functions - Calculations
    function calculateLoanInterest(
        bytes32 loanId
    ) external view returns (uint256 interest);
    
    function calculateRepaymentAmount(
        bytes32 loanId,
        uint256 repaymentAmount
    ) external view returns (uint256 principal, uint256 interest);
    
    function calculateLiquidationAmount(
        bytes32 loanId,
        address collateralAsset
    ) external view returns (uint256 liquidationAmount, uint256 bonus);
    
    function calculateBorrowFee(
        address asset,
        uint256 amount
    ) external view returns (uint256 fee);
    
    // View functions - Global statistics
    function getTotalValueBorrowed() external view returns (uint256);
    
    function getTotalValueCollateral() external view returns (uint256);
    
    function getGlobalUtilizationRate() external view returns (uint256);
    
    function getTotalActiveLoans() external view returns (uint256);
    
    function getTotalBorrowers() external view returns (uint256);
    
    function getAverageCreditScore() external view returns (uint256);
    
    function getSupportedAssets() external view returns (address[] memory);
    
    function getCollateralAssets() external view returns (address[] memory);
    
    // View functions - Health checks
    function isSystemHealthy() external view returns (bool);
    
    function getSystemHealth() external view returns (
        bool isHealthy,
        uint256 totalRisk,
        uint256 liquidityRisk,
        uint256 creditRisk
    );
    
    function isAssetHealthy(
        address asset
    ) external view returns (bool);
    
    function getAssetRisk(
        address asset
    ) external view returns (uint256 riskLevel);
}
