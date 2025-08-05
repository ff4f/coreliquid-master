#!/usr/bin/env node

/**
 * CoreLiquid WalletConnect Setup Script
 * Membantu setup WalletConnect Project ID untuk testing UI/UX
 */

const fs = require('fs');
const path = require('path');
const readline = require('readline');

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

function printHeader() {
  console.log('\n🔗 ===== CoreLiquid WalletConnect Setup =====');
  console.log('📱 Setup WalletConnect untuk UI/UX Testing\n');
}

function printInstructions() {
  console.log('📋 LANGKAH-LANGKAH:');
  console.log('1. Buka https://cloud.walletconnect.com/');
  console.log('2. Buat akun baru atau login');
  console.log('3. Klik "Create Project"');
  console.log('4. Isi nama project: "CoreLiquid Protocol"');
  console.log('5. Copy Project ID yang diberikan');
  console.log('6. Paste di sini\n');
}

function updateEnvFile(projectId) {
  const envPath = path.join(__dirname, '.env');
  
  try {
    let envContent = fs.readFileSync(envPath, 'utf8');
    
    // Update WalletConnect Project ID
    if (envContent.includes('NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID=')) {
      envContent = envContent.replace(
        /NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID=.*/,
        `NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID=${projectId}`
      );
    } else {
      envContent += `\nNEXT_PUBLIC_WALLETCONNECT_PROJECT_ID=${projectId}\n`;
    }
    
    fs.writeFileSync(envPath, envContent);
    
    console.log('\n✅ File .env berhasil diupdate!');
    console.log(`🔑 WalletConnect Project ID: ${projectId}`);
    
  } catch (error) {
    console.error('❌ Error updating .env file:', error.message);
    
    // Create new .env entry
    const newEnvEntry = `\n# WalletConnect Configuration\nNEXT_PUBLIC_WALLETCONNECT_PROJECT_ID=${projectId}\n`;
    fs.appendFileSync(envPath, newEnvEntry);
    
    console.log('✅ WalletConnect Project ID ditambahkan ke .env');
  }
}

function validateProjectId(projectId) {
  // WalletConnect Project ID format validation
  const projectIdRegex = /^[a-f0-9]{32}$/;
  return projectIdRegex.test(projectId);
}

function createVercelEnvFile(projectId) {
  const vercelEnvContent = `# Vercel Environment Variables
# Copy these to Vercel Dashboard > Settings > Environment Variables

# CRITICAL - WalletConnect Project ID
NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID=${projectId}

# Core Blockchain Configuration
NEXT_PUBLIC_ENVIRONMENT=testnet
CORE_TESTNET_RPC_URL=https://rpc.test2.btcs.network
CORE_RPC_URL=https://rpc.coredao.org
CORE_TESTNET_CHAIN_ID=1114
CORE_MAINNET_CHAIN_ID=1116

# Real Deployed Contract Addresses (Core Testnet)
NEXT_PUBLIC_CORE_LIQUID_TOKEN=0xcAc1f956DE2B60059971cC8CeE12aC11B5295E0a
NEXT_PUBLIC_BTC_TOKEN=0xC515E6030cC331Be138E9FE011ce23dd6eA0c9d6
NEXT_PUBLIC_SIMPLE_TULL_ADDRESS=0x0B306BF915C4d645ff596e518fAf3F9669b97016
NEXT_PUBLIC_OPTIMIZED_TULL_ADDRESS=0xc6e7DF5E7b4f2A278906862b61205850344D4e7d
NEXT_PUBLIC_CORE_NATIVE_STAKING_ADDRESS=0xDB8cFf278adCCF9E9b5da745B44E754fC4EE3C76
NEXT_PUBLIC_STCORE_TOKEN_ADDRESS=0xBb2180ebd78ce97360503434eD37fcf4a1Df61c3
NEXT_PUBLIC_UNIFIED_LIQUIDITY_POOL_ADDRESS=0x50EEf481cae4250d252Ae577A09bF514f224C6C4
NEXT_PUBLIC_UNIFIED_LP_TOKEN_ADDRESS=0x62c20Aa1e0272312BC100b4e23B4DC1Ed96dD7D1
NEXT_PUBLIC_REVENUE_MODEL_ADDRESS=0xDEb1E9a6Be7Baf84208BB6E10aC9F9bbE1D70809
NEXT_PUBLIC_RISK_ENGINE_ADDRESS=0xD718d5A27a29FF1cD22403426084bA0d479869a0
NEXT_PUBLIC_DEPOSIT_MANAGER_ADDRESS=0x4f559F30f5eB88D635FDe1548C4267DB8FaB0351
NEXT_PUBLIC_CREDIT_MANAGER_ADDRESS=0x416C42991d05b31E9A6dC209e91AD22b79D87Ae6
NEXT_PUBLIC_CORE_LIQUID_PROTOCOL_ADDRESS=0x978e3286EB805934215a88694d80b09aDed68D90
NEXT_PUBLIC_APR_OPTIMIZER_ADDRESS=0xd21060559c9beb54fC07aFd6151aDf6cFCDDCAeB
NEXT_PUBLIC_POSITION_NFT_ADDRESS=0x4C52a6277b1B84121b3072C0c92b6Be0b7CC10F1

# WebSocket for real-time data
NEXT_PUBLIC_CORE_WS_URL=wss://ws.coredao.org
`;
  
  fs.writeFileSync(path.join(__dirname, '.env.vercel'), vercelEnvContent);
  console.log('📄 File .env.vercel dibuat untuk Vercel deployment');
}

