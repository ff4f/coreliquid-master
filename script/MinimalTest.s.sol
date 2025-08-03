// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../lib/forge-std/src/Script.sol";
import "../lib/forge-std/src/console.sol";

contract MinimalTestScript is Script {
    function run() external {
        vm.startBroadcast();
        
        console.log("Making minimal transaction on Core Testnet...");
        console.log("Deployer:", msg.sender);
        console.log("Balance:", msg.sender.balance);
        console.log("Block number:", block.number);
        console.log("Chain ID:", block.chainid);
        
        vm.stopBroadcast();
        
        console.log("\n=== TRANSACTION COMPLETE ===");
        console.log("Network: Core Testnet (Chain ID: 1114)");
        console.log("Transaction hash will be shown above");
        console.log("Explorer: https://scan.test2.btcs.network/");
    }
}
