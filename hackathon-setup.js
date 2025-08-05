#!/usr/bin/env node

/**
 * CoreLiquid Hackathon Master Setup Script
 * Script lengkap untuk setup, testing, dan deployment hackathon
 */

const fs = require('fs');
const path = require('path');
const readline = require('readline');
const { execSync, spawn } = require('child_process');

class HackathonSetup {
  constructor() {
    this.projectRoot = __dirname;
    this.rl = readline.createInterface({
      input: process.stdin,
      output: process.stdout
    });
  }

  printWelcome() {
    console.log('\n🏆 ===== CORELIQUID HACKATHON SETUP =====');
    console.log('🎯 Core Connect Global Buildathon');
    console.log('🌐 https://dorahacks.io/hackathon/core-connect-global-buildathon\n');
    
    console.log('🚀 FITUR UTAMA CoreLiquid:');
    console.log('   💧 True Unified Liquidity Layer (TULL)');
    console.log('   🥩 Core Bitcoin Dual Staking');
    console.log('   🏦 Fixed-Cost Lending System');
    console.log('   🔄 Cross-Chain Asset Management');
    console.log('   📊 Real-time Portfolio Analytics\n');
    
    console.log('🎪 DEMO YANG AKAN DIBUAT:');
    console.log('   ✅ UI/UX dengan real wallet connection');
    console.log('   ✅ Real transactions di Core Testnet');
    console.log('   ✅ Live deployment di Vercel');
    console.log('   ✅ Complete documentation\n');
  }

  async askQuestion(question) {
    return new Promise((resolve) => {
      this.rl.question(question, resolve);
    });
  }

  async setupWalletConnect() {
    console.log('\n🔗 ===== WALLETCONNECT SETUP =====');
    console.log('\n📱 Untuk testing UI/UX, kita perlu WalletConnect Project ID');
    console.log('\n📋 LANGKAH-LANGKAH:');
    console.log('1. Buka: https://cloud.walletconnect.com/');
    console.log('2. Buat akun atau login');
    console.log('3. Klik "Create Project"');
    console.log('4. Nama project: "CoreLiquid Protocol"');
    console.log('5. Copy Project ID\n');
    
    const hasProjectId = await this.askQuestion('❓ Sudah punya WalletConnect Project ID? (y/N): ');
    
    if (hasProjectId.toLowerCase() === 'y') {
      const projectId = await this.askQuestion('🔑 Masukkan Project ID: ');
      
      if (projectId.trim()) {
        this.updateEnvWithWalletConnect(projectId.trim());
        console.log('✅ WalletConnect Project ID berhasil disimpan!');
        return true;
      }
    }
    
    console.log('\n⚠️  Silakan setup WalletConnect Project ID dulu.');
    console.log('   Jalankan: node setup-walletconnect.js');
    return false;
  }

  updateEnvWithWalletConnect(projectId) {
    const envPath = path.join(this.projectRoot, '.env');
    
    try {
      let envContent = fs.readFileSync(envPath, 'utf8');
      
      if (envContent.includes('NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID=')) {
        envContent = envContent.replace(
          /NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID=.*/,
          `NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID=${projectId}`
        );
      } else {
        envContent += `\nNEXT_PUBLIC_WALLETCONNECT_PROJECT_ID=${projectId}\n`;
      }
      
      fs.writeFileSync(envPath, envContent);
      
    } catch (error) {
      console.log('⚠️  Creating new .env file...');
      const newEnvContent = `NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID=${projectId}\n`;
      fs.writeFileSync(envPath, newEnvContent);
    }
  }

  checkCoreTestnetSetup() {
    console.log('\n💰 ===== CORE TESTNET SETUP =====');
    console.log('\n🌐 Core Testnet Details:');
    console.log('   Chain ID: 1114');
    console.log('   RPC URL: https://rpc.test2.btcs.network');
    console.log('   Explorer: https://scan.test2.btcs.network');
    console.log('   Faucet: https://scan.test2.btcs.network/faucet\n');
    
    console.log('📱 SETUP METAMASK:');
    console.log('1. Buka MetaMask');
    console.log('2. Add Network > Add network manually');
    console.log('3. Network Name: Core Testnet');
    console.log('4. RPC URL: https://rpc.test2.btcs.network');
    console.log('5. Chain ID: 1114');
    console.log('6. Currency Symbol: tCORE');
    console.log('7. Block Explorer: https://scan.test2.btcs.network\n');
    
    console.log('💰 GET TEST TOKENS:');
    console.log('1. Buka: https://scan.test2.btcs.network/faucet');
    console.log('2. Connect wallet');
    console.log('3. Request tCORE tokens');
    console.log('4. Wait for confirmation\n');
  }

  async runUITesting() {
    console.log('\n🧪 ===== UI/UX TESTING =====');
    
    const startTesting = await this.askQuestion('🚀 Start UI/UX testing sekarang? (y/N): ');
    
    if (startTesting.toLowerCase() === 'y') {
      console.log('\n🔄 Starting development server...');
      
      try {
        // Install dependencies if needed
        if (!fs.existsSync(path.join(this.projectRoot, 'node_modules'))) {
          console.log('📦 Installing dependencies...');
          execSync('npm install', { stdio: 'inherit', cwd: this.projectRoot });
        }
        
        // Start dev server
        console.log('🚀 Starting Next.js development server...');
        const serverProcess = spawn('npm', ['run', 'dev'], {
          cwd: this.projectRoot,
          stdio: 'inherit',
          detached: true
        });
        
        console.log('\n✅ Development server started!');
        console.log('🌐 URL: http://localhost:3000');
        console.log('\n📋 TESTING CHECKLIST:');
        console.log('□ Connect wallet ke Core Testnet');
        console.log('□ Test staking features');
        console.log('□ Test liquidity features');
        console.log('□ Test swap functionality');
        console.log('□ Verify real transactions');
        console.log('□ Screenshot untuk dokumentasi\n');
        
        return true;
        
      } catch (error) {
        console.error('❌ Failed to start testing:', error.message);
        return false;
      }
    }
    
    return false;
  }

