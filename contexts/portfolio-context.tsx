"use client"

import type React from "react"
import { createContext, useContext, useReducer, type ReactNode } from "react"
import { getTokenData, tokens } from "@/lib/token-data"

export interface Transaction {
  id: string
  type: "deposit" | "borrow" | "vault" | "swap" | "withdraw" | "repay" | "compound" | "rebalance" | "revenue_claim" | "ulp_deposit" | "ulp_withdraw" | "ulp"
  status: "pending" | "completed" | "failed"
  amount: number
  token: string
  valueUSD: number
  timestamp: number
  hash?: string
  gasUsed?: number
  revenueSource?: string
  automationTriggered?: boolean
}

export interface RecentActivity {
  id: string
  type: "deposit" | "borrow" | "swap" | "withdraw" | "repay" | "compound" | "rebalance" | "revenue_distribution" | "automation_executed" | "yield_harvest" | "ulp" | "revenue_claim" | "ulp_deposit" | "ulp_withdraw"
  status: "completed" | "pending" | "failed"
  amount: number
  token: string
  toToken?: string // For swaps
  valueUSD: number
  timestamp: number
  hash?: string
  automationTask?: string
  aprImpact?: number
  description?: string
}

export interface Position {
  id: string
  type: "deposit" | "borrow" | "vault" | "ulp" // Added ULP type
  token: string
  amount: number
  valueUSD: number
  apy?: number
  healthFactor?: number
  timestamp: number
  isCollateral?: boolean
  txHash?: string // Transaction hash for proof
  // ULP specific fields
  shares?: number
  sharePrice?: number
  compoundFrequency?: number
  lastCompound?: number
  nextCompound?: number
  projectedYield?: {
    daily: number
    weekly: number
    monthly: number
    yearly: number
  }
  // Revenue tracking
  totalEarned?: number
  pendingRewards?: number
  lifetimeRewards?: number
}

export interface TokenBalance {
  total: number // Total amount of token owned (deposits + borrowed)
  collateralized: number // Amount locked as collateral
  available: number // Amount available for use (total - collateralized)
  borrowed: number // Amount borrowed
  valueUSD: number // USD value of total tokens
}

// Enhanced interfaces for new business logic
export interface APRMetrics {
  current: number
  average7d: number
  average30d: number
  volatilityAdjusted: number
  projected: number
  confidenceLevel: number
  breakdown: {
    tradingFees: number
    arbitrageProfits: number
    liquidationFees: number
    yieldFarming: number
    compoundBonus: number
  }
  historicalData: {
    timestamps: number[]
    values: number[]
    volatility: number[]
  }
}

export interface RevenueMetrics {
  totalEarned: number
  pendingRewards: number
  lifetimeRewards: number
  lastClaimed: number | null
  sourceBreakdown: {
    tradingFees: number
    arbitrageProfits: number
    liquidationFees: number
    yieldFarming: number
    partnershipFees: number
    performanceFees: number
  }
  projectedDaily: number
  projectedWeekly: number
  projectedMonthly: number
  revenueGrowthRate: number
}

export interface AutomationStatus {
  isEnabled: boolean
  inEmergencyMode: boolean
  activeTasks: number
  totalExecutions: number
  successRate: number
  averageGas: number
  uptime: number
  lastExecution: number | null
  nextScheduledTasks: {
    taskType: string
    scheduledTime: number
    priority: number
    estimatedGas: number
  }[]
  marketCondition: {
    volatilityIndex: number
    liquidityLevel: number
    riskLevel: number
    emergencyMode: boolean
  }
}

export interface RiskMetrics {
  sharpeRatio: number
  maxDrawdown: number
  volatilityIndex: number
  consistencyScore: number
  liquidityRisk: number
  overallRiskLevel: number // 1-10 scale
  riskAdjustedReturn: number
  valueAtRisk: number // VaR calculation
}

