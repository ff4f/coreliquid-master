#!/usr/bin/env node

/**
 * CoreLiquid UI/UX Testing Script
 * Script otomatis untuk testing semua fitur UI/UX dengan real wallet
 */

const fs = require('fs');
const path = require('path');
const { execSync, spawn } = require('child_process');

class CoreLiquidTester {
  constructor() {
    this.envPath = path.join(__dirname, '.env');
    this.testResults = [];
    this.serverProcess = null;
  }

  printHeader() {
    console.log('\n🧪 ===== CoreLiquid UI/UX Testing Suite =====');
    console.log('🎯 Testing semua fitur dengan real wallet & transactions\n');
  }

  checkPrerequisites() {
    console.log('📋 Checking Prerequisites...');
    
    // Check .env file
    if (!fs.existsSync(this.envPath)) {
      throw new Error('❌ File .env tidak ditemukan! Jalankan setup-walletconnect.js dulu.');
    }
    
    const envContent = fs.readFileSync(this.envPath, 'utf8');
    
    // Check critical environment variables
    const requiredVars = [
      'PRIVATE_KEY',
      'NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID',
      'CORE_TESTNET_RPC_URL'
    ];
    
    const missingVars = requiredVars.filter(varName => 
      !envContent.includes(`${varName}=`) || 
      envContent.match(new RegExp(`${varName}=\\s*$`, 'm'))
    );
    
    if (missingVars.length > 0) {
      throw new Error(`❌ Environment variables tidak lengkap: ${missingVars.join(', ')}`);
    }
    
    console.log('✅ Environment variables OK');
    
    // Check node_modules
    if (!fs.existsSync(path.join(__dirname, 'node_modules'))) {
      console.log('📦 Installing dependencies...');
      execSync('npm install', { stdio: 'inherit', cwd: __dirname });
    }
    
    console.log('✅ Dependencies OK');
  }

  async startDevServer() {
    console.log('\n🚀 Starting Development Server...');
    
    return new Promise((resolve, reject) => {
      this.serverProcess = spawn('npm', ['run', 'dev'], {
        cwd: __dirname,
        stdio: ['pipe', 'pipe', 'pipe']
      });
      
      let output = '';
      
      this.serverProcess.stdout.on('data', (data) => {
        output += data.toString();
        process.stdout.write(data);
        
        // Check if server is ready
        if (output.includes('Ready in') || output.includes('Local:')) {
          console.log('\n✅ Development server started successfully!');
          console.log('🌐 URL: http://localhost:3000');
          resolve();
        }
      });
      
      this.serverProcess.stderr.on('data', (data) => {
        console.error(data.toString());
      });
      
      this.serverProcess.on('error', (error) => {
        reject(new Error(`❌ Failed to start server: ${error.message}`));
      });
      
      // Timeout after 60 seconds
      setTimeout(() => {
        if (!output.includes('Ready in')) {
          reject(new Error('❌ Server startup timeout'));
        }
      }, 60000);
    });
  }

  printTestingInstructions() {
    console.log('\n🎯 ===== MANUAL UI/UX TESTING CHECKLIST =====');
    console.log('\n📱 1. WALLET CONNECTION:');
    console.log('   □ Klik "Connect Wallet"');
    console.log('   □ Pilih MetaMask atau WalletConnect');
    console.log('   □ Pastikan terhubung ke Core Testnet (Chain ID: 1114)');
    console.log('   □ Verify wallet address muncul di UI\n');
    
    console.log('💰 2. DASHBOARD TESTING:');
    console.log('   □ Check balance CORE dan BTC tokens');
    console.log('   □ Verify portfolio overview');
    console.log('   □ Check APY rates display');
    console.log('   □ Test refresh data functionality\n');
    
    console.log('🥩 3. STAKING FEATURES:');
    console.log('   □ Navigate ke Staking page');
    console.log('   □ Test CORE Native Staking');
    console.log('   □ Test Dual Staking (CORE + BTC)');
    console.log('   □ Verify staking rewards calculation');
    console.log('   □ Test unstaking functionality\n');
    
    console.log('💧 4. LIQUIDITY FEATURES:');
    console.log('   □ Navigate ke Liquidity page');
    console.log('   □ Test Add Liquidity (CORE/BTC)');
    console.log('   □ Test Remove Liquidity');
    console.log('   □ Check LP token balance');
    console.log('   □ Verify liquidity rewards\n');
    
    console.log('🏦 5. LENDING/BORROWING:');
    console.log('   □ Navigate ke Lending page');
    console.log('   □ Test Deposit CORE/BTC');
    console.log('   □ Test Borrow against collateral');
    console.log('   □ Check interest rates');
    console.log('   □ Test repayment functionality\n');
    
    console.log('🔄 6. SWAP FUNCTIONALITY:');
    console.log('   □ Navigate ke Swap page');
    console.log('   □ Test CORE ↔ BTC swap');
    console.log('   □ Check slippage settings');
    console.log('   □ Verify swap rates');
    console.log('   □ Execute real swap transaction\n');
    
    console.log('📊 7. PORTFOLIO MANAGEMENT:');
    console.log('   □ Check positions overview');
    console.log('   □ Verify transaction history');
    console.log('   □ Test export functionality');
    console.log('   □ Check profit/loss calculations\n');
  }

