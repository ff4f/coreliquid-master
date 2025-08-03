// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IInfiniteLiquidityEngine
 * @dev Interface for the Infinite Liquidity Engine contract
 * @author CoreLiquid Protocol
 */
interface IInfiniteLiquidityEngine {
    // Events
    event LiquiditySourceAdded(
        bytes32 indexed sourceId,
        string indexed sourceName,
        address indexed sourceAddress,
        uint256 capacity,
        uint256 timestamp
    );
    
    event LiquiditySourceRemoved(
        bytes32 indexed sourceId,
        string indexed sourceName,
        uint256 timestamp
    );
    
    event LiquidityAggregated(
        address indexed asset,
        uint256 totalLiquidity,
        uint256 sourcesCount,
        uint256 timestamp
    );
    
    event VirtualLiquidityCreated(
        bytes32 indexed virtualPoolId,
        address indexed asset,
        uint256 virtualAmount,
        uint256 backingRatio,
        uint256 timestamp
    );
    
    event LiquidityRouted(
        bytes32 indexed routeId,
        address indexed user,
        address indexed asset,
        uint256 amount,
        string[] sources,
        uint256[] allocations,
        uint256 timestamp
    );
    
    event FlashLiquidityProvided(
        bytes32 indexed flashId,
        address indexed user,
        address indexed asset,
        uint256 amount,
        uint256 fee,
        uint256 timestamp
    );
    
    event LiquidityOptimized(
        address indexed asset,
        uint256 oldEfficiency,
        uint256 newEfficiency,
        uint256 timestamp
    );
    
    event EmergencyLiquidityActivated(
        address indexed asset,
        uint256 emergencyAmount,
        string reason,
        uint256 timestamp
    );
    
    event CrossChainLiquidityBridged(
        bytes32 indexed bridgeId,
        address indexed asset,
        uint256 amount,
        uint256 sourceChain,
        uint256 targetChain,
        uint256 timestamp
    );

    // Structs
    struct LiquiditySource {
        bytes32 sourceId;
        string name;
        address sourceAddress;
        address adapter;
        uint256 totalCapacity;
        uint256 availableCapacity;
        uint256 utilizationRate;
        uint256 apy;
        uint256 riskScore;
        uint256 latency;
        uint256 reliability;
        bool isActive;
        bool isVerified;
        uint256 lastUpdate;
        string[] supportedAssets;
        mapping(address => uint256) assetCapacities;
    }
    
    struct VirtualLiquidityPool {
        bytes32 poolId;
        address asset;
        uint256 virtualAmount;
        uint256 realAmount;
        uint256 backingRatio;
        uint256 utilizationRate;
        uint256 efficiency;
        uint256 createdAt;
        uint256 lastUpdate;
        bool isActive;
        bytes32[] backingSources;
        uint256[] sourceAllocations;
    }
    
    struct LiquidityRoute {
        bytes32 routeId;
        address asset;
        uint256 totalAmount;
        uint256 sourcesCount;
        bytes32[] sources;
        uint256[] allocations;
        uint256[] expectedReturns;
        uint256 totalExpectedReturn;
        uint256 routeEfficiency;
        uint256 executionTime;
        uint256 createdAt;
        bool isOptimal;
        bool isExecuted;
    }
    
    struct FlashLiquidity {
        bytes32 flashId;
        address user;
        address asset;
        uint256 amount;
        uint256 fee;
        uint256 deadline;
        bytes32[] sources;
        uint256[] sourceAmounts;
        uint256 requestedAt;
        uint256 executedAt;
        bool isActive;
        bool isRepaid;
    }
    
    struct LiquidityMetrics {
        address asset;
        uint256 totalLiquidity;
        uint256 availableLiquidity;
        uint256 virtualLiquidity;
        uint256 utilizationRate;
        uint256 efficiency;
        uint256 averageAPY;
        uint256 sourcesCount;
        uint256 lastUpdate;
    }
    
