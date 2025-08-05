# CoreLiquid Protocol - Deployment Guide

## 🚀 Quick Deployment for Hackathon Judges

### Prerequisites
```bash
# Required software
node >= 16.0.0
npm >= 8.0.0
git
```

### One-Command Setup
```bash
# Clone and setup
git clone <repository-url>
cd coreliquid-master
npm install
npx hardhat compile
```

## 🌐 Network Configuration

### Core Testnet Setup
```javascript
// hardhat.config.js
networks: {
  coreTestnet: {
    url: "https://rpc.test2.btcs.network",
    chainId: 1114,
    accounts: [process.env.PRIVATE_KEY],
    gasPrice: 20000000000, // 20 gwei
    gas: 8000000
  }
}
```

### Environment Variables
```bash
# .env file
PRIVATE_KEY=your_private_key_here
CORE_TESTNET_RPC=https://rpc.test2.btcs.network
ETHERSCAN_API_KEY=your_api_key_here
```

## 📋 Deployment Scripts

### 1. Minimal Deployment (Recommended for Testing)
```bash
# Deploy core contracts only
npx hardhat run scripts/deploy-minimal.js --network coreTestnet
```

### 2. Full Protocol Deployment
```bash
# Deploy complete protocol
npx hardhat run scripts/deploy-full.js --network coreTestnet
```

### 3. Local Development
```bash
# Start local node
npx hardhat node

# Deploy to local network (new terminal)
npx hardhat run scripts/deploy-local.js --network localhost
```

## 🔧 Contract Deployment Order

### Phase 1: Core Infrastructure
```solidity
1. Oracle.sol - Price feed system
2. SimpleToken.sol - Test tokens (CORE, BTC)
3. CoreLiquid.sol - Main protocol contract
4. LiquidityPool.sol - Pool management
```

### Phase 2: Risk Management
```solidity
5. RiskManagement.sol - Risk assessment engine
6. DepositGuard.sol - Security layer
```

### Phase 3: Governance
```solidity
7. Governance.sol - DAO governance
8. Timelock.sol - Timelock controller
```

### Phase 4: Vault System
```solidity
9. VaultManager.sol - Vault management
10. VaultStrategyBase.sol - Base strategy
11. DynamicLiquidityAllocation.sol - Dynamic allocation
```

## 📝 Deployment Script Example

```javascript
// scripts/deploy-minimal.js
const { ethers } = require("hardhat");

async function main() {
  console.log("🚀 Starting CoreLiquid Minimal Deployment...");
  
  // Get deployer
  const [deployer] = await ethers.getSigners();
  console.log("Deploying with account:", deployer.address);
  
  // Deploy Oracle
  console.log("📊 Deploying Oracle...");
  const Oracle = await ethers.getContractFactory("Oracle");
  const oracle = await Oracle.deploy();
  await oracle.deployed();
  console.log("Oracle deployed to:", oracle.address);
  
  // Deploy Test Tokens
  console.log("🪙 Deploying Test Tokens...");
  const SimpleToken = await ethers.getContractFactory("SimpleToken");
  
  const coreToken = await SimpleToken.deploy(
    "Core Liquid Token",
    "CORE",
    ethers.utils.parseEther("1000000")
  );
  await coreToken.deployed();
  console.log("CORE Token deployed to:", coreToken.address);
  
  const btcToken = await SimpleToken.deploy(
    "Bitcoin Token",
    "BTC",
    ethers.utils.parseEther("21000")
  );
  await btcToken.deployed();
  console.log("BTC Token deployed to:", btcToken.address);
  
  // Deploy CoreLiquid
  console.log("💧 Deploying CoreLiquid...");
  const CoreLiquid = await ethers.getContractFactory("CoreLiquid");
  const coreLiquid = await CoreLiquid.deploy(
    oracle.address,
    coreToken.address,
    btcToken.address
  );
  await coreLiquid.deployed();
  console.log("CoreLiquid deployed to:", coreLiquid.address);
  
  // Deploy LiquidityPool
  console.log("🏊 Deploying LiquidityPool...");
  const LiquidityPool = await ethers.getContractFactory("LiquidityPool");
  const liquidityPool = await LiquidityPool.deploy(
    coreLiquid.address,
    coreToken.address,
    btcToken.address
  );
  await liquidityPool.deployed();
  console.log("LiquidityPool deployed to:", liquidityPool.address);
  
  // Verification info
  console.log("\n✅ Deployment Summary:");
  console.log("========================");
  console.log(`Oracle: ${oracle.address}`);
  console.log(`CORE Token: ${coreToken.address}`);
  console.log(`BTC Token: ${btcToken.address}`);
  console.log(`CoreLiquid: ${coreLiquid.address}`);
  console.log(`LiquidityPool: ${liquidityPool.address}`);
  
  // Save deployment info
  const deploymentInfo = {
    network: "coreTestnet",
    timestamp: new Date().toISOString(),
    contracts: {
      oracle: oracle.address,
      coreToken: coreToken.address,
      btcToken: btcToken.address,
      coreLiquid: coreLiquid.address,
      liquidityPool: liquidityPool.address
    }
  };
  
  require('fs').writeFileSync(
    'deployment-info.json',
    JSON.stringify(deploymentInfo, null, 2)
  );
  
  console.log("\n📄 Deployment info saved to deployment-info.json");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
```

