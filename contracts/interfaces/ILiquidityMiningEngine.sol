// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title ILiquidityMiningEngine
 * @dev Interface for the Liquidity Mining Engine contract
 * @author CoreLiquid Protocol
 */
interface ILiquidityMiningEngine {
    // Events
    event MiningPoolCreated(
        bytes32 indexed poolId,
        address indexed creator,
        address indexed stakingToken,
        address rewardToken,
        uint256 rewardRate,
        uint256 duration,
        uint256 timestamp
    );
    
    event LiquidityStaked(
        bytes32 indexed poolId,
        address indexed user,
        uint256 amount,
        uint256 shares,
        uint256 timestamp
    );
    
    event LiquidityUnstaked(
        bytes32 indexed poolId,
        address indexed user,
        uint256 amount,
        uint256 shares,
        uint256 timestamp
    );
    
    event RewardsHarvested(
        bytes32 indexed poolId,
        address indexed user,
        uint256 rewardAmount,
        uint256 timestamp
    );
    
    event RewardsCompounded(
        bytes32 indexed poolId,
        address indexed user,
        uint256 compoundedAmount,
        uint256 newShares,
        uint256 timestamp
    );
    
    event PoolRewardsAdded(
        bytes32 indexed poolId,
        uint256 rewardAmount,
        uint256 newEndTime,
        uint256 timestamp
    );
    
    event BoostActivated(
        bytes32 indexed poolId,
        address indexed user,
        uint256 boostMultiplier,
        uint256 duration,
        uint256 timestamp
    );
    
    event MultiplierUpdated(
        bytes32 indexed poolId,
        address indexed user,
        uint256 oldMultiplier,
        uint256 newMultiplier,
        uint256 timestamp
    );
    
    event EmergencyWithdrawal(
        bytes32 indexed poolId,
        address indexed user,
        uint256 amount,
        uint256 timestamp
    );
    
    event PoolStatusChanged(
        bytes32 indexed poolId,
        PoolStatus oldStatus,
        PoolStatus newStatus,
        uint256 timestamp
    );
    
    event VestingScheduleCreated(
        bytes32 indexed scheduleId,
        address indexed user,
        uint256 totalAmount,
        uint256 duration,
        uint256 timestamp
    );

    // Structs
    struct MiningPool {
        bytes32 poolId;
        string name;
        address stakingToken;
        address rewardToken;
        uint256 totalStaked;
        uint256 totalShares;
        uint256 rewardRate;
        uint256 rewardPerTokenStored;
        uint256 lastUpdateTime;
        uint256 startTime;
        uint256 endTime;
        uint256 minStakeAmount;
        uint256 maxStakeAmount;
        uint256 lockPeriod;
        PoolStatus status;
        bool isActive;
        bool allowCompounding;
        bool allowEarlyWithdrawal;
        uint256 earlyWithdrawalFee;
        uint256 performanceFee;
        address feeRecipient;
    }
    
    struct UserStake {
        bytes32 poolId;
        address user;
        uint256 stakedAmount;
        uint256 shares;
        uint256 rewardPerTokenPaid;
        uint256 rewards;
        uint256 stakedAt;
        uint256 lastHarvestAt;
        uint256 lockUntil;
        uint256 boostMultiplier;
        uint256 boostEndTime;
        bool autoCompound;
        uint256 totalHarvested;
        uint256 totalCompounded;
    }
    
    struct RewardDistribution {
        bytes32 distributionId;
        bytes32 poolId;
        uint256 totalRewards;
        uint256 distributedRewards;
        uint256 remainingRewards;
        uint256 distributionRate;
        uint256 startTime;
        uint256 endTime;
        bool isActive;
        bool isCompleted;
    }
    
    struct BoostConfig {
        bytes32 boostId;
        string name;
        uint256 multiplier;
        uint256 duration;
        uint256 cost;
        address costToken;
        uint256 maxUses;
        uint256 currentUses;
        bool isActive;
        bool isTransferable;
    }
    
    struct VestingSchedule {
        bytes32 scheduleId;
        address user;
        uint256 totalAmount;
        uint256 vestedAmount;
        uint256 claimedAmount;
        uint256 startTime;
        uint256 duration;
        uint256 cliffPeriod;
        VestingType vestingType;
        bool isRevocable;
        bool isRevoked;
    }
    