    struct OptimizationConfig {
        address asset;
        uint256 targetUtilization;
        uint256 maxSlippage;
        uint256 rebalanceThreshold;
        uint256 optimizationFrequency;
        uint256 lastOptimization;
        bool autoOptimize;
        bool emergencyMode;
    }
    
    struct CrossChainLiquidity {
        bytes32 bridgeId;
        address asset;
        uint256 amount;
        uint256 sourceChain;
        uint256 targetChain;
        address sourceAddress;
        address targetAddress;
        uint256 bridgeFee;
        uint256 estimatedTime;
        uint256 initiatedAt;
        uint256 completedAt;
        bool isCompleted;
        bool isFailed;
        string status;
    }
    
    struct EmergencyLiquidity {
        address asset;
        uint256 reserveAmount;
        uint256 emergencyThreshold;
        uint256 activationCount;
        uint256 lastActivation;
        bool isActive;
        bytes32[] emergencySources;
        uint256[] sourceCapacities;
    }

    // Core liquidity functions
    function aggregateLiquidity(
        address asset
    ) external returns (uint256 totalLiquidity);
    
    function provideLiquidity(
        address asset,
        uint256 amount,
        bytes32[] calldata preferredSources
    ) external returns (bytes32 routeId);
    
    function requestLiquidity(
        address asset,
        uint256 amount,
        uint256 maxSlippage
    ) external returns (bytes32 routeId, uint256 actualAmount);
    
    function optimizeLiquidityAllocation(
        address asset
    ) external returns (uint256 newEfficiency);
    
    function rebalanceLiquidity(
        address asset
    ) external returns (uint256 rebalancedAmount);
    
    // Virtual liquidity functions
    function createVirtualPool(
        address asset,
        uint256 virtualAmount,
        uint256 backingRatio,
        bytes32[] calldata backingSources
    ) external returns (bytes32 poolId);
    
    function expandVirtualPool(
        bytes32 poolId,
        uint256 additionalAmount
    ) external returns (uint256 newVirtualAmount);
    
    function contractVirtualPool(
        bytes32 poolId,
        uint256 reductionAmount
    ) external returns (uint256 newVirtualAmount);
    
    function liquidateVirtualPool(
        bytes32 poolId,
        string calldata reason
    ) external returns (uint256 recoveredAmount);
    
    // Flash liquidity functions
    function requestFlashLiquidity(
        address asset,
        uint256 amount,
        uint256 deadline,
        bytes calldata data
    ) external returns (bytes32 flashId);
    
    function repayFlashLiquidity(
        bytes32 flashId
    ) external;
    
    function calculateFlashFee(
        address asset,
        uint256 amount
    ) external view returns (uint256 fee);
    
    function getMaxFlashAmount(
        address asset
    ) external view returns (uint256 maxAmount);
    
    // Source management
    function addLiquiditySource(
        string calldata name,
        address sourceAddress,
        address adapter,
        uint256 capacity,
        string[] calldata supportedAssets
    ) external returns (bytes32 sourceId);
    
    function removeLiquiditySource(
        bytes32 sourceId
    ) external;
    
    function updateSourceCapacity(
        bytes32 sourceId,
        uint256 newCapacity
    ) external;
    
    function pauseSource(
        bytes32 sourceId,
        string calldata reason
    ) external;
    
    function unpauseSource(
        bytes32 sourceId
    ) external;
    
    function verifySource(
        bytes32 sourceId
    ) external;
    
    // Route optimization
    function findOptimalRoute(
        address asset,
        uint256 amount,
        uint256 maxSources
    ) external view returns (
        bytes32[] memory sources,
        uint256[] memory allocations,
        uint256 expectedReturn
    );
    
    function executeOptimalRoute(
        bytes32 routeId
    ) external returns (uint256 actualReturn);
    
