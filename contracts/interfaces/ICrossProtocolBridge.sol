// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title ICrossProtocolBridge
 * @dev Interface for the Cross Protocol Bridge contract
 * @author CoreLiquid Protocol
 */
interface ICrossProtocolBridge {
    // Events
    event BridgeInitiated(
        bytes32 indexed bridgeId,
        address indexed user,
        address indexed sourceAsset,
        address targetAsset,
        uint256 amount,
        string sourceProtocol,
        string targetProtocol,
        uint256 timestamp
    );
    
    event BridgeCompleted(
        bytes32 indexed bridgeId,
        address indexed user,
        uint256 amountReceived,
        uint256 fees,
        uint256 slippage,
        uint256 timestamp
    );
    
    event BridgeFailed(
        bytes32 indexed bridgeId,
        address indexed user,
        string reason,
        uint256 timestamp
    );
    
    event ProtocolAdded(
        string indexed protocolName,
        address indexed protocolAddress,
        address indexed adapter,
        uint256 timestamp
    );
    
    event ProtocolRemoved(
        string indexed protocolName,
        address indexed protocolAddress,
        uint256 timestamp
    );
    
    event RouteOptimized(
        address indexed sourceAsset,
        address indexed targetAsset,
        string sourceProtocol,
        string targetProtocol,
        uint256 newRate,
        uint256 timestamp
    );
    
    event LiquidityAdded(
        address indexed provider,
        address indexed asset,
        uint256 amount,
        string protocol,
        uint256 timestamp
    );
    
    event LiquidityRemoved(
        address indexed provider,
        address indexed asset,
        uint256 amount,
        string protocol,
        uint256 timestamp
    );
    
    event EmergencyPause(
        string indexed protocolName,
        string reason,
        uint256 timestamp
    );

    // Structs
    struct BridgeRequest {
        bytes32 bridgeId;
        address user;
        address sourceAsset;
        address targetAsset;
        uint256 amount;
        string sourceProtocol;
        string targetProtocol;
        uint256 minAmountOut;
        uint256 deadline;
        bytes routeData;
        bool isUrgent;
    }
    
    struct BridgeExecution {
        bytes32 bridgeId;
        uint256 amountIn;
        uint256 amountOut;
        uint256 fees;
        uint256 slippage;
        uint256 gasUsed;
        uint256 executionTime;
        uint256 completedAt;
        bool isSuccessful;
        string failureReason;
    }
    
    struct ProtocolInfo {
        string name;
        address protocolAddress;
        address adapter;
        bool isActive;
        bool isVerified;
        uint256 totalVolume;
        uint256 totalFees;
        uint256 successRate;
        uint256 averageExecutionTime;
        uint256 lastUpdate;
        string[] supportedAssets;
        uint256[] assetLimits;
    }
    
    struct RouteInfo {
        address sourceAsset;
        address targetAsset;
        string sourceProtocol;
        string targetProtocol;
        uint256 exchangeRate;
        uint256 fee;
        uint256 slippage;
        uint256 liquidity;
        uint256 lastUpdate;
        bool isActive;
        bool isOptimal;
    }
    
    struct LiquidityPool {
        address asset;
        string protocol;
        uint256 totalLiquidity;
        uint256 availableLiquidity;
        uint256 utilizationRate;
        uint256 apy;
        uint256 totalProviders;
        uint256 lastUpdate;
        bool isActive;
        mapping(address => uint256) providerBalances;
    }
    
    struct BridgeMetrics {
        uint256 totalBridges;
        uint256 successfulBridges;
        uint256 failedBridges;
        uint256 totalVolume;
        uint256 totalFees;
        uint256 averageExecutionTime;
        uint256 averageSlippage;
        uint256 lastMetricsUpdate;
    }
    
    struct OptimizationConfig {
        uint256 maxSlippage;
        uint256 maxExecutionTime;
        uint256 minLiquidity;
        uint256 feeThreshold;
        bool autoOptimize;
        bool emergencyMode;
        uint256 lastOptimization;
    }

    // Core bridge functions
    function initiateBridge(
        address sourceAsset,
        address targetAsset,
        uint256 amount,
        string calldata sourceProtocol,
        string calldata targetProtocol,
        uint256 minAmountOut,
        uint256 deadline
    ) external returns (bytes32 bridgeId);
    
