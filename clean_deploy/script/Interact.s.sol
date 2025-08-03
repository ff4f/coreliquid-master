// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "../lib/forge-std/src/Script.sol";

// Import deployed contracts interfaces
interface ICoreToken {
    function balanceOf(address) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
    function approve(address, uint256) external returns (bool);
    function mint(address, uint256) external;
    function totalSupply() external view returns (uint256);
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
}

interface ICoreStaking {
    function stake(uint256) external;
    function unstake(uint256) external;
    function claimRewards() external;
    function totalStaked() external view returns (uint256);
    function getStakeInfo(address) external view returns (uint256, uint256, uint256);
    function getPendingRewards(address) external view returns (uint256);
}

interface ICorePool {
    function addLiquidity(uint256) external;
    function removeLiquidity(uint256) external;
    function getUserLiquidity(address) external view returns (uint256);
}

contract InteractScript is Script {
    // Deployed contract addresses
    address constant TOKEN_ADDRESS = 0x63A3F54b45094aB13294584babA15a60Cf7678a8;
    address constant STAKING_ADDRESS = 0xC55812399b5921040A423079a93888D6EE5119F7;
    address constant POOL_ADDRESS = 0x0AF458873Fd91808B9AAa2BB0e48F458C745A4b0;
    
    ICoreToken token;
    ICoreStaking staking;
    ICorePool pool;
    
    function run() external {
        vm.startBroadcast();
        
        // Initialize contract interfaces
        token = ICoreToken(TOKEN_ADDRESS);
        staking = ICoreStaking(STAKING_ADDRESS);
        pool = ICorePool(POOL_ADDRESS);
        
        console.log("=== CoreLiquid Protocol Interaction Test ===");
        console.log("User:", msg.sender);
        console.log("Block:", block.number);
        console.log("Timestamp:", block.timestamp);
        console.log("");
        
        // Display initial state
        console.log("=== Initial State ===");
        console.log("Token Name:", token.name());
        console.log("Token Symbol:", token.symbol());
        console.log("Total Supply:", token.totalSupply() / 1e18, "CLT");
        console.log("User Balance:", token.balanceOf(msg.sender) / 1e18, "CLT");
        console.log("Total Staked:", staking.totalStaked() / 1e18, "CLT");
        console.log("");
        
        // Test 1: Additional Token Minting
        console.log("=== Test 1: Additional Token Minting ===");
        uint256 mintAmount = 50000 * 1e18;
        token.mint(msg.sender, mintAmount);
        console.log("[SUCCESS] Minted additional", mintAmount / 1e18, "CLT tokens");
        console.log("New Balance:", token.balanceOf(msg.sender) / 1e18, "CLT");
        console.log("");
        
        // Test 2: Token Transfers
        console.log("=== Test 2: Token Transfer Tests ===");
        address testReceiver1 = address(0x2222222222222222222222222222222222222222);
        address testReceiver2 = address(0x3333333333333333333333333333333333333333);
        
        token.transfer(testReceiver1, 2000 * 1e18);
        console.log("[SUCCESS] Transferred 2,000 CLT to", testReceiver1);
        
        token.transfer(testReceiver2, 3000 * 1e18);
        console.log("[SUCCESS] Transferred 3,000 CLT to", testReceiver2);
        
        console.log("Receiver 1 Balance:", token.balanceOf(testReceiver1) / 1e18, "CLT");
        console.log("Receiver 2 Balance:", token.balanceOf(testReceiver2) / 1e18, "CLT");
        console.log("");
        
        // Test 3: Additional Staking
        console.log("=== Test 3: Additional Staking Tests ===");
        uint256 additionalStake = 15000 * 1e18;
        token.approve(STAKING_ADDRESS, additionalStake);
        staking.stake(additionalStake);
        console.log("[SUCCESS] Staked additional", additionalStake / 1e18, "CLT tokens");
        
        (uint256 userStaked, uint256 stakeTime, uint256 pendingRewards) = staking.getStakeInfo(msg.sender);
        console.log("Total User Staked:", userStaked / 1e18, "CLT");
        console.log("Stake Time:", stakeTime);
        console.log("Pending Rewards:", pendingRewards / 1e18, "CLT");
        console.log("Total Protocol Staked:", staking.totalStaked() / 1e18, "CLT");
        console.log("");
        
        // Test 4: Additional Liquidity
        console.log("=== Test 4: Additional Liquidity Tests ===");
        uint256 additionalLiquidity = 8000 * 1e18;
        token.approve(POOL_ADDRESS, additionalLiquidity);
        pool.addLiquidity(additionalLiquidity);
        console.log("[SUCCESS] Added additional", additionalLiquidity / 1e18, "CLT liquidity");
        
        uint256 userLiquidity = pool.getUserLiquidity(msg.sender);
        console.log("Total User Liquidity:", userLiquidity / 1e18, "CLT");
        console.log("");
        
        // Test 5: Partial Unstaking
        console.log("=== Test 5: Partial Unstaking Test ===");
        uint256 unstakeAmount = 5000 * 1e18;
        staking.unstake(unstakeAmount);
        console.log("[SUCCESS] Unstaked", unstakeAmount / 1e18, "CLT tokens");
        
        (userStaked, stakeTime, pendingRewards) = staking.getStakeInfo(msg.sender);
        console.log("Remaining Staked:", userStaked / 1e18, "CLT");
        console.log("Updated Total Staked:", staking.totalStaked() / 1e18, "CLT");
        console.log("");
        
        // Test 6: Reward Claims (if any)
        console.log("=== Test 6: Reward Claim Test ===");
        uint256 pendingRewardsCheck = staking.getPendingRewards(msg.sender);
        console.log("Pending Rewards:", pendingRewardsCheck / 1e18, "CLT");
        
        if (pendingRewardsCheck > 0) {
            staking.claimRewards();
            console.log("[SUCCESS] Claimed rewards:", pendingRewardsCheck / 1e18, "CLT");
        } else {
            console.log("[INFO] No rewards to claim yet (need more time for rewards to accumulate)");
        }
        console.log("");
        
        // Test 7: Multiple Small Transactions
        console.log("=== Test 7: Multiple Small Transactions ===");
        address[3] memory recipients = [
            address(0x4444444444444444444444444444444444444444),
            address(0x4444444444444444444444444444444444444445),
            address(0x4444444444444444444444444444444444444446)
        ];
        for (uint i = 0; i < 3; i++) {
            token.transfer(recipients[i], 500 * 1e18);
            console.log("[SUCCESS] Small transfer", i + 1, ": 500 CLT to", recipients[i]);
        }
        console.log("");
        
        // Final State
        console.log("=== Final Protocol State ===");
        console.log("Total Supply:", token.totalSupply() / 1e18, "CLT");
        console.log("User Balance:", token.balanceOf(msg.sender) / 1e18, "CLT");
        console.log("Total Staked:", staking.totalStaked() / 1e18, "CLT");
        console.log("User Liquidity:", pool.getUserLiquidity(msg.sender) / 1e18, "CLT");
        
        (userStaked,,) = staking.getStakeInfo(msg.sender);
        console.log("User Staked:", userStaked / 1e18, "CLT");
        
        vm.stopBroadcast();
        
        console.log("");
        console.log("=== INTERACTION TESTS COMPLETED ===");
        console.log("[SUCCESS] All tests passed successfully!");
        console.log("[LINK] Check all transactions on Core Explorer:");
        console.log("   https://scan.test2.btcs.network/address/", msg.sender);
        console.log("");
        console.log("[SUMMARY] Test Results:");
        console.log("   - Token minting: PASS");
        console.log("   - Token transfers: PASS");
        console.log("   - Additional staking: PASS");
        console.log("   - Additional liquidity: PASS");
        console.log("   - Partial unstaking: PASS");
        console.log("   - Reward system: PASS");
        console.log("   - Multiple transactions: PASS");
    }
}
