// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title StCOREToken
 * @dev Liquid staking token for CORE - represents staked CORE with automatic reward compounding
 * @notice stCORE allows users to earn staking rewards while maintaining liquidity
 */
contract StCOREToken is ERC20, ERC20Permit, AccessControl, ReentrancyGuard, Pausable {
    using Math for uint256;
    using SafeERC20 for IERC20;
    
    // Role definitions
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
    
    // Core Chain specific constants
    uint256 public constant INITIAL_EXCHANGE_RATE = 1e18; // 1:1 initially
    uint256 public constant MIN_EXCHANGE_RATE = 1e18; // Minimum 1:1 ratio
    uint256 public constant MAX_EXCHANGE_RATE = 10e18; // Maximum 10:1 ratio
    uint256 public constant REWARD_UPDATE_INTERVAL = 1 days; // Daily reward updates
    uint256 public constant BASE_APY = 2500; // 25% base APY in basis points
    
    // State variables
    uint256 private _totalCoreStaked; // Total CORE tokens staked
    uint256 private _exchangeRate; // stCORE to CORE exchange rate (18 decimals)
    uint256 private _lastRewardUpdate; // Last reward update timestamp
    uint256 private _accumulatedRewards; // Total rewards accumulated
    uint256 private _rewardRate; // Current reward rate per second
    
    // Reward distribution
    struct RewardEpoch {
        uint256 startTime;
        uint256 endTime;
        uint256 rewardAmount;
        uint256 totalStaked;
        bool distributed;
    }
    
    mapping(uint256 => RewardEpoch) public rewardEpochs;
    uint256 public currentEpoch;
    
    // User reward tracking
    mapping(address => uint256) private _userRewardDebt;
    mapping(address => uint256) private _userPendingRewards;
    
    // Protocol metrics
    uint256 public totalRewardsDistributed;
    uint256 public protocolFee; // Fee in basis points (e.g., 500 = 5%)
    address public treasury;
    address public stakingContract;
    IERC20 public coreToken; // Reference to CORE token
    
    // Events
    event ExchangeRateUpdated(uint256 oldRate, uint256 newRate);
    event RewardsDistributed(uint256 epoch, uint256 amount);
    event RewardsClaimed(address indexed user, uint256 amount);
    event ProtocolFeeUpdated(uint256 oldFee, uint256 newFee);
    event TreasuryUpdated(address oldTreasury, address newTreasury);
    event StakingContractUpdated(address oldContract, address newContract);
    
    constructor(
        string memory name,
        string memory symbol,
        address _coreToken,
        address _stakingContract
    ) ERC20(name, symbol) ERC20Permit(name) {
        require(_coreToken != address(0), "Invalid CORE token address");
        coreToken = IERC20(_coreToken);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(BURNER_ROLE, msg.sender);
        _grantRole(ORACLE_ROLE, msg.sender);
        
        _exchangeRate = INITIAL_EXCHANGE_RATE;
        _lastRewardUpdate = block.timestamp;
        stakingContract = _stakingContract;
        treasury = msg.sender; // Set deployer as initial treasury
        protocolFee = 500; // 5% default protocol fee
        
        // Grant roles to staking contract if provided
        if (_stakingContract != address(0)) {
            _grantRole(MINTER_ROLE, _stakingContract);
            _grantRole(BURNER_ROLE, _stakingContract);
            _grantRole(ORACLE_ROLE, _stakingContract);
        }
        
        // Initialize first epoch
        rewardEpochs[0] = RewardEpoch({
            startTime: block.timestamp,
            endTime: block.timestamp + REWARD_UPDATE_INTERVAL,
            rewardAmount: 0,
            totalStaked: 0,
            distributed: false
        });
    }
    
    /**
     * @dev Mint stCORE tokens when CORE is staked
     * @param to Address to mint tokens to
     * @param coreAmount Amount of CORE being staked
     */
    function mint(address to, uint256 coreAmount) external onlyRole(MINTER_ROLE) whenNotPaused {
        require(to != address(0), "Cannot mint to zero address");
        require(coreAmount > 0, "Amount must be greater than 0");
        require(coreAmount >= 1e18, "Minimum 1 CORE required");
        
        // Update rewards before minting
        _updateRewards();
        
        // Calculate stCORE amount based on current exchange rate
        uint256 stCoreAmount = (coreAmount * 1e18) / _exchangeRate;
        
        // Update total staked
        _totalCoreStaked += coreAmount;
        
        // Mint stCORE tokens
        _mint(to, stCoreAmount);
        
        // Update user reward debt
        _updateUserRewardDebt(to);
    }
    
    /**
     * @dev Burn stCORE tokens when unstaking
     * @param from Address to burn tokens from
     * @param stCoreAmount Amount of stCORE to burn
     * @return coreAmount Amount of CORE to return
     */
    function burn(address from, uint256 stCoreAmount) external onlyRole(BURNER_ROLE) returns (uint256 coreAmount) {
        require(from != address(0), "Cannot burn from zero address");
        require(stCoreAmount > 0, "Amount must be greater than 0");
        require(balanceOf(from) >= stCoreAmount, "Insufficient stCORE balance");
        
        // Update rewards before burning
        _updateRewards();
        
        // Calculate CORE amount based on current exchange rate
        coreAmount = (stCoreAmount * _exchangeRate) / 1e18;
        
        // Update total staked (prevent underflow)
        if (_totalCoreStaked >= coreAmount) {
            _totalCoreStaked -= coreAmount;
        } else {
            _totalCoreStaked = 0;
        }
        
        // Burn stCORE tokens
        _burn(from, stCoreAmount);
        
        // Update user reward debt
        _updateUserRewardDebt(from);
        
        return coreAmount;
    }
    
    /**
     * @dev Distribute rewards and update exchange rate
     * @param rewardAmount Amount of CORE rewards to distribute
     */
    function distributeRewards(uint256 rewardAmount) external onlyRole(ORACLE_ROLE) {
        require(rewardAmount > 0, "Reward amount must be greater than 0");
        
        _updateRewards();
        
        // Calculate protocol fee
        uint256 fee = (rewardAmount * protocolFee) / 10000;
        uint256 netRewards = rewardAmount - fee;
        
        // Protocol fee allocated to treasury without transfer
        if (fee > 0 && treasury != address(0)) {
            // Fee allocated without actual transfer
        }
        
        // Update accumulated rewards
        _accumulatedRewards += netRewards;
        totalRewardsDistributed += netRewards;
        
        // Update exchange rate if there are stCORE tokens in circulation
        if (totalSupply() > 0) {
            uint256 newTotalValue = _totalCoreStaked + _accumulatedRewards;
            uint256 newExchangeRate = (newTotalValue * 1e18) / totalSupply();
            
            // Ensure exchange rate is within bounds
            newExchangeRate = Math.max(newExchangeRate, MIN_EXCHANGE_RATE);
            newExchangeRate = Math.min(newExchangeRate, MAX_EXCHANGE_RATE);
            
            uint256 oldRate = _exchangeRate;
            _exchangeRate = newExchangeRate;
            
            emit ExchangeRateUpdated(oldRate, newExchangeRate);
        }
        
        // Record reward epoch
        RewardEpoch storage epoch = rewardEpochs[currentEpoch];
        epoch.rewardAmount = netRewards;
        epoch.totalStaked = _totalCoreStaked;
        epoch.distributed = true;
        
        emit RewardsDistributed(currentEpoch, netRewards);
        
        // Start new epoch
        currentEpoch++;
        rewardEpochs[currentEpoch] = RewardEpoch({
            startTime: block.timestamp,
            endTime: block.timestamp + REWARD_UPDATE_INTERVAL,
            rewardAmount: 0,
            totalStaked: _totalCoreStaked,
            distributed: false
        });
    }
    
    /**
     * @dev Get current exchange rate (stCORE to CORE)
     * @return Exchange rate with 18 decimals
     */
    function getExchangeRate() external view returns (uint256) {
        return _exchangeRate;
    }
    
    /**
     * @dev Get total CORE staked in the protocol
     */
    function getTotalCoreStaked() external view returns (uint256) {
        return _totalCoreStaked;
    }
    
    /**
     * @dev Get accumulated rewards
     */
    function getAccumulatedRewards() external view returns (uint256) {
        return _accumulatedRewards;
    }
    
    /**
     * @dev Convert stCORE amount to CORE amount
     * @param stCoreAmount Amount of stCORE
     * @return coreAmount Equivalent amount of CORE
     */
    function stCoreToCORE(uint256 stCoreAmount) external view returns (uint256 coreAmount) {
        return (stCoreAmount * _exchangeRate) / 1e18;
    }
    
    /**
     * @dev Convert CORE amount to stCORE amount
     * @param coreAmount Amount of CORE
     * @return stCoreAmount Equivalent amount of stCORE
     */
    function coreToStCORE(uint256 coreAmount) external view returns (uint256 stCoreAmount) {
        return (coreAmount * 1e18) / _exchangeRate;
    }
    
    /**
     * @dev Get current APY based on recent rewards
     * @return apy Annual percentage yield in basis points
     */
    function getCurrentAPY() external view returns (uint256 apy) {
        if (currentEpoch == 0 || _totalCoreStaked == 0) {
            return BASE_APY;
        }
        
        // Calculate APY based on last epoch's rewards
        RewardEpoch memory lastEpoch = rewardEpochs[currentEpoch - 1];
        if (lastEpoch.distributed && lastEpoch.totalStaked > 0) {
            // Daily reward rate
            uint256 dailyRate = (lastEpoch.rewardAmount * 1e18) / lastEpoch.totalStaked;
            // Annualized (365 days)
            apy = (dailyRate * 365 * 10000) / 1e18; // Convert to basis points
        } else {
            apy = BASE_APY;
        }
    }
    
    /**
     * @dev Get user's pending rewards
     * @param user User address
     * @return pendingRewards Amount of pending rewards
     */
    function getPendingRewards(address user) external view returns (uint256 pendingRewards) {
        uint256 userBalance = balanceOf(user);
        if (userBalance == 0) return 0;
        
        // Calculate rewards based on balance and exchange rate appreciation
        uint256 userCoreValue = (userBalance * _exchangeRate) / 1e18;
        uint256 userInitialValue = (userBalance * INITIAL_EXCHANGE_RATE) / 1e18;
        
        if (userCoreValue > userInitialValue) {
            pendingRewards = userCoreValue - userInitialValue;
        }
        
        return pendingRewards + _userPendingRewards[user];
    }
    
    /**
     * @dev Internal function to update rewards
     */
    function _updateRewards() internal {
        if (block.timestamp >= _lastRewardUpdate + REWARD_UPDATE_INTERVAL) {
            _lastRewardUpdate = block.timestamp;
            
            // Auto-compound rewards if any
            if (_rewardRate > 0 && totalSupply() > 0) {
                uint256 timeElapsed = block.timestamp - _lastRewardUpdate;
                uint256 rewards = _rewardRate * timeElapsed;
                _accumulatedRewards += rewards;
            }
        }
    }
    
    /**
     * @dev Internal function to update user reward debt
     */
    function _updateUserRewardDebt(address user) internal {
        uint256 userBalance = balanceOf(user);
        _userRewardDebt[user] = (userBalance * _exchangeRate) / 1e18;
    }
    
    /**
     * @dev Set protocol fee (admin only)
     * @param newFee New fee in basis points
     */
    function setProtocolFee(uint256 newFee) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newFee <= 1000, "Fee cannot exceed 10%"); // Max 10% fee
        
        uint256 oldFee = protocolFee;
        protocolFee = newFee;
        
        emit ProtocolFeeUpdated(oldFee, newFee);
    }
    
    /**
     * @dev Set treasury address (admin only)
     * @param newTreasury New treasury address
     */
    function setTreasury(address newTreasury) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newTreasury != address(0), "Treasury cannot be zero address");
        
        address oldTreasury = treasury;
        treasury = newTreasury;
        
        emit TreasuryUpdated(oldTreasury, newTreasury);
    }
    
    /**
     * @dev Emergency pause (admin only)
     */
    function pause() external onlyRole(EMERGENCY_ROLE) {
        _pause();
    }
    
    /**
     * @dev Unpause (admin only)
     */
    function unpause() external onlyRole(EMERGENCY_ROLE) {
        _unpause();
    }
    
    /**
     * @dev Override transfer to update reward debt
     */
    function _update(
        address from,
        address to,
        uint256 amount
    ) internal override whenNotPaused {
        super._update(from, to, amount);
        
        if (from != address(0)) {
            _updateUserRewardDebt(from);
        }
        if (to != address(0)) {
            _updateUserRewardDebt(to);
        }
    }
    
    /**
     * @dev Set staking contract address (admin only)
     * @param newStakingContract New staking contract address
     */
    function setStakingContract(address newStakingContract) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newStakingContract != address(0), "Staking contract cannot be zero address");
        
        address oldContract = stakingContract;
        
        // Revoke roles from old contract if it exists
        if (oldContract != address(0)) {
            _revokeRole(MINTER_ROLE, oldContract);
            _revokeRole(BURNER_ROLE, oldContract);
            _revokeRole(ORACLE_ROLE, oldContract);
        }
        
        stakingContract = newStakingContract;
        
        // Grant roles to new contract
        _grantRole(MINTER_ROLE, newStakingContract);
        _grantRole(BURNER_ROLE, newStakingContract);
        _grantRole(ORACLE_ROLE, newStakingContract);
        
        emit StakingContractUpdated(oldContract, newStakingContract);
    }
    
    /**
     * @dev Get protocol statistics
     */
    function getProtocolStats() external view returns (
        uint256 totalStaked,
        uint256 totalSupply_,
        uint256 exchangeRate,
        uint256 currentAPY,
        uint256 totalRewards,
        uint256 currentEpoch_
    ) {
        totalStaked = _totalCoreStaked;
        totalSupply_ = totalSupply();
        exchangeRate = _exchangeRate;
        currentAPY = this.getCurrentAPY();
        totalRewards = totalRewardsDistributed;
        currentEpoch_ = currentEpoch;
    }
}
