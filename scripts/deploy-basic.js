const { ethers } = require("hardhat");
const fs = require("fs");

async function main() {
    console.log("🚀 Starting Basic CoreLiquid Deployment...");
    
    const [deployer] = await ethers.getSigners();
    console.log("Deploying contracts with account:", deployer.address);
    console.log("Account balance:", (await deployer.getBalance()).toString());

    const deploymentResults = {
        network: "localhost",
        deployer: deployer.address,
        timestamp: new Date().toISOString(),
        contracts: {}
    };

    try {
        // Deploy SimpleToken for CORE
        console.log("\n📄 Deploying CORE Token...");
        const SimpleToken = await ethers.getContractFactory("SimpleToken");
        const coreToken = await SimpleToken.deploy(
            "Core Token",
            "CORE",
            ethers.utils.parseEther("1000000") // 1M tokens
        );
        await coreToken.deployed();
        console.log("✅ CORE Token deployed to:", coreToken.address);
        deploymentResults.contracts.coreToken = coreToken.address;

        // Deploy SimpleToken for BTC
        console.log("\n📄 Deploying BTC Token...");
        const btcToken = await SimpleToken.deploy(
            "Bitcoin Token",
            "BTC",
            ethers.utils.parseEther("21000") // 21K tokens
        );
        await btcToken.deployed();
        console.log("✅ BTC Token deployed to:", btcToken.address);
        deploymentResults.contracts.btcToken = btcToken.address;

        // Deploy Oracle
        console.log("\n📄 Deploying Oracle...");
        const Oracle = await ethers.getContractFactory("Oracle");
        const oracle = await Oracle.deploy();
        await oracle.deployed();
        console.log("✅ Oracle deployed to:", oracle.address);
        deploymentResults.contracts.oracle = oracle.address;

        // Set initial prices
        console.log("\n⚙️ Setting initial oracle prices...");
        await oracle.setPrice(coreToken.address, ethers.utils.parseEther("1")); // 1 USD
        await oracle.setPrice(btcToken.address, ethers.utils.parseEther("50000")); // 50,000 USD
        console.log("✅ Initial prices set");

        // Deploy CoreLiquid
        console.log("\n📄 Deploying CoreLiquid...");
        const CoreLiquid = await ethers.getContractFactory("CoreLiquid");
        const coreLiquid = await CoreLiquid.deploy(
            oracle.address,
            coreToken.address
        );
        await coreLiquid.deployed();
        console.log("✅ CoreLiquid deployed to:", coreLiquid.address);
        deploymentResults.contracts.coreLiquid = coreLiquid.address;

        // Deploy LiquidityPool
        console.log("\n📄 Deploying LiquidityPool...");
        const LiquidityPool = await ethers.getContractFactory("LiquidityPool");
        const liquidityPool = await LiquidityPool.deploy(
            coreLiquid.address,
            oracle.address
        );
        await liquidityPool.deployed();
        console.log("✅ LiquidityPool deployed to:", liquidityPool.address);
        deploymentResults.contracts.liquidityPool = liquidityPool.address;

        // Transfer some tokens to deployer for testing
        console.log("\n💰 Transferring initial tokens...");
        await coreToken.transfer(deployer.address, ethers.utils.parseEther("10000"));
        await btcToken.transfer(deployer.address, ethers.utils.parseEther("1"));
        console.log("✅ Initial tokens transferred");

        // Save deployment info
        const deploymentFile = `deployment-basic-${Date.now()}.json`;
        fs.writeFileSync(deploymentFile, JSON.stringify(deploymentResults, null, 2));
        console.log(`\n📋 Deployment info saved to: ${deploymentFile}`);

        console.log("\n🎉 Basic CoreLiquid Deployment Complete!");
        console.log("\n📊 Deployment Summary:");
        console.log("========================");
        console.log(`CORE Token: ${coreToken.address}`);
        console.log(`BTC Token: ${btcToken.address}`);
        console.log(`Oracle: ${oracle.address}`);
        console.log(`CoreLiquid: ${coreLiquid.address}`);
        console.log(`LiquidityPool: ${liquidityPool.address}`);
        console.log("========================");

        return deploymentResults;

    } catch (error) {
        console.error("❌ Deployment failed:", error);
        throw error;
    }
}

if (require.main === module) {
    main()
        .then(() => process.exit(0))
        .catch((error) => {
            console.error(error);
            process.exit(1);
        });
}

module.exports = main;