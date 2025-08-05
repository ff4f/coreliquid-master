# 🚀 CoreLiquid Vercel Deployment Guide
## Deploy ke Vercel dengan Branch "advantage"

---

## 📋 Prerequisites untuk Vercel Deployment

### 1. **Vercel Account Setup**
```bash
# 1. Buat akun di https://vercel.com
# 2. Install Vercel CLI
npm install -g vercel

# 3. Login ke Vercel
vercel login
```

### 2. **Environment Variables untuk Production**
```bash
# Variables yang WAJIB di-set di Vercel Dashboard:

# WalletConnect (CRITICAL - tanpa ini wallet tidak bisa connect)
NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID=your_actual_project_id

# Core Blockchain Configuration
NEXT_PUBLIC_ENVIRONMENT=testnet
CORE_TESTNET_RPC_URL=https://rpc.test2.btcs.network
CORE_RPC_URL=https://rpc.coredao.org
CORE_TESTNET_CHAIN_ID=1114
CORE_MAINNET_CHAIN_ID=1116

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

# WebSocket for real-time data
NEXT_PUBLIC_CORE_WS_URL=wss://ws.coredao.org
```

---

## 🔧 Deployment Steps

### Step 1: Prepare Branch "advantage"
```bash
# Pastikan Anda di branch advantage
git checkout advantage

# Atau buat branch baru jika belum ada
git checkout -b advantage

# Push semua changes
git add .
git commit -m "feat: prepare for vercel deployment with real contracts"
git push origin advantage
```

### Step 2: Vercel Project Setup
```bash
# Di root directory project
cd /Users/faliqulfikri/Documents/core\ hackathon/coreliquid-master

# Initialize Vercel project
vercel

# Follow prompts:
# ? Set up and deploy "~/Documents/core hackathon/coreliquid-master"? [Y/n] Y
# ? Which scope do you want to deploy to? [Your Account]
# ? Link to existing project? [y/N] N
# ? What's your project's name? coreliquid-protocol
# ? In which directory is your code located? ./
```

### Step 3: Configure Environment Variables
```bash
# Method 1: Via Vercel CLI
vercel env add NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID
# Paste your actual WalletConnect Project ID

vercel env add NEXT_PUBLIC_ENVIRONMENT
# Enter: testnet

vercel env add NEXT_PUBLIC_CORE_LIQUID_TOKEN
# Enter: 0xcAc1f956DE2B60059971cC8CeE12aC11B5295E0a

# ... (repeat for all environment variables)
```

```bash
# Method 2: Via Vercel Dashboard (Recommended)
# 1. Go to https://vercel.com/dashboard
# 2. Select your project
# 3. Go to Settings > Environment Variables
# 4. Add all variables from the list above
```

### Step 4: Deploy to Production
```bash
# Deploy from advantage branch
vercel --prod

# Or set specific branch
vercel --prod --branch advantage
```

---

## 📁 Vercel Configuration Files

### vercel.json (Already exists)
```json
{
  "buildCommand": "npm run build",
  "outputDirectory": ".next",
  "framework": "nextjs",
  "installCommand": "npm install",
  "devCommand": "npm run dev",
  "env": {
    "NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID": "@walletconnect-project-id",
    "NEXT_PUBLIC_ENVIRONMENT": "testnet"
  },
  "build": {
    "env": {
      "NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID": "@walletconnect-project-id",
      "NEXT_PUBLIC_ENVIRONMENT": "testnet"
    }
  },
  "functions": {
    "app/api/**/*.ts": {
      "maxDuration": 30
    }
  },
  "headers": [
    {
      "source": "/api/(.*)",
      "headers": [
        {
          "key": "Access-Control-Allow-Origin",
          "value": "*"
        },
        {
          "key": "Access-Control-Allow-Methods",
          "value": "GET, POST, PUT, DELETE, OPTIONS"
        },
        {
          "key": "Access-Control-Allow-Headers",
          "value": "Content-Type, Authorization"
        }
      ]
    }
  ]
}
```

