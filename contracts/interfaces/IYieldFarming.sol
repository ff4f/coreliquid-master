// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IYieldFarming
 * @dev Interface for the Yield Farming contract
 * @author CoreLiquid Protocol
 */
interface IYieldFarming {
    // Events
    event FarmCreated(
        uint256 indexed farmId,
        address indexed stakingToken,
        address indexed rewardToken,
        uint256 rewardRate,
        uint256 startTime,
        uint256 endTime
    );
    
    event FarmUpdated(
        uint256 indexed farmId,
        uint256 newRewardRate,
        uint256 newEndTime,
        uint256 timestamp
    );
    
    event FarmPaused(
        uint256 indexed farmId,
        string reason,
        uint256 timestamp
    );
    
    event FarmUnpaused(
        uint256 indexed farmId,
        uint256 timestamp
    );
    
    event Staked(
        uint256 indexed farmId,
        address indexed user,
        uint256 amount,
        uint256 timestamp
    );
    
    event Unstaked(
        uint256 indexed farmId,
        address indexed user,
        uint256 amount,
        uint256 timestamp
    );
    
    event RewardsClaimed(
        uint256 indexed farmId,
        address indexed user,
        uint256 amount,
        uint256 timestamp
    );
    
    event RewardsCompounded(
        uint256 indexed farmId,
        address indexed user,
        uint256 amount,
        uint256 timestamp
    );
    
    event RewardsAdded(
        uint256 indexed farmId,
        uint256 amount,
        uint256 newEndTime,
        uint256 timestamp
    );
    
    event EmergencyWithdraw(
        uint256 indexed farmId,
        address indexed user,
        uint256 amount,
        uint256 timestamp
    );
    
    event BoostActivated(
        uint256 indexed farmId,
        address indexed user,
        BoostType boostType,
        uint256 multiplier,
        uint256 duration
    );
    
    event BoostExpired(
        uint256 indexed farmId,
        address indexed user,
        BoostType boostType,
        uint256 timestamp
    );
    
    event LockupCreated(
        uint256 indexed farmId,
        address indexed user,
        uint256 amount,
        uint256 lockupPeriod,
        uint256 multiplier
    );
    
    event LockupExtended(
        uint256 indexed farmId,
        address indexed user,
        uint256 newLockupEnd,
        uint256 newMultiplier
    );
    
    event EarlyUnlockPenalty(
        uint256 indexed farmId,
        address indexed user,
        uint256 penaltyAmount,
        uint256 timestamp
    );
    
    event VestingScheduleCreated(
        uint256 indexed farmId,
        address indexed user,
        uint256 totalAmount,
        uint256 vestingPeriod,
        uint256 cliffPeriod
    );
    
    event VestedTokensReleased(
        uint256 indexed farmId,
        address indexed user,
        uint256 amount,
        uint256 timestamp
    );
    
    event FarmMigrated(
        uint256 indexed oldFarmId,
        uint256 indexed newFarmId,
        address indexed user,
        uint256 amount
    );
    
    event RewardTokenAdded(
        uint256 indexed farmId,
        address indexed rewardToken,
        uint256 rewardRate,
        uint256 timestamp
    );
    
    event RewardTokenRemoved(
        uint256 indexed farmId,
        address indexed rewardToken,
        uint256 timestamp
    );
    
    event FeeCollected(
        uint256 indexed farmId,
        address indexed feeToken,
        uint256 amount,
        uint256 timestamp
    );

    // Structs
    struct Farm {
        uint256 farmId;
        address stakingToken;
        address[] rewardTokens;
        uint256[] rewardRates;
        uint256 totalStaked;
        uint256 startTime;
        uint256 endTime;
        uint256 lastUpdateTime;
        bool isPaused;
        FarmConfig config;
        FarmMetrics metrics;
        mapping(address => RewardInfo) rewardInfo;
        mapping(address => UserInfo) userInfo;
    }
    
    struct FarmConfig {
        uint256 minStakeAmount;
        uint256 maxStakeAmount;
        uint256 stakingFee;
        uint256 unstakingFee;
        uint256 performanceFee;
        bool allowsCompounding;
        bool allowsEarlyWithdraw;
        uint256 earlyWithdrawPenalty;
        uint256 lockupPeriod;
        uint256 vestingPeriod;
        bool requiresWhitelist;
        address[] authorizedUsers;
    }
    
