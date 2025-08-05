// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/SimpleToken.sol";

/**
 * @title Basic Test Script with Real Address
 * @dev Basic token deployment and transfer testing
 */
contract BasicTestScript is Script {
    function run() external {
        // Use the provided private key directly
        uint256 deployerPrivateKey = 0x547319fd1f45871090b38a84c075dc6155012fddcf4024bf0b202f193e9878b6;
        
        vm.startBroadcast(deployerPrivateKey);
        
        console.log("=== CoreLiquid Basic Testing with Real Address ===");
        console.log("Deployer:", msg.sender);
        console.log("Target User:", 0x22A196A5D71B30542a9EEd349BE98DE352Fdb565);
        
        // Deploy test tokens
        SimpleToken coreToken = new SimpleToken("CoreLiquid Token", "CORE", 18, 1000000 * 1e18);
        SimpleToken btcToken = new SimpleToken("Bitcoin Token", "BTC", 8, 21000 * 1e8);
        
        console.log("CORE Token deployed at:", address(coreToken));
        console.log("BTC Token deployed at:", address(btcToken));
        
        // Check initial balances
        console.log("Deployer CORE balance:", coreToken.balanceOf(msg.sender));
        console.log("Deployer BTC balance:", btcToken.balanceOf(msg.sender));
        
        // Transfer tokens to target user
        address targetUser = 0x22A196A5D71B30542a9EEd349BE98DE352Fdb565;
        
        // Transfer significant amounts for testing
        uint256 coreAmount = 50000 * 1e18; // 50k CORE
        uint256 btcAmount = 5 * 1e8; // 5 BTC
        
        coreToken.transfer(targetUser, coreAmount);
        btcToken.transfer(targetUser, btcAmount);
        
        console.log("\n=== TRANSFER COMPLETED ===");
        console.log("Transferred to", targetUser, ":");
        console.log("- 50,000 CORE tokens");
        console.log("- 5 BTC tokens");
        
        // Verify balances
        console.log("\n=== BALANCE VERIFICATION ===");
        console.log("Target user CORE balance:", coreToken.balanceOf(targetUser));
        console.log("Target user BTC balance:", btcToken.balanceOf(targetUser));
        
        // Test approval functionality
        coreToken.approve(targetUser, 1000 * 1e18);
        console.log("Approved 1000 CORE for target user");
        console.log("Allowance:", coreToken.allowance(msg.sender, targetUser));
        
        vm.stopBroadcast();
        
        console.log("\n=== DEPLOYMENT SUMMARY ===");
        console.log("Network: Core Testnet (Chain ID: 1114)");
        console.log("CORE Token:", address(coreToken));
        console.log("BTC Token:", address(btcToken));
        console.log("Deployer:", msg.sender);
        console.log("Target User:", targetUser);
        console.log("Explorer Base: https://scan.test2.btcs.network/address/");
        
        console.log("\n=== TRANSACTION PROOF ===");
        console.log("[SUCCESS] All contracts deployed successfully!");
        console.log("[SUCCESS] Tokens transferred to real address!");
        console.log("[SUCCESS] Real transactions are now visible on Core Testnet Explorer");
        console.log("\nCheck transactions at:");
        console.log("https://scan.test2.btcs.network/address/", address(coreToken));
        console.log("https://scan.test2.btcs.network/address/", address(btcToken));
    }
}