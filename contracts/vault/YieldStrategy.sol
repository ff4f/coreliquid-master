// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "./YieldAggregator.sol";
import "./YieldOptimizer.sol";

/**
 * @title YieldStrategy
 * @dev Implements various yield farming strategies with automated execution
 */
contract YieldStrategy is AccessControl, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;
    using Math for uint256;

    
    bytes32 public constant STRATEGY_MANAGER_ROLE = keccak256("STRATEGY_MANAGER_ROLE");
    bytes32 public constant KEEPER_ROLE = keccak256("KEEPER_ROLE");
    bytes32 public constant HARVESTER_ROLE = keccak256("HARVESTER_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
    
    enum StrategyType {
        SINGLE_ASSET,
        DUAL_ASSET,
        MULTI_ASSET,
        LEVERAGED,
        DELTA_NEUTRAL,
        ARBITRAGE,
        YIELD_FARMING,
        LIQUIDITY_MINING
    }
    
    enum StrategyStatus {
        INACTIVE,
        ACTIVE,
        PAUSED,
        DEPRECATED,
        EMERGENCY
    }
    
    struct Strategy {
        uint256 id;
        string name;
        string description;
        StrategyType strategyType;
        StrategyStatus status;
        address[] inputTokens;
        address[] outputTokens;
        address[] protocols;
        uint256 minDeposit;
        uint256 maxDeposit;
        uint256 totalDeposited;
        uint256 totalShares;
        uint256 lastHarvest;
        uint256 harvestInterval;
        uint256 performanceFee; // in basis points
        uint256 managementFee; // in basis points
        uint256 riskLevel; // 1-10 scale
        uint256 expectedAPY;
        uint256 actualAPY;
        bool isActive;
        mapping(address => uint256) userShares;
        mapping(address => uint256) userDeposits;
        mapping(address => uint256) userLastDeposit;
        mapping(address => uint256) userRewards;
    }
    
    struct StrategyConfig {
        uint256 rebalanceThreshold; // in basis points
        uint256 slippageTolerance; // in basis points
        uint256 maxGasPrice;
        uint256 minProfitThreshold;
        bool autoCompound;
        bool autoRebalance;
        bool emergencyWithdrawEnabled;
        uint256 withdrawalFee; // in basis points
        uint256 depositFee; // in basis points
    }
    
    struct PerformanceMetrics {
        uint256 totalReturn;
        uint256 annualizedReturn;
        uint256 maxDrawdown;
        uint256 sharpeRatio;
        uint256 volatility;
        uint256 winRate;
        uint256 totalTrades;
        uint256 profitableTrades;
        uint256 lastUpdate;
    }
    
    struct RebalanceParams {
        address[] targetTokens;
        uint256[] targetAllocations;
        uint256 deadline;
        uint256 maxSlippage;
        bytes routerCalldata;
    }
    
    struct HarvestInfo {
        uint256 timestamp;
        uint256 totalRewards;
        uint256 gasUsed;
        uint256 profitGenerated;
        address harvester;
        bool successful;
    }
    
    mapping(uint256 => Strategy) public strategies;
    mapping(uint256 => StrategyConfig) public strategyConfigs;
    mapping(uint256 => PerformanceMetrics) public performanceMetrics;
    mapping(uint256 => mapping(uint256 => HarvestInfo)) public harvestHistory;
    mapping(uint256 => uint256) public harvestCounts;
    mapping(address => uint256[]) public userStrategies;
    mapping(address => mapping(uint256 => bool)) public userStrategyExists;
    
    uint256 public strategiesCount;
    uint256 public totalValueLocked;
    uint256 public totalRewardsDistributed;
    
    YieldAggregator public yieldAggregator;
    YieldOptimizer public yieldOptimizer;
    
    address public feeRecipient;
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant MAX_PERFORMANCE_FEE = 2000; // 20%
    uint256 public constant MAX_MANAGEMENT_FEE = 200; // 2%
    uint256 public constant MAX_STRATEGIES_PER_USER = 50;
    uint256 public constant HARVEST_HISTORY_LIMIT = 100;
    
    event StrategyCreated(
        uint256 indexed strategyId,
        string name,
        StrategyType strategyType,
        uint256 expectedAPY
    );
    
    event StrategyDeposit(
        uint256 indexed strategyId,
        address indexed user,
        uint256 amount,
        uint256 shares
    );
    
    event StrategyWithdraw(
        uint256 indexed strategyId,
        address indexed user,
        uint256 shares,
        uint256 amount
    );
    
    event StrategyHarvested(
        uint256 indexed strategyId,
        address indexed harvester,
        uint256 rewards,
        uint256 gasUsed
    );
    
    event StrategyRebalanced(
        uint256 indexed strategyId,
        address[] newTokens,
        uint256[] newAllocations
    );
    
    event PerformanceUpdated(
        uint256 indexed strategyId,
        uint256 totalReturn,
        uint256 annualizedReturn,
        uint256 sharpeRatio
    );
    
    event EmergencyWithdraw(
        uint256 indexed strategyId,
        address indexed user,
        uint256 amount
    );
    
    constructor(
        address _yieldAggregator,
        address _yieldOptimizer,
        address _feeRecipient
    ) {
        require(_yieldAggregator != address(0), "Invalid yield aggregator");
        require(_yieldOptimizer != address(0), "Invalid yield optimizer");
        require(_feeRecipient != address(0), "Invalid fee recipient");
        
        yieldAggregator = YieldAggregator(_yieldAggregator);
        yieldOptimizer = YieldOptimizer(_yieldOptimizer);
        feeRecipient = _feeRecipient;
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(STRATEGY_MANAGER_ROLE, msg.sender);
        _grantRole(KEEPER_ROLE, msg.sender);
        _grantRole(HARVESTER_ROLE, msg.sender);
        _grantRole(EMERGENCY_ROLE, msg.sender);
    }
    
    function createStrategy(
        string memory name,
        string memory description,
        StrategyType strategyType,
        address[] memory inputTokens,
        address[] memory outputTokens,
        address[] memory protocols,
        uint256 minDeposit,
        uint256 maxDeposit,
        uint256 harvestInterval,
        uint256 performanceFee,
        uint256 managementFee,
        uint256 riskLevel,
        uint256 expectedAPY
    ) external onlyRole(STRATEGY_MANAGER_ROLE) returns (uint256) {
        require(bytes(name).length > 0, "Invalid name");
        require(inputTokens.length > 0, "No input tokens");
        require(performanceFee <= MAX_PERFORMANCE_FEE, "Performance fee too high");
        require(managementFee <= MAX_MANAGEMENT_FEE, "Management fee too high");
        require(riskLevel >= 1 && riskLevel <= 10, "Invalid risk level");
        require(minDeposit <= maxDeposit, "Invalid deposit limits");
        
        uint256 strategyId = strategiesCount;
        Strategy storage strategy = strategies[strategyId];
        
        strategy.id = strategyId;
        strategy.name = name;
        strategy.description = description;
        strategy.strategyType = strategyType;
        strategy.status = StrategyStatus.ACTIVE;
        strategy.inputTokens = inputTokens;
        strategy.outputTokens = outputTokens;
        strategy.protocols = protocols;
        strategy.minDeposit = minDeposit;
        strategy.maxDeposit = maxDeposit;
        strategy.harvestInterval = harvestInterval;
        strategy.performanceFee = performanceFee;
        strategy.managementFee = managementFee;
        strategy.riskLevel = riskLevel;
        strategy.expectedAPY = expectedAPY;
        strategy.isActive = true;
        strategy.lastHarvest = block.timestamp;
        
        // Set default config
        StrategyConfig storage config = strategyConfigs[strategyId];
        config.rebalanceThreshold = 500; // 5%
        config.slippageTolerance = 100; // 1%
        config.maxGasPrice = 100 gwei;
        config.minProfitThreshold = 1e18; // 1 token
        config.autoCompound = true;
        config.autoRebalance = true;
        config.emergencyWithdrawEnabled = true;
        config.withdrawalFee = 50; // 0.5%
        config.depositFee = 25; // 0.25%
        
        strategiesCount++;
        
        emit StrategyCreated(strategyId, name, strategyType, expectedAPY);
        
        return strategyId;
    }
    
    function deposit(
        uint256 strategyId,
        uint256 amount
    ) external nonReentrant whenNotPaused {
        require(strategyId < strategiesCount, "Strategy not found");
        require(amount > 0, "Invalid amount");
        
        Strategy storage strategy = strategies[strategyId];
        require(strategy.isActive, "Strategy not active");
        require(strategy.status == StrategyStatus.ACTIVE, "Strategy not available");
        require(amount >= strategy.minDeposit, "Below minimum deposit");
        require(
            strategy.totalDeposited + amount <= strategy.maxDeposit,
            "Exceeds maximum deposit"
        );
        
        // Check user strategy limit
        if (!userStrategyExists[msg.sender][strategyId]) {
            require(
                userStrategies[msg.sender].length < MAX_STRATEGIES_PER_USER,
                "Too many strategies"
            );
            userStrategies[msg.sender].push(strategyId);
            userStrategyExists[msg.sender][strategyId] = true;
        }
        
        // Transfer input token
        address inputToken = strategy.inputTokens[0]; // Simplified for single input
        IERC20(inputToken).safeTransferFrom(msg.sender, address(this), amount);
        
        // Calculate deposit fee
        StrategyConfig storage config = strategyConfigs[strategyId];
        uint256 depositFee = (amount * config.depositFee) / BASIS_POINTS;
        uint256 netAmount = amount - depositFee;
        
        // Send fee to recipient
        if (depositFee > 0) {
            IERC20(inputToken).safeTransfer(feeRecipient, depositFee);
        }
        
        // Calculate shares
        uint256 shares;
        if (strategy.totalShares == 0) {
            shares = netAmount;
        } else {
            shares = (netAmount * strategy.totalShares) / strategy.totalDeposited;
        }
        
        // Update strategy state
        strategy.totalDeposited += netAmount;
        strategy.totalShares += shares;
        strategy.userShares[msg.sender] += shares;
        strategy.userDeposits[msg.sender] += netAmount;
        strategy.userLastDeposit[msg.sender] = block.timestamp;
        
        totalValueLocked += netAmount;
        
        // Execute strategy logic
        _executeStrategyDeposit(strategyId, netAmount);
        
        emit StrategyDeposit(strategyId, msg.sender, amount, shares);
    }
    
    function withdraw(
        uint256 strategyId,
        uint256 shares
    ) external nonReentrant {
        require(strategyId < strategiesCount, "Strategy not found");
        require(shares > 0, "Invalid shares");
        
        Strategy storage strategy = strategies[strategyId];
        require(strategy.userShares[msg.sender] >= shares, "Insufficient shares");
        
        // Calculate withdrawal amount
        uint256 totalAmount = (shares * strategy.totalDeposited) / strategy.totalShares;
        
        // Calculate withdrawal fee
        StrategyConfig storage config = strategyConfigs[strategyId];
        uint256 withdrawalFee = (totalAmount * config.withdrawalFee) / BASIS_POINTS;
        uint256 netAmount = totalAmount - withdrawalFee;
        
        // Execute strategy withdrawal
        uint256 actualAmount = _executeStrategyWithdraw(strategyId, totalAmount);
        
        // Adjust for actual amount received
        if (actualAmount < totalAmount) {
            withdrawalFee = (actualAmount * config.withdrawalFee) / BASIS_POINTS;
            netAmount = actualAmount - withdrawalFee;
        }
        
        // Update strategy state
        strategy.totalShares -= shares;
        strategy.totalDeposited -= totalAmount;
        strategy.userShares[msg.sender] -= shares;
        strategy.userDeposits[msg.sender] = (strategy.userDeposits[msg.sender] * (strategy.userShares[msg.sender])) / (strategy.userShares[msg.sender] + shares);
        
        totalValueLocked -= totalAmount;
        
        // Transfer tokens
        address outputToken = strategy.inputTokens[0]; // Simplified
        if (withdrawalFee > 0) {
            IERC20(outputToken).safeTransfer(feeRecipient, withdrawalFee);
        }
        IERC20(outputToken).safeTransfer(msg.sender, netAmount);
        
        emit StrategyWithdraw(strategyId, msg.sender, shares, netAmount);
    }
    
    function harvest(
        uint256 strategyId
    ) external onlyRole(HARVESTER_ROLE) nonReentrant {
        require(strategyId < strategiesCount, "Strategy not found");
        
        Strategy storage strategy = strategies[strategyId];
        require(strategy.isActive, "Strategy not active");
        require(
            block.timestamp >= strategy.lastHarvest + strategy.harvestInterval,
            "Harvest too early"
        );
        
        uint256 gasStart = gasleft();
        
        // Execute harvest logic
        uint256 rewards = _executeHarvest(strategyId);
        
        uint256 gasUsed = gasStart - gasleft();
        
        // Calculate performance fee
        uint256 performanceFee = (rewards * strategy.performanceFee) / BASIS_POINTS;
        uint256 netRewards = rewards - performanceFee;
        
        // Update strategy state
        strategy.lastHarvest = block.timestamp;
        strategy.totalDeposited += netRewards; // Auto-compound
        totalRewardsDistributed += rewards;
        
        // Record harvest
        uint256 harvestId = harvestCounts[strategyId];
        harvestHistory[strategyId][harvestId] = HarvestInfo({
            timestamp: block.timestamp,
            totalRewards: rewards,
            gasUsed: gasUsed,
            profitGenerated: netRewards,
            harvester: msg.sender,
            successful: true
        });
        harvestCounts[strategyId]++;
        
        // Limit harvest history
        if (harvestCounts[strategyId] > HARVEST_HISTORY_LIMIT) {
            delete harvestHistory[strategyId][harvestId - HARVEST_HISTORY_LIMIT];
        }
        
        // Send performance fee
        if (performanceFee > 0) {
            address rewardToken = strategy.outputTokens.length > 0 ? strategy.outputTokens[0] : strategy.inputTokens[0];
            IERC20(rewardToken).safeTransfer(feeRecipient, performanceFee);
        }
        
        // Update performance metrics
        _updatePerformanceMetrics(strategyId, rewards);
        
        emit StrategyHarvested(strategyId, msg.sender, rewards, gasUsed);
    }
    
    function rebalance(
        uint256 strategyId,
        RebalanceParams memory params
    ) external onlyRole(KEEPER_ROLE) nonReentrant {
        require(strategyId < strategiesCount, "Strategy not found");
        require(params.deadline >= block.timestamp, "Deadline passed");
        
        Strategy storage strategy = strategies[strategyId];
        require(strategy.isActive, "Strategy not active");
        
        StrategyConfig storage config = strategyConfigs[strategyId];
        require(config.autoRebalance, "Auto rebalance disabled");
        
        // Check if rebalance is needed
        bool needsRebalance = _checkRebalanceNeeded(strategyId, params.targetAllocations);
        require(needsRebalance, "Rebalance not needed");
        
        // Execute rebalance
        _executeRebalance(strategyId, params);
        
        emit StrategyRebalanced(strategyId, params.targetTokens, params.targetAllocations);
    }
    
    function emergencyWithdraw(
        uint256 strategyId
    ) external nonReentrant {
        require(strategyId < strategiesCount, "Strategy not found");
        
        Strategy storage strategy = strategies[strategyId];
        StrategyConfig storage config = strategyConfigs[strategyId];
        
        require(config.emergencyWithdrawEnabled, "Emergency withdraw disabled");
        require(strategy.userShares[msg.sender] > 0, "No shares");
        
        uint256 userShares = strategy.userShares[msg.sender];
        uint256 totalAmount = (userShares * strategy.totalDeposited) / strategy.totalShares;
        
        // Execute emergency withdrawal (no fees)
        uint256 actualAmount = _executeEmergencyWithdraw(strategyId, totalAmount);
        
        // Update state
        strategy.totalShares -= userShares;
        strategy.totalDeposited -= totalAmount;
        strategy.userShares[msg.sender] = 0;
        strategy.userDeposits[msg.sender] = 0;
        
        totalValueLocked -= totalAmount;
        
        // Transfer tokens
        address outputToken = strategy.inputTokens[0];
        IERC20(outputToken).safeTransfer(msg.sender, actualAmount);
        
        emit EmergencyWithdraw(strategyId, msg.sender, actualAmount);
    }
    
    function _executeStrategyDeposit(
        uint256 strategyId,
        uint256 amount
    ) internal {
        Strategy storage strategy = strategies[strategyId];
        
        if (strategy.strategyType == StrategyType.SINGLE_ASSET) {
            _executeSingleAssetStrategy(strategyId, amount);
        } else if (strategy.strategyType == StrategyType.DUAL_ASSET) {
            _executeDualAssetStrategy(strategyId, amount);
        } else if (strategy.strategyType == StrategyType.YIELD_FARMING) {
            _executeYieldFarmingStrategy(strategyId, amount);
        } else if (strategy.strategyType == StrategyType.LIQUIDITY_MINING) {
            _executeLiquidityMiningStrategy(strategyId, amount);
        }
        // Add more strategy types as needed
    }
    
    function _executeStrategyWithdraw(
        uint256 strategyId,
        uint256 amount
    ) internal view returns (uint256) {
        Strategy storage strategy = strategies[strategyId];
        
        if (strategy.strategyType == StrategyType.SINGLE_ASSET) {
            return _withdrawSingleAssetStrategy(strategyId, amount);
        } else if (strategy.strategyType == StrategyType.DUAL_ASSET) {
            return _withdrawDualAssetStrategy(strategyId, amount);
        } else if (strategy.strategyType == StrategyType.YIELD_FARMING) {
            return _withdrawYieldFarmingStrategy(strategyId, amount);
        } else if (strategy.strategyType == StrategyType.LIQUIDITY_MINING) {
            return _withdrawLiquidityMiningStrategy(strategyId, amount);
        }
        
        return amount; // Fallback
    }
    
    function _executeHarvest(uint256 strategyId) internal view returns (uint256) {
        Strategy storage strategy = strategies[strategyId];
        
        // Simplified harvest logic
        // In production, this would interact with specific protocols
        
        uint256 rewards = 0;
        
        // Simulate rewards based on strategy type and time elapsed
        uint256 timeElapsed = block.timestamp - strategy.lastHarvest;
        uint256 annualizedRewards = (strategy.totalDeposited * strategy.expectedAPY) / BASIS_POINTS;
        rewards = (annualizedRewards * timeElapsed) / 365 days;
        
        return rewards;
    }
    
    function _executeSingleAssetStrategy(
        uint256 strategyId,
        uint256 amount
    ) internal {
        // Implement single asset strategy logic
        // This could involve lending, staking, or other single-token strategies
    }
    
    function _executeDualAssetStrategy(
        uint256 strategyId,
        uint256 amount
    ) internal {
        // Implement dual asset strategy logic
        // This could involve LP provision, pairs trading, etc.
    }
    
    function _executeYieldFarmingStrategy(
        uint256 strategyId,
        uint256 amount
    ) internal {
        // Implement yield farming strategy logic
        // This could involve multiple protocol interactions
    }
    
    function _executeLiquidityMiningStrategy(
        uint256 strategyId,
        uint256 amount
    ) internal {
        // Implement liquidity mining strategy logic
        // This could involve AMM LP provision with reward farming
    }
    
    function _withdrawSingleAssetStrategy(
        uint256 strategyId,
        uint256 amount
    ) internal pure returns (uint256) {
        // Implement single asset withdrawal logic
        return amount;
    }
    
    function _withdrawDualAssetStrategy(
        uint256 strategyId,
        uint256 amount
    ) internal pure returns (uint256) {
        // Implement dual asset withdrawal logic
        return amount;
    }
    
    function _withdrawYieldFarmingStrategy(
        uint256 strategyId,
        uint256 amount
    ) internal pure returns (uint256) {
        // Implement yield farming withdrawal logic
        return amount;
    }
    
    function _withdrawLiquidityMiningStrategy(
        uint256 strategyId,
        uint256 amount
    ) internal pure returns (uint256) {
        // Implement liquidity mining withdrawal logic
        return amount;
    }
    
    function _executeEmergencyWithdraw(
        uint256 strategyId,
        uint256 amount
    ) internal view returns (uint256) {
        // Execute emergency withdrawal with minimal processing
        return _executeStrategyWithdraw(strategyId, amount);
    }
    
    function _executeRebalance(
        uint256 strategyId,
        RebalanceParams memory params
    ) internal {
        // Implement rebalancing logic
        // This would involve swapping tokens to achieve target allocations
    }
    
    function _checkRebalanceNeeded(
        uint256 strategyId,
        uint256[] memory targetAllocations
    ) internal view returns (bool) {
        // Check if current allocations deviate from target by threshold
        StrategyConfig storage config = strategyConfigs[strategyId];
        
        // Simplified check - in production would compare actual vs target allocations
        return true; // Placeholder
    }
    
    function _updatePerformanceMetrics(
        uint256 strategyId,
        uint256 rewards
    ) internal {
        PerformanceMetrics storage metrics = performanceMetrics[strategyId];
        Strategy storage strategy = strategies[strategyId];
        
        // Update total return
        metrics.totalReturn += rewards;
        
        // Calculate annualized return
        uint256 timeElapsed = block.timestamp - metrics.lastUpdate;
        if (timeElapsed > 0 && strategy.totalDeposited > 0) {
            uint256 periodReturn = (rewards * BASIS_POINTS) / strategy.totalDeposited;
            metrics.annualizedReturn = (periodReturn * 365 days) / timeElapsed;
        }
        
        // Update other metrics (simplified)
        metrics.totalTrades++;
        if (rewards > 0) {
            metrics.profitableTrades++;
        }
        metrics.winRate = (metrics.profitableTrades * BASIS_POINTS) / metrics.totalTrades;
        
        metrics.lastUpdate = block.timestamp;
        
        // Update strategy actual APY
        strategy.actualAPY = metrics.annualizedReturn;
        
        emit PerformanceUpdated(
            strategyId,
            metrics.totalReturn,
            metrics.annualizedReturn,
            metrics.sharpeRatio
        );
    }
    
    // View functions
    function getStrategy(uint256 strategyId) external view returns (
        string memory name,
        StrategyType strategyType,
        StrategyStatus status,
        uint256 totalDeposited,
        uint256 totalShares,
        uint256 expectedAPY,
        uint256 actualAPY,
        uint256 riskLevel
    ) {
        require(strategyId < strategiesCount, "Strategy not found");
        Strategy storage strategy = strategies[strategyId];
        
        return (
            strategy.name,
            strategy.strategyType,
            strategy.status,
            strategy.totalDeposited,
            strategy.totalShares,
            strategy.expectedAPY,
            strategy.actualAPY,
            strategy.riskLevel
        );
    }
    
    function getUserPosition(address user, uint256 strategyId) external view returns (
        uint256 shares,
        uint256 deposited,
        uint256 currentValue,
        uint256 rewards,
        uint256 lastDeposit
    ) {
        require(strategyId < strategiesCount, "Strategy not found");
        Strategy storage strategy = strategies[strategyId];
        
        shares = strategy.userShares[user];
        deposited = strategy.userDeposits[user];
        
        if (strategy.totalShares > 0) {
            currentValue = (shares * strategy.totalDeposited) / strategy.totalShares;
        }
        
        rewards = strategy.userRewards[user];
        lastDeposit = strategy.userLastDeposit[user];
    }
    
    function getUserStrategies(address user) external view returns (uint256[] memory) {
        return userStrategies[user];
    }
    
    function getStrategyConfig(uint256 strategyId) external view returns (StrategyConfig memory) {
        return strategyConfigs[strategyId];
    }
    
    function getPerformanceMetrics(uint256 strategyId) external view returns (PerformanceMetrics memory) {
        return performanceMetrics[strategyId];
    }
    
    function getHarvestHistory(uint256 strategyId, uint256 limit) external view returns (HarvestInfo[] memory) {
        uint256 count = harvestCounts[strategyId];
        if (limit == 0 || limit > count) {
            limit = count;
        }
        
        HarvestInfo[] memory history = new HarvestInfo[](limit);
        
        for (uint256 i = 0; i < limit; i++) {
            uint256 index = count > limit ? count - limit + i : i;
            history[i] = harvestHistory[strategyId][index];
        }
        
        return history;
    }
    
    // Admin functions
    function updateStrategyConfig(
        uint256 strategyId,
        StrategyConfig memory config
    ) external onlyRole(STRATEGY_MANAGER_ROLE) {
        require(strategyId < strategiesCount, "Strategy not found");
        require(config.slippageTolerance <= 1000, "Slippage too high"); // Max 10%
        require(config.withdrawalFee <= 1000, "Withdrawal fee too high"); // Max 10%
        require(config.depositFee <= 500, "Deposit fee too high"); // Max 5%
        
        strategyConfigs[strategyId] = config;
    }
    
    function pauseStrategy(uint256 strategyId) external onlyRole(STRATEGY_MANAGER_ROLE) {
        require(strategyId < strategiesCount, "Strategy not found");
        strategies[strategyId].status = StrategyStatus.PAUSED;
        strategies[strategyId].isActive = false;
    }
    
    function unpauseStrategy(uint256 strategyId) external onlyRole(STRATEGY_MANAGER_ROLE) {
        require(strategyId < strategiesCount, "Strategy not found");
        strategies[strategyId].status = StrategyStatus.ACTIVE;
        strategies[strategyId].isActive = true;
    }
    
    function setEmergencyMode(uint256 strategyId) external onlyRole(EMERGENCY_ROLE) {
        require(strategyId < strategiesCount, "Strategy not found");
        strategies[strategyId].status = StrategyStatus.EMERGENCY;
        strategies[strategyId].isActive = false;
    }
    
    function setFeeRecipient(address _feeRecipient) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_feeRecipient != address(0), "Invalid fee recipient");
        feeRecipient = _feeRecipient;
    }
    
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }
    
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
}
