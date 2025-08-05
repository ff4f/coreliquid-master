# 🎯 CoreLiquid UI/UX Testing Guide
## Testing dengan Real Wallet & Real Transactions di Core Testnet

---

## 📋 Prerequisites

### 1. **WalletConnect Project ID** (WAJIB!)
```bash
# 1. Kunjungi https://cloud.walletconnect.com/
# 2. Buat akun dan project baru
# 3. Copy Project ID
# 4. Update di file .env:
NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID=your_actual_project_id_here
```

### 2. **Core Testnet tCORE Tokens**
```bash
# Wallet Address untuk testing: 0x19C7fc7C730Fc6b8CEc573b4082F8d353bEA77cE
# 1. Kunjungi Core Testnet Faucet: https://scan.test.btcs.network/faucet
# 2. Request tCORE tokens ke address di atas
# 3. Minimal 1-2 tCORE untuk testing transaksi
```

### 3. **MetaMask Setup**
```bash
# Tambahkan Core Testnet ke MetaMask:
# Network Name: Core Testnet
# RPC URL: https://rpc.test2.btcs.network
# Chain ID: 1114
# Currency Symbol: tCORE
# Block Explorer: https://scan.test2.btcs.network
```

---

## 🚀 Step-by-Step Testing Guide

### Step 1: Setup Environment
```bash
cd /Users/faliqulfikri/Documents/core\ hackathon/coreliquid-master

# Install dependencies
npm install
# atau
pnpm install

# Check environment configuration
npm run check-env
```

### Step 2: Start Development Server
```bash
# Start Next.js development server
npm run dev
# atau
pnpm dev

# Server akan berjalan di: http://localhost:3000
```

### Step 3: Import Wallet ke MetaMask
```bash
# Private Key untuk testing (SUDAH ADA DI .env):
# 0x6241ca52a2e2cee1c9cbd048870abce11e2272a816dbff3f3d3ade137bc2dd9d
# Address: 0x19C7fc7C730Fc6b8CEc573b4082F8d353bEA77cE

# 1. Buka MetaMask
# 2. Import Account -> Private Key
# 3. Paste private key di atas
# 4. Switch ke Core Testnet network
```

### Step 4: Connect Wallet di UI
```bash
# 1. Buka http://localhost:3000
# 2. Klik "Connect Wallet"
# 3. Pilih MetaMask
# 4. Approve connection
# 5. Pastikan network Core Testnet (1114)
```

---

## 🧪 Testing Scenarios

### Scenario 1: Dashboard Overview
```bash
# URL: http://localhost:3000/dashboard
# Test:
# ✅ Wallet connection status
# ✅ Balance display (tCORE, CORE tokens, BTC tokens)
# ✅ Portfolio overview
# ✅ Real-time data updates
```

### Scenario 2: Staking Operations
```bash
# URL: http://localhost:3000/staking
# Test:
# ✅ Core Native Staking interface
# ✅ Stake tCORE tokens
# ✅ View staking rewards
# ✅ Unstake operations
# ✅ Real transaction di Core Testnet
```

### Scenario 3: Liquidity Operations
```bash
# URL: http://localhost:3000/liquidity
# Test:
# ✅ Add liquidity to pools
# ✅ Remove liquidity
# ✅ View LP token balance
# ✅ Yield farming rewards
# ✅ Real transaction confirmations
```

### Scenario 4: Lending/Borrowing
```bash
# URL: http://localhost:3000/lending
# Test:
# ✅ Deposit assets as collateral
# ✅ Borrow against collateral
# ✅ Repay loans
# ✅ Fixed-cost lending system
# ✅ Zero-interest compliance
```

### Scenario 5: Swap Operations
```bash
# URL: http://localhost:3000/swap
# Test:
# ✅ Token swaps (CORE <-> BTC)
# ✅ Price impact calculation
# ✅ Slippage tolerance
# ✅ Transaction execution
# ✅ Real DEX functionality
```

### Scenario 6: Portfolio Management
```bash
# URL: http://localhost:3000/portfolio
# Test:
# ✅ Asset allocation view
# ✅ Performance tracking
# ✅ Transaction history
# ✅ Yield analytics
# ✅ Risk assessment
```

---

## 🔍 Real Transaction Verification

### Setiap kali melakukan transaksi:

1. **Confirm di MetaMask**
   - Check gas fee
   - Confirm transaction
   - Wait for confirmation