    struct FarmMetrics {
        uint256 totalUsers;
        uint256 totalRewardsDistributed;
        uint256 totalFeesCollected;
        uint256 averageStakingPeriod;
        uint256 totalCompounds;
        uint256 peakTVL;
        uint256 averageTVL;
        uint256 totalTransactions;
        uint256 lastMetricsUpdate;
    }
    
    struct RewardInfo {
        address rewardToken;
        uint256 rewardRate;
        uint256 rewardPerTokenStored;
        uint256 totalRewardsDistributed;
        uint256 remainingRewards;
        uint256 lastUpdateTime;
        bool isActive;
        RewardConfig config;
        RewardMetrics metrics;
    }
    
    struct RewardConfig {
        uint256 minRewardRate;
        uint256 maxRewardRate;
        uint256 rewardMultiplier;
        uint256 bonusRewardRate;
        bool isDynamic;
        uint256 adjustmentFactor;
        uint256 distributionPeriod;
        address rewardSource;
    }
    
    struct RewardMetrics {
        uint256 totalDistributed;
        uint256 averageDistributionRate;
        uint256 peakDistributionRate;
        uint256 totalClaimed;
        uint256 totalCompounded;
        uint256 distributionEfficiency;
        uint256 lastDistribution;
    }
    
    struct UserInfo {
        uint256 stakedAmount;
        uint256 stakingTime;
        uint256 lastClaimTime;
        uint256 totalRewardsClaimed;
        uint256 totalRewardsCompounded;
        UserBoosts boosts;
        UserLockups lockups;
        UserVesting vesting;
        UserMetrics metrics;
        mapping(address => uint256) rewardDebt;
        mapping(address => uint256) pendingRewards;
    }
    
    struct UserBoosts {
        mapping(BoostType => BoostInfo) activeBoosts;
        uint256 totalMultiplier;
        uint256 loyaltyMultiplier;
        uint256 volumeMultiplier;
        uint256 timeMultiplier;
        uint256 lastBoostUpdate;
    }
    
    struct BoostInfo {
        BoostType boostType;
        uint256 multiplier;
        uint256 startTime;
        uint256 endTime;
        bool isActive;
        BoostConfig config;
    }
    
    struct BoostConfig {
        uint256 maxMultiplier;
        uint256 duration;
        uint256 cooldownPeriod;
        uint256 cost;
        address costToken;
        bool isStackable;
        uint256 maxStacks;
        BoostRequirement[] requirements;
    }
    
    struct BoostRequirement {
        RequirementType requirementType;
        uint256 value;
        address token;
        string description;
    }
    
    struct UserLockups {
        mapping(uint256 => LockupInfo) lockups;
        uint256[] activeLockupIds;
        uint256 totalLockedAmount;
        uint256 totalLockupMultiplier;
        uint256 nextLockupId;
    }
    
    struct LockupInfo {
        uint256 lockupId;
        uint256 amount;
        uint256 lockupPeriod;
        uint256 startTime;
        uint256 endTime;
        uint256 multiplier;
        bool isActive;
        LockupConfig config;
    }
    
    struct LockupConfig {
        uint256 minLockupPeriod;
        uint256 maxLockupPeriod;
        uint256 baseMultiplier;
        uint256 multiplierPerPeriod;
        uint256 maxMultiplier;
        bool allowsExtension;
        bool allowsEarlyUnlock;
        uint256 earlyUnlockPenalty;
    }
    
    struct UserVesting {
        mapping(address => VestingSchedule) schedules;
        address[] vestingTokens;
        uint256 totalVestedAmount;
        uint256 totalReleasedAmount;
        uint256 lastVestingUpdate;
    }
    
    struct VestingSchedule {
        address token;
        uint256 totalAmount;
        uint256 releasedAmount;
        uint256 startTime;
        uint256 cliffPeriod;
        uint256 vestingPeriod;
        uint256 lastReleaseTime;
        bool isActive;
        VestingConfig config;
    }
    