export interface ULPData {
  totalShares: number
  userShares: number
  sharePrice: number
  totalValue: number
  capitalEfficiency: number
  lastRebalance: number | null
  nextRebalance: number | null
  rebalanceThreshold: number
  tokenAllocations: {
    [token: string]: {
      amount: number
      percentage: number
      targetPercentage: number
      deviation: number
    }
  }
  performanceMetrics: {
    totalReturn: number
    annualizedReturn: number
    volatility: number
    sharpeRatio: number
  }
}

export interface PerformanceData {
  totalReturn: number
  totalReturnPercentage: number
  dailyPnL: number
  weeklyPnL: number
  monthlyPnL: number
  yearlyPnL: number
  bestDay: { date: number; return: number; percentage: number }
  worstDay: { date: number; return: number; percentage: number }
  winRate: number // Percentage of profitable days
  averageDailyReturn: number
  maxConsecutiveWins: number
  maxConsecutiveLosses: number
  calmarRatio: number // Annual return / max drawdown
}

export interface PortfolioState {
  isWalletConnected: boolean
  accountAddress: string
  totalValueUSD: number
  totalDepositsUSD: number
  totalBorrowsUSD: number
  totalVaultValueUSD: number
  totalULPValueUSD: number // New ULP value
  netWorthUSD: number
  healthFactor: number
  positions: Position[]
  transactions: Transaction[]
  recentActivities: RecentActivity[]
  coreHoldings: number
  balances: { [tokenSymbol: string]: TokenBalance }
  
  // Enhanced metrics for new business logic
  aprMetrics: APRMetrics
  revenueMetrics: RevenueMetrics
  automationStatus: AutomationStatus
  riskMetrics: RiskMetrics
  ulpData: ULPData
  performance: PerformanceData
  
  // Loading states
  isLoadingAPR: boolean
  isLoadingRevenue: boolean
  isLoadingAutomation: boolean
  isLoadingULP: boolean
  
  // Error states
  errors: {
    apr?: string
    revenue?: string
    automation?: string
    ulp?: string
    general?: string
  }
  
  // Settings
  settings: {
    autoCompound: boolean
    compoundFrequency: number // hours
    riskTolerance: number // 1-10
    rebalanceThreshold: number // percentage
    emergencyStopEnabled: boolean
    notificationsEnabled: boolean
  }
}

export type PortfolioAction =
  | { type: "CONNECT_WALLET"; payload: { address: string } }
  | { type: "DISCONNECT_WALLET" }
  | { type: "ADD_POSITION"; payload: Position }
  | { type: "REMOVE_POSITION"; payload: { id: string } }
  | { type: "UPDATE_POSITION"; payload: { id: string; updates: Partial<Position> } }
  | { type: "ADD_TRANSACTION"; payload: Transaction }
  | { type: "UPDATE_TRANSACTION"; payload: { id: string; updates: Partial<Transaction> } }
  | { type: "ADD_RECENT_ACTIVITY"; payload: RecentActivity }
  | { type: "SET_CORE_HOLDINGS"; payload: { amount: number } }
  | { type: "UPDATE_TOKEN_BALANCE"; payload: { symbol: string; balance: number } }
  // New actions for enhanced functionality
  | { type: "UPDATE_APR_METRICS"; payload: APRMetrics }
  | { type: "UPDATE_REVENUE_METRICS"; payload: RevenueMetrics }
  | { type: "UPDATE_AUTOMATION_STATUS"; payload: AutomationStatus }
  | { type: "UPDATE_RISK_METRICS"; payload: RiskMetrics }
  | { type: "UPDATE_ULP_DATA"; payload: ULPData }
  | { type: "UPDATE_PERFORMANCE"; payload: PerformanceData }
  | { type: "SET_LOADING"; payload: { key: string; loading: boolean } }
  | { type: "SET_ERROR"; payload: { key: string; error: string | null } }
  | { type: "UPDATE_SETTINGS"; payload: Partial<PortfolioState['settings']> }
  | { type: "EXECUTE_COMPOUND"; payload: { positionId: string; amount: number } }
  | { type: "EXECUTE_REBALANCE"; payload: { timestamp: number; gasUsed: number } }
  | { type: "CLAIM_REVENUE"; payload: { amount: number; token: string; source: string } }
  | { type: "EMERGENCY_STOP"; payload: { reason: string; timestamp: number } }
  // Real transaction handling actions
  | { type: "START_TRANSACTION"; payload: { id: string; type: Transaction['type']; amount: number; token: string; valueUSD: number } }
  | { type: "COMPLETE_TRANSACTION"; payload: { id: string; hash: string; gasUsed: number; timestamp: number } }
  | { type: "FAIL_TRANSACTION"; payload: { id: string; activityId: string; error: string } }

