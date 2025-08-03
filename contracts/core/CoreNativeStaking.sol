// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

// Core Chain specific interfaces
interface ICoreBTCStaking {
    function stakeBTC(bytes32 btcTxHash, uint256 amount, uint256 lockTime, address validator) external;
    function redeemBTC(bytes32 stakingTxHash) external;
    function claimRewards(address delegator) external returns (uint256);
    function getStakingInfo(address delegator) external view returns (uint256, uint256, uint256);
}

interface ICoreValidator {
    function delegateToValidator(address validator, uint256 amount) external;
    function undelegateFromValidator(address validator, uint256 amount) external;
    function getValidatorInfo(address validator) external view returns (uint256, uint256, bool);
    function claimValidatorRewards(address validator) external returns (uint256);
}

// stCORE token interface
interface IStCORE {
    function mint(address to, uint256 amount) external;
    function burn(address from, uint256 amount) external;
    function getExchangeRate() external view returns (uint256);
}

/**
 * @title CoreNativeStaking
 * @dev Implements Core Chain's native BTC staking, stCORE, and Dual Staking mechanisms
 * @notice This contract integrates with Core Chain's unique consensus mechanism
 */
contract CoreNativeStaking is AccessControl, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;
    using Math for uint256;
    
    // Role definitions
    bytes32 public constant VALIDATOR_ROLE = keccak256("VALIDATOR_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
    
    // Contract addresses for Core Chain native contracts
    address public immutable CORE_BTC_STAKING;
    address public immutable CORE_VALIDATOR_SET;
    address public immutable CORE_SLASH_INDICATOR;
    
    IERC20 public immutable coreToken;
    IStCORE public immutable stCoreToken;
    
    // Dual Staking configuration
    struct DualStakingTier {
        uint256 corePerBTC;     // CORE tokens required per BTC
        uint256 multiplier;     // Reward multiplier in basis points
        string tierName;
    }
    
    struct BTCStakingPosition {
        bytes32 btcTxHash;      // Bitcoin transaction hash
        uint256 btcAmount;      // Amount of BTC staked
        uint256 coreStaked;     // Amount of CORE staked for boost
        uint256 lockTime;       // Lock time in blocks
        uint256 startTime;      // Staking start time
        address validator;      // Delegated validator
        uint256 tier;          // Dual staking tier
        bool isActive;         // Position status
        uint256 rewardsClaimed; // Total rewards claimed
    }
    
    struct CoreStakingPosition {
        uint256 amount;         // Amount of CORE staked
        uint256 stCoreAmount;   // Amount of stCORE minted
        uint256 startTime;      // Staking start time
        address validator;      // Delegated validator
        uint256 rewardsClaimed; // Total rewards claimed
        bool isActive;         // Position status
    }
    
    // State variables
    mapping(address => BTCStakingPosition[]) public btcStakingPositions;
    mapping(address => CoreStakingPosition[]) public coreStakingPositions;
    mapping(address => uint256) public totalBTCStaked;
    mapping(address => uint256) public totalCoreStaked;
    mapping(address => uint256) public pendingRewards;
    
    DualStakingTier[4] public dualStakingTiers;
    
    // Protocol metrics
    uint256 public totalBTCInProtocol;
    uint256 public totalCoreInProtocol;
    uint256 public totalStCoreSupply;
    uint256 public totalRewardsDistributed;
    
    // Events
    event BTCStaked(address indexed user, bytes32 btcTxHash, uint256 amount, address validator, uint256 tier);
    event BTCRedeemed(address indexed user, bytes32 btcTxHash, uint256 amount);
    event CoreStaked(address indexed user, uint256 amount, uint256 stCoreAmount, address validator);
    event CoreUnstaked(address indexed user, uint256 amount, uint256 stCoreAmount);
    event RewardsClaimed(address indexed user, uint256 amount);
    event DualStakingTierUpdated(uint256 tier, uint256 corePerBTC, uint256 multiplier);
    
    constructor(
        address _coreToken,
        address _stCoreToken,
        address _coreBTCStaking,
        address _coreValidatorSet,
        address _coreSlashIndicator
    ) {
        coreToken = IERC20(_coreToken);
        stCoreToken = IStCORE(_stCoreToken);
        CORE_BTC_STAKING = _coreBTCStaking;
        CORE_VALIDATOR_SET = _coreValidatorSet;
        CORE_SLASH_INDICATOR = _coreSlashIndicator;
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(OPERATOR_ROLE, msg.sender);
        
        // Initialize dual staking tiers based on Core Chain specifications
        dualStakingTiers[0] = DualStakingTier({
            corePerBTC: 0,      // Base rate
            multiplier: 10000,  // 100% (base)
            tierName: "Base"
        });
        
        dualStakingTiers[1] = DualStakingTier({
            corePerBTC: 1000 * 1e18,  // 1,000 CORE per BTC
            multiplier: 12000,        // 120%
            tierName: "Level 1"
        });
        
        dualStakingTiers[2] = DualStakingTier({
            corePerBTC: 3000 * 1e18,  // 3,000 CORE per BTC
            multiplier: 15000,        // 150%
            tierName: "Level 2"
        });
        
        dualStakingTiers[3] = DualStakingTier({
            corePerBTC: 8000 * 1e18,  // 8,000 CORE per BTC
            multiplier: 20000,        // 200%
            tierName: "Level 3"
        });
    }
    
    /**
     * @dev Stake BTC using Core Chain's native BTC staking mechanism
     * @param btcTxHash Bitcoin transaction hash
     * @param btcAmount Amount of BTC staked (in satoshis)
     * @param lockTime Lock time in Bitcoin blocks
     * @param validator Validator address to delegate to
     * @param coreAmount Amount of CORE to stake for dual staking boost
     */
    function stakeBTC(
        bytes32 btcTxHash,
        uint256 btcAmount,
        uint256 lockTime,
        address validator,
        uint256 coreAmount
    ) external nonReentrant whenNotPaused {
        require(btcAmount >= 0.01 * 1e8, "Minimum 0.01 BTC required"); // 0.01 BTC in satoshis
        require(lockTime >= 10 * 24 * 6, "Minimum 10 days lock time"); // 10 days in Bitcoin blocks
        require(validator != address(0), "Invalid validator");
        
        // Determine dual staking tier
        uint256 tier = _calculateDualStakingTier(btcAmount, coreAmount);
        
        // If CORE is provided for dual staking, stake it
        if (coreAmount > 0) {
            _stakeCoreForDualStaking(msg.sender, coreAmount, validator);
        }
        
        // Interact with Core Chain's native BTC staking
        ICoreBTCStaking(CORE_BTC_STAKING).stakeBTC(btcTxHash, btcAmount, lockTime, validator);
        
        // Record the staking position
        btcStakingPositions[msg.sender].push(BTCStakingPosition({
            btcTxHash: btcTxHash,
            btcAmount: btcAmount,
            coreStaked: coreAmount,
            lockTime: lockTime,
            startTime: block.timestamp,
            validator: validator,
            tier: tier,
            isActive: true,
            rewardsClaimed: 0
        }));
        
        totalBTCStaked[msg.sender] += btcAmount;
        totalBTCInProtocol += btcAmount;
        
        emit BTCStaked(msg.sender, btcTxHash, btcAmount, validator, tier);
    }
    
    /**
     * @dev Stake CORE tokens and receive stCORE (liquid staking)
     * @param amount Amount of CORE to stake
     * @param validator Validator to delegate to
     */
    function stakeCORE(uint256 amount, address validator) external nonReentrant whenNotPaused {
        require(amount > 0, "Amount must be greater than 0");
        require(amount >= 1e18, "Minimum 1 CORE required");
        require(validator != address(0), "Invalid validator");
        
        // Calculate stCORE amount based on exchange rate
        uint256 exchangeRate = stCoreToken.getExchangeRate();
        uint256 stCoreAmount = (amount * 1e18) / exchangeRate;
        
        // Delegate to validator through Core Chain's native mechanism
        ICoreValidator(CORE_VALIDATOR_SET).delegateToValidator(validator, amount);
        
        // Mint stCORE tokens
        stCoreToken.mint(msg.sender, amount);
        
        // Record the staking position
        coreStakingPositions[msg.sender].push(CoreStakingPosition({
            amount: amount,
            stCoreAmount: stCoreAmount,
            startTime: block.timestamp,
            validator: validator,
            rewardsClaimed: 0,
            isActive: true
        }));
        
        totalCoreStaked[msg.sender] += amount;
        totalCoreInProtocol += amount;
        totalStCoreSupply += stCoreAmount;
        
        emit CoreStaked(msg.sender, amount, stCoreAmount, validator);
    }
    
    /**
     * @dev Unstake CORE tokens by burning stCORE
     * @param stCoreAmount Amount of stCORE to burn
     * @param positionIndex Index of the staking position
     */
    function unstakeCORE(uint256 stCoreAmount, uint256 positionIndex) external nonReentrant {
        require(positionIndex < coreStakingPositions[msg.sender].length, "Invalid position");
        
        CoreStakingPosition storage position = coreStakingPositions[msg.sender][positionIndex];
        require(position.isActive, "Position not active");
        require(position.stCoreAmount >= stCoreAmount, "Insufficient stCORE");
        
        // Calculate CORE amount based on exchange rate
        uint256 exchangeRate = stCoreToken.getExchangeRate();
        uint256 coreAmount = (stCoreAmount * exchangeRate) / 1e18;
        
        // Burn stCORE tokens
        stCoreToken.burn(msg.sender, stCoreAmount);
        
        // Undelegate from validator
        ICoreValidator(CORE_VALIDATOR_SET).undelegateFromValidator(position.validator, coreAmount);
        
        // CORE tokens returned without transfer
        
        // Update position
        position.amount -= coreAmount;
        position.stCoreAmount -= stCoreAmount;
        
        if (position.stCoreAmount == 0) {
            position.isActive = false;
        }
        
        totalCoreStaked[msg.sender] -= coreAmount;
        totalCoreInProtocol -= coreAmount;
        totalStCoreSupply -= stCoreAmount;
        
        emit CoreUnstaked(msg.sender, coreAmount, stCoreAmount);
    }
    
    /**
     * @dev Claim rewards from BTC and CORE staking
     */
    function claimRewards() external nonReentrant {
        uint256 totalRewards = 0;
        
        // Claim BTC staking rewards
        totalRewards += ICoreBTCStaking(CORE_BTC_STAKING).claimRewards(msg.sender);
        
        // Add any pending rewards
        totalRewards += pendingRewards[msg.sender];
        pendingRewards[msg.sender] = 0;
        
        if (totalRewards > 0) {
            // Rewards claimed without transfer
            totalRewardsDistributed += totalRewards;
            emit RewardsClaimed(msg.sender, totalRewards);
        }
    }
    
    /**
     * @dev Redeem BTC after lock time expires
     * @param positionIndex Index of the BTC staking position
     */
    function redeemBTC(uint256 positionIndex) external nonReentrant {
        require(positionIndex < btcStakingPositions[msg.sender].length, "Invalid position");
        
        BTCStakingPosition storage position = btcStakingPositions[msg.sender][positionIndex];
        require(position.isActive, "Position not active");
        require(block.timestamp >= position.startTime + (position.lockTime * 10 * 60), "Lock time not expired");
        
        // Redeem BTC through Core Chain's native mechanism
        ICoreBTCStaking(CORE_BTC_STAKING).redeemBTC(position.btcTxHash);
        
        // If CORE was staked for dual staking, handle it
        if (position.coreStaked > 0) {
            _unstakeCoreFromDualStaking(msg.sender, position.coreStaked, position.validator);
        }
        
        // Update state
        totalBTCStaked[msg.sender] -= position.btcAmount;
        totalBTCInProtocol -= position.btcAmount;
        
        position.isActive = false;
        
        emit BTCRedeemed(msg.sender, position.btcTxHash, position.btcAmount);
    }
    
    /**
     * @dev Calculate dual staking tier based on CORE:BTC ratio
     */
    function _calculateDualStakingTier(uint256 btcAmount, uint256 coreAmount) internal view returns (uint256) {
        if (coreAmount == 0) return 0; // Base tier
        
        // Convert BTC from satoshis to 18 decimals for calculation
        uint256 btcIn18Decimals = btcAmount * 1e10; // Convert from 8 to 18 decimals
        uint256 corePerBTC = (coreAmount * 1e18) / btcIn18Decimals;
        
        for (uint256 i = 3; i > 0; i--) {
            if (corePerBTC >= dualStakingTiers[i].corePerBTC) {
                return i;
            }
        }
        
        return 0; // Base tier
    }
    
    /**
     * @dev Internal function to stake CORE for dual staking
     */
    function _stakeCoreForDualStaking(address user, uint256 amount, address validator) internal {
        ICoreValidator(CORE_VALIDATOR_SET).delegateToValidator(validator, amount);
        totalCoreStaked[user] += amount;
        totalCoreInProtocol += amount;
    }
    
    /**
     * @dev Internal function to unstake CORE from dual staking
     */
    function _unstakeCoreFromDualStaking(address user, uint256 amount, address validator) internal {
        ICoreValidator(CORE_VALIDATOR_SET).undelegateFromValidator(validator, amount);
        // CORE tokens returned without transfer
        totalCoreStaked[user] -= amount;
        totalCoreInProtocol -= amount;
    }
    
    /**
     * @dev Get user's staking information
     */
    function getUserStakingInfo(address user) external view returns (
        uint256 btcStaked,
        uint256 coreStaked,
        uint256 stCoreBalance,
        uint256 pendingReward,
        uint256 activeBTCPositions,
        uint256 activeCorePositions
    ) {
        btcStaked = totalBTCStaked[user];
        coreStaked = totalCoreStaked[user];
        stCoreBalance = totalStCoreSupply > 0 ? (coreStaked * 1e18) / stCoreToken.getExchangeRate() : 0;
        pendingReward = pendingRewards[user];
        
        // Count active positions
        for (uint256 i = 0; i < btcStakingPositions[user].length; i++) {
            if (btcStakingPositions[user][i].isActive) {
                activeBTCPositions++;
            }
        }
        
        for (uint256 i = 0; i < coreStakingPositions[user].length; i++) {
            if (coreStakingPositions[user][i].isActive) {
                activeCorePositions++;
            }
        }
    }
    
    /**
     * @dev Get dual staking tier information
     */
    function getDualStakingTiers() external view returns (DualStakingTier[4] memory) {
        return dualStakingTiers;
    }
    
    /**
     * @dev Update dual staking tier (admin only)
     */
    function updateDualStakingTier(
        uint256 tier,
        uint256 corePerBTC,
        uint256 multiplier,
        string memory tierName
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(tier < 4, "Invalid tier");
        
        dualStakingTiers[tier] = DualStakingTier({
            corePerBTC: corePerBTC,
            multiplier: multiplier,
            tierName: tierName
        });
        
        emit DualStakingTierUpdated(tier, corePerBTC, multiplier);
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
}
