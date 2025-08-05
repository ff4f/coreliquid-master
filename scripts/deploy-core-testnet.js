require('dotenv').config();
const { ethers } = require("hardhat");

async function main() {
    console.log("🚀 Deploying CoreLiquid Protocol to Core Testnet");
    console.log("================================================\n");
    
    const [deployer] = await ethers.getSigners();
    console.log("Deploying contracts with account:", deployer.address);
    console.log("Account balance:", ethers.utils.formatEther(await deployer.getBalance()), "ETH\n");

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

    // Deploy CoreLiquid
    console.log("📄 Deploying CoreLiquid...");
    const CoreLiquid = await ethers.getContractFactory("CoreLiquid");
    const coreLiquid = await CoreLiquid.deploy(
        oracle.address,
        coreToken.address
    );
    await coreLiquid.deployed();
    console.log("✅ CoreLiquid deployed to:", coreLiquid.address);

    // Deploy LiquidityPool
    console.log("📄 Deploying LiquidityPool...");
    const LiquidityPool = await ethers.getContractFactory("LiquidityPool");
    const liquidityPool = await LiquidityPool.deploy(
        coreToken.address,
        oracle.address
    );
    await liquidityPool.deployed();
    console.log("✅ LiquidityPool deployed to:", liquidityPool.address);

    // Setup initial liquidity
    console.log("💧 Setting up initial liquidity...");
    const initialLiquidity = ethers.utils.parseEther("10000");
    await coreToken.approve(liquidityPool.address, initialLiquidity);
    await liquidityPool.addLiquidity(initialLiquidity);
    console.log("✅ Initial liquidity added");

    console.log("\n🎉 Deployment Summary");
    console.log("=====================");
    console.log("Network: Core Testnet");
    console.log("Deployer:", deployer.address);
    console.log("CORE Token:", coreToken.address);
    console.log("BTC Token:", btcToken.address);
    console.log("Oracle:", oracle.address);
    console.log("CoreLiquid:", coreLiquid.address);
    console.log("LiquidityPool:", liquidityPool.address);
    
    console.log("\n📋 Verification Commands:");
    console.log("=========================");
    console.log(`npx hardhat verify --network core_testnet ${coreToken.address} "Core Token" "CORE" "${ethers.utils.parseEther("1000000")}"`); 
    console.log(`npx hardhat verify --network core_testnet ${btcToken.address} "Bitcoin Token" "BTC" "${ethers.utils.parseEther("21000")}"`); 
    console.log(`npx hardhat verify --network core_testnet ${oracle.address}`);
    console.log(`npx hardhat verify --network core_testnet ${coreLiquid.address} ${oracle.address} ${coreToken.address}`);
    console.log(`npx hardhat verify --network core_testnet ${liquidityPool.address} ${coreToken.address} ${oracle.address}`);
    
    console.log("\n🏆 Ready for Hackathon Submission!");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });