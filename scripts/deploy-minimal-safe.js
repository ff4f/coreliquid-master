require('dotenv').config();
const { ethers } = require("hardhat");

async function main() {
    console.log("🚀 Deploying Minimal Safe Contracts to Core Testnet");
    console.log("==================================================\n");
    
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
        
        // Wait for confirmation
        await coreToken.deployTransaction.wait(2);
        console.log("✅ CORE Token confirmed");

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
        
        // Wait for confirmation
        await btcToken.deployTransaction.wait(2);
        console.log("✅ BTC Token confirmed");

        console.log("\n🎉 Deployment Summary");
        console.log("=====================");
        console.log("Network: Core Testnet");
        console.log("Chain ID: 1115");
        console.log("Deployer:", deployer.address);
        console.log("CORE Token:", coreToken.address);
        console.log("BTC Token:", btcToken.address);
        
        // Test token functionality
        console.log("\n🧪 Testing Token Functionality");
        console.log("==============================");
        
        const coreBalance = await coreToken.balanceOf(deployer.address);
        const btcBalance = await btcToken.balanceOf(deployer.address);
        
        console.log("CORE Balance:", ethers.utils.formatEther(coreBalance), "CORE");
        console.log("BTC Balance:", ethers.utils.formatEther(btcBalance), "BTC");
        
        // Test transfer
        const transferAmount = ethers.utils.parseEther("100");
        await coreToken.transfer("0x0000000000000000000000000000000000000001", transferAmount);
        console.log("✅ Transfer test successful");
        
        console.log("\n📋 Contract Verification Commands:");
        console.log("==================================");
        console.log(`npx hardhat verify --network coreTestnet ${coreToken.address} \"Core Token\" \"CORE\" \"${ethers.utils.parseEther("1000000")}\"`); 
        console.log(`npx hardhat verify --network coreTestnet ${btcToken.address} \"Bitcoin Token\" \"BTC\" \"${ethers.utils.parseEther("21000")}\"`); 
        
        console.log("\n🌐 Explorer Links:");
        console.log("==================");
        console.log(`CORE Token: https://scan.test.btcs.network/address/${coreToken.address}`);
        console.log(`BTC Token: https://scan.test.btcs.network/address/${btcToken.address}`);
        
        console.log("\n🏆 Minimal Deployment Successful!");
        console.log("Ready for Core Connect Global Buildathon!");
        
        // Save deployment info
        const deploymentInfo = {
            network: "Core Testnet",
            chainId: 1115,
            deployer: deployer.address,
            timestamp: new Date().toISOString(),
            contracts: {
                coreToken: {
                    address: coreToken.address,
                    name: "Core Token",
                    symbol: "CORE",
                    totalSupply: "1000000"
                },
                btcToken: {
                    address: btcToken.address,
                    name: "Bitcoin Token",
                    symbol: "BTC",
                    totalSupply: "21000"
                }
            }
        };
        
        console.log("\n📄 Deployment Info:");
        console.log(JSON.stringify(deploymentInfo, null, 2));
        
    } catch (error) {
        console.error("❌ Deployment failed:", error.message);
        if (error.transaction) {
            console.error("Transaction hash:", error.transaction.hash);
        }
        throw error;
    }
}

main()
    .then(() => {
        console.log("\n🎯 Deployment completed successfully!");
        process.exit(0);
    })
    .catch((error) => {
        console.error("\n💥 Deployment failed:", error);
        process.exit(1);
    });