# 🚀 CoreLiquid - Quick Start untuk Hackathon

> **One-command setup untuk Core Connect Global Buildathon**

## ⚡ Super Quick Start

```bash
# 1. Setup lengkap (WalletConnect + Environment)
npm run hackathon:setup

# 2. Start UI/UX testing dengan real wallet
npm run hackathon:test

# 3. Deploy ke Vercel (production)
npm run hackathon:deploy
```

## 🎯 Individual Commands

### Setup WalletConnect Project ID
```bash
npm run hackathon:walletconnect
```

### Start Development Server untuk Testing
```bash
npm run demo:start
# atau
npm run dev
```

### Build Production Version
```bash
npm run demo:build
```

### Check Environment Configuration
```bash
npm run check-env
```

## 📋 Prerequisites

1. **Node.js** (v18 atau lebih baru)
2. **MetaMask** dengan Core Testnet setup
3. **tCORE tokens** dari [faucet](https://scan.test2.btcs.network/faucet)
4. **WalletConnect Project ID** dari [cloud.walletconnect.com](https://cloud.walletconnect.com)
5. **Vercel account** untuk deployment

## 🌐 Core Testnet Setup

**Network Configuration untuk MetaMask:**
```
Network Name: Core Testnet
RPC URL: https://rpc.test2.btcs.network
Chain ID: 1114
Currency Symbol: tCORE
Block Explorer: https://scan.test2.btcs.network
```

## 🧪 Testing Checklist

- [ ] Connect wallet ke Core Testnet
- [ ] Test staking features (real transaction)
- [ ] Test liquidity features (real transaction)
- [ ] Test swap functionality (real transaction)
- [ ] Verify transactions di [Core Explorer](https://scan.test2.btcs.network)
- [ ] Screenshot untuk dokumentasi

## 🚀 Deployment ke Vercel

1. **Setup Environment Variables** di Vercel Dashboard
2. **Push ke branch `advantage`**
3. **Run deployment script**:
   ```bash
   npm run hackathon:deploy
   ```

## 🏆 Hackathon Links

- 🎯 **Hackathon**: [Core Connect Global Buildathon](https://dorahacks.io/hackathon/core-connect-global-buildathon)
- 📊 **Judging Criteria**: [Guidelines](https://dorahacks.io/hackathon/core-connect-global-buildathon/judging-criteria)
- 💡 **Inspiration**: [Core Community #24](https://github.com/coredao-org/core-community-contributions/issues/24)

## 🆘 Troubleshooting

### WalletConnect Issues
```bash
# Re-setup WalletConnect
npm run hackathon:walletconnect
```

### Development Server Issues
```bash
# Clean install
rm -rf node_modules package-lock.json
npm install
npm run dev
```

### Environment Issues
```bash
# Check configuration
npm run check-env

# Manual setup
cp .env.example .env
# Edit .env dengan values yang benar
```

## 📞 Support

Jika ada masalah, check:
1. **HACKATHON_README.md** - dokumentasi lengkap
2. **UI_UX_TESTING_GUIDE.md** - panduan testing detail
3. **VERCEL_DEPLOYMENT_GUIDE.md** - panduan deployment

---

**🏆 Siap menang hackathon dengan CoreLiquid!**

*True Unified Liquidity Layer untuk Core Chain & Bitcoin* 🚀