// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title CoreBitcoinDualStaking
 * @dev Core-native Bitcoin dual staking with Satoshi Plus validator integration
 * @author CoreLiquid Team
 */
contract CoreBitcoinDualStaking is ReentrancyGuard, AccessControl, Pausable {
    using SafeERC20 for IERC20;

    // Roles
    bytes32 public constant VALIDATOR_ROLE = keccak256("VALIDATOR_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");

    // Core and BTC token interfaces
    IERC20 public immutable coreToken;
    IERC20 public immutable btcToken; // Wrapped BTC or equivalent

    // Staking parameters
    uint256 public constant MIN_CORE_STAKE = 1000 * 1e18; // 1000 CORE
    uint256 public constant MIN_BTC_STAKE = 1e16; // 0.01 BTC
    uint256 public constant DUAL_STAKE_BONUS = 150; // 1.5x bonus for dual staking
    uint256 public constant BASE_PERCENTAGE = 100;
    uint256 public constant REWARD_PRECISION = 1e18;

    // Validator info
    struct ValidatorInfo {
        address validatorAddress;
        uint256 totalCoreStaked;
        uint256 totalBtcStaked;
        uint256 commission; // Basis points (100 = 1%)
        bool isActive;
        uint256 reputationScore;
        uint256 lastRewardDistribution;
    }

    // Dual stake info
    struct DualStakeInfo {
        uint256 coreAmount;
        uint256 btcAmount;
        uint256 validatorId;
        uint256 startTime;
        uint256 lastRewardClaim;
        uint256 accumulatedCoreRewards;
        uint256 accumulatedBtcRewards;
        bool isActive;
    }

    // State variables
    mapping(uint256 => ValidatorInfo) public validators;
    mapping(address => DualStakeInfo) public userStakes;
    mapping(address => uint256[]) public userValidatorHistory;
    
    uint256 public nextValidatorId = 1;
    uint256 public totalCoreStaked;
    uint256 public totalBtcStaked;
    uint256 public totalActiveStakers;
    
    // Reward pools
    uint256 public coreRewardPool;
    uint256 public btcRewardPool;
    uint256 public dailyRewardRate = 100; // 1% daily base rate
    
    // Satoshi Plus specific
    uint256 public epochDuration = 1 days;
    uint256 public currentEpoch;
    uint256 public lastEpochUpdate;
    
    mapping(uint256 => mapping(address => uint256)) public epochStakeSnapshots;
    mapping(uint256 => uint256) public epochTotalStake;

    // Events
    event DualStakeActivated(
        address indexed user,
        uint256 coreAmount,
        uint256 btcAmount,
        uint256 validatorId
    );
    
    event RewardsHarvested(
        address indexed user,
        uint256 coreRewards,
        uint256 btcRewards
    );
    
    event ValidatorRegistered(
        uint256 indexed validatorId,
        address indexed validator,
        uint256 commission
    );
    
    event ValidatorDelegated(
        address indexed user,
        uint256 indexed validatorId,
        uint256 coreAmount,
        uint256 btcAmount
    );
    
    event EpochAdvanced(uint256 newEpoch, uint256 timestamp);
    
    event EmergencyWithdraw(
        address indexed user,
        uint256 coreAmount,
        uint256 btcAmount
    );

    constructor(
        address _coreToken,
        address _btcToken
    ) {
        require(_coreToken != address(0), "Invalid CORE token");
        require(_btcToken != address(0), "Invalid BTC token");
        
        coreToken = IERC20(_coreToken);
        btcToken = IERC20(_btcToken);
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(OPERATOR_ROLE, msg.sender);
        _grantRole(EMERGENCY_ROLE, msg.sender);
        
        currentEpoch = 1;
        lastEpochUpdate = block.timestamp;
    }

    /**
     * @dev Activate dual staking with CORE and BTC delegation to validator
     * @param coreAmount Amount of CORE tokens to stake
     * @param btcAmount Amount of BTC tokens to stake
     * @param validatorId ID of the validator to delegate to
     */
    function activateDualStake(
        uint256 coreAmount,
        uint256 btcAmount,
        uint256 validatorId
    ) external nonReentrant whenNotPaused {
        require(coreAmount >= MIN_CORE_STAKE, "Insufficient CORE amount");
        require(btcAmount >= MIN_BTC_STAKE, "Insufficient BTC amount");
        require(validators[validatorId].isActive, "Validator not active");
        require(!userStakes[msg.sender].isActive, "Already staking");
        
        // Update epoch if needed
        _updateEpoch();
        
        // Transfer tokens
        coreToken.safeTransferFrom(msg.sender, address(this), coreAmount);
        btcToken.safeTransferFrom(msg.sender, address(this), btcAmount);
        
        // Update user stake info
        userStakes[msg.sender] = DualStakeInfo({
            coreAmount: coreAmount,
            btcAmount: btcAmount,
            validatorId: validatorId,
            startTime: block.timestamp,
            lastRewardClaim: block.timestamp,
            accumulatedCoreRewards: 0,
            accumulatedBtcRewards: 0,
            isActive: true
        });
        
        // Update validator stats
        validators[validatorId].totalCoreStaked = validators[validatorId].totalCoreStaked + coreAmount;
        validators[validatorId].totalBtcStaked = validators[validatorId].totalBtcStaked + btcAmount;
        
        // Update global stats
        totalCoreStaked = totalCoreStaked + coreAmount;
        totalBtcStaked = totalBtcStaked + btcAmount;
        totalActiveStakers = totalActiveStakers + 1;
        
        // Record epoch snapshot
        epochStakeSnapshots[currentEpoch][msg.sender] = coreAmount + btcAmount;
        epochTotalStake[currentEpoch] = epochTotalStake[currentEpoch] + coreAmount + btcAmount;
        
        // Add to user's validator history
        userValidatorHistory[msg.sender].push(validatorId);
        
        emit DualStakeActivated(msg.sender, coreAmount, btcAmount, validatorId);
        emit ValidatorDelegated(msg.sender, validatorId, coreAmount, btcAmount);
    }

    /**
     * @dev Harvest accumulated rewards from dual staking
     */
    function harvestRewards() external nonReentrant whenNotPaused {
        DualStakeInfo storage stake = userStakes[msg.sender];
        require(stake.isActive, "No active stake");
        
        // Update epoch if needed
        _updateEpoch();
        
        // Calculate rewards
        (uint256 coreRewards, uint256 btcRewards) = _calculateRewards(msg.sender);
        
        require(coreRewards > 0 || btcRewards > 0, "No rewards available");
        
        // Update accumulated rewards
        stake.accumulatedCoreRewards = stake.accumulatedCoreRewards + coreRewards;
        stake.accumulatedBtcRewards = stake.accumulatedBtcRewards + btcRewards;
        stake.lastRewardClaim = block.timestamp;
        
        // Transfer rewards
        if (coreRewards > 0 && coreRewardPool >= coreRewards) {
            coreRewardPool = coreRewardPool - coreRewards;
            coreToken.safeTransfer(msg.sender, coreRewards);
        }
        
        if (btcRewards > 0 && btcRewardPool >= btcRewards) {
            btcRewardPool = btcRewardPool - btcRewards;
            btcToken.safeTransfer(msg.sender, btcRewards);
        }
        
        // Update validator's last reward distribution
        validators[stake.validatorId].lastRewardDistribution = block.timestamp;
        
        emit RewardsHarvested(msg.sender, coreRewards, btcRewards);
    }

    /**
     * @dev Register a new validator
     * @param validatorAddress Address of the validator
     * @param commission Commission rate in basis points
     */
    function registerValidator(
        address validatorAddress,
        uint256 commission
    ) external onlyRole(OPERATOR_ROLE) {
        require(validatorAddress != address(0), "Invalid validator address");
        require(commission <= 2000, "Commission too high"); // Max 20%
        
        uint256 validatorId = nextValidatorId++;
        
        validators[validatorId] = ValidatorInfo({
            validatorAddress: validatorAddress,
            totalCoreStaked: 0,
            totalBtcStaked: 0,
            commission: commission,
            isActive: true,
            reputationScore: 100, // Start with 100% reputation
            lastRewardDistribution: block.timestamp
        });
        
        _grantRole(VALIDATOR_ROLE, validatorAddress);
        
        emit ValidatorRegistered(validatorId, validatorAddress, commission);
    }

    /**
     * @dev Unstake and withdraw both CORE and BTC
     */
    function unstake() external nonReentrant {
        DualStakeInfo storage stake = userStakes[msg.sender];
        require(stake.isActive, "No active stake");
        
        // Harvest any pending rewards first
        (uint256 coreRewards, uint256 btcRewards) = _calculateRewards(msg.sender);
        if (coreRewards > 0 || btcRewards > 0) {
            this.harvestRewards();
        }
        
        uint256 coreAmount = stake.coreAmount;
        uint256 btcAmount = stake.btcAmount;
        uint256 validatorId = stake.validatorId;
        
        // Update validator stats
        validators[validatorId].totalCoreStaked = validators[validatorId].totalCoreStaked - coreAmount;
        validators[validatorId].totalBtcStaked = validators[validatorId].totalBtcStaked - btcAmount;
        
        // Update global stats
        totalCoreStaked = totalCoreStaked - coreAmount;
        totalBtcStaked = totalBtcStaked - btcAmount;
        totalActiveStakers = totalActiveStakers - 1;
        
        // Clear user stake
        delete userStakes[msg.sender];
        
        // Transfer tokens back
        coreToken.safeTransfer(msg.sender, coreAmount);
        btcToken.safeTransfer(msg.sender, btcAmount);
        
        emit EmergencyWithdraw(msg.sender, coreAmount, btcAmount);
    }

    /**
     * @dev Add rewards to the pools
     * @param coreAmount Amount of CORE rewards to add
     * @param btcAmount Amount of BTC rewards to add
     */
    function addRewards(
        uint256 coreAmount,
        uint256 btcAmount
    ) external onlyRole(OPERATOR_ROLE) {
        if (coreAmount > 0) {
            coreToken.safeTransferFrom(msg.sender, address(this), coreAmount);
            coreRewardPool = coreRewardPool + coreAmount;
        }
        
        if (btcAmount > 0) {
            btcToken.safeTransferFrom(msg.sender, address(this), btcAmount);
            btcRewardPool = btcRewardPool + btcAmount;
        }
    }

    /**
     * @dev Calculate pending rewards for a user
     * @param user Address of the user
     * @return coreRewards Pending CORE rewards
     * @return btcRewards Pending BTC rewards
     */
    function _calculateRewards(address user) internal view returns (uint256 coreRewards, uint256 btcRewards) {
        DualStakeInfo storage stake = userStakes[user];
        if (!stake.isActive) return (0, 0);
        
        uint256 stakingDuration = block.timestamp - stake.lastRewardClaim;
        uint256 dailyRewards = stakingDuration / 1 days;
        
        if (dailyRewards == 0) return (0, 0);
        
        ValidatorInfo storage validator = validators[stake.validatorId];
        
        // Base rewards calculation
        uint256 baseCoreReward = stake.coreAmount * dailyRewardRate * dailyRewards / 10000;
        uint256 baseBtcReward = stake.btcAmount * dailyRewardRate * dailyRewards / 10000;
        
        // Apply dual staking bonus
        baseCoreReward = baseCoreReward * DUAL_STAKE_BONUS / BASE_PERCENTAGE;
        baseBtcReward = baseBtcReward * DUAL_STAKE_BONUS / BASE_PERCENTAGE;
        
        // Apply validator commission
        uint256 commission = validator.commission;
        coreRewards = baseCoreReward * (10000 - commission) / 10000;
        btcRewards = baseBtcReward * (10000 - commission) / 10000;
        
        // Apply reputation multiplier
        uint256 reputationMultiplier = validator.reputationScore;
        coreRewards = coreRewards * reputationMultiplier / 100;
        btcRewards = btcRewards * reputationMultiplier / 100;
    }

    /**
     * @dev Update epoch if duration has passed
     */
    function _updateEpoch() internal {
        if (block.timestamp >= lastEpochUpdate + epochDuration) {
            currentEpoch = currentEpoch + 1;
            lastEpochUpdate = block.timestamp;
            emit EpochAdvanced(currentEpoch, block.timestamp);
        }
    }

    /**
     * @dev Get user's staking information
     * @param user Address of the user
     * @return Dual stake information
     */
    function getUserStakeInfo(address user) external view returns (DualStakeInfo memory) {
        return userStakes[user];
    }

    /**
     * @dev Get validator information
     * @param validatorId ID of the validator
     * @return Validator information
     */
    function getValidatorInfo(uint256 validatorId) external view returns (ValidatorInfo memory) {
        return validators[validatorId];
    }

    /**
     * @dev Get pending rewards for a user
     * @param user Address of the user
     * @return coreRewards Pending CORE rewards
     * @return btcRewards Pending BTC rewards
     */
    function getPendingRewards(address user) external view returns (uint256 coreRewards, uint256 btcRewards) {
        return _calculateRewards(user);
    }

    /**
     * @dev Get total staking statistics
     * @return Total CORE staked, total BTC staked, total active stakers
     */
    function getTotalStats() external view returns (uint256, uint256, uint256) {
        return (totalCoreStaked, totalBtcStaked, totalActiveStakers);
    }

    /**
     * @dev Get user's validator delegation history
     * @param user Address of the user
     * @return Array of validator IDs
     */
    function getUserValidatorHistory(address user) external view returns (uint256[] memory) {
        return userValidatorHistory[user];
    }

    /**
     * @dev Emergency pause function
     */
    function emergencyPause() external onlyRole(EMERGENCY_ROLE) {
        _pause();
    }

    /**
     * @dev Emergency unpause function
     */
    function emergencyUnpause() external onlyRole(EMERGENCY_ROLE) {
        _unpause();
    }

    /**
     * @dev Update daily reward rate
     * @param newRate New daily reward rate in basis points
     */
    function updateDailyRewardRate(uint256 newRate) external onlyRole(OPERATOR_ROLE) {
        require(newRate <= 1000, "Rate too high"); // Max 10% daily
        dailyRewardRate = newRate;
    }

    /**
     * @dev Update validator reputation score
     * @param validatorId ID of the validator
     * @param newScore New reputation score (0-100)
     */
    function updateValidatorReputation(
        uint256 validatorId,
        uint256 newScore
    ) external onlyRole(OPERATOR_ROLE) {
        require(newScore <= 100, "Score too high");
        require(validators[validatorId].isActive, "Validator not active");
        validators[validatorId].reputationScore = newScore;
    }

    /**
     * @dev Deactivate a validator
     * @param validatorId ID of the validator to deactivate
     */
    function deactivateValidator(uint256 validatorId) external onlyRole(OPERATOR_ROLE) {
        validators[validatorId].isActive = false;
    }

    /**
     * @dev Get current epoch information
     * @return Current epoch number and last update timestamp
     */
    function getCurrentEpochInfo() external view returns (uint256, uint256) {
        return (currentEpoch, lastEpochUpdate);
    }

    /**
     * @dev Get epoch stake snapshot for user
     * @param epoch Epoch number
     * @param user User address
     * @return Stake amount in that epoch
     */
    function getEpochStakeSnapshot(uint256 epoch, address user) external view returns (uint256) {
        return epochStakeSnapshots[epoch][user];
    }

    /**
     * @dev Get total stake for an epoch
     * @param epoch Epoch number
     * @return Total stake amount in that epoch
     */
    function getEpochTotalStake(uint256 epoch) external view returns (uint256) {
        return epochTotalStake[epoch];
    }
}
