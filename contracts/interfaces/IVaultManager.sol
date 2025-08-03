// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IVaultManager
 * @dev Interface for the Vault Manager contract
 * @author CoreLiquid Protocol
 */
interface IVaultManager {
    // Events
    event VaultCreated(
        address indexed vault,
        address indexed asset,
        address indexed strategy,
        uint256 timestamp
    );
    
    event VaultDeposit(
        address indexed vault,
        address indexed user,
        uint256 amount,
        uint256 shares,
        uint256 timestamp
    );
    
    event VaultWithdrawal(
        address indexed vault,
        address indexed user,
        uint256 shares,
        uint256 amount,
        uint256 timestamp
    );
    
    event StrategyUpdated(
        address indexed vault,
        address indexed oldStrategy,
        address indexed newStrategy,
        uint256 timestamp
    );
    
    event YieldHarvested(
        address indexed vault,
        uint256 yield,
        uint256 fee,
        uint256 timestamp
    );
    
    event VaultPaused(
        address indexed vault,
        string reason,
        uint256 timestamp
    );
    
    event VaultUnpaused(
        address indexed vault,
        uint256 timestamp
    );

    // Structs
    struct VaultInfo {
        address vaultAddress;
        address asset;
        address strategy;
        string name;
        string symbol;
        uint256 totalAssets;
        uint256 totalShares;
        uint256 performanceFee;
        uint256 managementFee;
        uint256 lastHarvest;
        uint256 createdAt;
        bool isActive;
        bool isPaused;
    }
    
    struct UserPosition {
        uint256 shares;
        uint256 assets;
        uint256 lastDeposit;
        uint256 totalDeposited;
        uint256 totalWithdrawn;
        uint256 yieldEarned;
    }
    
    struct VaultMetrics {
        uint256 totalValueLocked;
        uint256 totalYieldGenerated;
        uint256 totalFeesCollected;
        uint256 averageAPY;
        uint256 sharpeRatio;
        uint256 maxDrawdown;
        uint256 volatility;
        uint256 totalUsers;
    }
    
    struct StrategyConfig {
        address strategyAddress;
        string name;
        uint256 riskLevel;
        uint256 expectedAPY;
        uint256 maxTVL;
        uint256 minDeposit;
        bool isActive;
        bool isVerified;
    }

    // Core vault functions
    function createVault(
        address asset,
        address strategy,
        string calldata name,
        string calldata symbol,
        uint256 performanceFee,
        uint256 managementFee
    ) external returns (address vault);
    
    function deposit(
        address vault,
        uint256 amount,
        address receiver
    ) external returns (uint256 shares);
    
    function withdraw(
        address vault,
        uint256 shares,
        address receiver
    ) external returns (uint256 amount);
    
    function redeem(
        address vault,
        uint256 amount,
        address receiver
    ) external returns (uint256 shares);
    
    // Strategy management
    function updateStrategy(
        address vault,
        address newStrategy
    ) external;
    
    function harvestYield(address vault) external returns (uint256 yield);
    
    function rebalanceVault(address vault) external;
    
    // Vault administration
    function pauseVault(address vault, string calldata reason) external;
    
    function unpauseVault(address vault) external;
    
    function setPerformanceFee(address vault, uint256 fee) external;
    
    function setManagementFee(address vault, uint256 fee) external;
    
    function emergencyWithdraw(address vault, address asset, uint256 amount) external;
    
    // Strategy registration
    function registerStrategy(
        address strategy,
        string calldata name,
        uint256 riskLevel,
        uint256 expectedAPY,
        uint256 maxTVL
    ) external;
    
    function deregisterStrategy(address strategy) external;
    
    function verifyStrategy(address strategy) external;
    
    // View functions
    function getVaultInfo(address vault) external view returns (VaultInfo memory);
    
    function getUserPosition(address vault, address user) external view returns (UserPosition memory);
    
    function getVaultMetrics(address vault) external view returns (VaultMetrics memory);
    
    function getStrategyConfig(address strategy) external view returns (StrategyConfig memory);
    
    function getAllVaults() external view returns (address[] memory);
    
    function getVaultsByAsset(address asset) external view returns (address[] memory);
    
    function getVaultsByStrategy(address strategy) external view returns (address[] memory);
    
    function getUserVaults(address user) external view returns (address[] memory);
    
    function getRegisteredStrategies() external view returns (address[] memory);
    
    // Asset and share calculations
    function convertToShares(address vault, uint256 assets) external view returns (uint256 shares);
    
    function convertToAssets(address vault, uint256 shares) external view returns (uint256 assets);
    
    function previewDeposit(address vault, uint256 assets) external view returns (uint256 shares);
    
    function previewWithdraw(address vault, uint256 shares) external view returns (uint256 assets);
    
    function maxDeposit(address vault, address user) external view returns (uint256 maxAssets);
    
    function maxWithdraw(address vault, address user) external view returns (uint256 maxAssets);
    
    // Yield and performance
    function getVaultAPY(address vault) external view returns (uint256 apy);
    
    function getVaultTVL(address vault) external view returns (uint256 tvl);
    
    function getVaultYield(address vault, uint256 period) external view returns (uint256 yield);
    
    function getUserYield(address vault, address user) external view returns (uint256 yield);
    
    function getPerformanceMetrics(address vault, uint256 period) external view returns (
        uint256 totalReturn,
        uint256 sharpeRatio,
        uint256 maxDrawdown,
        uint256 volatility
    );
    
    // Risk management
    function getVaultRiskLevel(address vault) external view returns (uint256 riskLevel);
    
    function isVaultHealthy(address vault) external view returns (bool);
    
    function getVaultUtilization(address vault) external view returns (uint256 utilization);
    
    function checkVaultLimits(address vault, uint256 depositAmount) external view returns (bool);
    
    // Fee calculations
    function calculatePerformanceFee(address vault, uint256 yield) external view returns (uint256 fee);
    
    function calculateManagementFee(address vault, uint256 period) external view returns (uint256 fee);
    
    function getTotalFees(address vault) external view returns (uint256 totalFees);
    
    // Vault status
    function isVaultActive(address vault) external view returns (bool);
    
    function isVaultPaused(address vault) external view returns (bool);
    
    function getVaultStatus(address vault) external view returns (string memory status);
    
    // Global statistics
    function getTotalTVL() external view returns (uint256 totalTVL);
    
    function getTotalVaults() external view returns (uint256 totalVaults);
    
    function getTotalUsers() external view returns (uint256 totalUsers);
    
    function getAverageAPY() external view returns (uint256 averageAPY);
    
    function getTotalYieldGenerated() external view returns (uint256 totalYield);
}