    function createCustomRoute(
        address asset,
        uint256 amount,
        bytes32[] calldata sources,
        uint256[] calldata allocations
    ) external returns (bytes32 routeId);
    
    function validateRoute(
        bytes32 routeId
    ) external view returns (bool isValid, string memory reason);
    
    // Cross-chain liquidity
    function bridgeLiquidity(
        address asset,
        uint256 amount,
        uint256 targetChain,
        address targetAddress
    ) external returns (bytes32 bridgeId);
    
    function completeCrossChainTransfer(
        bytes32 bridgeId,
        bytes calldata proof
    ) external;
    
    function cancelCrossChainTransfer(
        bytes32 bridgeId,
        string calldata reason
    ) external;
    
    function estimateBridgeFee(
        address asset,
        uint256 amount,
        uint256 targetChain
    ) external view returns (uint256 fee, uint256 estimatedTime);
    
    // Emergency functions
    function activateEmergencyLiquidity(
        address asset,
        string calldata reason
    ) external returns (uint256 emergencyAmount);
    
    function deactivateEmergencyLiquidity(
        address asset
    ) external;
    
    function setEmergencyReserve(
        address asset,
        uint256 reserveAmount,
        uint256 threshold
    ) external;
    
    function emergencyDrain(
        address asset,
        uint256 amount,
        address to,
        string calldata reason
    ) external;
    
    // Configuration functions
    function setOptimizationConfig(
        address asset,
        uint256 targetUtilization,
        uint256 maxSlippage,
        uint256 rebalanceThreshold,
        bool autoOptimize
    ) external;
    
    function setGlobalParameters(
        uint256 maxSources,
        uint256 defaultSlippage,
        uint256 flashFeeRate,
        uint256 optimizationInterval
    ) external;
    
    function setEmergencyMode(
        bool enabled,
        string calldata reason
    ) external;
    
    function updateSourceWeights(
        bytes32[] calldata sourceIds,
        uint256[] calldata weights
    ) external;
    
    // View functions - Liquidity information
    function getTotalLiquidity(
        address asset
    ) external view returns (uint256);
    
    function getAvailableLiquidity(
        address asset
    ) external view returns (uint256);
    
    function getVirtualLiquidity(
        address asset
    ) external view returns (uint256);
    
    function getLiquidityMetrics(
        address asset
    ) external view returns (LiquidityMetrics memory);
    
    function getLiquidityDistribution(
        address asset
    ) external view returns (
        bytes32[] memory sources,
        uint256[] memory amounts,
        uint256[] memory percentages
    );
    
    // View functions - Source information
    function getLiquiditySource(
        bytes32 sourceId
    ) external view returns (
        string memory name,
        address sourceAddress,
        uint256 capacity,
        uint256 utilization,
        uint256 apy,
        bool isActive
    );
    
    function getAllSources() external view returns (bytes32[] memory);
    
    function getActiveSources() external view returns (bytes32[] memory);
    
    function getSourcesByAsset(
        address asset
    ) external view returns (bytes32[] memory);
    
    function isSourceActive(
        bytes32 sourceId
    ) external view returns (bool);
    
    // View functions - Virtual pools
    function getVirtualPool(
        bytes32 poolId
    ) external view returns (VirtualLiquidityPool memory);
    
    function getVirtualPoolsByAsset(
        address asset
    ) external view returns (bytes32[] memory);
    
    function getVirtualPoolEfficiency(
        bytes32 poolId
    ) external view returns (uint256);
    
    function getTotalVirtualLiquidity(
        address asset
    ) external view returns (uint256);
    
    // View functions - Routes
    function getLiquidityRoute(
        bytes32 routeId
    ) external view returns (LiquidityRoute memory);
    
    function getActiveRoutes(
        address asset
    ) external view returns (bytes32[] memory);
    
    function getRouteEfficiency(
        bytes32 routeId
    ) external view returns (uint256);
    
