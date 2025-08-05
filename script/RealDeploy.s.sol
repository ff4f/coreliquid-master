// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../lib/forge-std/src/Script.sol";
import "../lib/forge-std/src/console.sol";
import "../contracts/staking/StCOREToken.sol";

contract RealDeployScript is Script {
    function run() external {
        vm.startBroadcast();
        
        console.log("Deploying StCOREToken to Core Testnet...");
        
        // Deploy StCOREToken with constructor parameters
        StCOREToken stCoreToken = new StCOREToken(
            address(0x1), // Mock CORE token address
            address(0x2), // Mock treasury address
            address(0x3)  // Mock staking manager address
        );
        
        console.log("StCOREToken deployed at:", address(stCoreToken));
        
        // Mint some test tokens
        stCoreToken.mint(msg.sender, 1000 * 1e18);
        
        console.log("Minted 1000 stCORE tokens to:", msg.sender);
        console.log("Total supply:", stCoreToken.totalSupply());
        
        vm.stopBroadcast();
        
        console.log("\n=== DEPLOYMENT COMPLETE ===");
        console.log("Network: Core Testnet (Chain ID: 1114)");
        console.log("StCOREToken Address:", address(stCoreToken));
        console.log("Explorer Link: https://scan.test2.btcs.network/address/", address(stCoreToken));
    }
}