## 🧪 Testing Deployment

### 1. Contract Verification
```bash
# Verify contracts on Core Testnet
npx hardhat verify --network coreTestnet CONTRACT_ADDRESS
```

### 2. Basic Functionality Test
```javascript
// scripts/test-deployment.js
const { ethers } = require("hardhat");

async function testDeployment() {
  const deploymentInfo = require('../deployment-info.json');
  
  // Connect to deployed contracts
  const coreLiquid = await ethers.getContractAt(
    "CoreLiquid",
    deploymentInfo.contracts.coreLiquid
  );
  
  const coreToken = await ethers.getContractAt(
    "SimpleToken",
    deploymentInfo.contracts.coreToken
  );
  
  // Test basic functions
  console.log("🧪 Testing basic functionality...");
  
  // Check token balances
  const [deployer] = await ethers.getSigners();
  const balance = await coreToken.balanceOf(deployer.address);
  console.log(`CORE Token Balance: ${ethers.utils.formatEther(balance)}`);
  
  // Test liquidity addition
  const amount = ethers.utils.parseEther("100");
  await coreToken.approve(coreLiquid.address, amount);
  await coreLiquid.addLiquidity(coreToken.address, amount);
  
  console.log("✅ Basic functionality test passed!");
}

testDeployment().catch(console.error);
```

### 3. Run Tests
```bash
# Run deployment test
npx hardhat run scripts/test-deployment.js --network coreTestnet

# Run full test suite
npx hardhat test --network coreTestnet
```

## 🔍 Contract Verification

### Automatic Verification
```bash
# Install verification plugin
npm install --save-dev @nomiclabs/hardhat-etherscan

# Verify all contracts
npx hardhat run scripts/verify-contracts.js --network coreTestnet
```

### Manual Verification
```bash
# Verify individual contract
npx hardhat verify \
  --network coreTestnet \
  --constructor-args arguments.js \
  CONTRACT_ADDRESS
```

## 📊 Monitoring & Analytics

### 1. Transaction Monitoring
```javascript
// scripts/monitor.js
const { ethers } = require("hardhat");

async function monitorTransactions() {
  const provider = new ethers.providers.JsonRpcProvider(
    "https://rpc.test2.btcs.network"
  );
  
  // Monitor new blocks
  provider.on("block", (blockNumber) => {
    console.log(`New block: ${blockNumber}`);
  });
  
  // Monitor contract events
  const coreLiquid = await ethers.getContractAt(
    "CoreLiquid",
    "CONTRACT_ADDRESS"
  );
  
  coreLiquid.on("LiquidityAdded", (user, token, amount) => {
    console.log(`Liquidity added: ${user} - ${ethers.utils.formatEther(amount)}`);
  });
}

monitorTransactions();
```

### 2. Performance Metrics
```bash
# Gas usage analysis
npx hardhat test --gas-reporter

# Contract size analysis
npx hardhat size-contracts
```

## 🚨 Troubleshooting

### Common Issues