    struct VestingConfig {
        uint256 minVestingPeriod;
        uint256 maxVestingPeriod;
        uint256 minCliffPeriod;
        uint256 releaseInterval;
        bool allowsRevocation;
        bool allowsAcceleration;
        uint256 accelerationFee;
    }
    
    struct UserMetrics {
        uint256 totalStaked;
        uint256 totalUnstaked;
        uint256 totalRewardsClaimed;
        uint256 totalRewardsCompounded;
        uint256 averageStakingPeriod;
        uint256 totalTransactions;
        uint256 firstStakeTime;
        uint256 lastActivityTime;
        uint256 loyaltyScore;
        uint256 riskScore;
    }
    
    struct YieldStrategy {
        uint256 strategyId;
        string name;
        address targetToken;
        address[] inputTokens;
        uint256[] allocations;
        uint256 expectedAPY;
        uint256 riskLevel;
        StrategyConfig config;
        StrategyMetrics metrics;
        bool isActive;
    }
    
    struct StrategyConfig {
        uint256 minInvestment;
        uint256 maxInvestment;
        uint256 managementFee;
        uint256 performanceFee;
        uint256 rebalanceThreshold;
        uint256 slippageTolerance;
        bool autoRebalance;
        address[] authorizedManagers;
    }
    
    struct StrategyMetrics {
        uint256 totalInvested;
        uint256 totalReturns;
        uint256 realizedAPY;
        uint256 sharpeRatio;
        uint256 maxDrawdown;
        uint256 volatility;
        uint256 totalRebalances;
        uint256 lastPerformanceUpdate;
    }
    
    struct YieldFarmingAnalytics {
        uint256 totalFarms;
        uint256 totalStaked;
        uint256 totalRewardsDistributed;
        uint256 totalUsers;
        uint256 averageAPY;
        uint256 totalTVL;
        uint256 averageStakingPeriod;
        uint256 lastUpdate;
    }

    // Enums
    enum BoostType {
        LOYALTY,
        VOLUME,
        TIME,
        REFERRAL,
        GOVERNANCE,
        PREMIUM,
        SEASONAL,
        CUSTOM
    }
    
    enum RequirementType {
        MIN_STAKE_AMOUNT,
        MIN_STAKE_DURATION,
        TOKEN_BALANCE,
        NFT_OWNERSHIP,
        GOVERNANCE_PARTICIPATION,
        REFERRAL_COUNT,
        CUSTOM
    }
    
    enum StrategyType {
        SINGLE_ASSET,
        MULTI_ASSET,
        LIQUIDITY_PROVISION,
        LENDING,
        ARBITRAGE,
        DELTA_NEUTRAL,
        CUSTOM
    }

    // Core farming functions
    function stake(
        uint256 farmId,
        uint256 amount
    ) external;
    
    function stakeWithLockup(
        uint256 farmId,
        uint256 amount,
        uint256 lockupPeriod
    ) external;
    
    function unstake(
        uint256 farmId,
        uint256 amount
    ) external;
    
    function claimRewards(
        uint256 farmId
    ) external;
    
    function claimRewards(
        uint256 farmId,
        address rewardToken
    ) external;
    
    function compoundRewards(
        uint256 farmId
    ) external;
    
    function emergencyWithdraw(
        uint256 farmId
    ) external;
    
    // Farm management functions
    function createFarm(
        address stakingToken,
        address[] calldata rewardTokens,
        uint256[] calldata rewardRates,
        uint256 startTime,
        uint256 endTime,
        FarmConfig calldata config
    ) external returns (uint256 farmId);
    
    function updateFarm(
        uint256 farmId,
        uint256[] calldata newRewardRates,
        uint256 newEndTime
    ) external;
    
    function pauseFarm(
        uint256 farmId,
        string calldata reason
    ) external;
    
    function unpauseFarm(
        uint256 farmId
    ) external;
    
    function closeFarm(
        uint256 farmId
    ) external;
    
    function migrateFarm(
        uint256 oldFarmId,
        uint256 newFarmId
    ) external;
    
    // Reward management functions
    function addRewards(
        uint256 farmId,
        address rewardToken,
        uint256 amount
    ) external;
    
    function addRewardToken(
        uint256 farmId,
        address rewardToken,
        uint256 rewardRate
    ) external;
    
