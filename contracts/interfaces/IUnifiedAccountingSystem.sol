// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IUnifiedAccountingSystem
 * @dev Interface for the Unified Accounting System contract
 * @author CoreLiquid Protocol
 */
interface IUnifiedAccountingSystem {
    // Events
    event AccountCreated(
        address indexed user,
        bytes32 indexed accountId,
        uint256 timestamp
    );
    
    event BalanceUpdated(
        address indexed user,
        address indexed asset,
        uint256 oldBalance,
        uint256 newBalance,
        string reason,
        uint256 timestamp
    );
    
    event CrossProtocolTransfer(
        address indexed from,
        address indexed to,
        address indexed asset,
        uint256 amount,
        string fromProtocol,
        string toProtocol,
        uint256 timestamp
    );
    
    event PositionOpened(
        address indexed user,
        bytes32 indexed positionId,
        address indexed asset,
        uint256 amount,
        string protocol,
        uint256 timestamp
    );
    
    event PositionClosed(
        address indexed user,
        bytes32 indexed positionId,
        address indexed asset,
        uint256 amount,
        uint256 pnl,
        string protocol,
        uint256 timestamp
    );
    
    event YieldAccrued(
        address indexed user,
        address indexed asset,
        uint256 yieldAmount,
        string source,
        uint256 timestamp
    );
    
    event FeesCollected(
        address indexed user,
        address indexed asset,
        uint256 feeAmount,
        string feeType,
        uint256 timestamp
    );
    
    event AccountingSnapshotCreated(
        uint256 indexed snapshotId,
        uint256 totalAssets,
        uint256 totalLiabilities,
        uint256 netWorth,
        uint256 timestamp
    );

    // Structs
    struct AccountInfo {
        bytes32 accountId;
        address owner;
        uint256 createdAt;
        uint256 lastActivity;
        bool isActive;
        bool isVerified;
        uint256 totalAssets;
        uint256 totalLiabilities;
        uint256 netWorth;
        uint256 riskScore;
    }
    
    struct AssetBalance {
        address asset;
        uint256 available;
        uint256 locked;
        uint256 staked;
        uint256 borrowed;
        uint256 collateral;
        uint256 totalBalance;
        uint256 lastUpdate;
    }
    
    struct Position {
        bytes32 positionId;
        address user;
        address asset;
        string protocol;
        uint256 amount;
        uint256 entryPrice;
        uint256 currentPrice;
        uint256 unrealizedPnL;
        uint256 realizedPnL;
        uint256 openedAt;
        uint256 lastUpdate;
        bool isOpen;
        bool isLong;
    }
    
    struct YieldInfo {
        address asset;
        uint256 totalYield;
        uint256 dailyYield;
        uint256 weeklyYield;
        uint256 monthlyYield;
        uint256 annualizedYield;
        uint256 lastAccrual;
        string[] sources;
        uint256[] sourceYields;
    }
    
    struct FeeInfo {
        address asset;
        uint256 totalFees;
        uint256 tradingFees;
        uint256 managementFees;
        uint256 performanceFees;
        uint256 withdrawalFees;
        uint256 lastCollection;
        string[] feeTypes;
        uint256[] feeAmounts;
    }
    
    struct ProtocolBalance {
        string protocolName;
        address protocolAddress;
        address asset;
        uint256 balance;
        uint256 yield;
        uint256 fees;
        uint256 lastSync;
        bool isActive;
    }
    
    struct AccountingSnapshot {
        uint256 snapshotId;
        uint256 timestamp;
        uint256 totalAssets;
        uint256 totalLiabilities;
        uint256 netWorth;
        uint256 totalYield;
        uint256 totalFees;
        uint256 activeUsers;
        uint256 totalPositions;
    }

    // Core accounting functions
    function createAccount(
        address user
    ) external returns (bytes32 accountId);
    
    function updateBalance(
        address user,
        address asset,
        uint256 amount,
        bool isIncrease,
        string calldata reason
    ) external;
    
    function transferBalance(
        address from,
        address to,
        address asset,
        uint256 amount,
        string calldata reason
    ) external;
    
    function lockBalance(
        address user,
        address asset,
        uint256 amount,
        string calldata reason
    ) external;
    
    function unlockBalance(
        address user,
        address asset,
        uint256 amount,
        string calldata reason
    ) external;
    
    function recordDeposit(
        address user,
        address asset,
        uint256 amount,
        string calldata protocol
    ) external;
    
    function recordWithdrawal(
        address user,
        address asset,
        uint256 amount,
        string calldata protocol
    ) external;
    
    // Position management
    function openPosition(
        address user,
        address asset,
        uint256 amount,
        uint256 entryPrice,
        bool isLong,
        string calldata protocol
    ) external returns (bytes32 positionId);
    
    function closePosition(
        bytes32 positionId,
        uint256 exitPrice
    ) external returns (uint256 pnl);
    
    function updatePosition(
        bytes32 positionId,
        uint256 currentPrice
    ) external;
    
    function liquidatePosition(
        bytes32 positionId,
        uint256 liquidationPrice,
        string calldata reason
    ) external returns (uint256 liquidationAmount);
    
    // Yield and fee tracking
    function recordYield(
        address user,
        address asset,
        uint256 yieldAmount,
        string calldata source
    ) external;
    
    function recordFee(
        address user,
        address asset,
        uint256 feeAmount,
        string calldata feeType
    ) external;
    
    function distributeYield(
        address asset,
        uint256 totalYield,
        address[] calldata users,
        uint256[] calldata amounts
    ) external;
    
    function collectFees(
        address asset,
        uint256 totalFees,
        string calldata feeType
    ) external;
    
