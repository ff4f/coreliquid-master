// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/SimpleTULL.sol";
import "../src/SimpleToken.sol";

/**
 * @title Simple Test Script with Real Address
 * @dev Simple deployment and testing script
 */
contract SimpleTestScript is Script {
    function run() external {
        // Use the provided private key directly
        uint256 deployerPrivateKey = 0x547319fd1f45871090b38a84c075dc6155012fddcf4024bf0b202f193e9878b6;
        
        vm.startBroadcast(deployerPrivateKey);
        
        console.log("=== CoreLiquid Simple Testing ===");
        console.log("Deployer:", msg.sender);
        console.log("Target User:", 0x22A196A5D71B30542a9EEd349BE98DE352Fdb565);
        
        // Deploy SimpleTULL
        SimpleTULL simpleTull = new SimpleTULL(msg.sender);
        console.log("SimpleTULL deployed at:", address(simpleTull));
        
        // Deploy test tokens
        SimpleToken coreToken = new SimpleToken("Core Token", "CORE", 18, 1000000 * 1e18);
        SimpleToken btcToken = new SimpleToken("Bitcoin Token", "BTC", 8, 21000 * 1e8);
        
        console.log("CORE Token deployed at:", address(coreToken));
        console.log("BTC Token deployed at:", address(btcToken));
        
        // Setup supported assets
        simpleTull.addSupportedAsset(address(coreToken));
        simpleTull.addSupportedAsset(address(btcToken));
        
        console.log("Assets added as supported");
        
        // Register a protocol
        simpleTull.registerProtocol(
            msg.sender,
            "CoreLiquid Protocol",
            1200, // 12% APY
            1000000 * 1e18 // 1M capacity
        );
        
        console.log("Protocol registered successfully");
        
        // Transfer tokens to target user
        address targetUser = 0x22A196A5D71B30542a9EEd349BE98DE352Fdb565;
        coreToken.transfer(targetUser, 10000 * 1e18); // 10k CORE
        btcToken.transfer(targetUser, 1 * 1e8); // 1 BTC
        
        console.log("Tokens transferred to target user:");
        console.log("- 10,000 CORE tokens");
        console.log("- 1 BTC token");
        
        // Grant PROTOCOL_ROLE to deployer for testing
        bytes32 protocolRole = keccak256("PROTOCOL_ROLE");
        simpleTull.grantRole(protocolRole, msg.sender);
        
        console.log("Protocol role granted to deployer");
        
        // Test deposit functionality
        coreToken.approve(address(simpleTull), 1000 * 1e18);
        simpleTull.deposit(address(coreToken), 1000 * 1e18, msg.sender);
        
        console.log("Test deposit completed: 1000 CORE");
        console.log("User balance:", simpleTull.getUserBalance(msg.sender, address(coreToken)));
        
        // Test protocol allocation
        simpleTull.allocateToProtocol(msg.sender, address(coreToken), 500 * 1e18);
        console.log("Allocated 500 CORE to protocol");
        
        vm.stopBroadcast();
        
        console.log("\n=== DEPLOYMENT SUMMARY ===");
        console.log("Network: Core Testnet (Chain ID: 1114)");
        console.log("SimpleTULL:", address(simpleTull));
        console.log("CORE Token:", address(coreToken));
        console.log("BTC Token:", address(btcToken));
        console.log("Explorer Base: https://scan.test2.btcs.network/address/");
        
        console.log("\n=== TRANSACTION PROOF ===");
        console.log("All contracts deployed and tested successfully!");
        console.log("Real transactions will be visible on Core Testnet Explorer");
    }
}