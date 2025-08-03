// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/TrueUnifiedLiquidityLayer.sol";
import "../src/SimpleToken.sol";

/**
 * @title Simple Deploy Script for TrueUnifiedLiquidityLayer
 * @dev Minimal deployment script for testing
 */
contract SimpleDeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        
        console.log("=== Deploying True Unified Liquidity Layer ===");
        console.log("Deployer:", msg.sender);
        
        // Deploy TrueUnifiedLiquidityLayer only
        TrueUnifiedLiquidityLayer liquidityLayer = new TrueUnifiedLiquidityLayer(msg.sender);
        console.log("TrueUnifiedLiquidityLayer deployed at:", address(liquidityLayer));
        
        vm.stopBroadcast();
        
        console.log("=== Deployment Complete ===");
    }
}