function printNextSteps() {
  console.log('\n🚀 ===== LANGKAH SELANJUTNYA =====');
  console.log('\n1. 🧪 TEST UI/UX LOCALLY:');
  console.log('   npm run dev');
  console.log('   Buka: http://localhost:3000');
  console.log('   Connect wallet dan test semua fitur\n');
  
  console.log('2. 🌐 DEPLOY KE VERCEL:');
  console.log('   git checkout advantage');
  console.log('   git add .');
  console.log('   git commit -m "feat: setup walletconnect for deployment"');
  console.log('   git push origin advantage');
  console.log('   vercel --prod\n');
  
  console.log('3. 📊 SETUP VERCEL ENV VARS:');
  console.log('   - Copy semua variables dari .env.vercel');
  console.log('   - Paste di Vercel Dashboard > Settings > Environment Variables\n');
  
  console.log('4. 🎯 DEMO HACKATHON:');
  console.log('   - Test semua fitur di live URL');
  console.log('   - Buat real transactions di Core Testnet');
  console.log('   - Record demo video');
  console.log('   - Submit ke hackathon\n');
  
  console.log('✅ Setup selesai! Siap untuk hackathon! 🏆');
}

function main() {
  printHeader();
  printInstructions();
  
  rl.question('🔑 Masukkan WalletConnect Project ID: ', (projectId) => {
    projectId = projectId.trim();
    
    if (!projectId) {
      console.log('❌ Project ID tidak boleh kosong!');
      rl.close();
      return;
    }
    
    if (!validateProjectId(projectId)) {
      console.log('⚠️  Format Project ID mungkin tidak valid.');
      console.log('   Project ID biasanya 32 karakter hexadecimal.');
      console.log('   Contoh: a1b2c3d4e5f6789012345678901234ab');
      
      rl.question('\n❓ Lanjutkan anyway? (y/N): ', (confirm) => {
        if (confirm.toLowerCase() !== 'y') {
          console.log('❌ Setup dibatalkan.');
          rl.close();
          return;
        }
        
        updateEnvFile(projectId);
        createVercelEnvFile(projectId);
        printNextSteps();
        rl.close();
      });
    } else {
      updateEnvFile(projectId);
      createVercelEnvFile(projectId);
      printNextSteps();
      rl.close();
    }
  });
}

if (require.main === module) {
  main();
}

module.exports = {
  updateEnvFile,
  validateProjectId,
  createVercelEnvFile
};