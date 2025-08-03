// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title StCOREToken
 * @dev Staked CORE token representing staked positions in the CoreLiquid protocol
 */
contract StCOREToken is ERC20, ERC20Burnable, ERC20Pausable, AccessControl, ReentrancyGuard {
    using Math for uint256;
    
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant EXCHANGE_RATE_UPDATER_ROLE = keccak256("EXCHANGE_RATE_UPDATER_ROLE");
    
    uint256 public constant PRECISION = 1e18;
    uint256 public constant INITIAL_EXCHANGE_RATE = 1e18; // 1:1 initially
    
    // Exchange rate tracking
    uint256 public exchangeRate; // stCORE to CORE exchange rate
    uint256 public totalCOREStaked;
    uint256 public totalRewards;
    uint256 public lastUpdateTimestamp;
    
    // Staking contract address
    address public stakingContract;
    
    // Reward distribution
    uint256 public rewardRate; // Rewards per second
    uint256 public lastRewardTimestamp;
    uint256 public accumulatedRewardsPerShare;
    
    // User reward tracking
    struct UserInfo {
        uint256 rewardDebt;
        uint256 pendingRewards;
        uint256 lastClaimTimestamp;
    }
    
    mapping(address => UserInfo) public userInfo;
    
    // Events
    event ExchangeRateUpdated(uint256 oldRate, uint256 newRate, uint256 timestamp);
    event RewardsDistributed(uint256 amount, uint256 timestamp);
    event RewardsClaimed(address indexed user, uint256 amount);
    event StakingContractUpdated(address oldContract, address newContract);
    event RewardRateUpdated(uint256 oldRate, uint256 newRate);
    
    constructor(
        string memory name,
        string memory symbol,
        address _stakingContract
    ) ERC20(name, symbol) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(BURNER_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(EXCHANGE_RATE_UPDATER_ROLE, msg.sender);
        
        stakingContract = _stakingContract;
        exchangeRate = INITIAL_EXCHANGE_RATE;
        lastUpdateTimestamp = block.timestamp;
        lastRewardTimestamp = block.timestamp;
        
        // Grant roles to staking contract if provided
        if (_stakingContract != address(0)) {
            _grantRole(MINTER_ROLE, _stakingContract);
            _grantRole(BURNER_ROLE, _stakingContract);
            _grantRole(EXCHANGE_RATE_UPDATER_ROLE, _stakingContract);
        }
    }
    
    /**
     * @dev Mint stCORE tokens (only minters)
     */
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) nonReentrant {
        require(to != address(0), "StCOREToken: mint to zero address");
        require(amount > 0, "StCOREToken: invalid amount");
        
        _updateRewards(to);
        _mint(to, amount);
    }
    
    /**
     * @dev Burn stCORE tokens (only burners)
     */
    function burn(uint256 amount) public override onlyRole(BURNER_ROLE) {
        _updateRewards(msg.sender);
        _burn(msg.sender, amount);
    }
    
    /**
     * @dev Burn stCORE tokens from specific account (only burners)
     */
    function burnFrom(address account, uint256 amount) public override onlyRole(BURNER_ROLE) {
        _updateRewards(account);
        _spendAllowance(account, _msgSender(), amount);
        _burn(account, amount);
    }
    
    /**
     * @dev Update exchange rate (only exchange rate updaters)
     */
    function updateExchangeRate(uint256 newRate) external onlyRole(EXCHANGE_RATE_UPDATER_ROLE) {
        require(newRate > 0, "StCOREToken: invalid exchange rate");
        
        uint256 oldRate = exchangeRate;
        exchangeRate = newRate;
        lastUpdateTimestamp = block.timestamp;
        
        emit ExchangeRateUpdated(oldRate, newRate, block.timestamp);
    }
    
    /**
     * @dev Get current exchange rate
     */
    function getExchangeRate() external view returns (uint256) {
        return exchangeRate;
    }
    
    /**
     * @dev Convert stCORE amount to CORE amount
     */
    function stCOREToCORE(uint256 stCOREAmount) external view returns (uint256) {
        if (stCOREAmount == 0) return 0;
        return (stCOREAmount * exchangeRate) / PRECISION;
    }
    
    /**
     * @dev Convert CORE amount to stCORE amount
     */
    function COREToStCORE(uint256 coreAmount) external view returns (uint256) {
        if (coreAmount == 0 || exchangeRate == 0) return 0;
        return (coreAmount * PRECISION) / exchangeRate;
    }
    
    /**
     * @dev Distribute rewards to all stakers
     */
    function distributeRewards(uint256 rewardAmount) external onlyRole(ADMIN_ROLE) nonReentrant {
        require(rewardAmount > 0, "StCOREToken: invalid reward amount");
        
        _updateGlobalRewards();
        
        if (totalSupply() > 0) {
            accumulatedRewardsPerShare += (rewardAmount * PRECISION) / totalSupply();
        }
        
        totalRewards += rewardAmount;
        
        emit RewardsDistributed(rewardAmount, block.timestamp);
    }
    
    /**
     * @dev Claim pending rewards
     */
    function claimRewards() external nonReentrant whenNotPaused {
        _updateRewards(msg.sender);
        
        UserInfo storage user = userInfo[msg.sender];
        uint256 pending = user.pendingRewards;
        
        require(pending > 0, "StCOREToken: no rewards to claim");
        
        user.pendingRewards = 0;
        user.lastClaimTimestamp = block.timestamp;
        
        // Transfer rewards (this would typically transfer CORE tokens)
        // For now, we'll emit an event
        emit RewardsClaimed(msg.sender, pending);
    }
    
    /**
     * @dev Get pending rewards for a user
     */
    function getPendingRewards(address user) external view returns (uint256) {
        UserInfo storage userInfoData = userInfo[user];
        uint256 userBalance = balanceOf(user);
        
        if (userBalance == 0) {
            return userInfoData.pendingRewards;
        }
        
        uint256 currentAccumulatedRewards = accumulatedRewardsPerShare;
        
        // Calculate additional rewards since last update
        if (block.timestamp > lastRewardTimestamp && totalSupply() > 0) {
            uint256 timeElapsed = block.timestamp - lastRewardTimestamp;
            uint256 additionalRewards = timeElapsed * rewardRate;
            currentAccumulatedRewards += (additionalRewards * PRECISION) / totalSupply();
        }
        
        uint256 userRewards = (userBalance * currentAccumulatedRewards) / PRECISION;
        return userInfoData.pendingRewards + userRewards - userInfoData.rewardDebt;
    }
    
    /**
     * @dev Set reward rate (rewards per second)
     */
    function setRewardRate(uint256 _rewardRate) external onlyRole(ADMIN_ROLE) {
        _updateGlobalRewards();
        
        uint256 oldRate = rewardRate;
        rewardRate = _rewardRate;
        
        emit RewardRateUpdated(oldRate, _rewardRate);
    }
    
    /**
     * @dev Update staking contract address
     */
    function setStakingContract(address _stakingContract) external onlyRole(ADMIN_ROLE) {
        require(_stakingContract != address(0), "StCOREToken: invalid staking contract");
        
        address oldContract = stakingContract;
        
        // Revoke roles from old contract
        if (oldContract != address(0)) {
            _revokeRole(MINTER_ROLE, oldContract);
            _revokeRole(BURNER_ROLE, oldContract);
            _revokeRole(EXCHANGE_RATE_UPDATER_ROLE, oldContract);
        }
        
        stakingContract = _stakingContract;
        
        // Grant roles to new contract
        _grantRole(MINTER_ROLE, _stakingContract);
        _grantRole(BURNER_ROLE, _stakingContract);
        _grantRole(EXCHANGE_RATE_UPDATER_ROLE, _stakingContract);
        
        emit StakingContractUpdated(oldContract, _stakingContract);
    }
    
    /**
     * @dev Get staking statistics
     */
    function getStakingStats() external view returns (
        uint256 totalStaked,
        uint256 totalRewardsDistributed,
        uint256 currentExchangeRate,
        uint256 totalStakers,
        uint256 currentRewardRate
    ) {
        return (
            totalCOREStaked,
            totalRewards,
            exchangeRate,
            totalSupply() > 0 ? 1 : 0, // Simplified staker count
            rewardRate
        );
    }
    
    /**
     * @dev Override transfer to update rewards
     */
    function _update(address from, address to, uint256 value) internal override(ERC20, ERC20Pausable) {
        if (from != address(0)) {
            _updateRewards(from);
        }
        if (to != address(0)) {
            _updateRewards(to);
        }
        
        super._update(from, to, value);
    }
    
    /**
     * @dev Update rewards for a user
     */
    function _updateRewards(address user) internal {
        _updateGlobalRewards();
        
        UserInfo storage userInfoData = userInfo[user];
        uint256 userBalance = balanceOf(user);
        
        if (userBalance > 0) {
            uint256 userRewards = (userBalance * accumulatedRewardsPerShare) / PRECISION;
            userInfoData.pendingRewards += userRewards - userInfoData.rewardDebt;
        }
        
        userInfoData.rewardDebt = (userBalance * accumulatedRewardsPerShare) / PRECISION;
    }
    
    /**
     * @dev Update global reward accumulation
     */
    function _updateGlobalRewards() internal {
        if (block.timestamp <= lastRewardTimestamp) {
            return;
        }
        
        if (totalSupply() == 0) {
            lastRewardTimestamp = block.timestamp;
            return;
        }
        
        uint256 timeElapsed = block.timestamp - lastRewardTimestamp;
        uint256 rewards = timeElapsed * rewardRate;
        
        if (rewards > 0) {
            accumulatedRewardsPerShare += (rewards * PRECISION) / totalSupply();
        }
        
        lastRewardTimestamp = block.timestamp;
    }
    
    /**
     * @dev Update total CORE staked (called by staking contract)
     */
    function updateTotalStaked(uint256 _totalCOREStaked) external onlyRole(EXCHANGE_RATE_UPDATER_ROLE) {
        totalCOREStaked = _totalCOREStaked;
        
        // Update exchange rate based on total staked and total supply
        if (totalSupply() > 0) {
            uint256 newRate = (totalCOREStaked * PRECISION) / totalSupply();
            if (newRate != exchangeRate) {
                uint256 oldRate = exchangeRate;
                exchangeRate = newRate;
                lastUpdateTimestamp = block.timestamp;
                emit ExchangeRateUpdated(oldRate, newRate, block.timestamp);
            }
        }
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
        require(token != address(this), "StCOREToken: cannot withdraw own tokens");
        IERC20(token).transfer(to, amount);
    }
    
    /**
     * @dev Get user staking information
     */
    function getUserStakingInfo(address user) external view returns (
        uint256 stakedAmount,
        uint256 pendingRewards,
        uint256 rewardDebt,
        uint256 lastClaimTimestamp,
        uint256 coreValue
    ) {
        UserInfo storage userInfoData = userInfo[user];
        uint256 balance = balanceOf(user);
        
        return (
            balance,
            this.getPendingRewards(user),
            userInfoData.rewardDebt,
            userInfoData.lastClaimTimestamp,
            (balance * exchangeRate) / PRECISION
        );
    }
}
