// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title ILiquidityMining
 * @dev Interface for the Liquidity Mining contract
 * @author CoreLiquid Protocol
 */
interface ILiquidityMining {
    // Events
    event PoolCreated(
        bytes32 indexed poolId,
        address indexed stakingToken,
        address indexed rewardToken,
        uint256 rewardRate,
        uint256 startTime,
        uint256 endTime,
        uint256 timestamp
    );
    
    event PoolUpdated(
        bytes32 indexed poolId,
        uint256 newRewardRate,
        uint256 newEndTime,
        uint256 timestamp
    );
    
    event PoolPaused(
        bytes32 indexed poolId,
        string reason,
        uint256 timestamp
    );
    
    event PoolUnpaused(
        bytes32 indexed poolId,
        uint256 timestamp
    );
    
    event Staked(
        bytes32 indexed poolId,
        address indexed user,
        uint256 amount,
        uint256 totalStaked,
        uint256 timestamp
    );
    
    event Unstaked(
        bytes32 indexed poolId,
        address indexed user,
        uint256 amount,
        uint256 totalStaked,
        uint256 timestamp
    );
    
    event RewardClaimed(
        bytes32 indexed poolId,
        address indexed user,
        address indexed rewardToken,
        uint256 amount,
        uint256 timestamp
    );
    
    event RewardAdded(
        bytes32 indexed poolId,
        address indexed rewardToken,
        uint256 amount,
        uint256 newRewardRate,
        uint256 timestamp
    );
    
    event MultiplierUpdated(
        bytes32 indexed poolId,
        address indexed user,
        uint256 oldMultiplier,
        uint256 newMultiplier,
        MultiplierType multiplierType,
        uint256 timestamp
    );
    
    event BoostActivated(
        bytes32 indexed poolId,
        address indexed user,
        BoostType boostType,
        uint256 multiplier,
        uint256 duration,
        uint256 timestamp
    );
    
    event BoostExpired(
        bytes32 indexed poolId,
        address indexed user,
        BoostType boostType,
        uint256 timestamp
    );
    
    event EmissionRateUpdated(
        bytes32 indexed poolId,
        uint256 oldRate,
        uint256 newRate,
        uint256 timestamp
    );
    
    event VestingScheduleCreated(
        bytes32 indexed scheduleId,
        address indexed beneficiary,
        uint256 totalAmount,
        uint256 startTime,
        uint256 duration,
        uint256 timestamp
    );
    
    event VestingClaimed(
        bytes32 indexed scheduleId,
        address indexed beneficiary,
        uint256 amount,
        uint256 timestamp
    );
    
    event LockupCreated(
        bytes32 indexed lockupId,
        address indexed user,
        uint256 amount,
        uint256 duration,
        uint256 multiplier,
        uint256 timestamp
    );
    
    event LockupExtended(
        bytes32 indexed lockupId,
        uint256 newDuration,
        uint256 newMultiplier,
        uint256 timestamp
    );
    
    event EarlyUnlockPenalty(
        bytes32 indexed lockupId,
        address indexed user,
        uint256 penaltyAmount,
        uint256 timestamp
    );
    
    event RewardDistributorUpdated(
        address indexed oldDistributor,
        address indexed newDistributor,
        uint256 timestamp
    );
    
    event AllRewardsClaimed(
        address indexed user,
        uint256 totalRewards,
        uint256 timestamp
    );
    
    event EmergencyWithdraw(
        address indexed user,
        uint256 indexed poolId,
        uint256 amount,
        uint256 fee,
        uint256 timestamp
    );
    
    event AllPoolsUpdated(
        uint256 timestamp
    );
    
    event RewardTokenAdded(
        uint256 indexed tokenId,
        address indexed token,
        uint256 rewardRate,
        uint256 startTime,
        uint256 endTime,
        uint256 timestamp
    );
    
    event EmissionScheduleSet(
        uint256 indexed scheduleId,
        uint256 indexed poolId,
        uint256 ratesLength,
        uint256 timestamp
    );
    
