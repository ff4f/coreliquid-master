// Script untuk memeriksa apakah contract addresses valid
const { ethers } = require('ethers');

// Contract addresses dari environment variables
const CONTRACT_ADDRESSES = {
  UNIFIED_LIQUIDITY_POOL: '0x50EEf481cae4250d252Ae577A09bF514f224C6C4',
  REVENUE_MODEL: '0xDEb1E9a6Be7Baf84208BB6E10aC9F9bbE1D70809',
  RISK_ENGINE: '0xD718d5A27a29FF1cD22403426084bA0d479869a0',
  CORE_LIQUID_TOKEN: '0xcAc1f956DE2B60059971cC8CeE12aC11B5295E0a',
  STCORE_TOKEN: '0xBb2180ebd78ce97360503434eD37fcf4a1Df61c3'
};

async function checkContracts() {
  try {
    console.log('🔍 Checking contract addresses on Core Testnet...');
    
    // Setup provider untuk Core Testnet
    const provider = new ethers.JsonRpcProvider('https://rpc.test2.btcs.network');
    
    for (const [name, address] of Object.entries(CONTRACT_ADDRESSES)) {
      console.log(`\n📋 Checking ${name}: ${address}`);
      
      try {
        // Check if address has code (is a contract)
        const code = await provider.getCode(address);
        
        if (code === '0x') {
          console.log(`❌ ${name}: No contract code found (EOA or non-existent)`);
        } else {
          console.log(`✅ ${name}: Contract found (${code.length} bytes)`);
          
          // Try to get balance to confirm network connectivity
          const balance = await provider.getBalance(address);
          console.log(`   Balance: ${ethers.formatEther(balance)} tCORE`);
        }
      } catch (error) {
        console.log(`❌ ${name}: Error checking - ${error.message}`);
      }
    }
    
    // Test network connectivity
    console.log('\n🌐 Testing network connectivity...');
    try {
      const blockNumber = await provider.getBlockNumber();
      console.log(`✅ Connected to Core Testnet, latest block: ${blockNumber}`);
    } catch (error) {
      console.log(`❌ Network error: ${error.message}`);
    }
    
  } catch (error) {
    console.error('❌ Error in contract checking:', error);
  }
}

// Jalankan check
checkContracts();