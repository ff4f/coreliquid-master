// Test script untuk memeriksa apakah contract calls masih menghasilkan error
const { ethers } = require('ethers');

// Contract addresses dari environment variables
const CONTRACT_ADDRESSES = {
  UNIFIED_LIQUIDITY_POOL: '0x50EEf481cae4250d252Ae577A09bF514f224C6C4',
  REVENUE_MODEL: '0xDEb1E9a6Be7Baf84208BB6E10aC9F9bbE1D70809',
  RISK_ENGINE: '0xD718d5A27a29FF1cD22403426084bA0d479869a0'
};

// ABIs untuk testing
const UNIFIED_LIQUIDITY_POOL_ABI = [
  'function getTotalValue() view returns (uint256)'
];

const REVENUE_MODEL_ABI = [
  'function getPendingRevenue(address user) view returns (uint256)'
];

const RISK_ENGINE_ABI = [
  'function calculateUserRiskProfile(address user) view returns (uint256 healthFactor, uint256 collateralValue, uint256 borrowValue)'
];

async function testContractCalls() {
  try {
    console.log('🧪 Testing contract calls...');
    
    // Setup provider untuk Core Testnet
    const provider = new ethers.JsonRpcProvider('https://rpc.test2.btcs.network');
    
    // Test address (dummy address untuk testing)
    const testAddress = '0x0000000000000000000000000000000000000001';
    
    // Test 1: getTotalValue
    console.log('\n1. Testing getTotalValue...');
    try {
      const ulpContract = new ethers.Contract(
        CONTRACT_ADDRESSES.UNIFIED_LIQUIDITY_POOL,
        UNIFIED_LIQUIDITY_POOL_ABI,
        provider
      );
      const totalValue = await ulpContract.getTotalValue();
      console.log('✅ getTotalValue berhasil:', ethers.formatEther(totalValue));
    } catch (error) {
      console.log('❌ getTotalValue error:', error.message);
    }
    
    // Test 2: getPendingRevenue
    console.log('\n2. Testing getPendingRevenue...');
    try {
      const revenueContract = new ethers.Contract(
        CONTRACT_ADDRESSES.REVENUE_MODEL,
        REVENUE_MODEL_ABI,
        provider
      );
      const pendingRevenue = await revenueContract.getPendingRevenue(testAddress);
      console.log('✅ getPendingRevenue berhasil:', ethers.formatEther(pendingRevenue));
    } catch (error) {
      console.log('❌ getPendingRevenue error:', error.message);
    }
    
    // Test 3: calculateUserRiskProfile
    console.log('\n3. Testing calculateUserRiskProfile...');
    try {
      const riskContract = new ethers.Contract(
        CONTRACT_ADDRESSES.RISK_ENGINE,
        RISK_ENGINE_ABI,
        provider
      );
      const riskProfile = await riskContract.calculateUserRiskProfile(testAddress);
      console.log('✅ calculateUserRiskProfile berhasil:', {
        healthFactor: ethers.formatUnits(riskProfile[0], 18),
        collateralValue: ethers.formatEther(riskProfile[1]),
        borrowValue: ethers.formatEther(riskProfile[2])
      });
    } catch (error) {
      console.log('❌ calculateUserRiskProfile error:', error.message);
    }
    
    console.log('\n🎉 Test selesai!');
    
  } catch (error) {
    console.error('❌ Error dalam testing:', error);
  }
}

// Jalankan test
testContractCalls();