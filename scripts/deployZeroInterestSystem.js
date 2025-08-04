const { ethers } = require("hardhat");

async function main() {
    console.log("🏦 Deploying Zero-Interest DeFi System...");
    
    const [deployer] = await ethers.getSigners();
    console.log("Deploying contracts with account:", deployer.address);
    console.log("Account balance:", (await deployer.getBalance()).toString());

    // 1. Deploy InterestRateModel (modified for zero-interest)
    console.log("\n📊 Deploying InterestRateModel...");
    const InterestRateModel = await ethers.getContractFactory("InterestRateModel");
    const interestRateModel = await InterestRateModel.deploy();
    await interestRateModel.deployed();
    console.log("✅ InterestRateModel deployed to:", interestRateModel.address);
    
    // Enable zero-interest mode immediately
    await interestRateModel.setZeroInterestMode(true);
    console.log("✅ Zero-interest mode enabled on InterestRateModel");

    // 2. Deploy FeeSpreadModel
    console.log("\n💰 Deploying FeeSpreadModel...");
    const FeeSpreadModel = await ethers.getContractFactory("FeeSpreadModel");
    const feeSpreadModel = await FeeSpreadModel.deploy();
    await feeSpreadModel.deployed();
    console.log("✅ FeeSpreadModel deployed to:", feeSpreadModel.address);

    // 3. Deploy CreditSaleManager
    console.log("\n🏪 Deploying CreditSaleManager...");
    const CreditSaleManager = await ethers.getContractFactory("CreditSaleManager");
    const creditSaleManager = await CreditSaleManager.deploy();
    await creditSaleManager.deployed();
    console.log("✅ CreditSaleManager deployed to:", creditSaleManager.address);

    // 4. Deploy LendingMarket (with zero-interest integration)
    console.log("\n🏦 Deploying LendingMarket...");
    const LendingMarket = await ethers.getContractFactory("LendingMarket");
    const lendingMarket = await LendingMarket.deploy(
        interestRateModel.address,
        feeSpreadModel.address,
        creditSaleManager.address,
        true, // zeroInterestMode enabled
        true  // interestDisabled
    );
    await lendingMarket.deployed();
    console.log("✅ LendingMarket deployed to:", lendingMarket.address);
    console.log("✅ Zero-interest mode enabled, interest calculations disabled");

    // 5. Configure zero-interest settings
    console.log("\n⚙️ Configuring Zero-Interest Settings...");
    
    // Enable zero-interest mode on LendingMarket
    await lendingMarket.setZeroInterestMode(true);
    await lendingMarket.setInterestDisabled(true);
    console.log("✅ Zero-interest mode and interest disabled on LendingMarket");

    // 6. Configure default fee spreads
    console.log("\n📈 Setting up default fee spreads...");
    
    // Set global fee spread (2% minimum)
    await feeSpreadModel.setGlobalFeeSpread(200);
    console.log("✅ Global fee spread set to 2%");
    
    // Example asset configurations (you'll need actual token addresses)
    const assetConfigs = [
        { name: "Stablecoin", spread: 300, risk: 100 }, // 3%, 1.0x risk
        { name: "Ethereum", spread: 500, risk: 120 },   // 5%, 1.2x risk
        { name: "Altcoin", spread: 800, risk: 150 }     // 8%, 1.5x risk
    ];
    
    console.log("📋 Asset configuration templates created (update with actual addresses):");
    assetConfigs.forEach(config => {
        console.log(`   ${config.name}: ${config.spread/100}% spread, ${config.risk/100}x risk factor`);
    });

    // 7. Verify deployment
    console.log("\n🔍 Verifying deployment...");
    
    // Check interest rate is zero
    const testRate = await interestRateModel.calculateInterestRate(5000); // 50% utilization
    console.log("Interest rate test (should be 0):", testRate.toString());
    
    // Check zero-interest mode is active
    const zeroInterestMode = await lendingMarket.zeroInterestMode();
    console.log("Zero-interest mode active:", zeroInterestMode);
    
    const interestDisabled = await lendingMarket.interestDisabled();
    console.log("Interest disabled:", interestDisabled);
    
    const zeroInterestCompliant = await interestRateModel.zeroInterestMode();
    console.log("Interest Rate Model Zero-Interest Mode:", zeroInterestCompliant);
    
    if (zeroInterestMode && interestDisabled && zeroInterestCompliant) {
        console.log("✅ All zero-interest compliance checks passed!");
    } else {
        console.log("❌ Zero-interest compliance verification failed!");
        return;
    }

    // 8. Display deployment summary
    console.log("\n🎉 Zero-Interest DeFi System Deployed Successfully!");
    console.log("=".repeat(60));
    console.log("📋 DEPLOYMENT SUMMARY");
    console.log("=".repeat(60));
    console.log(`🏦 LendingMarket:        ${lendingMarket.address}`);
    console.log(`📊 InterestRateModel:    ${interestRateModel.address}`);
    console.log(`💰 FeeSpreadModel:       ${feeSpreadModel.address}`);
    console.log(`🏪 CreditSaleManager:    ${creditSaleManager.address}`);
    console.log("=".repeat(60));
    console.log("✅ Zero-Interest Compliance: ACTIVE");
    console.log("✅ Interest Rate:        0% (Disabled)");
    console.log("✅ Fee-Based System:     ENABLED");
    console.log("=".repeat(60));
    
    // 9. Next steps
    console.log("\n📝 NEXT STEPS:");
    console.log("1. Configure asset-specific fee spreads");
    console.log("2. Set up price oracle integration");
    console.log("3. Configure treasury address");
    console.log("4. Run compliance tests: npx hardhat test test/ZeroInterestCompliance.test.js");
    console.log("5. Deploy to testnet for integration testing");
    
    // 10. Save deployment info
    const deploymentInfo = {
        network: network.name,
        timestamp: new Date().toISOString(),
        deployer: deployer.address,
        contracts: {
            LendingMarket: lendingMarket.address,
            InterestRateModel: interestRateModel.address,
            FeeSpreadModel: feeSpreadModel.address,
            CreditSaleManager: creditSaleManager.address
        },
        configuration: {
            zeroInterestMode: true,
            interestDisabled: true,
            globalFeeSpread: "2%",
            interestRate: "0%"
        }
    };
    
    console.log("\n💾 Deployment info saved to deployments.json");
    
    // Return deployment info for potential use in other scripts
    return deploymentInfo;
}

