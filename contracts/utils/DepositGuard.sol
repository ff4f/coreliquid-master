// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title DepositGuard
 * @dev Security guard for deposits with anti-MEV and flash loan protection
 */
contract DepositGuard is Ownable, ReentrancyGuard, Pausable {
    
    struct UserActivity {
        uint256 lastDepositBlock;
        uint256 lastWithdrawBlock;
        uint256 depositCount;
        uint256 withdrawCount;
        uint256 totalDeposited;
        uint256 totalWithdrawn;
        bool isBlacklisted;
    }

    struct SecurityConfig {
        uint256 minBlockDelay;
        uint256 maxDailyDeposits;
        uint256 maxDailyWithdrawals;
        uint256 maxDepositAmount;
        uint256 maxWithdrawAmount;
        uint256 suspiciousThreshold;
        bool flashLoanProtection;
        bool mevProtection;
    }

    mapping(address => UserActivity) public userActivity;
    mapping(address => mapping(uint256 => uint256)) public dailyDeposits; // user => day => amount
    mapping(address => mapping(uint256 => uint256)) public dailyWithdrawals; // user => day => amount
    mapping(address => bool) public authorizedContracts;
    mapping(bytes32 => bool) public suspiciousTransactions;
    
    SecurityConfig public securityConfig;
    
    uint256 public constant SECONDS_PER_DAY = 86400;
    uint256 public constant MAX_GAS_PRICE = 100 gwei;
    
    address public securityManager;
    bool public emergencyMode;

    event SecurityViolation(
        address indexed user,
        string violationType,
        uint256 blockNumber,
        uint256 timestamp
    );

    event UserBlacklisted(address indexed user, string reason);
    event UserWhitelisted(address indexed user);
    event SecurityConfigUpdated();
    event EmergencyModeToggled(bool enabled);
    event SuspiciousActivity(address indexed user, bytes32 txHash, string reason);

    modifier onlySecurityManager() {
        require(msg.sender == securityManager || msg.sender == owner(), "Not authorized");
        _;
    }

    modifier notBlacklisted(address user) {
        require(!userActivity[user].isBlacklisted, "User blacklisted");
        _;
    }

    modifier flashLoanProtection() {
        if (securityConfig.flashLoanProtection) {
            require(
                userActivity[msg.sender].lastDepositBlock != block.number &&
                userActivity[msg.sender].lastWithdrawBlock != block.number,
                "Flash loan detected"
            );
        }
        _;
    }

    modifier mevProtection() {
        if (securityConfig.mevProtection) {
            require(tx.gasprice <= MAX_GAS_PRICE, "Gas price too high");
            require(
                block.number > userActivity[msg.sender].lastDepositBlock + securityConfig.minBlockDelay,
                "MEV protection active"
            );
        }
        _;
    }

    constructor(address _securityManager) Ownable(msg.sender) {
        require(_securityManager != address(0), "Invalid security manager");
        securityManager = _securityManager;
        
        // Initialize default security config
        securityConfig = SecurityConfig({
            minBlockDelay: 1, // 1 block delay
            maxDailyDeposits: 10,
            maxDailyWithdrawals: 5,
            maxDepositAmount: 1000000 * 1e18, // 1M tokens
            maxWithdrawAmount: 500000 * 1e18, // 500K tokens
            suspiciousThreshold: 100000 * 1e18, // 100K tokens
            flashLoanProtection: true,
            mevProtection: true
        });
    }

    /**
     * @dev Check if deposit is allowed
     * @param user User address
     * @param amount Deposit amount
     * @return allowed True if deposit is allowed
     * @return reason Reason if not allowed
     */
    function checkDepositAllowed(
        address user,
        uint256 amount
    ) external view returns (bool allowed, string memory reason) {
        if (emergencyMode) {
            return (false, "Emergency mode active");
        }
        
        if (userActivity[user].isBlacklisted) {
            return (false, "User blacklisted");
        }
        
        if (amount > securityConfig.maxDepositAmount) {
            return (false, "Amount exceeds maximum");
        }
        
        uint256 today = block.timestamp / SECONDS_PER_DAY;
        if (dailyDeposits[user][today] + amount > securityConfig.maxDepositAmount) {
            return (false, "Daily deposit limit exceeded");
        }
        
        if (userActivity[user].depositCount >= securityConfig.maxDailyDeposits) {
            uint256 lastDepositDay = userActivity[user].lastDepositBlock / (SECONDS_PER_DAY / 12); // Approximate
            uint256 currentDay = block.number / (SECONDS_PER_DAY / 12);
            if (lastDepositDay == currentDay) {
                return (false, "Daily deposit count exceeded");
            }
        }
        
        if (securityConfig.mevProtection) {
            if (tx.gasprice > MAX_GAS_PRICE) {
                return (false, "Gas price too high");
            }
            
            if (block.number <= userActivity[user].lastDepositBlock + securityConfig.minBlockDelay) {
                return (false, "MEV protection active");
            }
        }
        
        return (true, "");
    }

    /**
     * @dev Check if withdrawal is allowed
     * @param user User address
     * @param amount Withdrawal amount
     * @return allowed True if withdrawal is allowed
     * @return reason Reason if not allowed
     */
    function checkWithdrawAllowed(
        address user,
        uint256 amount
    ) external view returns (bool allowed, string memory reason) {
        if (emergencyMode) {
            return (false, "Emergency mode active");
        }
        
        if (userActivity[user].isBlacklisted) {
            return (false, "User blacklisted");
        }
        
        if (amount > securityConfig.maxWithdrawAmount) {
            return (false, "Amount exceeds maximum");
        }
        
        uint256 today = block.timestamp / SECONDS_PER_DAY;
        if (dailyWithdrawals[user][today] + amount > securityConfig.maxWithdrawAmount) {
            return (false, "Daily withdrawal limit exceeded");
        }
        
        if (securityConfig.flashLoanProtection) {
            if (userActivity[user].lastDepositBlock == block.number) {
                return (false, "Flash loan protection active");
            }
        }
        
        return (true, "");
    }

    /**
     * @dev Record deposit activity
     * @param user User address
     * @param amount Deposit amount
     */
    function recordDeposit(
        address user,
        uint256 amount
    ) external nonReentrant notBlacklisted(user) flashLoanProtection mevProtection {
        require(authorizedContracts[msg.sender], "Not authorized contract");
        require(!emergencyMode, "Emergency mode active");
        
        UserActivity storage activity = userActivity[user];
        uint256 today = block.timestamp / SECONDS_PER_DAY;
        
        // Update user activity
        activity.lastDepositBlock = block.number;
        activity.depositCount++;
        activity.totalDeposited += amount;
        
        // Update daily deposits
        dailyDeposits[user][today] += amount;
        
        // Check for suspicious activity
        if (amount >= securityConfig.suspiciousThreshold) {
            bytes32 txHash = keccak256(abi.encodePacked(block.number, user, amount));
            suspiciousTransactions[txHash] = true;
            emit SuspiciousActivity(user, txHash, "Large deposit amount");
        }
        
        // Check for rapid deposits
        if (activity.depositCount > securityConfig.maxDailyDeposits) {
            emit SecurityViolation(user, "Excessive deposits", block.number, block.timestamp);
        }
    }

    /**
     * @dev Record withdrawal activity
     * @param user User address
     * @param amount Withdrawal amount
     */
    function recordWithdraw(
        address user,
        uint256 amount
    ) external nonReentrant notBlacklisted(user) {
        require(authorizedContracts[msg.sender], "Not authorized contract");
        require(!emergencyMode, "Emergency mode active");
        
        UserActivity storage activity = userActivity[user];
        uint256 today = block.timestamp / SECONDS_PER_DAY;
        
        // Update user activity
        activity.lastWithdrawBlock = block.number;
        activity.withdrawCount++;
        activity.totalWithdrawn += amount;
        
        // Update daily withdrawals
        dailyWithdrawals[user][today] += amount;
        
        // Check for suspicious activity
        if (amount >= securityConfig.suspiciousThreshold) {
            bytes32 txHash = keccak256(abi.encodePacked(block.number, user, amount));
            suspiciousTransactions[txHash] = true;
            emit SuspiciousActivity(user, txHash, "Large withdrawal amount");
        }
        
        // Check for rapid withdrawals
        if (activity.withdrawCount > securityConfig.maxDailyWithdrawals) {
            emit SecurityViolation(user, "Excessive withdrawals", block.number, block.timestamp);
        }
    }

    /**
     * @dev Blacklist a user
     * @param user User to blacklist
     * @param reason Reason for blacklisting
     */
    function blacklistUser(address user, string calldata reason) external onlySecurityManager {
        userActivity[user].isBlacklisted = true;
        emit UserBlacklisted(user, reason);
    }

    /**
     * @dev Whitelist a user (remove from blacklist)
     * @param user User to whitelist
     */
    function whitelistUser(address user) external onlySecurityManager {
        userActivity[user].isBlacklisted = false;
        emit UserWhitelisted(user);
    }

    /**
     * @dev Authorize a contract to use this guard
     * @param contractAddr Contract address
     * @param authorized Authorization status
     */
    function setAuthorizedContract(address contractAddr, bool authorized) external onlyOwner {
        authorizedContracts[contractAddr] = authorized;
    }

    /**
     * @dev Update security configuration
     * @param config New security configuration
     */
    function updateSecurityConfig(SecurityConfig calldata config) external onlySecurityManager {
        require(config.minBlockDelay <= 100, "Block delay too high");
        require(config.maxDailyDeposits <= 1000, "Daily deposits too high");
        require(config.maxDailyWithdrawals <= 1000, "Daily withdrawals too high");
        
        securityConfig = config;
        emit SecurityConfigUpdated();
    }

    /**
     * @dev Toggle emergency mode
     * @param enabled Emergency mode status
     */
    function setEmergencyMode(bool enabled) external onlySecurityManager {
        emergencyMode = enabled;
        emit EmergencyModeToggled(enabled);
    }

    /**
     * @dev Update security manager
     * @param newManager New security manager address
     */
    function updateSecurityManager(address newManager) external onlyOwner {
        require(newManager != address(0), "Invalid manager");
        securityManager = newManager;
    }

    /**
     * @dev Get user activity info
     * @param user User address
     * @return activity User activity data
     */
    function getUserActivity(address user) external view returns (UserActivity memory activity) {
        return userActivity[user];
    }

    /**
     * @dev Get daily deposit amount
     * @param user User address
     * @param day Day timestamp
     * @return amount Daily deposit amount
     */
    function getDailyDeposits(address user, uint256 day) external view returns (uint256 amount) {
        return dailyDeposits[user][day];
    }

    /**
     * @dev Get daily withdrawal amount
     * @param user User address
     * @param day Day timestamp
     * @return amount Daily withdrawal amount
     */
    function getDailyWithdrawals(address user, uint256 day) external view returns (uint256 amount) {
        return dailyWithdrawals[user][day];
    }

    /**
     * @dev Check if transaction is suspicious
     * @param txHash Transaction hash
     * @return suspicious True if suspicious
     */
    function isSuspiciousTransaction(bytes32 txHash) external view returns (bool suspicious) {
        return suspiciousTransactions[txHash];
    }

    /**
     * @dev Pause contract
     */
    function pause() external onlySecurityManager {
        _pause();
    }

    /**
     * @dev Unpause contract
     */
    function unpause() external onlySecurityManager {
        _unpause();
    }
}