  printTransactionVerification() {
    console.log('🔍 ===== TRANSACTION VERIFICATION =====');
    console.log('\n📝 Untuk setiap transaksi yang dilakukan:');
    console.log('1. 📋 Copy transaction hash dari wallet');
    console.log('2. 🌐 Buka Core Testnet Explorer:');
    console.log('   https://scan.test2.btcs.network');
    console.log('3. 🔍 Paste transaction hash untuk verify');
    console.log('4. ✅ Confirm transaction status: Success');
    console.log('5. 📸 Screenshot untuk dokumentasi\n');
    
    console.log('🎯 TARGET TRANSACTIONS untuk Demo:');
    console.log('□ Wallet Connection');
    console.log('□ Token Approval (CORE/BTC)');
    console.log('□ Staking Transaction');
    console.log('□ Liquidity Addition');
    console.log('□ Lending/Deposit');
    console.log('□ Swap Transaction');
    console.log('□ Unstaking/Withdrawal\n');
  }

  printContractAddresses() {
    console.log('📋 ===== DEPLOYED CONTRACT ADDRESSES =====');
    console.log('\n🌐 Core Testnet (Chain ID: 1114):');
    console.log('\n💰 Token Contracts:');
    console.log('   CORE Liquid: 0xcAc1f956DE2B60059971cC8CeE12aC11B5295E0a');
    console.log('   BTC Token:   0xC515E6030cC331Be138E9FE011ce23dd6eA0c9d6\n');
    
    console.log('🏗️ Core Protocol:');
    console.log('   Simple TULL:     0x0B306BF915C4d645ff596e518fAf3F9669b97016');
    console.log('   Optimized TULL:  0xc6e7DF5E7b4f2A278906862b61205850344D4e7d');
    console.log('   Native Staking:  0xDB8cFf278adCCF9E9b5da745B44E754fC4EE3C76');
    console.log('   stCORE Token:    0xBb2180ebd78ce97360503434eD37fcf4a1Df61c3\n');
    
    console.log('💧 Liquidity & DeFi:');
    console.log('   Liquidity Pool:  0x50EEf481cae4250d252Ae577A09bF514f224C6C4');
    console.log('   LP Token:        0x62c20Aa1e0272312BC100b4e23B4DC1Ed96dD7D1');
    console.log('   Revenue Model:   0xDEb1E9a6Be7Baf84208BB6E10aC9F9bbE1D70809');
    console.log('   Risk Engine:     0xD718d5A27a29FF1cD22403426084bA0d479869a0\n');
  }

  printHackathonDemo() {
    console.log('🏆 ===== HACKATHON DEMO SCRIPT =====');
    console.log('\n⏱️  5-MINUTE DEMO FLOW:');
    console.log('\n1. 🎬 INTRO (30s):');
    console.log('   "CoreLiquid - True Unified Liquidity Layer untuk Core Chain"');
    console.log('   "Menggabungkan Bitcoin & Core dalam satu protokol DeFi"\n');
    
    console.log('2. 🔗 WALLET CONNECTION (30s):');
    console.log('   - Connect MetaMask ke Core Testnet');
    console.log('   - Show wallet balance & network info\n');
    
    console.log('3. 🥩 DUAL STAKING DEMO (90s):');
    console.log('   - Navigate ke Staking page');
    console.log('   - Stake CORE tokens (real transaction)');
    console.log('   - Show staking rewards calculation');
    console.log('   - Verify transaction di Core Explorer\n');
    
    console.log('4. 💧 LIQUIDITY DEMO (90s):');
    console.log('   - Add CORE/BTC liquidity (real transaction)');
    console.log('   - Show LP token minting');
    console.log('   - Explain yield farming benefits\n');
    
    console.log('5. 🔄 SWAP DEMO (60s):');
    console.log('   - Swap CORE to BTC (real transaction)');
    console.log('   - Show price impact & slippage');
    console.log('   - Verify transaction success\n');
    
    console.log('6. 📊 PORTFOLIO OVERVIEW (30s):');
    console.log('   - Show complete portfolio');
    console.log('   - Transaction history');
    console.log('   - Total value locked (TVL)\n');
    
    console.log('7. 🎯 CLOSING (30s):');
    console.log('   "CoreLiquid memungkinkan Bitcoin holders mendapat yield"');
    console.log('   "Sambil tetap exposure ke Core ecosystem"\n');
  }

  async cleanup() {
    if (this.serverProcess) {
      console.log('\n🛑 Stopping development server...');
      this.serverProcess.kill('SIGTERM');
      
      // Wait for graceful shutdown
      await new Promise(resolve => {
        this.serverProcess.on('exit', resolve);
        setTimeout(resolve, 5000); // Force exit after 5s
      });
    }
  }

  async run() {
    try {
      this.printHeader();
      this.checkPrerequisites();
      await this.startDevServer();
      
      // Wait a bit for server to fully start
      await new Promise(resolve => setTimeout(resolve, 3000));
      
      this.printTestingInstructions();
      this.printTransactionVerification();
      this.printContractAddresses();
      this.printHackathonDemo();
      
      console.log('\n🎉 ===== TESTING ENVIRONMENT READY! =====');
      console.log('\n🌐 Frontend: http://localhost:3000');
      console.log('🔗 Core Testnet Explorer: https://scan.test2.btcs.network');
      console.log('💰 Get tCORE: https://scan.test2.btcs.network/faucet');
      console.log('\n⚡ Server akan tetap berjalan untuk testing...');
      console.log('📝 Tekan Ctrl+C untuk stop server\n');
      
      // Keep the process running
      process.on('SIGINT', async () => {
        console.log('\n\n👋 Stopping UI/UX testing...');
        await this.cleanup();
        console.log('✅ Testing session completed!');
        process.exit(0);
      });
      
      // Keep alive
      setInterval(() => {
        // Just keep the process running
      }, 1000);
      
    } catch (error) {
      console.error('❌ Testing failed:', error.message);
      await this.cleanup();
      process.exit(1);
    }
  }
}

// Run if called directly
if (require.main === module) {
  const tester = new CoreLiquidTester();
  tester.run();
}

module.exports = CoreLiquidTester;