    function executeBridge(
        bytes32 bridgeId
    ) external returns (uint256 amountOut);
    
    function completeBridge(
        bytes32 bridgeId,
        uint256 amountReceived
    ) external;
    
    function cancelBridge(
        bytes32 bridgeId,
        string calldata reason
    ) external;
    
    function retryBridge(
        bytes32 bridgeId
    ) external returns (bool success);
    
    // Advanced bridge functions
    function bridgeWithRoute(
        address sourceAsset,
        address targetAsset,
        uint256 amount,
        bytes calldata routeData,
        uint256 minAmountOut,
        uint256 deadline
    ) external returns (bytes32 bridgeId);
    
    function batchBridge(
        BridgeRequest[] calldata requests
    ) external returns (bytes32[] memory bridgeIds);
    
    function urgentBridge(
        address sourceAsset,
        address targetAsset,
        uint256 amount,
        string calldata sourceProtocol,
        string calldata targetProtocol,
        uint256 maxSlippage
    ) external returns (bytes32 bridgeId);
    
    // Protocol management
    function addProtocol(
        string calldata protocolName,
        address protocolAddress,
        address adapter,
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
        string calldata protocolName,
        string calldata reason
    ) external;
    
    function unpauseProtocol(
        string calldata protocolName
    ) external;
    
    function verifyProtocol(
        string calldata protocolName
    ) external;
    
    // Route management
    function addRoute(
        address sourceAsset,
        address targetAsset,
        string calldata sourceProtocol,
        string calldata targetProtocol,
        uint256 fee,
        uint256 maxSlippage
    ) external;
    
    function removeRoute(
        address sourceAsset,
        address targetAsset,
        string calldata sourceProtocol,
        string calldata targetProtocol
    ) external;
    
    function updateRouteRate(
        address sourceAsset,
        address targetAsset,
        string calldata sourceProtocol,
        string calldata targetProtocol,
        uint256 newRate
    ) external;
    
    function optimizeRoutes() external;
    
    function findOptimalRoute(
        address sourceAsset,
        address targetAsset,
        uint256 amount
    ) external view returns (
        string memory sourceProtocol,
        string memory targetProtocol,
        uint256 expectedOutput,
        uint256 fee
    );
    
    // Liquidity management
    function addLiquidity(
        address asset,
        uint256 amount,
        string calldata protocol
    ) external;
    
    function removeLiquidity(
        address asset,
        uint256 amount,
        string calldata protocol
    ) external;
    
    function rebalanceLiquidity(
        address asset
    ) external;
    
    function harvestLiquidityRewards(
        address asset,
        string calldata protocol
    ) external returns (uint256 rewards);
    
    // Configuration
    function setOptimizationConfig(
        uint256 maxSlippage,
        uint256 maxExecutionTime,
        uint256 minLiquidity,
        uint256 feeThreshold,
        bool autoOptimize
    ) external;
    
    function setEmergencyMode(
        bool enabled
    ) external;
    
    function updateFeeStructure(
        string calldata protocolName,
        uint256 baseFee,
        uint256 variableFee
    ) external;
    
    // Emergency functions
    function emergencyPauseAll(
        string calldata reason
    ) external;
    
    function emergencyUnpauseAll() external;
    
    function emergencyWithdraw(
        address asset,
        uint256 amount,
        address to
    ) external;
    
    function emergencyRefund(
        bytes32 bridgeId,
        string calldata reason
    ) external;
    
    // View functions - Bridge info
    function getBridgeRequest(
        bytes32 bridgeId
    ) external view returns (BridgeRequest memory);
    
    function getBridgeExecution(
        bytes32 bridgeId
    ) external view returns (BridgeExecution memory);
    
    function getBridgeStatus(
        bytes32 bridgeId
    ) external view returns (string memory status);
    
    function getUserBridges(
        address user
    ) external view returns (bytes32[] memory);
    
    function getPendingBridges(
        address user
    ) external view returns (bytes32[] memory);
    
    function getCompletedBridges(
        address user,
        uint256 limit
    ) external view returns (bytes32[] memory);
    
    // View functions - Protocol info
    function getProtocolInfo(
        string calldata protocolName
    ) external view returns (ProtocolInfo memory);
    
    function getSupportedProtocols() external view returns (string[] memory);
    
    function getActiveProtocols() external view returns (string[] memory);
    
