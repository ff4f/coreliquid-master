// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../contracts/SimpleToken.sol";
import "../contracts/lending/CollateralManager.sol";
import "../contracts/lending/BorrowEngine.sol";
import "../contracts/lending/LiquidationEngine.sol";
import "../contracts/lending/FeeSpreadModel.sol";

/**
 * @title Minimal Lending Deployment
 * @dev Deploy only the essential lending contracts for hackathon demo
 */
contract MinimalLendingDeployScript is Script {
    function run() external {
        // Use a test private key for simulation
        uint256 deployerPrivateKey = 0x4f3edf983ac636a65a842ce7c78d9aa706d3b113bce9c46f30d7d21715b23b1d;
        vm.startBroadcast(deployerPrivateKey);
        
        console.log("=== CoreLiquid Minimal Lending Deployment ===");
        console.log("Deployer:", msg.sender);
        
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
        
        // Deploy fee model
        FeeSpreadModel feeSpreadModel = new FeeSpreadModel(100); // 1% base fee
        console.log("Fee Spread Model deployed at:", address(feeSpreadModel));
        
        // Deploy core lending contracts
        CollateralManager collateralManager = new CollateralManager();
        console.log("Collateral Manager deployed at:", address(collateralManager));
        
        BorrowEngine borrowEngine = new BorrowEngine(
            address(0x1), // Mock oracle
            msg.sender // treasury
        );
        console.log("Borrow Engine deployed at:", address(borrowEngine));
        
        LiquidationEngine liquidationEngine = new LiquidationEngine(
            address(collateralManager),
            address(borrowEngine),
            msg.sender // treasury
        );
        console.log("Liquidation Engine deployed at:", address(liquidationEngine));
        
        console.log("\n=== Deployment Summary ===");
        console.log("[SUCCESS] Core lending contracts deployed");
        console.log("[SUCCESS] Ready for hackathon demo!");
        console.log("\n=== Contract Addresses ===");
        console.log("CORE Token:", address(coreToken));
        console.log("BTC Token:", address(btcToken));
        console.log("Fee Model:", address(feeSpreadModel));
        console.log("Collateral Manager:", address(collateralManager));
        console.log("Borrow Engine:", address(borrowEngine));
        console.log("Liquidation Engine:", address(liquidationEngine));
        
        vm.stopBroadcast();
    }
}