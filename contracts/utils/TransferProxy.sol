// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title TransferProxy
 * @dev Proxy contract for handling token transfers with additional security and batching
 */
contract TransferProxy is AccessControl, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;
    
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    
    // Transfer limits and controls
    struct TransferLimits {
        uint256 maxAmount;
        uint256 dailyLimit;
        bool isActive;
    }
    
    // User transfer tracking
    struct UserTransfers {
        uint256 dailyTransferred;
        uint256 lastTransferDay;
        bool isWhitelisted;
        bool isBlacklisted;
    }
    
    mapping(address => TransferLimits) public tokenLimits;
    mapping(address => UserTransfers) public userTransfers;
    mapping(address => bool) public supportedTokens;
    mapping(address => bool) public authorizedCallers;
    
    // Global settings
    uint256 public globalTransferLimit;
    bool public emergencyMode = false;
    
    // Events
    event TransferExecuted(
        address indexed from,
        address indexed to,
        address indexed token,
        uint256 amount,
        uint256 timestamp
    );
    
    event BatchTransferExecuted(
        address indexed operator,
        uint256 transferCount,
        uint256 timestamp
    );
    
    event LimitsUpdated(
        address indexed token,
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
            authorizedCallers[msg.sender] || hasRole(OPERATOR_ROLE, msg.sender),
            "TransferProxy: not authorized"
        );
        _;
    }
    
    modifier notBlacklisted(address user) {
        require(!userTransfers[user].isBlacklisted, "TransferProxy: user blacklisted");
        _;
    }
    
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(OPERATOR_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
    }
    
    /**
     * @dev Execute a single token transfer
     */
    function transferToken(
        address from,
        address to,
        address token,
        uint256 amount
    ) external onlyAuthorized notBlacklisted(from) nonReentrant whenNotPaused {
        require(to != address(0), "TransferProxy: invalid recipient");
        require(amount > 0, "TransferProxy: invalid amount");
        require(supportedTokens[token], "TransferProxy: token not supported");
        
        _validateTransfer(from, token, amount);
        _updateTransferTracking(from, amount);
        
        IERC20(token).safeTransferFrom(from, to, amount);
        
        emit TransferExecuted(from, to, token, amount, block.timestamp);
    }
    
    /**
     * @dev Execute multiple token transfers in a batch
     */
    function batchTransfer(
        address[] calldata from,
        address[] calldata to,
        address[] calldata tokens,
        uint256[] calldata amounts
    ) external onlyAuthorized nonReentrant whenNotPaused {
        require(
            from.length == to.length &&
            from.length == tokens.length &&
            from.length == amounts.length,
            "TransferProxy: array length mismatch"
        );
        
        require(from.length > 0, "TransferProxy: empty arrays");
        require(from.length <= 100, "TransferProxy: batch too large");
        
        for (uint256 i = 0; i < from.length; i++) {
            require(to[i] != address(0), "TransferProxy: invalid recipient");
            require(amounts[i] > 0, "TransferProxy: invalid amount");
            require(supportedTokens[tokens[i]], "TransferProxy: token not supported");
            require(!userTransfers[from[i]].isBlacklisted, "TransferProxy: user blacklisted");
            
            _validateTransfer(from[i], tokens[i], amounts[i]);
            _updateTransferTracking(from[i], amounts[i]);
            
            IERC20(tokens[i]).safeTransferFrom(from[i], to[i], amounts[i]);
            
            emit TransferExecuted(from[i], to[i], tokens[i], amounts[i], block.timestamp);
        }
        
        emit BatchTransferExecuted(msg.sender, from.length, block.timestamp);
    }
    
    /**
     * @dev Transfer tokens from this contract to a recipient
     */
    function transferOut(
        address to,
        address token,
        uint256 amount
    ) external onlyRole(OPERATOR_ROLE) nonReentrant {
        require(to != address(0), "TransferProxy: invalid recipient");
        require(amount > 0, "TransferProxy: invalid amount");
        
        IERC20(token).safeTransfer(to, amount);
        
        emit TransferExecuted(address(this), to, token, amount, block.timestamp);
    }
    
    /**
     * @dev Validate transfer against limits and restrictions
     */
    function _validateTransfer(
        address from,
        address token,
        uint256 amount
    ) internal view {
        if (emergencyMode) {
            require(
                userTransfers[from].isWhitelisted,
                "TransferProxy: emergency mode - whitelist only"
            );
        }
        
        TransferLimits storage limits = tokenLimits[token];
        require(limits.isActive, "TransferProxy: token transfers disabled");
        
        // Check amount limits
        require(amount <= limits.maxAmount, "TransferProxy: above maximum");
        
        UserTransfers storage userInfo = userTransfers[from];
        uint256 currentDay = block.timestamp / 86400;
        
        // Check daily limits
        uint256 dailyAmount = userInfo.lastTransferDay == currentDay ? userInfo.dailyTransferred : 0;
        require(
            dailyAmount + amount <= limits.dailyLimit,
            "TransferProxy: daily limit exceeded"
        );
        
        // Check global limit
        if (globalTransferLimit > 0) {
            require(amount <= globalTransferLimit, "TransferProxy: global limit exceeded");
        }
    }
    
    /**
     * @dev Update user transfer tracking
     */
    function _updateTransferTracking(address user, uint256 amount) internal {
        UserTransfers storage userInfo = userTransfers[user];
        uint256 currentDay = block.timestamp / 86400;
        
        // Reset daily counter if new day
        if (userInfo.lastTransferDay < currentDay) {
            userInfo.dailyTransferred = 0;
            userInfo.lastTransferDay = currentDay;
        }
        
        userInfo.dailyTransferred += amount;
    }
    
    /**
     * @dev Set transfer limits for a token
     */
    function setTokenLimits(
        address token,
        uint256 maxAmount,
        uint256 dailyLimit,
        bool isActive
    ) external onlyRole(ADMIN_ROLE) {
        require(token != address(0), "TransferProxy: invalid token");
        
        tokenLimits[token] = TransferLimits({
            maxAmount: maxAmount,
            dailyLimit: dailyLimit,
            isActive: isActive
        });
        
        if (!supportedTokens[token]) {
            supportedTokens[token] = true;
        }
        
        emit LimitsUpdated(token, maxAmount, dailyLimit);
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
    ) external onlyRole(ADMIN_ROLE) {
        require(!(whitelisted && blacklisted), "TransferProxy: conflicting status");
        
        UserTransfers storage userInfo = userTransfers[user];
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
    ) external onlyRole(ADMIN_ROLE) {
        require(
            users.length == whitelisted.length && users.length == blacklisted.length,
            "TransferProxy: array length mismatch"
        );
        
        for (uint256 i = 0; i < users.length; i++) {
            require(
                !(whitelisted[i] && blacklisted[i]),
                "TransferProxy: conflicting status"
            );
            
            UserTransfers storage userInfo = userTransfers[users[i]];
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
    function setEmergencyMode(bool enabled) external onlyRole(ADMIN_ROLE) {
        emergencyMode = enabled;
        emit EmergencyModeToggled(enabled);
    }
    
    /**
     * @dev Set global transfer limit
     */
    function setGlobalTransferLimit(uint256 limit) external onlyRole(ADMIN_ROLE) {
        globalTransferLimit = limit;
    }
    
    /**
     * @dev Reset user transfer counters (emergency function)
     */
    function resetUserTransfers(address user) external onlyRole(ADMIN_ROLE) {
        UserTransfers storage userInfo = userTransfers[user];
        userInfo.dailyTransferred = 0;
        userInfo.lastTransferDay = 0;
    }
    
    /**
     * @dev Get user transfer info
     */
    function getUserTransferInfo(address user) external view returns (
        uint256 dailyTransferred,
        uint256 lastTransferDay,
        bool isWhitelisted,
        bool isBlacklisted
    ) {
        UserTransfers storage userInfo = userTransfers[user];
        return (
            userInfo.dailyTransferred,
            userInfo.lastTransferDay,
            userInfo.isWhitelisted,
            userInfo.isBlacklisted
        );
    }
    
    /**
     * @dev Get token limits
     */
    function getTokenLimits(address token) external view returns (TransferLimits memory) {
        return tokenLimits[token];
    }
    
    /**
     * @dev Check if transfer is valid without executing
     */
    function isTransferValid(
        address from,
        address token,
        uint256 amount
    ) external view returns (bool, string memory) {
        if (!supportedTokens[token]) {
            return (false, "Token not supported");
        }
        
        if (userTransfers[from].isBlacklisted) {
            return (false, "User blacklisted");
        }
        
        if (emergencyMode && !userTransfers[from].isWhitelisted) {
            return (false, "Emergency mode - whitelist only");
        }
        
        TransferLimits storage limits = tokenLimits[token];
        if (!limits.isActive) {
            return (false, "Token transfers disabled");
        }
        
        if (amount > limits.maxAmount) {
            return (false, "Above maximum amount");
        }
        
        UserTransfers storage userInfo = userTransfers[from];
        uint256 currentDay = block.timestamp / 86400;
        uint256 dailyAmount = userInfo.lastTransferDay == currentDay ? userInfo.dailyTransferred : 0;
        
        if (dailyAmount + amount > limits.dailyLimit) {
            return (false, "Daily limit exceeded");
        }
        
        if (globalTransferLimit > 0 && amount > globalTransferLimit) {
            return (false, "Global limit exceeded");
        }
        
        return (true, "Valid");
    }
    
    /**
     * @dev Emergency function to recover stuck tokens
     */
    function emergencyWithdraw(
        address token,
        uint256 amount,
        address to
    ) external onlyRole(ADMIN_ROLE) {
        IERC20(token).safeTransfer(to, amount);
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
