// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "./UnifiedLiquidityLayer.sol";
import "./InfiniteLiquidityEngine.sol";
import "./SeamlessIntegrationHub.sol";
import "../interfaces/IOracleRouter.sol";
import "../interfaces/IVaultManager.sol";
import "../interfaces/IIdleCapitalManager.sol";

/**
 * @title IntelligentLiquidityRouter
 * @dev Advanced routing system that intelligently directs liquidity to optimal destinations
 * @author CoreLiquid Protocol
 */
contract IntelligentLiquidityRouter is AccessControl, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;
    using Math for uint256;

    // Roles
    bytes32 public constant ROUTER_MANAGER_ROLE = keccak256("ROUTER_MANAGER_ROLE");
    bytes32 public constant KEEPER_ROLE = keccak256("KEEPER_ROLE");
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");

    // Constants
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant PRECISION = 1e18;
    uint256 public constant MAX_ROUTES = 5;
    uint256 public constant MIN_ROUTE_AMOUNT = 1000;
    uint256 public constant OPTIMIZATION_THRESHOLD = 100;

    // Core contracts
    UnifiedLiquidityLayer public immutable unifiedLiquidity;
    InfiniteLiquidityEngine public immutable infiniteLiquidity;
    SeamlessIntegrationHub public immutable integrationHub;
    IOracleRouter public immutable oracleRouter;
    IVaultManager public immutable vaultManager;
    IIdleCapitalManager public immutable idleCapitalManager;

    // Route types
    enum RouteType {
        LENDING,
        DEX_TRADING,
        VAULT_STRATEGY,
        STAKING,
        INFINITE_LIQUIDITY,
        CROSS_PROTOCOL
    }

    // Route destination
    struct RouteDestination {
        RouteType routeType;
        address protocol;
        address asset;
        uint256 expectedYield;
        uint256 riskScore;
        uint256 liquidityDepth;
        uint256 accessLatency;
        uint256 gasCost;
        bool isActive;
        bool isEmergencyRoute;
    }

    // Routing strategy
    struct RoutingStrategy {
        uint256 maxRoutes;
        uint256 minAllocationPerRoute;
        uint256 maxAllocationPerRoute;
        uint256 riskTolerance;
        uint256 yieldTarget;
        uint256 liquidityRequirement;
        bool prioritizeYield;
        bool prioritizeLiquidity;
        bool allowEmergencyRoutes;
    }

    // Route execution
    struct RouteExecution {
        address user;
        address asset;
        uint256 totalAmount;
        RouteDestination[] routes;
        uint256[] allocations;
        uint256[] actualYields;
        uint256 totalYieldAchieved;
        uint256 executionGasCost;
        uint256 timestamp;
        bool isSuccessful;
        bool isOptimal;
    }

    // Intelligent routing metrics
    struct IntelligentMetrics {
        uint256 totalRoutingVolume;
        uint256 totalRoutesExecuted;
        uint256 averageYieldImprovement;
        uint256 totalGasSaved;
        uint256 optimalRoutePercentage;
        uint256 emergencyRoutesUsed;
        uint256 lastOptimization;
    }

    // Route optimization
    struct RouteOptimization {
        uint256 currentYield;
        uint256 optimizedYield;
        uint256 improvementPercentage;
        uint256 riskAdjustedReturn;
        uint256 liquidityScore;
        uint256 efficiencyScore;
        bool needsRebalancing;
        bool isOptimal;
    }

    // Storage
    mapping(address => RouteDestination[]) public assetRoutes;
    mapping(address => RoutingStrategy) public userStrategies;
    mapping(address => RouteExecution[]) public userRouteHistory;
    mapping(address => IntelligentMetrics) public assetMetrics;
    mapping(bytes32 => RouteOptimization) public routeOptimizations;
    
    address[] public supportedAssets;
    RouteDestination[] public globalRoutes;
    
    // Global metrics
    uint256 public totalIntelligentVolume;
    uint256 public totalOptimizationsPerformed;
    uint256 public totalYieldGenerated;
    uint256 public totalGasOptimized;

    // Events
    event IntelligentRouteExecuted(
        address indexed user,
        address indexed asset,
        uint256 amount,
        uint256 routeCount,
        uint256 totalYield,
        uint256 timestamp
    );
    
    event RouteOptimized(
        address indexed asset,
        uint256 oldYield,
        uint256 newYield,
        uint256 improvement,
        uint256 timestamp
    );
    
    event EmergencyRouteActivated(
        address indexed asset,
        address indexed protocol,
        uint256 amount,
        uint256 timestamp
    );
    
    event RoutingStrategyUpdated(
        address indexed user,
        uint256 riskTolerance,
        uint256 yieldTarget,
        uint256 timestamp
    );

    constructor(
        address _unifiedLiquidity,
        address payable _infiniteLiquidity,
        address _integrationHub,
        address _oracleRouter,
        address _vaultManager,
        address _idleCapitalManager
    ) {
        require(_unifiedLiquidity != address(0), "Invalid unified liquidity");
        require(_infiniteLiquidity != address(0), "Invalid infinite liquidity");
        require(_integrationHub != address(0), "Invalid integration hub");
        require(_oracleRouter != address(0), "Invalid oracle router");
        require(_vaultManager != address(0), "Invalid vault manager");
        require(_idleCapitalManager != address(0), "Invalid idle capital manager");
        
        unifiedLiquidity = UnifiedLiquidityLayer(_unifiedLiquidity);
        infiniteLiquidity = InfiniteLiquidityEngine(_infiniteLiquidity);
        integrationHub = SeamlessIntegrationHub(_integrationHub);
        oracleRouter = IOracleRouter(_oracleRouter);
        vaultManager = IVaultManager(_vaultManager);
        idleCapitalManager = IIdleCapitalManager(_idleCapitalManager);
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ROUTER_MANAGER_ROLE, msg.sender);
        _grantRole(KEEPER_ROLE, msg.sender);
        _grantRole(ORACLE_ROLE, msg.sender);
        _grantRole(EMERGENCY_ROLE, msg.sender);
    }

    /**
     * @dev Execute intelligent routing for optimal liquidity allocation
     */
    function executeIntelligentRouting(
        address asset,
        uint256 amount,
        RoutingStrategy memory strategy
    ) external nonReentrant whenNotPaused returns (uint256 totalYield) {
        require(asset != address(0), "Invalid asset");
        require(amount >= MIN_ROUTE_AMOUNT, "Amount too small");
        
        // Transfer asset from user
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
        
        // Get optimal routes and allocations
        RouteDestination[] memory routes = _getOptimalRoutes(asset, amount, strategy);
        uint256[] memory allocations = _calculateOptimalAllocations(asset, amount, routes, strategy);
        
        // Execute routes
        uint256[] memory actualYields = _executeRoutes(asset, routes, allocations);
        
        // Calculate total yield
        for (uint256 i = 0; i < actualYields.length; i++) {
            totalYield += actualYields[i];
        }
        
        // Record execution
        RouteExecution memory execution = RouteExecution({
            user: msg.sender,
            asset: asset,
            totalAmount: amount,
            routes: routes,
            allocations: allocations,
            actualYields: actualYields,
            totalYieldAchieved: totalYield,
            executionGasCost: gasleft(),
            timestamp: block.timestamp,
            isSuccessful: true,
            isOptimal: _isOptimalExecution(totalYield, amount, strategy)
        });
        
        userRouteHistory[msg.sender].push(execution);
        
        // Update metrics
        _updateIntelligentMetrics(asset, amount, totalYield, gasleft());
        
        // Update global metrics
        totalIntelligentVolume += amount;
        totalYieldGenerated += totalYield;
        totalOptimizationsPerformed++;
        
        emit IntelligentRouteExecuted(
            msg.sender,
            asset,
            amount,
            routes.length,
            totalYield,
            block.timestamp
        );
    }

    /**
     * @dev Get optimal routes for asset allocation
     */
    function _getOptimalRoutes(
        address asset,
        uint256 amount,
        RoutingStrategy memory strategy
    ) internal view returns (RouteDestination[] memory) {
        RouteDestination[] memory availableRoutes = assetRoutes[asset];
        RouteDestination[] memory optimalRoutes = new RouteDestination[](strategy.maxRoutes);
        
        uint256 routeCount = 0;
        
        // Score and sort routes
        uint256[] memory scores = new uint256[](availableRoutes.length);
        
        for (uint256 i = 0; i < availableRoutes.length; i++) {
            if (!availableRoutes[i].isActive) continue;
            
            scores[i] = _calculateRouteScore(
                availableRoutes[i],
                amount,
                strategy
            );
        }
        
        // Select top routes
        for (uint256 i = 0; i < strategy.maxRoutes && routeCount < availableRoutes.length; i++) {
            uint256 bestIndex = 0;
            uint256 bestScore = 0;
            
            for (uint256 j = 0; j < availableRoutes.length; j++) {
                if (scores[j] > bestScore) {
                    bestScore = scores[j];
                    bestIndex = j;
                }
            }
            
            if (bestScore > 0) {
                optimalRoutes[routeCount] = availableRoutes[bestIndex];
                scores[bestIndex] = 0; // Mark as used
                routeCount++;
            }
        }
        
        // Resize array to actual count
        RouteDestination[] memory finalRoutes = new RouteDestination[](routeCount);
        for (uint256 i = 0; i < routeCount; i++) {
            finalRoutes[i] = optimalRoutes[i];
        }
        
        return finalRoutes;
    }

    /**
     * @dev Calculate route score based on strategy
     */
    function _calculateRouteScore(
        RouteDestination memory route,
        uint256 amount,
        RoutingStrategy memory strategy
    ) internal view returns (uint256) {
        uint256 score = 0;
        
        // Yield score (40% weight)
        if (strategy.prioritizeYield) {
            score += (route.expectedYield * 4000) / BASIS_POINTS;
        } else {
            score += (route.expectedYield * 2000) / BASIS_POINTS;
        }
        
        // Risk score (30% weight) - lower risk = higher score
        uint256 riskScore = BASIS_POINTS - route.riskScore;
        score += (riskScore * 3000) / BASIS_POINTS;
        
        // Liquidity score (20% weight)
        if (strategy.prioritizeLiquidity) {
            uint256 liquidityScore = Math.min(route.liquidityDepth * BASIS_POINTS / amount, BASIS_POINTS);
            score += (liquidityScore * 2000) / BASIS_POINTS;
        } else {
            uint256 liquidityScore = Math.min(route.liquidityDepth * BASIS_POINTS / amount, BASIS_POINTS);
            score += (liquidityScore * 1000) / BASIS_POINTS;
        }
        
        // Gas efficiency score (10% weight)
        uint256 gasScore = route.gasCost > 0 ? BASIS_POINTS / route.gasCost : BASIS_POINTS;
        score += (gasScore * 1000) / BASIS_POINTS;
        
        // Risk tolerance check
        if (route.riskScore > strategy.riskTolerance) {
            score = score / 2; // Penalize high-risk routes
        }
        
        // Emergency route penalty
        if (route.isEmergencyRoute && !strategy.allowEmergencyRoutes) {
            score = 0;
        }
        
        return score;
    }

    /**
     * @dev Calculate optimal allocations across routes
     */
    function _calculateOptimalAllocations(
        address asset,
        uint256 totalAmount,
        RouteDestination[] memory routes,
        RoutingStrategy memory strategy
    ) internal view returns (uint256[] memory) {
        uint256[] memory allocations = new uint256[](routes.length);
        uint256 remainingAmount = totalAmount;
        
        // Calculate total score for proportional allocation
        uint256 totalScore = 0;
        uint256[] memory routeScores = new uint256[](routes.length);
        
        for (uint256 i = 0; i < routes.length; i++) {
            routeScores[i] = _calculateRouteScore(routes[i], totalAmount, strategy);
            totalScore += routeScores[i];
        }
        
        // Allocate proportionally based on scores
        for (uint256 i = 0; i < routes.length && remainingAmount > 0; i++) {
            if (totalScore == 0) break;
            
            uint256 allocation = (totalAmount * routeScores[i]) / totalScore;
            
            // Apply min/max constraints
            allocation = Math.max(allocation, strategy.minAllocationPerRoute);
            allocation = Math.min(allocation, strategy.maxAllocationPerRoute);
            allocation = Math.min(allocation, remainingAmount);
            
            allocations[i] = allocation;
            remainingAmount -= allocation;
        }
        
        // Distribute any remaining amount to the best route
        if (remainingAmount > 0 && routes.length > 0) {
            allocations[0] += remainingAmount;
        }
        
        return allocations;
    }

    /**
     * @dev Execute routes with allocated amounts
     */
    function _executeRoutes(
        address asset,
        RouteDestination[] memory routes,
        uint256[] memory allocations
    ) internal returns (uint256[] memory actualYields) {
        actualYields = new uint256[](routes.length);
        
        for (uint256 i = 0; i < routes.length; i++) {
            if (allocations[i] == 0) continue;
            
            actualYields[i] = _executeRoute(
                asset,
                routes[i],
                allocations[i]
            );
        }
    }

    /**
     * @dev Execute individual route
     */
    function _executeRoute(
        address asset,
        RouteDestination memory route,
        uint256 amount
    ) internal returns (uint256 actualYield) {
        // Approve asset for the route protocol
        IERC20(asset).forceApprove(route.protocol, amount);
        
        if (route.routeType == RouteType.LENDING) {
            actualYield = _executeLendingRoute(asset, route.protocol, amount);
        } else if (route.routeType == RouteType.DEX_TRADING) {
            actualYield = _executeDexRoute(asset, route.protocol, amount);
        } else if (route.routeType == RouteType.VAULT_STRATEGY) {
            actualYield = _executeVaultRoute(asset, route.protocol, amount);
        } else if (route.routeType == RouteType.STAKING) {
            actualYield = _executeStakingRoute(asset, route.protocol, amount);
        } else if (route.routeType == RouteType.INFINITE_LIQUIDITY) {
            actualYield = _executeInfiniteRoute(asset, amount);
        } else if (route.routeType == RouteType.CROSS_PROTOCOL) {
            actualYield = _executeCrossProtocolRoute(asset, route.protocol, amount);
        }
        
        // Reset approval
        IERC20(asset).forceApprove(route.protocol, 0);
    }

    /**
     * @dev Execute lending route
     */
    function _executeLendingRoute(
        address asset,
        address protocol,
        uint256 amount
    ) internal returns (uint256) {
        unifiedLiquidity.allocateToProtocol(asset, amount, "LENDING");
        return amount; // Return amount as yield placeholder
    }

    /**
     * @dev Execute DEX route
     */
    function _executeDexRoute(
        address asset,
        address protocol,
        uint256 amount
    ) internal returns (uint256) {
        unifiedLiquidity.allocateToProtocol(asset, amount, "DEX");
        return amount; // Return amount as yield placeholder
    }

    /**
     * @dev Execute vault route
     */
    function _executeVaultRoute(
        address asset,
        address protocol,
        uint256 amount
    ) internal returns (uint256) {
        unifiedLiquidity.allocateToProtocol(asset, amount, "VAULT");
        return amount; // Return amount as yield placeholder
    }

    /**
     * @dev Execute staking route
     */
    function _executeStakingRoute(
        address asset,
        address protocol,
        uint256 amount
    ) internal returns (uint256) {
        unifiedLiquidity.allocateToProtocol(asset, amount, "STAKING");
        return amount; // Return amount as yield placeholder
    }

    /**
     * @dev Execute infinite liquidity route
     */
    function _executeInfiniteRoute(
        address asset,
        uint256 amount
    ) internal returns (uint256) {
        return (amount * 500) / BASIS_POINTS; // 5% yield placeholder
    }

    /**
     * @dev Execute cross-protocol route
     */
    function _executeCrossProtocolRoute(
        address asset,
        address protocol,
        uint256 amount
    ) internal returns (uint256) {
        return (amount * 600) / BASIS_POINTS; // 6% yield placeholder
    }

    /**
     * @dev Check if execution is optimal
     */
    function _isOptimalExecution(
        uint256 actualYield,
        uint256 amount,
        RoutingStrategy memory strategy
    ) internal pure returns (bool) {
        uint256 yieldRate = (actualYield * BASIS_POINTS) / amount;
        return yieldRate >= strategy.yieldTarget;
    }

    /**
     * @dev Update intelligent metrics
     */
    function _updateIntelligentMetrics(
        address asset,
        uint256 amount,
        uint256 yield,
        uint256 gasCost
    ) internal {
        IntelligentMetrics storage metrics = assetMetrics[asset];
        
        metrics.totalRoutingVolume += amount;
        metrics.totalRoutesExecuted++;
        
        // Calculate yield improvement (simplified)
        uint256 baselineYield = (amount * 300) / BASIS_POINTS; // 3% baseline
        if (yield > baselineYield) {
            uint256 improvement = ((yield - baselineYield) * BASIS_POINTS) / baselineYield;
            metrics.averageYieldImprovement = 
                (metrics.averageYieldImprovement + improvement) / 2;
        }
        
        metrics.totalGasSaved += gasCost;
        metrics.lastOptimization = block.timestamp;
    }

    /**
     * @dev Add route destination for asset
     */
    function addRouteDestination(
        address asset,
        RouteDestination memory route
    ) external onlyRole(ROUTER_MANAGER_ROLE) {
        require(asset != address(0), "Invalid asset");
        require(route.protocol != address(0), "Invalid protocol");
        
        assetRoutes[asset].push(route);
        globalRoutes.push(route);
        
        _addSupportedAsset(asset);
    }

    /**
     * @dev Update routing strategy for user
     */
    function updateRoutingStrategy(
        RoutingStrategy memory strategy
    ) external {
        require(strategy.maxRoutes <= MAX_ROUTES, "Too many routes");
        require(strategy.riskTolerance <= BASIS_POINTS, "Invalid risk tolerance");
        
        userStrategies[msg.sender] = strategy;
        
        emit RoutingStrategyUpdated(
            msg.sender,
            strategy.riskTolerance,
            strategy.yieldTarget,
            block.timestamp
        );
    }

    /**
     * @dev Add supported asset
     */
    function _addSupportedAsset(address asset) internal {
        for (uint256 i = 0; i < supportedAssets.length; i++) {
            if (supportedAssets[i] == asset) return;
        }
        supportedAssets.push(asset);
    }

    // View functions
    function getAssetRoutes(address asset) external view returns (RouteDestination[] memory) {
        return assetRoutes[asset];
    }
    
    function getUserStrategy(address user) external view returns (RoutingStrategy memory) {
        return userStrategies[user];
    }
    
    function getUserRouteHistory(address user) external view returns (RouteExecution[] memory) {
        return userRouteHistory[user];
    }
    
    function getAssetMetrics(address asset) external view returns (IntelligentMetrics memory) {
        return assetMetrics[asset];
    }
    
    function getSupportedAssets() external view returns (address[] memory) {
        return supportedAssets;
    }
    
    function getGlobalRoutes() external view returns (RouteDestination[] memory) {
        return globalRoutes;
    }
    
    function getTotalStats() external view returns (
        uint256 totalVolume,
        uint256 totalOptimizations,
        uint256 totalYield,
        uint256 totalGasOptimized
    ) {
        return (
            totalIntelligentVolume,
            totalOptimizationsPerformed,
            totalYieldGenerated,
            totalGasOptimized
        );
    }

    /**
     * @dev Get optimal route quote
     */
    function getOptimalRouteQuote(
        address asset,
        uint256 amount,
        RoutingStrategy memory strategy
    ) external view returns (
        RouteDestination[] memory routes,
        uint256[] memory allocations,
        uint256 expectedTotalYield,
        uint256 estimatedGasCost
    ) {
        routes = _getOptimalRoutes(asset, amount, strategy);
        allocations = _calculateOptimalAllocations(asset, amount, routes, strategy);
        
        // Calculate expected total yield
        for (uint256 i = 0; i < routes.length; i++) {
            expectedTotalYield += (allocations[i] * routes[i].expectedYield) / BASIS_POINTS;
        }
        
        // Estimate gas cost
        estimatedGasCost = routes.length * 100000; // 100k gas per route
    }

    /**
     * @dev Emergency functions
     */
    function pause() external onlyRole(EMERGENCY_ROLE) {
        _pause();
    }
    
    function unpause() external onlyRole(EMERGENCY_ROLE) {
        _unpause();
    }
    
    function emergencyWithdraw(
        address asset,
        uint256 amount,
        address to
    ) external onlyRole(EMERGENCY_ROLE) {
        IERC20(asset).safeTransfer(to, amount);
    }
}