const initialState: PortfolioState = {
  isWalletConnected: false,
  accountAddress: "",
  totalValueUSD: 0,
  totalDepositsUSD: 0,
  totalBorrowsUSD: 0,
  totalVaultValueUSD: 0,
  totalULPValueUSD: 0,
  netWorthUSD: 0,
  healthFactor: 0,
  positions: [],
  transactions: [],
  recentActivities: [],
  coreHoldings: 0,
  balances: {
    CORE: {
      total: 10.5,
      collateralized: 0,
      available: 10.5,
      borrowed: 0,
      valueUSD: 10.5 * 1.23,
    },
    STCORE: {
      total: 0,
      collateralized: 0,
      available: 0,
      borrowed: 0,
      valueUSD: 0,
    },
    CLT: {
      total: 0,
      collateralized: 0,
      available: 0,
      borrowed: 0,
      valueUSD: 0,
    },
    USDT: {
      total: 0,
      collateralized: 0,
      available: 0,
      borrowed: 0,
      valueUSD: 0,
    },
    USDC: {
      total: 0,
      collateralized: 0,
      available: 0,
      borrowed: 0,
      valueUSD: 0,
    },
    WBTC: {
      total: 0,
      collateralized: 0,
      available: 0,
      borrowed: 0,
      valueUSD: 0,
    },
    WETH: {
      total: 0,
      collateralized: 0,
      available: 0,
      borrowed: 0,
      valueUSD: 0,
    },
  },
  
  // Initialize enhanced metrics
  aprMetrics: {
    current: 0,
    average7d: 0,
    average30d: 0,
    volatilityAdjusted: 0,
    projected: 0,
    confidenceLevel: 0,
    breakdown: {
      tradingFees: 0,
      arbitrageProfits: 0,
      liquidationFees: 0,
      yieldFarming: 0,
      compoundBonus: 0,
    },
    historicalData: {
      timestamps: [],
      values: [],
      volatility: [],
    },
  },
  
  revenueMetrics: {
    totalEarned: 0,
    pendingRewards: 0,
    lifetimeRewards: 0,
    lastClaimed: null,
    sourceBreakdown: {
      tradingFees: 0,
      arbitrageProfits: 0,
      liquidationFees: 0,
      yieldFarming: 0,
      partnershipFees: 0,
      performanceFees: 0,
    },
    projectedDaily: 0,
    projectedWeekly: 0,
    projectedMonthly: 0,
    revenueGrowthRate: 0,
  },
  
  automationStatus: {
    isEnabled: true,
    inEmergencyMode: false,
    activeTasks: 0,
    totalExecutions: 0,
    successRate: 0,
    averageGas: 0,
    uptime: 0,
    lastExecution: null,
    nextScheduledTasks: [],
    marketCondition: {
      volatilityIndex: 0,
      liquidityLevel: 0,
      riskLevel: 0,
      emergencyMode: false,
    },
  },
  
  riskMetrics: {
    sharpeRatio: 0,
    maxDrawdown: 0,
    volatilityIndex: 0,
    consistencyScore: 0,
    liquidityRisk: 0,
    overallRiskLevel: 0,
    riskAdjustedReturn: 0,
    valueAtRisk: 0,
  },
  
  ulpData: {
    totalShares: 0,
    userShares: 0,
    sharePrice: 1,
    totalValue: 0,
    capitalEfficiency: 0,
    lastRebalance: null,
    nextRebalance: null,
    rebalanceThreshold: 5, // 5% default
    tokenAllocations: {},
    performanceMetrics: {
      totalReturn: 0,
      annualizedReturn: 0,
      volatility: 0,
      sharpeRatio: 0,
    },
  },
  
  performance: {
    totalReturn: 0,
    totalReturnPercentage: 0,
    dailyPnL: 0,
    weeklyPnL: 0,
    monthlyPnL: 0,
    yearlyPnL: 0,
    bestDay: { date: 0, return: 0, percentage: 0 },
    worstDay: { date: 0, return: 0, percentage: 0 },
    winRate: 0,
    averageDailyReturn: 0,
    maxConsecutiveWins: 0,
    maxConsecutiveLosses: 0,
    calmarRatio: 0,
  },
  
  // Loading states
  isLoadingAPR: false,
  isLoadingRevenue: false,
  isLoadingAutomation: false,
  isLoadingULP: false,
  
  // Error states
  errors: {},
  
  // Default settings
  settings: {
    autoCompound: true,
    compoundFrequency: 6, // 6 hours
    riskTolerance: 5, // Medium risk
    rebalanceThreshold: 5, // 5%
    emergencyStopEnabled: true,
    notificationsEnabled: true,
  },
}

