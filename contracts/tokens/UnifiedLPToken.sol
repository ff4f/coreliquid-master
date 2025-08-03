// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title UnifiedLPToken
 * @dev ERC20 token representing liquidity provider shares in the unified pool
 */
contract UnifiedLPToken is ERC20, ERC20Burnable, ERC20Pausable, AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;
    
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant REWARD_MANAGER_ROLE = keccak256("REWARD_MANAGER_ROLE");
    
    uint256 public constant PRECISION = 1e18;
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant MAX_SUPPLY = 1000000000 * 1e18; // 1 billion tokens
    
    // Reward distribution
    struct RewardInfo {
        uint256 totalRewards;
        uint256 rewardPerToken;
        uint256 lastUpdateTime;
        uint256 rewardRate;
        uint256 periodFinish;
    }
    
    // User reward tracking
    struct UserReward {
        uint256 userRewardPerTokenPaid;
        uint256 rewards;
        uint256 lastClaimTime;
    }
    
    // Staking information
    struct StakeInfo {
        uint256 amount;
        uint256 stakingTime;
        uint256 lockPeriod;
        uint256 multiplier;
        bool isLocked;
    }
    
    // Pool information
    address public liquidityPool;
    uint256 public totalStaked;
    uint256 public totalRewardsDistributed;
    
    // Reward tracking
    RewardInfo public rewardInfo;
    mapping(address => UserReward) public userRewards;
    mapping(address => StakeInfo) public stakes;
    
    // Fee structure
    uint256 public transferFee = 0; // Basis points
    uint256 public burnFee = 0; // Basis points
    address public feeRecipient;
    
    // Vesting
    struct VestingSchedule {
        uint256 totalAmount;
        uint256 releasedAmount;
        uint256 startTime;
        uint256 duration;
        uint256 cliffDuration;
        bool revocable;
        bool revoked;
    }
    
    mapping(address => VestingSchedule[]) public vestingSchedules;
    uint256 public totalVestingAmount;
    
    // Governance
    mapping(address => uint256) public votingPower;
    uint256 public totalVotingPower;
    
    // Events
    event RewardAdded(uint256 reward, uint256 duration, uint256 timestamp);
    event RewardPaid(address indexed user, uint256 reward, uint256 timestamp);
    event Staked(address indexed user, uint256 amount, uint256 lockPeriod, uint256 timestamp);
    event Unstaked(address indexed user, uint256 amount, uint256 timestamp);
    event VestingScheduleCreated(
        address indexed beneficiary,
        uint256 amount,
        uint256 startTime,
        uint256 duration,
        uint256 timestamp
    );
    event VestingTokensReleased(address indexed beneficiary, uint256 amount, uint256 timestamp);
    event FeesCollected(uint256 amount, address indexed recipient, uint256 timestamp);
    
    constructor(
        string memory name,
        string memory symbol,
        address _liquidityPool,
        address _feeRecipient
    ) ERC20(name, symbol) {
        require(_liquidityPool != address(0), "UnifiedLPToken: invalid liquidity pool");
        require(_feeRecipient != address(0), "UnifiedLPToken: invalid fee recipient");
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(BURNER_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(REWARD_MANAGER_ROLE, msg.sender);
        
        liquidityPool = _liquidityPool;
        feeRecipient = _feeRecipient;
        
        // Grant minter role to liquidity pool
        _grantRole(MINTER_ROLE, _liquidityPool);
        _grantRole(BURNER_ROLE, _liquidityPool);
        
        rewardInfo.lastUpdateTime = block.timestamp;
    }
    
    /**
     * @dev Mint tokens to address
     */
    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        require(to != address(0), "UnifiedLPToken: mint to zero address");
        require(amount > 0, "UnifiedLPToken: invalid amount");
        require(totalSupply() + amount <= MAX_SUPPLY, "UnifiedLPToken: exceeds max supply");
        
        _updateReward(to);
        _mint(to, amount);
        
        // Update voting power
        votingPower[to] += amount;
        totalVotingPower += amount;
    }
    
    /**
     * @dev Burn tokens from address
     */
    function burnFrom(address account, uint256 amount) public override onlyRole(BURNER_ROLE) {
        require(account != address(0), "UnifiedLPToken: burn from zero address");
        require(amount > 0, "UnifiedLPToken: invalid amount");
        require(balanceOf(account) >= amount, "UnifiedLPToken: insufficient balance");
        
        _updateReward(account);
        
        // Calculate burn fee
        uint256 fee = 0;
        if (burnFee > 0) {
            fee = (amount * burnFee) / BASIS_POINTS;
            if (fee > 0) {
                _transfer(account, feeRecipient, fee);
            }
        }
        
        uint256 burnAmount = amount - fee;
        _burn(account, burnAmount);
        
        // Update voting power
        if (votingPower[account] >= amount) {
            votingPower[account] -= amount;
            totalVotingPower -= amount;
        }
    }
    
    /**
     * @dev Stake LP tokens for rewards
     */
    function stake(
        uint256 amount,
        uint256 lockPeriod
    ) external nonReentrant whenNotPaused {
        require(amount > 0, "UnifiedLPToken: invalid amount");
        require(balanceOf(msg.sender) >= amount, "UnifiedLPToken: insufficient balance");
        require(lockPeriod <= 365 days, "UnifiedLPToken: lock period too long");
        
        _updateReward(msg.sender);
        
        // Calculate multiplier based on lock period
        uint256 multiplier = PRECISION;
        if (lockPeriod >= 30 days) {
            multiplier += (lockPeriod * PRECISION) / (365 days); // Up to 2x for 1 year
        }
        
        // Transfer tokens to contract
        _transfer(msg.sender, address(this), amount);
        
        // Update stake info
        StakeInfo storage stakeInfo = stakes[msg.sender];
        stakeInfo.amount += amount;
        stakeInfo.stakingTime = block.timestamp;
        stakeInfo.lockPeriod = lockPeriod;
        stakeInfo.multiplier = multiplier;
        stakeInfo.isLocked = lockPeriod > 0;
        
        totalStaked += amount;
        
        emit Staked(msg.sender, amount, lockPeriod, block.timestamp);
    }
    
    /**
     * @dev Unstake LP tokens
     */
    function unstake(uint256 amount) external nonReentrant whenNotPaused {
        require(amount > 0, "UnifiedLPToken: invalid amount");
        
        StakeInfo storage stakeInfo = stakes[msg.sender];
        require(stakeInfo.amount >= amount, "UnifiedLPToken: insufficient staked amount");
        
        // Check lock period
        if (stakeInfo.isLocked) {
            require(
                block.timestamp >= stakeInfo.stakingTime + stakeInfo.lockPeriod,
                "UnifiedLPToken: tokens still locked"
            );
        }
        
        _updateReward(msg.sender);
        
        // Update stake info
        stakeInfo.amount -= amount;
        totalStaked -= amount;
        
        // Transfer tokens back to user
        _transfer(address(this), msg.sender, amount);
        
        emit Unstaked(msg.sender, amount, block.timestamp);
    }
    
    /**
     * @dev Claim accumulated rewards
     */
    function claimReward() external nonReentrant whenNotPaused {
        _updateReward(msg.sender);
        
        uint256 reward = userRewards[msg.sender].rewards;
        require(reward > 0, "UnifiedLPToken: no rewards to claim");
        
        userRewards[msg.sender].rewards = 0;
        userRewards[msg.sender].lastClaimTime = block.timestamp;
        
        // Mint reward tokens
        _mint(msg.sender, reward);
        totalRewardsDistributed += reward;
        
        emit RewardPaid(msg.sender, reward, block.timestamp);
    }
    
    /**
     * @dev Add rewards to the pool
     */
    function addReward(
        uint256 reward,
        uint256 duration
    ) external onlyRole(REWARD_MANAGER_ROLE) {
        require(reward > 0, "UnifiedLPToken: invalid reward amount");
        require(duration > 0, "UnifiedLPToken: invalid duration");
        
        _updateReward(address(0));
        
        if (block.timestamp >= rewardInfo.periodFinish) {
            rewardInfo.rewardRate = reward / duration;
        } else {
            uint256 remaining = rewardInfo.periodFinish - block.timestamp;
            uint256 leftover = remaining * rewardInfo.rewardRate;
            rewardInfo.rewardRate = (reward + leftover) / duration;
        }
        
        rewardInfo.lastUpdateTime = block.timestamp;
        rewardInfo.periodFinish = block.timestamp + duration;
        rewardInfo.totalRewards += reward;
        
        emit RewardAdded(reward, duration, block.timestamp);
    }
    
    /**
     * @dev Create vesting schedule
     */
    function createVestingSchedule(
        address beneficiary,
        uint256 amount,
        uint256 startTime,
        uint256 duration,
        uint256 cliffDuration,
        bool revocable
    ) external onlyRole(ADMIN_ROLE) {
        require(beneficiary != address(0), "UnifiedLPToken: invalid beneficiary");
        require(amount > 0, "UnifiedLPToken: invalid amount");
        require(duration > 0, "UnifiedLPToken: invalid duration");
        require(cliffDuration <= duration, "UnifiedLPToken: cliff too long");
        require(startTime >= block.timestamp, "UnifiedLPToken: start time in past");
        
        vestingSchedules[beneficiary].push(VestingSchedule({
            totalAmount: amount,
            releasedAmount: 0,
            startTime: startTime,
            duration: duration,
            cliffDuration: cliffDuration,
            revocable: revocable,
            revoked: false
        }));
        
        totalVestingAmount += amount;
        
        emit VestingScheduleCreated(beneficiary, amount, startTime, duration, block.timestamp);
    }
    
    /**
     * @dev Release vested tokens
     */
    function releaseVestedTokens(uint256 scheduleIndex) external nonReentrant {
        require(scheduleIndex < vestingSchedules[msg.sender].length, "UnifiedLPToken: invalid schedule");
        
        VestingSchedule storage schedule = vestingSchedules[msg.sender][scheduleIndex];
        require(!schedule.revoked, "UnifiedLPToken: schedule revoked");
        require(block.timestamp >= schedule.startTime + schedule.cliffDuration, "UnifiedLPToken: cliff not reached");
        
        uint256 vestedAmount = _calculateVestedAmount(schedule);
        uint256 releasableAmount = vestedAmount - schedule.releasedAmount;
        
        require(releasableAmount > 0, "UnifiedLPToken: no tokens to release");
        
        schedule.releasedAmount += releasableAmount;
        totalVestingAmount -= releasableAmount;
        
        _mint(msg.sender, releasableAmount);
        
        emit VestingTokensReleased(msg.sender, releasableAmount, block.timestamp);
    }
    
    /**
     * @dev Get earned rewards for user
     */
    function earned(address account) public view returns (uint256) {
        StakeInfo storage stakeInfo = stakes[account];
        if (stakeInfo.amount == 0) {
            return userRewards[account].rewards;
        }
        
        uint256 currentRewardPerToken = _rewardPerToken();
        uint256 userRewardPerTokenPaid = userRewards[account].userRewardPerTokenPaid;
        
        uint256 earnedAmount = (stakeInfo.amount * 
            (currentRewardPerToken - userRewardPerTokenPaid) * 
            stakeInfo.multiplier) / (PRECISION * PRECISION);
            
        return userRewards[account].rewards + earnedAmount;
    }
    
    /**
     * @dev Get vested amount for schedule
     */
    function getVestedAmount(address beneficiary, uint256 scheduleIndex) external view returns (uint256) {
        require(scheduleIndex < vestingSchedules[beneficiary].length, "UnifiedLPToken: invalid schedule");
        return _calculateVestedAmount(vestingSchedules[beneficiary][scheduleIndex]);
    }
    
    /**
     * @dev Get user staking info
     */
    function getStakeInfo(address user) external view returns (
        uint256 amount,
        uint256 stakingTime,
        uint256 lockPeriod,
        uint256 multiplier,
        bool isLocked,
        uint256 earnedRewards
    ) {
        StakeInfo storage stakeInfo = stakes[user];
        return (
            stakeInfo.amount,
            stakeInfo.stakingTime,
            stakeInfo.lockPeriod,
            stakeInfo.multiplier,
            stakeInfo.isLocked,
            earned(user)
        );
    }
    
    /**
     * @dev Calculate reward per token
     */
    function _rewardPerToken() internal view returns (uint256) {
        if (totalStaked == 0) {
            return rewardInfo.rewardPerToken;
        }
        
        uint256 lastTimeRewardApplicable = block.timestamp < rewardInfo.periodFinish ? 
            block.timestamp : rewardInfo.periodFinish;
            
        return rewardInfo.rewardPerToken + 
            ((lastTimeRewardApplicable - rewardInfo.lastUpdateTime) * 
             rewardInfo.rewardRate * PRECISION) / totalStaked;
    }
    
    /**
     * @dev Update reward for account
     */
    function _updateReward(address account) internal {
        rewardInfo.rewardPerToken = _rewardPerToken();
        rewardInfo.lastUpdateTime = block.timestamp < rewardInfo.periodFinish ? 
            block.timestamp : rewardInfo.periodFinish;
            
        if (account != address(0)) {
            userRewards[account].rewards = earned(account);
            userRewards[account].userRewardPerTokenPaid = rewardInfo.rewardPerToken;
        }
    }
    
    /**
     * @dev Calculate vested amount for schedule
     */
    function _calculateVestedAmount(VestingSchedule storage schedule) internal view returns (uint256) {
        if (block.timestamp < schedule.startTime + schedule.cliffDuration) {
            return 0;
        }
        
        if (block.timestamp >= schedule.startTime + schedule.duration) {
            return schedule.totalAmount;
        }
        
        uint256 timeFromStart = block.timestamp - schedule.startTime;
        return (schedule.totalAmount * timeFromStart) / schedule.duration;
    }
    
    /**
     * @dev Override transfer to handle fees
     */
    function _update(address from, address to, uint256 value) internal override(ERC20, ERC20Pausable) {
        if (from != address(0) && to != address(0) && transferFee > 0) {
            uint256 fee = (value * transferFee) / BASIS_POINTS;
            if (fee > 0) {
                super._update(from, feeRecipient, fee);
                value -= fee;
            }
        }
        
        super._update(from, to, value);
        
        // Update voting power
        if (from != address(0) && from != address(this)) {
            if (votingPower[from] >= value) {
                votingPower[from] -= value;
                totalVotingPower -= value;
            }
        }
        
        if (to != address(0) && to != address(this)) {
            votingPower[to] += value;
            totalVotingPower += value;
        }
    }
    
    /**
     * @dev Set transfer fee
     */
    function setTransferFee(uint256 _transferFee) external onlyRole(ADMIN_ROLE) {
        require(_transferFee <= 1000, "UnifiedLPToken: fee too high"); // Max 10%
        transferFee = _transferFee;
    }
    
    /**
     * @dev Set burn fee
     */
    function setBurnFee(uint256 _burnFee) external onlyRole(ADMIN_ROLE) {
        require(_burnFee <= 1000, "UnifiedLPToken: fee too high"); // Max 10%
        burnFee = _burnFee;
    }
    
    /**
     * @dev Set fee recipient
     */
    function setFeeRecipient(address _feeRecipient) external onlyRole(ADMIN_ROLE) {
        require(_feeRecipient != address(0), "UnifiedLPToken: invalid recipient");
        feeRecipient = _feeRecipient;
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
}
