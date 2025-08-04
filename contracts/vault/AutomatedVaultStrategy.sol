// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title AutomatedVaultStrategy
 * @dev Advanced automated vault strategy system with dynamic yield optimization
 */
contract AutomatedVaultStrategy is AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using Math for uint256;
    
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant STRATEGY_MANAGER_ROLE = keccak256("STRATEGY_MANAGER_ROLE");
    bytes32 public constant KEEPER_ROLE = keccak256("KEEPER_ROLE");
    bytes32 public constant VAULT_ROLE = keccak256("VAULT_ROLE");
    
    uint256 public constant PRECISION = 1e18;
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant MAX_STRATEGIES = 10;
    
    enum StrategyType {
        LENDING,
        LIQUIDITY_MINING,
        YIELD_FARMING,
        ARBITRAGE,
        DELTA_NEUTRAL,
        LEVERAGED_FARMING,
        STAKING,
        COMPOUND
    }
    
    enum StrategyStatus {
        INACTIVE,
        ACTIVE,
        PAUSED,
        DEPRECATED,
        EMERGENCY_EXIT
    }
    
    struct Strategy {
        uint256 strategyId;
        string name;
        StrategyType strategyType;
        address strategyContract;
        address targetAsset;
        uint256 targetAllocation; // Percentage in basis points
        uint256 currentAllocation;
        uint256 minAllocation;
        uint256 maxAllocation;
        uint256 expectedAPY;
        uint256 actualAPY;
        uint256 riskScore; // 1-100 scale
        uint256 totalDeposited;
        uint256 totalWithdrawn;
        uint256 totalRewards;
        uint256 lastRebalance;
        StrategyStatus status;
        bool autoCompound;
        bool emergencyWithdrawEnabled;
    }
    
    struct AllocationTarget {
        uint256 strategyId;
        uint256 targetPercentage;
        uint256 priority; // Higher number = higher priority
        uint256 minThreshold; // Minimum amount to allocate
        uint256 maxThreshold; // Maximum amount to allocate
    }
    
    struct RebalanceParams {
        uint256 rebalanceThreshold; // Percentage deviation to trigger rebalance
        uint256 maxSlippage; // Maximum slippage allowed during rebalance
        uint256 rebalanceInterval; // Minimum time between rebalances
        uint256 gasLimit; // Gas limit for rebalance operations
        bool autoRebalanceEnabled;
        bool emergencyRebalanceEnabled;
    }
    
    struct PerformanceMetrics {
        uint256 totalValueLocked;
        uint256 totalYieldGenerated;
        uint256 averageAPY;
        uint256 sharpeRatio;
        uint256 maxDrawdown;
        uint256 volatility;
        uint256 lastCalculation;
        uint256 performanceFee;
        uint256 managementFee;
    }
    
    struct RebalanceExecution {
        uint256 executionId;
        uint256 timestamp;
        uint256 totalValueBefore;
        uint256 totalValueAfter;
        uint256 gasUsed;
        uint256 strategiesRebalanced;
        bool successful;
        string reason;
    }
    
    // Storage
    mapping(uint256 => Strategy) public strategies;
    mapping(address => uint256[]) public assetStrategies; // asset -> strategy IDs
    mapping(uint256 => AllocationTarget[]) public strategyAllocations;
    mapping(address => RebalanceParams) public rebalanceParams;
    mapping(address => PerformanceMetrics) public performanceMetrics;
    mapping(uint256 => RebalanceExecution) public rebalanceHistory;
    
    // Strategy tracking
    uint256 public strategyCounter;
    uint256 public rebalanceCounter;
    uint256[] public activeStrategies;
    
    // Global parameters
    uint256 public globalRiskTolerance = 5000; // 50%
    uint256 public maxConcentrationRisk = 3000; // 30% max in single strategy
    uint256 public performanceFeeRate = 1000; // 10%
    uint256 public managementFeeRate = 200; // 2%
    address public feeRecipient;
    
    // Emergency controls
    bool public emergencyMode;
    bool public rebalancingPaused;
    mapping(uint256 => bool) public strategyEmergencyExit;
    
    event StrategyAdded(
        uint256 indexed strategyId,
        string name,
        StrategyType strategyType,
        address strategyContract
    );
    
    event StrategyRebalanced(
        uint256 indexed strategyId,
        uint256 oldAllocation,
        uint256 newAllocation,
        uint256 timestamp
    );
    
    event YieldHarvested(
        uint256 indexed strategyId,
        uint256 yieldAmount,
        uint256 performanceFee,
        uint256 timestamp
    );
    
    event EmergencyExitExecuted(
        uint256 indexed strategyId,
        uint256 amountWithdrawn,
        string reason
    );
    
    event PerformanceUpdated(
        address indexed asset,
        uint256 totalValue,
        uint256 averageAPY,
        uint256 sharpeRatio
    );
    
    constructor(address _feeRecipient) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(STRATEGY_MANAGER_ROLE, msg.sender);
        _grantRole(KEEPER_ROLE, msg.sender);
        
        feeRecipient = _feeRecipient;
    }
    
    /**
     * @dev Add a new strategy to the system
     */
    function addStrategy(
        string memory name,
        StrategyType strategyType,
        address strategyContract,
        address targetAsset,
        uint256 targetAllocation,
        uint256 minAllocation,
        uint256 maxAllocation,
        uint256 expectedAPY,
        uint256 riskScore
    ) external onlyRole(STRATEGY_MANAGER_ROLE) {
        require(strategyContract != address(0), "Invalid strategy contract");
        require(targetAsset != address(0), "Invalid target asset");
        require(targetAllocation <= BASIS_POINTS, "Invalid target allocation");
        require(minAllocation <= maxAllocation, "Invalid allocation bounds");
        require(riskScore <= 100, "Invalid risk score");
        
        uint256 strategyId = ++strategyCounter;
        
        strategies[strategyId] = Strategy({
            strategyId: strategyId,
            name: name,
            strategyType: strategyType,
            strategyContract: strategyContract,
            targetAsset: targetAsset,
            targetAllocation: targetAllocation,
            currentAllocation: 0,
            minAllocation: minAllocation,
            maxAllocation: maxAllocation,
            expectedAPY: expectedAPY,
            actualAPY: 0,
            riskScore: riskScore,
            totalDeposited: 0,
            totalWithdrawn: 0,
            totalRewards: 0,
            lastRebalance: block.timestamp,
            status: StrategyStatus.ACTIVE,
            autoCompound: true,
            emergencyWithdrawEnabled: true
        });
        
        assetStrategies[targetAsset].push(strategyId);
        activeStrategies.push(strategyId);
        
        emit StrategyAdded(strategyId, name, strategyType, strategyContract);
    }
    
    /**
     * @dev Execute automated rebalancing across all strategies
     */
    function executeAutoRebalance(address asset) external onlyRole(KEEPER_ROLE) nonReentrant {
        require(!rebalancingPaused && !emergencyMode, "Rebalancing disabled");
        
        RebalanceParams memory params = rebalanceParams[asset];
        require(params.autoRebalanceEnabled, "Auto rebalance disabled");
        require(
            block.timestamp >= params.rebalanceInterval + block.timestamp,
            "Rebalance interval not met"
        );
        
        uint256 executionId = ++rebalanceCounter;
        uint256 startGas = gasleft();
        uint256 totalValueBefore = _calculateTotalValue(asset);
        
        uint256[] memory strategyIds = assetStrategies[asset];
        uint256 strategiesRebalanced = 0;
        bool successful = true;
        string memory reason = "Automated rebalance";
        
        try this._executeRebalanceLogic(asset, strategyIds) {
            strategiesRebalanced = strategyIds.length;
        } catch Error(string memory error) {
            successful = false;
            reason = error;
        }
        
        uint256 totalValueAfter = _calculateTotalValue(asset);
        uint256 gasUsed = startGas - gasleft();
        
        rebalanceHistory[executionId] = RebalanceExecution({
            executionId: executionId,
            timestamp: block.timestamp,
            totalValueBefore: totalValueBefore,
            totalValueAfter: totalValueAfter,
            gasUsed: gasUsed,
            strategiesRebalanced: strategiesRebalanced,
            successful: successful,
            reason: reason
        });
        
        // Update performance metrics
        _updatePerformanceMetrics(asset);
    }
    
    /**
     * @dev Internal rebalance logic (external for try-catch)
     */
    function _executeRebalanceLogic(address asset, uint256[] memory strategyIds) external {
        require(msg.sender == address(this), "Internal only");
        
        uint256 totalValue = _calculateTotalValue(asset);
        
        for (uint256 i = 0; i < strategyIds.length; i++) {
            uint256 strategyId = strategyIds[i];
            Strategy storage strategy = strategies[strategyId];
            
            if (strategy.status != StrategyStatus.ACTIVE) continue;
            
            uint256 targetValue = (totalValue * strategy.targetAllocation) / BASIS_POINTS;
            uint256 currentValue = strategy.currentAllocation;
            
            if (_shouldRebalance(currentValue, targetValue, asset)) {
                _rebalanceStrategy(strategyId, targetValue);
            }
        }
    }
    
    /**
     * @dev Harvest yield from all strategies
     */
    function harvestAllYield(address asset) external onlyRole(KEEPER_ROLE) nonReentrant {
        uint256[] memory strategyIds = assetStrategies[asset];
        
        for (uint256 i = 0; i < strategyIds.length; i++) {
            uint256 strategyId = strategyIds[i];
            Strategy storage strategy = strategies[strategyId];
            
            if (strategy.status == StrategyStatus.ACTIVE && strategy.autoCompound) {
                _harvestStrategy(strategyId);
            }
        }
    }
    
    /**
     * @dev Harvest yield from specific strategy
     */
    function _harvestStrategy(uint256 strategyId) internal {
        Strategy storage strategy = strategies[strategyId];
        
        // Call strategy contract to harvest yield
        uint256 yieldAmount = _calculateStrategyYield(strategy);
        
        // Update strategy performance metrics
        _updateStrategyMetrics(strategyId, yieldAmount);
        
        if (yieldAmount > 0) {
            uint256 performanceFee = (yieldAmount * performanceFeeRate) / BASIS_POINTS;
            uint256 netYield = yieldAmount - performanceFee;
            
            strategy.totalRewards += netYield;
            
            if (performanceFee > 0) {
                IERC20(strategy.targetAsset).safeTransfer(feeRecipient, performanceFee);
            }
            
            emit YieldHarvested(strategyId, yieldAmount, performanceFee, block.timestamp);
        }
    }
    
    /**
     * @dev Execute emergency exit for a strategy
     */
    function emergencyExitStrategy(uint256 strategyId, string memory reason) 
        external 
        onlyRole(STRATEGY_MANAGER_ROLE) 
        nonReentrant 
    {
        Strategy storage strategy = strategies[strategyId];
        require(strategy.emergencyWithdrawEnabled, "Emergency exit disabled");
        
        strategy.status = StrategyStatus.EMERGENCY_EXIT;
        strategyEmergencyExit[strategyId] = true;
        
        // Withdraw all funds from strategy
        uint256 amountWithdrawn = strategy.currentAllocation;
        strategy.currentAllocation = 0;
        strategy.totalWithdrawn += amountWithdrawn;
        
        emit EmergencyExitExecuted(strategyId, amountWithdrawn, reason);
    }
    
    /**
     * @dev Optimize strategy allocations based on performance
     */
    function optimizeAllocations(address asset) external onlyRole(STRATEGY_MANAGER_ROLE) {
        uint256[] memory strategyIds = assetStrategies[asset];
        
        // Calculate performance scores
        uint256[] memory performanceScores = new uint256[](strategyIds.length);
        uint256 totalScore = 0;
        
        for (uint256 i = 0; i < strategyIds.length; i++) {
            uint256 strategyId = strategyIds[i];
            Strategy memory strategy = strategies[strategyId];
            
            if (strategy.status == StrategyStatus.ACTIVE) {
                // Performance score based on APY, risk, and reliability
                uint256 score = _calculatePerformanceScore(strategy);
                performanceScores[i] = score;
                totalScore += score;
            }
        }
        
        // Redistribute allocations based on performance
        for (uint256 i = 0; i < strategyIds.length; i++) {
            if (performanceScores[i] > 0) {
                uint256 newAllocation = (performanceScores[i] * BASIS_POINTS) / totalScore;
                
                // Apply constraints
                newAllocation = Math.max(newAllocation, strategies[strategyIds[i]].minAllocation);
                newAllocation = Math.min(newAllocation, strategies[strategyIds[i]].maxAllocation);
                
                strategies[strategyIds[i]].targetAllocation = newAllocation;
            }
        }
    }
    
    /**
     * @dev Calculate performance score for a strategy
     */
    function _calculatePerformanceScore(Strategy memory strategy) internal pure returns (uint256) {
        // Weighted score: 50% APY, 30% risk-adjusted return, 20% reliability
        uint256 apyScore = strategy.actualAPY;
        uint256 riskAdjustedScore = strategy.actualAPY * (100 - strategy.riskScore) / 100;
        uint256 reliabilityScore = strategy.totalRewards > 0 ? 100 : 50;
        
        return (apyScore * 50 + riskAdjustedScore * 30 + reliabilityScore * 20) / 100;
    }
    
    /**
     * @dev Check if strategy should be rebalanced
     */
    function _shouldRebalance(uint256 currentValue, uint256 targetValue, address asset) 
        internal 
        view 
        returns (bool) 
    {
        if (targetValue == 0) return currentValue > 0;
        
        uint256 deviation = currentValue > targetValue ? 
            ((currentValue - targetValue) * BASIS_POINTS) / targetValue :
            ((targetValue - currentValue) * BASIS_POINTS) / targetValue;
        
        return deviation > rebalanceParams[asset].rebalanceThreshold;
    }
    
    /**
     * @dev Rebalance specific strategy
     */
    function _rebalanceStrategy(uint256 strategyId, uint256 targetValue) internal {
        Strategy storage strategy = strategies[strategyId];
        uint256 oldAllocation = strategy.currentAllocation;
        
        if (targetValue > oldAllocation) {
            // Increase allocation
            uint256 increaseAmount = targetValue - oldAllocation;
            strategy.currentAllocation = targetValue;
            strategy.totalDeposited += increaseAmount;
        } else {
            // Decrease allocation
            uint256 decreaseAmount = oldAllocation - targetValue;
            strategy.currentAllocation = targetValue;
            strategy.totalWithdrawn += decreaseAmount;
        }
        
        strategy.lastRebalance = block.timestamp;
        
        emit StrategyRebalanced(strategyId, oldAllocation, targetValue, block.timestamp);
    }
    
    /**
     * @dev Calculate total value across all strategies for an asset
     */
    function _calculateTotalValue(address asset) internal view returns (uint256) {
        uint256[] memory strategyIds = assetStrategies[asset];
        uint256 totalValue = 0;
        
        for (uint256 i = 0; i < strategyIds.length; i++) {
            totalValue += strategies[strategyIds[i]].currentAllocation;
        }
        
        return totalValue;
    }
    
    /**
     * @dev Update performance metrics for an asset
     */
    function _updatePerformanceMetrics(address asset) internal {
        PerformanceMetrics storage metrics = performanceMetrics[asset];
        
        uint256 totalValue = _calculateTotalValue(asset);
        uint256[] memory strategyIds = assetStrategies[asset];
        
        uint256 totalYield = 0;
        uint256 weightedAPY = 0;
        
        for (uint256 i = 0; i < strategyIds.length; i++) {
            Strategy memory strategy = strategies[strategyIds[i]];
            totalYield += strategy.totalRewards;
            weightedAPY += (strategy.actualAPY * strategy.currentAllocation);
        }
        
        metrics.totalValueLocked = totalValue;
        metrics.totalYieldGenerated = totalYield;
        metrics.averageAPY = totalValue > 0 ? weightedAPY / totalValue : 0;
        metrics.lastCalculation = block.timestamp;
        
        emit PerformanceUpdated(asset, totalValue, metrics.averageAPY, metrics.sharpeRatio);
    }
    
    /**
     * @dev Set rebalance parameters for an asset
     */
    function setRebalanceParams(
        address asset,
        uint256 rebalanceThreshold,
        uint256 maxSlippage,
        uint256 rebalanceInterval,
        bool autoRebalanceEnabled
    ) external onlyRole(STRATEGY_MANAGER_ROLE) {
        rebalanceParams[asset] = RebalanceParams({
            rebalanceThreshold: rebalanceThreshold,
            maxSlippage: maxSlippage,
            rebalanceInterval: rebalanceInterval,
            gasLimit: 500000,
            autoRebalanceEnabled: autoRebalanceEnabled,
            emergencyRebalanceEnabled: true
        });
    }
    
    /**
     * @dev Get strategy performance data
     */
    function getStrategyPerformance(uint256 strategyId) 
        external 
        view 
        returns (
            uint256 totalDeposited,
            uint256 totalWithdrawn,
            uint256 totalRewards,
            uint256 actualAPY,
            uint256 currentAllocation
        ) 
    {
        Strategy memory strategy = strategies[strategyId];
        return (
            strategy.totalDeposited,
            strategy.totalWithdrawn,
            strategy.totalRewards,
            strategy.actualAPY,
            strategy.currentAllocation
        );
    }
    
    /**
     * @dev Get asset strategies
     */
    function getAssetStrategies(address asset) external view returns (uint256[] memory) {
        return assetStrategies[asset];
    }
    
    /**
     * @dev Emergency pause all rebalancing
     */
    function emergencyPauseRebalancing() external onlyRole(ADMIN_ROLE) {
        rebalancingPaused = true;
    }
    
    /**
     * @dev Resume rebalancing
     */
    function resumeRebalancing() external onlyRole(ADMIN_ROLE) {
        rebalancingPaused = false;
    }
    
    /**
     * @dev Update strategy status
     */
    function updateStrategyStatus(uint256 strategyId, StrategyStatus newStatus) 
        external 
        onlyRole(STRATEGY_MANAGER_ROLE) 
    {
        strategies[strategyId].status = newStatus;
    }
    
    /**
     * @dev Update fee rates
     */
    function updateFeeRates(uint256 newPerformanceFee, uint256 newManagementFee) 
        external 
        onlyRole(ADMIN_ROLE) 
    {
        require(newPerformanceFee <= 2000, "Performance fee too high"); // Max 20%
        require(newManagementFee <= 500, "Management fee too high"); // Max 5%
        
        performanceFeeRate = newPerformanceFee;
        managementFeeRate = newManagementFee;
    }

    /**
     * @dev Calculate strategy yield based on current performance
     */
    function _calculateStrategyYield(Strategy storage strategy) internal view returns (uint256) {
        // Calculate yield based on strategy type and current market conditions
        uint256 baseYield = (strategy.totalAllocated * strategy.expectedAPY) / (BASIS_POINTS * 365);
        
        // Apply performance multiplier based on strategy health
        uint256 performanceMultiplier = 100;
        if (strategy.currentAPY > strategy.expectedAPY) {
            performanceMultiplier = 110; // 10% bonus for outperformance
        } else if (strategy.currentAPY < strategy.expectedAPY / 2) {
            performanceMultiplier = 80; // 20% penalty for underperformance
        }
        
        return (baseYield * performanceMultiplier) / 100;
    }

    /**
     * @dev Update strategy performance metrics
     */
    function _updateStrategyMetrics(uint256 strategyId, uint256 yieldAmount) internal {
        Strategy storage strategy = strategies[strategyId];
        
        // Update total yield generated
        strategy.totalYieldGenerated += yieldAmount;
        
        // Update current APY based on recent performance
        if (strategy.totalAllocated > 0) {
            uint256 dailyReturn = (yieldAmount * BASIS_POINTS) / strategy.totalAllocated;
            strategy.currentAPY = dailyReturn * 365;
        }
        
        // Update last harvest timestamp
        strategy.lastHarvest = block.timestamp;
    }
}