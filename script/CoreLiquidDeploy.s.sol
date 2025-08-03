// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "forge-std/console.sol";

// Simple CoreLiquid Token for demonstration
contract CoreLiquidToken {
    string public name = "CoreLiquid Protocol Token";
    string public symbol = "CLT";
    uint8 public decimals = 18;
    uint256 public totalSupply;
    
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    
    address public owner;
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Mint(address indexed to, uint256 value);
    
    constructor(uint256 _initialSupply) {
        owner = msg.sender;
        totalSupply = _initialSupply * 10**decimals;
        balanceOf[msg.sender] = totalSupply;
        emit Transfer(address(0), msg.sender, totalSupply);
    }
    
    function transfer(address _to, uint256 _value) public returns (bool) {
        require(balanceOf[msg.sender] >= _value, "Insufficient balance");
        balanceOf[msg.sender] -= _value;
        balanceOf[_to] += _value;
        emit Transfer(msg.sender, _to, _value);
        return true;
    }
    
    function approve(address _spender, uint256 _value) public returns (bool) {
        allowance[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }
    
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool) {
        require(balanceOf[_from] >= _value, "Insufficient balance");
        require(allowance[_from][msg.sender] >= _value, "Insufficient allowance");
        balanceOf[_from] -= _value;
        balanceOf[_to] += _value;
        allowance[_from][msg.sender] -= _value;
        emit Transfer(_from, _to, _value);
        return true;
    }
    
    function mint(address _to, uint256 _value) public {
        require(msg.sender == owner, "Only owner can mint");
        totalSupply += _value;
        balanceOf[_to] += _value;
        emit Mint(_to, _value);
        emit Transfer(address(0), _to, _value);
    }
}

// Simple Staking Contract
contract CoreStaking {
    CoreLiquidToken public token;
    
    mapping(address => uint256) public stakedAmount;
    mapping(address => uint256) public stakingTime;
    mapping(address => uint256) public rewards;
    
    uint256 public totalStaked;
    uint256 public rewardRate = 100; // 1% per day (simplified)
    
    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event RewardClaimed(address indexed user, uint256 reward);
    
    constructor(address _token) {
        token = CoreLiquidToken(_token);
    }
    
    function stake(uint256 _amount) external {
        require(_amount > 0, "Amount must be greater than 0");
        require(token.transferFrom(msg.sender, address(this), _amount), "Transfer failed");
        
        if (stakedAmount[msg.sender] > 0) {
            _updateRewards(msg.sender);
        }
        
        stakedAmount[msg.sender] += _amount;
        stakingTime[msg.sender] = block.timestamp;
        totalStaked += _amount;
        
        emit Staked(msg.sender, _amount);
    }
    
    function unstake(uint256 _amount) external {
        require(stakedAmount[msg.sender] >= _amount, "Insufficient staked amount");
        
        _updateRewards(msg.sender);
        
        stakedAmount[msg.sender] -= _amount;
        totalStaked -= _amount;
        
        require(token.transfer(msg.sender, _amount), "Transfer failed");
        
        emit Unstaked(msg.sender, _amount);
    }
    
    function claimRewards() external {
        _updateRewards(msg.sender);
        
        uint256 reward = rewards[msg.sender];
        require(reward > 0, "No rewards to claim");
        
        rewards[msg.sender] = 0;
        token.mint(msg.sender, reward);
        
        emit RewardClaimed(msg.sender, reward);
    }
    
    function _updateRewards(address _user) internal {
        if (stakedAmount[_user] > 0) {
            uint256 timeStaked = block.timestamp - stakingTime[_user];
            uint256 reward = (stakedAmount[_user] * rewardRate * timeStaked) / (100 * 86400); // Daily rate
            rewards[_user] += reward;
            stakingTime[_user] = block.timestamp;
        }
    }
    
    function getRewards(address _user) external view returns (uint256) {
        if (stakedAmount[_user] == 0) return rewards[_user];
        
        uint256 timeStaked = block.timestamp - stakingTime[_user];
        uint256 pendingReward = (stakedAmount[_user] * rewardRate * timeStaked) / (100 * 86400);
        return rewards[_user] + pendingReward;
    }
}

contract CoreLiquidDeployScript is Script {
    CoreLiquidToken public token;
    CoreStaking public staking;
    
    function run() external {
        vm.startBroadcast();
        
        console.log("=== CoreLiquid Protocol Deployment ===");
        console.log("Deployer:", msg.sender);
        console.log("Balance:", msg.sender.balance);
        console.log("Network: Core Testnet (Chain ID: 1114)");
        console.log("");
        
        // Deploy CoreLiquid Token
        console.log("1. Deploying CoreLiquid Token...");
        token = new CoreLiquidToken(1000000); // 1M initial supply
        console.log("   Token deployed at:", address(token));
        console.log("   Initial supply:", token.totalSupply() / 1e18, "CLT");
        console.log("");
        
        // Deploy Staking Contract
        console.log("2. Deploying CoreStaking Contract...");
        staking = new CoreStaking(address(token));
        console.log("   Staking deployed at:", address(staking));
        console.log("");
        
        // Test functionality
        console.log("3. Testing functionality...");
        
        // Approve staking contract
        token.approve(address(staking), 10000 * 1e18);
        console.log("   Approved staking contract for 10,000 CLT");
        
        // Stake some tokens
        staking.stake(1000 * 1e18);
        console.log("   Staked 1,000 CLT tokens");
        
        // Mint additional tokens for testing
        token.mint(msg.sender, 5000 * 1e18);
        console.log("   Minted additional 5,000 CLT tokens");
        
        vm.stopBroadcast();
        
        console.log("");
        console.log("=== DEPLOYMENT COMPLETE ===");
        console.log("CoreLiquid Token:", address(token));
        console.log("CoreStaking:", address(staking));
        console.log("Total Supply:", token.totalSupply() / 1e18, "CLT");
        console.log("Deployer Balance:", token.balanceOf(msg.sender) / 1e18, "CLT");
        console.log("Staked Amount:", staking.stakedAmount(msg.sender) / 1e18, "CLT");
        console.log("");
        console.log("Explorer Links:");
        console.log("Token: https://scan.test2.btcs.network/address/", address(token));
        console.log("Staking: https://scan.test2.btcs.network/address/", address(staking));
    }
}
