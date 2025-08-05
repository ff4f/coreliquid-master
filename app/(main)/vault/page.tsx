"use client"

import { useState, useEffect } from "react"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Badge } from "@/components/ui/badge"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { ArrowUpRight, Shield, TrendingUp, Zap, Info, CheckCircle, Wallet } from "lucide-react"
import { usePortfolio } from "@/contexts/portfolio-context"
import { useToast } from "@/hooks/use-toast"
import { useCoreFluidX } from "@/hooks/use-corefluidx"
import { useAccount, useBalance } from "wagmi"
import { CONTRACT_ADDRESSES } from "@/lib/wagmi"
import { tokens, getTokenData, formatCurrency } from "@/lib/token-data"

export default function VaultPage() {
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

  const vaultStrategies = [
    {
      id: "low",
      name: "Stable Yield Vault",
      description: "Low risk, consistent returns from stablecoin lending.",
      apy: "5.2%",
      tvl: "125M",
      risk: "Low",
      color: "green",
      icon: <Shield className="w-6 h-6 text-green-400" />,
    },
    {
      id: "balanced",
      name: "Balanced Growth Vault",
      description: "Moderate risk, diversified exposure to blue-chip assets.",
      apy: "12.8%",
      tvl: "80M",
      risk: "Medium",
      color: "yellow",
      icon: <TrendingUp className="w-6 h-6 text-yellow-400" />,
    },
    {
      id: "high",
      name: "High Yield Vault",
      description: "Higher risk, aggressive strategies for maximum returns.",
      apy: "28.5%",
      tvl: "45M",
      risk: "High",
      color: "red",
      icon: <Zap className="w-6 h-6 text-red-400" />,
    },
  ]

  const [selectedVault, setSelectedVault] = useState(vaultStrategies[0])
  const [investAmount, setInvestAmount] = useState("")
  const [selectedToken, setSelectedToken] = useState("USDT")
  const [isProcessing, setIsProcessing] = useState(false)
  const [txHash, setTxHash] = useState<string | null>(null)

  const tokenList = Object.entries(tokens).map(([symbol, data]) => {
    const userBalance = state.positions
      .filter((p) => p.token === symbol && (p.type === "deposit" || p.type === "vault"))
      .reduce((sum, pos) => sum + pos.amount, 0)
    return {
      symbol,
      name: data.name,
      balance: userBalance.toFixed(6),
      icon: data.icon,
      price: data.price,
    }
  })

  const handleInvest = async () => {
    if (!isConnected || !address) {
      toast({
        title: "Wallet Not Connected",
        description: "Please connect your wallet to invest.",
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

    const amount = Number.parseFloat(investAmount)
    if (isNaN(amount) || amount <= 0) {
      toast({
        title: "Invalid Amount",
        description: "Please enter a valid investment amount.",
        variant: "destructive",
      })
      return
    }

    const tokenBalance = Number.parseFloat(tokenList.find((t) => t.symbol === selectedToken)?.balance || "0")
    if (amount > tokenBalance) {
      toast({
        title: "Insufficient Balance",
        description: `You only have ${tokenBalance} ${selectedToken} available.`,
        variant: "destructive",
      })
      return
    }

    setIsProcessing(true)
    setTxHash(null)

    try {
      let transactionHash: string
      
      if (selectedToken === "CORE") {
        // For native CORE, stake to get stCORE first
        const tx = await contracts.stakeCore(investAmount)
        await tx.wait()
        transactionHash = tx.hash
        
        toast({
          title: "Staking Successful",
          description: `Successfully staked ${investAmount} CORE for stCORE in ${selectedVault.name}`,
        })
      } else {
        // For other tokens, deposit to vault strategy
        const selectedTokenData = getTokenData(selectedToken)
        const tokenAddress = selectedTokenData.address || CONTRACT_ADDRESSES.CORE_LIQUID_TOKEN
        
        // Map vault strategy to appropriate contract function
        let tx
        switch (selectedVault.id) {
          case "low":
            // Stable yield - deposit to ULP
            tx = await contracts.depositToULP(tokenAddress, investAmount)
            break
          case "balanced":
            // Balanced growth - deposit to optimized TULL
            tx = await contracts.depositToOptimizedTULL(tokenAddress, investAmount, address)
            break
          case "high":
            // High yield - deposit to simple TULL
            tx = await contracts.depositToSimpleTULL(tokenAddress, investAmount, address)
            break
          default:
            tx = await contracts.depositToULP(tokenAddress, investAmount)
        }
        
        await tx.wait()
        transactionHash = tx.hash
        
        toast({
          title: "Investment Successful!",
          description: `Successfully invested ${investAmount} ${selectedToken} into ${selectedVault.name}`,
        })
      }

      setTxHash(transactionHash)
      
      const tokenData = getTokenData(selectedToken)
      const valueUSD = amount * tokenData.price

      dispatch({
        type: "ADD_POSITION",
        payload: {
          id: `vault-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
          type: "vault",
          token: selectedToken,
          amount: amount,
          valueUSD: valueUSD,
          apy: Number.parseFloat(selectedVault.apy),
          timestamp: Date.now(),
          txHash: transactionHash,
        },
      })

      setInvestAmount("")
    } catch (error: any) {
      console.error('Investment failed:', error)
      toast({
        title: "Investment Failed",
        description: error.message || "Failed to process investment. Please try again.",
        variant: "destructive",
      })
    } finally {
      setIsProcessing(false)
    }
  }

  useEffect(() => {
    console.log("Selected vault changed to:", selectedVault.name)
  }, [selectedVault])

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold text-white mb-2 font-mono">VAULTS</h1>
        <p className="text-gray-400 font-mono">Maximize your returns with automated yield strategies</p>
      </div>

      {/* Vault Strategies */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        {vaultStrategies.map((vault) => (
          <div
            key={vault.id}
            className={`relative p-6 rounded-lg border cursor-pointer transition-all duration-300
              ${
                selectedVault.id === vault.id
                  ? "ring-4 ring-cyan-400/60 bg-gradient-to-br from-cyan-900/20 to-cyan-900/5 shadow-lg shadow-cyan-500/25"
                  : "border-[#2A2A2A] bg-[#1E1E1E] hover:bg-gray-800/70 hover:border-cyan-500/30 hover:shadow-md hover:shadow-cyan-500/10"
              }
            `}
            onClick={() => {
              setSelectedVault(vault)
              toast({
                title: "Vault Strategy Selected",
                description: `You've selected the ${vault.name}.`,
                variant: "default",
              })
              console.log("Clicking vault:", vault.name)
            }}
          >
            {selectedVault.id === vault.id && (
              <Badge className="absolute top-3 right-3 bg-cyan-600 text-white font-mono animate-pulse">
                ● SELECTED
              </Badge>
            )}
            <div className="flex items-center space-x-3 mb-4">
              <div className="w-10 h-10 rounded-full bg-gray-800 flex items-center justify-center">{vault.icon}</div>
              <h3
                className={`text-xl font-semibold font-mono ${
                  selectedVault.id === vault.id ? "text-cyan-400" : "text-white"
                }`}
              >
                {vault.name}
              </h3>
            </div>
            <p className="text-gray-400 text-sm mb-4 font-mono">{vault.description}</p>
            <div className="grid grid-cols-2 gap-2 text-sm">
              <div>
                <span className="text-gray-400 font-mono">APY:</span>
                <p className={`font-bold font-mono text-${vault.color}-400`}>{vault.apy}</p>
              </div>
              <div>
                <span className="text-gray-400 font-mono">TVL:</span>
                <p className="text-white font-mono">{vault.tvl}</p>
              </div>
              <div>
                <span className="text-gray-400 font-mono">Risk:</span>
                <Badge variant="outline" className={`border-current font-mono text-${vault.color}-400`}>
                  {vault.risk}
                </Badge>
              </div>
            </div>
          </div>
        ))}
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Investment Form */}
        <Card className="bg-[#1E1E1E] border-[#2A2A2A]">
          <CardHeader>
            <CardTitle className="text-xl font-semibold text-white flex items-center font-mono">
              <ArrowUpRight className="w-5 h-5 mr-2 text-green-400" />
              Invest in Vault
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-6">
            <div className="space-y-2">
              <Label className="text-gray-400 font-mono">Amount to Invest</Label>
              <div className="flex space-x-2">
                <Input
                  type="number"
                  placeholder="0.00"
                  value={investAmount}
                  onChange={(e) => setInvestAmount(e.target.value)}
                  className="flex-1 bg-[#2A2A2A] border-[#3A3A3A] text-white font-mono"
                />
                <Select value={selectedToken} onValueChange={setSelectedToken}>
                  <SelectTrigger className="w-32 bg-[#2A2A2A] border-[#3A3A3A] text-white font-mono">
                    <SelectValue placeholder="Token" />
                  </SelectTrigger>
                  <SelectContent className="bg-[#2A2A2A] border-[#3A3A3A]">
                    {tokenList.map((token) => (
                      <SelectItem
                        key={token.symbol}
                        value={token.symbol}
                        className="text-white hover:bg-[#3A3A3A] font-mono"
                      >
                        <div className="flex items-center space-x-2">
                          <span className="text-lg">{token.icon}</span>
                          <span>{token.symbol}</span>
                        </div>
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
              {selectedToken && (
                <p className="text-sm text-gray-400 font-mono">
                  Balance: {tokenList.find((t) => t.symbol === selectedToken)?.balance || "0.000000"} {selectedToken}
                </p>
              )}
            </div>

            <div className="space-y-2">
              <Label className="text-gray-400 font-mono">Selected Vault Strategy</Label>
              <div className="p-3 bg-[#2A2A2A] border border-[#3A3A3A] rounded-lg flex items-center justify-between">
                <div className="flex items-center space-x-3">
                  <div className="w-8 h-8 rounded-full bg-gray-700 flex items-center justify-center">
                    {selectedVault.icon}
                  </div>
                  <span className="text-white font-mono">{selectedVault.name}</span>
                </div>
                <Badge variant="outline" className={`border-current font-mono text-${selectedVault.color}-400`}>
                  {selectedVault.risk} Risk
                </Badge>
              </div>
            </div>

            <Button
              className="w-full bg-green-600 hover:bg-green-700 text-white font-mono"
              onClick={handleInvest}
              disabled={
                !state.isWalletConnected ||
                isProcessing ||
                Number.parseFloat(investAmount) <= 0 ||
                Number.parseFloat(investAmount) >
                  Number.parseFloat(tokenList.find((t) => t.symbol === selectedToken)?.balance || "0")
              }
            >
              {isProcessing ? "PROCESSING_INVESTMENT..." : "EXECUTE_INVESTMENT"}
            </Button>
            
            {/* Transaction Hash Display */}
            {txHash && (
              <div className="bg-green-500/10 border border-green-500/20 rounded-lg p-3">
                <div className="flex items-start space-x-2">
                  <CheckCircle className="w-4 h-4 text-green-500 mt-0.5" />
                  <div className="flex-1">
                    <p className="text-green-400 font-medium font-mono text-sm">Transaction Successful!</p>
                    <p className="text-gray-400 text-xs font-mono mt-1">TX Hash:</p>
                    <p className="text-green-300 text-xs font-mono break-all">{txHash}</p>
                    <a
                      href={`https://scan.test2.btcs.network/tx/${txHash}`}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="text-cyan-400 hover:text-cyan-300 text-xs font-mono underline mt-1 inline-block"
                    >
                      View on Core Testnet Explorer →
                    </a>
                  </div>
                </div>
              </div>
            )}
            
            {!state.isWalletConnected && (
              <div className="bg-red-500/10 border border-red-500/20 rounded-lg p-3 flex items-center space-x-2">
                <Wallet className="w-4 h-4 text-red-500" />
                <p className="text-red-400 text-sm font-mono">Connect your wallet to enable investment.</p>
              </div>
            )}
          </CardContent>
        </Card>

        {/* Vault Details & Projection */}
        <Card className="bg-[#1E1E1E] border-[#2A2A2A]">
          <CardHeader>
            <CardTitle className="text-xl font-semibold text-white flex items-center font-mono">
              <Info className="w-5 h-5 mr-2 text-cyan-400" />
              Vault Details & Projection
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-6">
            <div className="space-y-3">
              <h3 className="text-lg font-semibold text-cyan-400 font-mono">SELECTED_STRATEGY: {selectedVault.name}</h3>
              <div className="flex justify-between">
                <span className="text-gray-400 font-mono">APY:</span>
                <span className={`font-bold font-mono text-${selectedVault.color}-400`}>{selectedVault.apy}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-gray-400 font-mono">TVL:</span>
                <span className="text-white font-mono">{selectedVault.tvl}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-gray-400 font-mono">Risk Level:</span>
                <Badge variant="outline" className={`border-current font-mono text-${selectedVault.color}-400`}>
                  {selectedVault.risk}
                </Badge>
              </div>
              <div className="flex justify-between">
                <span className="text-gray-400 font-mono">Audit Status:</span>
                <Badge variant="outline" className="border-green-500 text-green-400 font-mono">
                  <CheckCircle className="w-3 h-3 mr-1" /> Audited
                </Badge>
              </div>
            </div>

            <div className="space-y-3">
              <h3 className="text-lg font-semibold text-cyan-400 font-mono">EARNINGS_PROJECTION</h3>
              <div className="flex justify-between">
                <span className="text-gray-400 font-mono">Your Investment:</span>
                <span className="text-white font-mono">
                  {investAmount ? `${Number.parseFloat(investAmount).toFixed(2)} ${selectedToken}` : "0.00"}
                </span>
              </div>
              <div className="flex justify-between">
                <span className="text-gray-400 font-mono">Projected Annual Earnings:</span>
                <span className="text-green-400 font-mono">
                  {investAmount
                    ? formatCurrency(
                        Number.parseFloat(investAmount) *
                          getTokenData(selectedToken).price *
                          (Number.parseFloat(selectedVault.apy) / 100),
                      )
                    : formatCurrency(0)}
                </span>
              </div>
              <div className="flex justify-between">
                <span className="text-gray-400 font-mono">Projected Value in 1 Year:</span>
                <span className="text-white font-mono">
                  {investAmount
                    ? formatCurrency(
                        Number.parseFloat(investAmount) *
                          getTokenData(selectedToken).price *
                          (1 + Number.parseFloat(selectedVault.apy) / 100),
                      )
                    : formatCurrency(0)}
                </span>
              </div>
            </div>

            <div className="bg-blue-500/10 border border-blue-500/20 rounded-lg p-4">
              <div className="flex items-start space-x-2">
                <Info className="w-4 h-4 text-blue-500 mt-0.5" />
                <div className="text-sm">
                  <p className="text-blue-400 font-medium font-mono">Disclaimer</p>
                  <p className="text-gray-400 mt-1 font-mono text-xs">
                    Yield projections are estimates and not guaranteed. DeFi investments carry inherent risks.
                  </p>
                </div>
              </div>
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  )
}
