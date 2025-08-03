// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Nonces.sol";

/**
 * @title GovernanceToken
 * @dev Advanced governance token with voting capabilities, delegation, and reward mechanisms
 */
contract GovernanceToken is ERC20, ERC20Votes, ERC20Permit, AccessControl, Pausable, ReentrancyGuard {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant REWARD_DISTRIBUTOR_ROLE = keccak256("REWARD_DISTRIBUTOR_ROLE");

    // Constants
    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 1e18; // 1 billion tokens
    uint256 public constant INITIAL_SUPPLY = 100_000_000 * 1e18; // 100 million tokens
    uint256 public constant PRECISION = 1e18;
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant MIN_DELEGATION_PERIOD = 1 days;
    uint256 public constant MAX_DELEGATION_PERIOD = 365 days;
    uint256 public constant REWARD_DURATION = 7 days;

    // Structs
    struct VestingSchedule {
        uint256 totalAmount;
        uint256 releasedAmount;
        uint256 startTime;
        uint256 duration;
        uint256 cliffDuration;
        bool revocable;
        bool revoked;
        address beneficiary;
    }

    struct StakingInfo {
        uint256 stakedAmount;
        uint256 stakingStartTime;
        uint256 lastRewardClaim;
        uint256 accumulatedRewards;
        uint256 lockEndTime;
        bool isLocked;
    }

    struct DelegationInfo {
        address delegate;
        uint256 delegatedAmount;
        uint256 delegationStartTime;
        uint256 delegationEndTime;
        bool isActive;
    }

    struct RewardPool {
        uint256 totalRewards;
        uint256 rewardRate;
        uint256 lastUpdateTime;
        uint256 rewardPerTokenStored;
        uint256 periodFinish;
        mapping(address => uint256) userRewardPerTokenPaid;
        mapping(address => uint256) rewards;
    }

    struct GovernanceMetrics {
        uint256 totalVotingPower;
        uint256 totalDelegated;
        uint256 totalStaked;
        uint256 participationRate;
        uint256 lastUpdate;
    }

    // Storage
    mapping(address => VestingSchedule[]) public vestingSchedules;
    mapping(address => StakingInfo) public stakingInfo;
    mapping(address => DelegationInfo) public delegationInfo;
    mapping(address => uint256) public votingPowerMultiplier;
    mapping(address => bool) public blacklisted;
    mapping(address => uint256) public lastTransferTime;
    
    RewardPool public rewardPool;
    GovernanceMetrics public governanceMetrics;
    
    uint256 public totalVestingAmount;
    uint256 public totalStaked;
    uint256 public transferCooldown;
    uint256 public stakingRewardRate;
    uint256 public minimumStakingAmount;
    uint256 public maximumStakingAmount;
    bool public stakingEnabled;
    bool public transfersEnabled;
    address public treasury;
    address public rewardDistributor;
    
    // Events
    event VestingScheduleCreated(address indexed beneficiary, uint256 amount, uint256 duration);
    event TokensVested(address indexed beneficiary, uint256 amount);
    event VestingRevoked(address indexed beneficiary, uint256 unvestedAmount);
    event Staked(address indexed user, uint256 amount, uint256 lockDuration);
    event Unstaked(address indexed user, uint256 amount);
    event RewardClaimed(address indexed user, uint256 amount);
    event DelegationCreated(address indexed delegator, address indexed delegate, uint256 amount);
    event DelegationRevoked(address indexed delegator, address indexed delegate);
    event RewardPoolUpdated(uint256 reward, uint256 duration);
    event BlacklistUpdated(address indexed account, bool blacklisted);
    event TransferCooldownUpdated(uint256 newCooldown);
    event StakingParametersUpdated(uint256 minAmount, uint256 maxAmount, uint256 rewardRate);

    constructor(
        string memory name,
        string memory symbol,
        address _treasury,
        address _rewardDistributor
    ) ERC20(name, symbol) ERC20Permit(name) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(REWARD_DISTRIBUTOR_ROLE, _rewardDistributor);
        
        treasury = _treasury;
        rewardDistributor = _rewardDistributor;
        
        // Initial parameters
        transferCooldown = 0; // No cooldown initially
        stakingRewardRate = 1000; // 10% APY
        minimumStakingAmount = 100 * 1e18; // 100 tokens
        maximumStakingAmount = 10_000_000 * 1e18; // 10M tokens
        stakingEnabled = true;
        transfersEnabled = true;
        
        // Mint initial supply to treasury
        _mint(_treasury, INITIAL_SUPPLY);
    }

    /**
     * @dev Mint new tokens (only by minter role)
     */
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        require(totalSupply() + amount <= MAX_SUPPLY, "Exceeds max supply");
        _mint(to, amount);
    }

    /**
     * @dev Burn tokens (only by burner role or token holder)
     */
    function burn(uint256 amount) external {
        require(hasRole(BURNER_ROLE, msg.sender) || msg.sender == _msgSender(), "Not authorized to burn");
        _burn(_msgSender(), amount);
    }

    /**
     * @dev Burn tokens from specific account (only by burner role)
     */
    function burnFrom(address account, uint256 amount) external onlyRole(BURNER_ROLE) {
        _burn(account, amount);
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
        require(beneficiary != address(0), "Invalid beneficiary");
        require(amount > 0, "Amount must be greater than 0");
        require(duration > 0, "Duration must be greater than 0");
        require(cliffDuration <= duration, "Cliff duration exceeds total duration");
        require(balanceOf(msg.sender) >= amount, "Insufficient balance");
        
        vestingSchedules[beneficiary].push(VestingSchedule({
            totalAmount: amount,
            releasedAmount: 0,
            startTime: startTime,
            duration: duration,
            cliffDuration: cliffDuration,
            revocable: revocable,
            revoked: false,
            beneficiary: beneficiary
        }));
        
        totalVestingAmount += amount;
        _transfer(msg.sender, address(this), amount);
        
        emit VestingScheduleCreated(beneficiary, amount, duration);
    }

    /**
     * @dev Release vested tokens
     */
    function releaseVestedTokens(uint256 scheduleIndex) external nonReentrant {
        require(scheduleIndex < vestingSchedules[msg.sender].length, "Invalid schedule index");
        
        VestingSchedule storage schedule = vestingSchedules[msg.sender][scheduleIndex];
        require(!schedule.revoked, "Vesting schedule revoked");
        
        uint256 vestedAmount = _calculateVestedAmount(schedule);
        uint256 releasableAmount = vestedAmount - schedule.releasedAmount;
        
        require(releasableAmount > 0, "No tokens to release");
        
        schedule.releasedAmount += releasableAmount;
        totalVestingAmount -= releasableAmount;
        
        _transfer(address(this), msg.sender, releasableAmount);
        
        emit TokensVested(msg.sender, releasableAmount);
    }

    /**
     * @dev Stake tokens for governance rewards
     */
    function stake(uint256 amount, uint256 lockDuration) external nonReentrant whenNotPaused {
        require(stakingEnabled, "Staking disabled");
        require(amount >= minimumStakingAmount, "Below minimum staking amount");
        require(amount <= maximumStakingAmount, "Exceeds maximum staking amount");
        require(lockDuration >= MIN_DELEGATION_PERIOD && lockDuration <= MAX_DELEGATION_PERIOD, "Invalid lock duration");
        require(balanceOf(msg.sender) >= amount, "Insufficient balance");
        
        StakingInfo storage info = stakingInfo[msg.sender];
        
        // Update rewards before staking
        _updateReward(msg.sender);
        
        // Transfer tokens to contract
        _transfer(msg.sender, address(this), amount);
        
        // Update staking info
        info.stakedAmount += amount;
        info.stakingStartTime = block.timestamp;
        info.lockEndTime = block.timestamp + lockDuration;
        info.isLocked = true;
        
        totalStaked += amount;
        
        // Increase voting power for staked tokens
        votingPowerMultiplier[msg.sender] = _calculateVotingMultiplier(lockDuration);
        
        emit Staked(msg.sender, amount, lockDuration);
    }

    /**
     * @dev Unstake tokens
     */
    function unstake(uint256 amount) external nonReentrant {
        StakingInfo storage info = stakingInfo[msg.sender];
        require(info.stakedAmount >= amount, "Insufficient staked amount");
        require(!info.isLocked || block.timestamp >= info.lockEndTime, "Tokens still locked");
        
        // Update rewards before unstaking
        _updateReward(msg.sender);
        
        // Update staking info
        info.stakedAmount -= amount;
        totalStaked -= amount;
        
        if (info.stakedAmount == 0) {
            info.isLocked = false;
            votingPowerMultiplier[msg.sender] = BASIS_POINTS; // Reset to 100%
        }
        
        // Transfer tokens back to user
        _transfer(address(this), msg.sender, amount);
        
        emit Unstaked(msg.sender, amount);
    }

    /**
     * @dev Claim staking rewards
     */
    function claimRewards() external nonReentrant {
        _updateReward(msg.sender);
        
        uint256 reward = rewardPool.rewards[msg.sender];
        require(reward > 0, "No rewards to claim");
        
        rewardPool.rewards[msg.sender] = 0;
        stakingInfo[msg.sender].lastRewardClaim = block.timestamp;
        stakingInfo[msg.sender].accumulatedRewards += reward;
        
        _mint(msg.sender, reward);
        
        emit RewardClaimed(msg.sender, reward);
    }

    /**
     * @dev Delegate voting power
     */
    function delegateVotingPower(address delegate, uint256 amount, uint256 duration) external {
        require(delegate != address(0), "Invalid delegate");
        require(delegate != msg.sender, "Cannot delegate to self");
        require(amount > 0, "Amount must be greater than 0");
        require(duration >= MIN_DELEGATION_PERIOD && duration <= MAX_DELEGATION_PERIOD, "Invalid duration");
        require(balanceOf(msg.sender) >= amount, "Insufficient balance");
        
        DelegationInfo storage info = delegationInfo[msg.sender];
        require(!info.isActive, "Delegation already active");
        
        info.delegate = delegate;
        info.delegatedAmount = amount;
        info.delegationStartTime = block.timestamp;
        info.delegationEndTime = block.timestamp + duration;
        info.isActive = true;
        
        // Delegate votes
        _delegate(msg.sender, delegate);
        
        emit DelegationCreated(msg.sender, delegate, amount);
    }

    /**
     * @dev Revoke delegation
     */
    function revokeDelegation() external {
        DelegationInfo storage info = delegationInfo[msg.sender];
        require(info.isActive, "No active delegation");
        require(block.timestamp >= info.delegationEndTime, "Delegation period not ended");
        
        address delegate = info.delegate;
        
        // Reset delegation info
        info.isActive = false;
        info.delegate = address(0);
        info.delegatedAmount = 0;
        
        // Remove delegation
        _delegate(msg.sender, msg.sender);
        
        emit DelegationRevoked(msg.sender, delegate);
    }

    /**
     * @dev Update reward pool
     */
    function updateRewardPool(uint256 reward, uint256 duration) external onlyRole(REWARD_DISTRIBUTOR_ROLE) {
        require(duration > 0, "Duration must be greater than 0");
        
        _updateRewardPool();
        
        if (block.timestamp >= rewardPool.periodFinish) {
            rewardPool.rewardRate = reward / duration;
        } else {
            uint256 remaining = rewardPool.periodFinish - block.timestamp;
            uint256 leftover = remaining * rewardPool.rewardRate;
            rewardPool.rewardRate = (reward + leftover) / duration;
        }
        
        rewardPool.lastUpdateTime = block.timestamp;
        rewardPool.periodFinish = block.timestamp + duration;
        rewardPool.totalRewards += reward;
        
        emit RewardPoolUpdated(reward, duration);
    }

    /**
     * @dev Get vested amount for a schedule
     */
    function getVestedAmount(address beneficiary, uint256 scheduleIndex) external view returns (uint256) {
        require(scheduleIndex < vestingSchedules[beneficiary].length, "Invalid schedule index");
        return _calculateVestedAmount(vestingSchedules[beneficiary][scheduleIndex]);
    }

    /**
     * @dev Get staking info for a user
     */
    function getStakingInfo(address user) external view returns (StakingInfo memory) {
        return stakingInfo[user];
    }

    /**
     * @dev Get delegation info for a user
     */
    function getDelegationInfo(address user) external view returns (DelegationInfo memory) {
        return delegationInfo[user];
    }

    /**
     * @dev Get earned rewards for a user
     */
    function earned(address account) public view returns (uint256) {
        return (stakingInfo[account].stakedAmount * 
                (rewardPerToken() - rewardPool.userRewardPerTokenPaid[account]) / 1e18) + 
                rewardPool.rewards[account];
    }

    /**
     * @dev Get reward per token
     */
    function rewardPerToken() public view returns (uint256) {
        if (totalStaked == 0) {
            return rewardPool.rewardPerTokenStored;
        }
        return rewardPool.rewardPerTokenStored + 
               (((lastTimeRewardApplicable() - rewardPool.lastUpdateTime) * 
                rewardPool.rewardRate * 1e18) / totalStaked);
    }

    /**
     * @dev Get last time reward applicable
     */
    function lastTimeRewardApplicable() public view returns (uint256) {
        return block.timestamp < rewardPool.periodFinish ? block.timestamp : rewardPool.periodFinish;
    }

    // Admin functions
    function setTransferCooldown(uint256 _cooldown) external onlyRole(ADMIN_ROLE) {
        transferCooldown = _cooldown;
        emit TransferCooldownUpdated(_cooldown);
    }

    function setStakingParameters(
        uint256 _minAmount,
        uint256 _maxAmount,
        uint256 _rewardRate
    ) external onlyRole(ADMIN_ROLE) {
        minimumStakingAmount = _minAmount;
        maximumStakingAmount = _maxAmount;
        stakingRewardRate = _rewardRate;
        emit StakingParametersUpdated(_minAmount, _maxAmount, _rewardRate);
    }

    function setBlacklist(address account, bool _blacklisted) external onlyRole(ADMIN_ROLE) {
        blacklisted[account] = _blacklisted;
        emit BlacklistUpdated(account, _blacklisted);
    }

    function toggleStaking() external onlyRole(ADMIN_ROLE) {
        stakingEnabled = !stakingEnabled;
    }

    function toggleTransfers() external onlyRole(ADMIN_ROLE) {
        transfersEnabled = !transfersEnabled;
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    // Internal functions
    function _calculateVestedAmount(VestingSchedule memory schedule) internal view returns (uint256) {
        if (block.timestamp < schedule.startTime + schedule.cliffDuration) {
            return 0;
        }
        
        if (block.timestamp >= schedule.startTime + schedule.duration) {
            return schedule.totalAmount;
        }
        
        uint256 timeElapsed = block.timestamp - schedule.startTime - schedule.cliffDuration;
        uint256 vestingDuration = schedule.duration - schedule.cliffDuration;
        
        return (schedule.totalAmount * timeElapsed) / vestingDuration;
    }

    function _calculateVotingMultiplier(uint256 lockDuration) internal pure returns (uint256) {
        // Longer lock = higher voting power (up to 2x)
        uint256 multiplier = BASIS_POINTS + (lockDuration * BASIS_POINTS) / MAX_DELEGATION_PERIOD;
        return multiplier > 2 * BASIS_POINTS ? 2 * BASIS_POINTS : multiplier;
    }

    function _updateReward(address account) internal {
        rewardPool.rewardPerTokenStored = rewardPerToken();
        rewardPool.lastUpdateTime = lastTimeRewardApplicable();
        
        if (account != address(0)) {
            rewardPool.rewards[account] = earned(account);
            rewardPool.userRewardPerTokenPaid[account] = rewardPool.rewardPerTokenStored;
        }
    }

    function _updateRewardPool() internal {
        rewardPool.rewardPerTokenStored = rewardPerToken();
        rewardPool.lastUpdateTime = lastTimeRewardApplicable();
    }

    function _update(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20, ERC20Votes) whenNotPaused {
        require(!blacklisted[from] && !blacklisted[to], "Address blacklisted");
        
        if (from != address(0) && to != address(0)) {
            require(transfersEnabled, "Transfers disabled");
            
            if (transferCooldown > 0) {
                require(block.timestamp >= lastTransferTime[from] + transferCooldown, "Transfer cooldown active");
                lastTransferTime[from] = block.timestamp;
            }
        }
        
        super._update(from, to, amount);
    }

    function nonces(address owner) public view override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }
}