    struct MiningMetrics {
        uint256 totalPools;
        uint256 activePools;
        uint256 totalValueLocked;
        uint256 totalRewardsDistributed;
        uint256 totalUsers;
        uint256 averageAPR;
        uint256 totalHarvests;
        uint256 totalCompounds;
        uint256 lastUpdate;
    }
    
    struct PoolPerformance {
        bytes32 poolId;
        uint256 totalStaked;
        uint256 totalRewards;
        uint256 currentAPR;
        uint256 averageAPR;
        uint256 totalUsers;
        uint256 averageStakeSize;
        uint256 retentionRate;
        uint256 lastUpdate;
    }
    
    struct UserPerformance {
        address user;
        uint256 totalStaked;
        uint256 totalRewards;
        uint256 totalPools;
        uint256 averageAPR;
        uint256 totalHarvests;
        uint256 totalCompounds;
        uint256 lastActivity;
    }

    // Enums
    enum PoolStatus {
        PENDING,
        ACTIVE,
        PAUSED,
        ENDED,
        EMERGENCY
    }
    
    enum VestingType {
        LINEAR,
        CLIFF,
        STEPPED,
        EXPONENTIAL
    }

    // Core mining functions
    function createMiningPool(
        string calldata name,
        address stakingToken,
        address rewardToken,
        uint256 rewardAmount,
        uint256 duration,
        uint256 minStakeAmount,
        uint256 lockPeriod
    ) external returns (bytes32 poolId);
    
    function stakeLiquidity(
        bytes32 poolId,
        uint256 amount
    ) external returns (uint256 shares);
    
    function unstakeLiquidity(
        bytes32 poolId,
        uint256 shares
    ) external returns (uint256 amount);
    
    function harvestRewards(
        bytes32 poolId
    ) external returns (uint256 rewardAmount);
    
    function compoundRewards(
        bytes32 poolId
    ) external returns (uint256 compoundedAmount);
    
    function emergencyWithdraw(
        bytes32 poolId
    ) external returns (uint256 amount);
    
    // Advanced mining functions
    function stakeWithBoost(
        bytes32 poolId,
        uint256 amount,
        bytes32 boostId
    ) external returns (uint256 shares, uint256 boostMultiplier);
    
    function batchHarvest(
        bytes32[] calldata poolIds
    ) external returns (uint256[] memory rewardAmounts);
    
    function batchCompound(
        bytes32[] calldata poolIds
    ) external returns (uint256[] memory compoundedAmounts);
    
    function autoCompoundRewards(
        bytes32 poolId,
        bool enabled
    ) external;
    
    function migrateStake(
        bytes32 fromPoolId,
        bytes32 toPoolId,
        uint256 shares
    ) external returns (uint256 newShares);
    
    function extendStakeLock(
        bytes32 poolId,
        uint256 additionalLockTime
    ) external;
    
    // Pool management
    function addPoolRewards(
        bytes32 poolId,
        uint256 rewardAmount,
        uint256 additionalDuration
    ) external;
    
    function updatePoolRewardRate(
        bytes32 poolId,
        uint256 newRewardRate
    ) external;
    
    function pausePool(
        bytes32 poolId
    ) external;
    
    function unpausePool(
        bytes32 poolId
    ) external;
    
    function endPool(
        bytes32 poolId
    ) external;
    
    function updatePoolParameters(
        bytes32 poolId,
        uint256 minStakeAmount,
        uint256 maxStakeAmount,
        uint256 lockPeriod,
        uint256 performanceFee
    ) external;
    
    function setPoolEmergencyMode(
        bytes32 poolId,
        bool enabled
    ) external;
    
    // Boost system
    function createBoost(
        string calldata name,
        uint256 multiplier,
        uint256 duration,
        uint256 cost,
        address costToken,
        uint256 maxUses
    ) external returns (bytes32 boostId);
    
    function activateBoost(
        bytes32 poolId,
        bytes32 boostId
    ) external;
    
    function transferBoost(
        bytes32 boostId,
        address to
    ) external;
    
    function updateBoostConfig(
        bytes32 boostId,
        uint256 newMultiplier,
        uint256 newDuration,
        uint256 newCost
    ) external;
    