    event BoostConfigSet(
        address indexed user,
        uint256 multiplier,
        uint256 duration,
        uint256 timestamp
    );
    
    event LockConfigSet(
        uint256 indexed configId,
        uint256 duration,
        uint256 multiplier,
        uint256 timestamp
    );
    
    event VestingScheduleSet(
        address indexed user,
        uint256 amount,
        uint256 startTime,
        uint256 duration,
        uint256 cliffDuration,
        uint256 timestamp
    );
    
    event PoolEmergencyStopped(
        uint256 indexed poolId,
        uint256 timestamp
    );
    
    event MiningConfigUpdated(
        uint256 timestamp
    );
    
    event RewardsClaimed(
        address indexed user,
        uint256 indexed poolId,
        uint256 rewards,
        uint256 timestamp
    );
    
    event PoolUpdated(
        uint256 indexed poolId,
        uint256 accRewardPerShare,
        uint256 reward,
        uint256 timestamp
    );

    // Structs
    struct Pool {
        bytes32 poolId;
        address stakingToken;
        address[] rewardTokens;
        uint256[] rewardRates;
        uint256 totalStaked;
        uint256 startTime;
        uint256 endTime;
        uint256 lastUpdateTime;
        bool isPaused;
        PoolConfig config;
        PoolMetrics metrics;
    }
    
    struct PoolConfig {
        uint256 minStakeAmount;
        uint256 maxStakeAmount;
        uint256 stakingFee;
        uint256 unstakingFee;
        uint256 lockupPeriod;
        bool requiresWhitelist;
        bool allowEarlyUnstake;
        uint256 earlyUnstakePenalty;
        MultiplierConfig multiplierConfig;
        VestingConfig vestingConfig;
    }
    
    struct PoolMetrics {
        uint256 totalRewardsDistributed;
        uint256 totalStakers;
        uint256 averageStakeAmount;
        uint256 totalVolume;
        uint256 apr;
        uint256 apy;
        uint256 tvl;
        uint256 utilizationRate;
    }
    
    struct RewardInfo {
        address rewardToken;
        uint256 rewardRate;
        uint256 rewardPerTokenStored;
        uint256 lastUpdateTime;
        uint256 totalRewards;
        uint256 distributedRewards;
        uint256 pendingRewards;
        RewardConfig config;
    }
    
    struct RewardConfig {
        uint256 emissionRate;
        uint256 maxRewardPerSecond;
        uint256 rewardDuration;
        bool isLinear;
        uint256 vestingPeriod;
        uint256 cliffPeriod;
        DistributionMethod distributionMethod;
    }
    
    struct UserInfo {
        address user;
        uint256 stakedAmount;
        uint256 stakingTime;
        uint256 lastClaimTime;
        uint256 totalClaimed;
        uint256 pendingRewards;
        UserMultipliers multipliers;
        UserBoosts boosts;
        UserLockups lockups;
        UserMetrics metrics;
    }
    
    struct UserMultipliers {
        uint256 baseMultiplier;
        uint256 timeMultiplier;
        uint256 volumeMultiplier;
        uint256 loyaltyMultiplier;
        uint256 boostMultiplier;
        uint256 totalMultiplier;
        uint256 lastUpdate;
    }
    
    struct UserBoosts {
        BoostType[] boostTypes;
        uint256 totalBoostMultiplier;
        uint256 boostExpiry;
    }
    
    struct BoostInfo {
        BoostType boostType;
        uint256 multiplier;
        uint256 startTime;
        uint256 duration;
        uint256 endTime;
        bool isActive;
        BoostConfig config;
    }
    
    struct BoostConfig {
        uint256 maxMultiplier;
        uint256 minDuration;
        uint256 maxDuration;
        uint256 cost;
        address costToken;
        bool isStackable;
        uint256 cooldownPeriod;
    }
    
    struct UserLockups {
        bytes32[] lockupIds;
        uint256 totalLockedAmount;
        uint256 totalLockupMultiplier;
    }
    
    struct LockupInfo {
        bytes32 lockupId;
        uint256 amount;
        uint256 startTime;
        uint256 duration;
        uint256 endTime;
        uint256 multiplier;
        bool isActive;
        LockupConfig config;
    }
    