    function isProtocolSupported(
        string calldata protocolName
    ) external view returns (bool);
    
    function isProtocolActive(
        string calldata protocolName
    ) external view returns (bool);
    
    // View functions - Route info
    function getRouteInfo(
        address sourceAsset,
        address targetAsset,
        string calldata sourceProtocol,
        string calldata targetProtocol
    ) external view returns (RouteInfo memory);
    
    function getAvailableRoutes(
        address sourceAsset,
        address targetAsset
    ) external view returns (RouteInfo[] memory);
    
    function getBestRoute(
        address sourceAsset,
        address targetAsset,
        uint256 amount
    ) external view returns (RouteInfo memory);
    
    function isRouteActive(
        address sourceAsset,
        address targetAsset,
        string calldata sourceProtocol,
        string calldata targetProtocol
    ) external view returns (bool);
    
    // View functions - Liquidity info
    function getLiquidityPool(
        address asset,
        string calldata protocol
    ) external view returns (
        uint256 totalLiquidity,
        uint256 availableLiquidity,
        uint256 utilizationRate,
        uint256 apy
    );
    
    function getUserLiquidity(
        address user,
        address asset,
        string calldata protocol
    ) external view returns (uint256);
    
    function getTotalLiquidity(
        address asset
    ) external view returns (uint256);
    
    function getAvailableLiquidity(
        address asset,
        string calldata protocol
    ) external view returns (uint256);
    
    // View functions - Calculations
    function calculateBridgeOutput(
        address sourceAsset,
        address targetAsset,
        uint256 amount,
        string calldata sourceProtocol,
        string calldata targetProtocol
    ) external view returns (
        uint256 amountOut,
        uint256 fee,
        uint256 slippage
    );
    
    function calculateOptimalAmount(
        address sourceAsset,
        address targetAsset,
        uint256 targetAmount,
        string calldata sourceProtocol,
        string calldata targetProtocol
    ) external view returns (uint256 requiredInput);
    
    function estimateExecutionTime(
        address sourceAsset,
        address targetAsset,
        uint256 amount,
        string calldata sourceProtocol,
        string calldata targetProtocol
    ) external view returns (uint256 estimatedTime);
    
    function calculateFees(
        address sourceAsset,
        address targetAsset,
        uint256 amount,
        string calldata sourceProtocol,
        string calldata targetProtocol
    ) external view returns (
        uint256 baseFee,
        uint256 variableFee,
        uint256 totalFee
    );
    
    // View functions - Metrics
    function getBridgeMetrics() external view returns (BridgeMetrics memory);
    
    function getProtocolMetrics(
        string calldata protocolName
    ) external view returns (
        uint256 totalVolume,
        uint256 totalFees,
        uint256 successRate,
        uint256 averageExecutionTime
    );
    
    function getUserMetrics(
        address user
    ) external view returns (
        uint256 totalBridges,
        uint256 totalVolume,
        uint256 totalFees,
        uint256 successRate
    );
    
    function getAssetMetrics(
        address asset
    ) external view returns (
        uint256 totalVolume,
        uint256 totalBridges,
        uint256 averageAmount,
        uint256 lastActivity
    );
    
    // View functions - Status checks
    function canBridge(
        address sourceAsset,
        address targetAsset,
        uint256 amount,
        string calldata sourceProtocol,
        string calldata targetProtocol
    ) external view returns (bool);
    
    function hasEnoughLiquidity(
        address asset,
        uint256 amount,
        string calldata protocol
    ) external view returns (bool);
    
    function isWithinSlippageTolerance(
        address sourceAsset,
        address targetAsset,
        uint256 amount,
        uint256 maxSlippage,
        string calldata sourceProtocol,
        string calldata targetProtocol
    ) external view returns (bool);
    
    function isBridgeExpired(
        bytes32 bridgeId
    ) external view returns (bool);
    
    // View functions - Global statistics
    function getTotalBridgeVolume() external view returns (uint256);
    
    function getTotalBridgeCount() external view returns (uint256);
    
    function getGlobalSuccessRate() external view returns (uint256);
    
    function getAverageExecutionTime() external view returns (uint256);
    
    function getAverageSlippage() external view returns (uint256);
    
    function getTotalFeesCollected() external view returns (uint256);
    
    function getActiveBridgeCount() external view returns (uint256);
    
    function getSupportedAssets() external view returns (address[] memory);
}
