// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/SimpleTULL.sol";
import "../src/SimpleToken.sol";

contract SimpleTULLDeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        
        console.log("=== Deploying Simple TULL ===");
        console.log("Deployer:", msg.sender);
        
        // Deploy SimpleTULL
        SimpleTULL tull = new SimpleTULL(msg.sender);
        console.log("SimpleTULL deployed at:", address(tull));
        
        // Deploy test tokens
        SimpleToken coreToken = new SimpleToken("Core Token", "CORE", 18, 1000000 * 10**18);
        SimpleToken btcToken = new SimpleToken("Bitcoin Token", "BTC", 8, 21000 * 10**8);
        
        console.log("CORE Token deployed at:", address(coreToken));
        console.log("BTC Token deployed at:", address(btcToken));
        
        // Add supported assets
        tull.addSupportedAsset(address(coreToken));
        tull.addSupportedAsset(address(btcToken));
        
        console.log("Assets added to TULL");
        
        vm.stopBroadcast();
        
        console.log("=== Simple TULL Deployment Complete ===");
        console.log("SimpleTULL:", address(tull));
        console.log("CORE Token:", address(coreToken));
        console.log("BTC Token:", address(btcToken));
    }
}
