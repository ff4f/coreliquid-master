// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title MockCoreBTCStaking
 * @dev Mock implementation of Core Chain's BTC staking interface for testing
 */
contract MockCoreBTCStaking {
    mapping(bytes32 => bool) public stakedTxHashes;
    mapping(address => uint256) public stakedAmounts;
    mapping(address => uint256) public rewards;
    
    event BTCStaked(bytes32 indexed btcTxHash, uint256 amount, uint256 lockTime, address validator);
    event BTCRedeemed(bytes32 indexed stakingTxHash);
    event RewardsClaimed(address indexed delegator, uint256 amount);
    
    function stakeBTC(bytes32 btcTxHash, uint256 amount, uint256 lockTime, address validator) external {
        require(!stakedTxHashes[btcTxHash], "BTC already staked");
        require(amount > 0, "Invalid amount");
        require(validator != address(0), "Invalid validator");
        
        stakedTxHashes[btcTxHash] = true;
        stakedAmounts[msg.sender] += amount;
        
        emit BTCStaked(btcTxHash, amount, lockTime, validator);
    }
    
    function redeemBTC(bytes32 stakingTxHash) external {
        require(stakedTxHashes[stakingTxHash], "Invalid staking tx");
        
        emit BTCRedeemed(stakingTxHash);
    }
    
    function claimRewards(address delegator) external returns (uint256) {
        uint256 reward = rewards[delegator];
        rewards[delegator] = 0;
        
        emit RewardsClaimed(delegator, reward);
        return reward;
    }
    
    function getStakingInfo(address delegator) external view returns (uint256, uint256, uint256) {
        return (stakedAmounts[delegator], rewards[delegator], block.timestamp);
    }
    
    // Helper function to set rewards for testing
    function setRewards(address delegator, uint256 amount) external {
        rewards[delegator] = amount;
    }
}