    function deactivateBoost(
        bytes32 boostId
    ) external;
    
    // Vesting system
    function createVestingSchedule(
        address user,
        uint256 totalAmount,
        uint256 duration,
        uint256 cliffPeriod,
        VestingType vestingType
    ) external returns (bytes32 scheduleId);
    
    function claimVestedTokens(
        bytes32 scheduleId
    ) external returns (uint256 claimedAmount);
    
    function revokeVesting(
        bytes32 scheduleId
    ) external;
    
    function updateVestingSchedule(
        bytes32 scheduleId,
        uint256 newDuration,
        uint256 newCliffPeriod
    ) external;
    
    function transferVesting(
        bytes32 scheduleId,
        address newBeneficiary
    ) external;
    
    // Reward distribution
    function createRewardDistribution(
        bytes32 poolId,
        uint256 totalRewards,
        uint256 duration
    ) external returns (bytes32 distributionId);
    
    function updateRewardDistribution(
        bytes32 distributionId,
        uint256 newRate
    ) external;
    
    function pauseRewardDistribution(
        bytes32 distributionId
    ) external;
    
    function resumeRewardDistribution(
        bytes32 distributionId
    ) external;
    
    function endRewardDistribution(
        bytes32 distributionId
    ) external;
    
    // Configuration functions
    function setGlobalParameters(
        uint256 maxPoolsPerUser,
        uint256 maxBoostsPerUser,
        uint256 defaultPerformanceFee,
        address defaultFeeRecipient
    ) external;
    
    function setEmergencyMode(
        bool enabled
    ) external;
    
    function setAutoCompoundEnabled(
        bool enabled
    ) external;
    
    function setMinimumStakePeriod(
        uint256 period
    ) external;
    
    function setMaximumBoostMultiplier(
        uint256 multiplier
    ) external;
    
    // Emergency functions
    function emergencyPauseAll() external;
    
    function emergencyUnpauseAll() external;
    
    function emergencyWithdrawPoolRewards(
        bytes32 poolId,
        address to
    ) external;
    
    function emergencyStopRewards(
        bytes32 poolId
    ) external;
    
    function emergencyMigratePool(
        bytes32 poolId,
        address newContract
    ) external;
    
    // View functions - Pool information
    function getMiningPool(
        bytes32 poolId
    ) external view returns (MiningPool memory);
    
    function getUserStake(
        bytes32 poolId,
        address user
    ) external view returns (UserStake memory);
    
    function getAllPools() external view returns (bytes32[] memory);
    
    function getActivePools() external view returns (bytes32[] memory);
    
    function getUserPools(
        address user
    ) external view returns (bytes32[] memory);
    
    function getPoolsByToken(
        address token
    ) external view returns (bytes32[] memory);
    
    // View functions - Reward calculations
    function calculatePendingRewards(
        bytes32 poolId,
        address user
    ) external view returns (uint256 pendingRewards);
    
    function calculateRewardRate(
        bytes32 poolId
    ) external view returns (uint256 rewardRate);
    
    function calculateAPR(
        bytes32 poolId
    ) external view returns (uint256 apr);
    
    function calculateUserAPR(
        bytes32 poolId,
        address user
    ) external view returns (uint256 userAPR);
    
    function estimateRewards(
        bytes32 poolId,
        uint256 amount,
        uint256 duration
    ) external view returns (uint256 estimatedRewards);
    
    function calculateCompoundRewards(
        bytes32 poolId,
        address user,
        uint256 periods
    ) external view returns (uint256 compoundedRewards);
    
    // View functions - Boost information
    function getBoostConfig(
        bytes32 boostId
    ) external view returns (BoostConfig memory);
    
    function getUserBoosts(
        address user
    ) external view returns (bytes32[] memory);
    
    function getActiveBoosts() external view returns (bytes32[] memory);
    
    function getUserBoostMultiplier(
        bytes32 poolId,
        address user
    ) external view returns (uint256 multiplier, uint256 endTime);
    
    function calculateBoostCost(
        bytes32 boostId,
        uint256 duration
    ) external view returns (uint256 cost);
    
    // View functions - Vesting information
    function getVestingSchedule(
        bytes32 scheduleId
    ) external view returns (VestingSchedule memory);
    