    struct LockupConfig {
        uint256[] durations;
        uint256[] multipliers;
        uint256 minLockupAmount;
        uint256 maxLockupAmount;
        uint256 earlyUnlockPenalty;
        bool allowExtension;
        bool allowPartialUnlock;
    }
    
    struct UserMetrics {
        uint256 totalStaked;
        uint256 totalUnstaked;
        uint256 totalRewardsClaimed;
        uint256 stakingDuration;
        uint256 averageStakeAmount;
        uint256 maxStakeAmount;
        uint256 stakingFrequency;
        uint256 loyaltyScore;
    }
    
    struct MultiplierConfig {
        uint256 baseMultiplier;
        TimeMultiplier timeMultiplier;
        VolumeMultiplier volumeMultiplier;
        LoyaltyMultiplier loyaltyMultiplier;
        bool enableTimeMultiplier;
        bool enableVolumeMultiplier;
        bool enableLoyaltyMultiplier;
    }
    
    struct TimeMultiplier {
        uint256[] thresholds;
        uint256[] multipliers;
        uint256 maxMultiplier;
        uint256 updateInterval;
    }
    
    struct VolumeMultiplier {
        uint256[] volumeThresholds;
        uint256[] multipliers;
        uint256 maxMultiplier;
        uint256 measurementPeriod;
    }
    
    struct LoyaltyMultiplier {
        uint256[] loyaltyThresholds;
        uint256[] multipliers;
        uint256 maxMultiplier;
        uint256 decayRate;
    }
    
    struct VestingSchedule {
        bytes32 scheduleId;
        address beneficiary;
        uint256 totalAmount;
        uint256 startTime;
        uint256 duration;
        uint256 cliffDuration;
        uint256 releasedAmount;
        uint256 lastReleaseTime;
        bool isRevocable;
        bool isRevoked;
        VestingConfig config;
    }
    
    struct VestingConfig {
        VestingType vestingType;
        uint256[] releaseMilestones;
        uint256[] releasePercentages;
        bool isLinear;
        uint256 releaseInterval;
        uint256 minReleaseAmount;
    }
    
    struct MiningPool {
        uint256 poolId;
        address stakingToken;
        address rewardToken;
        uint256 rewardRate;
        uint256 startTime;
        uint256 endTime;
        uint256 maxStakers;
        uint256 createdAt;
        address createdBy;
        bool isActive;
    }
    
    struct UserStake {
        address user;
        uint256 totalStaked;
        uint256 lastStakeTime;
        uint256 lockEndTime;
        uint256 lockBonus;
    }
    
    struct RewardToken {
        uint256 tokenId;
        address token;
        uint256 rewardRate;
        uint256 startTime;
        uint256 endTime;
        uint256 totalDistributed;
        bool isActive;
    }
    
    struct UserRewards {
        address user;
        uint256 totalEarned;
        uint256 totalClaimed;
        uint256 lastClaimTime;
    }
    
    struct StakingHistory {
        uint256 poolId;
        uint256 amount;
        uint256 timestamp;
        StakingAction action;
        uint256 lockDuration;
    }
    
    struct LockConfig {
        uint256 configId;
        uint256 duration;
        uint256 multiplier;
        bool isActive;
    }
    
    struct MiningConfig {
        uint256 baseRewardRate;
        uint256 maxBoostMultiplier;
        uint256 minStakeAmount;
        uint256 maxStakeAmount;
        uint256 emergencyWithdrawFee;
        uint256 performanceFee;
        uint256 lockBonusMultiplier;
        uint256 vestingDuration;
        bool isActive;
    }

    struct SystemMetrics {
        uint256 totalPools;
        uint256 activePools;
        uint256 totalStakers;
        uint256 activeStakers;
        uint256 totalValueLocked;
        uint256 totalRewardsDistributed;
        uint256 averageAPY;
        uint256 systemHealth;
        uint256 lastUpdate;
    }
    
