// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title MockCoreValidator
 * @dev Mock implementation of Core Chain's validator interface for testing
 */
contract MockCoreValidator {
    mapping(address => mapping(address => uint256)) public delegatedAmounts;
    mapping(address => uint256) public validatorStakes;
    mapping(address => bool) public validatorStatus;
    mapping(address => uint256) public validatorRewards;
    
    event DelegatedToValidator(address indexed delegator, address indexed validator, uint256 amount);
    event UndelegatedFromValidator(address indexed delegator, address indexed validator, uint256 amount);
    event ValidatorRewardsClaimed(address indexed validator, uint256 amount);
    
    function delegateToValidator(address validator, uint256 amount) external {
        require(validator != address(0), "Invalid validator");
        require(amount > 0, "Invalid amount");
        
        delegatedAmounts[msg.sender][validator] += amount;
        validatorStakes[validator] += amount;
        validatorStatus[validator] = true;
        
        emit DelegatedToValidator(msg.sender, validator, amount);
    }
    
    function undelegateFromValidator(address validator, uint256 amount) external {
        require(delegatedAmounts[msg.sender][validator] >= amount, "Insufficient delegation");
        
        delegatedAmounts[msg.sender][validator] -= amount;
        validatorStakes[validator] -= amount;
        
        emit UndelegatedFromValidator(msg.sender, validator, amount);
    }
    
    function getValidatorInfo(address validator) external view returns (uint256, uint256, bool) {
        return (validatorStakes[validator], validatorRewards[validator], validatorStatus[validator]);
    }
    
    function claimValidatorRewards(address validator) external returns (uint256) {
        uint256 reward = validatorRewards[validator];
        validatorRewards[validator] = 0;
        
        emit ValidatorRewardsClaimed(validator, reward);
        return reward;
    }
    
    // Helper functions for testing
    function setValidatorRewards(address validator, uint256 amount) external {
        validatorRewards[validator] = amount;
    }
    
    function setValidatorStatus(address validator, bool status) external {
        validatorStatus[validator] = status;
    }
}
