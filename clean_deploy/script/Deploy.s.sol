// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "../lib/forge-std/src/Script.sol";

// CoreLiquid Protocol Token
contract CoreLiquidToken {
    string public name = "CoreLiquid Protocol Token";
    string public symbol = "CLT";
    uint8 public decimals = 18;
    uint256 public totalSupply;
    
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    
    address public owner;
    bool public paused = false;
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Mint(address indexed to, uint256 value);
    event Burn(address indexed from, uint256 value);
    event Pause();
    event Unpause();
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }
    
    modifier whenNotPaused() {
        require(!paused, "Contract is paused");
        _;
    }
    
    constructor(uint256 _initialSupply) {
        owner = msg.sender;
        totalSupply = _initialSupply * 10**decimals;
        balanceOf[msg.sender] = totalSupply;
        emit Transfer(address(0), msg.sender, totalSupply);
    }
    
    function transfer(address _to, uint256 _value) public whenNotPaused returns (bool) {
        require(_to != address(0), "Invalid address");
        require(balanceOf[msg.sender] >= _value, "Insufficient balance");
        balanceOf[msg.sender] -= _value;
        balanceOf[_to] += _value;
        emit Transfer(msg.sender, _to, _value);
        return true;
    }
    
    function approve(address _spender, uint256 _value) public whenNotPaused returns (bool) {
        allowance[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }
    
    function transferFrom(address _from, address _to, uint256 _value) public whenNotPaused returns (bool) {
        require(_to != address(0), "Invalid address");
        require(balanceOf[_from] >= _value, "Insufficient balance");
        require(allowance[_from][msg.sender] >= _value, "Insufficient allowance");
        balanceOf[_from] -= _value;
        balanceOf[_to] += _value;
        allowance[_from][msg.sender] -= _value;
        emit Transfer(_from, _to, _value);
        return true;
    }
    
    function mint(address _to, uint256 _value) public onlyOwner {
        require(_to != address(0), "Invalid address");
        totalSupply += _value;
        balanceOf[_to] += _value;
        emit Mint(_to, _value);
        emit Transfer(address(0), _to, _value);
    }
    
    function burn(uint256 _value) public {
        require(balanceOf[msg.sender] >= _value, "Insufficient balance");
        balanceOf[msg.sender] -= _value;
        totalSupply -= _value;
        emit Burn(msg.sender, _value);
        emit Transfer(msg.sender, address(0), _value);
    }
    
    function pause() public onlyOwner {
        paused = true;
        emit Pause();
    }
    
    function unpause() public onlyOwner {
        paused = false;
        emit Unpause();
    }
}

// CoreLiquid Staking Contract
contract CoreLiquidStaking {
    CoreLiquidToken public immutable token;
    
    struct StakeInfo {
        uint256 amount;
        uint256 timestamp;
        uint256 lastRewardClaim;
    }
    
    mapping(address => StakeInfo) public stakes;
    mapping(address => uint256) public rewards;
    
    uint256 public totalStaked;
    uint256 public rewardRate = 100; // 1% per day (basis points)
    uint256 public constant SECONDS_PER_DAY = 86400;
    uint256 public constant BASIS_POINTS = 10000;
    
    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event RewardClaimed(address indexed user, uint256 reward);
    event RewardRateUpdated(uint256 newRate);
    
    constructor(address _token) {
        token = CoreLiquidToken(_token);
    }
    
    function stake(uint256 _amount) external {
        require(_amount > 0, "Amount must be greater than 0");
        require(token.transferFrom(msg.sender, address(this), _amount), "Transfer failed");
        
        _updateRewards(msg.sender);
        
        stakes[msg.sender].amount += _amount;
        stakes[msg.sender].timestamp = block.timestamp;
        stakes[msg.sender].lastRewardClaim = block.timestamp;
        totalStaked += _amount;
        
        emit Staked(msg.sender, _amount);
    }
    
    function unstake(uint256 _amount) external {
        require(stakes[msg.sender].amount >= _amount, "Insufficient staked amount");
        
        _updateRewards(msg.sender);
        
        stakes[msg.sender].amount -= _amount;
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
        if (stakes[_user].amount > 0) {
            uint256 timeStaked = block.timestamp - stakes[_user].lastRewardClaim;
            uint256 reward = (stakes[_user].amount * rewardRate * timeStaked) / (BASIS_POINTS * SECONDS_PER_DAY);
            rewards[_user] += reward;
            stakes[_user].lastRewardClaim = block.timestamp;
        }
    }
    
    function getPendingRewards(address _user) external view returns (uint256) {
        if (stakes[_user].amount == 0) return rewards[_user];
        
        uint256 timeStaked = block.timestamp - stakes[_user].lastRewardClaim;
        uint256 pendingReward = (stakes[_user].amount * rewardRate * timeStaked) / (BASIS_POINTS * SECONDS_PER_DAY);
        return rewards[_user] + pendingReward;
    }
    
    function getStakeInfo(address _user) external view returns (uint256 amount, uint256 timestamp, uint256 pendingRewards) {
        amount = stakes[_user].amount;
        timestamp = stakes[_user].timestamp;
        
        if (amount > 0) {
            uint256 timeStaked = block.timestamp - stakes[_user].lastRewardClaim;
            uint256 pending = (amount * rewardRate * timeStaked) / (BASIS_POINTS * SECONDS_PER_DAY);
            pendingRewards = rewards[_user] + pending;
        } else {
            pendingRewards = rewards[_user];
        }
    }
}