    struct RewardDistribution {
        bytes32 distributionId;
        address[] recipients;
        uint256[] amounts;
        address rewardToken;
        uint256 totalAmount;
        uint256 distributionTime;
        DistributionStatus status;
        DistributionConfig config;
    }
    
    struct DistributionConfig {
        DistributionMethod method;
        uint256 batchSize;
        uint256 gasLimit;
        bool requiresClaim;
        uint256 claimDeadline;
        bool allowPartialDistribution;
    }
    
    struct EmissionSchedule {
        bytes32 scheduleId;
        uint256 startTime;
        uint256 endTime;
        uint256 totalEmission;
        uint256 currentEmission;
        EmissionCurve curve;
        EmissionConfig config;
    }
    
    struct EmissionConfig {
        uint256 initialRate;
        uint256 finalRate;
        uint256 halvingPeriod;
        uint256 decayRate;
        bool isDecaying;
        uint256 minEmissionRate;
    }
    
    struct LiquidityMiningMetrics {
        uint256 totalPools;
        uint256 activePools;
        uint256 totalStakers;
        uint256 totalValueLocked;
        uint256 totalRewardsDistributed;
        uint256 averageAPR;
        uint256 totalVolume;
        uint256 lastUpdate;
    }

    // Enums
    enum MultiplierType {
        BASE,
        TIME,
        VOLUME,
        LOYALTY,
        BOOST,
        LOCKUP
    }
    
    enum BoostType {
        STAKING_BOOST,
        REWARD_BOOST,
        TIME_BOOST,
        VOLUME_BOOST,
        LOYALTY_BOOST,
        PREMIUM_BOOST,
        EVENT_BOOST
    }
    
    enum VestingType {
        LINEAR,
        CLIFF,
        MILESTONE,
        EXPONENTIAL,
        CUSTOM
    }
    
    enum DistributionMethod {
        PROPORTIONAL,
        EQUAL,
        WEIGHTED,
        MERIT_BASED,
        LOTTERY,
        FIRST_COME_FIRST_SERVE
    }
    
    enum DistributionStatus {
        PENDING,
        IN_PROGRESS,
        COMPLETED,
        FAILED,
        CANCELLED
    }
    
    enum EmissionCurve {
        LINEAR,
        EXPONENTIAL,
        LOGARITHMIC,
        HALVING,
        CUSTOM
    }
    
    enum StakingAction {
        STAKE,
        UNSTAKE,
        CLAIM,
        COMPOUND,
        EMERGENCY_WITHDRAW
    }

    // Core staking functions
    function stake(
        bytes32 poolId,
        uint256 amount
    ) external;
    
    function stakeWithLockup(
        bytes32 poolId,
        uint256 amount,
        uint256 lockupDuration
    ) external returns (bytes32 lockupId);
    
    function unstake(
        bytes32 poolId,
        uint256 amount
    ) external;
    
    function unstakeWithPenalty(
        bytes32 poolId,
        uint256 amount
    ) external returns (uint256 penaltyAmount);
    
    function emergencyUnstake(
        bytes32 poolId
    ) external;
    
    function claimRewards(
        bytes32 poolId
    ) external;
    
    function claimRewardsForToken(
        bytes32 poolId,
        address rewardToken
    ) external;
    
    function claimAllRewards(
        bytes32[] calldata poolIds
    ) external;
    
    function compoundRewards(
        bytes32 poolId
    ) external;
    
    // Pool management functions
    function createPool(
        address stakingToken,
        address[] calldata rewardTokens,
        uint256[] calldata rewardRates,
        uint256 startTime,
        uint256 endTime,
        PoolConfig calldata config
    ) external returns (bytes32 poolId);
    
    function updatePool(
        bytes32 poolId,
        uint256[] calldata newRewardRates,
        uint256 newEndTime
    ) external;
    
    function pausePool(
        bytes32 poolId,
        string calldata reason
    ) external;
    
    function unpausePool(
        bytes32 poolId
    ) external;
    
    function addRewardToken(
        bytes32 poolId,
        address rewardToken,
        uint256 rewardRate,
        RewardConfig calldata config
    ) external;
    