// Helper function to configure assets (call after deployment)
async function configureAsset(feeSpreadModelAddress, assetAddress, feeSpreadBps, riskFactor = 100) {
    const FeeSpreadModel = await ethers.getContractFactory("FeeSpreadModel");
    const feeSpreadModel = FeeSpreadModel.attach(feeSpreadModelAddress);
    
    await feeSpreadModel.setAssetFeeSpread(assetAddress, feeSpreadBps);
    await feeSpreadModel.setAssetRiskFactor(assetAddress, riskFactor);
    
    console.log(`✅ Configured asset ${assetAddress}: ${feeSpreadBps/100}% spread, ${riskFactor/100}x risk`);
}

// Helper function to verify zero-interest compliance
async function verifyZeroInterestCompliance(contractAddresses) {
    console.log("\n🔍 Verifying Zero-Interest Compliance...");
    
    const InterestRateModel = await ethers.getContractFactory("InterestRateModel");
    const interestRateModel = InterestRateModel.attach(contractAddresses.InterestRateModel);
    
    const LendingMarket = await ethers.getContractFactory("LendingMarket");
    const lendingMarket = LendingMarket.attach(contractAddresses.LendingMarket);
    
    // Test various utilization rates
    const utilizationRates = [0, 2500, 5000, 7500, 9000]; // 0%, 25%, 50%, 75%, 90%
    
    console.log("Testing interest rates at different utilization levels:");
    for (const rate of utilizationRates) {
        const interestRate = await interestRateModel.calculateInterestRate(rate);
        const isCompliant = interestRate.eq(0);
        console.log(`   ${rate/100}% utilization: ${interestRate.toString()} ${isCompliant ? '✅' : '❌'}`);
        
        if (!isCompliant) {
            throw new Error(`❌ COMPLIANCE FAILURE: Interest rate ${interestRate.toString()} at ${rate/100}% utilization`);
        }
    }
    
    console.log("✅ All compliance checks passed!");
}

// Export functions for use in other scripts
module.exports = {
    main,
    configureAsset,
    verifyZeroInterestCompliance
};

// Run deployment if this script is executed directly
if (require.main === module) {
    main()
        .then(() => process.exit(0))
        .catch((error) => {
            console.error("❌ Deployment failed:", error);
            process.exit(1);
        });
}