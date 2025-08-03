// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/TestContract.sol";

contract TestDeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        
        console.log("=== Deploying Test Contract ===");
        console.log("Deployer:", msg.sender);
        
        TestContract testContract = new TestContract(msg.sender);
        console.log("TestContract deployed at:", address(testContract));
        
        vm.stopBroadcast();
        
        console.log("=== Test Deployment Complete ===");
    }
}