### .vercelignore
```bash
# Files to ignore during deployment
node_modules
.env.local
.env.development
.env.staging
.git
.gitignore
README.md
*.log
.DS_Store
Thumbs.db

# Foundry/Hardhat artifacts
out/
cache/
artifacts/
broadcast/

# Testing files
test/
*.test.js
*.test.ts
*.spec.js
*.spec.ts

# Documentation
*.md
!README.md
docs/

# Scripts
scripts/
script/
```

---

## 🔍 Post-Deployment Verification

### 1. **Check Deployment Status**
```bash
# Check deployment logs
vercel logs

# Get deployment URL
vercel ls
```

### 2. **Test Live Application**
```bash
# Your app will be available at:
# https://coreliquid-protocol-[random].vercel.app

# Test checklist:
# ✅ Page loads without errors
# ✅ Wallet connection works
# ✅ Core Testnet network detection
# ✅ Contract interactions functional
# ✅ Real transactions possible
```

### 3. **Environment Variables Verification**
```bash
# Check if all env vars are set
vercel env ls

# Test WalletConnect specifically
# Open browser console and check for:
# "WalletConnect Project ID loaded successfully"
```

---

## 🚨 Common Issues & Solutions

### Issue 1: Build Fails
```bash
# Solution:
# 1. Check TypeScript errors
npm run build

# 2. Fix any compilation errors
# 3. Ensure all dependencies are in package.json
# 4. Redeploy
vercel --prod
```

### Issue 2: Environment Variables Not Working
```bash
# Solution:
# 1. Verify all NEXT_PUBLIC_ variables are set
# 2. Check Vercel Dashboard > Settings > Environment Variables
# 3. Redeploy after adding missing variables
vercel --prod
```

### Issue 3: Wallet Connection Fails
```bash
# Solution:
# 1. Verify WalletConnect Project ID is correct
# 2. Check browser console for errors
# 3. Test with different wallets (MetaMask, WalletConnect)
# 4. Ensure HTTPS is working (Vercel provides this automatically)
```

### Issue 4: Contract Interactions Fail
```bash
# Solution:
# 1. Verify all contract addresses are correct
# 2. Check Core Testnet RPC is accessible
# 3. Test with Core Testnet in MetaMask
# 4. Verify ABI compatibility
```

---

## 📊 Deployment Checklist

### Pre-Deployment
- [ ] All code committed to `advantage` branch
- [ ] WalletConnect Project ID obtained
- [ ] All contract addresses verified
- [ ] Local testing completed
- [ ] Environment variables prepared

### During Deployment
- [ ] Vercel project created
- [ ] Environment variables set
- [ ] Build successful
- [ ] No TypeScript errors
- [ ] Deployment URL generated

### Post-Deployment
- [ ] Live site accessible
- [ ] Wallet connection works
- [ ] Core Testnet network supported
- [ ] Contract interactions functional
- [ ] Real transactions possible
- [ ] All features working as expected

---

## 🎯 Final Deployment Commands

```bash
# Complete deployment sequence:

# 1. Ensure you're on advantage branch
git checkout advantage
git pull origin advantage

# 2. Build and test locally
npm run build
npm run start

# 3. Deploy to Vercel
vercel --prod

# 4. Set custom domain (optional)
vercel domains add coreliquid.your-domain.com

# 5. Verify deployment
vercel ls
vercel logs
```

---

## 🏆 Success Metrics

### Deployment berhasil jika:

✅ **Build & Deploy**
- Build completes without errors
- Deployment URL accessible
- All pages load correctly

✅ **Functionality**
- Wallet connection works
- Core Testnet network supported
- Contract interactions successful
- Real transactions possible

✅ **Performance**
- Fast loading times
- Responsive UI
- No console errors
- Mobile compatibility

✅ **Hackathon Ready**
- Live demo URL available
- Real transaction proofs
- Professional presentation
- Full feature showcase

---

## 🚀 Ready untuk Hackathon Submission!

Setelah deployment berhasil, Anda akan memiliki:
- ✅ Live application di Vercel
- ✅ Real wallet integration
- ✅ Functional Core Testnet transactions
- ✅ Professional demo URL
- ✅ Complete hackathon submission

**Deployment URL akan menjadi bukti live demo untuk hackathon! 🏆**