"use client"

import { useState, useEffect } from "react"
import { CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Separator } from "@/components/ui/separator"
import { TrendingUp, Shield, Zap, Wallet } from "lucide-react"
import { NeonCard } from "@/components/neon-card"
import { CyberButton } from "@/components/cyber-button"
import { GlitchText } from "@/components/glitch-text"
import { usePortfolio } from "@/contexts/portfolio-context"
import { useToast } from "@/hooks/use-toast"
import { useCoreFluidX } from "@/hooks/use-corefluidx"
import { useAccount, useBalance } from "wagmi"
import { CONTRACT_ADDRESSES } from "@/lib/wagmi"
import { tokens, getTokenData, formatCurrency, TokenData } from "@/lib/token-data"

export default function DepositPage() {
  const { state, dispatch } = usePortfolio()
  const { toast } = useToast()
  const { address, isConnected } = useAccount()
  const { data: balance } = useBalance({ address })
  const {
    contracts,
    isLoading: contractsLoading,
    depositToULP,
    isTransactionPending
  } = useCoreFluidX()
  
  const [selectedToken, setSelectedToken] = useState("CORE")
  const [depositAmount, setDepositAmount] = useState("")
  const [isProcessing, setIsProcessing] = useState(false)
  const [tokenBalance, setTokenBalance] = useState("0")
  const [needsApproval, setNeedsApproval] = useState(false)

  const selectedTokenData = getTokenData(selectedToken)
  const depositValueUSD = Number.parseFloat(depositAmount) * selectedTokenData.price || 0

  // Load token balance when token or address changes
  useEffect(() => {
    const loadBalance = async () => {
      if (address && contracts && selectedToken !== "CORE") {
        try {
          const tokenBalance = await contracts.getTokenBalance(address)
          setTokenBalance(tokenBalance)
        } catch (error) {
          console.error('Failed to load token balance:', error)
        }
      } else if (selectedToken === "CORE" && balance) {
        setTokenBalance(balance.formatted)
      }
    }
    
    loadBalance()
  }, [address, contracts, selectedToken, balance])

  const handleDeposit = async () => {
    if (!isConnected || !address) {
      toast({
        title: "Wallet Not Connected",
        description: "Please connect your wallet to make a deposit.",
        variant: "destructive",
      })
      return
    }

    if (!contracts) {
      toast({
        title: "Contracts Not Loaded",
        description: "Smart contracts are still loading. Please wait.",
        variant: "destructive",
      })
      return
    }

    if (!depositAmount || Number.parseFloat(depositAmount) <= 0) {
      toast({
        title: "Invalid Amount",
        description: "Please enter a valid deposit amount.",
        variant: "destructive",
      })
      return
    }

    const amount = Number.parseFloat(depositAmount)
    const availableBalance = Number.parseFloat(tokenBalance)
    
    if (amount > availableBalance) {
      toast({
        title: "Insufficient Balance",
        description: `You only have ${tokenBalance} ${selectedToken} available.`,
        variant: "destructive",
      })
      return
    }

    setIsProcessing(true)

    try {
      let txHash: string
      
      if (selectedToken === "CORE") {
        // For native CORE, stake directly to get stCORE
        const tx = await contracts.stakeCore(depositAmount)
        await tx.wait()
        txHash = tx.hash
        
        toast({
          title: "Staking Successful",
          description: `Successfully staked ${depositAmount} CORE for stCORE`,
        })
      } else if (selectedToken === "CLT") {
        // For CLT token, add to liquidity pool
        // First approve if needed
        const cltContract = contracts.getContract('coreLiquidToken')
        if (!cltContract) {
          throw new Error('CLT contract not available')
        }
        
        const allowance = await cltContract.allowance(address, CONTRACT_ADDRESSES.CORE_LIQUID_PROTOCOL)
        const amountWei = BigInt(Math.floor(amount * 1e18))
        
        if (allowance < amountWei) {
          const approveTx = await contracts.approveToken(CONTRACT_ADDRESSES.CORE_LIQUID_PROTOCOL, depositAmount)
          await approveTx.wait()
          
          toast({
            title: "Approval Successful",
            description: "Token approval completed. Now processing deposit...",
          })
        }
        
        const tx = await contracts.addLiquidity(depositAmount)
        await tx.wait()
        txHash = tx.hash
        
        toast({
          title: "Liquidity Added",
          description: `Successfully added ${depositAmount} CLT to liquidity pool`,
        })
      } else {
        // For other tokens, deposit to ULP
        const tokenAddress = selectedTokenData.address || CONTRACT_ADDRESSES.CORE_LIQUID_TOKEN
        await depositToULP(tokenAddress, depositAmount)
        txHash = 'simulated-hash' // depositToULP should return tx hash
        
        toast({
          title: "Deposit Successful",
          description: `Successfully deposited ${depositAmount} ${selectedToken} to Unified Liquidity Pool`,
        })
      }

      // Update portfolio state
      const newPosition = {
        id: `deposit-${Date.now()}`,
        type: "deposit" as const,
        token: selectedToken,
        amount: amount,
        valueUSD: depositValueUSD,
        apy: 8.5,
        timestamp: Date.now(),
        txHash,
      }

      dispatch({ type: "ADD_POSITION", payload: newPosition })
      
      // Reset form
      setDepositAmount("")
      
      // Refresh balance
      if (selectedToken === "CORE" && balance) {
        setTokenBalance(balance.formatted)
      } else if (contracts) {
        const newBalance = await contracts.getTokenBalance(address)
        setTokenBalance(newBalance)
      }
      
    } catch (error: any) {
      console.error('Deposit failed:', error)
      toast({
        title: "Deposit Failed",
        description: error.message || "Failed to process deposit. Please try again.",
        variant: "destructive",
      })
    } finally {
      setIsProcessing(false)
    }
  }

  return (
    <div className="space-y-6">
      <div className="text-center space-y-2">
        <GlitchText text="DEPOSIT_ASSETS" className="text-3xl font-bold text-cyan-400" />
        <p className="text-gray-400 font-mono">[EARN_YIELD_ON_YOUR_DIGITAL_ASSETS.EXE]</p>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <div className="lg:col-span-2 space-y-6">
          <NeonCard>
            <CardHeader>
              <CardTitle className="flex items-center gap-2 text-cyan-400 font-mono">
                <Zap className="w-5 h-5" />
                DEPOSIT_INTERFACE
              </CardTitle>
              <CardDescription className="font-mono text-gray-400">
                Select asset and amount to deposit into the liquidity pool
              </CardDescription>
            </CardHeader>
            <CardContent className="space-y-6">
              <div className="space-y-2">
                <Label htmlFor="token-select" className="text-cyan-400 font-mono">
                  SELECT_ASSET
                </Label>
                <Select value={selectedToken} onValueChange={setSelectedToken}>
                  <SelectTrigger className="bg-gray-900 border-cyan-500/30 text-white font-mono">
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent className="bg-gray-900 border-cyan-500/30">
                    {Object.entries(tokens).map(([symbol, data]) => {
                      const tokenData = data as TokenData;
                      return (
                        <SelectItem key={symbol} value={symbol} className="text-white font-mono">
                          <div className="flex items-center gap-2">
                            <span className="text-lg">{tokenData.icon}</span>
                            <span>{tokenData.symbol}</span>
                            <span className="text-gray-400">- {tokenData.name}</span>
                            <span className="text-cyan-400 ml-auto">{formatCurrency(tokenData.price)}</span>
                          </div>
                        </SelectItem>
                      );
                    })}
                  </SelectContent>
                </Select>
              </div>

              <div className="space-y-2">
                <Label htmlFor="amount" className="text-cyan-400 font-mono">
                  DEPOSIT_AMOUNT
                </Label>
                <div className="relative">
                  <Input
                    id="amount"
                    type="number"
                    placeholder="0.00"
                    value={depositAmount}
                    onChange={(e) => setDepositAmount(e.target.value)}
                    className="bg-gray-900 border-cyan-500/30 text-white font-mono text-lg pr-20"
                  />
                  <div className="absolute right-3 top-1/2 -translate-y-1/2 text-cyan-400 font-mono">
                    {selectedToken}
                  </div>
                </div>
                {depositValueUSD > 0 && (
                  <p className="text-sm text-gray-400 font-mono">≈ {formatCurrency(depositValueUSD)}</p>
                )}
              </div>

              <CyberButton
                onClick={handleDeposit}
                disabled={!isConnected || !contracts || !depositAmount || isProcessing || isTransactionPending || contractsLoading}
                className="w-full"
              >
                {!isConnected ? "CONNECT_WALLET" : 
                 contractsLoading ? "LOADING_CONTRACTS..." :
                 isProcessing || isTransactionPending ? "PROCESSING..." : 
                 "EXECUTE_DEPOSIT"}
              </CyberButton>
              
              {/* Wallet Connection Status */}
              {isConnected && address && (
                <div className="flex items-center justify-between text-sm font-mono">
                  <span className="text-gray-400">Wallet:</span>
                  <span className="text-cyan-400">{address.slice(0, 6)}...{address.slice(-4)}</span>
                </div>
              )}
              
              {/* Token Balance Display */}
              {selectedToken && tokenBalance && (
                <div className="flex items-center justify-between text-sm font-mono">
                  <span className="text-gray-400">Balance:</span>
                  <span className="text-cyan-400">{Number.parseFloat(tokenBalance).toFixed(4)} {selectedToken}</span>
                </div>
              )}
            </CardContent>
          </NeonCard>

          <NeonCard>
            <CardHeader>
              <CardTitle className="flex items-center gap-2 text-cyan-400 font-mono">
                <TrendingUp className="w-5 h-5" />
                YIELD_OPPORTUNITIES
              </CardTitle>
            </CardHeader>
            <CardContent>
              <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                {Object.entries(tokens)
                  .slice(0, 3)
                  .map(([symbol, data]) => {
                    const tokenData = data as TokenData;
                    return (
                      <div key={symbol} className="p-4 bg-gray-900/50 rounded-lg border border-cyan-500/20">
                        <div className="flex items-center gap-2 mb-2">
                          <span className="text-lg">{tokenData.icon}</span>
                          <span className="font-mono text-white">{symbol}</span>
                        </div>
                       <div className="space-y-1">
                         <div className="flex justify-between text-sm">
                           <span className="text-gray-400 font-mono">APY:</span>
                           <span className="text-green-400 font-mono">8.5%</span>
                         </div>
                         <div className="flex justify-between text-sm">
                           <span className="text-gray-400 font-mono">TVL:</span>
                           <span className="text-cyan-400 font-mono">$2.1M</span>
                         </div>
                       </div>
                     </div>
                   );
                 })}
              </div>
            </CardContent>
          </NeonCard>
        </div>

        <div className="space-y-6">
          <NeonCard>
            <CardHeader>
              <CardTitle className="flex items-center gap-2 text-cyan-400 font-mono">
                <Shield className="w-5 h-5" />
                DEPOSIT_PREVIEW
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="space-y-3">
                <div className="flex justify-between">
                  <span className="text-gray-400 font-mono">Asset:</span>
                  <span className="text-white font-mono">{selectedToken}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-gray-400 font-mono">Amount:</span>
                  <span className="text-white font-mono">{depositAmount || "0.00"}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-gray-400 font-mono">USD Value:</span>
                  <span className="text-cyan-400 font-mono">{formatCurrency(depositValueUSD)}</span>
                </div>
                <Separator className="bg-cyan-500/20" />
                <div className="flex justify-between">
                  <span className="text-gray-400 font-mono">Est. APY:</span>
                  <span className="text-green-400 font-mono">8.5%</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-gray-400 font-mono">Daily Earnings:</span>
                  <span className="text-green-400 font-mono">{formatCurrency((depositValueUSD * 0.085) / 365)}</span>
                </div>
              </div>

              <div className="p-3 bg-blue-500/10 rounded-lg border border-blue-500/20">
                <p className="text-xs text-blue-400 font-mono">
                  [INFO] Deposits are secured by multi-signature smart contracts and earn compound interest.
                </p>
              </div>
            </CardContent>
          </NeonCard>

          <NeonCard>
            <CardHeader>
              <CardTitle className="text-cyan-400 font-mono">PROTOCOL_STATS</CardTitle>
            </CardHeader>
            <CardContent className="space-y-3">
              <div className="flex justify-between">
                <span className="text-gray-400 font-mono">Total TVL:</span>
                <span className="text-cyan-400 font-mono">$12.5M</span>
              </div>
              <div className="flex justify-between">
                <span className="text-gray-400 font-mono">Active Users:</span>
                <span className="text-cyan-400 font-mono">2,847</span>
              </div>
              <div className="flex justify-between">
                <span className="text-gray-400 font-mono">Avg APY:</span>
                <span className="text-green-400 font-mono">8.2%</span>
              </div>
            </CardContent>
          </NeonCard>
        </div>
      </div>
    </div>
  )
}