function recalculatePortfolioState(positions: Position[], coreHoldings: number, ulpData?: ULPData): Partial<PortfolioState> {
  const newBalances: { [tokenSymbol: string]: TokenBalance } = {}

  // Initialize balances for all known tokens to zero
  Object.keys(tokens).forEach((symbol) => {
    newBalances[symbol] = { total: 0, collateralized: 0, available: 0, borrowed: 0, valueUSD: 0 }
  })

  // First pass: Calculate totals and borrowed amounts
  positions.forEach((pos) => {
    const tokenSymbol = pos.token
    if (!newBalances[tokenSymbol]) {
      // Fallback for unknown tokens
      newBalances[tokenSymbol] = { total: 0, collateralized: 0, available: 0, borrowed: 0, valueUSD: 0 }
    }

    if (pos.type === "deposit" || pos.type === "vault") {
      // Add to total deposits
      newBalances[tokenSymbol].total += pos.amount

      // If it's collateral, add to collateralized amount
      if (pos.isCollateral) {
        newBalances[tokenSymbol].collateralized += pos.amount
      }
    } else if (pos.type === "borrow") {
      // Borrowed assets increase total and borrowed amounts
      newBalances[tokenSymbol].total += pos.amount
      newBalances[tokenSymbol].borrowed += pos.amount
    }
  })

  // Second pass: Calculate available balance and USD values
  Object.keys(newBalances).forEach((symbol) => {
    const tokenData = getTokenData(symbol)
    // Available = total - collateralized
    newBalances[symbol].available = Math.max(0, newBalances[symbol].total - newBalances[symbol].collateralized)
    // Calculate USD value based on total amount
    newBalances[symbol].valueUSD = newBalances[symbol].total * tokenData.price
  })

  // Calculate total USD values from positions
  let totalDepositsUSD = 0
  let totalBorrowsUSD = 0
  let totalVaultValueUSD = 0
  let totalULPValueUSD = 0

  positions.forEach((pos) => {
    if (pos.type === "deposit") {
      totalDepositsUSD += pos.valueUSD
    } else if (pos.type === "borrow") {
      totalBorrowsUSD += pos.valueUSD
    } else if (pos.type === "vault") {
      totalVaultValueUSD += pos.valueUSD
    } else if (pos.type === "ulp") {
      totalULPValueUSD += pos.valueUSD
    }
  })

  const coreTokenData = getTokenData("CORE")
  const coreValueUSD = coreHoldings * coreTokenData.price

  const totalValueUSD = totalDepositsUSD + totalVaultValueUSD + totalULPValueUSD + coreValueUSD
  const netWorthUSD = totalValueUSD - totalBorrowsUSD

  // Calculate health factor: (collateral value * liquidation threshold) / borrowed value
  const collateralValueUSD = positions
    .filter((pos) => pos.type === "deposit" && pos.isCollateral)
    .reduce((sum, pos) => sum + pos.valueUSD, 0)

  const healthFactor = totalBorrowsUSD > 0 ? (collateralValueUSD * 0.8) / totalBorrowsUSD : 0

  return {
    totalDepositsUSD,
    totalBorrowsUSD,
    totalVaultValueUSD,
    totalULPValueUSD,
    totalValueUSD,
    netWorthUSD,
    healthFactor,
    balances: newBalances,
  }
}