    // Cross-protocol operations
    function recordCrossProtocolTransfer(
        address user,
        address asset,
        uint256 amount,
        string calldata fromProtocol,
        string calldata toProtocol
    ) external;
    
    function syncProtocolBalance(
        address user,
        string calldata protocol,
        address asset,
        uint256 balance
    ) external;
    
    function reconcileProtocolBalances(
        address user,
        address asset
    ) external;
    
    // Snapshot and reporting
    function createSnapshot() external returns (uint256 snapshotId);
    
    function updateAccountMetrics(
        address user
    ) external;
    
    function calculateNetWorth(
        address user
    ) external returns (uint256 netWorth);
    
    function calculateRiskScore(
        address user
    ) external returns (uint256 riskScore);
    
    // Administrative functions
    function addSupportedAsset(
        address asset,
        string calldata symbol,
        uint8 decimals
    ) external;
    
    function removeSupportedAsset(
        address asset
    ) external;
    
    function addProtocol(
        string calldata protocolName,
        address protocolAddress
    ) external;
    
    function removeProtocol(
        string calldata protocolName
    ) external;
    
    function pauseAccount(
        address user,
        string calldata reason
    ) external;
    
    function unpauseAccount(
        address user
    ) external;
    
    // View functions - Account info
    function getAccountInfo(
        address user
    ) external view returns (AccountInfo memory);
    
    function getAssetBalance(
        address user,
        address asset
    ) external view returns (AssetBalance memory);
    
    function getAllBalances(
        address user
    ) external view returns (AssetBalance[] memory);
    
    function getAvailableBalance(
        address user,
        address asset
    ) external view returns (uint256);
    
    function getLockedBalance(
        address user,
        address asset
    ) external view returns (uint256);
    
    function getTotalBalance(
        address user,
        address asset
    ) external view returns (uint256);
    
    // View functions - Positions
    function getPosition(
        bytes32 positionId
    ) external view returns (Position memory);
    
    function getUserPositions(
        address user
    ) external view returns (Position[] memory);
    
    function getOpenPositions(
        address user
    ) external view returns (Position[] memory);
    
    function getPositionsByAsset(
        address user,
        address asset
    ) external view returns (Position[] memory);
    
    function getPositionsByProtocol(
        address user,
        string calldata protocol
    ) external view returns (Position[] memory);
    
    // View functions - Yield and fees
    function getYieldInfo(
        address user,
        address asset
    ) external view returns (YieldInfo memory);
    
    function getFeeInfo(
        address user,
        address asset
    ) external view returns (FeeInfo memory);
    
    function getTotalYield(
        address user
    ) external view returns (uint256);
    
    function getTotalFees(
        address user
    ) external view returns (uint256);
    
    function getYieldByPeriod(
        address user,
        address asset,
        uint256 startTime,
        uint256 endTime
    ) external view returns (uint256);
    
    // View functions - Protocol balances
    function getProtocolBalance(
        address user,
        string calldata protocol,
        address asset
    ) external view returns (uint256);
    
    function getAllProtocolBalances(
        address user
    ) external view returns (ProtocolBalance[] memory);
    
    function getProtocolBalancesByAsset(
        address user,
        address asset
    ) external view returns (ProtocolBalance[] memory);
    
    // View functions - Calculations
    function calculateUnrealizedPnL(
        address user
    ) external view returns (uint256);
    
    function calculateRealizedPnL(
        address user,
        uint256 startTime,
        uint256 endTime
    ) external view returns (uint256);
    
    function calculatePortfolioValue(
        address user
    ) external view returns (uint256);
    
    function calculateCollateralRatio(
        address user
    ) external view returns (uint256);
    
    function calculateLiquidationThreshold(
        address user
    ) external view returns (uint256);
    
    // View functions - Risk metrics
    function getUserRiskScore(
        address user
    ) external view returns (uint256);
    
    function getPortfolioRisk(
        address user
    ) external view returns (uint256);
    
    function getExposureByAsset(
        address user
    ) external view returns (address[] memory assets, uint256[] memory exposures);
    
    function getExposureByProtocol(
        address user
    ) external view returns (string[] memory protocols, uint256[] memory exposures);
    
    // View functions - Global statistics
    function getTotalUsers() external view returns (uint256);
    
    function getTotalAssets() external view returns (uint256);
    
    function getTotalLiabilities() external view returns (uint256);
    
    function getGlobalNetWorth() external view returns (uint256);
    
    function getTotalYieldGenerated() external view returns (uint256);
    
    function getTotalFeesCollected() external view returns (uint256);
    
    function getActivePositions() external view returns (uint256);
    
    function getSupportedAssets() external view returns (address[] memory);
    
    function getSupportedProtocols() external view returns (string[] memory);
    
    // View functions - Snapshots
    function getSnapshot(
        uint256 snapshotId
    ) external view returns (
        uint256 timestamp,
        uint256 totalAssets,
        uint256 totalLiabilities,
        uint256 netWorth,
        uint256 totalYield,
        uint256 totalFees
    );
    
    function getLatestSnapshot() external view returns (
        uint256 snapshotId,
        uint256 timestamp,
        uint256 totalAssets,
        uint256 totalLiabilities,
        uint256 netWorth
    );
    
    function getSnapshotHistory(
        uint256 limit
    ) external view returns (uint256[] memory snapshotIds);
    
    // View functions - Account status
    function isAccountActive(
        address user
    ) external view returns (bool);
    
    function isAccountVerified(
        address user
    ) external view returns (bool);
    
    function hasAccount(
        address user
    ) external view returns (bool);
    
    function canTransfer(
        address from,
        address to,
        address asset,
        uint256 amount
    ) external view returns (bool);
    
    function canWithdraw(
        address user,
        address asset,
        uint256 amount
    ) external view returns (bool);
}
