// React hook for CoreFluidX contract integration
import { useState, useEffect, useCallback, useRef } from 'react'
import { ethers } from 'ethers'
import { usePortfolio } from '../contexts/portfolio-context'
import { CoreFluidXContracts } from '../lib/contracts'
import { toast } from 'sonner'

// Extend Window interface to include ethereum
declare global {
  interface Window {
    ethereum?: any
  }
}

interface UseCoreFluidXOptions {
  autoRefresh?: boolean
  refreshInterval?: number // in milliseconds
  enableEventListeners?: boolean
}

interface UseCoreFluidXReturn {
  contracts: CoreFluidXContracts | null
  isLoading: boolean
  loading: boolean // alias for isLoading
  error: string | null
  
  // ULP Operations
  depositToULP: (token: string, amount: string) => Promise<void>
  withdrawFromULP: (token: string, amount: string) => Promise<void>
  refreshULPData: () => Promise<void>
  
  // Revenue Operations
  claimRevenue: () => Promise<void>
  refreshRevenueData: () => Promise<void>
  
  // Automation Operations
  emergencyStop: () => Promise<void>
  refreshAutomationStatus: () => Promise<void>
  
  // Compound Operations
  setCompoundConfig: (frequency: number, autoCompound: boolean) => Promise<void>
  executeManualCompound: () => Promise<void>
  
  // Rebalance Operations
  executeManualRebalance: () => Promise<void>
  getRebalancingData: () => Promise<any>
  pauseRebalancing: () => Promise<void>
  resumeRebalancing: () => Promise<void>
  
  // Data Refresh
  refreshAllData: () => Promise<void>
  
  // Real-time status
  isTransactionPending: boolean
  lastUpdateTime: number | null
  
  // Analytics Data
  aprMetrics?: {
         currentAPR: number
         projectedAPR: number
         totalAPR?: number
         baseAPR?: number
         boostAPR?: number
         monthlyAverage?: number
         weeklyAverage?: number
         allTimeHigh?: number
       }
  revenueMetrics?: {
      totalEarned: number
      pendingRewards: number
      liquidationRewards?: number
      protocolRewards?: number
      stakingRewards?: number
      tradingFees?: number
      yieldFarming?: number
      lendingInterest?: number
    }
  automationStatus?: {
    isHealthy: boolean
    activeTasks: number
    lastExecution?: number
    emergencyMode?: boolean
  }
  riskMetrics?: {
    utilizationRatio: number
    sharpeRatio: number
    valueAtRisk: number
    maxDrawdown: number
    volatility: number
    riskScore: number
  }
  ulpData?: {
    totalValue: number
    utilizationRatio: number
    capitalEfficiency: number
    activePools?: number
  }
  performance?: {
        dailyReturn: number
        weeklyReturn?: number
        monthlyReturn?: number
        totalReturn?: number
        winRate: number
      }
}

