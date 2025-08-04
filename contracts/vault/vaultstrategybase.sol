// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title VaultStrategyBase
 * @dev Base contract for all vault strategies with common functionality
 */
abstract contract VaultStrategyBase is AccessControl, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    using Math for uint256;

    bytes32 public constant STRATEGY_MANAGER_ROLE = keccak256("STRATEGY_MANAGER_ROLE");
    bytes32 public constant KEEPER_ROLE = keccak256("KEEPER_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");

    uint256 public constant PRECISION = 1e18;
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant MAX_SLIPPAGE = 1000; // 10%
    uint256 public constant MAX_PERFORMANCE_FEE = 2000; // 20%
    uint256 public constant MAX_MANAGEMENT_FEE = 200; // 2%

    struct StrategyInfo {
        string name;
        string description;
        address asset;
        uint256 totalDeposits;
        uint256 totalShares;
        uint256 lastHarvest;
        uint256 performanceFee;
        uint256 managementFee;
        bool isActive;
    }

    struct PerformanceMetrics {
        uint256 totalReturns;
        uint256 annualizedReturn;
        uint256 sharpeRatio;
        uint256 maxDrawdown;
        uint256 volatility;
        uint256 lastUpdate;
    }

    struct RiskParameters {
        uint256 maxLeverage;
        uint256 maxSlippage;
        uint256 maxPositionSize;
        uint256 stopLossThreshold;
        uint256 rebalanceThreshold;
        bool emergencyExitEnabled;
    }

    StrategyInfo public strategyInfo;
    PerformanceMetrics public performanceMetrics;
    RiskParameters public riskParameters;
    
    address public vault;
    address public feeRecipient;
    uint256 public minDeposit = 1000; // Minimum deposit amount
    uint256 public maxDeposit = type(uint256).max; // Maximum deposit amount
    uint256 public withdrawalDelay = 0; // Withdrawal delay in seconds
    uint256 public lastRebalance;
    uint256 public rebalanceInterval = 24 hours;
    
    mapping(address => uint256) public userShares;
    mapping(address => uint256) public userLastDeposit;
    mapping(address => uint256) public pendingWithdrawals;
    
    event Deposited(address indexed user, uint256 amount, uint256 shares);
    event Withdrawn(address indexed user, uint256 amount, uint256 shares);
    event Harvested(uint256 profit, uint256 performanceFee);
    event Rebalanced(uint256 timestamp);
    event EmergencyExit(uint256 amount);
    event FeesUpdated(uint256 performanceFee, uint256 managementFee);
    event RiskParametersUpdated();

    modifier onlyVault() {
        require(msg.sender == vault, "Only vault can call");
        _;
    }

    modifier onlyKeeper() {
        require(hasRole(KEEPER_ROLE, msg.sender), "Only keeper can call");
        _;
    }

    constructor(
        string memory _name,
        string memory _description,
        address _asset,
        address _vault,
        address _feeRecipient
    ) {
        require(_asset != address(0), "Invalid asset");
        require(_vault != address(0), "Invalid vault");
        require(_feeRecipient != address(0), "Invalid fee recipient");

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(STRATEGY_MANAGER_ROLE, msg.sender);
        _grantRole(KEEPER_ROLE, msg.sender);
        _grantRole(EMERGENCY_ROLE, msg.sender);

        strategyInfo = StrategyInfo({
            name: _name,
            description: _description,
            asset: _asset,
            totalDeposits: 0,
            totalShares: 0,
            lastHarvest: block.timestamp,
            performanceFee: 1000, // 10% default
            managementFee: 100,   // 1% default
            isActive: true
        });

        riskParameters = RiskParameters({
            maxLeverage: 300, // 3x
            maxSlippage: 100, // 1%
            maxPositionSize: 5000, // 50%
            stopLossThreshold: 1000, // 10%
            rebalanceThreshold: 500, // 5%
            emergencyExitEnabled: true
        });

        vault = _vault;
        feeRecipient = _feeRecipient;
        lastRebalance = block.timestamp;
    }

    /**
     * @dev Deposit assets into the strategy
     * @param amount Amount to deposit
     * @return shares Number of shares minted
     */
    function deposit(uint256 amount) external virtual nonReentrant whenNotPaused returns (uint256 shares) {
        require(strategyInfo.isActive, "Strategy not active");
        require(amount >= minDeposit, "Amount below minimum");
        require(amount <= maxDeposit, "Amount above maximum");

        IERC20(strategyInfo.asset).safeTransferFrom(msg.sender, address(this), amount);

        // Calculate shares to mint
        shares = _calculateShares(amount);
        require(shares > 0, "No shares to mint");

        // Update state
        strategyInfo.totalDeposits = strategyInfo.totalDeposits.add(amount);
        strategyInfo.totalShares = strategyInfo.totalShares.add(shares);
        userShares[msg.sender] = userShares[msg.sender].add(shares);
        userLastDeposit[msg.sender] = block.timestamp;

        // Deploy capital
        _deployCapital(amount);

        emit Deposited(msg.sender, amount, shares);
        return shares;
    }

    /**
     * @dev Withdraw assets from the strategy
     * @param shares Number of shares to burn
     * @return amount Amount of assets withdrawn
     */
    function withdraw(uint256 shares) external virtual nonReentrant returns (uint256 amount) {
        require(shares > 0, "Invalid shares");
        require(userShares[msg.sender] >= shares, "Insufficient shares");
        require(block.timestamp >= userLastDeposit[msg.sender].add(withdrawalDelay), "Withdrawal delay not met");

        // Calculate amount to withdraw
        amount = _calculateWithdrawalAmount(shares);
        require(amount > 0, "No assets to withdraw");

        // Update state
        strategyInfo.totalShares = strategyInfo.totalShares.sub(shares);
        userShares[msg.sender] = userShares[msg.sender].sub(shares);

        // Withdraw capital
        _withdrawCapital(amount);

        // Transfer assets
        IERC20(strategyInfo.asset).safeTransfer(msg.sender, amount);

        emit Withdrawn(msg.sender, amount, shares);
        return amount;
    }

    /**
     * @dev Harvest profits and compound returns
     * @return profit Total profit harvested
     */
    function harvest() external virtual onlyKeeper nonReentrant returns (uint256 profit) {
        require(strategyInfo.isActive, "Strategy not active");

        // Get current total value
        uint256 currentValue = totalAssets();
        uint256 totalDeposits = strategyInfo.totalDeposits;

        if (currentValue > totalDeposits) {
            profit = currentValue.sub(totalDeposits);
            
            // Calculate and take performance fee
            uint256 performanceFee = profit.mul(strategyInfo.performanceFee).div(BASIS_POINTS);
            if (performanceFee > 0) {
                _takePerformanceFee(performanceFee);
                profit = profit.sub(performanceFee);
            }

            // Compound remaining profit
            _compoundReturns(profit);

            // Update metrics
            _updatePerformanceMetrics(profit);
            strategyInfo.lastHarvest = block.timestamp;

            emit Harvested(profit, performanceFee);
        }

        return profit;
    }

    /**
     * @dev Rebalance the strategy positions
     */
    function rebalance() external virtual onlyKeeper nonReentrant {
        require(strategyInfo.isActive, "Strategy not active");
        require(block.timestamp >= lastRebalance.add(rebalanceInterval), "Rebalance too soon");

        _rebalancePositions();
        lastRebalance = block.timestamp;

        emit Rebalanced(block.timestamp);
    }

    /**
     * @dev Emergency exit from all positions
     */
    function emergencyExit() external onlyRole(EMERGENCY_ROLE) nonReentrant {
        require(riskParameters.emergencyExitEnabled, "Emergency exit disabled");

        uint256 totalValue = _emergencyWithdraw();
        strategyInfo.isActive = false;

        emit EmergencyExit(totalValue);
    }

    /**
     * @dev Set strategy fees
     * @param _performanceFee Performance fee in basis points
     * @param _managementFee Management fee in basis points
     */
    function setFees(uint256 _performanceFee, uint256 _managementFee) 
        external 
        onlyRole(STRATEGY_MANAGER_ROLE) 
    {
        require(_performanceFee <= MAX_PERFORMANCE_FEE, "Performance fee too high");
        require(_managementFee <= MAX_MANAGEMENT_FEE, "Management fee too high");

        strategyInfo.performanceFee = _performanceFee;
        strategyInfo.managementFee = _managementFee;

        emit FeesUpdated(_performanceFee, _managementFee);
    }

    /**
     * @dev Set risk parameters
     */
    function setRiskParameters(
        uint256 _maxLeverage,
        uint256 _maxSlippage,
        uint256 _maxPositionSize,
        uint256 _stopLossThreshold,
        uint256 _rebalanceThreshold
    ) external onlyRole(STRATEGY_MANAGER_ROLE) {
        require(_maxSlippage <= MAX_SLIPPAGE, "Slippage too high");
        require(_maxPositionSize <= BASIS_POINTS, "Position size too high");

        riskParameters.maxLeverage = _maxLeverage;
        riskParameters.maxSlippage = _maxSlippage;
        riskParameters.maxPositionSize = _maxPositionSize;
        riskParameters.stopLossThreshold = _stopLossThreshold;
        riskParameters.rebalanceThreshold = _rebalanceThreshold;

        emit RiskParametersUpdated();
    }

    /**
     * @dev Calculate shares to mint for deposit amount
     */
    function _calculateShares(uint256 amount) internal view returns (uint256) {
        if (strategyInfo.totalShares == 0) {
            return amount;
        }
        
        uint256 totalValue = totalAssets();
        if (totalValue == 0) {
            return amount;
        }
        
        return amount.mul(strategyInfo.totalShares).div(totalValue);
    }

    /**
     * @dev Calculate withdrawal amount for shares
     */
    function _calculateWithdrawalAmount(uint256 shares) internal view returns (uint256) {
        if (strategyInfo.totalShares == 0) {
            return 0;
        }
        
        uint256 totalValue = totalAssets();
        return shares.mul(totalValue).div(strategyInfo.totalShares);
    }

    /**
     * @dev Take performance fee
     */
    function _takePerformanceFee(uint256 feeAmount) internal virtual {
        if (feeAmount > 0 && feeRecipient != address(0)) {
            IERC20(strategyInfo.asset).safeTransfer(feeRecipient, feeAmount);
        }
    }

    /**
     * @dev Update performance metrics
     */
    function _updatePerformanceMetrics(uint256 profit) internal {
        performanceMetrics.totalReturns = performanceMetrics.totalReturns.add(profit);
        performanceMetrics.lastUpdate = block.timestamp;
        
        // Calculate annualized return
        uint256 timePeriod = block.timestamp.sub(strategyInfo.lastHarvest);
        if (timePeriod > 0 && strategyInfo.totalDeposits > 0) {
            uint256 periodReturn = profit.mul(PRECISION).div(strategyInfo.totalDeposits);
            performanceMetrics.annualizedReturn = periodReturn.mul(365 days).div(timePeriod);
        }
    }

    // Abstract functions to be implemented by specific strategies
    function totalAssets() public view virtual returns (uint256);
    function _deployCapital(uint256 amount) internal virtual;
    function _withdrawCapital(uint256 amount) internal virtual;
    function _compoundReturns(uint256 profit) internal virtual;
    function _rebalancePositions() internal virtual;
    function _emergencyWithdraw() internal virtual returns (uint256);

    /**
     * @dev Get strategy information
     */
    function getStrategyInfo() external view returns (StrategyInfo memory) {
        return strategyInfo;
    }

    /**
     * @dev Get performance metrics
     */
    function getPerformanceMetrics() external view returns (PerformanceMetrics memory) {
        return performanceMetrics;
    }

    /**
     * @dev Get risk parameters
     */
    function getRiskParameters() external view returns (RiskParameters memory) {
        return riskParameters;
    }

    /**
     * @dev Get user share balance
     */
    function getUserShares(address user) external view returns (uint256) {
        return userShares[user];
    }

    /**
     * @dev Get user asset balance
     */
    function getUserBalance(address user) external view returns (uint256) {
        if (strategyInfo.totalShares == 0) {
            return 0;
        }
        
        uint256 totalValue = totalAssets();
        return userShares[user].mul(totalValue).div(strategyInfo.totalShares);
    }

    /**
     * @dev Pause the strategy
     */
    function pause() external onlyRole(EMERGENCY_ROLE) {
        _pause();
    }

    /**
     * @dev Unpause the strategy
     */
    function unpause() external onlyRole(EMERGENCY_ROLE) {
        _unpause();
    }

    /**
     * @dev Set strategy active status
     */
    function setActive(bool _isActive) external onlyRole(STRATEGY_MANAGER_ROLE) {
        strategyInfo.isActive = _isActive;
    }
}