// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./UnifiedLiquidityPool.sol";

/**
 * @title CompoundEngine
 * @dev Automated compounding engine with configurable frequency and
 * optimized gas efficiency for maximum yield generation
 */
contract CompoundEngine is Ownable, ReentrancyGuard {
    using Math for uint256;

    // Compound configuration
    struct CompoundConfig {
        uint256 frequency;           // Compound frequency in seconds
        uint256 minThreshold;        // Minimum amount to trigger compound
        uint256 gasOptimization;     // Gas optimization level (0-100)
        uint256 batchSize;          // Maximum users per batch
        bool autoCompoundEnabled;   // Auto compound activation
    }

    // User compound settings
    struct UserCompoundSettings {
        bool autoCompoundEnabled;   // User's auto compound preference
        uint256 customFrequency;    // User's custom frequency (0 = use default)
        uint256 minCompoundAmount;  // User's minimum compound threshold
        uint256 lastCompoundTime;   // Last compound timestamp
        uint256 totalCompounded;    // Total amount compounded
    }

    // Yield source tracking
    struct YieldSource {
        string name;                // Source name (trading fees, arbitrage, etc.)
        uint256 totalYield;         // Total yield generated
        uint256 yieldRate;          // Current yield rate (per second)
        uint256 lastUpdate;         // Last update timestamp
        bool isActive;              // Source activation status
    }

    // Compound batch for gas optimization
    struct CompoundBatch {
        address[] users;            // Users in batch
        uint256[] amounts;          // Compound amounts
        uint256 totalGasCost;       // Estimated gas cost
        uint256 timestamp;          // Batch timestamp
    }

    // Constants
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant MAX_BATCH_SIZE = 50;
    uint256 public constant MIN_COMPOUND_AMOUNT = 1e18; // $1 minimum
    uint256 public constant GAS_OPTIMIZATION_THRESHOLD = 100000; // Gas units
    
    // State variables
    UnifiedLiquidityPool public immutable liquidityPool;
    CompoundConfig public compoundConfig;
    mapping(address => UserCompoundSettings) public userSettings;
    mapping(string => YieldSource) public yieldSources;
    string[] public yieldSourceNames;
    
    // Batching and optimization
    mapping(uint256 => CompoundBatch) public compoundBatches;
    uint256 public currentBatchId;
    address[] public pendingCompounds;
    
    // Performance tracking
    uint256 public totalCompoundsExecuted;
    uint256 public totalYieldCompounded;
    uint256 public averageGasUsed;
    
    // Events
    event CompoundExecuted(
        address indexed user,
        uint256 amount,
        uint256 newShares,
        string yieldSource
    );
    event BatchCompoundExecuted(
        uint256 indexed batchId,
        uint256 userCount,
        uint256 totalAmount,
        uint256 gasUsed
    );
    event YieldSourceAdded(string name, uint256 yieldRate);
    event UserSettingsUpdated(address indexed user, bool autoEnabled, uint256 frequency);
    event CompoundConfigUpdated(uint256 frequency, uint256 minThreshold);

    constructor(address _liquidityPool, address initialOwner) Ownable(initialOwner) {
        liquidityPool = UnifiedLiquidityPool(_liquidityPool);
        
        // Initialize default compound configuration
        compoundConfig = CompoundConfig({
            frequency: 1 hours,
            minThreshold: MIN_COMPOUND_AMOUNT,
            gasOptimization: 80, // 80% optimization level
            batchSize: 25,
            autoCompoundEnabled: true
        });
        
        _initializeYieldSources();
    }

    /**
     * @dev Initialize default yield sources
     */
    function _initializeYieldSources() internal {
        _addYieldSource("trading_fees", 2740000000000); // ~8.65% APR
        _addYieldSource("arbitrage_profits", 1370000000000); // ~4.32% APR
        _addYieldSource("liquidation_fees", 685000000000); // ~2.16% APR
        _addYieldSource("yield_farming", 4110000000000); // ~12.96% APR
    }

    /**
     * @dev Add a new yield source
     */
    function _addYieldSource(string memory name, uint256 yieldRate) internal {
        yieldSources[name] = YieldSource({
            name: name,
            totalYield: 0,
            yieldRate: yieldRate,
            lastUpdate: block.timestamp,
            isActive: true
        });
        yieldSourceNames.push(name);
        
        emit YieldSourceAdded(name, yieldRate);
    }

    /**
     * @dev Set user compound preferences
     */
    function setUserCompoundSettings(
        bool autoCompoundEnabled,
        uint256 customFrequency,
        uint256 minCompoundAmount
    ) external {
        require(customFrequency == 0 || customFrequency >= 1 hours, "Invalid frequency");
        require(minCompoundAmount >= MIN_COMPOUND_AMOUNT, "Amount too low");
        
        userSettings[msg.sender] = UserCompoundSettings({
            autoCompoundEnabled: autoCompoundEnabled,
            customFrequency: customFrequency,
            minCompoundAmount: minCompoundAmount,
            lastCompoundTime: userSettings[msg.sender].lastCompoundTime,
            totalCompounded: userSettings[msg.sender].totalCompounded
        });
        
        emit UserSettingsUpdated(msg.sender, autoCompoundEnabled, customFrequency);
    }

    /**
     * @dev Manual compound for a specific user
     */
    function compoundUser(address user) external nonReentrant {
        require(user != address(0), "Invalid user address");
        
        uint256 compoundAmount = _calculateCompoundAmount(user);
        require(compoundAmount >= userSettings[user].minCompoundAmount, "Below minimum threshold");
        
        _executeCompound(user, compoundAmount);
    }

    /**
     * @dev Batch compound for multiple users (gas optimization)
     */
    function batchCompound(address[] calldata users) external nonReentrant {
        require(users.length <= compoundConfig.batchSize, "Batch too large");
        
        uint256 gasStart = gasleft();
        uint256 totalAmount = 0;
        uint256 validUsers = 0;
        
        for (uint256 i = 0; i < users.length; i++) {
            uint256 compoundAmount = _calculateCompoundAmount(users[i]);
            
            if (compoundAmount >= userSettings[users[i]].minCompoundAmount) {
                _executeCompound(users[i], compoundAmount);
                totalAmount += compoundAmount;
                validUsers++;
            }
        }
        
        uint256 gasUsed = gasStart - gasleft();
        _updateGasMetrics(gasUsed);
        
        emit BatchCompoundExecuted(currentBatchId++, validUsers, totalAmount, gasUsed);
    }

    /**
     * @dev Automated compound execution (called by keeper/bot)
     */
    function autoCompound() external {
        require(compoundConfig.autoCompoundEnabled, "Auto compound disabled");
        
        address[] memory eligibleUsers = _getEligibleUsers();
        
        if (eligibleUsers.length == 0) return;
        
        // Process in batches for gas optimization
        uint256 batchSize = compoundConfig.batchSize;
        for (uint256 i = 0; i < eligibleUsers.length; i += batchSize) {
            uint256 endIndex = Math.min(i + batchSize, eligibleUsers.length);
            address[] memory batch = new address[](endIndex - i);
            
            for (uint256 j = i; j < endIndex; j++) {
                batch[j - i] = eligibleUsers[j];
            }
            
            _processBatch(batch);
        }
    }

    /**
     * @dev Calculate compound amount for a user based on yield sources
     */
    function _calculateCompoundAmount(address user) internal view returns (uint256) {
        // Get user's position in the liquidity pool
        (uint256 currentValue, , , , ) = liquidityPool.getUserPositionInfo(user);
        
        if (currentValue == 0) return 0;
        
        UserCompoundSettings memory settings = userSettings[user];
        uint256 lastCompound = settings.lastCompoundTime;
        
        if (lastCompound == 0) {
            lastCompound = block.timestamp - _getCompoundFrequency(user);
        }
        
        uint256 timeElapsed = block.timestamp - lastCompound;
        uint256 totalYield = 0;
        
        // Calculate yield from all active sources
        for (uint256 i = 0; i < yieldSourceNames.length; i++) {
            YieldSource memory source = yieldSources[yieldSourceNames[i]];
            if (source.isActive) {
                uint256 sourceYield = _calculateSourceYield(user, source, timeElapsed);
                totalYield += sourceYield;
            }
        }
        
        return totalYield;
    }

    /**
     * @dev Calculate yield from a specific source
     */
    function _calculateSourceYield(
        address user,
        YieldSource memory source,
        uint256 timeElapsed
    ) internal view returns (uint256) {
        (uint256 userValue, , , , ) = liquidityPool.getUserPositionInfo(user);
        
        // Calculate user's share of total pool
        uint256 totalPoolValue = _getTotalPoolValue();
        if (totalPoolValue == 0) return 0;
        
        uint256 userShare = (userValue * BASIS_POINTS) / totalPoolValue;
        
        // Calculate yield based on time elapsed and yield rate
        uint256 annualYield = (userValue * source.yieldRate) / BASIS_POINTS;
        uint256 timeBasedYield = (annualYield * timeElapsed) / 365 days;
        
        return timeBasedYield;
    }

    /**
     * @dev Execute compound for a user
     */
    function _executeCompound(address user, uint256 amount) internal {
        require(amount > 0, "No yield to compound");
        
        // Update user's last compound time
        userSettings[user].lastCompoundTime = block.timestamp;
        userSettings[user].totalCompounded += amount;
        
        // Execute compound through liquidity pool
        liquidityPool.compoundRewards(user);
        
        // Update global metrics
        totalCompoundsExecuted++;
        totalYieldCompounded += amount;
        
        emit CompoundExecuted(user, amount, 0, "auto_compound");
    }

    /**
     * @dev Get users eligible for auto compound
     */
    function _getEligibleUsers() internal pure returns (address[] memory) {
        // This would typically query the liquidity pool for all users
        // For demo purposes, return empty array
        address[] memory eligible = new address[](0);
        return eligible;
    }

    /**
     * @dev Process a batch of compounds
     */
    function _processBatch(address[] memory users) internal {
        uint256 gasStart = gasleft();
        uint256 totalAmount = 0;
        
        for (uint256 i = 0; i < users.length; i++) {
            uint256 compoundAmount = _calculateCompoundAmount(users[i]);
            
            if (compoundAmount >= userSettings[users[i]].minCompoundAmount) {
                _executeCompound(users[i], compoundAmount);
                totalAmount += compoundAmount;
            }
        }
        
        uint256 gasUsed = gasStart - gasleft();
        _updateGasMetrics(gasUsed);
        
        emit BatchCompoundExecuted(currentBatchId++, users.length, totalAmount, gasUsed);
    }

    /**
     * @dev Update gas usage metrics for optimization
     */
    function _updateGasMetrics(uint256 gasUsed) internal {
        if (totalCompoundsExecuted == 0) {
            averageGasUsed = gasUsed;
        } else {
            averageGasUsed = (averageGasUsed + gasUsed) / 2;
        }
    }

    /**
     * @dev Get compound frequency for a user
     */
    function _getCompoundFrequency(address user) internal view returns (uint256) {
        uint256 customFreq = userSettings[user].customFrequency;
        return customFreq > 0 ? customFreq : compoundConfig.frequency;
    }

    /**
     * @dev Get total pool value from liquidity pool
     */
    function _getTotalPoolValue() internal pure returns (uint256) {
        // This would integrate with the liquidity pool
        return 1000000e18; // $1M for demo
    }

    /**
     * @dev Execute automated compounding (alias for autoCompound)
     */
    function executeAutomatedCompounding() external {
        require(compoundConfig.autoCompoundEnabled, "Auto compound disabled");
        
        address[] memory eligibleUsers = _getEligibleUsers();
        
        if (eligibleUsers.length == 0) return;
        
        // Process in batches for gas optimization
        uint256 batchSize = compoundConfig.batchSize;
        for (uint256 i = 0; i < eligibleUsers.length; i += batchSize) {
            uint256 endIndex = Math.min(i + batchSize, eligibleUsers.length);
            address[] memory batch = new address[](endIndex - i);
            
            for (uint256 j = i; j < endIndex; j++) {
                batch[j - i] = eligibleUsers[j];
            }
            
            _processBatch(batch);
        }
    }

    // View functions
    function getUserCompoundInfo(address user) external view returns (
        uint256 pendingCompound,
        uint256 nextCompoundTime,
        uint256 totalCompounded,
        bool autoEnabled
    ) {
        UserCompoundSettings memory settings = userSettings[user];
        
        pendingCompound = _calculateCompoundAmount(user);
        nextCompoundTime = settings.lastCompoundTime + _getCompoundFrequency(user);
        totalCompounded = settings.totalCompounded;
        autoEnabled = settings.autoCompoundEnabled;
    }

    function getYieldSourceInfo(string calldata sourceName) external view returns (
        uint256 totalYield,
        uint256 yieldRate,
        uint256 lastUpdate,
        bool isActive
    ) {
        YieldSource memory source = yieldSources[sourceName];
        return (source.totalYield, source.yieldRate, source.lastUpdate, source.isActive);
    }

    function getCompoundMetrics() external view returns (
        uint256 totalCompounds,
        uint256 totalYield,
        uint256 avgGas,
        uint256 activeUsers
    ) {
        return (
            totalCompoundsExecuted,
            totalYieldCompounded,
            averageGasUsed,
            pendingCompounds.length
        );
    }

    function simulateCompound(address user) external view returns (
        uint256 currentAmount,
        uint256 projectedDaily,
        uint256 projectedWeekly,
        uint256 projectedMonthly
    ) {
        currentAmount = _calculateCompoundAmount(user);
        
        // Project future compounds based on current yield rates
        uint256 dailyYield = _calculateCompoundAmount(user) * 24; // Hourly * 24
        projectedDaily = dailyYield;
        projectedWeekly = dailyYield * 7;
        projectedMonthly = dailyYield * 30;
    }

    // Admin functions
    function updateCompoundConfig(
        uint256 frequency,
        uint256 minThreshold,
        uint256 gasOptimization,
        uint256 batchSize,
        bool autoEnabled
    ) external onlyOwner {
        require(frequency >= 1 hours, "Frequency too low");
        require(batchSize <= MAX_BATCH_SIZE, "Batch size too large");
        require(gasOptimization <= 100, "Invalid optimization level");
        
        compoundConfig = CompoundConfig({
            frequency: frequency,
            minThreshold: minThreshold,
            gasOptimization: gasOptimization,
            batchSize: batchSize,
            autoCompoundEnabled: autoEnabled
        });
        
        emit CompoundConfigUpdated(frequency, minThreshold);
    }

    function updateYieldSource(
        string calldata name,
        uint256 yieldRate,
        bool isActive
    ) external onlyOwner {
        require(bytes(yieldSources[name].name).length > 0, "Source not found");
        
        yieldSources[name].yieldRate = yieldRate;
        yieldSources[name].isActive = isActive;
        yieldSources[name].lastUpdate = block.timestamp;
    }

    function addYieldSource(
        string calldata name,
        uint256 yieldRate
    ) external onlyOwner {
        require(bytes(yieldSources[name].name).length == 0, "Source already exists");
        _addYieldSource(name, yieldRate);
    }
}
