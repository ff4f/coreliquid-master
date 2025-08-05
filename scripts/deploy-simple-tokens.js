require('dotenv').config();
const { ethers } = require("hardhat");

async function main() {
    console.log("🚀 Deploying Simple Tokens to Core Testnet");
    console.log("==========================================\n");
    
    const [deployer] = await ethers.getSigners();
    console.log("Deploying contracts with account:", deployer.address);
    console.log("Account balance:", ethers.utils.formatEther(await deployer.getBalance()), "ETH\n");

    try {
        // Deploy SimpleToken for CORE
        console.log("📄 Deploying CORE Token...");
        const CoreToken = await ethers.getContractFactory("SimpleToken");
        const coreToken = await CoreToken.deploy(
            "Core Token",
            "CORE",
            ethers.utils.parseEther("1000000") // 1M tokens
        );
        await coreToken.deployed();
        console.log("✅ CORE Token deployed to:", coreToken.address);

        // Deploy SimpleToken for BTC
        console.log("📄 Deploying BTC Token...");
        const BtcToken = await ethers.getContractFactory("SimpleToken");
        const btcToken = await BtcToken.deploy(
            "Bitcoin Token",
            "BTC",
            ethers.utils.parseEther("21000") // 21K tokens
        );
        await btcToken.deployed();
        console.log("✅ BTC Token deployed to:", btcToken.address);

        // Deploy Oracle
        console.log("📄 Deploying Oracle...");
        const Oracle = await ethers.getContractFactory("Oracle");
        const oracle = await Oracle.deploy();
        await oracle.deployed();
        console.log("✅ Oracle deployed to:", oracle.address);

        // Set initial prices
        console.log("📊 Setting initial prices...");
        await oracle.setPrice(coreToken.address, ethers.utils.parseEther("1.5")); // $1.5
        await oracle.setPrice(btcToken.address, ethers.utils.parseEther("45000")); // $45,000
        console.log("✅ Initial prices set");

        console.log("\n🎉 Deployment Summary");
        console.log("=====================");
        console.log("Network: Core Testnet");
        console.log("Deployer:", deployer.address);
        console.log("CORE Token:", coreToken.address);
        console.log("BTC Token:", btcToken.address);
        console.log("Oracle:", oracle.address);
        
        console.log("\n📋 Verification Commands:");
        console.log("=========================");
        console.log(`npx hardhat verify --network coreTestnet ${coreToken.address} "Core Token" "CORE" "${ethers.utils.parseEther("1000000")}"`); 
        console.log(`npx hardhat verify --network coreTestnet ${btcToken.address} "Bitcoin Token" "BTC" "${ethers.utils.parseEther("21000")}"`); 
        console.log(`npx hardhat verify --network coreTestnet ${oracle.address}`);
        
        console.log("\n🏆 Basic Contracts Deployed Successfully!");
        console.log("Ready for hackathon demonstration!");
        
    } catch (error) {
        console.error("❌ Deployment failed:", error.message);
        throw error;
    }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });