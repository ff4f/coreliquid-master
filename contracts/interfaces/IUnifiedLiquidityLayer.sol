// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IUnifiedLiquidityLayer
 * @dev Interface for the Unified Liquidity Layer contract
 * @author CoreLiquid Protocol
 */
interface IUnifiedLiquidityLayer {
    // Events
    event LiquidityAdded(
        address indexed provider,
        address indexed asset,
        uint256 amount,
        uint256 shares,
        string protocol,
        uint256 timestamp
    );
    
    event LiquidityRemoved(
        address indexed provider,
        address indexed asset,
        uint256 amount,
        uint256 shares,
        string protocol,
        uint256 timestamp
    );
    
    event LiquidityRebalanced(
        address indexed asset,
        string fromProtocol,
        string toProtocol,
        uint256 amount,
        uint256 timestamp
    );
    
    event ProtocolIntegrated(
        string indexed protocolName,
        address indexed protocolAddress,
        address indexed adapter,
        uint256 timestamp
    );
    
    event YieldHarvested(
        address indexed asset,
        string indexed protocol,
        uint256 yieldAmount,
        uint256 timestamp
    );
    
    event OptimizationExecuted(
        address indexed asset,
        uint256 totalOptimized,
        uint256 yieldImprovement,
        uint256 timestamp
    );
    
    event EmergencyWithdrawal(
        address indexed asset,
        string indexed protocol,
        uint256 amount,
        string reason,
        uint256 timestamp
    );
    
    event LiquidityUtilized(
        address indexed user,
        address indexed asset,
        uint256 amount,
        string purpose,
        uint256 timestamp
    );

    // Structs
    struct LiquidityPool {
        address asset;
        string protocol;
        uint256 totalLiquidity;
        uint256 availableLiquidity;
        uint256 utilizedLiquidity;
        uint256 totalShares;
        uint256 pricePerShare;
        uint256 apy;
        uint256 utilizationRate;
        uint256 lastUpdate;
        bool isActive;
        bool isOptimized;
    }
    
    struct ProviderInfo {
        address provider;
        address asset;
        string protocol;
        uint256 liquidityProvided;
        uint256 shares;
        uint256 yieldEarned;
        uint256 lastDeposit;
        uint256 lastWithdrawal;
        bool isActive;
    }
    
    struct ProtocolAdapter {
        string protocolName;
        address protocolAddress;
        address adapterAddress;
        bool isActive;
        bool isVerified;
        uint256 totalLiquidity;
        uint256 apy;
        uint256 riskScore;
        uint256 lastUpdate;
        string[] supportedAssets;
        uint256[] assetLimits;
    }
    
    struct OptimizationStrategy {
        address asset;
        string[] protocols;
        uint256[] allocations;
        uint256[] expectedAPYs;
        uint256 totalAllocation;
        uint256 expectedYield;
        uint256 riskScore;
        uint256 lastOptimization;
        bool isActive;
    }
    
    struct LiquidityMetrics {
        uint256 totalLiquidity;
        uint256 totalUtilized;
        uint256 totalYieldGenerated;
        uint256 averageAPY;
        uint256 utilizationRate;
        uint256 totalProviders;
        uint256 activeProtocols;
        uint256 lastMetricsUpdate;
    }
    
    struct RebalanceConfig {
        address asset;
        uint256 minRebalanceThreshold;
        uint256 maxSlippage;
        uint256 rebalanceFrequency;
        uint256 lastRebalance;
        bool autoRebalance;
        bool emergencyMode;
    }
    
    struct YieldDistribution {
        address asset;
        string protocol;
        uint256 totalYield;
        uint256 protocolFee;
        uint256 performanceFee;
        uint256 providerYield;
        uint256 distributedAt;
        address[] providers;
        uint256[] providerShares;
    }

    // Core liquidity functions
    function addLiquidity(
        address asset,
        uint256 amount,
        string calldata protocol
    ) external returns (uint256 shares);
    
    function removeLiquidity(
        address asset,
        uint256 shares,
        string calldata protocol
    ) external returns (uint256 amount);
    
    function utilizeLiquidity(
        address asset,
        uint256 amount,
        string calldata purpose
    ) external returns (bool success);
    
    function returnLiquidity(
        address asset,
        uint256 amount,
        string calldata purpose
    ) external;
    
    function rebalanceLiquidity(
        address asset
    ) external returns (uint256 totalRebalanced);
    