function portfolioReducer(state: PortfolioState, action: PortfolioAction): PortfolioState {
  switch (action.type) {
    case "CONNECT_WALLET": {
      const updatedState = recalculatePortfolioState(state.positions, state.coreHoldings, state.ulpData)
      return {
        ...state,
        isWalletConnected: true,
        accountAddress: action.payload.address,
        ...updatedState,
      }
    }

    case "DISCONNECT_WALLET":
      return {
        ...initialState,
      }

    case "ADD_POSITION": {
      const newPositions = [...state.positions, action.payload]
      const updatedState = recalculatePortfolioState(newPositions, state.coreHoldings, state.ulpData)

      // Create a transaction record for the new position
      const transaction: Transaction = {
        id: `tx-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
        type: action.payload.type,
        status: "completed",
        amount: action.payload.amount,
        token: action.payload.token,
        valueUSD: action.payload.valueUSD,
        timestamp: action.payload.timestamp,
        hash: `0x${Math.random().toString(16).substr(2, 64)}`,
      }

      // Create recent activity record
      const recentActivity: RecentActivity = {
        id: `activity-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
        type: action.payload.type === "vault" ? "deposit" : action.payload.type,
        status: "completed",
        amount: action.payload.amount,
        token: action.payload.token,
        valueUSD: action.payload.valueUSD,
        timestamp: action.payload.timestamp,
        hash: transaction.hash,
      }

      return {
        ...state,
        positions: newPositions,
        transactions: [transaction, ...state.transactions],
        recentActivities: [recentActivity, ...state.recentActivities.slice(0, 19)],
        ...updatedState,
      }
    }

    case "REMOVE_POSITION": {
      const newPositions = state.positions.filter((p) => p.id !== action.payload.id)
      const updatedState = recalculatePortfolioState(newPositions, state.coreHoldings, state.ulpData)
      return {
        ...state,
        positions: newPositions,
        ...updatedState,
      }
    }

    case "UPDATE_POSITION": {
      const newPositions = state.positions.map((p) =>
        p.id === action.payload.id ? { ...p, ...action.payload.updates } : p,
      )
      const updatedState = recalculatePortfolioState(newPositions, state.coreHoldings, state.ulpData)
      return {
        ...state,
        positions: newPositions,
        ...updatedState,
      }
    }

    case "ADD_TRANSACTION": {
      return {
        ...state,
        transactions: [action.payload, ...state.transactions],
      }
    }

    case "UPDATE_TRANSACTION": {
      const newTransactions = state.transactions.map((tx) =>
        tx.id === action.payload.id ? { ...tx, ...action.payload.updates } : tx,
      )
      return {
        ...state,
        transactions: newTransactions,
      }
    }

    case "ADD_RECENT_ACTIVITY": {
      return {
        ...state,
        recentActivities: [action.payload, ...state.recentActivities.slice(0, 19)],
      }
    }

    case "SET_CORE_HOLDINGS": {
      const updatedState = recalculatePortfolioState(state.positions, action.payload.amount, state.ulpData)
      return {
        ...state,
        coreHoldings: action.payload.amount,
        ...updatedState,
      }
    }

    case "UPDATE_TOKEN_BALANCE": {
      const tokenData = getTokenData(action.payload.symbol)
      const updatedBalances = {
        ...state.balances,
        [action.payload.symbol]: {
          ...state.balances[action.payload.symbol],
          total: action.payload.balance,
          available: Math.max(0, action.payload.balance - (state.balances[action.payload.symbol]?.collateralized || 0)),
          valueUSD: action.payload.balance * tokenData.price,
        },
      }
      return {
        ...state,
        balances: updatedBalances,
      }
    }

    // New action handlers for enhanced functionality
    case "UPDATE_APR_METRICS":
      return {
        ...state,
        aprMetrics: action.payload,
        isLoadingAPR: false,
      }

    case "UPDATE_REVENUE_METRICS":
      return {
        ...state,
        revenueMetrics: action.payload,
        isLoadingRevenue: false,
      }

    case "UPDATE_AUTOMATION_STATUS":
      return {
        ...state,
        automationStatus: action.payload,
        isLoadingAutomation: false,
      }

    case "UPDATE_RISK_METRICS":
      return {
        ...state,
        riskMetrics: action.payload,
      }

    case "UPDATE_ULP_DATA": {
      const updatedState = recalculatePortfolioState(state.positions, state.coreHoldings, action.payload)
      return {
        ...state,
        ulpData: action.payload,
        isLoadingULP: false,
        ...updatedState,
      }
    }

    case "UPDATE_PERFORMANCE":
      return {
        ...state,
        performance: action.payload,
      }

    case "SET_LOADING":
      return {
        ...state,
        [`isLoading${action.payload.key.charAt(0).toUpperCase() + action.payload.key.slice(1)}`]: action.payload.loading,
      }

    case "SET_ERROR":
      return {
        ...state,
        errors: {
          ...state.errors,
          [action.payload.key]: action.payload.error,
        },
      }

    case "UPDATE_SETTINGS":
      return {
        ...state,
        settings: {
          ...state.settings,
          ...action.payload,
        },
      }

    case "EXECUTE_COMPOUND": {
      // Add compound transaction
      const compoundTransaction: Transaction = {
        id: `compound-${Date.now()}`,
        type: "compound",
        status: "completed",
        amount: action.payload.amount,
        token: "ULP",
        valueUSD: action.payload.amount,
        timestamp: Date.now(),
        automationTriggered: true,
      }

      const compoundActivity: RecentActivity = {
        id: `activity-compound-${Date.now()}`,
        type: "compound",
        status: "completed",
        amount: action.payload.amount,
        token: "ULP",
        valueUSD: action.payload.amount,
        timestamp: Date.now(),
        description: "Automated compound executed",
      }

      return {
        ...state,
        transactions: [compoundTransaction, ...state.transactions.slice(0, 49)],
        recentActivities: [compoundActivity, ...state.recentActivities.slice(0, 9)],
      }
    }

    case "EXECUTE_REBALANCE": {
      const rebalanceActivity: RecentActivity = {
        id: `activity-rebalance-${Date.now()}`,
        type: "rebalance",
        status: "completed",
        amount: 0,
        token: "ULP",
        valueUSD: 0,
        timestamp: action.payload.timestamp,
        description: `Automated rebalance executed (Gas: ${action.payload.gasUsed})`,
      }

      return {
        ...state,
        recentActivities: [rebalanceActivity, ...state.recentActivities.slice(0, 9)],
        ulpData: {
          ...state.ulpData,
          lastRebalance: action.payload.timestamp,
        },
      }
    }

    case "CLAIM_REVENUE": {
      const claimTransaction: Transaction = {
        id: `revenue-claim-${Date.now()}`,
        type: "revenue_claim",
        status: "completed",
        amount: action.payload.amount,
        token: action.payload.token,
        valueUSD: action.payload.amount,
        timestamp: Date.now(),
        revenueSource: action.payload.source,
      }

      const claimActivity: RecentActivity = {
        id: `activity-revenue-${Date.now()}`,
        type: "revenue_distribution",
        status: "completed",
        amount: action.payload.amount,
        token: action.payload.token,
        valueUSD: action.payload.amount,
        timestamp: Date.now(),
        description: `Revenue claimed from ${action.payload.source}`,
      }

      return {
        ...state,
        transactions: [claimTransaction, ...state.transactions.slice(0, 49)],
        recentActivities: [claimActivity, ...state.recentActivities.slice(0, 9)],
        revenueMetrics: {
          ...state.revenueMetrics,
          lastClaimed: Date.now(),
          pendingRewards: Math.max(0, state.revenueMetrics.pendingRewards - action.payload.amount),
          lifetimeRewards: state.revenueMetrics.lifetimeRewards + action.payload.amount,
        },
      }
    }

    case "EMERGENCY_STOP": {
      const emergencyActivity: RecentActivity = {
        id: `activity-emergency-${Date.now()}`,
        type: "automation_executed",
        status: "completed",
        amount: 0,
        token: "SYSTEM",
        valueUSD: 0,
        timestamp: action.payload.timestamp,
        description: `Emergency stop triggered: ${action.payload.reason}`,
      }

      return {
        ...state,
        automationStatus: {
          ...state.automationStatus,
          inEmergencyMode: true,
          isEnabled: false,
        },
        recentActivities: [emergencyActivity, ...state.recentActivities.slice(0, 9)],
      }
    }

    case "START_TRANSACTION": {
      const transaction: Transaction = {
        id: action.payload.id,
        type: action.payload.type,
        status: "pending",
        amount: action.payload.amount,
        token: action.payload.token,
        valueUSD: action.payload.valueUSD,
        timestamp: Date.now(),
      }
      
      return {
        ...state,
        transactions: [transaction, ...state.transactions],
        recentActivities: [
          {
            id: `activity-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
            type: action.payload.type === "vault" ? "deposit" : action.payload.type,
            status: "pending",
            amount: action.payload.amount,
            token: action.payload.token,
            valueUSD: action.payload.valueUSD,
            timestamp: Date.now(),
            description: `${action.payload.type} transaction initiated`,
          },
          ...state.recentActivities.slice(0, 19),
        ],
      }
    }

    case "COMPLETE_TRANSACTION": {
      const updatedTransactions = state.transactions.map(tx => 
        tx.id === action.payload.id 
          ? { ...tx, status: "completed" as const, hash: action.payload.hash, gasUsed: action.payload.gasUsed }
          : tx
      )
      
      const updatedActivities = state.recentActivities.map(activity => 
        activity.hash === action.payload.hash || activity.timestamp === action.payload.timestamp
          ? { ...activity, status: "completed" as const, hash: action.payload.hash }
          : activity
      )
      
      return {
        ...state,
        transactions: updatedTransactions,
        recentActivities: updatedActivities,
      }
    }

    case "FAIL_TRANSACTION": {
      const updatedTransactions = state.transactions.map(tx => 
        tx.id === action.payload.id 
          ? { ...tx, status: "failed" as const }
          : tx
      )
      
      const updatedActivities = state.recentActivities.map(activity => 
        activity.id === action.payload.activityId
          ? { ...activity, status: "failed" as const, description: action.payload.error }
          : activity
      )
      
      return {
        ...state,
        transactions: updatedTransactions,
        recentActivities: updatedActivities,
        errors: {
          ...state.errors,
          general: action.payload.error,
        },
      }
    }

    default:
      return state
  }
}

const PortfolioContext = createContext<{
  state: PortfolioState
  dispatch: React.Dispatch<PortfolioAction>
} | null>(null)

export function PortfolioProvider({ children }: { children: ReactNode }) {
  const [state, dispatch] = useReducer(portfolioReducer, initialState)

  return <PortfolioContext.Provider value={{ state, dispatch }}>{children}</PortfolioContext.Provider>
}

export function usePortfolio() {
  const context = useContext(PortfolioContext)
  if (!context) {
    throw new Error("usePortfolio must be used within a PortfolioProvider")
  }
  return context
}