    function removeRewardToken(
        bytes32 poolId,
        address rewardToken
    ) external;
    
    function updateRewardRate(
        bytes32 poolId,
        address rewardToken,
        uint256 newRate
    ) external;
    
    function extendPool(
        bytes32 poolId,
        uint256 newEndTime
    ) external;
    
    function closePool(
        bytes32 poolId,
        string calldata reason
    ) external;
    
    // Reward management functions
    function addRewards(
        bytes32 poolId,
        address rewardToken,
        uint256 amount
    ) external;
    
    function withdrawUnusedRewards(
        bytes32 poolId,
        address rewardToken,
        uint256 amount
    ) external;
    
    function updateEmissionRate(
        bytes32 poolId,
        uint256 newRate
    ) external;
    
    function setEmissionSchedule(
        bytes32 poolId,
        EmissionSchedule calldata schedule
    ) external;
    
    function distributeRewards(
        bytes32 poolId,
        address[] calldata recipients,
        uint256[] calldata amounts
    ) external;
    
    function batchDistributeRewards(
        RewardDistribution[] calldata distributions
    ) external;
    
    // Multiplier and boost functions
    function updateMultipliers(
        bytes32 poolId,
        address user
    ) external;
    
    function activateBoost(
        bytes32 poolId,
        BoostType boostType,
        uint256 duration
    ) external;
    
    function deactivateBoost(
        bytes32 poolId,
        BoostType boostType
    ) external;
    
    function extendBoost(
        bytes32 poolId,
        BoostType boostType,
        uint256 additionalDuration
    ) external;
    
    function updateMultiplierConfig(
        bytes32 poolId,
        MultiplierConfig calldata config
    ) external;
    
    function setBoostConfig(
        BoostType boostType,
        BoostConfig calldata config
    ) external;
    
    // Lockup functions
    function createLockup(
        bytes32 poolId,
        uint256 amount,
        uint256 duration
    ) external returns (bytes32 lockupId);
    
    function extendLockup(
        bytes32 lockupId,
        uint256 additionalDuration
    ) external;
    
    function unlockEarly(
        bytes32 lockupId
    ) external returns (uint256 penaltyAmount);
    
    function unlockLockup(
        bytes32 lockupId
    ) external;
    
    function updateLockupConfig(
        bytes32 poolId,
        LockupConfig calldata config
    ) external;
    
    // Vesting functions
    function createVestingSchedule(
        address beneficiary,
        uint256 totalAmount,
        uint256 startTime,
        uint256 duration,
        VestingConfig calldata config
    ) external returns (bytes32 scheduleId);
    
    function releaseVestedTokens(
        bytes32 scheduleId
    ) external;
    
    function revokeVesting(
        bytes32 scheduleId,
        string calldata reason
    ) external;
    
    function updateVestingSchedule(
        bytes32 scheduleId,
        VestingConfig calldata newConfig
    ) external;
    
    // Configuration functions
    function updatePoolConfig(
        bytes32 poolId,
        PoolConfig calldata newConfig
    ) external;
    
    function setRewardDistributor(
        address newDistributor
    ) external;
    
    function updateGlobalConfig(
        string calldata parameter,
        uint256 value
    ) external;
    
    function setWhitelist(
        bytes32 poolId,
        address[] calldata users,
        bool[] calldata statuses
    ) external;
    
    function pauseSystem(
        string calldata reason
    ) external;
    
    function unpauseSystem() external;
    
    // Emergency functions
    function emergencyWithdraw(
        bytes32 poolId,
        address token,
        uint256 amount
    ) external;
    
    function emergencyPause(
        string calldata reason
    ) external;
    
    function recoverTokens(
        address token,
        uint256 amount
    ) external;
    
    function forceUnstake(
        bytes32 poolId,
        address user,
        string calldata reason
    ) external;
    
    // View functions - Pools
    function getPool(
        bytes32 poolId
    ) external view returns (Pool memory);
    
    function getAllPools() external view returns (bytes32[] memory);
    