    function optimizeLiquidity(
        address asset
    ) external returns (uint256 yieldImprovement);
    
    // Advanced liquidity functions
    function flashLoan(
        address asset,
        uint256 amount,
        bytes calldata data
    ) external;
    
    function batchAddLiquidity(
        address[] calldata assets,
        uint256[] calldata amounts,
        string[] calldata protocols
    ) external returns (uint256[] memory shares);
    
    function batchRemoveLiquidity(
        address[] calldata assets,
        uint256[] calldata shares,
        string[] calldata protocols
    ) external returns (uint256[] memory amounts);
    
    function crossProtocolSwap(
        address fromAsset,
        address toAsset,
        uint256 amount,
        string calldata fromProtocol,
        string calldata toProtocol,
        uint256 minAmountOut
    ) external returns (uint256 amountOut);
    
    // Protocol management
    function integrateProtocol(
        string calldata protocolName,
        address protocolAddress,
        address adapterAddress,
        string[] calldata supportedAssets,
        uint256[] calldata assetLimits
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
    
    // Yield management
    function harvestYield(
        address asset,
        string calldata protocol
    ) external returns (uint256 yieldAmount);
    
    function harvestAllYields(
        address asset
    ) external returns (uint256 totalYield);
    
    function distributeYield(
        address asset,
        string calldata protocol
    ) external;
    
    function compoundYield(
        address asset,
        string calldata protocol
    ) external returns (uint256 compoundedAmount);
    
    function claimYield(
        address asset,
        string calldata protocol
    ) external returns (uint256 yieldAmount);
    
    // Optimization functions
    function createOptimizationStrategy(
        address asset,
        string[] calldata protocols,
        uint256[] calldata allocations
    ) external returns (bytes32 strategyId);
    
    function executeOptimizationStrategy(
        bytes32 strategyId
    ) external returns (uint256 yieldImprovement);
    
    function updateOptimizationStrategy(
        bytes32 strategyId,
        string[] calldata protocols,
        uint256[] calldata allocations
    ) external;
    
    function findOptimalAllocation(
        address asset,
        uint256 amount
    ) external view returns (
        string[] memory protocols,
        uint256[] memory allocations,
        uint256 expectedYield
    );
    
    // Configuration functions
    function setRebalanceConfig(
        address asset,
        uint256 minThreshold,
        uint256 maxSlippage,
        uint256 frequency,
        bool autoRebalance
    ) external;
    
    function setProtocolWeights(
        address asset,
        string[] calldata protocols,
        uint256[] calldata weights
    ) external;
    
    function setYieldFees(
        uint256 protocolFee,
        uint256 performanceFee
    ) external;
    
    function setEmergencyMode(
        bool enabled
    ) external;
    
    // Emergency functions
    function emergencyWithdrawAll(
        address asset,
        string calldata reason
    ) external;
    
    function emergencyWithdrawProtocol(
        address asset,
        string calldata protocol,
        string calldata reason
    ) external;
    
    function emergencyPauseAll() external;
    
    function emergencyUnpauseAll() external;
    
    function emergencyRebalance(
        address asset,
        string calldata reason
    ) external;
    
    // View functions - Pool information
    function getLiquidityPool(
        address asset,
        string calldata protocol
    ) external view returns (LiquidityPool memory);
    
    function getAllPools(
        address asset
    ) external view returns (LiquidityPool[] memory);
    
    function getActivePools(
        address asset
    ) external view returns (LiquidityPool[] memory);
    
    function getPoolsByProtocol(
        string calldata protocol
    ) external view returns (LiquidityPool[] memory);
    
    // View functions - Provider information
    function getProviderInfo(
        address provider,
        address asset,
        string calldata protocol
    ) external view returns (ProviderInfo memory);
    
    function getProviderPools(
        address provider
    ) external view returns (ProviderInfo[] memory);
    
    function getProviderYield(
        address provider,
        address asset,
        string calldata protocol
    ) external view returns (uint256);
    
    function getProviderShares(
        address provider,
        address asset,
        string calldata protocol
    ) external view returns (uint256);
    
    // View functions - Protocol information
    function getProtocolAdapter(
        string calldata protocolName
    ) external view returns (ProtocolAdapter memory);
    
    function getSupportedProtocols() external view returns (string[] memory);
    
    function getActiveProtocols() external view returns (string[] memory);
    
    function isProtocolSupported(
        string calldata protocolName
    ) external view returns (bool);
    
    function isProtocolActive(
        string calldata protocolName
    ) external view returns (bool);
    
    // View functions - Liquidity calculations
    function getTotalLiquidity(
        address asset
    ) external view returns (uint256);
    
    function getAvailableLiquidity(
        address asset
    ) external view returns (uint256);
    
    function getUtilizedLiquidity(
        address asset
    ) external view returns (uint256);
    
    function getUtilizationRate(
        address asset
    ) external view returns (uint256);
    
    function getLiquidityByProtocol(
        address asset,
        string calldata protocol
    ) external view returns (uint256);
    
    function calculateShares(
        address asset,
        uint256 amount,
        string calldata protocol
    ) external view returns (uint256 shares);
    
    function calculateAmount(
        address asset,
        uint256 shares,
        string calldata protocol
    ) external view returns (uint256 amount);
    
    // View functions - Yield calculations
    function getPoolAPY(
        address asset,
        string calldata protocol
    ) external view returns (uint256);
    
    function getAverageAPY(
        address asset
    ) external view returns (uint256);
    
    function getBestAPY(
        address asset
    ) external view returns (uint256 apy, string memory protocol);
    
    function getYieldProjection(
        address asset,
        uint256 amount,
        string calldata protocol,
        uint256 duration
    ) external view returns (uint256 projectedYield);
    
    function getPendingYield(
        address provider,
        address asset,
        string calldata protocol
    ) external view returns (uint256);
    
    // View functions - Optimization
    function getOptimizationStrategy(
        bytes32 strategyId
    ) external view returns (OptimizationStrategy memory);
    
    function getOptimalProtocol(
        address asset,
        uint256 amount
    ) external view returns (string memory protocol, uint256 expectedYield);
    
    function getRebalanceConfig(
        address asset
    ) external view returns (RebalanceConfig memory);
    
    function needsRebalancing(
        address asset
    ) external view returns (bool);
    
    function getOptimizationOpportunity(
        address asset
    ) external view returns (uint256 potentialYieldIncrease);
    
    // View functions - Metrics
    function getLiquidityMetrics(
        address asset
    ) external view returns (LiquidityMetrics memory);
    
    function getGlobalMetrics() external view returns (LiquidityMetrics memory);
    
    function getProtocolMetrics(
        string calldata protocol
    ) external view returns (
        uint256 totalLiquidity,
        uint256 apy,
        uint256 utilizationRate,
        uint256 riskScore
    );
    
    function getProviderMetrics(
        address provider
    ) external view returns (
        uint256 totalLiquidity,
        uint256 totalYield,
        uint256 averageAPY,
        uint256 activePools
    );
    
    // View functions - Risk assessment
    function getProtocolRisk(
        string calldata protocol
    ) external view returns (uint256 riskScore);
    
    function getPoolRisk(
        address asset,
        string calldata protocol
    ) external view returns (uint256 riskScore);
    
    function isPoolHealthy(
        address asset,
        string calldata protocol
    ) external view returns (bool);
    
    function getRiskAdjustedReturn(
        address asset,
        string calldata protocol
    ) external view returns (uint256);
    
    // View functions - Capacity and limits
    function getPoolCapacity(
        address asset,
        string calldata protocol
    ) external view returns (uint256 capacity, uint256 available);
    
    function canAddLiquidity(
        address asset,
        uint256 amount,
        string calldata protocol
    ) external view returns (bool);
    
    function canUtilizeLiquidity(
        address asset,
        uint256 amount
    ) external view returns (bool);
    
    function getMaxUtilizable(
        address asset
    ) external view returns (uint256);
    
    // View functions - Global statistics
    function getTotalValueLocked() external view returns (uint256);
    
    function getTotalProviders() external view returns (uint256);
    
    function getTotalYieldGenerated() external view returns (uint256);
    
    function getGlobalUtilizationRate() external view returns (uint256);
    
    function getGlobalAPY() external view returns (uint256);
    
    function getSupportedAssets() external view returns (address[] memory);
    
    function getActiveAssets() external view returns (address[] memory);
    
    // Cross-protocol access function
    /**
     * @dev Access assets from shared pool without withdrawal
     * @notice Enables cross-protocol access to liquidity without actual token movement
     * @param token The asset token address to access
     * @param amount The amount of tokens to access
     * @param user The user address requesting access
     * @param data Additional data for the access operation
     * @return success Whether the access operation was successful
     */
    function accessAssets(
        address token,
        uint256 amount,
        address user,
        bytes calldata data
    ) external returns (bool success);
}
