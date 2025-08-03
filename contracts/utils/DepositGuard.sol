// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title DepositGuard
 * @dev Security layer for deposit operations with validation and limits
 */
contract DepositGuard is AccessControl, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;
    
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    
    // Deposit limits and controls
    struct DepositLimits {
        uint256 minAmount;
        uint256 maxAmount;
        uint256 dailyLimit;
        uint256 totalLimit;
        bool isActive;
    }
    
    // User deposit tracking
    struct UserDeposits {
        uint256 totalDeposited;
        uint256 dailyDeposited;
        uint256 lastDepositDay;
        bool isWhitelisted;
        bool isBlacklisted;
    }
    
    mapping(address => DepositLimits) public tokenLimits;
    mapping(address => UserDeposits) public userDeposits;
    mapping(address => bool) public supportedTokens;
    mapping(address => bool) public authorizedCallers;
    
    // Global settings
    uint256 public globalDailyLimit;
    uint256 public globalTotalLimit;
    uint256 public emergencyWithdrawDelay = 86400; // 24 hours
    bool public emergencyMode = false;
    
    // Events
    event DepositValidated(
        address indexed user,
        address indexed token,
        uint256 amount,
        uint256 timestamp
    );
    
    event LimitsUpdated(
        address indexed token,
        uint256 minAmount,
        uint256 maxAmount,
        uint256 dailyLimit
    );
    
    event UserStatusUpdated(
        address indexed user,
        bool whitelisted,
        bool blacklisted
    );
    
    event EmergencyModeToggled(bool enabled);
    
    modifier onlyAuthorized() {
        require(
            authorizedCallers[msg.sender] || hasRole(ADMIN_ROLE, msg.sender),
            "DepositGuard: not authorized"
        );
        _;
    }
    
    modifier notBlacklisted(address user) {
        require(!userDeposits[user].isBlacklisted, "DepositGuard: user blacklisted");
        _;
    }
    
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(GUARDIAN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
    }
    
    /**
     * @dev Validate a deposit before processing
     */
    function validateDeposit(
        address user,
        address token,
        uint256 amount
    ) external onlyAuthorized notBlacklisted(user) whenNotPaused returns (bool) {
        require(supportedTokens[token], "DepositGuard: token not supported");
        require(amount > 0, "DepositGuard: invalid amount");
        
        if (emergencyMode) {
            require(
                userDeposits[user].isWhitelisted,
                "DepositGuard: emergency mode - whitelist only"
            );
        }
        
        DepositLimits storage limits = tokenLimits[token];
        require(limits.isActive, "DepositGuard: token deposits disabled");
        
        // Check amount limits
        require(amount >= limits.minAmount, "DepositGuard: below minimum");
        require(amount <= limits.maxAmount, "DepositGuard: above maximum");
        
        UserDeposits storage userInfo = userDeposits[user];
        uint256 currentDay = block.timestamp / 86400;
        
        // Reset daily counter if new day
        if (userInfo.lastDepositDay < currentDay) {
            userInfo.dailyDeposited = 0;
            userInfo.lastDepositDay = currentDay;
        }
        
        // Check daily limits
        require(
            userInfo.dailyDeposited + amount <= limits.dailyLimit,
            "DepositGuard: daily limit exceeded"
        );
        
        // Check total limits
        require(
            userInfo.totalDeposited + amount <= limits.totalLimit,
            "DepositGuard: total limit exceeded"
        );
        
        // Update user deposit tracking
        userInfo.totalDeposited += amount;
        userInfo.dailyDeposited += amount;
        
        emit DepositValidated(user, token, amount, block.timestamp);
        
        return true;
    }
    
    /**
     * @dev Set deposit limits for a token
     */
    function setTokenLimits(
        address token,
        uint256 minAmount,
        uint256 maxAmount,
        uint256 dailyLimit,
        uint256 totalLimit,
        bool isActive
    ) external onlyRole(ADMIN_ROLE) {
        require(token != address(0), "DepositGuard: invalid token");
        require(maxAmount >= minAmount, "DepositGuard: invalid limits");
        
        tokenLimits[token] = DepositLimits({
            minAmount: minAmount,
            maxAmount: maxAmount,
            dailyLimit: dailyLimit,
            totalLimit: totalLimit,
            isActive: isActive
        });
        
        if (!supportedTokens[token]) {
            supportedTokens[token] = true;
        }
        
        emit LimitsUpdated(token, minAmount, maxAmount, dailyLimit);
    }
    
    /**
     * @dev Add or remove supported token
     */
    function setSupportedToken(address token, bool supported) external onlyRole(ADMIN_ROLE) {
        supportedTokens[token] = supported;
    }
    
    /**
     * @dev Set user whitelist/blacklist status
     */
    function setUserStatus(
        address user,
        bool whitelisted,
        bool blacklisted
    ) external onlyRole(GUARDIAN_ROLE) {
        require(!(whitelisted && blacklisted), "DepositGuard: conflicting status");
        
        UserDeposits storage userInfo = userDeposits[user];
        userInfo.isWhitelisted = whitelisted;
        userInfo.isBlacklisted = blacklisted;
        
        emit UserStatusUpdated(user, whitelisted, blacklisted);
    }
    
    /**
     * @dev Batch set user statuses
     */
    function batchSetUserStatus(
        address[] calldata users,
        bool[] calldata whitelisted,
        bool[] calldata blacklisted
    ) external onlyRole(GUARDIAN_ROLE) {
        require(
            users.length == whitelisted.length && users.length == blacklisted.length,
            "DepositGuard: array length mismatch"
        );
        
        for (uint256 i = 0; i < users.length; i++) {
            require(
                !(whitelisted[i] && blacklisted[i]),
                "DepositGuard: conflicting status"
            );
            
            UserDeposits storage userInfo = userDeposits[users[i]];
            userInfo.isWhitelisted = whitelisted[i];
            userInfo.isBlacklisted = blacklisted[i];
            
            emit UserStatusUpdated(users[i], whitelisted[i], blacklisted[i]);
        }
    }
    
    /**
     * @dev Set authorized caller status
     */
    function setAuthorizedCaller(address caller, bool authorized) external onlyRole(ADMIN_ROLE) {
        authorizedCallers[caller] = authorized;
    }
    
    /**
     * @dev Toggle emergency mode
     */
    function setEmergencyMode(bool enabled) external onlyRole(GUARDIAN_ROLE) {
        emergencyMode = enabled;
        emit EmergencyModeToggled(enabled);
    }
    
    /**
     * @dev Set global limits
     */
    function setGlobalLimits(
        uint256 dailyLimit,
        uint256 totalLimit
    ) external onlyRole(ADMIN_ROLE) {
        globalDailyLimit = dailyLimit;
        globalTotalLimit = totalLimit;
    }
    
    /**
     * @dev Reset user deposit counters (emergency function)
     */
    function resetUserDeposits(address user) external onlyRole(GUARDIAN_ROLE) {
        UserDeposits storage userInfo = userDeposits[user];
        userInfo.totalDeposited = 0;
        userInfo.dailyDeposited = 0;
        userInfo.lastDepositDay = 0;
    }
    
    /**
     * @dev Get user deposit info
     */
    function getUserDepositInfo(address user) external view returns (
        uint256 totalDeposited,
        uint256 dailyDeposited,
        uint256 lastDepositDay,
        bool isWhitelisted,
        bool isBlacklisted
    ) {
        UserDeposits storage userInfo = userDeposits[user];
        return (
            userInfo.totalDeposited,
            userInfo.dailyDeposited,
            userInfo.lastDepositDay,
            userInfo.isWhitelisted,
            userInfo.isBlacklisted
        );
    }
    
    /**
     * @dev Get token limits
     */
    function getTokenLimits(address token) external view returns (DepositLimits memory) {
        return tokenLimits[token];
    }
    
    /**
     * @dev Check if deposit is valid without updating state
     */
    function isDepositValid(
        address user,
        address token,
        uint256 amount
    ) external view returns (bool, string memory) {
        if (!supportedTokens[token]) {
            return (false, "Token not supported");
        }
        
        if (userDeposits[user].isBlacklisted) {
            return (false, "User blacklisted");
        }
        
        if (emergencyMode && !userDeposits[user].isWhitelisted) {
            return (false, "Emergency mode - whitelist only");
        }
        
        DepositLimits storage limits = tokenLimits[token];
        if (!limits.isActive) {
            return (false, "Token deposits disabled");
        }
        
        if (amount < limits.minAmount) {
            return (false, "Below minimum amount");
        }
        
        if (amount > limits.maxAmount) {
            return (false, "Above maximum amount");
        }
        
        UserDeposits storage userInfo = userDeposits[user];
        uint256 currentDay = block.timestamp / 86400;
        uint256 dailyAmount = userInfo.lastDepositDay == currentDay ? userInfo.dailyDeposited : 0;
        
        if (dailyAmount + amount > limits.dailyLimit) {
            return (false, "Daily limit exceeded");
        }
        
        if (userInfo.totalDeposited + amount > limits.totalLimit) {
            return (false, "Total limit exceeded");
        }
        
        return (true, "Valid");
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