    function removeRewardToken(
        uint256 farmId,
        address rewardToken
    ) external;
    
    function updateRewardRate(
        uint256 farmId,
        address rewardToken,
        uint256 newRate
    ) external;
    
    function distributeRewards(
        uint256 farmId
    ) external;
    
    function recoverRewardTokens(
        uint256 farmId,
        address rewardToken,
        uint256 amount
    ) external;
    
    // Boost functions
    function activateBoost(
        uint256 farmId,
        BoostType boostType
    ) external;
    
    function deactivateBoost(
        uint256 farmId,
        BoostType boostType
    ) external;
    
    function updateBoostConfig(
        BoostType boostType,
        BoostConfig calldata newConfig
    ) external;
    
    function calculateBoostMultiplier(
        uint256 farmId,
        address user
    ) external view returns (uint256 multiplier);
    
    // Lockup functions
    function createLockup(
        uint256 farmId,
        uint256 amount,
        uint256 lockupPeriod
    ) external returns (uint256 lockupId);
    
    function extendLockup(
        uint256 farmId,
        uint256 lockupId,
        uint256 additionalPeriod
    ) external;
    
    function unlockEarly(
        uint256 farmId,
        uint256 lockupId
    ) external;
    
    function updateLockupConfig(
        LockupConfig calldata newConfig
    ) external;
    
    // Vesting functions
    function createVestingSchedule(
        uint256 farmId,
        address user,
        address token,
        uint256 amount,
        uint256 vestingPeriod,
        uint256 cliffPeriod
    ) external;
    
    function releaseVestedTokens(
        uint256 farmId,
        address token
    ) external;
    
    function revokeVesting(
        uint256 farmId,
        address user,
        address token
    ) external;
    
    function accelerateVesting(
        uint256 farmId,
        address token,
        uint256 amount
    ) external;
    
    // Strategy functions
    function createYieldStrategy(
        string calldata name,
        address targetToken,
        address[] calldata inputTokens,
        uint256[] calldata allocations,
        StrategyConfig calldata config
    ) external returns (uint256 strategyId);
    
    function executeStrategy(
        uint256 strategyId,
        uint256 amount
    ) external;
    
    function rebalanceStrategy(
        uint256 strategyId
    ) external;
    
    function updateStrategyConfig(
        uint256 strategyId,
        StrategyConfig calldata newConfig
    ) external;
    
    function pauseStrategy(
        uint256 strategyId
    ) external;
    
    function closeStrategy(
        uint256 strategyId
    ) external;
    
    // Configuration functions
    function updateFarmConfig(
        uint256 farmId,
        FarmConfig calldata newConfig
    ) external;
    
    function setFarmManager(
        uint256 farmId,
        address manager,
        bool authorized
    ) external;
    
    function updateGlobalConfig(
        string calldata parameter,
        uint256 value
    ) external;
    
    function setWhitelist(
        uint256 farmId,
        address[] calldata users,
        bool whitelisted
    ) external;
    
    // Emergency functions
    function emergencyPause(
        string calldata reason
    ) external;
    
    function emergencyUnpause() external;
    
    function emergencyRecoverTokens(
        address token,
        uint256 amount
    ) external;
    
    function forceUnstake(
        uint256 farmId,
        address user,
        string calldata reason
    ) external;
    
    // View functions - Farms
    function getFarm(
        uint256 farmId
    ) external view returns (Farm memory);
    
    function getAllFarms() external view returns (uint256[] memory);
    
    function getActiveFarms() external view returns (uint256[] memory);
    
    function getFarmsByToken(
        address token
    ) external view returns (uint256[] memory);
    
    function isFarmActive(
        uint256 farmId
    ) external view returns (bool active);
    
    function getFarmConfig(
        uint256 farmId
    ) external view returns (FarmConfig memory);
    
    function getFarmMetrics(
        uint256 farmId
    ) external view returns (FarmMetrics memory);
    
    function getTotalStaked(
        uint256 farmId
    ) external view returns (uint256 totalStaked);
    
    function getFarmAPY(
        uint256 farmId
    ) external view returns (uint256 apy);
    
