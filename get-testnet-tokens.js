require('dotenv').config();
const { ethers } = require('ethers');

async function getTestnetTokens() {
    console.log('🚰 CoreLiquid Protocol - Getting Core Testnet Tokens');
    console.log('==================================================\n');
    
    const walletAddress = process.env.WALLET_ADDRESS || '0x19C7fc7C730Fc6b8CEc573b4082F8d353bEA77cE';
    const rpcUrl = process.env.CORE_TESTNET_RPC_URL || 'https://rpc.test2.btcs.network';
    
    console.log('Wallet Address:', walletAddress);
    console.log('RPC URL:', rpcUrl);
    
    try {
        // Connect to Core Testnet
        const provider = new ethers.JsonRpcProvider(rpcUrl);
        
        // Check current balance
        const balance = await provider.getBalance(walletAddress);
        console.log('\n💰 Current Balance:', ethers.formatEther(balance), 'tCORE');
        
        if (parseFloat(ethers.formatEther(balance)) < 0.1) {
            console.log('\n⚠️  Low balance detected! You need testnet tokens.');
            console.log('\n🚰 Get testnet tokens from:');
            console.log('   • Core Testnet Faucet: https://scan.test.btcs.network/faucet');
            console.log('   • Alternative Faucet: https://bridge.coredao.org/faucet');
            console.log('\n📋 Instructions:');
            console.log('   1. Visit the faucet URL');
            console.log('   2. Connect your wallet or paste address:', walletAddress);
            console.log('   3. Request testnet tokens');
            console.log('   4. Wait for confirmation');
            console.log('   5. Run this script again to verify');
            
            return false;
        } else {
            console.log('\n✅ Sufficient balance for deployment!');
            console.log('\n🚀 Ready to deploy contracts!');
            console.log('\n📋 Next steps:');
            console.log('   1. Run: npm run deploy:testnet');
            console.log('   2. Start frontend: npm run dev');
            console.log('   3. Test with real wallet connection');
            
            return true;
        }
        
    } catch (error) {
        console.error('\n❌ Error checking balance:', error.message);
        return false;
    }
}

// Auto-check balance every 30 seconds if insufficient
async function autoCheck() {
    const hasBalance = await getTestnetTokens();
    
    if (!hasBalance) {
        console.log('\n⏰ Will check again in 30 seconds...');
        setTimeout(autoCheck, 30000);
    }
}

if (require.main === module) {
    autoCheck();
}

module.exports = { getTestnetTokens };