// CoreLiquid Liquidity Pool
contract CoreLiquidPool {
    CoreLiquidToken public immutable token;
    
    struct PoolInfo {
        uint256 totalLiquidity;
        uint256 totalShares;
        uint256 feeRate; // basis points
    }
    
    struct UserInfo {
        uint256 shares;
        uint256 lastDeposit;
    }
    
    PoolInfo public pool;
    mapping(address => UserInfo) public users;
    
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant MIN_LIQUIDITY = 1000;
    
    event LiquidityAdded(address indexed user, uint256 amount, uint256 shares);
    event LiquidityRemoved(address indexed user, uint256 amount, uint256 shares);
    event FeesCollected(uint256 amount);
    
    constructor(address _token) {
        token = CoreLiquidToken(_token);
        pool.feeRate = 30; // 0.3%
    }
    
    function addLiquidity(uint256 _amount) external {
        require(_amount > 0, "Amount must be greater than 0");
        require(token.transferFrom(msg.sender, address(this), _amount), "Transfer failed");
        
        uint256 shares;
        if (pool.totalShares == 0) {
            shares = _amount;
        } else {
            shares = (_amount * pool.totalShares) / pool.totalLiquidity;
        }
        
        pool.totalLiquidity += _amount;
        pool.totalShares += shares;
        users[msg.sender].shares += shares;
        users[msg.sender].lastDeposit = block.timestamp;
        
        emit LiquidityAdded(msg.sender, _amount, shares);
    }
    
    function removeLiquidity(uint256 _shares) external {
        require(_shares > 0, "Shares must be greater than 0");
        require(users[msg.sender].shares >= _shares, "Insufficient shares");
        
        uint256 amount = (_shares * pool.totalLiquidity) / pool.totalShares;
        
        pool.totalLiquidity -= amount;
        pool.totalShares -= _shares;
        users[msg.sender].shares -= _shares;
        
        require(token.transfer(msg.sender, amount), "Transfer failed");
        
        emit LiquidityRemoved(msg.sender, amount, _shares);
    }
    
    function getUserLiquidity(address _user) external view returns (uint256) {
        if (pool.totalShares == 0) return 0;
        return (users[_user].shares * pool.totalLiquidity) / pool.totalShares;
    }
}

contract DeployScript is Script {
    CoreLiquidToken public token;
    CoreLiquidStaking public staking;
    CoreLiquidPool public pool;
    
    function run() external {
        vm.startBroadcast();
        
        console.log("=== CoreLiquid Protocol Deployment ===");
        console.log("Deployer:", msg.sender);
        console.log("Balance:", msg.sender.balance / 1e18, "CORE");
        console.log("Network: Core Testnet (Chain ID: 1114)");
        console.log("Block:", block.number);
        console.log("Timestamp:", block.timestamp);
        console.log("");
        
        // Deploy CoreLiquid Token
        console.log("1. Deploying CoreLiquid Token...");
        token = new CoreLiquidToken(1000000); // 1M initial supply
        console.log("   Token deployed at:", address(token));
        console.log("   Initial supply:", token.totalSupply() / 1e18, "CLT");
        console.log("   Owner:", token.owner());
        console.log("");
        
        // Deploy Staking Contract
        console.log("2. Deploying CoreLiquid Staking...");
        staking = new CoreLiquidStaking(address(token));
        console.log("   Staking deployed at:", address(staking));
        console.log("   Reward rate:", staking.rewardRate(), "basis points per day");
        console.log("");
        
        // Deploy Liquidity Pool
        console.log("3. Deploying CoreLiquid Pool...");
        pool = new CoreLiquidPool(address(token));
        console.log("   Pool deployed at:", address(pool));
        console.log("");
        
        // Test functionality
        console.log("4. Testing Protocol Functionality...");
        
        // Approve contracts
        token.approve(address(staking), 50000 * 1e18);
        token.approve(address(pool), 50000 * 1e18);
        console.log("   Approved staking and pool contracts");
        
        // Test staking
        staking.stake(10000 * 1e18);
        console.log("   Staked 10,000 CLT tokens");
        
        // Test liquidity provision
        pool.addLiquidity(5000 * 1e18);
        console.log("   Added 5,000 CLT liquidity");
        
        // Mint additional tokens for ecosystem
        token.mint(msg.sender, 100000 * 1e18);
        console.log("   Minted additional 100,000 CLT tokens");
        
        // Create some test transactions
        token.transfer(address(0x1111111111111111111111111111111111111111), 1000 * 1e18);
        console.log("   Test transfer completed");
        
        vm.stopBroadcast();
        
        console.log("");
        console.log("=== DEPLOYMENT SUMMARY ===");
        console.log("CoreLiquid Token:", address(token));
        console.log("CoreLiquid Staking:", address(staking));
        console.log("CoreLiquid Pool:", address(pool));
        console.log("");
        console.log("Protocol Stats:");
        console.log("   Total Supply:", token.totalSupply() / 1e18, "CLT");
        console.log("   Deployer Balance:", token.balanceOf(msg.sender) / 1e18, "CLT");
        console.log("   Total Staked:", staking.totalStaked() / 1e18, "CLT");
        
        (uint256 userStaked,,) = staking.getStakeInfo(msg.sender);
        console.log("   User Staked:", userStaked / 1e18, "CLT");
        console.log("   Pool Liquidity:", pool.getUserLiquidity(msg.sender) / 1e18, "CLT");
        
        console.log("");
        console.log("Explorer Links:");
        console.log("   Token: https://scan.test2.btcs.network/address/", address(token));
        console.log("   Staking: https://scan.test2.btcs.network/address/", address(staking));
        console.log("   Pool: https://scan.test2.btcs.network/address/", address(pool));
        console.log("");
        console.log("CoreLiquid Protocol Successfully Deployed!");
    }
}