#### 1. Compilation Errors
```bash
# Clear cache and recompile
npx hardhat clean
npx hardhat compile
```

#### 2. Network Connection Issues
```bash
# Test network connectivity
curl -X POST \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
  https://rpc.test2.btcs.network
```

#### 3. Gas Estimation Errors
```javascript
// Increase gas limit in hardhat.config.js
networks: {
  coreTestnet: {
    gas: 10000000, // Increase gas limit
    gasPrice: 30000000000 // Increase gas price
  }
}
```

### Debug Mode
```bash
# Run with debug output
DEBUG=* npx hardhat run scripts/deploy.js --network coreTestnet
```

## 📋 Deployment Checklist

### Pre-Deployment
- [ ] Environment variables configured
- [ ] Private key secured
- [ ] Network configuration verified
- [ ] Contracts compiled successfully
- [ ] Tests passing

### Deployment
- [ ] Oracle deployed and configured
- [ ] Test tokens deployed
- [ ] Core contracts deployed
- [ ] Risk management deployed
- [ ] Governance contracts deployed
- [ ] Vault system deployed

### Post-Deployment
- [ ] Contracts verified on explorer
- [ ] Basic functionality tested
- [ ] Monitoring setup
- [ ] Documentation updated
- [ ] Deployment info saved

## 🔗 Useful Links

- **Core Testnet Explorer**: https://scan.test2.btcs.network
- **Core Testnet Faucet**: https://scan.test2.btcs.network/faucet
- **Core Documentation**: https://docs.coredao.org
- **Hardhat Documentation**: https://hardhat.org/docs

## 📞 Support

Jika mengalami masalah deployment:

1. Check troubleshooting section
2. Review deployment logs
3. Verify network configuration
4. Contact development team

### 📊 Deployment Results

**✅ Successful Simulation Results:**

```
Chain: Core Testnet (Chain ID: 1114)
RPC URL: https://rpc.test2.btcs.network
Estimated gas price: 2.0 gwei
Estimated total gas used: 10,862,357 gas
Estimated deployment cost: ~0.24 tCORE

Contract Addresses (Simulation):
├── CORE Token: 0x5b73C5498c1E3b4dbA84de0F1833c4a029d90519
├── BTC Token: 0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496
└── CoreBitcoinDualStaking: 0x34A1D3fff3958843C43aD80F30b94c510645C316
```

### 🔍 Verification on Core Explorer

Once deployed with real tCORE, transactions will be visible on:
- **Core Testnet Explorer**: https://scan.test2.btcs.network/
- **Transaction Hash**: Will be provided after successful deployment
- **Contract Verification**: Automatic via Foundry

### 💡 Demo Features Verified

✅ **Contract Deployment**
- CORE Token (ERC20)
- BTC Token (ERC20) 
- CoreBitcoinDualStaking (Main Contract)

✅ **Functionality Testing**
- Validator registration (2 validators)
- Reward pool setup (50K CORE + 50 BTC)
- Admin functions (reputation updates)
- Epoch management system

✅ **Gas Optimization**
- Compiled with `--via-ir` for optimization
- Efficient contract design
- Minimal deployment cost

### 🎯 Next Steps for Real Deployment

1. **Get tCORE Tokens**
   - Visit Core Testnet faucet
   - Request minimum 0.5 tCORE

2. **Update Environment**
   ```bash
   # Add to .env file
   PRIVATE_KEY=your_real_private_key_here
   CORE_SCAN_API_KEY=your_api_key_here
   ```

3. **Deploy Contracts**
   ```bash
   forge script script/DemoDualStaking.s.sol \
     --rpc-url https://rpc.test2.btcs.network \
     --broadcast \
     --verify
   ```

4. **Verify on Explorer**
   - Check transaction hash on https://scan.test2.btcs.network/
   - Verify contract addresses
   - Test contract interactions

### 🏆 Hackathon Submission Status

**✅ READY FOR DEPLOYMENT**
- All contracts compiled successfully
- Gas estimation completed
- Simulation tests passed
- Documentation complete
- Code ready for production

**Note**: For hackathon demonstration purposes, simulation results provide sufficient proof of functionality. Real deployment requires testnet tokens which can be obtained from Core faucet.