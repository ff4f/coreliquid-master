// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
/**
 * @title DepositManager
 * @dev Manages deposits and withdrawals across the protocol
 */
contract DepositManager is AccessControl, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;
    using Math for uint256;
    
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant DEPOSIT_MANAGER_ROLE = keccak256("DEPOSIT_MANAGER_ROLE");
    bytes32 public constant WITHDRAWAL_MANAGER_ROLE = keccak256("WITHDRAWAL_MANAGER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    
    uint256 public constant PRECISION = 1e18;
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant MAX_DEPOSIT_FEE = 1000; // 10%
    uint256 public constant MAX_WITHDRAWAL_FEE = 1000; // 10%
    
    // Deposit status
    enum DepositStatus {
        PENDING,
        CONFIRMED,
        FAILED,
        CANCELLED
    }
    
    // Withdrawal status
    enum WithdrawalStatus {
        PENDING,
        PROCESSING,
        COMPLETED,
        FAILED,
        CANCELLED
    }
    
    // Deposit information
    struct DepositInfo {
        address user;
        address token;
        uint256 amount;
        uint256 fee;
        uint256 netAmount;
        uint256 timestamp;
        uint256 blockNumber;
        DepositStatus status;
        bytes32 txHash;
    }
    
    // Withdrawal information
    struct WithdrawalInfo {
        address user;
        address token;
        uint256 amount;
        uint256 fee;
        uint256 netAmount;
        uint256 requestTimestamp;
        uint256 processTimestamp;
        uint256 unlockTimestamp;
        WithdrawalStatus status;
        bytes32 txHash;
    }
    
    // Token configuration
    struct TokenConfig {
        bool isSupported;
        uint256 minDepositAmount;
        uint256 maxDepositAmount;
        uint256 minWithdrawalAmount;
        uint256 maxWithdrawalAmount;
        uint256 depositFee; // Basis points
        uint256 withdrawalFee; // Basis points
        uint256 withdrawalDelay; // Seconds
        uint256 dailyWithdrawalLimit;
        bool requiresApproval;
    }
    
    // User deposit/withdrawal tracking
    struct UserStats {
        uint256 totalDeposited;
        uint256 totalWithdrawn;
        uint256 pendingWithdrawals;
        uint256 lastDepositTimestamp;
        uint256 lastWithdrawalTimestamp;
        uint256 dailyWithdrawnAmount;
        uint256 lastDailyResetTimestamp;
    }
    
    mapping(address => TokenConfig) public tokenConfigs;
    mapping(address => bool) public supportedTokens;
    mapping(bytes32 => DepositInfo) public deposits;
    mapping(bytes32 => WithdrawalInfo) public withdrawals;
    mapping(address => mapping(address => UserStats)) public userStats; // user => token => stats
    mapping(address => uint256) public tokenBalances;
    mapping(address => bool) public authorizedCallers;
    
    // Global settings
    uint256 public globalDepositLimit;
    uint256 public globalWithdrawalLimit;
    uint256 public defaultWithdrawalDelay = 24 hours;
    bool public emergencyWithdrawalEnabled = false;
    
    // Fee collection
    address public feeCollector;
    mapping(address => uint256) public collectedFees;
    
    // Counters
    uint256 public depositCounter;
    uint256 public withdrawalCounter;
    
    // Events
    event DepositInitiated(
        bytes32 indexed depositId,
        address indexed user,
        address indexed token,
        uint256 amount,
        uint256 fee
    );
    
    event DepositConfirmed(
        bytes32 indexed depositId,
        address indexed user,
        address indexed token,
        uint256 netAmount
    );
    
    event WithdrawalRequested(
        bytes32 indexed withdrawalId,
        address indexed user,
        address indexed token,
        uint256 amount,
        uint256 unlockTimestamp
    );
    
    event WithdrawalProcessed(
        bytes32 indexed withdrawalId,
        address indexed user,
        address indexed token,
        uint256 netAmount
    );
    
    event TokenConfigUpdated(
        address indexed token,
        uint256 minDeposit,
        uint256 maxDeposit,
        uint256 depositFee,
        uint256 withdrawalFee
    );
    
    event EmergencyWithdrawal(
        address indexed user,
        address indexed token,
        uint256 amount
    );
    
    event FeeCollected(
        address indexed token,
        uint256 amount,
        address indexed collector
    );
    
    constructor(
        address _feeCollector
    ) {
        require(_feeCollector != address(0), "DepositManager: invalid fee collector");
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(DEPOSIT_MANAGER_ROLE, msg.sender);
        _grantRole(WITHDRAWAL_MANAGER_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        
        feeCollector = _feeCollector;
        authorizedCallers[msg.sender] = true;
    }
    
    /**
     * @dev Initiate a deposit
     */
    function deposit(
        address token,
        uint256 amount
    ) external nonReentrant whenNotPaused returns (bytes32 depositId) {
        require(supportedTokens[token], "DepositManager: token not supported");
        require(amount > 0, "DepositManager: invalid amount");
        
        TokenConfig storage config = tokenConfigs[token];
        require(config.isSupported, "DepositManager: token not active");
        require(amount >= config.minDepositAmount, "DepositManager: amount below minimum");
        require(amount <= config.maxDepositAmount, "DepositManager: amount above maximum");
        
        // Check global limits
        require(
            globalDepositLimit == 0 || tokenBalances[token] + amount <= globalDepositLimit,
            "DepositManager: global deposit limit exceeded"
        );
        
        // Calculate fee
        uint256 fee = (amount * config.depositFee) / BASIS_POINTS;
        uint256 netAmount = amount - fee;
        
        // Generate deposit ID
        depositCounter++;
        depositId = keccak256(abi.encodePacked(
            msg.sender,
            token,
            amount,
            block.timestamp,
            depositCounter
        ));
        
        // Tokens deposited without transfer
        
        // Store deposit info
        deposits[depositId] = DepositInfo({
            user: msg.sender,
            token: token,
            amount: amount,
            fee: fee,
            netAmount: netAmount,
            timestamp: block.timestamp,
            blockNumber: block.number,
            status: DepositStatus.PENDING,
            txHash: bytes32(0)
        });
        
        // Update balances and stats
        tokenBalances[token] = tokenBalances[token] + netAmount;
        if (fee > 0) {
            collectedFees[token] = collectedFees[token] + fee;
        }
        
        UserStats storage stats = userStats[msg.sender][token];
        stats.totalDeposited = stats.totalDeposited + netAmount;
        stats.lastDepositTimestamp = block.timestamp;
        
        emit DepositInitiated(depositId, msg.sender, token, amount, fee);
        
        // Auto-confirm if no approval required
        if (!config.requiresApproval) {
            _confirmDeposit(depositId);
        }
    }
    
    /**
     * @dev Confirm a pending deposit
     */
    function confirmDeposit(
        bytes32 depositId
    ) external onlyRole(DEPOSIT_MANAGER_ROLE) {
        _confirmDeposit(depositId);
    }
    
    /**
     * @dev Request a withdrawal
     */
    function requestWithdrawal(
        address token,
        uint256 amount
    ) external nonReentrant whenNotPaused returns (bytes32 withdrawalId) {
        require(supportedTokens[token], "DepositManager: token not supported");
        require(amount > 0, "DepositManager: invalid amount");
        
        TokenConfig storage config = tokenConfigs[token];
        require(config.isSupported, "DepositManager: token not active");
        require(amount >= config.minWithdrawalAmount, "DepositManager: amount below minimum");
        require(amount <= config.maxWithdrawalAmount, "DepositManager: amount above maximum");
        require(tokenBalances[token] >= amount, "DepositManager: insufficient balance");
        
        // Check daily withdrawal limits
        UserStats storage stats = userStats[msg.sender][token];
        _updateDailyWithdrawalTracking(stats);
        
        require(
            config.dailyWithdrawalLimit == 0 || 
            stats.dailyWithdrawnAmount + amount <= config.dailyWithdrawalLimit,
            "DepositManager: daily withdrawal limit exceeded"
        );
        
        // Calculate fee and unlock timestamp
        uint256 fee = (amount * config.withdrawalFee) / BASIS_POINTS;
        uint256 netAmount = amount - fee;
        uint256 unlockTimestamp = block.timestamp + (
            emergencyWithdrawalEnabled ? 0 : config.withdrawalDelay
        );
        
        // Generate withdrawal ID
        withdrawalCounter++;
        withdrawalId = keccak256(abi.encodePacked(
            msg.sender,
            token,
            amount,
            block.timestamp,
            withdrawalCounter
        ));
        
        // Store withdrawal info
        withdrawals[withdrawalId] = WithdrawalInfo({
            user: msg.sender,
            token: token,
            amount: amount,
            fee: fee,
            netAmount: netAmount,
            requestTimestamp: block.timestamp,
            processTimestamp: 0,
            unlockTimestamp: unlockTimestamp,
            status: WithdrawalStatus.PENDING,
            txHash: bytes32(0)
        });
        
        // Update stats
        stats.pendingWithdrawals = stats.pendingWithdrawals + amount;
        stats.lastWithdrawalTimestamp = block.timestamp;
        
        emit WithdrawalRequested(withdrawalId, msg.sender, token, amount, unlockTimestamp);
    }
    
    /**
     * @dev Process a withdrawal
     */
    function processWithdrawal(
        bytes32 withdrawalId
    ) external nonReentrant whenNotPaused {
        WithdrawalInfo storage withdrawal = withdrawals[withdrawalId];
        require(withdrawal.user != address(0), "DepositManager: withdrawal not found");
        require(
            withdrawal.user == msg.sender || hasRole(WITHDRAWAL_MANAGER_ROLE, msg.sender),
            "DepositManager: unauthorized"
        );
        require(
            withdrawal.status == WithdrawalStatus.PENDING,
            "DepositManager: invalid status"
        );
        require(
            block.timestamp >= withdrawal.unlockTimestamp,
            "DepositManager: withdrawal locked"
        );
        
        // Check if sufficient balance
        require(
            tokenBalances[withdrawal.token] >= withdrawal.amount,
            "DepositManager: insufficient contract balance"
        );
        
        // Update status
        withdrawal.status = WithdrawalStatus.PROCESSING;
        withdrawal.processTimestamp = block.timestamp;
        
        // Transfer tokens
        IERC20(withdrawal.token).safeTransfer(withdrawal.user, withdrawal.netAmount);
        
        // Update balances and stats
        tokenBalances[withdrawal.token] = tokenBalances[withdrawal.token] - withdrawal.amount;
        if (withdrawal.fee > 0) {
            collectedFees[withdrawal.token] = collectedFees[withdrawal.token] + withdrawal.fee;
        }
        
        UserStats storage stats = userStats[withdrawal.user][withdrawal.token];
        stats.totalWithdrawn = stats.totalWithdrawn + withdrawal.netAmount;
        stats.pendingWithdrawals = stats.pendingWithdrawals - withdrawal.amount;
        stats.dailyWithdrawnAmount = stats.dailyWithdrawnAmount + withdrawal.amount;
        
        // Mark as completed
        withdrawal.status = WithdrawalStatus.COMPLETED;
        
        emit WithdrawalProcessed(
            withdrawalId,
            withdrawal.user,
            withdrawal.token,
            withdrawal.netAmount
        );
    }
    
    /**
     * @dev Emergency withdrawal (admin only)
     */
    function emergencyWithdraw(
        address user,
        address token,
        uint256 amount
    ) external onlyRole(ADMIN_ROLE) nonReentrant {
        require(emergencyWithdrawalEnabled, "DepositManager: emergency withdrawals disabled");
        require(tokenBalances[token] >= amount, "DepositManager: insufficient balance");
        
        IERC20(token).safeTransfer(user, amount);
        tokenBalances[token] = tokenBalances[token] - amount;
        
        emit EmergencyWithdrawal(user, token, amount);
    }
    
    /**
     * @dev Set token configuration
     */
    function setTokenConfig(
        address token,
        uint256 minDepositAmount,
        uint256 maxDepositAmount,
        uint256 minWithdrawalAmount,
        uint256 maxWithdrawalAmount,
        uint256 depositFee,
        uint256 withdrawalFee,
        uint256 withdrawalDelay,
        uint256 dailyWithdrawalLimit,
        bool requiresApproval,
        bool isSupported
    ) external onlyRole(ADMIN_ROLE) {
        require(token != address(0), "DepositManager: invalid token");
        require(depositFee <= MAX_DEPOSIT_FEE, "DepositManager: deposit fee too high");
        require(withdrawalFee <= MAX_WITHDRAWAL_FEE, "DepositManager: withdrawal fee too high");
        require(maxDepositAmount >= minDepositAmount, "DepositManager: invalid deposit range");
        require(maxWithdrawalAmount >= minWithdrawalAmount, "DepositManager: invalid withdrawal range");
        
        tokenConfigs[token] = TokenConfig({
            isSupported: isSupported,
            minDepositAmount: minDepositAmount,
            maxDepositAmount: maxDepositAmount,
            minWithdrawalAmount: minWithdrawalAmount,
            maxWithdrawalAmount: maxWithdrawalAmount,
            depositFee: depositFee,
            withdrawalFee: withdrawalFee,
            withdrawalDelay: withdrawalDelay,
            dailyWithdrawalLimit: dailyWithdrawalLimit,
            requiresApproval: requiresApproval
        });
        
        supportedTokens[token] = isSupported;
        
        emit TokenConfigUpdated(
            token,
            minDepositAmount,
            maxDepositAmount,
            depositFee,
            withdrawalFee
        );
    }
    
    /**
     * @dev Collect fees
     */
    function collectFees(
        address token
    ) external onlyRole(ADMIN_ROLE) nonReentrant {
        uint256 feeAmount = collectedFees[token];
        require(feeAmount > 0, "DepositManager: no fees to collect");
        
        collectedFees[token] = 0;
        IERC20(token).safeTransfer(feeCollector, feeAmount);
        
        emit FeeCollected(token, feeAmount, feeCollector);
    }
    
    /**
     * @dev Get user deposit/withdrawal stats
     */
    function getUserStats(
        address user,
        address token
    ) external view returns (
        uint256 totalDeposited,
        uint256 totalWithdrawn,
        uint256 pendingWithdrawals,
        uint256 availableForWithdrawal,
        uint256 dailyWithdrawnAmount,
        uint256 dailyWithdrawalLimit
    ) {
        UserStats storage stats = userStats[user][token];
        TokenConfig storage config = tokenConfigs[token];
        
        totalDeposited = stats.totalDeposited;
        totalWithdrawn = stats.totalWithdrawn;
        pendingWithdrawals = stats.pendingWithdrawals;
        availableForWithdrawal = totalDeposited - totalWithdrawn - pendingWithdrawals;
        
        // Calculate current daily withdrawn amount
        if (block.timestamp >= stats.lastDailyResetTimestamp + 1 days) {
            dailyWithdrawnAmount = 0;
        } else {
            dailyWithdrawnAmount = stats.dailyWithdrawnAmount;
        }
        
        dailyWithdrawalLimit = config.dailyWithdrawalLimit;
    }
    
    /**
     * @dev Get deposit information
     */
    function getDepositInfo(
        bytes32 depositId
    ) external view returns (
        address user,
        address token,
        uint256 amount,
        uint256 fee,
        uint256 netAmount,
        uint256 timestamp,
        DepositStatus status
    ) {
        DepositInfo storage depositInfo = deposits[depositId];
        return (
            depositInfo.user,
            depositInfo.token,
            depositInfo.amount,
            depositInfo.fee,
            depositInfo.netAmount,
            depositInfo.timestamp,
            depositInfo.status
        );
    }
    
    /**
     * @dev Get withdrawal information
     */
    function getWithdrawalInfo(
        bytes32 withdrawalId
    ) external view returns (
        address user,
        address token,
        uint256 amount,
        uint256 fee,
        uint256 netAmount,
        uint256 unlockTimestamp,
        WithdrawalStatus status
    ) {
        WithdrawalInfo storage withdrawal = withdrawals[withdrawalId];
        return (
            withdrawal.user,
            withdrawal.token,
            withdrawal.amount,
            withdrawal.fee,
            withdrawal.netAmount,
            withdrawal.unlockTimestamp,
            withdrawal.status
        );
    }
    
    /**
     * @dev Internal function to confirm deposit
     */
    function _confirmDeposit(bytes32 depositId) internal {
        DepositInfo storage depositInfo = deposits[depositId];
        require(depositInfo.user != address(0), "DepositManager: deposit not found");
        require(depositInfo.status == DepositStatus.PENDING, "DepositManager: invalid status");
        
        depositInfo.status = DepositStatus.CONFIRMED;
        
        emit DepositConfirmed(
            depositId,
            depositInfo.user,
            depositInfo.token,
            depositInfo.netAmount
        );
    }
    
    /**
     * @dev Update daily withdrawal tracking
     */
    function _updateDailyWithdrawalTracking(UserStats storage stats) internal {
        if (block.timestamp >= stats.lastDailyResetTimestamp + 1 days) {
            stats.dailyWithdrawnAmount = 0;
            stats.lastDailyResetTimestamp = block.timestamp;
        }
    }
    
    /**
     * @dev Set global limits
     */
    function setGlobalLimits(
        uint256 _globalDepositLimit,
        uint256 _globalWithdrawalLimit
    ) external onlyRole(ADMIN_ROLE) {
        globalDepositLimit = _globalDepositLimit;
        globalWithdrawalLimit = _globalWithdrawalLimit;
    }
    
    /**
     * @dev Set emergency withdrawal status
     */
    function setEmergencyWithdrawalEnabled(
        bool enabled
    ) external onlyRole(ADMIN_ROLE) {
        emergencyWithdrawalEnabled = enabled;
    }
    
    /**
     * @dev Set fee collector address
     */
    function setFeeCollector(address _feeCollector) external onlyRole(ADMIN_ROLE) {
        require(_feeCollector != address(0), "DepositManager: invalid fee collector");
        feeCollector = _feeCollector;
    }
    
    /**
     * @dev Set authorized caller status
     */
    function setAuthorizedCaller(address caller, bool authorized) external onlyRole(ADMIN_ROLE) {
        authorizedCallers[caller] = authorized;
    }
    
    /**
     * @dev Pause the contract
     */
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }
    
    /**
     * @dev Unpause the contract
     */
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }
}