  async setupVercelDeployment() {
    console.log('\n🚀 ===== VERCEL DEPLOYMENT SETUP =====');
    
    const setupDeployment = await this.askQuestion('🌐 Setup Vercel deployment? (y/N): ');
    
    if (setupDeployment.toLowerCase() === 'y') {
      console.log('\n📋 VERCEL PREREQUISITES:');
      console.log('1. Vercel account: https://vercel.com');
      console.log('2. GitHub repository dengan branch "advantage"');
      console.log('3. Environment variables ready\n');
      
      const hasVercelAccount = await this.askQuestion('✅ Sudah punya Vercel account? (y/N): ');
      
      if (hasVercelAccount.toLowerCase() === 'y') {
        console.log('\n🔧 Creating Vercel configuration...');
        
        // Create vercel.json
        const vercelConfig = {
          "name": "coreliquid-protocol",
          "framework": "nextjs",
          "buildCommand": "npm run build",
          "env": {
            "NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID": "@walletconnect_project_id",
            "NEXT_PUBLIC_ENVIRONMENT": "production"
          }
        };
        
        fs.writeFileSync(
          path.join(this.projectRoot, 'vercel.json'),
          JSON.stringify(vercelConfig, null, 2)
        );
        
        console.log('✅ vercel.json created');
        
        console.log('\n📝 DEPLOYMENT STEPS:');
        console.log('1. git checkout advantage');
        console.log('2. git add .');
        console.log('3. git commit -m "feat: ready for deployment"');
        console.log('4. git push origin advantage');
        console.log('5. vercel --prod');
        console.log('\n💡 Atau jalankan: node deploy-vercel.js\n');
        
        return true;
      }
    }
    
    return false;
  }

  printHackathonSubmission() {
    console.log('\n🏆 ===== HACKATHON SUBMISSION =====');
    console.log('\n📝 SUBMISSION CHECKLIST:');
    console.log('□ Live demo URL (Vercel)');
    console.log('□ GitHub repository link');
    console.log('□ Demo video (5 minutes)');
    console.log('□ Documentation lengkap');
    console.log('□ Real transaction proofs');
    console.log('□ Technical architecture explanation\n');
    
    console.log('🎯 JUDGING CRITERIA:');
    console.log('1. 💡 Innovation & Creativity');
    console.log('2. 🛠️  Technical Implementation');
    console.log('3. 🎨 User Experience');
    console.log('4. 🌐 Core Chain Integration');
    console.log('5. 📊 Business Potential\n');
    
    console.log('🔗 SUBMISSION LINKS:');
    console.log('   🏆 Hackathon: https://dorahacks.io/hackathon/core-connect-global-buildathon');
    console.log('   📚 Judging Criteria: https://dorahacks.io/hackathon/core-connect-global-buildathon/judging-criteria');
    console.log('   💡 Inspiration: https://github.com/coredao-org/core-community-contributions/issues/24\n');
  }

  printFinalInstructions() {
    console.log('\n🎉 ===== SETUP COMPLETED! =====');
    console.log('\n🚀 NEXT ACTIONS:');
    console.log('\n1. 🧪 UI/UX TESTING:');
    console.log('   node test-ui-ux.js');
    console.log('   # Test semua fitur dengan real wallet\n');
    
    console.log('2. 🌐 VERCEL DEPLOYMENT:');
    console.log('   node deploy-vercel.js');
    console.log('   # Deploy ke production\n');
    
    console.log('3. 📹 DEMO RECORDING:');
    console.log('   - Record 5-minute demo video');
    console.log('   - Show real transactions');
    console.log('   - Explain technical features\n');
    
    console.log('4. 📝 HACKATHON SUBMISSION:');
    console.log('   - Submit di DoraHacks platform');
    console.log('   - Include live URL & GitHub repo');
    console.log('   - Upload demo video\n');
    
    console.log('🏆 SIAP MENANG HACKATHON! 🏆');
    console.log('\n💪 CoreLiquid: Revolutionizing DeFi on Core Chain!');
    console.log('🌟 True Unified Liquidity Layer untuk Bitcoin & Core\n');
  }

  async run() {
    try {
      this.printWelcome();
      
      // Setup WalletConnect
      const walletConnectReady = await this.setupWalletConnect();
      if (!walletConnectReady) {
        console.log('\n⏸️  Setup dihentikan. Jalankan lagi setelah setup WalletConnect.');
        this.rl.close();
        return;
      }
      
      // Check Core Testnet setup
      this.checkCoreTestnetSetup();
      
      const continueSetup = await this.askQuestion('✅ Core Testnet sudah ready? (y/N): ');
      if (continueSetup.toLowerCase() !== 'y') {
        console.log('\n⏸️  Setup Core Testnet dulu, lalu jalankan script ini lagi.');
        this.rl.close();
        return;
      }
      
      // UI Testing
      await this.runUITesting();
      
      // Vercel Deployment
      await this.setupVercelDeployment();
      
      // Final instructions
      this.printHackathonSubmission();
      this.printFinalInstructions();
      
      this.rl.close();
      
    } catch (error) {
      console.error('❌ Setup failed:', error.message);
      this.rl.close();
      process.exit(1);
    }
  }
}

// Run if called directly
if (require.main === module) {
  const setup = new HackathonSetup();
  setup.run();
}

module.exports = HackathonSetup;