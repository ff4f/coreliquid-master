# 🚀 Manual Vercel Deployment Guide - CoreLiquid Protocol

## Panduan Lengkap Deploy ke Vercel untuk Hackathon Core Connect Global Buildathon

---

## 📋 Prerequisites

### 1. Akun dan Tools yang Dibutuhkan
- ✅ Akun GitHub (untuk integrasi)
- ✅ Akun Vercel (https://vercel.com)
- ✅ WalletConnect Project ID
- ✅ Git repository dengan branch `implementation`

### 2. Install Dependencies
```bash
# Install Vercel CLI (optional, untuk deployment via CLI)
npm install -g vercel

# Atau gunakan npx
npx vercel --version
```

---

## 🔧 Step 1: Persiapan Environment Variables

### A. Buat WalletConnect Project ID
1. Buka https://cloud.walletconnect.com/
2. Buat akun baru atau login
3. Klik **"Create Project"**
4. Isi nama project: **"CoreLiquid Protocol"**
5. Copy **Project ID** yang diberikan
6. Simpan untuk digunakan nanti

### B. Siapkan Environment Variables
Buat file `.env.local` di root project dengan isi:

```bash
# CRITICAL: WalletConnect Configuration
NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID=your_actual_project_id_here

# Core Blockchain Configuration
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

# App Configuration
NEXT_PUBLIC_APP_NAME=CoreLiquid Protocol
NEXT_PUBLIC_ENABLE_TESTNET=true
```

---

## 🌿 Step 2: Persiapan Git Repository

### A. Pastikan Branch Implementation
```bash
# Check current branch
git branch

# Switch ke branch implementation (atau buat jika belum ada)
git checkout implementation
# atau
git checkout -b implementation

# Pastikan semua changes sudah di-commit
git add .
git commit -m "feat: prepare for vercel deployment"
git push origin implementation
```

### B. Verifikasi File yang Dibutuhkan
Pastikan file-file ini ada di repository:
- ✅ `package.json`
- ✅ `next.config.mjs`
- ✅ `vercel.json`
- ✅ `tailwind.config.ts`
- ✅ `tsconfig.json`

---

## 🚀 Step 3: Deploy via Vercel Dashboard (Recommended)

### A. Login ke Vercel
1. Buka https://vercel.com
2. Login dengan akun GitHub Anda
3. Klik **"Add New..."** → **"Project"**

### B. Import GitHub Repository
1. Pilih **"Import Git Repository"**
2. Cari repository CoreLiquid Anda
3. Klik **"Import"**

### C. Configure Project Settings
1. **Project Name**: `coreliquid-protocol`
2. **Framework Preset**: Next.js (auto-detected)
3. **Root Directory**: `./` (default)
4. **Build Command**: `npm run build` (default)
5. **Output Directory**: `.next` (default)
6. **Install Command**: `npm install` (default)

### D. Set Environment Variables
1. Klik **"Environment Variables"**
2. Tambahkan satu per satu semua variables dari `.env.local`:

```
Key: NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID
Value: [paste your actual project ID]
Environments: Production, Preview, Development

Key: NEXT_PUBLIC_ENVIRONMENT
Value: testnet
Environments: Production, Preview, Development

Key: NEXT_PUBLIC_CORE_RPC_URL
Value: https://rpc.test2.btcs.network
Environments: Production, Preview, Development

... (lanjutkan untuk semua variables)
```

### E. Configure Branch
1. Scroll ke **"Git"**
2. Set **Production Branch**: `implementation`
3. Klik **"Deploy"**

---

## 🔄 Step 4: Deploy via Vercel CLI (Alternative)

```bash
# Login ke Vercel
vercel login

# Di root directory project
cd /path/to/coreliquid-master

# Deploy
vercel

# Follow prompts:
# ? Set up and deploy? [Y/n] Y
# ? Which scope? [Your Account]
# ? Link to existing project? [y/N] N
# ? Project name? coreliquid-protocol
# ? In which directory is your code located? ./

# Set environment variables
vercel env add NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID production
# [paste your project ID]

vercel env add NEXT_PUBLIC_ENVIRONMENT production
# testnet

# ... (repeat for all variables)

# Deploy to production
vercel --prod
```

---

## ✅ Step 5: Verifikasi Deployment

### A. Check Deployment Status
1. Buka Vercel Dashboard
2. Pilih project `coreliquid-protocol`
3. Check status deployment
4. Klik URL deployment untuk test

### B. Test Functionality
1. **Wallet Connection**: Test connect wallet
2. **Contract Interaction**: Test basic functions
3. **UI/UX**: Check responsive design
4. **Performance**: Check loading speed

### C. Check Logs
Jika ada error:
1. Buka **"Functions"** tab
2. Check **"Real-time Logs"**
3. Debug issues

---

## 🔧 Step 6: Custom Domain (Optional)

### A. Add Custom Domain
1. Di Vercel Dashboard → Project Settings
2. Klik **"Domains"**
3. Add domain: `coreliquid.your-domain.com`
4. Follow DNS configuration

### B. Update Environment Variables
```bash
NEXT_PUBLIC_APP_URL=https://coreliquid.your-domain.com
```

---

## 🚨 Troubleshooting

### Common Issues:

#### 1. Build Errors
```bash
# Local test build
npm run build

# Fix TypeScript errors
npm run lint
```

#### 2. Environment Variables Not Working
- Pastikan prefix `NEXT_PUBLIC_` untuk client-side variables
- Check spelling dan case sensitivity
- Restart deployment setelah update env vars

#### 3. WalletConnect Issues
- Verify Project ID is correct
- Check domain whitelist di WalletConnect dashboard
- Test dengan different wallets

#### 4. Contract Connection Issues
- Verify contract addresses
- Check RPC URL accessibility
- Test network connectivity

---

## 📱 Step 7: Mobile Testing

### A. Test Responsive Design
1. Open deployment URL di mobile browser
2. Test wallet connection
3. Check UI elements

### B. PWA Features
1. Test "Add to Home Screen"
2. Check offline functionality
3. Verify push notifications

---

## 🎯 Final Checklist

- [ ] ✅ Repository pushed to GitHub
- [ ] ✅ Branch `implementation` created
- [ ] ✅ Vercel project created
- [ ] ✅ Environment variables configured
- [ ] ✅ Deployment successful
- [ ] ✅ Wallet connection working
- [ ] ✅ Contract interactions working
- [ ] ✅ Mobile responsive
- [ ] ✅ Performance optimized
- [ ] ✅ Error handling working

---

## 🔗 Useful Links

- **Vercel Dashboard**: https://vercel.com/dashboard
- **WalletConnect Cloud**: https://cloud.walletconnect.com/
- **Core Chain Testnet**: https://scan.test.btcs.network/
- **Core Chain Mainnet**: https://scan.coredao.org/

---

## 📞 Support

Jika ada masalah:
1. Check Vercel documentation
2. Check project logs
3. Test locally first
4. Verify environment variables

**Good luck dengan hackathon! 🚀**