// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title CoreBitcoinDualStaking
 * @dev Dual staking contract for Core and Bitcoin tokens
 */
contract CoreBitcoinDualStaking is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    
    struct StakeInfo {
        uint256 coreAmount;
        uint256 bitcoinAmount;
        uint256 timestamp;
        uint256 rewardDebt;
        bool isActive;
    }
    
    IERC20 public coreToken;
    IERC20 public bitcoinToken;
    IERC20 public rewardToken;
    
    mapping(address => StakeInfo) public stakes;
    mapping(address => uint256) public userRewards;
    
    uint256 public totalCoreStaked;
    uint256 public totalBitcoinStaked;
    uint256 public rewardRate = 100; // Rewards per second
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;
    
    uint256 public constant MINIMUM_STAKE_PERIOD = 7 days;
    uint256 public constant CORE_WEIGHT = 60; // 60% weight for CORE
    uint256 public constant BITCOIN_WEIGHT = 40; // 40% weight for Bitcoin
    
    event Staked(address indexed user, uint256 coreAmount, uint256 bitcoinAmount);
    event Withdrawn(address indexed user, uint256 coreAmount, uint256 bitcoinAmount);
    event RewardClaimed(address indexed user, uint256 amount);
    
    constructor(
        address _coreToken,
        address _bitcoinToken,
        address _rewardToken
    ) Ownable(msg.sender) {
        coreToken = IERC20(_coreToken);
        bitcoinToken = IERC20(_bitcoinToken);
        rewardToken = IERC20(_rewardToken);
        lastUpdateTime = block.timestamp;
    }
    
    function stake(uint256 coreAmount, uint256 bitcoinAmount) external nonReentrant {
        require(coreAmount > 0 || bitcoinAmount > 0, "Must stake something");
        
        updateReward(msg.sender);
        
        if (coreAmount > 0) {
            coreToken.safeTransferFrom(msg.sender, address(this), coreAmount);
            totalCoreStaked += coreAmount;
        }
        
        if (bitcoinAmount > 0) {
            bitcoinToken.safeTransferFrom(msg.sender, address(this), bitcoinAmount);
            totalBitcoinStaked += bitcoinAmount;
        }
        
        StakeInfo storage userStake = stakes[msg.sender];
        userStake.coreAmount += coreAmount;
        userStake.bitcoinAmount += bitcoinAmount;
        userStake.timestamp = block.timestamp;
        userStake.isActive = true;
        
        emit Staked(msg.sender, coreAmount, bitcoinAmount);
    }
    
    function withdraw(uint256 coreAmount, uint256 bitcoinAmount) external nonReentrant {
        StakeInfo storage userStake = stakes[msg.sender];
        require(userStake.isActive, "No active stake");
        require(block.timestamp >= userStake.timestamp + MINIMUM_STAKE_PERIOD, "Minimum stake period not met");
        require(coreAmount <= userStake.coreAmount, "Insufficient CORE staked");
        require(bitcoinAmount <= userStake.bitcoinAmount, "Insufficient Bitcoin staked");
        
        updateReward(msg.sender);
        
        if (coreAmount > 0) {
            userStake.coreAmount -= coreAmount;
            totalCoreStaked -= coreAmount;
            coreToken.safeTransfer(msg.sender, coreAmount);
        }
        
        if (bitcoinAmount > 0) {
            userStake.bitcoinAmount -= bitcoinAmount;
            totalBitcoinStaked -= bitcoinAmount;
            bitcoinToken.safeTransfer(msg.sender, bitcoinAmount);
        }
        
        if (userStake.coreAmount == 0 && userStake.bitcoinAmount == 0) {
            userStake.isActive = false;
        }
        
        emit Withdrawn(msg.sender, coreAmount, bitcoinAmount);
    }
    
    function claimReward() external nonReentrant {
        updateReward(msg.sender);
        
        uint256 reward = userRewards[msg.sender];
        require(reward > 0, "No rewards to claim");
        
        userRewards[msg.sender] = 0;
        rewardToken.safeTransfer(msg.sender, reward);
        
        emit RewardClaimed(msg.sender, reward);
    }
    
    function updateReward(address account) internal {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = block.timestamp;
        
        if (account != address(0)) {
            userRewards[account] = earned(account);
            stakes[account].rewardDebt = rewardPerTokenStored;
        }
    }
    
    function rewardPerToken() public view returns (uint256) {
        uint256 totalStaked = totalCoreStaked + totalBitcoinStaked;
        if (totalStaked == 0) {
            return rewardPerTokenStored;
        }
        
        return rewardPerTokenStored + 
            (((block.timestamp - lastUpdateTime) * rewardRate * 1e18) / totalStaked);
    }
    
    function earned(address account) public view returns (uint256) {
        StakeInfo memory userStake = stakes[account];
        uint256 userTotalStaked = userStake.coreAmount + userStake.bitcoinAmount;
        
        return (userTotalStaked * (rewardPerToken() - userStake.rewardDebt)) / 1e18 + userRewards[account];
    }
    
    function getStakeInfo(address account) external view returns (StakeInfo memory) {
        return stakes[account];
    }
    
    function setRewardRate(uint256 _rewardRate) external onlyOwner {
        updateReward(address(0));
        rewardRate = _rewardRate;
    }
}