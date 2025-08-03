// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title DepositLPToken
 * @dev ERC-20 token representing protocol liquidity shares
 */
contract DepositLPToken is ERC20, ERC20Burnable, AccessControl, Pausable {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    
    struct UserInfo {
        uint256 totalDeposited;
        uint256 totalWithdrawn;
        uint256 lastDepositTime;
        uint256 rewardDebt;
    }
    
    mapping(address => UserInfo) public userInfo;
    mapping(address => uint256) public userShares;
    
    uint256 public totalValueLocked;
    uint256 public totalRewardsDistributed;
    uint256 public rewardPerShare;
    
    event SharesMinted(address indexed user, uint256 shares, uint256 underlyingValue);
    event SharesBurned(address indexed user, uint256 shares, uint256 underlyingValue);
    event RewardsDistributed(uint256 amount, uint256 newRewardPerShare);
    event UserRewardsClaimed(address indexed user, uint256 amount);
    
    constructor(
        string memory name,
        string memory symbol
    ) ERC20(name, symbol) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(BURNER_ROLE, msg.sender);
    }
    
    function mint(address to, uint256 amount, uint256 underlyingValue) 
        external 
        onlyRole(MINTER_ROLE) 
        whenNotPaused 
    {
        require(to != address(0), "Invalid recipient");
        require(amount > 0, "Invalid amount");
        
        _mint(to, amount);
        
        userInfo[to].totalDeposited += underlyingValue;
        userInfo[to].lastDepositTime = block.timestamp;
        userShares[to] += amount;
        totalValueLocked += underlyingValue;
        
        // Update reward debt
        userInfo[to].rewardDebt = (userShares[to] * rewardPerShare) / 1e18;
        
        emit SharesMinted(to, amount, underlyingValue);
    }
    
    function burnFrom(address from, uint256 amount, uint256 underlyingValue) 
        external 
        onlyRole(BURNER_ROLE) 
        whenNotPaused 
    {
        require(from != address(0), "Invalid address");
        require(amount > 0, "Invalid amount");
        require(balanceOf(from) >= amount, "Insufficient balance");
        
        // Claim pending rewards before burning
        _claimRewards(from);
        
        _burn(from, amount);
        
        userInfo[from].totalWithdrawn += underlyingValue;
        userShares[from] -= amount;
        totalValueLocked -= underlyingValue;
        
        // Update reward debt
        userInfo[from].rewardDebt = (userShares[from] * rewardPerShare) / 1e18;
        
        emit SharesBurned(from, amount, underlyingValue);
    }
    
    function distributeRewards(uint256 rewardAmount) external onlyRole(MINTER_ROLE) {
        require(rewardAmount > 0, "Invalid reward amount");
        require(totalSupply() > 0, "No shares to distribute to");
        
        uint256 rewardPerShareIncrease = (rewardAmount * 1e18) / totalSupply();
        rewardPerShare += rewardPerShareIncrease;
        totalRewardsDistributed += rewardAmount;
        
        emit RewardsDistributed(rewardAmount, rewardPerShare);
    }
    
    function claimRewards() external whenNotPaused {
        _claimRewards(msg.sender);
    }
    
    function _claimRewards(address user) internal {
        uint256 pending = getPendingRewards(user);
        if (pending > 0) {
            userInfo[user].rewardDebt = (userShares[user] * rewardPerShare) / 1e18;
            // In a real implementation, transfer reward tokens here
            emit UserRewardsClaimed(user, pending);
        }
    }
    
    function getPendingRewards(address user) public view returns (uint256) {
        if (userShares[user] == 0) return 0;
        
        uint256 accumulatedRewards = (userShares[user] * rewardPerShare) / 1e18;
        return accumulatedRewards - userInfo[user].rewardDebt;
    }
    
    function getShareValue() external view returns (uint256) {
        if (totalSupply() == 0) return 1e18; // 1:1 ratio initially
        return (totalValueLocked * 1e18) / totalSupply();
    }
    
    function getUserStats(address user) external view returns (
        uint256 shares,
        uint256 shareValue,
        uint256 totalValue,
        uint256 pendingRewards,
        uint256 totalDeposited,
        uint256 totalWithdrawn
    ) {
        shares = userShares[user];
        shareValue = this.getShareValue();
        totalValue = (shares * shareValue) / 1e18;
        pendingRewards = getPendingRewards(user);
        totalDeposited = userInfo[user].totalDeposited;
        totalWithdrawn = userInfo[user].totalWithdrawn;
    }
    
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }
    
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }
    
    function _update(
        address from,
        address to,
        uint256 amount
    ) internal override whenNotPaused {
        super._update(from, to, amount);
        
        // Update shares tracking on transfer
        if (from != address(0) && to != address(0)) {
            // Claim rewards for both parties
            _claimRewards(from);
            _claimRewards(to);
            
            // Update shares
            userShares[from] -= amount;
            userShares[to] += amount;
            
            // Update reward debt
            userInfo[from].rewardDebt = (userShares[from] * rewardPerShare) / 1e18;
            userInfo[to].rewardDebt = (userShares[to] * rewardPerShare) / 1e18;
        }
    }
    
    function emergencyWithdraw() external onlyRole(DEFAULT_ADMIN_ROLE) {
        // Emergency function to withdraw stuck tokens
        // Implementation depends on specific requirements
    }
}