    function getActivePools() external view returns (bytes32[] memory);
    
    function getPoolsByToken(
        address stakingToken
    ) external view returns (bytes32[] memory);
    
    function getPoolConfig(
        bytes32 poolId
    ) external view returns (PoolConfig memory);
    
    function getPoolMetrics(
        bytes32 poolId
    ) external view returns (PoolMetrics memory);
    
    function isPoolActive(
        bytes32 poolId
    ) external view returns (bool active);
    
    function getPoolAPR(
        bytes32 poolId
    ) external view returns (uint256 apr);
    
    function getPoolTVL(
        bytes32 poolId
    ) external view returns (uint256 tvl);
    
    // View functions - User info
    function getUserInfo(
        bytes32 poolId,
        address user
    ) external view returns (UserInfo memory);
    
    function getUserStake(
        bytes32 poolId,
        address user
    ) external view returns (uint256 stakedAmount);
    
    function getUserRewards(
        bytes32 poolId,
        address user
    ) external view returns (uint256[] memory rewards);
    
    function getUserPendingRewards(
        bytes32 poolId,
        address user,
        address rewardToken
    ) external view returns (uint256 pendingRewards);
    
    function getUserMultipliers(
        bytes32 poolId,
        address user
    ) external view returns (UserMultipliers memory);
    
    function getUserBoosts(
        bytes32 poolId,
        address user
    ) external view returns (BoostInfo[] memory activeBoosts);
    
    function getUserLockups(
        bytes32 poolId,
        address user
    ) external view returns (LockupInfo[] memory lockups);
    
    function getUserMetrics(
        bytes32 poolId,
        address user
    ) external view returns (UserMetrics memory);
    
    // View functions - Rewards
    function getRewardInfo(
        bytes32 poolId,
        address rewardToken
    ) external view returns (RewardInfo memory);
    
    function getRewardRate(
        bytes32 poolId,
        address rewardToken
    ) external view returns (uint256 rate);
    
    function getTotalRewards(
        bytes32 poolId,
        address rewardToken
    ) external view returns (uint256 totalRewards);
    
    function getDistributedRewards(
        bytes32 poolId,
        address rewardToken
    ) external view returns (uint256 distributedRewards);
    
    function calculateRewards(
        bytes32 poolId,
        address user,
        address rewardToken
    ) external view returns (uint256 rewards);
    
    // View functions - Vesting
    function getVestingSchedule(
        bytes32 scheduleId
    ) external view returns (VestingSchedule memory);
    
    function getUserVestingSchedules(
        address user
    ) external view returns (bytes32[] memory scheduleIds);
    
    function getVestedAmount(
        bytes32 scheduleId
    ) external view returns (uint256 vestedAmount);
    
    function getReleasableAmount(
        bytes32 scheduleId
    ) external view returns (uint256 releasableAmount);
    
    // View functions - Lockups
    function getLockupInfo(
        bytes32 lockupId
    ) external view returns (LockupInfo memory);
    
    function getUserLockupIds(
        address user
    ) external view returns (bytes32[] memory lockupIds);
    
    function getLockupMultiplier(
        uint256 duration
    ) external view returns (uint256 multiplier);
    
    function getEarlyUnlockPenalty(
        bytes32 lockupId
    ) external view returns (uint256 penalty);
    
    // View functions - Analytics
    function getLiquidityMiningMetrics() external view returns (LiquidityMiningMetrics memory);
    
    function getPoolAnalytics(
        bytes32 poolId,
        uint256 timeframe
    ) external view returns (
        uint256 totalStaked,
        uint256 totalRewards,
        uint256 averageAPR,
        uint256 participantCount
    );
    
    function getUserAnalytics(
        address user,
        uint256 timeframe
    ) external view returns (
        uint256 totalStaked,
        uint256 totalRewards,
        uint256 poolsParticipated,
        uint256 averageMultiplier
    );
    
    function getSystemHealth() external view returns (
        uint256 totalTVL,
        uint256 totalRewardsPerDay,
        uint256 averageAPR,
        uint256 activeUsers
    );
}
