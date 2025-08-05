const { run } = require("hardhat");
const fs = require('fs');

async function main() {
  console.log("🔍 Starting Contract Verification...");
  
  // Find the latest deployment file
  const files = fs.readdirSync('.')
    .filter(file => file.startsWith('deployment-') && file.endsWith('.json'))
    .sort((a, b) => {
      const timeA = parseInt(a.split('-').pop().replace('.json', ''));
      const timeB = parseInt(b.split('-').pop().replace('.json', ''));
      return timeB - timeA;
    });
  
  if (files.length === 0) {
    console.error("❌ No deployment file found. Please run deployment first.");
    process.exit(1);
  }
  
  const deploymentFile = files[0];
  console.log(`📄 Using deployment file: ${deploymentFile}`);
  
  const deploymentInfo = JSON.parse(fs.readFileSync(deploymentFile, 'utf8'));
  const contracts = deploymentInfo.contracts;
  
  console.log(`\n🌐 Network: ${deploymentInfo.network}`);
  console.log(`⏰ Deployment time: ${deploymentInfo.timestamp}`);
  
  const verificationResults = {
    timestamp: new Date().toISOString(),
    network: deploymentInfo.network,
    results: {}
  };
  
  // Verification functions
  async function verifyContract(name, address, constructorArgs = []) {
    console.log(`\n🔍 Verifying ${name} at ${address}...`);
    
    try {
      await run("verify:verify", {
        address: address,
        constructorArguments: constructorArgs,
      });
      
      console.log(`✅ ${name} verified successfully`);
      verificationResults.results[name] = {
        address: address,
        status: "success",
        constructorArgs: constructorArgs
      };
      
      return true;
    } catch (error) {
      if (error.message.includes("Already Verified")) {
        console.log(`✅ ${name} already verified`);
        verificationResults.results[name] = {
          address: address,
          status: "already_verified",
          constructorArgs: constructorArgs
        };
        return true;
      } else {
        console.error(`❌ ${name} verification failed:`, error.message);
        verificationResults.results[name] = {
          address: address,
          status: "failed",
          error: error.message,
          constructorArgs: constructorArgs
        };
        return false;
      }
    }
  }
  
  try {
    // Verify Oracle (no constructor args)
    await verifyContract("Oracle", contracts.oracle, []);
    
    // Wait between verifications to avoid rate limiting
    await new Promise(resolve => setTimeout(resolve, 2000));
    
    // Verify CORE Token
    await verifyContract("CORE Token", contracts.coreToken, [
      "Core Liquid Token",
      "CORE",
      "1000000000000000000000000" // 1M tokens in wei
    ]);
    
    await new Promise(resolve => setTimeout(resolve, 2000));
    
    // Verify BTC Token
    await verifyContract("BTC Token", contracts.btcToken, [
      "Bitcoin Token",
      "BTC",
      "21000000000000000000000" // 21K tokens in wei
    ]);
    
    await new Promise(resolve => setTimeout(resolve, 2000));
    
    // Verify CoreLiquid
    await verifyContract("CoreLiquid", contracts.coreLiquid, [
      contracts.oracle,
      contracts.coreToken,
      contracts.btcToken
    ]);
    
    await new Promise(resolve => setTimeout(resolve, 2000));
    
    // Verify LiquidityPool
    await verifyContract("LiquidityPool", contracts.liquidityPool, [
      contracts.coreLiquid,
      contracts.coreToken,
      contracts.btcToken
    ]);
    
    // Verify DepositGuard if it exists
    if (contracts.depositGuard) {
      await new Promise(resolve => setTimeout(resolve, 2000));
      await verifyContract("DepositGuard", contracts.depositGuard, [
        contracts.coreLiquid,
        contracts.oracle
      ]);
    }
    
    // Summary
    console.log("\n" + "=".repeat(60));
    console.log("🎉 VERIFICATION SUMMARY");
    console.log("=".repeat(60));
    
    let successCount = 0;
    let totalCount = 0;
    
    for (const [name, result] of Object.entries(verificationResults.results)) {
      totalCount++;
      const status = result.status === "success" || result.status === "already_verified" ? "✅" : "❌";
      const statusText = result.status === "success" ? "VERIFIED" : 
                        result.status === "already_verified" ? "ALREADY VERIFIED" : "FAILED";
      
      console.log(`${status} ${name}: ${statusText}`);
      console.log(`   Address: ${result.address}`);
      
      if (result.status === "success" || result.status === "already_verified") {
        successCount++;
      }
      
      if (result.error) {
        console.log(`   Error: ${result.error}`);
      }
      console.log("");
    }
    
    console.log(`📊 Success Rate: ${successCount}/${totalCount} contracts verified`);
    console.log("=".repeat(60));
    
    // Save verification results
    const resultsFile = `verification-results-${Date.now()}.json`;
    fs.writeFileSync(resultsFile, JSON.stringify(verificationResults, null, 2));
    console.log(`\n📄 Verification results saved to ${resultsFile}`);
    
    // Generate explorer links
    console.log("\n🔗 Block Explorer Links:");
    const explorerBase = deploymentInfo.network === "coreTestnet" ? 
      "https://scan.test2.btcs.network/address" : 
      "https://scan.coredao.org/address";
    
    for (const [name, address] of Object.entries(contracts)) {
      console.log(`${name}: ${explorerBase}/${address}`);
    }
    
    if (successCount === totalCount) {
      console.log("\n🎉 All contracts verified successfully!");
      console.log("🚀 Ready for hackathon submission!");
    } else {
      console.log(`\n⚠️ ${totalCount - successCount} contracts failed verification`);
      console.log("Check the error messages above for details");
    }
    
  } catch (error) {
    console.error("\n❌ Verification process failed:", error);
    verificationResults.error = error.message;
    
    // Save partial results
    const resultsFile = `verification-results-failed-${Date.now()}.json`;
    fs.writeFileSync(resultsFile, JSON.stringify(verificationResults, null, 2));
    console.log(`📄 Partial results saved to ${resultsFile}`);
    
    process.exit(1);
  }
}

main()
  .then(() => {
    console.log("\n✅ Verification process completed!");
    process.exit(0);
  })
  .catch((error) => {
    console.error("\n❌ Verification failed:", error);
    process.exit(1);
  });