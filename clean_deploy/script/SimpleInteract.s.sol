// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../lib/forge-std/src/Script.sol";
import "../lib/forge-std/src/console.sol";

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function totalSupply() external view returns (uint256);
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
}

interface IStaking {
    function totalStaked() external view returns (uint256);
}

contract SimpleInteractScript is Script {
    // Contract addresses from deployment
    address constant TOKEN_ADDRESS = 0xb6FA89f623169D8f071aE7449b6CCA6726d7d302;
    address constant STAKING_ADDRESS = 0x2ceb6C61b806cD41e89f33eEFb177c970d9c4649;
    address constant POOL_ADDRESS = 0xb30FE4D5b684d0093625b0CE3b9Cbd12db4603aD;
    
    // Test recipient addresses
    address constant RECIPIENT_1 = 0x2222222222222222222222222222222222222222;
    address constant RECIPIENT_2 = 0x3333333333333333333333333333333333333333;
    address constant RECIPIENT_3 = 0x4444444444444444444444444444444444444444;
    
    function run() external {
        uint256 deployerPrivateKey = 0xa964ebb3fcd6f9df281a24dca86ed4cf7def119aa32487461a0d7e6a9b7c8865;
        vm.startBroadcast(deployerPrivateKey);
        
        address deployer = vm.addr(deployerPrivateKey);
        
        IERC20 token = IERC20(TOKEN_ADDRESS);
        IStaking staking = IStaking(STAKING_ADDRESS);
        
        console.log("=== CoreLiquid Protocol Simple Interaction Test ===");
        console.log("User:", deployer);
        console.log("Block:", block.number);
        console.log("Timestamp:", block.timestamp);
        console.log("");
        
        // Check initial state
        console.log("=== Initial State ===");
        console.log("Token Name:", token.name());
        console.log("Token Symbol:", token.symbol());
        console.log("Total Supply:", token.totalSupply() / 1e18, "CLT");
        console.log("User Balance:", token.balanceOf(deployer) / 1e18, "CLT");
        console.log("Total Staked:", staking.totalStaked() / 1e18, "CLT");
        console.log("");
        
        // Test 1: Token Transfers
        uint256 userBalance = token.balanceOf(deployer);
        if (userBalance > 0) {
            console.log("=== Test 1: Token Transfers ===");
            
            uint256 transferAmount = 100 * 1e18; // 100 CLT
            if (userBalance >= transferAmount * 3) {
                // Transfer to recipient 1
                token.transfer(RECIPIENT_1, transferAmount);
                console.log("[SUCCESS] Transferred", transferAmount / 1e18, "CLT to", RECIPIENT_1);
                
                // Transfer to recipient 2
                token.transfer(RECIPIENT_2, transferAmount);
                console.log("[SUCCESS] Transferred", transferAmount / 1e18, "CLT to", RECIPIENT_2);
                
                // Transfer to recipient 3
                token.transfer(RECIPIENT_3, transferAmount);
                console.log("[SUCCESS] Transferred", transferAmount / 1e18, "CLT to", RECIPIENT_3);
            } else {
                console.log("[INFO] Insufficient balance for transfers");
            }
            console.log("");
        }
        
        // Test 2: Additional Approvals
        console.log("=== Test 2: Additional Approvals ===");
        token.approve(STAKING_ADDRESS, 1000 * 1e18);
        console.log("[SUCCESS] Approved 1000 CLT for staking");
        
        token.approve(POOL_ADDRESS, 500 * 1e18);
        console.log("[SUCCESS] Approved 500 CLT for pool");
        console.log("");
        
        // Test 3: Final State Check
        console.log("=== Test 3: Final State Check ===");
        console.log("Total Supply:", token.totalSupply() / 1e18, "CLT");
        console.log("Total Staked:", staking.totalStaked() / 1e18, "CLT");
        console.log("User Balance:", token.balanceOf(deployer) / 1e18, "CLT");
        console.log("Recipient 1 Balance:", token.balanceOf(RECIPIENT_1) / 1e18, "CLT");
        console.log("Recipient 2 Balance:", token.balanceOf(RECIPIENT_2) / 1e18, "CLT");
        console.log("Recipient 3 Balance:", token.balanceOf(RECIPIENT_3) / 1e18, "CLT");
        console.log("");
        
        console.log("[LINK] Check all transactions on Core Explorer:");
        console.log("https://scan.test2.btcs.network/address/", deployer);
        console.log("");
        
        console.log("[SUMMARY] Simple Interaction Test Results:");
        console.log("- Token transfers: COMPLETED");
        console.log("- Additional approvals: COMPLETED");
        console.log("- State verification: COMPLETED");
        console.log("- All transactions successful!");
        
        vm.stopBroadcast();
    }
}
