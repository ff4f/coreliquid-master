require('dotenv').config();
const { ethers } = require('ethers');

// Contract ABI for SimpleToken
const SimpleTokenABI = [
    "function name() view returns (string)",
    "function symbol() view returns (string)",
    "function decimals() view returns (uint8)",
    "function totalSupply() view returns (uint256)",
    "function balanceOf(address) view returns (uint256)",
    "function transfer(address to, uint256 amount) returns (bool)",
    "function mint(address to, uint256 amount)",
    "function burn(uint256 amount)",
    "event Transfer(address indexed from, address indexed to, uint256 value)"
];

async function testRealWallet() {
    console.log('🧪 CoreLiquid Protocol - Real Wallet Testing');
    console.log('============================================\n');
    
    const privateKey = process.env.PRIVATE_KEY;
    const rpcUrl = process.env.CORE_TESTNET_RPC_URL || 'https://rpc.test2.btcs.network';
    const coreTokenAddress = '0x162ff7e6202d6765290E58932EABA20Cc26939AF';
    const btcTokenAddress = '0x5b3578d284bEbcb15037567A49Ce855A636fff4E';
    
    try {
        // Connect to Core Testnet
        const provider = new ethers.JsonRpcProvider(rpcUrl);
        const wallet = new ethers.Wallet(privateKey, provider);
        
        console.log('🔗 Connected to Core Testnet');
        console.log('Wallet Address:', wallet.address);
        
        // Check wallet balance
        const balance = await provider.getBalance(wallet.address);
        console.log('Wallet Balance:', ethers.formatEther(balance), 'tCORE\n');
        
        // Connect to contracts
        const coreToken = new ethers.Contract(coreTokenAddress, SimpleTokenABI, wallet);
        const btcToken = new ethers.Contract(btcTokenAddress, SimpleTokenABI, wallet);
        
        // Test CORE Token
        console.log('🪙 Testing CORE Token Contract');
        console.log('==============================');
        const coreName = await coreToken.name();
        const coreSymbol = await coreToken.symbol();
        const coreDecimals = await coreToken.decimals();
        const coreTotalSupply = await coreToken.totalSupply();
        const coreBalance = await coreToken.balanceOf(wallet.address);
        
        console.log('Name:', coreName);
        console.log('Symbol:', coreSymbol);
        console.log('Decimals:', coreDecimals);
        console.log('Total Supply:', ethers.formatEther(coreTotalSupply));
        console.log('Your Balance:', ethers.formatEther(coreBalance), coreSymbol);
        
        // Test BTC Token
        console.log('\n₿ Testing BTC Token Contract');
        console.log('=============================');
        const btcName = await btcToken.name();
        const btcSymbol = await btcToken.symbol();
        const btcDecimals = await btcToken.decimals();
        const btcTotalSupply = await btcToken.totalSupply();
        const btcBalance = await btcToken.balanceOf(wallet.address);
        
        console.log('Name:', btcName);
        console.log('Symbol:', btcSymbol);
        console.log('Decimals:', btcDecimals);
        console.log('Total Supply:', ethers.formatUnits(btcTotalSupply, btcDecimals));
        console.log('Your Balance:', ethers.formatUnits(btcBalance, btcDecimals), btcSymbol);
        
        // Test real transaction - Transfer small amount to self
        console.log('\n🔄 Testing Real Transaction');
        console.log('============================');
        
        const transferAmount = ethers.parseEther('1'); // 1 CORE token
        console.log('Transferring 1 CORE token to self...');
        
        const tx = await coreToken.transfer(wallet.address, transferAmount);
        console.log('Transaction Hash:', tx.hash);
        console.log('Explorer Link:', `https://scan.test.btcs.network/tx/${tx.hash}`);
        
        console.log('⏳ Waiting for confirmation...');
        const receipt = await tx.wait();
        console.log('✅ Transaction confirmed in block:', receipt.blockNumber);
        
        // Check balance after transfer
        const newCoreBalance = await coreToken.balanceOf(wallet.address);
        console.log('New CORE Balance:', ethers.formatEther(newCoreBalance), 'CORE');
        
        console.log('\n🎉 Real Wallet Testing Completed Successfully!');
        console.log('===============================================');
        console.log('✅ Smart contracts are working');
        console.log('✅ Real transactions are successful');
        console.log('✅ Ready for UI/UX testing');
        
        console.log('\n📋 Next Steps for UI/UX Testing:');
        console.log('1. Start frontend: npm run dev');
        console.log('2. Connect your wallet (MetaMask/WalletConnect)');
        console.log('3. Switch to Core Testnet (Chain ID: 1114)');
        console.log('4. Test token interactions through UI');
        console.log('5. Verify transactions on explorer');
        
        return {
            success: true,
            contracts: {
                coreToken: coreTokenAddress,
                btcToken: btcTokenAddress
            },
            transactionHash: tx.hash,
            blockNumber: receipt.blockNumber
        };
        
    } catch (error) {
        console.error('\n❌ Testing failed:', error.message);
        return { success: false, error: error.message };
    }
}

if (require.main === module) {
    testRealWallet();
}

module.exports = { testRealWallet };