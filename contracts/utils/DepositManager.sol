// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title DepositManager
 * @dev Manages deposits and withdrawals for the protocol
 */
contract DepositManager is Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    struct DepositInfo {
        address user;
        address token;
        uint256 amount;
        uint256 timestamp;
        uint256 lockPeriod;
        bool isWithdrawn;
        uint256 rewards;
    }

    mapping(uint256 => DepositInfo) public deposits;
    mapping(address => uint256[]) public userDeposits;
    mapping(address => bool) public supportedTokens;
    mapping(address => uint256) public tokenBalances;
    
    uint256 public nextDepositId = 1;
    uint256 public minDepositAmount = 1000 * 1e18; // 1000 tokens minimum
    uint256 public maxDepositAmount = 1000000 * 1e18; // 1M tokens maximum
    uint256 public defaultLockPeriod = 30 days;
    
    address public treasury;
    uint256 public depositFee = 50; // 0.5% in basis points
    uint256 public withdrawalFee = 100; // 1% in basis points
    uint256 public constant BASIS_POINTS = 10000;

    event DepositMade(
        uint256 indexed depositId,
        address indexed user,
        address indexed token,
        uint256 amount,
        uint256 lockPeriod
    );

    event WithdrawalMade(
        uint256 indexed depositId,
        address indexed user,
        address indexed token,
        uint256 amount,
        uint256 rewards
    );

    event TokenSupported(address indexed token, bool supported);
    event FeesUpdated(uint256 depositFee, uint256 withdrawalFee);
    event TreasuryUpdated(address indexed newTreasury);

    constructor(address _treasury) Ownable(msg.sender) {
        require(_treasury != address(0), "Invalid treasury");
        treasury = _treasury;
    }

    /**
     * @dev Make a deposit
     * @param token Token to deposit
     * @param amount Amount to deposit
     * @param lockPeriod Lock period in seconds
     * @return depositId Unique deposit ID
     */
    function deposit(
        address token,
        uint256 amount,
        uint256 lockPeriod
    ) external nonReentrant whenNotPaused returns (uint256 depositId) {
        require(supportedTokens[token], "Token not supported");
        require(amount >= minDepositAmount, "Amount below minimum");
        require(amount <= maxDepositAmount, "Amount above maximum");
        require(lockPeriod >= 1 days, "Lock period too short");
        require(lockPeriod <= 365 days, "Lock period too long");

        // Calculate deposit fee
        uint256 fee = amount * depositFee / BASIS_POINTS;
        uint256 netAmount = amount - fee;

        // Transfer tokens from user
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        
        // Transfer fee to treasury
        if (fee > 0) {
            IERC20(token).safeTransfer(treasury, fee);
        }

        // Create deposit record
        depositId = nextDepositId++;
        deposits[depositId] = DepositInfo({
            user: msg.sender,
            token: token,
            amount: netAmount,
            timestamp: block.timestamp,
            lockPeriod: lockPeriod,
            isWithdrawn: false,
            rewards: 0
        });

        userDeposits[msg.sender].push(depositId);
        tokenBalances[token] += netAmount;

        emit DepositMade(depositId, msg.sender, token, netAmount, lockPeriod);
    }

    /**
     * @dev Withdraw a deposit
     * @param depositId Deposit ID to withdraw
     */
    function withdraw(uint256 depositId) external nonReentrant {
        DepositInfo storage depositInfo = deposits[depositId];
        require(depositInfo.user == msg.sender, "Not deposit owner");
        require(!depositInfo.isWithdrawn, "Already withdrawn");
        require(
            block.timestamp >= depositInfo.timestamp + depositInfo.lockPeriod,
            "Lock period not expired"
        );

        uint256 totalAmount = depositInfo.amount + depositInfo.rewards;
        uint256 fee = totalAmount * withdrawalFee / BASIS_POINTS;
        uint256 netAmount = totalAmount - fee;

        // Mark as withdrawn
        depositInfo.isWithdrawn = true;
        tokenBalances[depositInfo.token] -= depositInfo.amount;

        // Transfer tokens to user
        IERC20(depositInfo.token).safeTransfer(msg.sender, netAmount);
        
        // Transfer fee to treasury
        if (fee > 0) {
            IERC20(depositInfo.token).safeTransfer(treasury, fee);
        }

        emit WithdrawalMade(
            depositId,
            msg.sender,
            depositInfo.token,
            netAmount,
            depositInfo.rewards
        );
    }

    /**
     * @dev Emergency withdraw (with penalty)
     * @param depositId Deposit ID to withdraw
     */
    function emergencyWithdraw(uint256 depositId) external nonReentrant {
        DepositInfo storage depositInfo = deposits[depositId];
        require(depositInfo.user == msg.sender, "Not deposit owner");
        require(!depositInfo.isWithdrawn, "Already withdrawn");

        uint256 penalty = depositInfo.amount * 1000 / BASIS_POINTS; // 10% penalty
        uint256 netAmount = depositInfo.amount - penalty;

        // Mark as withdrawn
        depositInfo.isWithdrawn = true;
        tokenBalances[depositInfo.token] -= depositInfo.amount;

        // Transfer tokens to user (minus penalty)
        IERC20(depositInfo.token).safeTransfer(msg.sender, netAmount);
        
        // Transfer penalty to treasury
        IERC20(depositInfo.token).safeTransfer(treasury, penalty);

        emit WithdrawalMade(depositId, msg.sender, depositInfo.token, netAmount, 0);
    }

    /**
     * @dev Add rewards to a deposit
     * @param depositId Deposit ID
     * @param rewardAmount Reward amount to add
     */
    function addRewards(uint256 depositId, uint256 rewardAmount) external onlyOwner {
        require(deposits[depositId].user != address(0), "Deposit not found");
        require(!deposits[depositId].isWithdrawn, "Deposit already withdrawn");
        
        deposits[depositId].rewards += rewardAmount;
    }

    /**
     * @dev Set token support status
     * @param token Token address
     * @param supported Whether token is supported
     */
    function setTokenSupport(address token, bool supported) external onlyOwner {
        require(token != address(0), "Invalid token");
        supportedTokens[token] = supported;
        emit TokenSupported(token, supported);
    }

    /**
     * @dev Update fees
     * @param _depositFee New deposit fee (basis points)
     * @param _withdrawalFee New withdrawal fee (basis points)
     */
    function updateFees(uint256 _depositFee, uint256 _withdrawalFee) external onlyOwner {
        require(_depositFee <= 500, "Deposit fee too high"); // Max 5%
        require(_withdrawalFee <= 1000, "Withdrawal fee too high"); // Max 10%
        
        depositFee = _depositFee;
        withdrawalFee = _withdrawalFee;
        emit FeesUpdated(_depositFee, _withdrawalFee);
    }

    /**
     * @dev Update treasury address
     * @param _treasury New treasury address
     */
    function updateTreasury(address _treasury) external onlyOwner {
        require(_treasury != address(0), "Invalid treasury");
        treasury = _treasury;
        emit TreasuryUpdated(_treasury);
    }

    /**
     * @dev Update deposit limits
     * @param _minAmount New minimum deposit amount
     * @param _maxAmount New maximum deposit amount
     */
    function updateDepositLimits(uint256 _minAmount, uint256 _maxAmount) external onlyOwner {
        require(_minAmount < _maxAmount, "Invalid limits");
        minDepositAmount = _minAmount;
        maxDepositAmount = _maxAmount;
    }

    /**
     * @dev Get user deposits
     * @param user User address
     * @return depositIds Array of deposit IDs
     */
    function getUserDeposits(address user) external view returns (uint256[] memory depositIds) {
        return userDeposits[user];
    }

    /**
     * @dev Get deposit info
     * @param depositId Deposit ID
     * @return depositInfo Deposit information
     */
    function getDepositInfo(uint256 depositId) external view returns (DepositInfo memory depositInfo) {
        return deposits[depositId];
    }

    /**
     * @dev Check if deposit is withdrawable
     * @param depositId Deposit ID
     * @return withdrawable True if withdrawable
     */
    function isWithdrawable(uint256 depositId) external view returns (bool withdrawable) {
        DepositInfo memory depositInfo = deposits[depositId];
        return !depositInfo.isWithdrawn && 
               block.timestamp >= depositInfo.timestamp + depositInfo.lockPeriod;
    }

    /**
     * @dev Pause contract
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev Unpause contract
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @dev Emergency token recovery
     * @param token Token to recover
     * @param amount Amount to recover
     */
    function emergencyRecovery(address token, uint256 amount) external onlyOwner {
        IERC20(token).safeTransfer(owner(), amount);
    }
}