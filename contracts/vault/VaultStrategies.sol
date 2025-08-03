// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title VaultStrategies
 * @dev Advanced yield farming and strategy management system
 */
contract VaultStrategies is AccessControl, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;
    using Math for uint256;

    bytes32 public constant STRATEGY_MANAGER_ROLE = keccak256("STRATEGY_MANAGER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant HARVESTER_ROLE = keccak256("HARVESTER_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");

    // Constants
    uint256 public constant PRECISION = 1e18;
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant MAX_PERFORMANCE_FEE = 2000; // 20%
    uint256 public constant MAX_MANAGEMENT_FEE = 200; // 2%
    uint256 public constant MIN_HARVEST_INTERVAL = 1 hours;
    uint256 public constant MAX_HARVEST_INTERVAL = 7 days;
    uint256 public constant APY_CALCULATION_PERIOD = 30 days;
    uint256 public constant MAX_SLIPPAGE = 500; // 5%

    // Enums
    enum StrategyType {
        LENDING,
        LIQUIDITY_MINING,
        YIELD_FARMING,
        ARBITRAGE,
        DELTA_NEUTRAL,
        LEVERAGED_FARMING
    }

    enum StrategyStatus {
        ACTIVE,
        PAUSED,
        DEPRECATED,
        EMERGENCY_EXIT
    }

    // Structs
    struct Strategy {
        address strategyAddress;
        address asset;
        StrategyType strategyType;
        StrategyStatus status;
        uint256 totalDeployed;
        uint256 totalHarvested;
        uint256 lastHarvest;
        uint256 performanceFee; // Basis points
        uint256 managementFee; // Basis points
        uint256 maxCapacity;
        uint256 minDeployment;
        uint256 harvestInterval;
        uint256 riskScore; // 0-100
        bool autoCompound;
        string name;
        string description;
    }

    struct StrategyMetrics {
        uint256 totalReturn;
        uint256 annualizedReturn;
        uint256 sharpeRatio;
        uint256 maxDrawdown;
        uint256 volatility;
        uint256 winRate;
        uint256 averageHoldTime;
        uint256 lastUpdated;
    }

    struct HarvestInfo {
        uint256 timestamp;
        uint256 amountHarvested;
        uint256 gasUsed;
        uint256 profitGenerated;
        address harvester;
    }

    struct AllocationTarget {
        address strategy;
        uint256 targetPercentage; // Basis points
        uint256 currentPercentage;
        uint256 lastRebalance;
    }

    struct YieldData {
        uint256 totalYield;
        uint256 yieldPerShare;
        uint256 lastYieldCalculation;
        uint256 cumulativeYield;
        uint256[] dailyYields;
        uint256 yieldIndex;
    }

    struct RiskMetrics {
        uint256 valueAtRisk; // VaR at 95% confidence
        uint256 expectedShortfall; // Expected loss beyond VaR
        uint256 beta; // Market correlation
        uint256 alpha; // Excess return
        uint256 informationRatio;
        uint256 lastCalculated;
    }

    // Storage
    mapping(address => Strategy) public strategies;
    mapping(address => StrategyMetrics) public strategyMetrics;
    mapping(address => YieldData) public yieldData;
    mapping(address => RiskMetrics) public riskMetrics;
    mapping(address => HarvestInfo[]) public harvestHistory;
    mapping(address => AllocationTarget[]) public allocationTargets;
    mapping(address => mapping(address => uint256)) public userAllocations;
    mapping(address => bool) public authorizedStrategies;
    mapping(address => uint256) public strategyWeights;
    
    address[] public allStrategies;
    address public treasury;
    address public performanceFeeRecipient;
    address public emergencyRecipient;
    
    uint256 public totalValueLocked;
    uint256 public globalPerformanceFee;
    uint256 public globalManagementFee;
    uint256 public rebalanceThreshold;
    uint256 public emergencyExitThreshold;
    bool public autoRebalanceEnabled;
    uint256 public lastGlobalRebalance;
    
    // Events
    event StrategyAdded(address indexed strategy, StrategyType strategyType, string name);
    event StrategyRemoved(address indexed strategy);
    event StrategyDeployed(address indexed strategy, uint256 amount, address indexed user);
    event StrategyWithdrawn(address indexed strategy, uint256 amount, address indexed user);
    event YieldHarvested(address indexed strategy, uint256 amount, address indexed harvester);
    event StrategyRebalanced(address indexed strategy, uint256 oldAllocation, uint256 newAllocation);
    event PerformanceFeeCollected(address indexed strategy, uint256 amount);
    event EmergencyExit(address indexed strategy, uint256 amount);
    event APYCalculated(address indexed strategy, uint256 apy, uint256 timestamp);
    event RiskMetricsUpdated(address indexed strategy, uint256 riskScore, uint256 valueAtRisk);

    constructor(address _treasury, address _performanceFeeRecipient) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(STRATEGY_MANAGER_ROLE, msg.sender);
        _grantRole(HARVESTER_ROLE, msg.sender);
        _grantRole(EMERGENCY_ROLE, msg.sender);
        
        treasury = _treasury;
        performanceFeeRecipient = _performanceFeeRecipient;
        globalPerformanceFee = 1000; // 10%
        globalManagementFee = 100; // 1%
        rebalanceThreshold = 500; // 5%
        emergencyExitThreshold = 2000; // 20% loss
        autoRebalanceEnabled = true;
    }

    /**
     * @dev Deploy funds to a strategy
     */
    function deployToStrategy(address strategy, uint256 amount) external nonReentrant whenNotPaused {
        require(authorizedStrategies[strategy], "Strategy not authorized");
        require(amount > 0, "Amount must be greater than 0");
        
        Strategy storage strategyInfo = strategies[strategy];
        require(strategyInfo.status == StrategyStatus.ACTIVE, "Strategy not active");
        require(strategyInfo.totalDeployed + amount <= strategyInfo.maxCapacity, "Exceeds strategy capacity");
        require(amount >= strategyInfo.minDeployment, "Below minimum deployment");
        
        // Transfer tokens from user
        IERC20(strategyInfo.asset).safeTransferFrom(msg.sender, address(this), amount);
        
        // Deploy to strategy
        IERC20(strategyInfo.asset).safeTransfer(strategy, amount);
        
        // Update strategy state
        strategyInfo.totalDeployed += amount;
        userAllocations[msg.sender][strategy] += amount;
        totalValueLocked += amount;
        
        // Update yield tracking
        _updateYieldData(strategy, amount, true);
        
        emit StrategyDeployed(strategy, amount, msg.sender);
    }

    /**
     * @dev Harvest yield from a strategy
     */
    function harvestYield(address strategy) external nonReentrant onlyRole(HARVESTER_ROLE) {
        require(authorizedStrategies[strategy], "Strategy not authorized");
        
        Strategy storage strategyInfo = strategies[strategy];
        require(strategyInfo.status == StrategyStatus.ACTIVE, "Strategy not active");
        require(block.timestamp >= strategyInfo.lastHarvest + strategyInfo.harvestInterval, "Too early to harvest");
        
        uint256 gasStart = gasleft();
        
        // Call harvest function on strategy contract
        uint256 harvestedAmount = _executeHarvest(strategy);
        
        if (harvestedAmount > 0) {
            // Calculate fees
            uint256 performanceFee = (harvestedAmount * strategyInfo.performanceFee) / BASIS_POINTS;
            uint256 managementFee = (strategyInfo.totalDeployed * strategyInfo.managementFee * 
                                   (block.timestamp - strategyInfo.lastHarvest)) / (BASIS_POINTS * 365 days);
            
            uint256 totalFees = performanceFee + managementFee;
            uint256 netHarvest = harvestedAmount - totalFees;
            
            // Transfer fees
            if (totalFees > 0) {
                IERC20(strategyInfo.asset).safeTransfer(performanceFeeRecipient, totalFees);
                emit PerformanceFeeCollected(strategy, totalFees);
            }
            
            // Update strategy state
            strategyInfo.totalHarvested += netHarvest;
            strategyInfo.lastHarvest = block.timestamp;
            
            // Auto-compound if enabled
            if (strategyInfo.autoCompound && netHarvest > 0) {
                _autoCompound(strategy, netHarvest);
            }
            
            // Record harvest info
            uint256 gasUsed = gasStart - gasleft();
            harvestHistory[strategy].push(HarvestInfo({
                timestamp: block.timestamp,
                amountHarvested: harvestedAmount,
                gasUsed: gasUsed,
                profitGenerated: netHarvest,
                harvester: msg.sender
            }));
            
            // Update yield data
            _updateYieldData(strategy, netHarvest, true);
            
            emit YieldHarvested(strategy, harvestedAmount, msg.sender);
        }
    }

    /**
     * @dev Calculate strategy APY
     */
    function calculateStrategyAPY(address strategy) public view returns (uint256) {
        require(authorizedStrategies[strategy], "Strategy not authorized");
        
        Strategy memory strategyInfo = strategies[strategy];
        YieldData memory yieldInfo = yieldData[strategy];
        
        if (strategyInfo.totalDeployed == 0 || yieldInfo.totalYield == 0) {
            return 0;
        }
        
        // Calculate time-weighted return
        uint256 timeElapsed = block.timestamp - yieldInfo.lastYieldCalculation;
        if (timeElapsed == 0) return 0;
        
        // Annualized return calculation
        uint256 totalReturn = (yieldInfo.totalYield * PRECISION) / strategyInfo.totalDeployed;
        uint256 annualizedReturn = (totalReturn * 365 days) / timeElapsed;
        
        return annualizedReturn;
    }

    /**
     * @dev Get strategy performance metrics
     */
    function getStrategyMetrics(address strategy) external view returns (StrategyMetrics memory) {
        return strategyMetrics[strategy];
    }

    /**
     * @dev Get strategy risk metrics
     */
    function getRiskMetrics(address strategy) external view returns (RiskMetrics memory) {
        return riskMetrics[strategy];
    }

    /**
     * @dev Get harvest history for a strategy
     */
    function getHarvestHistory(address strategy, uint256 count) external view returns (HarvestInfo[] memory) {
        HarvestInfo[] storage history = harvestHistory[strategy];
        uint256 length = history.length;
        
        if (count > length) count = length;
        
        HarvestInfo[] memory result = new HarvestInfo[](count);
        for (uint256 i = 0; i < count; i++) {
            result[i] = history[length - 1 - i];
        }
        
        return result;
    }

    /**
     * @dev Add new strategy
     */
    function addStrategy(
        address strategyAddress,
        address asset,
        StrategyType strategyType,
        uint256 maxCapacity,
        uint256 minDeployment,
        uint256 harvestInterval,
        string memory name,
        string memory description
    ) external onlyRole(STRATEGY_MANAGER_ROLE) {
        require(strategyAddress != address(0), "Invalid strategy address");
        require(!authorizedStrategies[strategyAddress], "Strategy already exists");
        require(harvestInterval >= MIN_HARVEST_INTERVAL && harvestInterval <= MAX_HARVEST_INTERVAL, "Invalid harvest interval");
        
        strategies[strategyAddress] = Strategy({
            strategyAddress: strategyAddress,
            asset: asset,
            strategyType: strategyType,
            status: StrategyStatus.ACTIVE,
            totalDeployed: 0,
            totalHarvested: 0,
            lastHarvest: block.timestamp,
            performanceFee: globalPerformanceFee,
            managementFee: globalManagementFee,
            maxCapacity: maxCapacity,
            minDeployment: minDeployment,
            harvestInterval: harvestInterval,
            riskScore: 50, // Default medium risk
            autoCompound: true,
            name: name,
            description: description
        });
        
        authorizedStrategies[strategyAddress] = true;
        allStrategies.push(strategyAddress);
        
        // Initialize yield data
        yieldData[strategyAddress].dailyYields = new uint256[](30); // 30 days history
        
        emit StrategyAdded(strategyAddress, strategyType, name);
    }

    /**
     * @dev Remove strategy
     */
    function removeStrategy(address strategy) external onlyRole(STRATEGY_MANAGER_ROLE) {
        require(authorizedStrategies[strategy], "Strategy not found");
        require(strategies[strategy].totalDeployed == 0, "Strategy has active deployments");
        
        authorizedStrategies[strategy] = false;
        strategies[strategy].status = StrategyStatus.DEPRECATED;
        
        // Remove from allStrategies array
        for (uint256 i = 0; i < allStrategies.length; i++) {
            if (allStrategies[i] == strategy) {
                allStrategies[i] = allStrategies[allStrategies.length - 1];
                allStrategies.pop();
                break;
            }
        }
        
        emit StrategyRemoved(strategy);
    }

    /**
     * @dev Update strategy parameters
     */
    function updateStrategyParams(
        address strategy,
        uint256 performanceFee,
        uint256 managementFee,
        uint256 maxCapacity,
        uint256 harvestInterval
    ) external onlyRole(STRATEGY_MANAGER_ROLE) {
        require(authorizedStrategies[strategy], "Strategy not found");
        require(performanceFee <= MAX_PERFORMANCE_FEE, "Performance fee too high");
        require(managementFee <= MAX_MANAGEMENT_FEE, "Management fee too high");
        require(harvestInterval >= MIN_HARVEST_INTERVAL && harvestInterval <= MAX_HARVEST_INTERVAL, "Invalid harvest interval");
        
        Strategy storage strategyInfo = strategies[strategy];
        strategyInfo.performanceFee = performanceFee;
        strategyInfo.managementFee = managementFee;
        strategyInfo.maxCapacity = maxCapacity;
        strategyInfo.harvestInterval = harvestInterval;
    }

    /**
     * @dev Emergency exit from strategy
     */
    function emergencyExit(address strategy) external onlyRole(EMERGENCY_ROLE) {
        require(authorizedStrategies[strategy], "Strategy not found");
        
        Strategy storage strategyInfo = strategies[strategy];
        strategyInfo.status = StrategyStatus.EMERGENCY_EXIT;
        
        // Withdraw all funds from strategy
        uint256 withdrawnAmount = _emergencyWithdraw(strategy);
        
        // Transfer to emergency recipient
        if (withdrawnAmount > 0) {
            IERC20(strategyInfo.asset).safeTransfer(emergencyRecipient, withdrawnAmount);
        }
        
        emit EmergencyExit(strategy, withdrawnAmount);
    }

    /**
     * @dev Rebalance strategy allocations
     */
    function rebalanceStrategies() external onlyRole(STRATEGY_MANAGER_ROLE) {
        require(autoRebalanceEnabled, "Auto rebalance disabled");
        
        for (uint256 i = 0; i < allStrategies.length; i++) {
            address strategy = allStrategies[i];
            _rebalanceStrategy(strategy);
        }
        
        lastGlobalRebalance = block.timestamp;
    }

    /**
     * @dev Update risk metrics for a strategy
     */
    function updateRiskMetrics(address strategy) external onlyRole(STRATEGY_MANAGER_ROLE) {
        require(authorizedStrategies[strategy], "Strategy not found");
        
        RiskMetrics storage metrics = riskMetrics[strategy];
        
        // Calculate VaR and other risk metrics
        (uint256 var95, uint256 expectedShortfall, uint256 beta, uint256 alpha) = _calculateRiskMetrics(strategy);
        
        metrics.valueAtRisk = var95;
        metrics.expectedShortfall = expectedShortfall;
        metrics.beta = beta;
        metrics.alpha = alpha;
        metrics.lastCalculated = block.timestamp;
        
        // Update strategy risk score
        strategies[strategy].riskScore = _calculateRiskScore(strategy);
        
        emit RiskMetricsUpdated(strategy, strategies[strategy].riskScore, var95);
    }

    // Internal functions
    function _executeHarvest(address strategy) internal returns (uint256) {
        // This would call the actual strategy contract's harvest function
        // For now, return a simulated harvest amount
        return 0;
    }

    function _autoCompound(address strategy, uint256 amount) internal {
        // Re-invest harvested yield back into the strategy
        strategies[strategy].totalDeployed += amount;
    }

    function _updateYieldData(address strategy, uint256 amount, bool isPositive) internal {
        YieldData storage data = yieldData[strategy];
        
        if (isPositive) {
            data.totalYield += amount;
            data.cumulativeYield += amount;
        } else {
            if (data.totalYield >= amount) {
                data.totalYield -= amount;
            }
        }
        
        // Update daily yields array
        uint256 dayIndex = (block.timestamp / 1 days) % 30;
        if (dayIndex != data.yieldIndex) {
            data.dailyYields[dayIndex] = 0;
            data.yieldIndex = dayIndex;
        }
        
        if (isPositive) {
            data.dailyYields[dayIndex] += amount;
        }
        
        data.lastYieldCalculation = block.timestamp;
    }

    function _emergencyWithdraw(address strategy) internal returns (uint256) {
        // This would call the strategy's emergency withdraw function
        return strategies[strategy].totalDeployed;
    }

    function _rebalanceStrategy(address strategy) internal {
        // Implement rebalancing logic based on allocation targets
        AllocationTarget[] storage targets = allocationTargets[strategy];
        
        for (uint256 i = 0; i < targets.length; i++) {
            AllocationTarget storage target = targets[i];
            
            uint256 deviation = target.currentPercentage > target.targetPercentage ?
                target.currentPercentage - target.targetPercentage :
                target.targetPercentage - target.currentPercentage;
            
            if (deviation > rebalanceThreshold) {
                // Perform rebalancing
                target.lastRebalance = block.timestamp;
                emit StrategyRebalanced(strategy, target.currentPercentage, target.targetPercentage);
            }
        }
    }

    function _calculateRiskMetrics(address strategy) internal view returns (uint256, uint256, uint256, uint256) {
        // Implement risk metrics calculation
        // This is a simplified version - real implementation would be more complex
        return (0, 0, PRECISION, 0);
    }

    function _calculateRiskScore(address strategy) internal view returns (uint256) {
        // Calculate risk score based on various factors
        StrategyMetrics memory metrics = strategyMetrics[strategy];
        
        uint256 volatilityScore = metrics.volatility > 50 * PRECISION / 100 ? 80 : 20;
        uint256 drawdownScore = metrics.maxDrawdown > 20 * PRECISION / 100 ? 60 : 10;
        uint256 returnScore = metrics.annualizedReturn > 10 * PRECISION / 100 ? 10 : 30;
        
        return (volatilityScore + drawdownScore + returnScore) / 3;
    }

    // Admin functions
    function setTreasury(address _treasury) external onlyRole(ADMIN_ROLE) {
        treasury = _treasury;
    }

    function setPerformanceFeeRecipient(address _recipient) external onlyRole(ADMIN_ROLE) {
        performanceFeeRecipient = _recipient;
    }

    function setEmergencyRecipient(address _recipient) external onlyRole(ADMIN_ROLE) {
        emergencyRecipient = _recipient;
    }

    function setGlobalFees(uint256 _performanceFee, uint256 _managementFee) external onlyRole(ADMIN_ROLE) {
        require(_performanceFee <= MAX_PERFORMANCE_FEE, "Performance fee too high");
        require(_managementFee <= MAX_MANAGEMENT_FEE, "Management fee too high");
        
        globalPerformanceFee = _performanceFee;
        globalManagementFee = _managementFee;
    }

    function setRebalanceThreshold(uint256 _threshold) external onlyRole(ADMIN_ROLE) {
        rebalanceThreshold = _threshold;
    }

    function toggleAutoRebalance() external onlyRole(ADMIN_ROLE) {
        autoRebalanceEnabled = !autoRebalanceEnabled;
    }

    function pause() external onlyRole(EMERGENCY_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    // View functions
    function getAllStrategies() external view returns (address[] memory) {
        return allStrategies;
    }

    function getStrategy(address strategy) external view returns (Strategy memory) {
        return strategies[strategy];
    }

    function getUserAllocation(address user, address strategy) external view returns (uint256) {
        return userAllocations[user][strategy];
    }

    function getTotalValueLocked() external view returns (uint256) {
        return totalValueLocked;
    }

    function getYieldData(address strategy) external view returns (YieldData memory) {
        return yieldData[strategy];
    }
}