    function estimateRouteReturn(
        address asset,
        uint256 amount,
        bytes32[] calldata sources,
        uint256[] calldata allocations
    ) external view returns (uint256 expectedReturn);
    
    // View functions - Flash liquidity
    function getFlashLiquidity(
        bytes32 flashId
    ) external view returns (FlashLiquidity memory);
    
    function getActiveFlashLoans(
        address user
    ) external view returns (bytes32[] memory);
    
    function getFlashLiquidityCapacity(
        address asset
    ) external view returns (uint256);
    
    function isFlashLiquidityAvailable(
        address asset,
        uint256 amount
    ) external view returns (bool);
    
    // View functions - Cross-chain
    function getCrossChainLiquidity(
        bytes32 bridgeId
    ) external view returns (CrossChainLiquidity memory);
    
    function getPendingBridges(
        address user
    ) external view returns (bytes32[] memory);
    
    function getSupportedChains() external view returns (uint256[] memory);
    
    function getChainLiquidity(
        uint256 chainId,
        address asset
    ) external view returns (uint256);
    
    // View functions - Emergency
    function getEmergencyLiquidity(
        address asset
    ) external view returns (EmergencyLiquidity memory);
    
    function isEmergencyActive(
        address asset
    ) external view returns (bool);
    
    function getEmergencyThreshold(
        address asset
    ) external view returns (uint256);
    
    function canActivateEmergency(
        address asset
    ) external view returns (bool);
    
    // View functions - Optimization
    function getOptimizationConfig(
        address asset
    ) external view returns (OptimizationConfig memory);
    
    function needsOptimization(
        address asset
    ) external view returns (bool);
    
    function getOptimizationOpportunity(
        address asset
    ) external view returns (uint256 potentialImprovement);
    
    function getLastOptimization(
        address asset
    ) external view returns (uint256 timestamp);
    
    // View functions - Calculations
    function calculateOptimalAllocation(
        address asset,
        uint256 amount
    ) external view returns (
        bytes32[] memory sources,
        uint256[] memory allocations
    );
    
    function calculateLiquidityEfficiency(
        address asset
    ) external view returns (uint256 efficiency);
    
    function calculateUtilizationRate(
        address asset
    ) external view returns (uint256 rate);
    
    function calculateAPY(
        address asset,
        bytes32 sourceId
    ) external view returns (uint256 apy);
    
    function calculateSlippage(
        address asset,
        uint256 amount
    ) external view returns (uint256 slippage);
    
    // View functions - Capacity and limits
    function getMaxLiquidityCapacity(
        address asset
    ) external view returns (uint256);
    
    function getAvailableCapacity(
        address asset,
        bytes32 sourceId
    ) external view returns (uint256);
    
    function canProvideLiquidity(
        address asset,
        uint256 amount
    ) external view returns (bool);
    
    function canRequestLiquidity(
        address asset,
        uint256 amount
    ) external view returns (bool);
    
    // View functions - Global statistics
    function getTotalValueLocked() external view returns (uint256);
    
    function getGlobalUtilizationRate() external view returns (uint256);
    
    function getGlobalEfficiency() external view returns (uint256);
    
    function getTotalSources() external view returns (uint256);
    
    function getTotalVirtualPools() external view returns (uint256);
    
    function getTotalActiveRoutes() external view returns (uint256);
    
    function getSupportedAssets() external view returns (address[] memory);
    
    // View functions - Health and status
    function isSystemHealthy() external view returns (bool);
    
    function getSystemHealth() external view returns (
        bool isHealthy,
        uint256 liquidityHealth,
        uint256 sourceHealth,
        uint256 routeHealth
    );
    
    function isAssetHealthy(
        address asset
    ) external view returns (bool);
    
    function getAssetHealth(
        address asset
    ) external view returns (
        bool isHealthy,
        uint256 liquidityLevel,
        uint256 utilizationHealth,
        uint256 sourceReliability
    );
}
