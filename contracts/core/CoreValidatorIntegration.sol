// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

// Interfaces for Core Chain system contracts
interface ICoreValidatorSet {
    function getValidators() external view returns (address[] memory);
    function isCurrentValidator(address validator) external view returns (bool);
    function getValidatorInfo(address validator) external view returns (
        uint256 votingPower,
        uint256 jailed,
        uint256 incoming
    );
    function delegate(address validator) external payable;
    function undelegate(address validator, uint256 amount) external;
    function redelegate(address srcValidator, address dstValidator, uint256 amount) external;
}

interface ICoreSlashIndicator {
    function getSlashRecord(address validator) external view returns (uint256, uint256);
    function isSlashed(address validator) external view returns (bool);
}

interface ICoreSystemReward {
    function claimRewards() external;
    function getRewardInfo(address delegator) external view returns (uint256, uint256);
}

/**
 * @title CoreValidatorIntegration
 * @dev Integrates with Core Chain's unique Delegated Proof of Work (DPoW) and validator system
 * @notice This contract handles validator delegation, hash power management, and consensus participation
 */
contract CoreValidatorIntegration is AccessControl, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;
    using Math for uint256;
    
    // Role definitions
    bytes32 public constant VALIDATOR_MANAGER_ROLE = keccak256("VALIDATOR_MANAGER_ROLE");
    bytes32 public constant HASH_POWER_ORACLE_ROLE = keccak256("HASH_POWER_ORACLE_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
    
    // Core Chain system contracts (precompiled addresses)
    address public constant CORE_VALIDATOR_SET = 0x0000000000000000000000000000000000001000;
    address public constant CORE_SLASH_INDICATOR = 0x0000000000000000000000000000000000001001;
    address public constant CORE_SYSTEM_REWARD = 0x0000000000000000000000000000000000001002;
    address public constant CORE_LIGHT_CLIENT = 0x0000000000000000000000000000000000001003;
    address public constant CORE_RELAY_HUB = 0x0000000000000000000000000000000000001004;
    
    // Validator information structure
    struct ValidatorInfo {
        address validatorAddress;
        string moniker;
        string website;
        string details;
        uint256 commission; // Commission rate in basis points
        uint256 votingPower;
        uint256 totalDelegated;
        uint256 selfStake;
        bool isActive;
        bool isJailed;
        uint256 jailTime;
        uint256 hashPower; // Bitcoin hash power delegated
        uint256 lastRewardClaim;
        uint256 slashCount;
        uint256 uptime; // Uptime percentage in basis points
    }
    
    // Delegation tracking
    struct DelegationInfo {
        address validator;
        uint256 amount;
        uint256 delegationTime;
        uint256 lastRewardClaim;
        uint256 accumulatedRewards;
        bool isActive;
    }
    
    // Hash power delegation (unique to Core Chain)
    struct HashPowerDelegation {
        address miner;
        address validator;
        uint256 hashRate; // Hash rate in TH/s
        uint256 delegationTime;
        uint256 duration; // Duration in blocks
        bool isActive;
        uint256 rewardsEarned;
    }
    
    // State variables
    mapping(address => ValidatorInfo) public validators;
    mapping(address => DelegationInfo[]) public userDelegations;
    mapping(address => HashPowerDelegation[]) public hashPowerDelegations;
    mapping(address => uint256) public totalUserDelegated;
    mapping(address => uint256) public userRewardBalance;
    
    address[] public validatorList;
    uint256 public totalValidators;
    uint256 public totalDelegatedAmount;
    uint256 public totalHashPowerDelegated;
    
    // Protocol parameters
    uint256 public minDelegationAmount = 1 ether; // Minimum 1 CORE
    uint256 public maxValidatorsPerUser = 10;
    uint256 public delegationCooldown = 7 days;
    uint256 public validatorCommissionCap = 2000; // 20% max commission
    
    IERC20 public immutable coreToken;
    
    // Events
    event ValidatorRegistered(address indexed validator, string moniker);
    event ValidatorUpdated(address indexed validator, uint256 commission, string details);
    event Delegated(address indexed delegator, address indexed validator, uint256 amount);
    event Undelegated(address indexed delegator, address indexed validator, uint256 amount);
    event Redelegated(address indexed delegator, address indexed srcValidator, address indexed dstValidator, uint256 amount);
    event HashPowerDelegated(address indexed miner, address indexed validator, uint256 hashRate);
    event RewardsClaimed(address indexed user, uint256 amount);
    event ValidatorSlashed(address indexed validator, uint256 amount, string reason);
    event ValidatorJailed(address indexed validator, uint256 jailTime);
    
    constructor(address _coreToken) {
        coreToken = IERC20(_coreToken);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(VALIDATOR_MANAGER_ROLE, msg.sender);
        _grantRole(HASH_POWER_ORACLE_ROLE, msg.sender);
    }
    
    /**
     * @dev Register a new validator
     * @param validatorAddress Validator's address
     * @param moniker Validator's display name
     * @param website Validator's website
     * @param details Additional details
     * @param commission Commission rate in basis points
     */
    function registerValidator(
        address validatorAddress,
        string memory moniker,
        string memory website,
        string memory details,
        uint256 commission
    ) external onlyRole(VALIDATOR_MANAGER_ROLE) {
        require(validatorAddress != address(0), "Invalid validator address");
        require(commission <= validatorCommissionCap, "Commission too high");
        require(!validators[validatorAddress].isActive, "Validator already registered");
        
        validators[validatorAddress] = ValidatorInfo({
            validatorAddress: validatorAddress,
            moniker: moniker,
            website: website,
            details: details,
            commission: commission,
            votingPower: 0,
            totalDelegated: 0,
            selfStake: 0,
            isActive: true,
            isJailed: false,
            jailTime: 0,
            hashPower: 0,
            lastRewardClaim: block.timestamp,
            slashCount: 0,
            uptime: 10000 // 100% initial uptime
        });
        
        validatorList.push(validatorAddress);
        totalValidators++;
        
        emit ValidatorRegistered(validatorAddress, moniker);
    }
    
    /**
     * @dev Delegate CORE tokens to a validator
     * @param validator Validator address
     * @param amount Amount to delegate
     */
    function delegateToValidator(address validator, uint256 amount) external nonReentrant whenNotPaused {
        require(amount >= minDelegationAmount, "Amount below minimum");
        require(validators[validator].isActive, "Validator not active");
        require(!validators[validator].isJailed, "Validator is jailed");
        require(userDelegations[msg.sender].length < maxValidatorsPerUser, "Too many delegations");
        
        // CORE tokens delegated without transfer
        
        // Delegate through Core Chain's native mechanism
        ICoreValidatorSet(CORE_VALIDATOR_SET).delegate{value: amount}(validator);
        
        // Record delegation
        userDelegations[msg.sender].push(DelegationInfo({
            validator: validator,
            amount: amount,
            delegationTime: block.timestamp,
            lastRewardClaim: block.timestamp,
            accumulatedRewards: 0,
            isActive: true
        }));
        
        // Update state
        validators[validator].totalDelegated += amount;
        totalUserDelegated[msg.sender] += amount;
        totalDelegatedAmount += amount;
        
        emit Delegated(msg.sender, validator, amount);
    }
    
    /**
     * @dev Undelegate CORE tokens from a validator
     * @param validator Validator address
     * @param amount Amount to undelegate
     */
    function undelegateFromValidator(address validator, uint256 amount) external nonReentrant {
        require(amount > 0, "Amount must be greater than 0");
        
        // Find and update delegation
        bool found = false;
        for (uint256 i = 0; i < userDelegations[msg.sender].length; i++) {
            DelegationInfo storage delegation = userDelegations[msg.sender][i];
            if (delegation.validator == validator && delegation.isActive && delegation.amount >= amount) {
                // Check cooldown period
                require(block.timestamp >= delegation.delegationTime + delegationCooldown, "Cooldown period not met");
                
                // Undelegate through Core Chain's native mechanism
                ICoreValidatorSet(CORE_VALIDATOR_SET).undelegate(validator, amount);
                
                // Update delegation
                delegation.amount -= amount;
                if (delegation.amount == 0) {
                    delegation.isActive = false;
                }
                
                // Update state
                validators[validator].totalDelegated -= amount;
                totalUserDelegated[msg.sender] -= amount;
                totalDelegatedAmount -= amount;
                
                // Transfer tokens back to user
                coreToken.safeTransfer(msg.sender, amount);
                
                found = true;
                break;
            }
        }
        
        require(found, "Delegation not found or insufficient amount");
        emit Undelegated(msg.sender, validator, amount);
    }
    
    /**
     * @dev Redelegate from one validator to another
     * @param srcValidator Source validator
     * @param dstValidator Destination validator
     * @param amount Amount to redelegate
     */
    function redelegateValidator(
        address srcValidator,
        address dstValidator,
        uint256 amount
    ) external nonReentrant whenNotPaused {
        require(amount > 0, "Amount must be greater than 0");
        require(validators[dstValidator].isActive, "Destination validator not active");
        require(!validators[dstValidator].isJailed, "Destination validator is jailed");
        
        // Find source delegation
        bool found = false;
        for (uint256 i = 0; i < userDelegations[msg.sender].length; i++) {
            DelegationInfo storage delegation = userDelegations[msg.sender][i];
            if (delegation.validator == srcValidator && delegation.isActive && delegation.amount >= amount) {
                // Redelegate through Core Chain's native mechanism
                ICoreValidatorSet(CORE_VALIDATOR_SET).redelegate(srcValidator, dstValidator, amount);
                
                // Update source delegation
                delegation.amount -= amount;
                if (delegation.amount == 0) {
                    delegation.isActive = false;
                }
                
                // Create new delegation
                userDelegations[msg.sender].push(DelegationInfo({
                    validator: dstValidator,
                    amount: amount,
                    delegationTime: block.timestamp,
                    lastRewardClaim: block.timestamp,
                    accumulatedRewards: 0,
                    isActive: true
                }));
                
                // Update validator states
                validators[srcValidator].totalDelegated -= amount;
                validators[dstValidator].totalDelegated += amount;
                
                found = true;
                break;
            }
        }
        
        require(found, "Source delegation not found or insufficient amount");
        emit Redelegated(msg.sender, srcValidator, dstValidator, amount);
    }
    
    /**
     * @dev Delegate hash power to a validator (unique to Core Chain)
     * @param validator Validator address
     * @param hashRate Hash rate in TH/s
     * @param duration Duration in blocks
     */
    function delegateHashPower(
        address validator,
        uint256 hashRate,
        uint256 duration
    ) external onlyRole(HASH_POWER_ORACLE_ROLE) {
        require(validators[validator].isActive, "Validator not active");
        require(hashRate > 0, "Hash rate must be greater than 0");
        require(duration > 0, "Duration must be greater than 0");
        
        // Record hash power delegation
        hashPowerDelegations[msg.sender].push(HashPowerDelegation({
            miner: msg.sender,
            validator: validator,
            hashRate: hashRate,
            delegationTime: block.timestamp,
            duration: duration,
            isActive: true,
            rewardsEarned: 0
        }));
        
        // Update validator hash power
        validators[validator].hashPower += hashRate;
        totalHashPowerDelegated += hashRate;
        
        emit HashPowerDelegated(msg.sender, validator, hashRate);
    }
    
    /**
     * @dev Claim staking rewards
     */
    function claimRewards() external nonReentrant {
        uint256 totalRewards = 0;
        
        // Claim from Core Chain's system reward contract
        ICoreSystemReward(CORE_SYSTEM_REWARD).claimRewards();
        
        // Calculate user's share of rewards
        for (uint256 i = 0; i < userDelegations[msg.sender].length; i++) {
            DelegationInfo storage delegation = userDelegations[msg.sender][i];
            if (delegation.isActive) {
                // Calculate rewards based on delegation amount and time
                uint256 timeElapsed = block.timestamp - delegation.lastRewardClaim;
                uint256 validatorRewards = _calculateValidatorRewards(delegation.validator, timeElapsed);
                uint256 userShare = (validatorRewards * delegation.amount) / validators[delegation.validator].totalDelegated;
                
                // Apply validator commission
                uint256 commission = (userShare * validators[delegation.validator].commission) / 10000;
                uint256 netRewards = userShare - commission;
                
                delegation.accumulatedRewards += netRewards;
                delegation.lastRewardClaim = block.timestamp;
                totalRewards += netRewards;
            }
        }
        
        // Add any pending rewards
        totalRewards += userRewardBalance[msg.sender];
        userRewardBalance[msg.sender] = 0;
        
        if (totalRewards > 0) {
            coreToken.safeTransfer(msg.sender, totalRewards);
            emit RewardsClaimed(msg.sender, totalRewards);
        }
    }
    
    /**
     * @dev Get user's delegation information
     * @param user User address
     * @return delegations Array of user's delegations
     */
    function getUserDelegations(address user) external view returns (DelegationInfo[] memory delegations) {
        return userDelegations[user];
    }
    
    /**
     * @dev Get validator information
     * @param validator Validator address
     * @return info Validator information
     */
    function getValidatorInfo(address validator) external view returns (ValidatorInfo memory info) {
        return validators[validator];
    }
    
    /**
     * @dev Get all active validators
     * @return activeValidators Array of active validator addresses
     */
    function getActiveValidators() external view returns (address[] memory activeValidators) {
        uint256 count = 0;
        for (uint256 i = 0; i < validatorList.length; i++) {
            if (validators[validatorList[i]].isActive && !validators[validatorList[i]].isJailed) {
                count++;
            }
        }
        
        activeValidators = new address[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < validatorList.length; i++) {
            if (validators[validatorList[i]].isActive && !validators[validatorList[i]].isJailed) {
                activeValidators[index] = validatorList[i];
                index++;
            }
        }
    }
    
    /**
     * @dev Update validator information
     * @param validator Validator address
     * @param commission New commission rate
     * @param details New details
     */
    function updateValidator(
        address validator,
        uint256 commission,
        string memory details
    ) external onlyRole(VALIDATOR_MANAGER_ROLE) {
        require(validators[validator].isActive, "Validator not active");
        require(commission <= validatorCommissionCap, "Commission too high");
        
        validators[validator].commission = commission;
        validators[validator].details = details;
        
        emit ValidatorUpdated(validator, commission, details);
    }
    
    /**
     * @dev Jail a validator (admin only)
     * @param validator Validator address
     * @param jailTime Jail duration in seconds
     */
    function jailValidator(address validator, uint256 jailTime) external onlyRole(VALIDATOR_MANAGER_ROLE) {
        require(validators[validator].isActive, "Validator not active");
        
        validators[validator].isJailed = true;
        validators[validator].jailTime = block.timestamp + jailTime;
        
        emit ValidatorJailed(validator, jailTime);
    }
    
    /**
     * @dev Unjail a validator
     * @param validator Validator address
     */
    function unjailValidator(address validator) external onlyRole(VALIDATOR_MANAGER_ROLE) {
        require(validators[validator].isJailed, "Validator not jailed");
        require(block.timestamp >= validators[validator].jailTime, "Jail time not expired");
        
        validators[validator].isJailed = false;
        validators[validator].jailTime = 0;
    }
    
    /**
     * @dev Internal function to calculate validator rewards
     */
    function _calculateValidatorRewards(address validator, uint256 timeElapsed) internal view returns (uint256) {
        // Base reward calculation (simplified)
        uint256 baseReward = (validators[validator].totalDelegated * 25) / 10000; // 2.5% annual
        uint256 timeReward = (baseReward * timeElapsed) / 365 days;
        
        // Hash power bonus (unique to Core Chain)
        uint256 hashPowerBonus = (validators[validator].hashPower * 100) / 1000; // Bonus based on hash power
        
        return timeReward + hashPowerBonus;
    }
    
    /**
     * @dev Emergency pause
     */
    function pause() external onlyRole(EMERGENCY_ROLE) {
        _pause();
    }
    
    /**
     * @dev Unpause
     */
    function unpause() external onlyRole(EMERGENCY_ROLE) {
        _unpause();
    }
    
    /**
     * @dev Set minimum delegation amount
     */
    function setMinDelegationAmount(uint256 newAmount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        minDelegationAmount = newAmount;
    }
    
    /**
     * @dev Set delegation cooldown period
     */
    function setDelegationCooldown(uint256 newCooldown) external onlyRole(DEFAULT_ADMIN_ROLE) {
        delegationCooldown = newCooldown;
    }
}
