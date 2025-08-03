// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../lib/forge-std/src/Script.sol";
import "../lib/forge-std/src/console.sol";

// Simple test contract
contract SimpleStorage {
    uint256 public value;
    
    constructor(uint256 _value) {
        value = _value;
    }
    
    function setValue(uint256 _value) external {
        value = _value;
    }
}

contract SimpleTestScript is Script {
    function run() external {
        vm.startBroadcast();
        
        console.log("Deploying Simple Storage to Core Testnet...");
        console.log("Deployer:", msg.sender);
        console.log("Balance:", msg.sender.balance);
        
        // Deploy simple contract
        SimpleStorage storage_ = new SimpleStorage(42);
        
        console.log("SimpleStorage deployed at:", address(storage_));
        console.log("Initial value:", storage_.value());
        
        // Make a transaction
        storage_.setValue(100);
        console.log("Updated value:", storage_.value());
        
        vm.stopBroadcast();
        
        console.log("\n=== DEPLOYMENT COMPLETE ===");
        console.log("Network: Core Testnet (Chain ID: 1114)");
        console.log("Contract Address:", address(storage_));
        console.log("Explorer Link: https://scan.test2.btcs.network/address/", address(storage_));
    }
}