    function getUserVestingSchedules(
        address user
    ) external view returns (bytes32[] memory);
    
    function calculateVestedAmount(
        bytes32 scheduleId
    ) external view returns (uint256 vestedAmount);
    
    function calculateClaimableAmount(
        bytes32 scheduleId
    ) external view returns (uint256 claimableAmount);
    
    function getVestingProgress(
        bytes32 scheduleId
    ) external view returns (uint256 progressPercentage);
    
    // View functions - Distribution information
    function getRewardDistribution(
        bytes32 distributionId
    ) external view returns (RewardDistribution memory);
    
    function getPoolDistributions(
        bytes32 poolId
    ) external view returns (bytes32[] memory);
    
    function getActiveDistributions() external view returns (bytes32[] memory);
    
    function calculateDistributionProgress(
        bytes32 distributionId
    ) external view returns (uint256 progressPercentage);
    
    // View functions - Performance metrics
    function getMiningMetrics() external view returns (MiningMetrics memory);
    
    function getPoolPerformance(
        bytes32 poolId
    ) external view returns (PoolPerformance memory);
    
    function getUserPerformance(
        address user
    ) external view returns (UserPerformance memory);
    
    function getTopPerformingPools(
        uint256 count
    ) external view returns (bytes32[] memory poolIds, uint256[] memory aprs);
    
    function getPoolRanking() external view returns (
        bytes32[] memory poolIds,
        uint256[] memory scores
    );
    
    // View functions - Staking information
    function getTotalStaked(
        bytes32 poolId
    ) external view returns (uint256 totalStaked);
    
    function getUserTotalStaked(
        address user
    ) external view returns (uint256 totalStaked);
    
    function getPoolUtilization(
        bytes32 poolId
    ) external view returns (uint256 utilizationRate);
    
    function getStakeValue(
        bytes32 poolId,
        address user
    ) external view returns (uint256 stakeValue);
    
    function canUnstake(
        bytes32 poolId,
        address user,
        uint256 shares
    ) external view returns (bool canUnstake, uint256 lockTimeRemaining);
    
    // View functions - Pool capacity and limits
    function getPoolCapacity(
        bytes32 poolId
    ) external view returns (uint256 maxCapacity, uint256 currentUtilization);
    
    function getMaxStakeAmount(
        bytes32 poolId,
        address user
    ) external view returns (uint256 maxAmount);
    
    function getMinStakeAmount(
        bytes32 poolId
    ) external view returns (uint256 minAmount);
    
    function canStake(
        bytes32 poolId,
        address user,
        uint256 amount
    ) external view returns (bool);
    
    function getRemainingRewards(
        bytes32 poolId
    ) external view returns (uint256 remainingRewards);
    
    // View functions - Time information
    function getPoolTimeRemaining(
        bytes32 poolId
    ) external view returns (uint256 timeRemaining);
    
    function getUserLockTimeRemaining(
        bytes32 poolId,
        address user
    ) external view returns (uint256 lockTimeRemaining);
    
    function isPoolActive(
        bytes32 poolId
    ) external view returns (bool);
    
    function isPoolEnded(
        bytes32 poolId
    ) external view returns (bool);
    
    function getNextHarvestTime(
        bytes32 poolId,
        address user
    ) external view returns (uint256 nextHarvestTime);
    
    // View functions - Configuration
    function getGlobalParameters() external view returns (
        uint256 maxPoolsPerUser,
        uint256 maxBoostsPerUser,
        uint256 defaultPerformanceFee,
        address defaultFeeRecipient
    );
    
    function isEmergencyMode() external view returns (bool);
    
    function isAutoCompoundEnabled() external view returns (bool);
    
    function getMinimumStakePeriod() external view returns (uint256);
    
    function getMaximumBoostMultiplier() external view returns (uint256);
    
    // View functions - System health
    function isSystemHealthy() external view returns (bool);
    
    function getSystemHealth() external view returns (
        bool isHealthy,
        uint256 liquidityHealth,
        uint256 rewardHealth,
        uint256 performanceHealth
    );
    
    function getPoolHealth(
        bytes32 poolId
    ) external view returns (
        bool isHealthy,
        uint256 liquidityLevel,
        uint256 rewardLevel,
        uint256 userActivity
    );
}
