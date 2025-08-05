// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/TrueUnifiedLiquidityLayer.sol";
import "../src/SimpleToken.sol";

/**
 * @title Test Deploy Script with Real Address
 * @dev Deployment script for testing with provided address
 */
contract TestDeployScript is Script {
    function run() external {
        // Use the provided private key directly
        uint256 deployerPrivateKey = 0x547319fd1f45871090b38a84c075dc6155012fddcf4024bf0b202f193e9878b6;
        
        vm.startBroadcast(deployerPrivateKey);
        
        console.log("=== Testing CoreLiquid with Real Address ===");
        console.log("Deployer:", msg.sender);
        console.log("Target User:", 0x22A196A5D71B30542a9EEd349BE98DE352Fdb565);
        
        // Deploy TrueUnifiedLiquidityLayer
        TrueUnifiedLiquidityLayer liquidityLayer = new TrueUnifiedLiquidityLayer(msg.sender);
        console.log("TrueUnifiedLiquidityLayer deployed at:", address(liquidityLayer));
        
        // Deploy test tokens
        SimpleToken coreToken = new SimpleToken("Core Token", "CORE", 18, 1000000 * 1e18);
        SimpleToken btcToken = new SimpleToken("Bitcoin Token", "BTC", 8, 21000 * 1e8);
        
        console.log("CORE Token deployed at:", address(coreToken));
        console.log("BTC Token deployed at:", address(btcToken));
        
        // Setup supported assets
        liquidityLayer.addSupportedAsset(address(coreToken));
        liquidityLayer.addSupportedAsset(address(btcToken));
        
        console.log("Assets added as supported");
        
        // Register a mock protocol
        liquidityLayer.registerProtocol(
            msg.sender, // Use deployer as mock protocol
            "CoreLiquid Protocol",
            1200, // 12% APY
            1000000 * 1e18, // 1M capacity
            30 // Medium risk
        );
        
        console.log("CoreLiquid protocol registered");
        
        // Transfer some tokens to target user for testing
        address targetUser = 0x22A196A5D71B30542a9EEd349BE98DE352Fdb565;
        coreToken.transfer(targetUser, 10000 * 1e18); // 10k CORE
        btcToken.transfer(targetUser, 1 * 1e8); // 1 BTC
        
        console.log("Tokens transferred to target user:");
        console.log("- 10,000 CORE tokens");
        console.log("- 1 BTC token");
        
        // Grant PROTOCOL_ROLE to deployer for testing
        bytes32 protocolRole = keccak256("PROTOCOL_ROLE");
        liquidityLayer.grantRole(protocolRole, msg.sender);
        
        console.log("Protocol role granted to deployer");
        
        // Test deposit functionality - approve from deployer and deposit for deployer
        coreToken.approve(address(liquidityLayer), 1000 * 1e18);
        liquidityLayer.deposit(address(coreToken), 1000 * 1e18, msg.sender);
        
        console.log("Test deposit completed: 1000 CORE");
        console.log("User balance:", liquidityLayer.getUserBalance(msg.sender, address(coreToken)));
        
        vm.stopBroadcast();
        
        console.log("\n=== DEPLOYMENT SUMMARY ===");
        console.log("Network: Core Testnet (Chain ID: 1114)");
        console.log("TrueUnifiedLiquidityLayer:", address(liquidityLayer));
        console.log("CORE Token:", address(coreToken));
        console.log("BTC Token:", address(btcToken));
        console.log("Explorer Base: https://scan.test2.btcs.network/address/");
    }
}
