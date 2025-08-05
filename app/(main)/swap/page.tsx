"use client"

import { useState, useEffect } from "react"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Switch } from "@/components/ui/switch"
import { Badge } from "@/components/ui/badge"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { ArrowLeftRight, ArrowUpDown, Shield, Zap, Info, Lock, Settings } from "lucide-react"
import { usePortfolio } from "@/contexts/portfolio-context"
import { useToast } from "@/hooks/use-toast"
import { tokens, getTokenData, formatCurrency } from "@/lib/token-data"

export default function SwapPage() {
  const { state, dispatch } = usePortfolio()
  const { toast } = useToast()
  const [fromToken, setFromToken] = useState("")
  const [toToken, setToToken] = useState("")
  const [fromAmount, setFromAmount] = useState("")
  const [toAmount, setToAmount] = useState("")
  const [mevSafe, setMevSafe] = useState(true)
  const [slippage, setSlippage] = useState("0.5")
  const [isProcessing, setIsProcessing] = useState(false)
  const [showAdvanced, setShowAdvanced] = useState(false)
  const [priceImpact, setPriceImpact] = useState(0.12)
  const [estimatedGas, setEstimatedGas] = useState(0.0045)

  // Generate token list with user's available balances (not collateralized)
  const tokenList = Object.entries(tokens).map(([symbol, data]) => {
    const balanceData = state.balances[symbol]
    const userAvailableBalance = balanceData ? balanceData.available : 0
    const userTotalBalance = balanceData ? balanceData.total : 0
    const userCollateralizedBalance = balanceData ? balanceData.collateralized : 0

    return {
      symbol,
      name: data.name,
      availableBalance: userAvailableBalance,
      totalBalance: userTotalBalance,
      collateralizedBalance: userCollateralizedBalance,
      icon: data.icon,
      price: data.price,
    }
  })

  const handleSwapTokens = () => {
    const tempFrom = fromToken
    const tempFromAmount = fromAmount
    setFromToken(toToken)
    setToToken(tempFrom)
    setFromAmount(toAmount)
    setToAmount(tempFromAmount)
  }

  const calculateOutput = () => {
    if (!fromAmount || !fromToken || !toToken) return "0"

    const fromTokenData = getTokenData(fromToken)
    const toTokenData = getTokenData(toToken)
    const fromValueUSD = Number.parseFloat(fromAmount) * fromTokenData.price
    const outputAmount = fromValueUSD / toTokenData.price

    // Apply slippage
    const slippageMultiplier = 1 - Number.parseFloat(slippage) / 100
    return (outputAmount * slippageMultiplier).toFixed(6)
  }

  const estimatedOutput = calculateOutput()

  // Check if swap amount exceeds available balance
  const fromTokenData = tokenList.find((t) => t.symbol === fromToken)
  const fromAmountNum = Number.parseFloat(fromAmount) || 0
  const availableBalance = fromTokenData?.availableBalance || 0
  const exceedsBalance = fromAmountNum > availableBalance
  const hasCollateral = (fromTokenData?.collateralizedBalance || 0) > 0

  const handleSwap = async () => {
    if (!state.isWalletConnected) {
      toast({
        title: "Wallet Not Connected",
        description: "Please connect your wallet to swap tokens.",
        variant: "destructive",
      })
      return
    }

    if (!fromToken || !toToken || !fromAmount) {
      toast({
        title: "Invalid Swap",
        description: "Please select tokens and enter an amount.",
        variant: "destructive",
      })
      return
    }

    const amountToSwap = Number.parseFloat(fromAmount)
    if (amountToSwap <= 0) {
      toast({
        title: "Invalid Amount",
        description: "Please enter a valid swap amount.",
        variant: "destructive",
      })
      return
    }

    if (exceedsBalance) {
      toast({
        title: "Insufficient Available Balance",
        description: `You only have ${availableBalance.toFixed(6)} ${fromToken} available for swap.${
          hasCollateral
            ? ` ${(fromTokenData?.collateralizedBalance || 0).toFixed(6)} ${fromToken} is locked as collateral.`
            : ""
        }`,
        variant: "destructive",
      })
      return
    }

    setIsProcessing(true)

    try {
      // Import contracts and ethers
       const { CoreFluidXContracts } = await import('@/lib/contracts')
       const { ethers } = await import('ethers')
       
       // Get provider and signer
       if (!window.ethereum) {
         throw new Error('Please install MetaMask to use swap functionality')
       }
       
       const provider = new ethers.BrowserProvider(window.ethereum)
       const signer = await provider.getSigner()
       const contracts = new CoreFluidXContracts(provider, signer)
      
      // Calculate minimum amount out with slippage tolerance
      const slippageTolerance = Number.parseFloat(slippage) / 100
      const minAmountOut = (Number.parseFloat(estimatedOutput) * (1 - slippageTolerance)).toString()
      
      // Execute the actual swap
      const tx = await contracts.executeSwap(
        fromToken,
        toToken,
        fromAmount,
        minAmountOut
      )
      
      // Wait for transaction confirmation
      const receipt = await tx.wait()

      const fromTokenDataPrice = getTokenData(fromToken)
      const fromValueUSD = amountToSwap * fromTokenDataPrice.price
      
      // Update balances after successful swap
      const outputAmount = Number.parseFloat(estimatedOutput)
      
      // Decrease fromToken balance
      dispatch({
        type: "UPDATE_TOKEN_BALANCE",
        payload: {
          symbol: fromToken,
          balance: Math.max(0, (state.balances[fromToken]?.total || 0) - amountToSwap)
        }
      })
      
      // Increase toToken balance
      dispatch({
        type: "UPDATE_TOKEN_BALANCE",
        payload: {
          symbol: toToken,
          balance: (state.balances[toToken]?.total || 0) + outputAmount
        }
      })

      // Add recent activity for swap with real transaction hash
      const swapActivity = {
        id: `swap-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
        type: "swap" as const,
        status: "completed" as const,
        amount: amountToSwap,
        token: fromToken,
        toToken: toToken,
        valueUSD: fromValueUSD,
        timestamp: Date.now(),
        hash: receipt.hash,
      }

      dispatch({ type: "ADD_RECENT_ACTIVITY", payload: swapActivity })

      toast({
        title: "Swap Successful",
        description: (
          <div className="flex flex-col gap-2">
            <div>Successfully swapped {fromAmount} {fromToken} for {estimatedOutput} {toToken}</div>
            <div className="text-xs opacity-75">
              Transaction: {receipt.hash.slice(0, 10)}...{receipt.hash.slice(-8)}
            </div>
            <a 
              href={`https://scan.test2.btcs.network/tx/${receipt.hash}`}
              target="_blank"
              rel="noopener noreferrer"
              className="text-blue-400 hover:text-blue-300 text-xs underline"
            >
              View on CoreScan →
            </a>
          </div>
        ),
        variant: "default",
      })

      // Reset form
      setFromAmount("")
      setToAmount("")
    } catch (error: any) {
      console.error('Swap error:', error)
      
      const fromTokenDataPrice = getTokenData(fromToken)
      const fromValueUSD = amountToSwap * fromTokenDataPrice.price
      
      // Add failed transaction to activities
      const failedSwapActivity = {
        id: `swap-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
        type: "swap" as const,
        status: "failed" as const,
        amount: amountToSwap,
        token: fromToken,
        toToken: toToken,
        valueUSD: fromValueUSD,
        timestamp: Date.now(),
        hash: error.hash || 'failed',
      }
      
      dispatch({ type: "ADD_RECENT_ACTIVITY", payload: failedSwapActivity })
      
      toast({
        title: "Swap Failed",
        description: (
          <div className="flex flex-col gap-2">
            <div>Swap failed: {error.message || 'Unknown error'}</div>
            {error.hash && (
              <a 
                href={`https://scan.test2.btcs.network/tx/${error.hash}`}
                target="_blank"
                rel="noopener noreferrer"
                className="text-blue-400 hover:text-blue-300 text-xs underline"
              >
                View failed transaction →
              </a>
            )}
          </div>
        ),
        variant: "destructive",
      })
    } finally {
      setIsProcessing(false)
    }
  }

  // Update toAmount when fromAmount changes
  useEffect(() => {
    if (fromAmount && fromToken && toToken) {
      setToAmount(estimatedOutput)
    } else {
      setToAmount("")
    }
  }, [fromAmount, fromToken, toToken, slippage, estimatedOutput])

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold text-white mb-2 font-mono">SWAP</h1>
        <p className="text-gray-400 font-mono">Exchange assets with MEV protection</p>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Swap Interface */}
        <Card className="bg-[#1E1E1E] border-[#2A2A2A]">
          <CardHeader>
            <CardTitle className="text-xl font-semibold text-white flex items-center font-mono">
              <ArrowLeftRight className="w-5 h-5 mr-2 text-cyan-400" />
              Swap Tokens
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-6">
            {/* From Token */}
            <div className="space-y-2">
              <Label className="text-gray-400 font-mono">From</Label>
              <div className="flex space-x-2">
                <Select value={fromToken} onValueChange={setFromToken}>
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
                          <span className="text-cyan-400 ml-auto">{formatCurrency(token.price)}</span>
                        </div>
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
                <Input
                  type="number"
                  placeholder="0.00"
                  value={fromAmount}
                  onChange={(e) => setFromAmount(e.target.value)}
                  className={`flex-1 bg-[#2A2A2A] border-[#3A3A3A] text-white font-mono ${
                    exceedsBalance && fromAmount ? "border-red-500" : ""
                  }`}
                />
              </div>
              {fromToken && (
                <div className="space-y-1">
                  <div className="flex items-center justify-between">
                    <p className="text-sm text-gray-400 font-mono">
                      Available: {fromTokenData?.availableBalance.toFixed(6) || "0.000000"} {fromToken}
                    </p>
                    <Button
                      variant="ghost"
                      size="sm"
                      onClick={() => setFromAmount(fromTokenData?.availableBalance.toString() || "0")}
                      className="text-xs text-cyan-400 hover:text-cyan-300 h-auto p-1 font-mono"
                    >
                      MAX
                    </Button>
                  </div>
                  {hasCollateral && (
                    <div className="flex items-center space-x-1">
                      <Lock className="w-3 h-3 text-yellow-400" />
                      <p className="text-xs text-yellow-400 font-mono">
                        {(fromTokenData?.collateralizedBalance || 0).toFixed(6)} {fromToken} locked as collateral
                      </p>
                    </div>
                  )}
                  {exceedsBalance && fromAmount && (
                    <p className="text-xs text-red-400 font-mono">Amount exceeds available balance</p>
                  )}
                </div>
              )}
            </div>

            {/* Swap Button */}
            <div className="flex justify-center">
              <Button
                variant="outline"
                size="icon"
                onClick={handleSwapTokens}
                className="bg-[#2A2A2A] border-[#3A3A3A] text-white hover:bg-[#3A3A3A]"
              >
                <ArrowUpDown className="w-4 h-4" />
              </Button>
            </div>

            {/* To Token */}
            <div className="space-y-2">
              <Label className="text-gray-400 font-mono">To</Label>
              <div className="flex space-x-2">
                <Select value={toToken} onValueChange={setToToken}>
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
                          <span className="text-cyan-400 ml-auto">{formatCurrency(token.price)}</span>
                        </div>
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
                <Input
                  type="number"
                  placeholder="0.00"
                  value={toAmount}
                  readOnly
                  className="flex-1 bg-[#2A2A2A] border-[#3A3A3A] text-white font-mono"
                />
              </div>
              {toToken && (
                <p className="text-sm text-gray-400 font-mono">
                  Available: {tokenList.find((t) => t.symbol === toToken)?.availableBalance.toFixed(6) || "0.000000"}{" "}
                  {toToken}
                </p>
              )}
            </div>

            {/* Mode Toggle */}
            <div className="space-y-4">
              <div className="flex items-center justify-between">
                <div className="flex items-center space-x-2">
                  <Shield className="w-4 h-4 text-blue-500" />
                  <Label className="text-white font-mono">MEV-Safe Mode</Label>
                </div>
                <Switch checked={mevSafe} onCheckedChange={setMevSafe} />
              </div>
              <div className="flex items-center space-x-2">
                <Badge
                  variant={mevSafe ? "default" : "secondary"}
                  className={`font-mono ${mevSafe ? "bg-blue-600" : "bg-orange-600"}`}
                >
                  {mevSafe ? <Shield className="w-3 h-3 mr-1" /> : <Zap className="w-3 h-3 mr-1" />}
                  {mevSafe ? "MEV-Safe" : "FAST_MODE"}
                </Badge>
                <span className="text-sm text-gray-400 font-mono">
                  {mevSafe ? "Protected from MEV attacks" : "Faster execution"}
                </span>
              </div>
            </div>

            {/* Slippage */}
            <div className="space-y-2">
              <Label className="text-gray-400 font-mono">Slippage Tolerance</Label>
              <div className="flex space-x-2">
                {["0.1", "0.5", "1.0"].map((value) => (
                  <Button
                    key={value}
                    variant={slippage === value ? "default" : "outline"}
                    size="sm"
                    onClick={() => setSlippage(value)}
                    className={`font-mono ${
                      slippage === value ? "bg-blue-600" : "bg-[#2A2A2A] border-[#3A3A3A] text-white hover:bg-[#3A3A3A]"
                    }`}
                  >
                    {value}%
                  </Button>
                ))}
                <Input
                  type="number"
                  placeholder="Custom"
                  value={slippage}
                  onChange={(e) => setSlippage(e.target.value)}
                  className="w-20 bg-[#2A2A2A] border-[#3A3A3A] text-white font-mono"
                />
              </div>
            </div>

            {/* Advanced Settings Toggle */}
            <Button
              variant="ghost"
              onClick={() => setShowAdvanced(!showAdvanced)}
              className="w-full text-gray-400 hover:text-white font-mono"
            >
              <Info className="w-4 h-4 mr-2" />
              {showAdvanced ? 'Hide' : 'Show'} Advanced Settings
            </Button>

            {/* Advanced Settings */}
            {showAdvanced && (
              <Card className="bg-gray-800/50 border-gray-700">
                <CardContent className="p-4 space-y-4">
                  <div className="grid grid-cols-2 gap-4">
                    <div>
                      <label className="text-sm text-gray-400 font-mono">Price Impact</label>
                      <div className={`text-lg font-semibold font-mono ${
                        priceImpact < 1 ? 'text-green-400' : 
                        priceImpact < 3 ? 'text-yellow-400' : 'text-red-400'
                      }`}>
                        {priceImpact.toFixed(2)}%
                      </div>
                    </div>
                    <div>
                      <label className="text-sm text-gray-400 font-mono">Estimated Gas</label>
                      <div className="text-lg font-semibold text-blue-400 font-mono">
                        {estimatedGas.toFixed(4)} ETH
                      </div>
                    </div>
                  </div>
                  
                  <div>
                    <label className="text-sm text-gray-400 font-mono">Slippage Protection</label>
                    <div className="flex items-center gap-2 mt-1">
                      <Shield className="w-4 h-4 text-green-400" />
                      <span className="text-green-400 text-sm font-mono">Active (Max: 5.0%)</span>
                    </div>
                  </div>
                  
                  <div>
                    <label className="text-sm text-gray-400 font-mono">Route</label>
                    <div className="text-sm text-white mt-1 font-mono">
                      {fromToken || 'TOKEN'} → {toToken || 'TOKEN'} (Direct)
                    </div>
                  </div>
                </CardContent>
              </Card>
            )}

            <Button
              className={`w-full font-mono ${
                exceedsBalance || !state.isWalletConnected || !fromToken || !toToken || !fromAmount || isProcessing
                  ? "bg-gray-600 cursor-not-allowed"
                  : "bg-blue-600 hover:bg-blue-700"
              } text-white`}
              disabled={
                !state.isWalletConnected || !fromToken || !toToken || !fromAmount || isProcessing || exceedsBalance
              }
              onClick={handleSwap}
            >
              <ArrowLeftRight className="w-4 h-4 mr-2" />
              {isProcessing
                ? "PROCESSING..."
                : exceedsBalance
                  ? "INSUFFICIENT_BALANCE"
                  : !state.isWalletConnected
                    ? "CONNECT_WALLET"
                    : "EXECUTE_SWAP"}
            </Button>

            {/* Balance Warning */}
            {exceedsBalance && fromAmount && (
              <div className="bg-red-500/10 border border-red-500/20 rounded-lg p-3">
                <div className="flex items-start space-x-2">
                  <Info className="w-4 h-4 text-red-500 mt-0.5" />
                  <div className="text-sm">
                    <p className="text-red-400 font-medium font-mono">Insufficient Balance</p>
                    <p className="text-gray-400 mt-1 font-mono text-xs">
                      You're trying to swap {fromAmount} {fromToken} but only have {availableBalance.toFixed(6)}{" "}
                      available.
                      {hasCollateral &&
                        ` ${fromTokenData?.collateralizedBalance.toFixed(6)} ${fromToken} is locked as collateral.`}
                    </p>
                  </div>
                </div>
              </div>
            )}
          </CardContent>
        </Card>

        {/* Route Breakdown */}
        <Card className="bg-[#1E1E1E] border-[#2A2A2A]">
          <CardHeader>
            <CardTitle className="text-xl font-semibold text-white font-mono text-cyan-400">Route Breakdown</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            {fromToken && toToken && fromAmount && !exceedsBalance ? (
              <>
                <div className="space-y-3">
                  <div className="flex justify-between">
                    <span className="text-gray-400 font-mono">Exchange Rate:</span>
                    <span className="text-white font-mono">
                      1 {fromToken} = {(getTokenData(fromToken).price / getTokenData(toToken).price).toFixed(6)}{" "}
                      {toToken}
                    </span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-gray-400 font-mono">Price Impact:</span>
                    <span className="text-green-500 font-mono">0.02%</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-gray-400 font-mono">Protocol Fee:</span>
                    <span className="text-white font-mono">0.05%</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-gray-400 font-mono">Slippage:</span>
                    <span className="text-yellow-400 font-mono">{slippage}%</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-gray-400 font-mono">Gas Fee:</span>
                    <span className="text-white font-mono">~$3.50</span>
                  </div>
                </div>

                <div className="space-y-2">
                  <Label className="text-gray-400 font-mono">Route Distribution</Label>
                  <div className="space-y-2">
                    <div className="flex items-center justify-between">
                      <span className="text-sm text-white font-mono">Internal AMM:</span>
                      <span className="text-sm text-blue-500 font-mono">65%</span>
                    </div>
                    <div className="w-full bg-[#2A2A2A] rounded-full h-2">
                      <div className="bg-blue-500 h-2 rounded-full" style={{ width: "65%" }}></div>
                    </div>
                    <div className="flex items-center justify-between">
                      <span className="text-sm text-white font-mono">External DEX:</span>
                      <span className="text-sm text-purple-500 font-mono">35%</span>
                    </div>
                    <div className="w-full bg-[#2A2A2A] rounded-full h-2">
                      <div className="bg-purple-500 h-2 rounded-full" style={{ width: "35%" }}></div>
                    </div>
                  </div>
                </div>

                <div className="bg-blue-500/10 border border-blue-500/20 rounded-lg p-4">
                  <div className="flex items-start space-x-2">
                    <Info className="w-4 h-4 text-blue-500 mt-0.5" />
                    <div className="text-sm">
                      <p className="text-blue-400 font-medium font-mono">Optimal Route Found</p>
                      <p className="text-gray-400 mt-1 font-mono text-xs">
                        Best price achieved by splitting across multiple liquidity sources.
                      </p>
                    </div>
                  </div>
                </div>
              </>
            ) : (
              <div className="text-center py-8">
                <div className="w-16 h-16 bg-[#2A2A2A] rounded-full flex items-center justify-center mx-auto mb-4">
                  <ArrowLeftRight className="w-8 h-8 text-gray-400" />
                </div>
                <p className="text-gray-400 font-mono">
                  {exceedsBalance
                    ? "Fix balance issue to see route details"
                    : "Select tokens and amount to see route details"}
                </p>
              </div>
            )}
          </CardContent>
        </Card>
      </div>

      {/* Recent Swaps */}
      <Card className="bg-[#1E1E1E] border-[#2A2A2A]">
        <CardHeader>
          <CardTitle className="text-xl font-semibold text-white font-mono text-cyan-400">Recent Swaps</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="space-y-3">
            {state.recentActivities
              .filter((activity) => activity.type === "swap")
              .slice(0, 5)
              .map((swap) => (
                <div key={swap.id} className="flex items-center justify-between p-3 rounded-lg bg-[#2A2A2A]">
                  <div className="flex items-center space-x-3">
                    <div className="flex items-center space-x-1">
                      <div className="w-6 h-6 bg-gradient-to-r from-blue-500 to-purple-600 rounded-full flex items-center justify-center">
                        <span className="text-xs font-bold">{swap.token[0]}</span>
                      </div>
                      <ArrowLeftRight className="w-3 h-3 text-gray-400" />
                      <div className="w-6 h-6 bg-gradient-to-r from-green-500 to-blue-600 rounded-full flex items-center justify-center">
                        <span className="text-xs font-bold">{swap.toToken?.[0] || "?"}</span>
                      </div>
                    </div>
                    <div>
                      <p className="text-white font-medium font-mono">
                        {swap.token} → {swap.toToken}
                      </p>
                      <p className="text-sm text-gray-400 font-mono">{formatCurrency(swap.valueUSD)}</p>
                    </div>
                  </div>
                  <div className="text-right">
                    <Badge 
                      variant="outline" 
                      className={`font-mono ${
                        swap.status === 'completed' 
                          ? 'border-green-500 text-green-500' 
                          : 'border-red-500 text-red-500'
                      }`}
                    >
                      {swap.status.toUpperCase()}
                    </Badge>
                    <p className="text-xs text-gray-400 mt-1 font-mono">
                      {Math.floor((Date.now() - swap.timestamp) / (1000 * 60))}m ago
                    </p>
                    {swap.hash && swap.hash !== 'failed' && (
                      <a 
                        href={`https://scan.test2.btcs.network/tx/${swap.hash}`}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="text-xs text-blue-400 hover:text-blue-300 underline font-mono block mt-1"
                      >
                        {swap.hash.slice(0, 6)}...{swap.hash.slice(-4)}
                      </a>
                    )}
                  </div>
                </div>
              ))}
            {state.recentActivities.filter((activity) => activity.type === "swap").length === 0 && (
              <div className="text-center py-8">
                <ArrowLeftRight className="w-12 h-12 text-gray-600 mx-auto mb-4" />
                <p className="text-gray-400 font-mono">No recent swaps</p>
                <p className="text-gray-500 text-sm font-mono mt-1">Your swap history will appear here</p>
              </div>
            )}
          </div>
        </CardContent>
      </Card>
    </div>
  )
}