    // View functions - User info
    function getUserInfo(
        uint256 farmId,
        address user
    ) external view returns (UserInfo memory);
    
    function getUserStakedAmount(
        uint256 farmId,
        address user
    ) external view returns (uint256 stakedAmount);
    
    function getPendingRewards(
        uint256 farmId,
        address user
    ) external view returns (address[] memory tokens, uint256[] memory amounts);
    
    function getPendingRewards(
        uint256 farmId,
        address user,
        address rewardToken
    ) external view returns (uint256 pendingAmount);
    
    function getUserMetrics(
        uint256 farmId,
        address user
    ) external view returns (UserMetrics memory);
    
    function getUserBoosts(
        uint256 farmId,
        address user
    ) external view returns (UserBoosts memory);
    
    function getUserLockups(
        uint256 farmId,
        address user
    ) external view returns (UserLockups memory);
    
    function getUserVesting(
        uint256 farmId,
        address user
    ) external view returns (UserVesting memory);
    
    // View functions - Rewards
    function getRewardInfo(
        uint256 farmId,
        address rewardToken
    ) external view returns (RewardInfo memory);
    
    function getRewardTokens(
        uint256 farmId
    ) external view returns (address[] memory);
    
    function getRewardRate(
        uint256 farmId,
        address rewardToken
    ) external view returns (uint256 rate);
    
    function getRemainingRewards(
        uint256 farmId,
        address rewardToken
    ) external view returns (uint256 remaining);
    
    function calculateRewards(
        uint256 farmId,
        address user,
        uint256 timeframe
    ) external view returns (uint256[] memory rewards);
    
    // View functions - Boosts
    function getBoostInfo(
        uint256 farmId,
        address user,
        BoostType boostType
    ) external view returns (BoostInfo memory);
    
    function getActiveBoosts(
        uint256 farmId,
        address user
    ) external view returns (BoostType[] memory);
    
    function getBoostMultiplier(
        uint256 farmId,
        address user
    ) external view returns (uint256 multiplier);
    
    function getBoostConfig(
        BoostType boostType
    ) external view returns (BoostConfig memory);
    
    // View functions - Lockups
    function getLockupInfo(
        uint256 farmId,
        address user,
        uint256 lockupId
    ) external view returns (LockupInfo memory);
    
    function getUserLockupIds(
        uint256 farmId,
        address user
    ) external view returns (uint256[] memory);
    
    function getTotalLockedAmount(
        uint256 farmId,
        address user
    ) external view returns (uint256 totalLocked);
    
    function getLockupMultiplier(
        uint256 farmId,
        address user
    ) external view returns (uint256 multiplier);
    
    // View functions - Vesting
    function getVestingSchedule(
        uint256 farmId,
        address user,
        address token
    ) external view returns (VestingSchedule memory);
    
    function getVestableAmount(
        uint256 farmId,
        address user,
        address token
    ) external view returns (uint256 vestableAmount);
    
    function getVestingTokens(
        uint256 farmId,
        address user
    ) external view returns (address[] memory);
    
    // View functions - Strategies
    function getYieldStrategy(
        uint256 strategyId
    ) external view returns (YieldStrategy memory);
    
    function getAllStrategies() external view returns (uint256[] memory);
    
    function getActiveStrategies() external view returns (uint256[] memory);
    
    function getStrategyMetrics(
        uint256 strategyId
    ) external view returns (StrategyMetrics memory);
    
    function getStrategyAPY(
        uint256 strategyId
    ) external view returns (uint256 apy);
    
    // View functions - Analytics
    function getYieldFarmingAnalytics() external view returns (YieldFarmingAnalytics memory);
    
    function getFarmAnalytics(
        uint256 farmId,
        uint256 timeframe
    ) external view returns (
        uint256 totalStaked,
        uint256 totalRewards,
        uint256 averageAPY,
        uint256 userCount
    );
    
    function getUserAnalytics(
        address user,
        uint256 timeframe
    ) external view returns (
        uint256 totalStaked,
        uint256 totalRewards,
        uint256 averageAPY,
        uint256 farmCount
    );
    
    function getSystemHealth() external view returns (
        uint256 totalTVL,
        uint256 totalFarms,
        uint256 totalUsers,
        uint256 averageAPY
    );
}
