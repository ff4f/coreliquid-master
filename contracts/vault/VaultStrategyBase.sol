// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title VaultStrategyBase
 * @dev Base contract for all vault strategies
 */
abstract contract VaultStrategyBase is AccessControl, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;
    using Math for uint256;
    
    bytes32 public constant STRATEGY_MANAGER_ROLE = keccak256("STRATEGY_MANAGER_ROLE");
    bytes32 public constant KEEPER_ROLE = keccak256("KEEPER_ROLE");
    bytes32 public constant HARVESTER_ROLE = keccak256("HARVESTER_ROLE");
    
    struct StrategyConfig {
        string name;
        string description;
        address vault;
        address want; // Primary token this strategy wants
        uint256 performanceFee; // Performance fee in basis points
        uint256 managementFee; // Management fee in basis points
        uint256 withdrawalFee; // Withdrawal fee in basis points
        uint256 maxDeposit; // Maximum deposit amount
        uint256 minDeposit; // Minimum deposit amount
        bool isActive;
        bool emergencyExit;
    }
    
    struct StrategyMetrics {
        uint256 totalDeposited;
        uint256 totalWithdrawn;
        uint256 totalHarvested;
        uint256 totalFees;
        uint256 lastHarvest;
        uint256 lastDeposit;
        uint256 lastWithdraw;
        uint256 apy; // Annual Percentage Yield
        uint256 sharpeRatio; // Risk-adjusted return
    }
    
    struct PerformanceData {
        uint256 timestamp;
        uint256 totalAssets;
        uint256 pricePerShare;
        uint256 apy;
        uint256 totalReturns;
    }
    
    StrategyConfig public config;
    StrategyMetrics public metrics;
    
    mapping(uint256 => PerformanceData) public performanceHistory;
    mapping(address => uint256) public userDeposits;
    mapping(address => uint256) public userShares;
    mapping(address => uint256) public userLastDeposit;
    
    uint256 public totalShares;
    uint256 public lastPerformanceUpdate;
    uint256 public performanceHistoryLength;
    
    address public treasury;
    address public strategist;
    
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant MAX_PERFORMANCE_FEE = 2000; // 20%
    uint256 public constant MAX_MANAGEMENT_FEE = 200; // 2%
    uint256 public constant MAX_WITHDRAWAL_FEE = 100; // 1%
    uint256 public constant PERFORMANCE_HISTORY_LIMIT = 365; // 1 year of daily data
    
    event Deposited(
        address indexed user,
        uint256 amount,
        uint256 shares
    );
    
    event Withdrawn(
        address indexed user,
        uint256 amount,
        uint256 shares,
        uint256 fee
    );
    
    event Harvested(
        address indexed harvester,
        uint256 profit,
        uint256 performanceFee,
        uint256 timestamp
    );
    
    event StrategyConfigUpdated(
        string name,
        uint256 performanceFee,
        uint256 managementFee,
        bool isActive
    );
    
    event EmergencyExitEnabled(uint256 timestamp);
    
    event PerformanceUpdated(
        uint256 totalAssets,
        uint256 pricePerShare,
        uint256 apy
    );
    
    modifier onlyVault() {
        require(msg.sender == config.vault, "Only vault can call");
        _;
    }
    
    modifier onlyStrategist() {
        require(msg.sender == strategist, "Only strategist can call");
        _;
    }
    
    modifier whenNotEmergencyExit() {
        require(!config.emergencyExit, "Emergency exit enabled");
        _;
    }
    
    constructor(
        StrategyConfig memory _config,
        address _treasury,
        address _strategist
    ) {
        require(_config.vault != address(0), "Invalid vault");
        require(_config.want != address(0), "Invalid want token");
        require(_treasury != address(0), "Invalid treasury");
        require(_strategist != address(0), "Invalid strategist");
        require(_config.performanceFee <= MAX_PERFORMANCE_FEE, "Performance fee too high");
        require(_config.managementFee <= MAX_MANAGEMENT_FEE, "Management fee too high");
        require(_config.withdrawalFee <= MAX_WITHDRAWAL_FEE, "Withdrawal fee too high");
        
        config = _config;
        treasury = _treasury;
        strategist = _strategist;
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(STRATEGY_MANAGER_ROLE, msg.sender);
        _grantRole(KEEPER_ROLE, msg.sender);
        _grantRole(HARVESTER_ROLE, msg.sender);
        
        // Initialize performance tracking
        lastPerformanceUpdate = block.timestamp;
    }
    
    function deposit(uint256 amount) external virtual onlyVault nonReentrant whenNotPaused whenNotEmergencyExit {
        require(amount > 0, "Invalid amount");
        require(amount >= config.minDeposit, "Below minimum deposit");
        require(amount <= config.maxDeposit, "Above maximum deposit");
        require(config.isActive, "Strategy not active");
        
        // Transfer tokens from vault
        IERC20(config.want).safeTransferFrom(msg.sender, address(this), amount);
        
        // Calculate shares to mint
        uint256 shares = _calculateShares(amount);
        
        // Update user data
        userDeposits[tx.origin] += amount;
        userShares[tx.origin] += shares;
        userLastDeposit[tx.origin] = block.timestamp;
        
        // Update total shares
        totalShares += shares;
        
        // Update metrics
        metrics.totalDeposited += amount;
        metrics.lastDeposit = block.timestamp;
        
        // Deploy funds to strategy
        _deployFunds(amount);
        
        emit Deposited(tx.origin, amount, shares);
    }
    
    function withdraw(uint256 shares) external virtual onlyVault nonReentrant whenNotPaused returns (uint256 amount) {
        require(shares > 0, "Invalid shares");
        require(userShares[tx.origin] >= shares, "Insufficient shares");
        
        // Calculate withdrawal amount
        amount = _calculateWithdrawalAmount(shares);
        
        // Calculate withdrawal fee
        uint256 fee = (amount * config.withdrawalFee) / BASIS_POINTS;
        uint256 netAmount = amount - fee;
        
        // Update user data
        userShares[tx.origin] -= shares;
        userDeposits[tx.origin] = userDeposits[tx.origin] > amount ? userDeposits[tx.origin] - amount : 0;
        
        // Update total shares
        totalShares -= shares;
        
        // Update metrics
        metrics.totalWithdrawn += amount;
        metrics.totalFees += fee;
        metrics.lastWithdraw = block.timestamp;
        
        // Withdraw funds from strategy
        _withdrawFunds(amount);
        
        // Transfer tokens to vault
        IERC20(config.want).safeTransfer(msg.sender, netAmount);
        
        // Transfer fee to treasury
        if (fee > 0) {
            IERC20(config.want).safeTransfer(treasury, fee);
        }
        
        emit Withdrawn(tx.origin, netAmount, shares, fee);
        
        return netAmount;
    }
    
    function harvest() external virtual onlyRole(HARVESTER_ROLE) nonReentrant whenNotPaused {
        require(config.isActive, "Strategy not active");
        
        uint256 beforeBalance = IERC20(config.want).balanceOf(address(this));
        
        // Execute strategy-specific harvest logic
        _harvest();
        
        uint256 afterBalance = IERC20(config.want).balanceOf(address(this));
        uint256 profit = afterBalance > beforeBalance ? afterBalance - beforeBalance : 0;
        
        if (profit > 0) {
            // Calculate performance fee
            uint256 performanceFee = (profit * config.performanceFee) / BASIS_POINTS;
            
            // Transfer performance fee to treasury
            if (performanceFee > 0) {
                IERC20(config.want).safeTransfer(treasury, performanceFee);
            }
            
            // Update metrics
            metrics.totalHarvested += profit;
            metrics.totalFees += performanceFee;
            metrics.lastHarvest = block.timestamp;
            
            // Redeploy remaining profit
            uint256 remainingProfit = profit - performanceFee;
            if (remainingProfit > 0) {
                _deployFunds(remainingProfit);
            }
            
            emit Harvested(msg.sender, profit, performanceFee, block.timestamp);
        }
        
        // Update performance metrics
        _updatePerformanceMetrics();
    }
    
    function emergencyWithdraw() external virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        config.emergencyExit = true;
        
        // Withdraw all funds from strategy
        _emergencyWithdraw();
        
        emit EmergencyExitEnabled(block.timestamp);
    }
    
    function balanceOf() public view virtual returns (uint256) {
        return _balanceOfStrategy() + IERC20(config.want).balanceOf(address(this));
    }
    
    function balanceOfWant() public view returns (uint256) {
        return IERC20(config.want).balanceOf(address(this));
    }
    
    function balanceOfStrategy() public view virtual returns (uint256) {
        return _balanceOfStrategy();
    }
    
    function pricePerShare() public view returns (uint256) {
        if (totalShares == 0) {
            return 1e18;
        }
        return (balanceOf() * 1e18) / totalShares;
    }
    
    function getUserInfo(address user) external view returns (
        uint256 deposits,
        uint256 shares,
        uint256 value,
        uint256 lastDeposit
    ) {
        deposits = userDeposits[user];
        shares = userShares[user];
        value = (shares * pricePerShare()) / 1e18;
        lastDeposit = userLastDeposit[user];
    }
    
    function getAPY() public view returns (uint256) {
        if (performanceHistoryLength < 2) {
            return 0;
        }
        
        // Calculate APY based on recent performance
        uint256 recentIndex = performanceHistoryLength - 1;
        uint256 oldIndex = recentIndex > 30 ? recentIndex - 30 : 0; // 30-day window
        
        PerformanceData memory recent = performanceHistory[recentIndex];
        PerformanceData memory old = performanceHistory[oldIndex];
        
        if (old.pricePerShare == 0 || recent.timestamp <= old.timestamp) {
            return 0;
        }
        
        uint256 priceGrowth = (recent.pricePerShare * 1e18) / old.pricePerShare;
        uint256 timeElapsed = recent.timestamp - old.timestamp;
        
        // Annualize the return
        uint256 apy = ((priceGrowth - 1e18) * 365 days) / timeElapsed;
        
        return apy;
    }
    
    function _calculateShares(uint256 amount) internal view returns (uint256) {
        if (totalShares == 0) {
            return amount;
        }
        return (amount * totalShares) / balanceOf();
    }
    
    function _calculateWithdrawalAmount(uint256 shares) internal view returns (uint256) {
        return (shares * balanceOf()) / totalShares;
    }
    
    function _updatePerformanceMetrics() internal {
        uint256 currentBalance = balanceOf();
        uint256 currentPricePerShare = pricePerShare();
        uint256 currentAPY = getAPY();
        
        // Store performance data
        performanceHistory[performanceHistoryLength] = PerformanceData({
            timestamp: block.timestamp,
            totalAssets: currentBalance,
            pricePerShare: currentPricePerShare,
            apy: currentAPY,
            totalReturns: metrics.totalHarvested
        });
        
        performanceHistoryLength++;
        
        // Limit history size
        if (performanceHistoryLength > PERFORMANCE_HISTORY_LIMIT) {
            // Shift array (simplified - in production use more efficient method)
            for (uint256 i = 0; i < PERFORMANCE_HISTORY_LIMIT - 1; i++) {
                performanceHistory[i] = performanceHistory[i + 1];
            }
            performanceHistoryLength = PERFORMANCE_HISTORY_LIMIT;
        }
        
        // Update metrics
        metrics.apy = currentAPY;
        lastPerformanceUpdate = block.timestamp;
        
        emit PerformanceUpdated(currentBalance, currentPricePerShare, currentAPY);
    }
    
    function getPerformanceHistory(uint256 limit) external view returns (PerformanceData[] memory) {
        if (limit == 0 || limit > performanceHistoryLength) {
            limit = performanceHistoryLength;
        }
        
        PerformanceData[] memory history = new PerformanceData[](limit);
        
        for (uint256 i = 0; i < limit; i++) {
            uint256 index = performanceHistoryLength > limit ? 
                performanceHistoryLength - limit + i : i;
            history[i] = performanceHistory[index];
        }
        
        return history;
    }
    
    function updateConfig(
        string memory name,
        uint256 performanceFee,
        uint256 managementFee,
        uint256 withdrawalFee
    ) external onlyRole(STRATEGY_MANAGER_ROLE) {
        require(performanceFee <= MAX_PERFORMANCE_FEE, "Performance fee too high");
        require(managementFee <= MAX_MANAGEMENT_FEE, "Management fee too high");
        require(withdrawalFee <= MAX_WITHDRAWAL_FEE, "Withdrawal fee too high");
        
        config.name = name;
        config.performanceFee = performanceFee;
        config.managementFee = managementFee;
        config.withdrawalFee = withdrawalFee;
        
        emit StrategyConfigUpdated(name, performanceFee, managementFee, config.isActive);
    }
    
    function setActive(bool active) external onlyRole(STRATEGY_MANAGER_ROLE) {
        config.isActive = active;
    }
    
    function setDepositLimits(
        uint256 minDeposit,
        uint256 maxDepositLimit
    ) external onlyRole(STRATEGY_MANAGER_ROLE) {
        require(minDeposit <= maxDepositLimit, "Invalid deposit limits");
        config.minDeposit = minDeposit;
        config.maxDeposit = maxDepositLimit;
    }
    
    function setTreasury(address _treasury) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_treasury != address(0), "Invalid treasury");
        treasury = _treasury;
    }
    
    function setStrategist(address _strategist) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_strategist != address(0), "Invalid strategist");
        strategist = _strategist;
    }
    
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }
    
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
    
    // Abstract functions to be implemented by specific strategies
    function _deployFunds(uint256 amount) internal virtual;
    function _withdrawFunds(uint256 amount) internal virtual;
    function _harvest() internal virtual;
    function _balanceOfStrategy() internal view virtual returns (uint256);
    function _emergencyWithdraw() internal virtual;
    
    // Optional: Strategy-specific functions
    function estimatedTotalAssets() external view virtual returns (uint256) {
        return balanceOf();
    }
    
    function estimatedAPY() external view virtual returns (uint256) {
        return getAPY();
    }
    
    function maxDeposit() external view virtual returns (uint256) {
        return config.maxDeposit;
    }
    
    function maxWithdraw(address user) external view virtual returns (uint256) {
        return _calculateWithdrawalAmount(userShares[user]);
    }
}