2. **Verify di Core Explorer**
   ```bash
   # Buka: https://scan.test2.btcs.network
   # Search transaction hash
   # Verify:
   # ✅ Transaction status: Success
   # ✅ Gas used
   # ✅ Contract interaction
   # ✅ Event logs
   ```

3. **Check Balance Updates**
   - Refresh UI
   - Verify balance changes
   - Check transaction history

---

## 📊 Contract Addresses untuk Verification

### Deployed Contracts (Core Testnet):
```bash
# Core Tokens
CORE Token: 0xcAc1f956DE2B60059971cC8CeE12aC11B5295E0a
BTC Token:  0xC515E6030cC331Be138E9FE011ce23dd6eA0c9d6

# TULL Contracts
Simple TULL:    0x0B306BF915C4d645ff596e518fAf3F9669b97016
Optimized TULL: 0xc6e7DF5E7b4f2A278906862b61205850344D4e7d

# Core Native Staking
Staking Contract: 0xDB8cFf278adCCF9E9b5da745B44E754fC4EE3C76
stCORE Token:     0xBb2180ebd78ce97360503434eD37fcf4a1Df61c3

# DeFi Protocols
Liquidity Pool: 0x50EEf481cae4250d252Ae577A09bF514f224C6C4
LP Token:       0x62c20Aa1e0272312BC100b4e23B4DC1Ed96dD7D1
Revenue Model:  0xDEb1E9a6Be7Baf84208BB6E10aC9F9bbE1D70809
```

---

## 🐛 Troubleshooting

### Issue 1: Wallet Connection Failed
```bash
# Solution:
# 1. Check WalletConnect Project ID di .env
# 2. Clear browser cache
# 3. Restart development server
# 4. Try different browser
```

### Issue 2: Transaction Failed
```bash
# Solution:
# 1. Check tCORE balance untuk gas
# 2. Increase gas limit
# 3. Check network (harus Core Testnet 1114)
# 4. Verify contract addresses
```

### Issue 3: Balance Not Updating
```bash
# Solution:
# 1. Refresh page
# 2. Check transaction confirmation
# 3. Wait for block confirmation
# 4. Check RPC connection
```

### Issue 4: Contract Interaction Failed
```bash
# Solution:
# 1. Check contract addresses di .env
# 2. Verify ABI compatibility
# 3. Check function parameters
# 4. Increase gas limit
```

---

## 📈 Success Metrics

### UI/UX Testing berhasil jika:

✅ **Wallet Connection**
- MetaMask connects successfully
- Network switches to Core Testnet
- Balance displays correctly

✅ **Transaction Execution**
- All buttons clickable and responsive
- Transaction prompts appear
- MetaMask confirmation works
- Transactions confirm on-chain

✅ **Real-time Updates**
- Balance updates after transactions
- Transaction history shows
- Portfolio reflects changes

✅ **Cross-feature Integration**
- Staking -> Portfolio updates
- Liquidity -> Balance changes
- Lending -> Collateral tracking

✅ **Error Handling**
- Graceful error messages
- Network error recovery
- Transaction failure handling

---

## 🎯 Demo Script untuk Hackathon

### 5-Minute Demo Flow:

1. **[0:00-0:30] Setup & Connection**
   - Open localhost:3000
   - Connect MetaMask
   - Show Core Testnet network

2. **[0:30-1:30] Dashboard Overview**
   - Show portfolio balance
   - Highlight real contract addresses
   - Display transaction history

3. **[1:30-2:30] Staking Demo**
   - Navigate to staking
   - Stake some tCORE
   - Show real transaction hash
   - Verify on Core Explorer

4. **[2:30-3:30] Liquidity Demo**
   - Add liquidity to pool
   - Show LP token minting
   - Real transaction confirmation

5. **[3:30-4:30] Lending Demo**
   - Deposit collateral
   - Borrow against it
   - Show zero-interest system

6. **[4:30-5:00] Verification**
   - Show all transactions on Core Explorer
   - Highlight real addresses
   - Demonstrate live functionality

---

## 🚀 Ready untuk Hackathon!

Setelah mengikuti guide ini, Anda akan memiliki:
- ✅ Fully functional UI dengan real wallet
- ✅ Real transactions di Core Testnet
- ✅ Verifiable transaction proofs
- ✅ Complete demo scenario
- ✅ Professional presentation ready

**Good luck dengan hackathon! 🏆**