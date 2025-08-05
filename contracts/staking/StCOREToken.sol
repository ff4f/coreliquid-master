// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title StCOREToken
 * @dev Staked CORE token representing staked positions in the protocol
 */
contract StCOREToken is ERC20, ERC20Burnable, Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    struct StakingInfo {
        uint256 stakedAmount;
        uint256 stakingTime;
        uint256 lockPeriod;
        uint256 rewardDebt;
        uint256 pendingRewards;
        bool isLocked;
    }

    struct RewardPool {
        uint256 totalRewards;
        uint256 rewardPerToken;
        uint256 lastUpdateTime;
        uint256 rewardRate;
        uint256 periodFinish;
    }

    IERC20 public immutable coreToken;
    
    mapping(address => StakingInfo) public stakingInfo;
    mapping(address => bool) public authorizedMinters;
    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;
    
    RewardPool public rewardPool;
    
    uint256 public totalStaked;
    uint256 public minStakeAmount = 100 * 1e18; // 100 CORE minimum
    uint256 public maxStakeAmount = 1000000 * 1e18; // 1M CORE maximum
    uint256 public stakingFee = 50; // 0.5% in basis points
    uint256 public unstakingFee = 100; // 1% in basis points
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant REWARD_DURATION = 7 days;
    
    address public treasury;
    address public stakingManager;
    bool public stakingEnabled = true;
    bool public unstakingEnabled = true;

    event Staked(address indexed user, uint256 amount, uint256 stTokens, uint256 lockPeriod);
    event Unstaked(address indexed user, uint256 amount, uint256 stTokens);
    event RewardPaid(address indexed user, uint256 reward);
    event RewardAdded(uint256 reward);
    event StakingFeeUpdated(uint256 newFee);
    event UnstakingFeeUpdated(uint256 newFee);
    event TreasuryUpdated(address indexed newTreasury);
    event StakingManagerUpdated(address indexed newManager);
    event StakingToggled(bool enabled);
    event UnstakingToggled(bool enabled);

    modifier onlyStakingManager() {
        require(msg.sender == stakingManager || msg.sender == owner(), "Not authorized");
        _;
    }

    modifier updateReward(address account) {
        rewardPool.rewardPerToken = rewardPerToken();
        rewardPool.lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPool.rewardPerToken;
        }
        _;
    }

    constructor(
        address _coreToken,
        address _treasury,
        address _stakingManager
    ) ERC20("Staked CORE", "stCORE") Ownable(msg.sender) {
        require(_coreToken != address(0), "Invalid CORE token");
        require(_treasury != address(0), "Invalid treasury");
        require(_stakingManager != address(0), "Invalid staking manager");
        
        coreToken = IERC20(_coreToken);
        treasury = _treasury;
        stakingManager = _stakingManager;
    }

    /**
     * @dev Stake CORE tokens to receive stCORE
     * @param amount Amount of CORE tokens to stake
     * @param lockPeriod Lock period in seconds (0 for no lock)
     * @return stTokens Amount of stCORE tokens minted
     */
    function stake(
        uint256 amount,
        uint256 lockPeriod
    ) external nonReentrant whenNotPaused updateReward(msg.sender) returns (uint256 stTokens) {
        require(stakingEnabled, "Staking disabled");
        require(amount >= minStakeAmount, "Amount below minimum");
        require(amount <= maxStakeAmount, "Amount above maximum");
        require(lockPeriod <= 365 days, "Lock period too long");

        // Calculate staking fee
        uint256 fee = amount * stakingFee / BASIS_POINTS;
        uint256 netAmount = amount - fee;

        // Transfer CORE tokens from user
        coreToken.safeTransferFrom(msg.sender, address(this), amount);
        
        // Transfer fee to treasury
        if (fee > 0) {
            coreToken.safeTransfer(treasury, fee);
        }

        // Calculate stCORE tokens to mint (1:1 ratio for now)
        stTokens = netAmount;
        
        // Update staking info
        StakingInfo storage info = stakingInfo[msg.sender];
        info.stakedAmount += netAmount;
        info.stakingTime = block.timestamp;
        info.lockPeriod = lockPeriod;
        info.isLocked = lockPeriod > 0;
        info.rewardDebt = info.stakedAmount * rewardPool.rewardPerToken / 1e18;
        
        // Update total staked
        totalStaked += netAmount;
        
        // Mint stCORE tokens
        _mint(msg.sender, stTokens);

        emit Staked(msg.sender, netAmount, stTokens, lockPeriod);
    }

    /**
     * @dev Unstake stCORE tokens to receive CORE
     * @param stTokenAmount Amount of stCORE tokens to burn
     * @return coreAmount Amount of CORE tokens returned
     */
    function unstake(
        uint256 stTokenAmount
    ) external nonReentrant updateReward(msg.sender) returns (uint256 coreAmount) {
        require(unstakingEnabled, "Unstaking disabled");
        require(stTokenAmount > 0, "Invalid amount");
        require(balanceOf(msg.sender) >= stTokenAmount, "Insufficient balance");
        
        StakingInfo storage info = stakingInfo[msg.sender];
        
        // Check lock period
        if (info.isLocked) {
            require(
                block.timestamp >= info.stakingTime + info.lockPeriod,
                "Tokens still locked"
            );
        }
        
        // Calculate CORE amount to return (1:1 ratio for now)
        coreAmount = stTokenAmount;
        require(coreAmount <= info.stakedAmount, "Amount exceeds staked");
        
        // Calculate unstaking fee
        uint256 fee = coreAmount * unstakingFee / BASIS_POINTS;
        uint256 netAmount = coreAmount - fee;
        
        // Update staking info
        info.stakedAmount -= coreAmount;
        if (info.stakedAmount == 0) {
            info.isLocked = false;
            info.lockPeriod = 0;
        }
        
        // Update total staked
        totalStaked -= coreAmount;
        
        // Burn stCORE tokens
        _burn(msg.sender, stTokenAmount);
        
        // Transfer CORE tokens to user
        coreToken.safeTransfer(msg.sender, netAmount);
        
        // Transfer fee to treasury
        if (fee > 0) {
            coreToken.safeTransfer(treasury, fee);
        }

        emit Unstaked(msg.sender, netAmount, stTokenAmount);
    }

    /**
     * @dev Claim pending rewards
     */
    function claimRewards() external nonReentrant updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            coreToken.safeTransfer(msg.sender, reward);
            emit RewardPaid(msg.sender, reward);
        }
    }

    /**
     * @dev Emergency unstake (with penalty)
     * @param stTokenAmount Amount of stCORE tokens to burn
     */
    function emergencyUnstake(uint256 stTokenAmount) external nonReentrant {
        require(stTokenAmount > 0, "Invalid amount");
        require(balanceOf(msg.sender) >= stTokenAmount, "Insufficient balance");
        
        StakingInfo storage info = stakingInfo[msg.sender];
        uint256 coreAmount = stTokenAmount;
        require(coreAmount <= info.stakedAmount, "Amount exceeds staked");
        
        // Apply emergency penalty (10%)
        uint256 penalty = coreAmount * 1000 / BASIS_POINTS;
        uint256 netAmount = coreAmount - penalty;
        
        // Update staking info
        info.stakedAmount -= coreAmount;
        if (info.stakedAmount == 0) {
            info.isLocked = false;
            info.lockPeriod = 0;
        }
        
        // Update total staked
        totalStaked -= coreAmount;
        
        // Burn stCORE tokens
        _burn(msg.sender, stTokenAmount);
        
        // Transfer tokens
        coreToken.safeTransfer(msg.sender, netAmount);
        coreToken.safeTransfer(treasury, penalty);

        emit Unstaked(msg.sender, netAmount, stTokenAmount);
    }

    /**
     * @dev Add rewards to the pool
     * @param reward Amount of rewards to add
     */
    function addReward(uint256 reward) external onlyStakingManager updateReward(address(0)) {
        require(reward > 0, "Invalid reward amount");
        
        if (block.timestamp >= rewardPool.periodFinish) {
            rewardPool.rewardRate = reward / REWARD_DURATION;
        } else {
            uint256 remaining = rewardPool.periodFinish - block.timestamp;
            uint256 leftover = remaining * rewardPool.rewardRate;
            rewardPool.rewardRate = (reward + leftover) / REWARD_DURATION;
        }
        
        rewardPool.lastUpdateTime = block.timestamp;
        rewardPool.periodFinish = block.timestamp + REWARD_DURATION;
        rewardPool.totalRewards += reward;
        
        // Transfer reward tokens to contract
        coreToken.safeTransferFrom(msg.sender, address(this), reward);
        
        emit RewardAdded(reward);
    }

    /**
     * @dev Mint stCORE tokens (authorized minters only)
     * @param to Recipient address
     * @param amount Amount to mint
     */
    function mint(address to, uint256 amount) external {
        require(authorizedMinters[msg.sender], "Not authorized minter");
        _mint(to, amount);
    }

    /**
     * @dev Set authorized minter status
     * @param minter Minter address
     * @param authorized Authorization status
     */
    function setAuthorizedMinter(address minter, bool authorized) external onlyOwner {
        authorizedMinters[minter] = authorized;
    }

    /**
     * @dev Update staking fee
     * @param newFee New staking fee (basis points)
     */
    function setStakingFee(uint256 newFee) external onlyOwner {
        require(newFee <= 500, "Fee too high"); // Max 5%
        stakingFee = newFee;
        emit StakingFeeUpdated(newFee);
    }

    /**
     * @dev Update unstaking fee
     * @param newFee New unstaking fee (basis points)
     */
    function setUnstakingFee(uint256 newFee) external onlyOwner {
        require(newFee <= 1000, "Fee too high"); // Max 10%
        unstakingFee = newFee;
        emit UnstakingFeeUpdated(newFee);
    }

    /**
     * @dev Update treasury address
     * @param newTreasury New treasury address
     */
    function setTreasury(address newTreasury) external onlyOwner {
        require(newTreasury != address(0), "Invalid treasury");
        treasury = newTreasury;
        emit TreasuryUpdated(newTreasury);
    }

    /**
     * @dev Update staking manager
     * @param newManager New staking manager address
     */
    function setStakingManager(address newManager) external onlyOwner {
        require(newManager != address(0), "Invalid manager");
        stakingManager = newManager;
        emit StakingManagerUpdated(newManager);
    }

    /**
     * @dev Toggle staking enabled/disabled
     * @param enabled Staking enabled status
     */
    function setStakingEnabled(bool enabled) external onlyOwner {
        stakingEnabled = enabled;
        emit StakingToggled(enabled);
    }

    /**
     * @dev Toggle unstaking enabled/disabled
     * @param enabled Unstaking enabled status
     */
    function setUnstakingEnabled(bool enabled) external onlyOwner {
        unstakingEnabled = enabled;
        emit UnstakingToggled(enabled);
    }

    /**
     * @dev Update stake limits
     * @param minAmount New minimum stake amount
     * @param maxAmount New maximum stake amount
     */
    function setStakeLimits(uint256 minAmount, uint256 maxAmount) external onlyOwner {
        require(minAmount < maxAmount, "Invalid limits");
        minStakeAmount = minAmount;
        maxStakeAmount = maxAmount;
    }

    /**
     * @dev Calculate reward per token
     * @return rewardPerTokenValue Current reward per token
     */
    function rewardPerToken() public view returns (uint256 rewardPerTokenValue) {
        if (totalSupply() == 0) {
            return rewardPool.rewardPerToken;
        }
        return rewardPool.rewardPerToken + 
            (lastTimeRewardApplicable() - rewardPool.lastUpdateTime) * 
            rewardPool.rewardRate * 1e18 / totalSupply();
    }

    /**
     * @dev Get last time reward applicable
     * @return timestamp Last applicable timestamp
     */
    function lastTimeRewardApplicable() public view returns (uint256 timestamp) {
        return block.timestamp < rewardPool.periodFinish ? block.timestamp : rewardPool.periodFinish;
    }

    /**
     * @dev Calculate earned rewards for an account
     * @param account Account address
     * @return earnedAmount Earned reward amount
     */
    function earned(address account) public view returns (uint256 earnedAmount) {
        return balanceOf(account) * (rewardPerToken() - userRewardPerTokenPaid[account]) / 1e18 + rewards[account];
    }

    /**
     * @dev Get staking info for an account
     * @param account Account address
     * @return info Staking information
     */
    function getStakingInfo(address account) external view returns (StakingInfo memory info) {
        return stakingInfo[account];
    }

    /**
     * @dev Get reward pool info
     * @return pool Reward pool information
     */
    function getRewardPool() external view returns (RewardPool memory pool) {
        return rewardPool;
    }

    /**
     * @dev Check if tokens are locked for an account
     * @param account Account address
     * @return locked True if tokens are locked
     */
    function isLocked(address account) external view returns (bool locked) {
        StakingInfo memory info = stakingInfo[account];
        return info.isLocked && block.timestamp < info.stakingTime + info.lockPeriod;
    }

    /**
     * @dev Get unlock time for an account
     * @param account Account address
     * @return unlockTime Unlock timestamp
     */
    function getUnlockTime(address account) external view returns (uint256 unlockTime) {
        StakingInfo memory info = stakingInfo[account];
        if (!info.isLocked) return 0;
        return info.stakingTime + info.lockPeriod;
    }

    /**
     * @dev Pause contract
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev Unpause contract
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @dev Emergency token recovery
     * @param token Token to recover
     * @param amount Amount to recover
     */
    function emergencyRecovery(address token, uint256 amount) external onlyOwner {
        IERC20(token).safeTransfer(owner(), amount);
    }

    /**
     * @dev Override transfer to prevent transfers of locked tokens
     */
    function _update(address from, address to, uint256 value) internal override {
        if (from != address(0) && to != address(0)) {
            // Check if sender has locked tokens
            StakingInfo memory info = stakingInfo[from];
            if (info.isLocked && block.timestamp < info.stakingTime + info.lockPeriod) {
                require(value <= balanceOf(from) - info.stakedAmount, "Tokens are locked");
            }
        }
        super._update(from, to, value);
    }
}