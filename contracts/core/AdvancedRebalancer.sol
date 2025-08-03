// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./UnifiedLiquidityLayer.sol";
import "./CrossProtocolBridge.sol";
import "../common/OracleRouter.sol";
import "../common/RiskEngine.sol";

/**
 * @title AdvancedRebalancer
 * @dev Advanced automated rebalancing system for cross-protocol liquidity optimization
 * @notice This contract implements intelligent rebalancing strategies across lending, DEX, vaults, and staking
 */
contract AdvancedRebalancer is AccessControl, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;
    using Math for uint256;
    
    bytes32 public constant REBALANCER_ROLE = keccak256("REBALANCER_ROLE");
    bytes32 public constant STRATEGY_MANAGER_ROLE = keccak256("STRATEGY_MANAGER_ROLE");
    bytes32 public constant KEEPER_ROLE = keccak256("KEEPER_ROLE");
    bytes32 public constant RISK_MANAGER_ROLE = keccak256("RISK_MANAGER_ROLE");
    
    // Core integrations
    UnifiedLiquidityLayer public immutable unifiedLiquidity;
    CrossProtocolBridge public immutable crossProtocolBridge;
    OracleRouter public immutable oracleRouter;
    RiskEngine public immutable riskEngine;
    
    // Rebalancing strategy types
    enum StrategyType {
        YIELD_OPTIMIZATION,
        RISK_MINIMIZATION,
        LIQUIDITY_MAXIMIZATION,
        ARBITRAGE_CAPTURE,
        DYNAMIC_HEDGING
    }
    
    // Protocol types for rebalancing
    enum ProtocolType {
        LENDING,
        DEX,
        VAULT,
        STAKING,
        EXTERNAL
    }
    
    // Rebalancing strategy configuration
    struct RebalanceStrategy {
        StrategyType strategyType;
        address asset;
        ProtocolType[] targetProtocols;
        uint256[] targetAllocations; // in basis points
        uint256[] minAllocations;
        uint256[] maxAllocations;
        uint256 rebalanceThreshold; // minimum deviation to trigger rebalance
        uint256 maxSlippage; // maximum acceptable slippage
        uint256 cooldownPeriod; // minimum time between rebalances
        uint256 lastRebalance;
        bool isActive;
        bool isEmergencyMode;
    }
    
    // Market condition analysis
    struct MarketCondition {
        uint256 volatility;
        uint256 liquidityDepth;
        uint256 tradingVolume;
        uint256 yieldSpread;
        uint256 riskScore;
        uint256 timestamp;
        bool isBullish;
        bool isBearish;
        bool isHighVolatility;
    }
    
    // Rebalancing execution data
    struct RebalanceExecution {
        uint256 strategyId;
        address asset;
        ProtocolType[] fromProtocols;
        ProtocolType[] toProtocols;
        uint256[] amounts;
        uint256[] actualSlippage;
        uint256 totalGasCost;
        uint256 netBenefit;
        uint256 timestamp;
        bool isSuccessful;
    }
    
    // Dynamic allocation parameters
    struct DynamicAllocation {
        uint256 baseAllocation;
        uint256 volatilityAdjustment;
        uint256 yieldAdjustment;
        uint256 liquidityAdjustment;
        uint256 riskAdjustment;
        uint256 finalAllocation;
        uint256 confidence; // confidence level in allocation
    }
    
    // Risk management parameters
    struct RiskParameters {
        uint256 maxConcentration; // max allocation to single protocol
        uint256 maxVolatilityExposure; // max exposure to high volatility assets
        uint256 minLiquidityBuffer; // minimum liquidity to maintain
        uint256 emergencyThreshold; // threshold to trigger emergency rebalancing
        uint256 correlationLimit; // max correlation between protocols
        bool riskLimitsEnabled;
    }
    
    // Yield optimization data
    struct YieldOptimization {
        mapping(ProtocolType => uint256) currentYields;
        mapping(ProtocolType => uint256) projectedYields;
        mapping(ProtocolType => uint256) yieldVolatility;
        uint256 optimalYieldTarget;
        uint256 yieldEfficiency;
        uint256 lastYieldUpdate;
    }
    
    mapping(uint256 => RebalanceStrategy) public strategies;
    mapping(address => MarketCondition) public marketConditions;
    mapping(uint256 => RebalanceExecution[]) public executionHistory;
    mapping(address => YieldOptimization) public yieldOptimizations;
    mapping(address => RiskParameters) public riskParameters;
    mapping(address => DynamicAllocation[]) public allocationHistory;
    
    mapping(address => uint256[]) public assetStrategies;
    mapping(address => bool) public isAssetActive;
    
    uint256 public nextStrategyId = 1;
    uint256 public totalRebalances;
    uint256 public totalGasSaved;
    uint256 public totalYieldGenerated;
    
    uint256 public constant PRECISION = 1e18;
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant MAX_PROTOCOLS = 10;
    uint256 public constant MIN_REBALANCE_AMOUNT = 1000 * PRECISION;
    uint256 public constant MAX_SLIPPAGE = 500; // 5%
    uint256 public constant DEFAULT_COOLDOWN = 1 hours;
    
    event StrategyCreated(
        uint256 indexed strategyId,
        StrategyType strategyType,
        address indexed asset,
        ProtocolType[] targetProtocols
    );
    
    event RebalanceExecuted(
        uint256 indexed strategyId,
        address indexed asset,
        uint256[] oldAllocations,
        uint256[] newAllocations,
        uint256 netBenefit,
        uint256 timestamp
    );
    
    event EmergencyRebalanceTriggered(
        uint256 indexed strategyId,
        address indexed asset,
        uint256 riskScore,
        uint256 timestamp
    );
    
    event YieldOptimizationUpdated(
        address indexed asset,
        uint256 oldYieldTarget,
        uint256 newYieldTarget,
        uint256 efficiency
    );
    
    event MarketConditionUpdated(
        address indexed asset,
        uint256 volatility,
        uint256 riskScore,
        bool isBullish,
        uint256 timestamp
    );
    
    event AllocationOptimized(
        address indexed asset,
        ProtocolType protocol,
        uint256 oldAllocation,
        uint256 newAllocation,
        uint256 confidence
    );
    
    constructor(
        address _unifiedLiquidity,
        address _crossProtocolBridge,
        address _oracleRouter,
        address _riskEngine
    ) {
        require(_unifiedLiquidity != address(0), "Invalid unified liquidity");
        require(_crossProtocolBridge != address(0), "Invalid cross protocol bridge");
        require(_oracleRouter != address(0), "Invalid oracle router");
        require(_riskEngine != address(0), "Invalid risk engine");
        
        unifiedLiquidity = UnifiedLiquidityLayer(_unifiedLiquidity);
        crossProtocolBridge = CrossProtocolBridge(_crossProtocolBridge);
        oracleRouter = OracleRouter(_oracleRouter);
        riskEngine = RiskEngine(_riskEngine);
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(REBALANCER_ROLE, msg.sender);
        _grantRole(STRATEGY_MANAGER_ROLE, msg.sender);
        _grantRole(KEEPER_ROLE, msg.sender);
        _grantRole(RISK_MANAGER_ROLE, msg.sender);
    }
    
    /**
     * @dev Create new rebalancing strategy
     */
    function createRebalanceStrategy(
        StrategyType strategyType,
        address asset,
        ProtocolType[] calldata targetProtocols,
        uint256[] calldata targetAllocations,
        uint256[] calldata minAllocations,
        uint256[] calldata maxAllocations,
        uint256 rebalanceThreshold,
        uint256 maxSlippage,
        uint256 cooldownPeriod
    ) external onlyRole(STRATEGY_MANAGER_ROLE) returns (uint256 strategyId) {
        require(targetProtocols.length == targetAllocations.length, "Array length mismatch");
        require(targetProtocols.length == minAllocations.length, "Array length mismatch");
        require(targetProtocols.length == maxAllocations.length, "Array length mismatch");
        require(targetProtocols.length <= MAX_PROTOCOLS, "Too many protocols");
        require(maxSlippage <= MAX_SLIPPAGE, "Slippage too high");
        
        // Verify allocations sum to 100%
        uint256 totalAllocation = 0;
        for (uint256 i = 0; i < targetAllocations.length; i++) {
            require(targetAllocations[i] >= minAllocations[i], "Target below minimum");
            require(targetAllocations[i] <= maxAllocations[i], "Target above maximum");
            totalAllocation += targetAllocations[i];
        }
        require(totalAllocation == BASIS_POINTS, "Allocations must sum to 100%");
        
        strategyId = nextStrategyId++;
        
        strategies[strategyId] = RebalanceStrategy({
            strategyType: strategyType,
            asset: asset,
            targetProtocols: targetProtocols,
            targetAllocations: targetAllocations,
            minAllocations: minAllocations,
            maxAllocations: maxAllocations,
            rebalanceThreshold: rebalanceThreshold,
            maxSlippage: maxSlippage,
            cooldownPeriod: cooldownPeriod > 0 ? cooldownPeriod : DEFAULT_COOLDOWN,
            lastRebalance: 0,
            isActive: true,
            isEmergencyMode: false
        });
        
        assetStrategies[asset].push(strategyId);
        isAssetActive[asset] = true;
        
        // Initialize risk parameters
        _initializeRiskParameters(asset);
        
        emit StrategyCreated(
            strategyId,
            strategyType,
            asset,
            targetProtocols
        );
    }
    
    /**
     * @dev Execute rebalancing for a strategy
     */
    function executeRebalance(
        uint256 strategyId
    ) external onlyRole(KEEPER_ROLE) nonReentrant whenNotPaused {
        RebalanceStrategy storage strategy = strategies[strategyId];
        require(strategy.isActive, "Strategy not active");
        require(
            block.timestamp >= strategy.lastRebalance + strategy.cooldownPeriod,
            "Cooldown period not met"
        );
        
        // Update market conditions
        _updateMarketConditions(strategy.asset);
        
        // Calculate current allocations
        uint256[] memory currentAllocations = _getCurrentAllocations(strategyId);
        
        // Calculate optimal allocations based on strategy type
        uint256[] memory optimalAllocations = _calculateOptimalAllocations(
            strategyId,
            currentAllocations
        );
        
        // Check if rebalancing is needed
        if (!_shouldRebalance(strategyId, currentAllocations, optimalAllocations)) {
            return;
        }
        
        // Execute rebalancing
        RebalanceExecution memory execution = _executeRebalanceStrategy(
            strategyId,
            currentAllocations,
            optimalAllocations
        );
        
        // Update strategy
        strategy.lastRebalance = block.timestamp;
        totalRebalances++;
        
        // Record execution
        executionHistory[strategyId].push(execution);
        
        emit RebalanceExecuted(
            strategyId,
            strategy.asset,
            currentAllocations,
            optimalAllocations,
            execution.netBenefit,
            block.timestamp
        );
    }
    
    /**
     * @dev Execute emergency rebalancing
     */
    function executeEmergencyRebalance(
        uint256 strategyId
    ) external onlyRole(RISK_MANAGER_ROLE) {
        RebalanceStrategy storage strategy = strategies[strategyId];
        require(strategy.isActive, "Strategy not active");
        
        // Check if emergency conditions are met
        uint256 riskScore = riskEngine.calculateRiskScore(strategy.asset);
        require(
            riskScore >= riskParameters[strategy.asset].emergencyThreshold,
            "Emergency threshold not met"
        );
        
        strategy.isEmergencyMode = true;
        
        // Execute emergency rebalancing to safe allocations
        _executeEmergencyRebalancing(strategyId, riskScore);
        
        emit EmergencyRebalanceTriggered(
            strategyId,
            strategy.asset,
            riskScore,
            block.timestamp
        );
    }
    
    /**
     * @dev Update market conditions for asset
     */
    function updateMarketConditions(
        address asset
    ) external onlyRole(KEEPER_ROLE) {
        _updateMarketConditions(asset);
    }
    
    /**
     * @dev Optimize yield allocation for asset
     */
    function optimizeYieldAllocation(
        address asset
    ) external onlyRole(KEEPER_ROLE) {
        require(isAssetActive[asset], "Asset not active");
        
        YieldOptimization storage yieldOpt = yieldOptimizations[asset];
        
        // Update current yields from all protocols
        uint256[] memory strategyIds = assetStrategies[asset];
        for (uint256 i = 0; i < strategyIds.length; i++) {
            RebalanceStrategy storage strategy = strategies[strategyIds[i]];
            
            for (uint256 j = 0; j < strategy.targetProtocols.length; j++) {
                ProtocolType protocol = strategy.targetProtocols[j];
                uint256 currentYield = _getProtocolYield(asset, protocol);
                yieldOpt.currentYields[protocol] = currentYield;
                
                // Calculate projected yield
                uint256 projectedYield = _calculateProjectedYield(asset, protocol);
                yieldOpt.projectedYields[protocol] = projectedYield;
            }
        }
        
        // Calculate optimal yield target
        uint256 oldTarget = yieldOpt.optimalYieldTarget;
        uint256 newTarget = _calculateOptimalYieldTarget(asset);
        uint256 efficiency = _calculateYieldEfficiency(asset);
        
        yieldOpt.optimalYieldTarget = newTarget;
        yieldOpt.yieldEfficiency = efficiency;
        yieldOpt.lastYieldUpdate = block.timestamp;
        
        emit YieldOptimizationUpdated(
            asset,
            oldTarget,
            newTarget,
            efficiency
        );
    }
    
    /**
     * @dev Calculate optimal allocations based on strategy type
     */
    function _calculateOptimalAllocations(
        uint256 strategyId,
        uint256[] memory currentAllocations
    ) internal view returns (uint256[] memory) {
        RebalanceStrategy storage strategy = strategies[strategyId];
        
        if (strategy.strategyType == StrategyType.YIELD_OPTIMIZATION) {
            return _calculateYieldOptimizedAllocations(strategyId);
        } else if (strategy.strategyType == StrategyType.RISK_MINIMIZATION) {
            return _calculateRiskMinimizedAllocations(strategyId);
        } else if (strategy.strategyType == StrategyType.LIQUIDITY_MAXIMIZATION) {
            return _calculateLiquidityMaximizedAllocations(strategyId);
        } else if (strategy.strategyType == StrategyType.ARBITRAGE_CAPTURE) {
            return _calculateArbitrageOptimizedAllocations(strategyId);
        } else if (strategy.strategyType == StrategyType.DYNAMIC_HEDGING) {
            return _calculateDynamicHedgedAllocations(strategyId);
        }
        
        return strategy.targetAllocations;
    }
    
    /**
     * @dev Calculate yield-optimized allocations
     */
    function _calculateYieldOptimizedAllocations(
        uint256 strategyId
    ) internal view returns (uint256[] memory) {
        RebalanceStrategy storage strategy = strategies[strategyId];
        YieldOptimization storage yieldOpt = yieldOptimizations[strategy.asset];
        
        uint256[] memory allocations = new uint256[](strategy.targetProtocols.length);
        uint256[] memory yieldScores = new uint256[](strategy.targetProtocols.length);
        uint256 totalScore = 0;
        
        // Calculate yield scores for each protocol
        for (uint256 i = 0; i < strategy.targetProtocols.length; i++) {
            ProtocolType protocol = strategy.targetProtocols[i];
            uint256 currentYield = yieldOpt.currentYields[protocol];
            uint256 projectedYield = yieldOpt.projectedYields[protocol];
            uint256 volatility = yieldOpt.yieldVolatility[protocol];
            
            // Score = (current + projected) / (1 + volatility)
            yieldScores[i] = ((currentYield + projectedYield) * PRECISION) / (PRECISION + volatility);
            totalScore += yieldScores[i];
        }
        
        // Calculate allocations based on yield scores
        for (uint256 i = 0; i < strategy.targetProtocols.length; i++) {
            if (totalScore > 0) {
                allocations[i] = (yieldScores[i] * BASIS_POINTS) / totalScore;
                
                // Apply min/max constraints
                allocations[i] = Math.max(allocations[i], strategy.minAllocations[i]);
                allocations[i] = Math.min(allocations[i], strategy.maxAllocations[i]);
            } else {
                allocations[i] = strategy.targetAllocations[i];
            }
        }
        
        return _normalizeAllocations(allocations);
    }
    
    /**
     * @dev Calculate risk-minimized allocations
     */
    function _calculateRiskMinimizedAllocations(
        uint256 strategyId
    ) internal view returns (uint256[] memory) {
        RebalanceStrategy storage strategy = strategies[strategyId];
        RiskParameters storage riskParams = riskParameters[strategy.asset];
        
        uint256[] memory allocations = new uint256[](strategy.targetProtocols.length);
        uint256[] memory riskScores = new uint256[](strategy.targetProtocols.length);
        uint256 totalInverseRisk = 0;
        
        // Calculate inverse risk scores
        for (uint256 i = 0; i < strategy.targetProtocols.length; i++) {
            ProtocolType protocol = strategy.targetProtocols[i];
            uint256 riskScore = _getProtocolRiskScore(strategy.asset, protocol);
            
            // Inverse risk score (lower risk = higher allocation)
            riskScores[i] = riskScore > 0 ? (BASIS_POINTS * PRECISION) / riskScore : PRECISION;
            totalInverseRisk += riskScores[i];
        }
        
        // Calculate allocations based on inverse risk
        for (uint256 i = 0; i < strategy.targetProtocols.length; i++) {
            if (totalInverseRisk > 0) {
                allocations[i] = (riskScores[i] * BASIS_POINTS) / totalInverseRisk;
                
                // Apply concentration limits
                allocations[i] = Math.min(allocations[i], riskParams.maxConcentration);
                
                // Apply min/max constraints
                allocations[i] = Math.max(allocations[i], strategy.minAllocations[i]);
                allocations[i] = Math.min(allocations[i], strategy.maxAllocations[i]);
            } else {
                allocations[i] = strategy.targetAllocations[i];
            }
        }
        
        return _normalizeAllocations(allocations);
    }
    
    /**
     * @dev Calculate liquidity-maximized allocations
     */
    function _calculateLiquidityMaximizedAllocations(
        uint256 strategyId
    ) internal view returns (uint256[] memory) {
        RebalanceStrategy storage strategy = strategies[strategyId];
        
        uint256[] memory allocations = new uint256[](strategy.targetProtocols.length);
        uint256[] memory liquidityScores = new uint256[](strategy.targetProtocols.length);
        uint256 totalScore = 0;
        
        // Calculate liquidity scores
        for (uint256 i = 0; i < strategy.targetProtocols.length; i++) {
            ProtocolType protocol = strategy.targetProtocols[i];
            uint256 liquidityDepth = _getProtocolLiquidityDepth(strategy.asset, protocol);
            uint256 utilizationRate = _getProtocolUtilization(strategy.asset, protocol);
            
            // Score = liquidity_depth * (1 - utilization_rate)
            liquidityScores[i] = (liquidityDepth * (BASIS_POINTS - utilizationRate)) / BASIS_POINTS;
            totalScore += liquidityScores[i];
        }
        
        // Calculate allocations based on liquidity scores
        for (uint256 i = 0; i < strategy.targetProtocols.length; i++) {
            if (totalScore > 0) {
                allocations[i] = (liquidityScores[i] * BASIS_POINTS) / totalScore;
                
                // Apply min/max constraints
                allocations[i] = Math.max(allocations[i], strategy.minAllocations[i]);
                allocations[i] = Math.min(allocations[i], strategy.maxAllocations[i]);
            } else {
                allocations[i] = strategy.targetAllocations[i];
            }
        }
        
        return _normalizeAllocations(allocations);
    }
    
    /**
     * @dev Calculate arbitrage-optimized allocations
     */
    function _calculateArbitrageOptimizedAllocations(
        uint256 strategyId
    ) internal view returns (uint256[] memory) {
        RebalanceStrategy storage strategy = strategies[strategyId];
        
        uint256[] memory allocations = new uint256[](strategy.targetProtocols.length);
        uint256[] memory arbitrageScores = new uint256[](strategy.targetProtocols.length);
        uint256 totalScore = 0;
        
        // Calculate arbitrage opportunity scores
        for (uint256 i = 0; i < strategy.targetProtocols.length; i++) {
            ProtocolType protocol = strategy.targetProtocols[i];
            uint256 priceDeviation = _getProtocolPriceDeviation(strategy.asset, protocol);
            uint256 tradingVolume = _getProtocolTradingVolume(strategy.asset, protocol);
            
            // Score = price_deviation * trading_volume
            arbitrageScores[i] = (priceDeviation * tradingVolume) / PRECISION;
            totalScore += arbitrageScores[i];
        }
        
        // Calculate allocations based on arbitrage scores
        for (uint256 i = 0; i < strategy.targetProtocols.length; i++) {
            if (totalScore > 0) {
                allocations[i] = (arbitrageScores[i] * BASIS_POINTS) / totalScore;
                
                // Apply min/max constraints
                allocations[i] = Math.max(allocations[i], strategy.minAllocations[i]);
                allocations[i] = Math.min(allocations[i], strategy.maxAllocations[i]);
            } else {
                allocations[i] = strategy.targetAllocations[i];
            }
        }
        
        return _normalizeAllocations(allocations);
    }
    
    /**
     * @dev Calculate dynamic hedged allocations
     */
    function _calculateDynamicHedgedAllocations(
        uint256 strategyId
    ) internal view returns (uint256[] memory) {
        RebalanceStrategy storage strategy = strategies[strategyId];
        MarketCondition storage market = marketConditions[strategy.asset];
        
        uint256[] memory allocations = new uint256[](strategy.targetProtocols.length);
        
        // Adjust allocations based on market conditions
        for (uint256 i = 0; i < strategy.targetProtocols.length; i++) {
            uint256 baseAllocation = strategy.targetAllocations[i];
            
            // Adjust for volatility
            if (market.isHighVolatility) {
                // Reduce exposure to high-risk protocols
                if (_isHighRiskProtocol(strategy.targetProtocols[i])) {
                    baseAllocation = (baseAllocation * 7000) / BASIS_POINTS; // 70% of original
                }
            }
            
            // Adjust for market direction
            if (market.isBullish) {
                // Increase exposure to growth protocols
                if (_isGrowthProtocol(strategy.targetProtocols[i])) {
                    baseAllocation = (baseAllocation * 12000) / BASIS_POINTS; // 120% of original
                }
            } else if (market.isBearish) {
                // Increase exposure to stable protocols
                if (_isStableProtocol(strategy.targetProtocols[i])) {
                    baseAllocation = (baseAllocation * 11000) / BASIS_POINTS; // 110% of original
                }
            }
            
            // Apply constraints
            allocations[i] = Math.max(baseAllocation, strategy.minAllocations[i]);
            allocations[i] = Math.min(allocations[i], strategy.maxAllocations[i]);
        }
        
        return _normalizeAllocations(allocations);
    }
    
    /**
     * @dev Execute rebalancing strategy
     */
    function _executeRebalanceStrategy(
        uint256 strategyId,
        uint256[] memory currentAllocations,
        uint256[] memory optimalAllocations
    ) internal returns (RebalanceExecution memory) {
        RebalanceStrategy storage strategy = strategies[strategyId];
        
        uint256 gasStart = gasleft();
        
        // Calculate rebalancing moves
        (ProtocolType[] memory fromProtocols, 
         ProtocolType[] memory toProtocols, 
         uint256[] memory amounts) = _calculateRebalancingMoves(
            strategyId,
            currentAllocations,
            optimalAllocations
        );
        
        // Execute moves through cross-protocol bridge
        uint256[] memory actualSlippage = new uint256[](amounts.length);
        bool isSuccessful = true;
        
        for (uint256 i = 0; i < amounts.length; i++) {
            if (amounts[i] > MIN_REBALANCE_AMOUNT) {
                try crossProtocolBridge.executeSeamlessTransfer(
                    strategy.asset,
                    amounts[i],
                    CrossProtocolBridge.ProtocolType(uint8(fromProtocols[i])),
                    CrossProtocolBridge.ProtocolType(uint8(toProtocols[i])),
                    ""
                ) {
                    actualSlippage[i] = _calculateActualSlippage(strategy.asset, amounts[i]);
                } catch {
                    isSuccessful = false;
                    break;
                }
            }
        }
        
        uint256 gasUsed = gasStart - gasleft();
        uint256 gasCost = gasUsed * tx.gasprice;
        
        // Calculate net benefit
        uint256 netBenefit = _calculateNetBenefit(
            strategyId,
            currentAllocations,
            optimalAllocations,
            gasCost
        );
        
        return RebalanceExecution({
            strategyId: strategyId,
            asset: strategy.asset,
            fromProtocols: fromProtocols,
            toProtocols: toProtocols,
            amounts: amounts,
            actualSlippage: actualSlippage,
            totalGasCost: gasCost,
            netBenefit: netBenefit,
            timestamp: block.timestamp,
            isSuccessful: isSuccessful
        });
    }
    
    /**
     * @dev Execute emergency rebalancing
     */
    function _executeEmergencyRebalancing(
        uint256 strategyId,
        uint256 riskScore
    ) internal {
        RebalanceStrategy storage strategy = strategies[strategyId];
        
        // Move to safe allocations (e.g., more stable protocols)
        uint256[] memory safeAllocations = _calculateSafeAllocations(strategyId, riskScore);
        uint256[] memory currentAllocations = _getCurrentAllocations(strategyId);
        
        _executeRebalanceStrategy(strategyId, currentAllocations, safeAllocations);
    }
    
    /**
     * @dev Update market conditions
     */
    function _updateMarketConditions(address asset) internal {
        MarketCondition storage condition = marketConditions[asset];
        
        // Get market data from oracles and risk engine
        uint256 volatility = _calculateVolatility(asset);
        uint256 liquidityDepth = _calculateLiquidityDepth(asset);
        uint256 tradingVolume = _getTradingVolume(asset);
        uint256 yieldSpread = _calculateYieldSpread(asset);
        uint256 riskScore = riskEngine.calculateRiskScore(asset);
        
        // Determine market sentiment
        bool isBullish = _isBullishMarket(asset);
        bool isBearish = _isBearishMarket(asset);
        bool isHighVolatility = volatility > 2000; // 20%
        
        condition.volatility = volatility;
        condition.liquidityDepth = liquidityDepth;
        condition.tradingVolume = tradingVolume;
        condition.yieldSpread = yieldSpread;
        condition.riskScore = riskScore;
        condition.timestamp = block.timestamp;
        condition.isBullish = isBullish;
        condition.isBearish = isBearish;
        condition.isHighVolatility = isHighVolatility;
        
        emit MarketConditionUpdated(
            asset,
            volatility,
            riskScore,
            isBullish,
            block.timestamp
        );
    }
    
    /**
     * @dev Check if rebalancing should be executed
     */
    function _shouldRebalance(
        uint256 strategyId,
        uint256[] memory currentAllocations,
        uint256[] memory optimalAllocations
    ) internal view returns (bool) {
        RebalanceStrategy storage strategy = strategies[strategyId];
        
        // Calculate total deviation
        uint256 totalDeviation = 0;
        for (uint256 i = 0; i < currentAllocations.length; i++) {
            uint256 deviation = currentAllocations[i] > optimalAllocations[i] ?
                currentAllocations[i] - optimalAllocations[i] :
                optimalAllocations[i] - currentAllocations[i];
            totalDeviation += deviation;
        }
        
        return totalDeviation >= strategy.rebalanceThreshold;
    }
    
    /**
     * @dev Calculate rebalancing moves
     */
    function _calculateRebalancingMoves(
        uint256 strategyId,
        uint256[] memory currentAllocations,
        uint256[] memory optimalAllocations
    ) internal view returns (
        ProtocolType[] memory fromProtocols,
        ProtocolType[] memory toProtocols,
        uint256[] memory amounts
    ) {
        RebalanceStrategy storage strategy = strategies[strategyId];
        uint256 totalLiquidity = _getTotalLiquidity(strategy.asset);
        
        // Calculate moves needed
        uint256 moveCount = 0;
        for (uint256 i = 0; i < currentAllocations.length; i++) {
            if (currentAllocations[i] != optimalAllocations[i]) {
                moveCount++;
            }
        }
        
        fromProtocols = new ProtocolType[](moveCount);
        toProtocols = new ProtocolType[](moveCount);
        amounts = new uint256[](moveCount);
        
        uint256 moveIndex = 0;
        
        // Calculate actual moves
        for (uint256 i = 0; i < currentAllocations.length; i++) {
            if (optimalAllocations[i] > currentAllocations[i]) {
                // Need to add to this protocol
                uint256 addAmount = ((optimalAllocations[i] - currentAllocations[i]) * totalLiquidity) / BASIS_POINTS;
                
                // Find source protocol to move from
                for (uint256 j = 0; j < currentAllocations.length; j++) {
                    if (currentAllocations[j] > optimalAllocations[j] && moveIndex < moveCount) {
                        uint256 removeAmount = ((currentAllocations[j] - optimalAllocations[j]) * totalLiquidity) / BASIS_POINTS;
                        uint256 moveAmount = Math.min(addAmount, removeAmount);
                        
                        fromProtocols[moveIndex] = strategy.targetProtocols[j];
                        toProtocols[moveIndex] = strategy.targetProtocols[i];
                        amounts[moveIndex] = moveAmount;
                        
                        moveIndex++;
                        break;
                    }
                }
            }
        }
    }
    
    // Helper functions
    function _initializeRiskParameters(address asset) internal {
        riskParameters[asset] = RiskParameters({
            maxConcentration: 5000, // 50%
            maxVolatilityExposure: 3000, // 30%
            minLiquidityBuffer: 1000, // 10%
            emergencyThreshold: 8000, // 80% risk score
            correlationLimit: 7000, // 70%
            riskLimitsEnabled: true
        });
    }
    
    function _normalizeAllocations(uint256[] memory allocations) internal pure returns (uint256[] memory) {
        uint256 total = 0;
        for (uint256 i = 0; i < allocations.length; i++) {
            total += allocations[i];
        }
        
        if (total == 0) return allocations;
        
        for (uint256 i = 0; i < allocations.length; i++) {
            allocations[i] = (allocations[i] * BASIS_POINTS) / total;
        }
        
        return allocations;
    }
    
    function _getCurrentAllocations(uint256 strategyId) internal view returns (uint256[] memory) {
        RebalanceStrategy storage strategy = strategies[strategyId];
        uint256[] memory allocations = new uint256[](strategy.targetProtocols.length);
        
        uint256 totalLiquidity = _getTotalLiquidity(strategy.asset);
        
        for (uint256 i = 0; i < strategy.targetProtocols.length; i++) {
            uint256 protocolLiquidity = _getProtocolLiquidity(strategy.asset, strategy.targetProtocols[i]);
            allocations[i] = totalLiquidity > 0 ? (protocolLiquidity * BASIS_POINTS) / totalLiquidity : 0;
        }
        
        return allocations;
    }
    
    // Placeholder functions for external data
    function _getProtocolYield(address asset, ProtocolType protocol) internal view returns (uint256) {
        return 500; // 5% APY placeholder
    }
    
    function _calculateProjectedYield(address asset, ProtocolType protocol) internal view returns (uint256) {
        return 550; // 5.5% projected APY placeholder
    }
    
    function _calculateOptimalYieldTarget(address asset) internal view returns (uint256) {
        return 600; // 6% optimal target placeholder
    }
    
    function _calculateYieldEfficiency(address asset) internal view returns (uint256) {
        return 8500; // 85% efficiency placeholder
    }
    
    function _getProtocolRiskScore(address asset, ProtocolType protocol) internal view returns (uint256) {
        return 3000; // 30% risk score placeholder
    }
    
    function _getProtocolLiquidityDepth(address asset, ProtocolType protocol) internal view returns (uint256) {
        return 1000000 * PRECISION; // 1M liquidity depth placeholder
    }
    
    function _getProtocolUtilization(address asset, ProtocolType protocol) internal view returns (uint256) {
        return 7000; // 70% utilization placeholder
    }
    
    function _getProtocolPriceDeviation(address asset, ProtocolType protocol) internal view returns (uint256) {
        return 100; // 1% price deviation placeholder
    }
    
    function _getProtocolTradingVolume(address asset, ProtocolType protocol) internal view returns (uint256) {
        return 100000 * PRECISION; // 100K trading volume placeholder
    }
    
    function _getTotalLiquidity(address asset) internal view returns (uint256) {
        return 10000000 * PRECISION; // 10M total liquidity placeholder
    }
    
    function _getProtocolLiquidity(address asset, ProtocolType protocol) internal view returns (uint256) {
        return 2000000 * PRECISION; // 2M protocol liquidity placeholder
    }
    
    function _calculateVolatility(address asset) internal view returns (uint256) {
        return 1500; // 15% volatility placeholder
    }
    
    function _calculateLiquidityDepth(address asset) internal view returns (uint256) {
        return 5000000 * PRECISION; // 5M liquidity depth placeholder
    }
    
    function _getTradingVolume(address asset) internal view returns (uint256) {
        return 1000000 * PRECISION; // 1M trading volume placeholder
    }
    
    function _calculateYieldSpread(address asset) internal view returns (uint256) {
        return 200; // 2% yield spread placeholder
    }
    
    function _isBullishMarket(address asset) internal view returns (bool) {
        return true; // Placeholder
    }
    
    function _isBearishMarket(address asset) internal view returns (bool) {
        return false; // Placeholder
    }
    
    function _isHighRiskProtocol(ProtocolType protocol) internal pure returns (bool) {
        return protocol == ProtocolType.DEX; // Placeholder
    }
    
    function _isGrowthProtocol(ProtocolType protocol) internal pure returns (bool) {
        return protocol == ProtocolType.STAKING; // Placeholder
    }
    
    function _isStableProtocol(ProtocolType protocol) internal pure returns (bool) {
        return protocol == ProtocolType.LENDING; // Placeholder
    }
    
    function _calculateActualSlippage(address asset, uint256 amount) internal view returns (uint256) {
        return 50; // 0.5% slippage placeholder
    }
    
    function _calculateNetBenefit(
        uint256 strategyId,
        uint256[] memory currentAllocations,
        uint256[] memory optimalAllocations,
        uint256 gasCost
    ) internal view returns (uint256) {
        return 1000 * PRECISION; // 1000 net benefit placeholder
    }
    
    function _calculateSafeAllocations(
        uint256 strategyId,
        uint256 riskScore
    ) internal view returns (uint256[] memory) {
        RebalanceStrategy storage strategy = strategies[strategyId];
        uint256[] memory safeAllocations = new uint256[](strategy.targetProtocols.length);
        
        // Move more allocation to stable protocols during high risk
        for (uint256 i = 0; i < strategy.targetProtocols.length; i++) {
            if (_isStableProtocol(strategy.targetProtocols[i])) {
                safeAllocations[i] = 6000; // 60% to stable
            } else {
                safeAllocations[i] = 4000 / (strategy.targetProtocols.length - 1); // Distribute rest
            }
        }
        
        return _normalizeAllocations(safeAllocations);
    }
    
    // View functions
    function getStrategy(uint256 strategyId) external view returns (
        StrategyType strategyType,
        address asset,
        ProtocolType[] memory targetProtocols,
        uint256[] memory targetAllocations,
        bool isActive
    ) {
        RebalanceStrategy storage strategy = strategies[strategyId];
        return (
            strategy.strategyType,
            strategy.asset,
            strategy.targetProtocols,
            strategy.targetAllocations,
            strategy.isActive
        );
    }
    
    function getMarketCondition(address asset) external view returns (MarketCondition memory) {
        return marketConditions[asset];
    }
    
    function getExecutionHistory(uint256 strategyId) external view returns (RebalanceExecution[] memory) {
        return executionHistory[strategyId];
    }
    
    function getAssetStrategies(address asset) external view returns (uint256[] memory) {
        return assetStrategies[asset];
    }
    
    function getRiskParameters(address asset) external view returns (RiskParameters memory) {
        return riskParameters[asset];
    }
    
    function getRebalanceStats() external view returns (
        uint256 totalRebalancesCount,
        uint256 totalGasSavedAmount,
        uint256 totalYieldGeneratedAmount
    ) {
        return (totalRebalances, totalGasSaved, totalYieldGenerated);
    }
}
