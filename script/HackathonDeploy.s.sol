// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../contracts/SimpleToken.sol";
import "../contracts/lending/BorrowEngine.sol";
import "../contracts/lending/LiquidationEngine.sol";
import "../contracts/lending/CollateralManager.sol";
import "../contracts/lending/CreditManager.sol";
import "../contracts/lending/FeeSpreadModel.sol";
import "../contracts/core/DynamicFeeModel.sol";
import "../contracts/oracles/PriceOracle.sol";

/**
 * @title Hackathon Deployment Script
 * @dev Deploy CoreLiquid lending system for Core DAO hackathon
 */
contract HackathonDeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        
        console.log("=== CoreLiquid Hackathon Deployment ===");
        console.log("Deployer:", msg.sender);
        console.log("Network:", block.chainid);
        
        // Deploy test tokens
        SimpleToken coreToken = new SimpleToken(
            "Core Token",
            "CORE",
            18,
            1000000 // 1M tokens
        );
        
        SimpleToken btcToken = new SimpleToken(
            "Bitcoin Token", 
            "BTC",
            8,
            21000 // 21K tokens
        );
        
        console.log("CORE Token deployed at:", address(coreToken));
        console.log("BTC Token deployed at:", address(btcToken));
        
        // Deploy oracle
        PriceOracle oracle = new PriceOracle();
        console.log("Price Oracle deployed at:", address(oracle));
        
        // Deploy fee models
        FeeSpreadModel feeSpreadModel = new FeeSpreadModel(100); // 1% base fee
        DynamicFeeModel dynamicFeeModel = new DynamicFeeModel();
        
        console.log("Fee Spread Model deployed at:", address(feeSpreadModel));
        console.log("Dynamic Fee Model deployed at:", address(dynamicFeeModel));
        
        // Deploy core lending contracts
        CollateralManager collateralManager = new CollateralManager(
            address(oracle),
            msg.sender // treasury
        );
        
        BorrowEngine borrowEngine = new BorrowEngine(
            address(oracle),
            address(collateralManager),
            msg.sender // treasury
        );
        
        LiquidationEngine liquidationEngine = new LiquidationEngine(
            address(borrowEngine),
            address(collateralManager),
            address(oracle),
            msg.sender // treasury
        );
        
        CreditManager creditManager = new CreditManager(
            address(dynamicFeeModel),
            address(oracle),
            msg.sender // treasury
        );
        
        console.log("Collateral Manager deployed at:", address(collateralManager));
        console.log("Borrow Engine deployed at:", address(borrowEngine));
        console.log("Liquidation Engine deployed at:", address(liquidationEngine));
        console.log("Credit Manager deployed at:", address(creditManager));
        
        // Setup initial configuration
        console.log("\n=== Setting up initial configuration ===");
        
        // Add supported assets to collateral manager
        collateralManager.addSupportedAsset(address(coreToken), 8000); // 80% LTV
        collateralManager.addSupportedAsset(address(btcToken), 7500);  // 75% LTV
        
        // Set liquidation engine in borrow engine
        borrowEngine.setLiquidationEngine(address(liquidationEngine));
        
        // Add fee curves for dynamic fee model
        dynamicFeeModel.addAsset(
            address(coreToken),
            500,  // 5% base spread
            1000, // 10% slope
            8000  // 80% target utilization
        );
        
        dynamicFeeModel.addAsset(
            address(btcToken),
            600,  // 6% base spread
            1200, // 12% slope
            7500  // 75% target utilization
        );
        
        console.log("Configuration completed successfully!");
        
        // Transfer some tokens to deployer for testing
        console.log("\n=== Initial token distribution ===");
        console.log("Deployer CORE balance:", coreToken.balanceOf(msg.sender));
        console.log("Deployer BTC balance:", btcToken.balanceOf(msg.sender));
        
        vm.stopBroadcast();
        
        console.log("\n=== Deployment Summary ===");
        console.log("[SUCCESS] All contracts deployed successfully");
        console.log("[SUCCESS] Initial configuration completed");
        console.log("[SUCCESS] Ready for hackathon demo!");
    }
}