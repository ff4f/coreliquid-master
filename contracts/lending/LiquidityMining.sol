// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "../interfaces/ILiquidityMining.sol";
import "../interfaces/IOracle.sol";

/**
 * @title LiquidityMining
 * @dev Comprehensive liquidity mining and rewards system for CoreLiquid Protocol
 * @author CoreLiquid Protocol
 */
contract LiquidityMining is ILiquidityMining, AccessControl, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;
    using Math for uint256;

    // Roles
    bytes32 public constant MINING_MANAGER_ROLE = keccak256("MINING_MANAGER_ROLE");
    bytes32 public constant POOL_MANAGER_ROLE = keccak256("POOL_MANAGER_ROLE");
    bytes32 public constant REWARD_MANAGER_ROLE = keccak256("REWARD_MANAGER_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
    bytes32 public constant KEEPER_ROLE = keccak256("KEEPER_ROLE");

    // Constants
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant PRECISION = 1e18;
    uint256 public constant MAX_POOLS = 100;
    uint256 public constant MAX_REWARD_TOKENS = 10;
    uint256 public constant MIN_LOCK_DURATION = 1 days;
    uint256 public constant MAX_LOCK_DURATION = 365 days;
    uint256 public constant BOOST_MULTIPLIER_CAP = 500; // 5x

    // External contracts
    IOracle public immutable oracle;

    // Storage mappings
    mapping(uint256 => MiningPool) public miningPools;
    mapping(address => UserStake) public userStakes;
    mapping(uint256 => RewardToken) public rewardTokens;
    mapping(address => UserRewards) public userRewards;
    mapping(uint256 => PoolMetrics) public poolMetrics;
    mapping(address => StakingHistory[]) public stakingHistory;
    mapping(uint256 => EmissionSchedule) public emissionSchedules;
    mapping(address => BoostConfig) public boostConfigs;
    mapping(uint256 => LockConfig) public lockConfigs;
    mapping(address => VestingSchedule) public vestingSchedules;
    mapping(address => uint256[]) public userPools;
    mapping(uint256 => address[]) public poolStakers;
    mapping(address => mapping(uint256 => uint256)) public userPoolStakes;
    mapping(uint256 => mapping(address => uint256)) public poolRewardDebts;
    
    // Global arrays
    uint256[] public allPools;
    address[] public allStakers;
    uint256[] public activeRewardTokens;
    uint256[] public activeLockConfigs;
    
    // Mining configuration
    MiningConfig public config;
    
    // Counters
    uint256 public totalPools;
    uint256 public totalStakers;
    uint256 public totalRewardTokens;
    uint256 public totalEmissionSchedules;
    uint256 public totalLockConfigs;

    // State variables
    bool public emergencyMode;
    uint256 public lastGlobalUpdate;
    mapping(uint256 => uint256) public lastPoolUpdate;
    mapping(uint256 => bool) public isPoolActive;
    mapping(address => bool) public isStakerActive;

    constructor(
        address _oracle,
        uint256 _baseRewardRate,
        uint256 _maxBoostMultiplier
    ) {
        require(_oracle != address(0), "Invalid oracle");
        require(_baseRewardRate > 0, "Invalid base reward rate");
        require(_maxBoostMultiplier <= BOOST_MULTIPLIER_CAP, "Boost multiplier too high");
        
        oracle = IOracle(_oracle);
        
        config = MiningConfig({
            baseRewardRate: _baseRewardRate,
            maxBoostMultiplier: _maxBoostMultiplier,
            minStakeAmount: 1e18, // 1 token
            maxStakeAmount: 1000000e18, // 1M tokens
            emergencyWithdrawFee: 1000, // 10%
            performanceFee: 200, // 2%
            lockBonusMultiplier: 150, // 1.5x
            vestingDuration: 30 days,
            isActive: true
        });
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINING_MANAGER_ROLE, msg.sender);
        _grantRole(POOL_MANAGER_ROLE, msg.sender);
        _grantRole(REWARD_MANAGER_ROLE, msg.sender);
        _grantRole(EMERGENCY_ROLE, msg.sender);
        _grantRole(KEEPER_ROLE, msg.sender);
    }

    // Core mining functions
    function createPool(
        address stakingToken,
        address rewardToken,
        uint256 rewardRate,
        uint256 startTime,
        uint256 endTime,
        uint256 maxStakers
    ) external override onlyRole(POOL_MANAGER_ROLE) returns (uint256) {
        require(stakingToken != address(0), "Invalid staking token");
        require(rewardToken != address(0), "Invalid reward token");
        require(rewardRate > 0, "Invalid reward rate");
        require(startTime >= block.timestamp, "Invalid start time");
        require(endTime > startTime, "Invalid end time");
        require(totalPools < MAX_POOLS, "Too many pools");
        
        uint256 poolId = totalPools;
        
        MiningPool storage pool = miningPools[poolId];
        pool.poolId = poolId;
        pool.stakingToken = stakingToken;
        pool.rewardToken = rewardToken;
        pool.rewardRate = rewardRate;
        pool.startTime = startTime;
        pool.endTime = endTime;
        pool.maxStakers = maxStakers;
        pool.createdAt = block.timestamp;
        pool.createdBy = msg.sender;
        pool.isActive = true;
        
        // Initialize pool metrics
        PoolMetrics storage metrics = poolMetrics[poolId];
        metrics.poolId = poolId;
        metrics.lastUpdate = block.timestamp;
        
        allPools.push(poolId);
        isPoolActive[poolId] = true;
        totalPools++;
        
        emit PoolCreated(poolId, stakingToken, rewardToken, rewardRate, startTime, endTime, block.timestamp);
        
        return poolId;
    }

    function stake(
        uint256 poolId,
        uint256 amount,
        uint256 lockDuration
    ) external override nonReentrant whenNotPaused {
        require(isPoolActive[poolId], "Pool not active");
        require(amount >= config.minStakeAmount, "Amount too small");
        require(amount <= config.maxStakeAmount, "Amount too large");
        require(lockDuration >= MIN_LOCK_DURATION || lockDuration == 0, "Lock duration too short");
        require(lockDuration <= MAX_LOCK_DURATION, "Lock duration too long");
        
        MiningPool storage pool = miningPools[poolId];
        require(pool.isActive, "Pool inactive");
        require(block.timestamp >= pool.startTime, "Pool not started");
        require(block.timestamp < pool.endTime, "Pool ended");
        require(poolStakers[poolId].length < pool.maxStakers, "Pool full");
        
        // Update pool rewards before staking
        _updatePool(poolId);
        
        // Transfer staking tokens
        IERC20(pool.stakingToken).safeTransferFrom(msg.sender, address(this), amount);
        
        // Update user stake
        UserStake storage userStake = userStakes[msg.sender];
        if (userStake.user == address(0)) {
            userStake.user = msg.sender;
            allStakers.push(msg.sender);
            isStakerActive[msg.sender] = true;
            totalStakers++;
        }
        
        // Add to user's pools if not already there
        bool poolExists = false;
        for (uint256 i = 0; i < userPools[msg.sender].length; i++) {
            if (userPools[msg.sender][i] == poolId) {
                poolExists = true;
                break;
            }
        }
        if (!poolExists) {
            userPools[msg.sender].push(poolId);
            poolStakers[poolId].push(msg.sender);
        }
        
        // Calculate lock bonus
        uint256 lockBonus = lockDuration > 0 ? 
            (lockDuration * config.lockBonusMultiplier) / MAX_LOCK_DURATION : 0;
        
        // Update stake amounts
        userPoolStakes[msg.sender][poolId] += amount;
        userStake.totalStaked += amount;
        userStake.lastStakeTime = block.timestamp;
        
        // Set lock if specified
        if (lockDuration > 0) {
            userStake.lockEndTime = block.timestamp + lockDuration;
            userStake.lockBonus = lockBonus;
        }
        
        // Update pool metrics
        PoolMetrics storage metrics = poolMetrics[poolId];
        metrics.totalStaked += amount;
        metrics.totalStakers = poolStakers[poolId].length;
        metrics.lastUpdate = block.timestamp;
        
        // Add to staking history
        StakingHistory memory historyEntry = StakingHistory({
            poolId: poolId,
            amount: amount,
            timestamp: block.timestamp,
            action: StakingAction.STAKE,
            lockDuration: lockDuration
        });
        stakingHistory[msg.sender].push(historyEntry);
        
        emit Staked(msg.sender, poolId, amount, lockDuration, block.timestamp);
    }

    function unstake(
        uint256 poolId,
        uint256 amount
    ) external override nonReentrant {
        require(isPoolActive[poolId], "Pool not active");
        require(amount > 0, "Invalid amount");
        require(userPoolStakes[msg.sender][poolId] >= amount, "Insufficient stake");
        
        UserStake storage userStake = userStakes[msg.sender];
        require(userStake.lockEndTime <= block.timestamp, "Stake still locked");
        
        // Update pool rewards before unstaking
        _updatePool(poolId);
        
        // Claim pending rewards
        _claimRewards(msg.sender, poolId);
        
        MiningPool storage pool = miningPools[poolId];
        
        // Update stake amounts
        userPoolStakes[msg.sender][poolId] -= amount;
        userStake.totalStaked -= amount;
        
        // Update pool metrics
        PoolMetrics storage metrics = poolMetrics[poolId];
        metrics.totalStaked -= amount;
        metrics.lastUpdate = block.timestamp;
        
        // Transfer staking tokens back
        IERC20(pool.stakingToken).safeTransfer(msg.sender, amount);
        
        // Add to staking history
        StakingHistory memory historyEntry = StakingHistory({
            poolId: poolId,
            amount: amount,
            timestamp: block.timestamp,
            action: StakingAction.UNSTAKE,
            lockDuration: 0
        });
        stakingHistory[msg.sender].push(historyEntry);
        
        emit Unstaked(msg.sender, poolId, amount, block.timestamp);
    }

    function claimRewards(
        uint256 poolId
    ) external override nonReentrant {
        require(isPoolActive[poolId], "Pool not active");
        require(userPoolStakes[msg.sender][poolId] > 0, "No stake in pool");
        
        // Update pool rewards
        _updatePool(poolId);
        
        // Claim rewards
        uint256 rewards = _claimRewards(msg.sender, poolId);
        require(rewards > 0, "No rewards to claim");
        
        emit RewardsClaimed(msg.sender, poolId, rewards, block.timestamp);
    }

    function claimAllRewards() external override nonReentrant {
        uint256[] memory pools = userPools[msg.sender];
        require(pools.length > 0, "No pools to claim from");
        
        uint256 totalRewards = 0;
        
        for (uint256 i = 0; i < pools.length; i++) {
            uint256 poolId = pools[i];
            if (isPoolActive[poolId] && userPoolStakes[msg.sender][poolId] > 0) {
                _updatePool(poolId);
                uint256 rewards = _claimRewards(msg.sender, poolId);
                totalRewards += rewards;
            }
        }
        
        require(totalRewards > 0, "No rewards to claim");
        
        emit AllRewardsClaimed(msg.sender, totalRewards, block.timestamp);
    }

    function emergencyWithdraw(
        uint256 poolId
    ) external override nonReentrant {
        require(userPoolStakes[msg.sender][poolId] > 0, "No stake in pool");
        
        uint256 amount = userPoolStakes[msg.sender][poolId];
        MiningPool storage pool = miningPools[poolId];
        
        // Calculate emergency fee
        uint256 fee = (amount * config.emergencyWithdrawFee) / BASIS_POINTS;
        uint256 withdrawAmount = amount - fee;
        
        // Update stake amounts
        userPoolStakes[msg.sender][poolId] = 0;
        userStakes[msg.sender].totalStaked -= amount;
        
        // Update pool metrics
        PoolMetrics storage metrics = poolMetrics[poolId];
        metrics.totalStaked -= amount;
        metrics.emergencyWithdrawals += amount;
        metrics.lastUpdate = block.timestamp;
        
        // Transfer tokens (minus fee)
        IERC20(pool.stakingToken).safeTransfer(msg.sender, withdrawAmount);
        
        // Add to staking history
        StakingHistory memory historyEntry = StakingHistory({
            poolId: poolId,
            amount: amount,
            timestamp: block.timestamp,
            action: StakingAction.EMERGENCY_WITHDRAW,
            lockDuration: 0
        });
        stakingHistory[msg.sender].push(historyEntry);
        
        emit EmergencyWithdraw(msg.sender, poolId, amount, fee, block.timestamp);
    }

    function updatePool(
        uint256 poolId
    ) external override onlyRole(KEEPER_ROLE) {
        require(isPoolActive[poolId], "Pool not active");
        _updatePool(poolId);
    }

    function updateAllPools() external override onlyRole(KEEPER_ROLE) {
        for (uint256 i = 0; i < allPools.length; i++) {
            if (isPoolActive[allPools[i]]) {
                _updatePool(allPools[i]);
            }
        }
        
        lastGlobalUpdate = block.timestamp;
        
        emit AllPoolsUpdated(block.timestamp);
    }

    function addRewardToken(
        uint256 tokenId,
        address token,
        uint256 rewardRate,
        uint256 startTime,
        uint256 endTime
    ) external override onlyRole(REWARD_MANAGER_ROLE) {
        require(token != address(0), "Invalid token");
        require(rewardRate > 0, "Invalid reward rate");
        require(startTime >= block.timestamp, "Invalid start time");
        require(endTime > startTime, "Invalid end time");
        require(totalRewardTokens < MAX_REWARD_TOKENS, "Too many reward tokens");
        
        RewardToken storage rewardToken = rewardTokens[tokenId];
        rewardToken.tokenId = tokenId;
        rewardToken.token = token;
        rewardToken.rewardRate = rewardRate;
        rewardToken.startTime = startTime;
        rewardToken.endTime = endTime;
        rewardToken.totalDistributed = 0;
        rewardToken.isActive = true;
        
        activeRewardTokens.push(tokenId);
        totalRewardTokens++;
        
        emit RewardTokenAdded(tokenId, token, rewardRate, startTime, endTime, block.timestamp);
    }

    function setEmissionSchedule(
        uint256 scheduleId,
        uint256 poolId,
        uint256[] calldata rates,
        uint256[] calldata timestamps
    ) external override onlyRole(REWARD_MANAGER_ROLE) {
        require(isPoolActive[poolId], "Pool not active");
        require(rates.length == timestamps.length, "Array length mismatch");
        require(rates.length > 0, "Empty arrays");
        
        EmissionSchedule storage schedule = emissionSchedules[scheduleId];
        schedule.scheduleId = scheduleId;
        schedule.poolId = poolId;
        schedule.rates = rates;
        schedule.timestamps = timestamps;
        schedule.currentIndex = 0;
        schedule.isActive = true;
        
        totalEmissionSchedules++;
        
        emit EmissionScheduleSet(scheduleId, poolId, rates.length, block.timestamp);
    }

    function setBoostConfig(
        address user,
        uint256 multiplier,
        uint256 duration
    ) external override onlyRole(MINING_MANAGER_ROLE) {
        require(user != address(0), "Invalid user");
        require(multiplier <= config.maxBoostMultiplier, "Multiplier too high");
        require(duration > 0, "Invalid duration");
        
        BoostConfig storage boost = boostConfigs[user];
        boost.user = user;
        boost.multiplier = multiplier;
        boost.startTime = block.timestamp;
        boost.endTime = block.timestamp + duration;
        boost.isActive = true;
        
        emit BoostConfigSet(user, multiplier, duration, block.timestamp);
    }

    function setLockConfig(
        uint256 configId,
        uint256 duration,
        uint256 multiplier
    ) external override onlyRole(MINING_MANAGER_ROLE) {
        require(duration >= MIN_LOCK_DURATION, "Duration too short");
        require(duration <= MAX_LOCK_DURATION, "Duration too long");
        require(multiplier <= BOOST_MULTIPLIER_CAP, "Multiplier too high");
        
        LockConfig storage lockConfig = lockConfigs[configId];
        lockConfig.configId = configId;
        lockConfig.duration = duration;
        lockConfig.multiplier = multiplier;
        lockConfig.isActive = true;
        
        activeLockConfigs.push(configId);
        totalLockConfigs++;
        
        emit LockConfigSet(configId, duration, multiplier, block.timestamp);
    }

    function setVestingSchedule(
        address user,
        uint256 amount,
        uint256 startTime,
        uint256 duration,
        uint256 cliffDuration
    ) external override onlyRole(REWARD_MANAGER_ROLE) {
        require(user != address(0), "Invalid user");
        require(amount > 0, "Invalid amount");
        require(startTime >= block.timestamp, "Invalid start time");
        require(duration > 0, "Invalid duration");
        require(cliffDuration <= duration, "Cliff too long");
        
        VestingSchedule storage vesting = vestingSchedules[user];
        vesting.user = user;
        vesting.totalAmount = amount;
        vesting.startTime = startTime;
        vesting.duration = duration;
        vesting.cliffDuration = cliffDuration;
        vesting.releasedAmount = 0;
        vesting.isActive = true;
        
        emit VestingScheduleSet(user, amount, startTime, duration, cliffDuration, block.timestamp);
    }

    // Emergency functions
    function pausePool(
        uint256 poolId
    ) external override onlyRole(EMERGENCY_ROLE) {
        require(isPoolActive[poolId], "Pool not active");
        
        miningPools[poolId].isActive = false;
        isPoolActive[poolId] = false;
        
        emit PoolPaused(poolId, block.timestamp);
    }

    function unpausePool(
        uint256 poolId
    ) external override onlyRole(EMERGENCY_ROLE) {
        require(!isPoolActive[poolId], "Pool already active");
        
        miningPools[poolId].isActive = true;
        isPoolActive[poolId] = true;
        
        emit PoolUnpaused(poolId, block.timestamp);
    }

    function emergencyStopPool(
        uint256 poolId
    ) external override onlyRole(EMERGENCY_ROLE) {
        require(isPoolActive[poolId], "Pool not active");
        
        MiningPool storage pool = miningPools[poolId];
        pool.isActive = false;
        pool.endTime = block.timestamp;
        isPoolActive[poolId] = false;
        
        emit PoolEmergencyStopped(poolId, block.timestamp);
    }

    // Configuration functions
    function updateMiningConfig(
        MiningConfig calldata newConfig
    ) external onlyRole(MINING_MANAGER_ROLE) {
        require(newConfig.baseRewardRate > 0, "Invalid base reward rate");
        require(newConfig.maxBoostMultiplier <= BOOST_MULTIPLIER_CAP, "Boost multiplier too high");
        require(newConfig.minStakeAmount > 0, "Invalid min stake amount");
        require(newConfig.maxStakeAmount > newConfig.minStakeAmount, "Invalid max stake amount");
        require(newConfig.emergencyWithdrawFee <= BASIS_POINTS, "Fee too high");
        require(newConfig.performanceFee <= BASIS_POINTS, "Fee too high");
        
        config = newConfig;
        
        emit MiningConfigUpdated(block.timestamp);
    }

    // View functions
    function getMiningPool(uint256 poolId) external view override returns (MiningPool memory) {
        return miningPools[poolId];
    }

    function getUserStake(address user) external view override returns (UserStake memory) {
        return userStakes[user];
    }

    function getRewardToken(uint256 tokenId) external view override returns (RewardToken memory) {
        return rewardTokens[tokenId];
    }

    function getUserRewards(address user) external view override returns (UserRewards memory) {
        return userRewards[user];
    }

    function getPoolMetrics(uint256 poolId) external view override returns (PoolMetrics memory) {
        return poolMetrics[poolId];
    }

    function getStakingHistory(address user) external view override returns (StakingHistory[] memory) {
        return stakingHistory[user];
    }

    function getEmissionSchedule(uint256 scheduleId) external view override returns (EmissionSchedule memory) {
        return emissionSchedules[scheduleId];
    }

    function getBoostConfig(address user) external view override returns (BoostConfig memory) {
        return boostConfigs[user];
    }

    function getLockConfig(uint256 configId) external view override returns (LockConfig memory) {
        return lockConfigs[configId];
    }

    function getVestingSchedule(address user) external view override returns (VestingSchedule memory) {
        return vestingSchedules[user];
    }

    function getMiningConfig() external view override returns (MiningConfig memory) {
        return config;
    }

    function getUserPools(address user) external view override returns (uint256[] memory) {
        return userPools[user];
    }

    function getPoolStakers(uint256 poolId) external view override returns (address[] memory) {
        return poolStakers[poolId];
    }

    function getAllPools() external view override returns (uint256[] memory) {
        return allPools;
    }

    function getAllStakers() external view override returns (address[] memory) {
        return allStakers;
    }

    function getPendingRewards(address user, uint256 poolId) external view override returns (uint256) {
        return _calculatePendingRewards(user, poolId);
    }

    function getSystemMetrics() external view override returns (SystemMetrics memory) {
        return SystemMetrics({
            totalPools: totalPools,
            activePools: _countActivePools(),
            totalStakers: totalStakers,
            activeStakers: _countActiveStakers(),
            totalValueLocked: _calculateTotalValueLocked(),
            totalRewardsDistributed: _calculateTotalRewardsDistributed(),
            averageAPY: _calculateAverageAPY(),
            systemHealth: _calculateSystemHealth(),
            lastUpdate: block.timestamp
        });
    }

    // Internal functions
    function _updatePool(uint256 poolId) internal {
        MiningPool storage pool = miningPools[poolId];
        PoolMetrics storage metrics = poolMetrics[poolId];
        
        if (block.timestamp <= metrics.lastUpdate) {
            return;
        }
        
        if (metrics.totalStaked == 0) {
            metrics.lastUpdate = block.timestamp;
            return;
        }
        
        uint256 timeElapsed = block.timestamp - metrics.lastUpdate;
        uint256 reward = timeElapsed * pool.rewardRate;
        
        metrics.accRewardPerShare += (reward * PRECISION) / metrics.totalStaked;
        metrics.totalRewards += reward;
        metrics.lastUpdate = block.timestamp;
        
        lastPoolUpdate[poolId] = block.timestamp;
        
        emit PoolUpdated(poolId, metrics.accRewardPerShare, reward, block.timestamp);
    }

    function _claimRewards(address user, uint256 poolId) internal returns (uint256) {
        PoolMetrics storage metrics = poolMetrics[poolId];
        uint256 userStakeAmount = userPoolStakes[user][poolId];
        
        if (userStakeAmount == 0) {
            return 0;
        }
        
        uint256 pending = _calculatePendingRewards(user, poolId);
        
        if (pending > 0) {
            MiningPool storage pool = miningPools[poolId];
            
            // Apply boost if active
            BoostConfig storage boost = boostConfigs[user];
            if (boost.isActive && block.timestamp <= boost.endTime) {
                pending = (pending * boost.multiplier) / BASIS_POINTS;
            }
            
            // Apply lock bonus
            UserStake storage userStake = userStakes[user];
            if (userStake.lockBonus > 0) {
                pending = (pending * (BASIS_POINTS + userStake.lockBonus)) / BASIS_POINTS;
            }
            
            // Update user rewards
            UserRewards storage rewards = userRewards[user];
            rewards.user = user;
            rewards.totalEarned += pending;
            rewards.totalClaimed += pending;
            rewards.lastClaimTime = block.timestamp;
            
            // Update pool reward debt
            poolRewardDebts[poolId][user] = (userStakeAmount * metrics.accRewardPerShare) / PRECISION;
            
            // Transfer reward tokens
            IERC20(pool.rewardToken).safeTransfer(user, pending);
            
            // Update reward token metrics
            RewardToken storage rewardToken = rewardTokens[0]; // Simplified
            rewardToken.totalDistributed += pending;
        }
        
        return pending;
    }

    function _calculatePendingRewards(address user, uint256 poolId) internal view returns (uint256) {
        PoolMetrics storage metrics = poolMetrics[poolId];
        uint256 userStakeAmount = userPoolStakes[user][poolId];
        
        if (userStakeAmount == 0) {
            return 0;
        }
        
        uint256 accRewardPerShare = metrics.accRewardPerShare;
        
        // Calculate updated accRewardPerShare if pool needs update
        if (block.timestamp > metrics.lastUpdate && metrics.totalStaked > 0) {
            MiningPool storage pool = miningPools[poolId];
            uint256 timeElapsed = block.timestamp - metrics.lastUpdate;
            uint256 reward = timeElapsed * pool.rewardRate;
            accRewardPerShare += (reward * PRECISION) / metrics.totalStaked;
        }
        
        uint256 pending = ((userStakeAmount * accRewardPerShare) / PRECISION) - poolRewardDebts[poolId][user];
        
        return pending;
    }

    function _countActivePools() internal view returns (uint256) {
        uint256 count = 0;
        for (uint256 i = 0; i < allPools.length; i++) {
            if (isPoolActive[allPools[i]]) {
                count++;
            }
        }
        return count;
    }

    function _countActiveStakers() internal view returns (uint256) {
        uint256 count = 0;
        for (uint256 i = 0; i < allStakers.length; i++) {
            if (isStakerActive[allStakers[i]]) {
                count++;
            }
        }
        return count;
    }

    function _calculateTotalValueLocked() internal view returns (uint256) {
        uint256 totalValue = 0;
        
        for (uint256 i = 0; i < allPools.length; i++) {
            if (isPoolActive[allPools[i]]) {
                PoolMetrics storage metrics = poolMetrics[allPools[i]];
                MiningPool storage pool = miningPools[allPools[i]];
                
                // Get token price from oracle
                uint256 price = oracle.getPrice(pool.stakingToken);
                totalValue += (metrics.totalStaked * price) / PRECISION;
            }
        }
        
        return totalValue;
    }

    function _calculateTotalRewardsDistributed() internal view returns (uint256) {
        uint256 totalRewards = 0;
        
        for (uint256 i = 0; i < activeRewardTokens.length; i++) {
            RewardToken storage rewardToken = rewardTokens[activeRewardTokens[i]];
            totalRewards += rewardToken.totalDistributed;
        }
        
        return totalRewards;
    }

    function _calculateAverageAPY() internal view returns (uint256) {
        if (allPools.length == 0) return 0;
        
        uint256 totalAPY = 0;
        uint256 activePools = 0;
        
        for (uint256 i = 0; i < allPools.length; i++) {
            if (isPoolActive[allPools[i]]) {
                // Simplified APY calculation
                totalAPY += 1000; // 10% APY placeholder
                activePools++;
            }
        }
        
        return activePools > 0 ? totalAPY / activePools : 0;
    }

    function _calculateSystemHealth() internal view returns (uint256) {
        uint256 activePools = _countActivePools();
        uint256 activeStakers = _countActiveStakers();
        
        if (totalPools == 0 || totalStakers == 0) return 0;
        
        uint256 poolHealth = (activePools * BASIS_POINTS) / totalPools;
        uint256 stakerHealth = (activeStakers * BASIS_POINTS) / totalStakers;
        
        return (poolHealth + stakerHealth) / 2;
    }

    // Emergency functions
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
}
