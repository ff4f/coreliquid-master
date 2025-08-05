const { ethers } = require("hardhat");
const fs = require('fs');

async function main() {
  console.log("🚀 Starting CoreLiquid Minimal Deployment...");
  
  // Get deployer
  const [deployer] = await ethers.getSigners();
  console.log("Deploying with account:", deployer.address);
  console.log("Account balance:", (await deployer.getBalance()).toString());
  
  try {
    // Deploy Oracle
    console.log("\n📊 Deploying Oracle...");
    const Oracle = await ethers.getContractFactory("Oracle");
    const oracle = await Oracle.deploy();
    await oracle.deployed();
    console.log("✅ Oracle deployed to:", oracle.address);
    
    // Deploy Test Tokens
    console.log("\n🪙 Deploying Test Tokens...");
    const SimpleToken = await ethers.getContractFactory("SimpleToken");
    
    const coreToken = await SimpleToken.deploy(
      "Core Liquid Token",
      "CORE",
      ethers.utils.parseEther("1000000")
    );
    await coreToken.deployed();
    console.log("✅ CORE Token deployed to:", coreToken.address);
    
    const btcToken = await SimpleToken.deploy(
      "Bitcoin Token",
      "BTC",
      ethers.utils.parseEther("21000")
    );
    await btcToken.deployed();
    console.log("✅ BTC Token deployed to:", btcToken.address);
    
    // Deploy CoreLiquid
    console.log("\n💧 Deploying CoreLiquid...");
    const CoreLiquid = await ethers.getContractFactory("CoreLiquid");
    const coreLiquid = await CoreLiquid.deploy(
      oracle.address,
      coreToken.address,
      btcToken.address
    );
    await coreLiquid.deployed();
    console.log("✅ CoreLiquid deployed to:", coreLiquid.address);
    
    // Deploy LiquidityPool
    console.log("\n🏊 Deploying LiquidityPool...");
    const LiquidityPool = await ethers.getContractFactory("LiquidityPool");
    const liquidityPool = await LiquidityPool.deploy(
      coreLiquid.address,
      coreToken.address,
      btcToken.address
    );
    await liquidityPool.deployed();
    console.log("✅ LiquidityPool deployed to:", liquidityPool.address);
    
    // Deploy DepositGuard (if available)
    let depositGuard;
    try {
      console.log("\n🛡️ Deploying DepositGuard...");
      const DepositGuard = await ethers.getContractFactory("DepositGuard");
      depositGuard = await DepositGuard.deploy(
        coreLiquid.address,
        oracle.address
      );
      await depositGuard.deployed();
      console.log("✅ DepositGuard deployed to:", depositGuard.address);
    } catch (error) {
      console.log("⚠️ DepositGuard deployment skipped:", error.message);
    }
    
    // Verification info
    console.log("\n" + "=".repeat(50));
    console.log("✅ DEPLOYMENT SUMMARY");
    console.log("=".repeat(50));
    console.log(`📊 Oracle: ${oracle.address}`);
    console.log(`🪙 CORE Token: ${coreToken.address}`);
    console.log(`🪙 BTC Token: ${btcToken.address}`);
    console.log(`💧 CoreLiquid: ${coreLiquid.address}`);
    console.log(`🏊 LiquidityPool: ${liquidityPool.address}`);
    if (depositGuard) {
      console.log(`🛡️ DepositGuard: ${depositGuard.address}`);
    }
    console.log("=".repeat(50));
    
    // Save deployment info
    const deploymentInfo = {
      network: network.name,
      chainId: network.config.chainId,
      timestamp: new Date().toISOString(),
      deployer: deployer.address,
      contracts: {
        oracle: oracle.address,
        coreToken: coreToken.address,
        btcToken: btcToken.address,
        coreLiquid: coreLiquid.address,
        liquidityPool: liquidityPool.address,
        ...(depositGuard && { depositGuard: depositGuard.address })
      },
      gasUsed: {
        oracle: (await oracle.deployTransaction.wait()).gasUsed.toString(),
        coreToken: (await coreToken.deployTransaction.wait()).gasUsed.toString(),
        btcToken: (await btcToken.deployTransaction.wait()).gasUsed.toString(),
        coreLiquid: (await coreLiquid.deployTransaction.wait()).gasUsed.toString(),
        liquidityPool: (await liquidityPool.deployTransaction.wait()).gasUsed.toString()
      }
    };
    
    const filename = `deployment-${network.name}-${Date.now()}.json`;
    fs.writeFileSync(filename, JSON.stringify(deploymentInfo, null, 2));
    console.log(`\n📄 Deployment info saved to ${filename}`);
    
    // Basic setup
    console.log("\n🔧 Setting up basic configuration...");
    
    // Set oracle prices
    await oracle.setPrice(coreToken.address, ethers.utils.parseEther("1")); // 1 USD
    await oracle.setPrice(btcToken.address, ethers.utils.parseEther("50000")); // 50,000 USD
    console.log("✅ Oracle prices set");
    
    // Transfer some tokens to CoreLiquid for initial liquidity
    const initialLiquidity = ethers.utils.parseEther("10000");
    await coreToken.transfer(coreLiquid.address, initialLiquidity);
    await btcToken.transfer(coreLiquid.address, ethers.utils.parseEther("1"));
    console.log("✅ Initial liquidity transferred");
    
    console.log("\n🎉 Minimal deployment completed successfully!");
    console.log("\n📋 Next steps:");
    console.log("1. Verify contracts on block explorer");
    console.log("2. Run test script: npx hardhat run scripts/test-deployment.js");
    console.log("3. Interact with contracts via frontend or scripts");
    
  } catch (error) {
    console.error("\n❌ Deployment failed:", error);
    process.exit(1);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });