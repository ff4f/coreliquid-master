# 🚀 Quick Start: Deploy CoreLiquid ke Vercel

## Panduan Cepat untuk Hackathon Core Connect Global Buildathon

---

## ⚡ Quick Setup (5 menit)

### 1. Cek Kesiapan Deployment
```bash
npm run deployment:check
```

### 2. Setup Otomatis
```bash
npm run deployment:setup
```

### 3. Deploy ke Vercel
- Buka https://vercel.com
- Import repository GitHub
- Set branch: `implementation`
- Deploy!

---

## 📋 Checklist Cepat

### Prerequisites
- [ ] ✅ Akun GitHub
- [ ] ✅ Akun Vercel
- [ ] ✅ WalletConnect Project ID
- [ ] ✅ Repository di GitHub

### Setup
- [ ] ✅ Run `npm run deployment:check`
- [ ] ✅ Run `npm run deployment:setup`
- [ ] ✅ Commit & push ke branch `implementation`

### Vercel
- [ ] ✅ Import repository
- [ ] ✅ Set production branch: `implementation`
- [ ] ✅ Copy environment variables dari `.env.local`
- [ ] ✅ Deploy

---

## 🔧 Environment Variables untuk Vercel

Copy semua variables ini ke Vercel Dashboard:

```bash
# CRITICAL - Tanpa ini wallet tidak bisa connect
NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID=your_project_id

# Core Blockchain
NEXT_PUBLIC_ENVIRONMENT=testnet
NEXT_PUBLIC_CORE_RPC_URL=https://rpc.test2.btcs.network
NEXT_PUBLIC_CORE_CHAIN_ID=1114
NEXT_PUBLIC_CORE_MAINNET_RPC_URL=https://rpc.coredao.org
NEXT_PUBLIC_CORE_MAINNET_CHAIN_ID=1116
NEXT_PUBLIC_CORE_WS_URL=wss://ws.coredao.org

# Contract Addresses (Real Deployed)
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

# App Config
NEXT_PUBLIC_APP_NAME=CoreLiquid Protocol
NEXT_PUBLIC_ENABLE_TESTNET=true
```

---

## 🎯 Langkah Detail

### Step 1: WalletConnect Setup
1. Buka https://cloud.walletconnect.com/
2. Create Project: "CoreLiquid Protocol"
3. Copy Project ID

### Step 2: Local Setup
```bash
# Check semua konfigurasi
npm run deployment:check

# Setup otomatis (akan minta WalletConnect ID)
npm run deployment:setup
```

### Step 3: Vercel Deployment
1. **Login Vercel**: https://vercel.com
2. **Add New Project**
3. **Import dari GitHub**
4. **Configure**:
   - Project Name: `coreliquid-protocol`
   - Framework: Next.js (auto-detect)
   - Production Branch: `implementation`
5. **Environment Variables**: Copy dari `.env.local`
6. **Deploy**

---

## 🚨 Troubleshooting

### Build Errors
```bash
# Test build locally
npm run build

# Fix lint errors
npm run lint
```

### Environment Issues
- Pastikan semua `NEXT_PUBLIC_` variables ada
- Check WalletConnect Project ID valid
- Verify contract addresses

### Git Issues
```bash
# Switch ke branch implementation
git checkout implementation

# Atau buat baru
git checkout -b implementation

# Push changes
git add .
git commit -m "feat: ready for vercel deployment"
git push origin implementation
```

---

## 📱 Testing Deployment

### Setelah Deploy
1. ✅ Buka URL deployment
2. ✅ Test wallet connection
3. ✅ Test basic functions
4. ✅ Check mobile responsive
5. ✅ Verify contract interactions

### Performance Check
- Loading speed < 3 detik
- Wallet connect < 5 detik
- Transaction response < 10 detik

---

## 🔗 Links Penting

- **Vercel Dashboard**: https://vercel.com/dashboard
- **WalletConnect**: https://cloud.walletconnect.com/
- **Core Testnet**: https://scan.test.btcs.network/
- **Hackathon**: https://dorahacks.io/hackathon/core-connect-global-buildathon/

---

## 🏆 Success Criteria

- [ ] ✅ Deployment berhasil
- [ ] ✅ Wallet connection working
- [ ] ✅ Contract interactions working
- [ ] ✅ UI responsive
- [ ] ✅ No console errors
- [ ] ✅ Fast loading

**Good luck dengan hackathon! 🚀**