// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../lib/forge-std/src/Script.sol";
import "../lib/forge-std/src/console.sol";
import "../contracts/StCOREToken.sol";

contract SimpleStCOREDeployScript is Script {
    function run() external {
        vm.startBroadcast();
        
        console.log("Deploying StCOREToken to Core Testnet...");
        console.log("Deployer address:", msg.sender);
        console.log("Chain ID:", block.chainid);
        
        // Deploy StCOREToken with constructor parameters
        StCOREToken stCoreToken = new StCOREToken(
            "Staked CORE",
            "stCORE",
            address(0) // No staking contract for now
        );
        
        console.log("StCOREToken deployed at:", address(stCoreToken));
        
        // Mint some test tokens
        stCoreToken.mint(msg.sender, 1000 * 1e18);
        
        console.log("Minted 1000 stCORE tokens to:", msg.sender);
        console.log("Total supply:", stCoreToken.totalSupply());
        console.log("Balance of deployer:", stCoreToken.balanceOf(msg.sender));
        
        vm.stopBroadcast();
        
        console.log("\n=== DEPLOYMENT COMPLETE ===");
        console.log("Network: Core Testnet (Chain ID: 1114)");
        console.log("StCOREToken Address:", address(stCoreToken));
        console.log("Explorer Link: https://scan.test2.btcs.network/address/%s", address(stCoreToken));
        console.log("Transaction Explorer: https://scan.test2.btcs.network/tx/");
    }
}
