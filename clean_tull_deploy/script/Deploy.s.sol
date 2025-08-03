// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/TrueUnifiedLiquidityLayer.sol";
import "../src/SimpleToken.sol";

/**
 * @title Clean Deploy Script for TrueUnifiedLiquidityLayer
 * @dev Simple deployment script for testing
 */
contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        
        console.log("=== Deploying True Unified Liquidity Layer ===");
        console.log("Deployer:", msg.sender);
        
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
            "Mock Protocol",
            800, // 8% APY
            1000000 * 1e18, // 1M capacity
            25 // Medium risk
        );
        
        console.log("Mock protocol registered");
        
        vm.stopBroadcast();
        
        console.log("=== Deployment Completed ===");
    }
}
