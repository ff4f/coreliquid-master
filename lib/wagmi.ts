import { getDefaultConfig } from '@rainbow-me/rainbowkit';
import { defineChain } from 'viem';

// Define Core Testnet chain
export const coreTestnet = defineChain({
  id: 1114,
  name: 'Core Testnet',
  nativeCurrency: {
    decimals: 18,
    name: 'tCORE',
    symbol: 'tCORE',
  },
  rpcUrls: {
    default: {
      http: ['https://rpc.test2.btcs.network'],
    },
  },
  blockExplorers: {
    default: {
      name: 'Core Testnet Explorer',
      url: 'https://scan.test2.btcs.network',
    },
  },
  testnet: true,
});

// Define Core Mainnet chain
export const coreMainnet = defineChain({
  id: 1116,
  name: 'Core',
  nativeCurrency: {
    decimals: 18,
    name: 'CORE',
    symbol: 'CORE',
  },
  rpcUrls: {
    default: {
      http: ['https://rpc.coredao.org'],
    },
  },
  blockExplorers: {
    default: {
      name: 'Core Explorer',
      url: 'https://scan.coredao.org',
    },
  },
  testnet: false,
});

// Get WalletConnect project ID from environment
const projectId = process.env.NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID;

if (!projectId) {
  throw new Error('NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID is not set');
}

// Configure wagmi with RainbowKit
export const config = getDefaultConfig({
  appName: 'CoreLiquid Protocol',
  projectId,
  chains: [coreTestnet, coreMainnet],
  ssr: true,
});

// Contract addresses for Core Testnet
export const CONTRACT_ADDRESSES = {
  // From deployment proof
  CORE_LIQUID_TOKEN: '0x63A3F54b45094aB13294584babA15a60Cf7678a8',
  CORE_LIQUID_STAKING: '0xC55812399b5921040A423079a93888D6EE5119F7',
  CORE_LIQUID_POOL: '0x0AF458873Fd91808B9AAa2BB0e48F458C745A4b0',
  
  // Additional contracts from environment variables
  STCORE_TOKEN: process.env.NEXT_PUBLIC_STCORE_TOKEN_ADDRESS || '0xBb2180ebd78ce97360503434eD37fcf4a1Df61c3',
  CORE_NATIVE_STAKING: process.env.NEXT_PUBLIC_CORE_NATIVE_STAKING_ADDRESS || '0xDB8cFf278adCCF9E9b5da745B44E754fC4EE3C76',
  UNIFIED_LIQUIDITY_POOL: process.env.NEXT_PUBLIC_UNIFIED_LIQUIDITY_POOL_ADDRESS || '0x50EEf481cae4250d252Ae577A09bF514f224C6C4',
  UNIFIED_LP_TOKEN: process.env.NEXT_PUBLIC_UNIFIED_LP_TOKEN_ADDRESS || '0x62c20Aa1e0272312BC100b4e23B4DC1Ed96dD7D1',
  REVENUE_MODEL: process.env.NEXT_PUBLIC_REVENUE_MODEL_ADDRESS || '0xDEb1E9a6Be7Baf84208BB6E10aC9F9bbE1D70809',
  RISK_ENGINE: process.env.NEXT_PUBLIC_RISK_ENGINE_ADDRESS || '0xD718d5A27a29FF1cD22403426084bA0d479869a0',
  DEPOSIT_MANAGER: process.env.NEXT_PUBLIC_DEPOSIT_MANAGER_ADDRESS || '0x4f559F30f5eB88D635FDe1548C4267DB8FaB0351',
  CREDIT_MANAGER: process.env.NEXT_PUBLIC_CREDIT_MANAGER_ADDRESS || '0x416C42991d05b31E9A6dC209e91AD22b79D87Ae6',
  CORE_LIQUID_PROTOCOL: process.env.NEXT_PUBLIC_CORE_LIQUID_PROTOCOL_ADDRESS || '0x978e3286EB805934215a88694d80b09aDed68D90',
  APR_OPTIMIZER: process.env.NEXT_PUBLIC_APR_OPTIMIZER_ADDRESS || '0xd21060559c9beb54fC07aFd6151aDf6cFCDDCAeB',
  POSITION_NFT: process.env.NEXT_PUBLIC_POSITION_NFT_ADDRESS || '0x4C52a6277b1B84121b3072C0c92b6Be0b7CC10F1',
  SIMPLE_TULL: process.env.NEXT_PUBLIC_SIMPLE_TULL_ADDRESS || '0x0B306BF915C4d645ff596e518fAf3F9669b97016',
  OPTIMIZED_TULL: '0xc6e7DF5E7b4f2A278906862b61205850344D4e7d',
  CORE_TOKEN: '0x59b670e9fA9D0A427751Af201D676719a970857b',
  BTC_TOKEN: '0x4ed7c70F96B99c776995fB64377f0d4aB3B0e1C1',
} as const;

// Chain configuration
export const CHAIN_CONFIG = {
  TESTNET: {
    chainId: 1114,
    name: 'Core Testnet',
    rpcUrl: 'https://rpc.test2.btcs.network',
    explorerUrl: 'https://scan.test2.btcs.network',
    nativeCurrency: {
      name: 'tCORE',
      symbol: 'tCORE',
      decimals: 18,
    },
  },
  MAINNET: {
    chainId: 1116,
    name: 'Core',
    rpcUrl: 'https://rpc.coredao.org',
    explorerUrl: 'https://scan.coredao.org',
    nativeCurrency: {
      name: 'CORE',
      symbol: 'CORE',
      decimals: 18,
    },
  },
} as const;

// Default to testnet for development
export const DEFAULT_CHAIN = coreTestnet;
export const DEFAULT_CHAIN_ID = 1114;