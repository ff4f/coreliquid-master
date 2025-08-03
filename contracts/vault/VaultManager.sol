// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./VaultStrategyBase.sol";

/**
 * @title VaultManager
 * @dev Manages multiple vault strategies and allocates funds optimally
 */
contract VaultManager is AccessControl, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;
    using Math for uint256;
    
    bytes32 public constant VAULT_MANAGER_ROLE = keccak256("VAULT_MANAGER_ROLE");
    bytes32 public constant STRATEGY_MANAGER_ROLE = keccak256("STRATEGY_MANAGER_ROLE");
    bytes32 public constant KEEPER_ROLE = keccak256("KEEPER_ROLE");
    bytes32 public constant ALLOCATOR_ROLE = keccak256("ALLOCATOR_ROLE");
    
    struct StrategyInfo {
        address strategy;
        uint256 allocation; // Allocation percentage in basis points
        uint256 maxAllocation; // Maximum allocation percentage
        uint256 minAllocation; // Minimum allocation percentage
        uint256 totalDeposited;
        uint256 totalWithdrawn;
        uint256 lastRebalance;
        bool isActive;
        bool isEmergencyExit;
        string name;
        string description;
    }
    
    struct VaultConfig {
        address asset; // Primary asset managed by vault
        uint256 managementFee; // Management fee in basis points
        uint256 performanceFee; // Performance fee in basis points
        uint256 maxTotalSupply; // Maximum total supply
        uint256 minDeposit; // Minimum deposit amount
        uint256 maxDeposit; // Maximum deposit per user
        uint256 withdrawalDelay; // Withdrawal delay in seconds
        uint256 rebalanceThreshold; // Threshold for automatic rebalancing
        bool autoRebalance; // Enable automatic rebalancing
        bool emergencyShutdown; // Emergency shutdown flag
    }
    
    struct AllocationTarget {
        address strategy;
        uint256 targetAllocation; // Target allocation in basis points
        uint256 priority; // Priority for allocation (higher = more priority)
    }
    
    struct RebalanceData {
        uint256 timestamp;
        uint256 totalAssets;
        uint256 gasUsed;
        uint256 strategiesRebalanced;
        bool successful;
    }
    
    VaultConfig public config;
    
    mapping(address => StrategyInfo) public strategies;
    mapping(uint256 => address) public strategyList;
    mapping(address => uint256) public strategyIndex;
    mapping(address => uint256) public userWithdrawalRequests;
    mapping(address => uint256) public userLastDeposit;
    mapping(uint256 => RebalanceData) public rebalanceHistory;
    
    uint256 public strategiesCount;
    uint256 public totalAssets;
    uint256 public lastRebalance;
    uint256 public rebalanceHistoryLength;
    uint256 public totalShares;
    
    address public treasury;
    address public guardian;
    
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant MAX_STRATEGIES = 20;
    uint256 public constant MAX_MANAGEMENT_FEE = 200; // 2%
    uint256 public constant MAX_PERFORMANCE_FEE = 2000; // 20%
    uint256 public constant REBALANCE_HISTORY_LIMIT = 100;
    
    event StrategyAdded(
        address indexed strategy,
        string name,
        uint256 allocation
    );
    
    event StrategyRemoved(
        address indexed strategy,
        uint256 timestamp
    );
    
    event StrategyUpdated(
        address indexed strategy,
        uint256 newAllocation,
        bool isActive
    );
    
    event FundsAllocated(
        address indexed strategy,
        uint256 amount,
        uint256 newAllocation
    );
    
    event FundsDeallocated(
        address indexed strategy,
        uint256 amount,
        uint256 newAllocation
    );
    
    event Rebalanced(
        uint256 timestamp,
        uint256 totalAssets,
        uint256 strategiesRebalanced,
        uint256 gasUsed
    );
    
    event EmergencyShutdown(
        uint256 timestamp,
        address triggeredBy
    );
    
    event WithdrawalRequested(
        address indexed user,
        uint256 amount,
        uint256 availableAt
    );
    
    event ConfigUpdated(
        uint256 managementFee,
        uint256 performanceFee,
        bool autoRebalance
    );
    
    modifier onlyGuardian() {
        require(msg.sender == guardian, "Only guardian can call");
        _;
    }
    
    modifier whenNotShutdown() {
        require(!config.emergencyShutdown, "Vault is shutdown");
        _;
    }
    
    modifier validStrategy(address strategy) {
        require(strategy != address(0), "Invalid strategy address");
        require(strategies[strategy].strategy != address(0), "Strategy not found");
        _;
    }
    
    constructor(
        VaultConfig memory _config,
        address _treasury,
        address _guardian
    ) {
        require(_config.asset != address(0), "Invalid asset");
        require(_treasury != address(0), "Invalid treasury");
        require(_guardian != address(0), "Invalid guardian");
        require(_config.managementFee <= MAX_MANAGEMENT_FEE, "Management fee too high");
        require(_config.performanceFee <= MAX_PERFORMANCE_FEE, "Performance fee too high");
        
        config = _config;
        treasury = _treasury;
        guardian = _guardian;
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(VAULT_MANAGER_ROLE, msg.sender);
        _grantRole(STRATEGY_MANAGER_ROLE, msg.sender);
        _grantRole(KEEPER_ROLE, msg.sender);
        _grantRole(ALLOCATOR_ROLE, msg.sender);
        
        lastRebalance = block.timestamp;
    }
    
    function addStrategy(
        address strategy,
        string memory name,
        string memory description,
        uint256 allocation,
        uint256 maxAllocation,
        uint256 minAllocation
    ) external onlyRole(STRATEGY_MANAGER_ROLE) whenNotShutdown {
        require(strategy != address(0), "Invalid strategy");
        require(strategies[strategy].strategy == address(0), "Strategy already exists");
        require(strategiesCount < MAX_STRATEGIES, "Too many strategies");
        require(allocation <= maxAllocation, "Allocation exceeds maximum");
        require(minAllocation <= maxAllocation, "Invalid allocation range");
        require(maxAllocation <= BASIS_POINTS, "Max allocation too high");
        
        // Verify total allocation doesn't exceed 100%
        uint256 totalAllocation = _getTotalAllocation() + allocation;
        require(totalAllocation <= BASIS_POINTS, "Total allocation exceeds 100%");
        
        strategies[strategy] = StrategyInfo({
            strategy: strategy,
            allocation: allocation,
            maxAllocation: maxAllocation,
            minAllocation: minAllocation,
            totalDeposited: 0,
            totalWithdrawn: 0,
            lastRebalance: block.timestamp,
            isActive: true,
            isEmergencyExit: false,
            name: name,
            description: description
        });
        
        strategyList[strategiesCount] = strategy;
        strategyIndex[strategy] = strategiesCount;
        strategiesCount++;
        
        emit StrategyAdded(strategy, name, allocation);
    }
    
    function removeStrategy(address strategy) external onlyRole(STRATEGY_MANAGER_ROLE) validStrategy(strategy) {
        // First withdraw all funds from strategy
        _withdrawFromStrategy(strategy, type(uint256).max);
        
        // Remove from mapping
        uint256 index = strategyIndex[strategy];
        
        // Move last strategy to removed position
        if (index < strategiesCount - 1) {
            address lastStrategy = strategyList[strategiesCount - 1];
            strategyList[index] = lastStrategy;
            strategyIndex[lastStrategy] = index;
        }
        
        // Clean up
        delete strategies[strategy];
        delete strategyIndex[strategy];
        delete strategyList[strategiesCount - 1];
        strategiesCount--;
        
        emit StrategyRemoved(strategy, block.timestamp);
    }
    
    function updateStrategyAllocation(
        address strategy,
        uint256 newAllocation
    ) external onlyRole(ALLOCATOR_ROLE) validStrategy(strategy) whenNotShutdown {
        StrategyInfo storage strategyInfo = strategies[strategy];
        require(newAllocation <= strategyInfo.maxAllocation, "Allocation exceeds maximum");
        require(newAllocation >= strategyInfo.minAllocation, "Allocation below minimum");
        
        // Check total allocation
        uint256 totalAllocation = _getTotalAllocation() - strategyInfo.allocation + newAllocation;
        require(totalAllocation <= BASIS_POINTS, "Total allocation exceeds 100%");
        
        uint256 oldAllocation = strategyInfo.allocation;
        strategyInfo.allocation = newAllocation;
        
        emit StrategyUpdated(strategy, newAllocation, strategyInfo.isActive);
        
        // Trigger rebalance if auto-rebalance is enabled
        if (config.autoRebalance) {
            _rebalanceStrategy(strategy, oldAllocation, newAllocation);
        }
    }
    
    function setStrategyActive(
        address strategy,
        bool active
    ) external onlyRole(STRATEGY_MANAGER_ROLE) validStrategy(strategy) {
        strategies[strategy].isActive = active;
        
        if (!active) {
            // Withdraw funds from inactive strategy
            _withdrawFromStrategy(strategy, type(uint256).max);
        }
        
        emit StrategyUpdated(strategy, strategies[strategy].allocation, active);
    }
    
    function deposit(uint256 amount) external nonReentrant whenNotPaused whenNotShutdown {
        require(amount > 0, "Invalid amount");
        require(amount >= config.minDeposit, "Below minimum deposit");
        require(amount <= config.maxDeposit, "Above maximum deposit");
        
        // Check total supply limit
        require(totalAssets + amount <= config.maxTotalSupply, "Exceeds max total supply");
        
        // Transfer tokens from user
        IERC20(config.asset).safeTransferFrom(msg.sender, address(this), amount);
        
        // Update user data
        userLastDeposit[msg.sender] = block.timestamp;
        
        // Update total assets
        totalAssets += amount;
        
        // Allocate funds to strategies
        _allocateFunds(amount);
    }
    
    function requestWithdrawal(uint256 amount) external nonReentrant whenNotPaused {
        require(amount > 0, "Invalid amount");
        
        // Check if user has sufficient balance (simplified - in production check shares)
        require(amount <= _getUserBalance(msg.sender), "Insufficient balance");
        
        // Set withdrawal request with delay
        userWithdrawalRequests[msg.sender] = amount;
        uint256 availableAt = block.timestamp + config.withdrawalDelay;
        
        emit WithdrawalRequested(msg.sender, amount, availableAt);
    }
    
    function executeWithdrawal() external nonReentrant whenNotPaused {
        uint256 amount = userWithdrawalRequests[msg.sender];
        require(amount > 0, "No withdrawal request");
        
        // Check withdrawal delay
        require(
            block.timestamp >= userLastDeposit[msg.sender] + config.withdrawalDelay,
            "Withdrawal delay not met"
        );
        
        // Clear withdrawal request
        userWithdrawalRequests[msg.sender] = 0;
        
        // Withdraw funds from strategies if needed
        uint256 availableBalance = IERC20(config.asset).balanceOf(address(this));
        if (availableBalance < amount) {
            _withdrawFromStrategies(amount - availableBalance);
        }
        
        // Update total assets
        totalAssets = totalAssets > amount ? totalAssets - amount : 0;
        
        // Transfer tokens to user
        IERC20(config.asset).safeTransfer(msg.sender, amount);
    }
    
    function rebalance() external onlyRole(KEEPER_ROLE) nonReentrant whenNotPaused whenNotShutdown {
        uint256 gasStart = gasleft();
        uint256 strategiesRebalanced = 0;
        
        // Get current total assets
        uint256 currentTotalAssets = _calculateTotalAssets();
        
        // Rebalance each active strategy
        for (uint256 i = 0; i < strategiesCount; i++) {
            address strategy = strategyList[i];
            StrategyInfo storage strategyInfo = strategies[strategy];
            
            if (!strategyInfo.isActive || strategyInfo.isEmergencyExit) {
                continue;
            }
            
            uint256 targetAmount = (currentTotalAssets * strategyInfo.allocation) / BASIS_POINTS;
            uint256 currentAmount = VaultStrategyBase(strategy).balanceOf();
            
            if (_shouldRebalance(currentAmount, targetAmount)) {
                if (currentAmount > targetAmount) {
                    // Withdraw excess
                    _withdrawFromStrategy(strategy, currentAmount - targetAmount);
                } else {
                    // Deposit more
                    uint256 availableBalance = IERC20(config.asset).balanceOf(address(this));
                    uint256 depositAmount = Math.min(targetAmount - currentAmount, availableBalance);
                    if (depositAmount > 0) {
                        _depositToStrategy(strategy, depositAmount);
                    }
                }
                
                strategyInfo.lastRebalance = block.timestamp;
                strategiesRebalanced++;
            }
        }
        
        // Update rebalance data
        uint256 gasUsed = gasStart - gasleft();
        lastRebalance = block.timestamp;
        
        // Store rebalance history
        rebalanceHistory[rebalanceHistoryLength] = RebalanceData({
            timestamp: block.timestamp,
            totalAssets: currentTotalAssets,
            gasUsed: gasUsed,
            strategiesRebalanced: strategiesRebalanced,
            successful: true
        });
        
        rebalanceHistoryLength++;
        
        // Limit history size
        if (rebalanceHistoryLength > REBALANCE_HISTORY_LIMIT) {
            // Shift array (simplified)
            for (uint256 i = 0; i < REBALANCE_HISTORY_LIMIT - 1; i++) {
                rebalanceHistory[i] = rebalanceHistory[i + 1];
            }
            rebalanceHistoryLength = REBALANCE_HISTORY_LIMIT;
        }
        
        emit Rebalanced(block.timestamp, currentTotalAssets, strategiesRebalanced, gasUsed);
    }
    
    function emergencyShutdown() external onlyGuardian {
        config.emergencyShutdown = true;
        
        // Withdraw all funds from strategies
        for (uint256 i = 0; i < strategiesCount; i++) {
            address strategy = strategyList[i];
            if (strategies[strategy].isActive) {
                try VaultStrategyBase(strategy).emergencyWithdraw() {
                    strategies[strategy].isEmergencyExit = true;
                } catch {
                    // Continue with other strategies if one fails
                }
            }
        }
        
        emit EmergencyShutdown(block.timestamp, msg.sender);
    }
    
    function harvest() external onlyRole(KEEPER_ROLE) nonReentrant whenNotPaused {
        for (uint256 i = 0; i < strategiesCount; i++) {
            address strategy = strategyList[i];
            if (strategies[strategy].isActive && !strategies[strategy].isEmergencyExit) {
                try VaultStrategyBase(strategy).harvest() {
                    // Harvest successful
                } catch {
                    // Continue with other strategies if one fails
                }
            }
        }
    }
    
    function _allocateFunds(uint256 amount) internal {
        uint256 remainingAmount = amount;
        
        // Allocate to strategies based on their allocation percentages
        for (uint256 i = 0; i < strategiesCount && remainingAmount > 0; i++) {
            address strategy = strategyList[i];
            StrategyInfo storage strategyInfo = strategies[strategy];
            
            if (!strategyInfo.isActive || strategyInfo.isEmergencyExit) {
                continue;
            }
            
            uint256 allocationAmount = (amount * strategyInfo.allocation) / BASIS_POINTS;
            allocationAmount = Math.min(allocationAmount, remainingAmount);
            
            if (allocationAmount > 0) {
                _depositToStrategy(strategy, allocationAmount);
                remainingAmount -= allocationAmount;
            }
        }
    }
    
    function _withdrawFromStrategies(uint256 amount) internal {
        uint256 remainingAmount = amount;
        
        // Withdraw from strategies in reverse order of priority
        for (uint256 i = strategiesCount; i > 0 && remainingAmount > 0; i--) {
            address strategy = strategyList[i - 1];
            StrategyInfo storage strategyInfo = strategies[strategy];
            
            if (!strategyInfo.isActive) {
                continue;
            }
            
            uint256 strategyBalance = VaultStrategyBase(strategy).balanceOf();
            uint256 withdrawAmount = Math.min(remainingAmount, strategyBalance);
            
            if (withdrawAmount > 0) {
                _withdrawFromStrategy(strategy, withdrawAmount);
                remainingAmount -= withdrawAmount;
            }
        }
    }
    
    function _depositToStrategy(address strategy, uint256 amount) internal {
        IERC20(config.asset).forceApprove(strategy, amount);
        VaultStrategyBase(strategy).deposit(amount);
        
        strategies[strategy].totalDeposited += amount;
        
        emit FundsAllocated(strategy, amount, strategies[strategy].allocation);
    }
    
    function _withdrawFromStrategy(address strategy, uint256 amount) internal {
        uint256 strategyBalance = VaultStrategyBase(strategy).balanceOf();
        uint256 withdrawAmount = Math.min(amount, strategyBalance);
        
        if (withdrawAmount > 0) {
            // Calculate shares to withdraw (simplified)
            uint256 shares = (withdrawAmount * VaultStrategyBase(strategy).totalShares()) / strategyBalance;
            VaultStrategyBase(strategy).withdraw(shares);
            
            strategies[strategy].totalWithdrawn += withdrawAmount;
            
            emit FundsDeallocated(strategy, withdrawAmount, strategies[strategy].allocation);
        }
    }
    
    function _rebalanceStrategy(
        address strategy,
        uint256 oldAllocation,
        uint256 newAllocation
    ) internal {
        uint256 currentBalance = VaultStrategyBase(strategy).balanceOf();
        uint256 targetBalance = (totalAssets * newAllocation) / BASIS_POINTS;
        
        if (currentBalance > targetBalance) {
            _withdrawFromStrategy(strategy, currentBalance - targetBalance);
        } else if (currentBalance < targetBalance) {
            uint256 availableBalance = IERC20(config.asset).balanceOf(address(this));
            uint256 depositAmount = Math.min(targetBalance - currentBalance, availableBalance);
            if (depositAmount > 0) {
                _depositToStrategy(strategy, depositAmount);
            }
        }
    }
    
    function _shouldRebalance(uint256 current, uint256 target) internal view returns (bool) {
        if (target == 0) return current > 0;
        
        uint256 deviation = current > target ? current - target : target - current;
        uint256 deviationPercentage = (deviation * BASIS_POINTS) / target;
        
        return deviationPercentage >= config.rebalanceThreshold;
    }
    
    function _getTotalAllocation() internal view returns (uint256) {
        uint256 total = 0;
        for (uint256 i = 0; i < strategiesCount; i++) {
            total += strategies[strategyList[i]].allocation;
        }
        return total;
    }
    
    function _calculateTotalAssets() internal view returns (uint256) {
        uint256 total = IERC20(config.asset).balanceOf(address(this));
        
        for (uint256 i = 0; i < strategiesCount; i++) {
            address strategy = strategyList[i];
            if (strategies[strategy].isActive) {
                total += VaultStrategyBase(strategy).balanceOf();
            }
        }
        
        return total;
    }
    
    function _getUserBalance(address user) internal view returns (uint256) {
        // Simplified - in production this would be based on shares
        return IERC20(config.asset).balanceOf(user);
    }
    
    // View functions
    function getStrategyInfo(address strategy) external view returns (StrategyInfo memory) {
        return strategies[strategy];
    }
    
    function getAllStrategies() external view returns (address[] memory) {
        address[] memory allStrategies = new address[](strategiesCount);
        for (uint256 i = 0; i < strategiesCount; i++) {
            allStrategies[i] = strategyList[i];
        }
        return allStrategies;
    }
    
    function getTotalAssets() external view returns (uint256) {
        return _calculateTotalAssets();
    }
    
    function getStrategyBalance(address strategy) external view returns (uint256) {
        return VaultStrategyBase(strategy).balanceOf();
    }
    
    function getRebalanceHistory(uint256 limit) external view returns (RebalanceData[] memory) {
        if (limit == 0 || limit > rebalanceHistoryLength) {
            limit = rebalanceHistoryLength;
        }
        
        RebalanceData[] memory history = new RebalanceData[](limit);
        
        for (uint256 i = 0; i < limit; i++) {
            uint256 index = rebalanceHistoryLength > limit ? 
                rebalanceHistoryLength - limit + i : i;
            history[i] = rebalanceHistory[index];
        }
        
        return history;
    }
    
    // Admin functions
    function updateConfig(
        uint256 managementFee,
        uint256 performanceFee,
        uint256 rebalanceThreshold,
        bool autoRebalance
    ) external onlyRole(VAULT_MANAGER_ROLE) {
        require(managementFee <= MAX_MANAGEMENT_FEE, "Management fee too high");
        require(performanceFee <= MAX_PERFORMANCE_FEE, "Performance fee too high");
        
        config.managementFee = managementFee;
        config.performanceFee = performanceFee;
        config.rebalanceThreshold = rebalanceThreshold;
        config.autoRebalance = autoRebalance;
        
        emit ConfigUpdated(managementFee, performanceFee, autoRebalance);
    }
    
    function setTreasury(address _treasury) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_treasury != address(0), "Invalid treasury");
        treasury = _treasury;
    }
    
    function setGuardian(address _guardian) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_guardian != address(0), "Invalid guardian");
        guardian = _guardian;
    }
    
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }
    
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
}
