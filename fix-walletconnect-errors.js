#!/usr/bin/env node

/**
 * Fix WalletConnect Errors Script
 * Solves common WalletConnect and contract interaction issues
 */

const fs = require('fs');
const path = require('path');

console.log('🔧 CoreLiquid - Fixing WalletConnect & Contract Errors');
console.log('=' .repeat(60));

// Check if .env file exists
const envPath = path.join(process.cwd(), '.env');
if (!fs.existsSync(envPath)) {
  console.error('❌ .env file not found!');
  console.log('Please run: npm run hackathon:setup first');
  process.exit(1);
}

// Read current .env
const envContent = fs.readFileSync(envPath, 'utf8');
const lines = envContent.split('\n');

// Extract WalletConnect Project ID
const wcProjectIdLine = lines.find(line => line.startsWith('NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID='));
if (!wcProjectIdLine) {
  console.error('❌ WalletConnect Project ID not found in .env!');
  console.log('Please add: NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID=your_project_id');
  process.exit(1);
}

const projectId = wcProjectIdLine.split('=')[1];
console.log('✅ WalletConnect Project ID found:', projectId);

// Instructions for fixing WalletConnect allowlist
console.log('\n🔧 FIXING WALLETCONNECT ALLOWLIST ERROR:');
console.log('=' .repeat(50));
console.log('1. Go to: https://cloud.reown.com/app');
console.log('2. Login to your WalletConnect account');
console.log('3. Find your project:', projectId);
console.log('4. Go to "Settings" > "Allowlist"');
const domainsToAdd = [
  'http://localhost:3000',
  'https://localhost:3000',
  'http://127.0.0.1:3000',
  'https://127.0.0.1:3000',
  'http://localhost:3001',
  'https://localhost:3001',
  'http://127.0.0.1:3001',
  'https://127.0.0.1:3001',
  'http://127.0.2.2:3000',
  'https://127.0.2.2:3000',
  'http://127.0.2.2:3001',
  'https://127.0.2.2:3001'
];

console.log('5. Add these domains to the allowlist:');
domainsToAdd.forEach(domain => {
  console.log(`   - ${domain}`);
});
console.log('6. Save the configuration');
console.log('7. Wait 2-3 minutes for changes to propagate');

// Instructions for contract errors
console.log('\n🔧 FIXING CONTRACT INTERACTION ERRORS:');
console.log('=' .repeat(50));
console.log('1. Make sure you are connected to Core Testnet');
console.log('2. Ensure you have tCORE tokens from faucet:');
console.log('   https://scan.test2.btcs.network/faucet');
console.log('3. Contract addresses being used:');

// Display contract addresses from .env
const contractLines = lines.filter(line => 
  line.startsWith('NEXT_PUBLIC_') && 
  line.includes('ADDRESS') && 
  line.includes('=')
);

contractLines.forEach(line => {
  const [key, value] = line.split('=');
  if (value && value.trim()) {
    console.log(`   ${key.replace('NEXT_PUBLIC_', '').replace('_ADDRESS', '')}: ${value}`);
  }
});

console.log('\n🔧 TROUBLESHOOTING STEPS:');
console.log('=' .repeat(50));
console.log('1. Clear browser cache and cookies');
console.log('2. Disconnect and reconnect MetaMask');
console.log('3. Switch to Core Testnet in MetaMask:');
console.log('   - Network Name: Core Testnet');
console.log('   - RPC URL: https://rpc.test2.btcs.network');
console.log('   - Chain ID: 1114');
console.log('   - Currency Symbol: tCORE');
console.log('   - Block Explorer: https://scan.test2.btcs.network');
console.log('4. Get test tokens from faucet');
console.log('5. Restart the development server');

console.log('\n🚀 NEXT STEPS:');
console.log('=' .repeat(50));
console.log('1. Fix WalletConnect allowlist (steps above)');
console.log('2. Wait 2-3 minutes');
console.log('3. Restart development server: npm run dev');
console.log('4. Test wallet connection');
console.log('5. If still having issues, check browser console for specific errors');

console.log('\n📋 VERIFICATION CHECKLIST:');
console.log('=' .repeat(50));
console.log('□ WalletConnect Project ID configured');
console.log('□ Domains added to WalletConnect allowlist');
console.log('□ MetaMask connected to Core Testnet');
console.log('□ tCORE tokens in wallet');
console.log('□ Development server restarted');
console.log('□ Browser cache cleared');

console.log('\n✨ Ready for testing! Visit: http://localhost:3000');