export const useCoreFluidX = (options: UseCoreFluidXOptions = {}): UseCoreFluidXReturn => {
  const {
    autoRefresh = true,
    refreshInterval = 30000, // 30 seconds
    enableEventListeners = true,
  } = options

  const { state, dispatch } = usePortfolio()
  const [contracts, setContracts] = useState<CoreFluidXContracts | null>(null)
  const [isLoading, setIsLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [isTransactionPending, setIsTransactionPending] = useState(false)
  const [lastUpdateTime, setLastUpdateTime] = useState<number | null>(null)
  
  const refreshIntervalRef = useRef<NodeJS.Timeout | null>(null)
  const contractsRef = useRef<CoreFluidXContracts | null>(null)

  // Initialize contracts
  useEffect(() => {
    const initializeContracts = async () => {
      try {
        if (typeof window !== 'undefined' && window.ethereum) {
          const provider = new ethers.BrowserProvider(window.ethereum)
          const signer = await provider.getSigner()
          const contractInstance = new CoreFluidXContracts(provider, signer)
          
          setContracts(contractInstance)
          contractsRef.current = contractInstance
          
          if (enableEventListeners) {
            setupEventListeners(contractInstance)
          }
        }
      } catch (err) {
        console.error('Failed to initialize contracts:', err)
        setError('Failed to initialize contracts')
      }
    }

    if (state.isWalletConnected) {
      initializeContracts()
    }

    return () => {
      if (contractsRef.current) {
        contractsRef.current.removeAllListeners()
      }
    }
  }, [state.isWalletConnected, enableEventListeners])

  // Setup event listeners
  const setupEventListeners = useCallback((contractInstance: CoreFluidXContracts) => {
    contractInstance.setupEventListeners({
      onDeposit: (event) => {
        toast.success(`Deposit successful: ${ethers.formatEther(event.amount)} ${event.token}`)
        refreshULPData()
      },
      
      onWithdraw: (event) => {
        toast.success(`Withdrawal successful: ${ethers.formatEther(event.amount)} tokens`)
        refreshULPData()
      },
      
      onRebalance: (event) => {
        dispatch({
          type: 'EXECUTE_REBALANCE',
          payload: {
            timestamp: Number(event.timestamp) * 1000,
            gasUsed: Number(event.gasUsed),
          },
        })
        toast.info('Portfolio rebalanced automatically')
        refreshULPData()
      },
      
      onCompound: (event) => {
        dispatch({
          type: 'EXECUTE_COMPOUND',
          payload: {
            positionId: 'ulp-main',
            amount: Number(ethers.formatEther(event.amount)),
          },
        })
        toast.success(`Compound executed: ${ethers.formatEther(event.amount)} tokens`)
        refreshULPData()
      },
      
      onRevenueDistribution: (event) => {
        dispatch({
          type: 'CLAIM_REVENUE',
          payload: {
            amount: Number(ethers.formatEther(event.amount)),
            token: 'CORE',
            source: event.source,
          },
        })
        toast.success(`Revenue distributed: ${ethers.formatEther(event.amount)} CORE`)
        refreshRevenueData()
      },
      

      

    })
  }, [dispatch])

  // Auto refresh data
  useEffect(() => {
    if (autoRefresh && contracts && state.isWalletConnected) {
      const startAutoRefresh = () => {
        refreshIntervalRef.current = setInterval(() => {
          refreshAllData()
        }, refreshInterval)
      }

      startAutoRefresh()
      // Initial data load
      refreshAllData()

      return () => {
        if (refreshIntervalRef.current) {
          clearInterval(refreshIntervalRef.current)
        }
      }
    }
  }, [autoRefresh, contracts, state.isWalletConnected, refreshInterval])

  // ULP Operations
  const depositToULP = useCallback(async (token: string, amount: string) => {
    if (!contracts) {
      toast.error('Contracts not initialized')
      return
    }

    try {
      setIsTransactionPending(true)
      dispatch({ type: 'SET_LOADING', payload: { key: 'ulp', loading: true } })
      
      const tx = await contracts.depositToULP(token, amount)
      console.log(`🔄 Deposit Transaction Hash: ${tx.hash}`)
      toast.info(`Transaction submitted: ${tx.hash.slice(0, 10)}...`)
      
      const receipt = await tx.wait()
      console.log(`✅ Deposit Confirmed - Block: ${receipt?.blockNumber || 'unknown'}, Gas Used: ${receipt?.gasUsed?.toString() || 'unknown'}`)
      toast.success(`Deposit successful! Tx: ${tx.hash.slice(0, 10)}...`)
      
      // Refresh data after successful transaction
      await refreshULPData()
      
    } catch (err: any) {
      console.error('❌ Deposit failed:', err)
      toast.error(`Deposit failed: ${err.message || 'Unknown error'}`)
      dispatch({ type: 'SET_ERROR', payload: { key: 'ulp', error: err.message } })
    } finally {
      setIsTransactionPending(false)
      dispatch({ type: 'SET_LOADING', payload: { key: 'ulp', loading: false } })
    }
  }, [contracts, dispatch])

  const withdrawFromULP = useCallback(async (token: string, amount: string) => {
    if (!contracts) {
      toast.error('Contracts not initialized')
      return
    }

    try {
      setIsTransactionPending(true)
      dispatch({ type: 'SET_LOADING', payload: { key: 'ulp', loading: true } })
      
      const tx = await contracts.withdrawFromULP(token, amount)
      console.log(`🔄 Withdraw Transaction Hash: ${tx.hash}`)
      toast.info(`Transaction submitted: ${tx.hash.slice(0, 10)}...`)
      
      const receipt = await tx.wait()
      console.log(`✅ Withdraw Confirmed - Block: ${receipt?.blockNumber || 'unknown'}, Gas Used: ${receipt?.gasUsed?.toString() || 'unknown'}`)
      toast.success(`Withdrawal successful! Tx: ${tx.hash.slice(0, 10)}...`)
      
      await refreshULPData()
      
    } catch (err: any) {
      console.error('❌ Withdrawal failed:', err)
      toast.error(`Withdrawal failed: ${err.message || 'Unknown error'}`)
      dispatch({ type: 'SET_ERROR', payload: { key: 'ulp', error: err.message } })
    } finally {
      setIsTransactionPending(false)
      dispatch({ type: 'SET_LOADING', payload: { key: 'ulp', loading: false } })
    }
  }, [contracts, dispatch])

  const refreshULPData = useCallback(async () => {
    if (!contracts || !state.accountAddress) return

    try {
      dispatch({ type: 'SET_LOADING', payload: { key: 'ulp', loading: true } })
      const ulpData = await contracts.getULPData(state.accountAddress)
      dispatch({ type: 'UPDATE_ULP_DATA', payload: ulpData })
      setLastUpdateTime(Date.now())
    } catch (err: any) {
      console.error('Failed to refresh ULP data:', err)
      dispatch({ type: 'SET_ERROR', payload: { key: 'ulp', error: err.message } })
    } finally {
      dispatch({ type: 'SET_LOADING', payload: { key: 'ulp', loading: false } })
    }
  }, [contracts, state.accountAddress, dispatch])

  // Revenue Operations
  const claimRevenue = useCallback(async () => {
    if (!contracts || !state.accountAddress) {
      toast.error('Contracts not initialized or wallet not connected')
      return
    }

    try {
      setIsTransactionPending(true)
      dispatch({ type: 'SET_LOADING', payload: { key: 'revenue', loading: true } })
      
      const tx = await contracts.claimRevenue()
      console.log(`🔄 Claim Revenue Transaction Hash: ${tx.hash}`)
      toast.info(`Transaction submitted: ${tx.hash.slice(0, 10)}...`)
      
      const receipt = await tx.wait()
      console.log(`✅ Revenue Claim Confirmed - Block: ${receipt?.blockNumber || 'unknown'}, Gas Used: ${receipt?.gasUsed?.toString() || 'unknown'}`)
      toast.success(`Revenue claimed successfully! Tx: ${tx.hash.slice(0, 10)}...`)
      
      await refreshRevenueData()
      
    } catch (err: any) {
      console.error('❌ Revenue claim failed:', err)
      toast.error(`Revenue claim failed: ${err.message || 'Unknown error'}`)
      dispatch({ type: 'SET_ERROR', payload: { key: 'revenue', error: err.message } })
    } finally {
      setIsTransactionPending(false)
      dispatch({ type: 'SET_LOADING', payload: { key: 'revenue', loading: false } })
    }
  }, [contracts, state.accountAddress, dispatch])

  const refreshRevenueData = useCallback(async () => {
    if (!contracts || !state.accountAddress) return

    try {
      dispatch({ type: 'SET_LOADING', payload: { key: 'revenue', loading: true } })
      const revenueData = await contracts.getRevenueMetrics(state.accountAddress)
      dispatch({ type: 'UPDATE_REVENUE_METRICS', payload: revenueData })
      setLastUpdateTime(Date.now())
    } catch (err: any) {
      console.error('Failed to refresh revenue data:', err)
      dispatch({ type: 'SET_ERROR', payload: { key: 'revenue', error: err.message } })
    } finally {
      dispatch({ type: 'SET_LOADING', payload: { key: 'revenue', loading: false } })
    }
  }, [contracts, state.accountAddress, dispatch])

  // Automation Operations
  const emergencyStop = useCallback(async () => {
    if (!contracts) {
      toast.error('Contracts not initialized')
      return
    }

    try {
      setIsTransactionPending(true)
      
      const reason = 'Manual emergency stop triggered'
      const tx = await contracts.emergencyStop(reason)
      toast.info('Emergency stop submitted, waiting for confirmation...')
      
      await tx.wait()
      toast.success('Emergency stop executed!')
      
      await refreshAutomationStatus()
      
    } catch (err: any) {
      console.error('Emergency stop failed:', err)
      toast.error(`Emergency stop failed: ${err.message || 'Unknown error'}`)
    } finally {
      setIsTransactionPending(false)
    }
  }, [contracts])

  const refreshAutomationStatus = useCallback(async () => {
    if (!contracts) return

    try {
      dispatch({ type: 'SET_LOADING', payload: { key: 'automation', loading: true } })
      const automationData = await contracts.getAutomationStatus()
      dispatch({ type: 'UPDATE_AUTOMATION_STATUS', payload: automationData })
      setLastUpdateTime(Date.now())
    } catch (err: any) {
      console.error('Failed to refresh automation status:', err)
      dispatch({ type: 'SET_ERROR', payload: { key: 'automation', error: err.message } })
    } finally {
      dispatch({ type: 'SET_LOADING', payload: { key: 'automation', loading: false } })
    }
  }, [contracts, dispatch])

  // Compound Operations
  const setCompoundConfig = useCallback(async (frequency: number, autoCompound: boolean) => {
    if (!contracts) {
      toast.error('Contracts not initialized')
      return
    }

    try {
      setIsTransactionPending(true)
      
      const tx = await contracts.setCompoundConfig(frequency, autoCompound)
      toast.info('Transaction submitted, waiting for confirmation...')
      
      await tx.wait()
      toast.success('Compound configuration updated!')
      
      // Update local settings
      dispatch({
        type: 'UPDATE_SETTINGS',
        payload: {
          autoCompound,
          compoundFrequency: frequency,
        },
      })
      
    } catch (err: any) {
      console.error('Set compound config failed:', err)
      toast.error(`Configuration update failed: ${err.message || 'Unknown error'}`)
    } finally {
      setIsTransactionPending(false)
    }
  }, [contracts, dispatch])

  const executeManualCompound = useCallback(async () => {
    if (!contracts || !state.accountAddress) {
      toast.error('Contracts not initialized or wallet not connected')
      return
    }

    try {
      setIsTransactionPending(true)
      
      const tx = await contracts.executeCompound(state.accountAddress)
      toast.info('Transaction submitted, waiting for confirmation...')
      
      await tx.wait()
      toast.success('Manual compound executed!')
      
      await refreshULPData()
      
    } catch (err: any) {
      console.error('Manual compound failed:', err)
      toast.error(`Manual compound failed: ${err.message || 'Unknown error'}`)
    } finally {
      setIsTransactionPending(false)
    }
  }, [contracts, state.accountAddress])

  // Rebalance Operations
  const executeManualRebalance = useCallback(async () => {
    if (!contracts) {
      toast.error('Contracts not initialized')
      return
    }

    try {
      setIsTransactionPending(true)
      
      const tx = await contracts.executeRebalance()
      toast.info('Transaction submitted, waiting for confirmation...')
      
      await tx.wait()
      toast.success('Manual rebalance executed!')
      
      await refreshULPData()
      
    } catch (err: any) {
      console.error('Manual rebalance failed:', err)
      toast.error(`Manual rebalance failed: ${err.message || 'Unknown error'}`)
    } finally {
      setIsTransactionPending(false)
    }
  }, [contracts])

  // Enhanced Rebalancing Operations
  const getRebalancingData = useCallback(async () => {
    if (!contracts) return null

    try {
      const rebalancingData = {
        isActive: true,
        isRebalancing: false,
        lastRebalance: Date.now() - 2 * 60 * 60 * 1000, // 2 hours ago
        nextRebalance: Date.now() + 2 * 60 * 60 * 1000, // 2 hours from now
        strategy: "Conservative",
        frequency: "Every 4 hours",
        totalRebalances: 47,
        emergencyPaused: false,
        currentActions: [
          {
            tokenFrom: "USDC",
            tokenTo: "ETH",
            amount: 5000,
            expectedReturn: 5250,
            riskScore: 25,
            status: "pending"
          },
          {
            tokenFrom: "DAI",
            tokenTo: "WBTC",
            amount: 3000,
            expectedReturn: 3150,
            riskScore: 35,
            status: "completed"
          }
        ],
        slippageProtection: {
          enabled: true,
          maxSlippage: 5.0, // 5%
          triggeredCount: 3
        }
      }
      return rebalancingData
    } catch (err: any) {
      console.error('Failed to get rebalancing data:', err)
      return null
    }
  }, [contracts])

  const pauseRebalancing = useCallback(async () => {
    if (!contracts) {
      toast.error('Contracts not initialized')
      return
    }

    try {
      setIsTransactionPending(true)
      
      const tx = await contracts.pauseRebalancing()
      toast.info('Transaction submitted, waiting for confirmation...')
      
      await tx.wait()
      toast.success('Rebalancing paused!')
      
      await refreshAutomationStatus()
      
    } catch (err: any) {
      console.error('Pause rebalancing failed:', err)
      toast.error(`Pause rebalancing failed: ${err.message || 'Unknown error'}`)
    } finally {
      setIsTransactionPending(false)
    }
  }, [contracts])

  const resumeRebalancing = useCallback(async () => {
    if (!contracts) {
      toast.error('Contracts not initialized')
      return
    }

    try {
      setIsTransactionPending(true)
      
      const tx = await contracts.resumeRebalancing()
      toast.info('Transaction submitted, waiting for confirmation...')
      
      await tx.wait()
      toast.success('Rebalancing resumed!')
      
      await refreshAutomationStatus()
      
    } catch (err: any) {
      console.error('Resume rebalancing failed:', err)
      toast.error(`Resume rebalancing failed: ${err.message || 'Unknown error'}`)
    } finally {
      setIsTransactionPending(false)
    }
  }, [contracts])

  // Refresh all data
  const refreshAllData = useCallback(async () => {
    if (!contracts || !state.accountAddress) return

    try {
      setIsLoading(true)
      setError(null)
      
      // Fetch all data in parallel
      const [aprData, revenueData, automationData, ulpData, riskData, performanceData] = await Promise.allSettled([
        contracts.getAPRMetrics(),
        contracts.getRevenueMetrics(state.accountAddress),
        contracts.getAutomationStatus(),
        contracts.getULPData(state.accountAddress),
        contracts.getRiskMetrics(state.accountAddress),
        contracts.getPerformanceData(state.accountAddress),
      ])

      // Update state with successful results
      if (aprData.status === 'fulfilled') {
        dispatch({ type: 'UPDATE_APR_METRICS', payload: aprData.value })
      }
      
      if (revenueData.status === 'fulfilled') {
        dispatch({ type: 'UPDATE_REVENUE_METRICS', payload: revenueData.value })
      }
      
      if (automationData.status === 'fulfilled') {
        dispatch({ type: 'UPDATE_AUTOMATION_STATUS', payload: automationData.value })
      }
      
      if (ulpData.status === 'fulfilled') {
        dispatch({ type: 'UPDATE_ULP_DATA', payload: ulpData.value })
      }
      
      if (riskData.status === 'fulfilled') {
        dispatch({ type: 'UPDATE_RISK_METRICS', payload: riskData.value })
      }
      
      if (performanceData.status === 'fulfilled') {
        dispatch({ type: 'UPDATE_PERFORMANCE', payload: performanceData.value })
      }

      setLastUpdateTime(Date.now())
      
    } catch (err: any) {
      console.error('Failed to refresh all data:', err)
      setError(err.message || 'Failed to refresh data')
    } finally {
      setIsLoading(false)
    }
  }, [contracts, state.accountAddress, dispatch])

  return {
    contracts,
    isLoading,
    loading: isLoading, // alias for compatibility
    error,
    
    // ULP Operations
    depositToULP,
    withdrawFromULP,
    refreshULPData,
    
    // Revenue Operations
    claimRevenue,
    refreshRevenueData,
    
    // Automation Operations
    emergencyStop,
    refreshAutomationStatus,
    
    // Compound Operations
    setCompoundConfig,
    executeManualCompound,
    
    // Rebalance Operations
    executeManualRebalance,
    getRebalancingData,
    pauseRebalancing,
    resumeRebalancing,
    
    // Data Refresh
    refreshAllData,
    
    // Real-time status
    isTransactionPending,
    lastUpdateTime,
    
    // Analytics Data (mock data for now)
    aprMetrics: {
           currentAPR: 12.5,
           projectedAPR: 14.2,
           totalAPR: 13.8,
           baseAPR: 10.2,
           boostAPR: 2.3,
           monthlyAverage: 11.8,
           weeklyAverage: 12.1,
           allTimeHigh: 18.9
         },
    revenueMetrics: {
        totalEarned: 1250.75,
        pendingRewards: 45.32,
        liquidationRewards: 125.50,
        protocolRewards: 89.25,
        stakingRewards: 234.80,
        tradingFees: 67.45,
        yieldFarming: 156.90,
        lendingInterest: 198.75
      },
    automationStatus: {
      isHealthy: true,
      activeTasks: 3,
      lastExecution: Date.now() - 30000,
      emergencyMode: false
    },
    riskMetrics: {
      utilizationRatio: 0.65,
      sharpeRatio: 1.8,
      valueAtRisk: 0.05,
      maxDrawdown: 0.12,
      volatility: 0.18,
      riskScore: 75
    },
    ulpData: {
      totalValue: 25000,
      utilizationRatio: 0.78,
      capitalEfficiency: 0.85,
      activePools: 8
    },
    performance: {
        dailyReturn: 0.0025,
        weeklyReturn: 0.032,
        monthlyReturn: 0.089,
        totalReturn: 0.156,
        winRate: 0.72
      }
  }
}

export default useCoreFluidX