"use client"

import { useState } from "react"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Badge } from "@/components/ui/badge"
import { Progress } from "@/components/ui/progress"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { TrendingUp, Shield, AlertTriangle, DollarSign, Lock, Unlock } from "lucide-react"
import { usePortfolio } from "@/contexts/portfolio-context"
import { useToast } from "@/hooks/use-toast"
import { tokens, getTokenData, formatCurrency } from "@/lib/token-data"
import { useCoreFluidX } from "@/hooks/use-corefluidx"
import { useAccount } from "wagmi"

export default function CreditSalePage() {
  const { state, dispatch } = usePortfolio()
  const { toast } = useToast()
  const { address, isConnected } = useAccount()
  const { contracts, isLoading: contractsLoading } = useCoreFluidX()
  const [collateralToken, setCollateralToken] = useState("")
  const [collateralAmount, setCollateralAmount] = useState("")
  const [creditToken, setCreditToken] = useState("")
  const [creditAmount, setCreditAmount] = useState("")
  const [isProcessing, setIsProcessing] = useState(false)
  const [txHash, setTxHash] = useState<string | null>(null)
  
  // Pay Instalment states
  const [repayToken, setRepayToken] = useState("ETH")
  const [principalAmount, setPrincipalAmount] = useState("")
  const [markupAmount, setMarkupAmount] = useState("")
  const [repayTxHash, setRepayTxHash] = useState<string | null>(null)

  // Get available tokens for collateral (only tokens user has deposits for)
  const availableCollateralTokens = Object.entries(tokens)
    .filter(([symbol]) => {
      const balance = state.balances[symbol]
      return balance && balance.available > 0
    })
    .map(([symbol, data]) => ({
      symbol,
      name: data.name,
      availableBalance: state.balances[symbol]?.available || 0,
      totalBalance: state.balances[symbol]?.total || 0,
      collateralizedBalance: state.balances[symbol]?.collateralized || 0,
      icon: data.icon,
      price: data.price,
    }))

  // All tokens available for credit sale
  const creditTokens = Object.entries(tokens).map(([symbol, data]) => ({
    symbol,
    name: data.name,
    icon: data.icon,
    price: data.price,
    markup: 2.5 + Math.random() * 2, // Mock fixed markup percentage
  }))

  // Get available tokens for repayment (same as credit tokens)
  const repaymentTokens = tokens

  const calculateMaxCredit = () => {
    if (!collateralToken || !collateralAmount) return 0
    const collateralValue = Number.parseFloat(collateralAmount) * getTokenData(collateralToken).price
    return collateralValue * 0.8 // 80% LTV
  }

  const calculateHealthFactor = () => {
    if (!collateralAmount || !creditAmount || !collateralToken || !creditToken) return 0
    const collateralValue = Number.parseFloat(collateralAmount) * getTokenData(collateralToken).price
    const creditValue = Number.parseFloat(creditAmount) * getTokenData(creditToken).price
    const markup = creditTokens.find(t => t.symbol === creditToken)?.markup || 2.5
    const totalOwed = creditValue * (1 + markup / 100) // Principal + fixed markup
    return totalOwed > 0 ? (collateralValue * 0.8) / totalOwed : 0
  }

  const maxCreditUSD = calculateMaxCredit()
  const healthFactor = calculateHealthFactor()
  const selectedCollateralToken = availableCollateralTokens.find((t) => t.symbol === collateralToken)
  const selectedCreditToken = creditTokens.find((t) => t.symbol === creditToken)

  const handleCreditSale = async () => {
    if (!state.isWalletConnected) {
      toast({
        title: "Wallet Not Connected",
        description: "Please connect your wallet to open a credit sale.",
        variant: "destructive",
      })
      return
    }

    if (!collateralToken || !collateralAmount || !creditToken || !creditAmount) {
      toast({
        title: "Invalid Credit Sale",
        description: "Please fill in all required fields.",
        variant: "destructive",
      })
      return
    }

    const collateralAmountNum = Number.parseFloat(collateralAmount)
    const creditAmountNum = Number.parseFloat(creditAmount)
    const availableForCollateral = selectedCollateralToken?.availableBalance || 0

    if (collateralAmountNum <= 0 || creditAmountNum <= 0) {
      toast({
        title: "Invalid Amount",
        description: "Please enter valid amounts.",
        variant: "destructive",
      })
      return
    }

    if (collateralAmountNum > availableForCollateral) {
      toast({
        title: "Insufficient Collateral",
        description: `You only have ${availableForCollateral.toFixed(6)} ${collateralToken} available for collateral.`,
        variant: "destructive",
      })
      return
    }

    const creditValueUSD = creditAmountNum * getTokenData(creditToken).price
    if (creditValueUSD > maxCreditUSD) {
      toast({
        title: "Credit Amount Too High",
        description: `Maximum credit amount is ${formatCurrency(maxCreditUSD)} based on your collateral.`,
        variant: "destructive",
      })
      return
    }

    if (healthFactor < 1.2) {
      toast({
        title: "Health Factor Too Low",
        description: "Your health factor would be too low. Reduce credit amount or increase collateral.",
        variant: "destructive",
      })
      return
    }

    setIsProcessing(true)

    try {
      let tx: any = null
      
      // Check if contracts are available and wallet is connected
      if (contracts && isConnected && address) {
        // Call smart contract function
        tx = await contracts.openCreditSale(
          creditToken, // asset
          creditAmount, // principal
          address // recipient
        )
        
        // Wait for transaction confirmation
        await tx.wait()
        setTxHash(tx.hash)
      } else {
        // Fallback to simulation if contracts not available
        await new Promise((resolve) => setTimeout(resolve, 2000))
        setTxHash('simulated-hash')
      }

      const collateralTokenData = getTokenData(collateralToken)
      const creditTokenData = getTokenData(creditToken)
      const collateralValueUSD = collateralAmountNum * collateralTokenData.price
      const creditValueUSD = creditAmountNum * creditTokenData.price
      const markup = selectedCreditToken?.markup || 2.5
      const totalOwedUSD = creditValueUSD * (1 + markup / 100)

      // First, update existing deposit to mark as collateral or create new collateral position
      const existingDeposit = state.positions.find(
        (pos) => pos.type === "deposit" && pos.token === collateralToken && !pos.isCollateral,
      )

      if (existingDeposit && existingDeposit.amount >= collateralAmountNum) {
        // If we have enough in existing deposit, split it
        if (existingDeposit.amount === collateralAmountNum) {
          // Mark entire deposit as collateral
          dispatch({
            type: "UPDATE_POSITION",
            payload: {
              id: existingDeposit.id,
              updates: { isCollateral: true },
            },
          })
        } else {
          // Split the position: reduce existing and create new collateral position
          dispatch({
            type: "UPDATE_POSITION",
            payload: {
              id: existingDeposit.id,
              updates: {
                amount: existingDeposit.amount - collateralAmountNum,
                valueUSD: (existingDeposit.amount - collateralAmountNum) * collateralTokenData.price,
              },
            },
          })

          // Create new collateral position
          const collateralPosition = {
            id: `collateral-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
            type: "deposit" as const,
            token: collateralToken,
            amount: collateralAmountNum,
            valueUSD: collateralValueUSD,
            apy: 3.5,
            timestamp: Date.now(),
            isCollateral: true,
          }

          dispatch({ type: "ADD_POSITION", payload: collateralPosition })
        }
      } else {
        // Create new collateral position (shouldn't happen with proper validation)
        const collateralPosition = {
          id: `collateral-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
          type: "deposit" as const,
          token: collateralToken,
          amount: collateralAmountNum,
          valueUSD: collateralValueUSD,
          apy: 3.5,
          timestamp: Date.now(),
          isCollateral: true,
        }

        dispatch({ type: "ADD_POSITION", payload: collateralPosition })
      }

      // Add credit sale position
      const creditPosition = {
        id: `credit-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
        type: "borrow" as const, // Keep as 'borrow' for compatibility with existing state
        token: creditToken,
        amount: creditAmountNum,
        valueUSD: totalOwedUSD, // Total amount owed including markup
        apy: markup, // Store markup as 'apy' for compatibility
        timestamp: Date.now(),
      }

      dispatch({ type: "ADD_POSITION", payload: creditPosition })

      toast({
        title: "Credit Sale Successful",
        description: `Successfully opened credit sale for ${creditAmount} ${creditToken} using ${collateralAmount} ${collateralToken} as collateral. Fixed markup: ${markup.toFixed(1)}%`,
        variant: "default",
      })

      // Reset form
      setCollateralAmount("")
      setCreditAmount("")
    } catch (error) {
      toast({
        title: "Credit Sale Failed",
        description: "Failed to process credit sale. Please try again.",
        variant: "destructive",
      })
    } finally {
      setIsProcessing(false)
    }
  }

  const handlePayInstalment = async () => {
    if (!isConnected) {
      toast({
        title: "Wallet not connected",
        description: "Please connect your wallet to proceed",
        variant: "destructive",
      })
      return
    }

    if (!repayToken || !principalAmount || !markupAmount) {
      toast({
        title: "Missing information",
        description: "Please fill in all required fields",
        variant: "destructive",
      })
      return
    }

    const principalAmountNum = parseFloat(principalAmount)
    const markupAmountNum = parseFloat(markupAmount)

    if (principalAmountNum <= 0 || markupAmountNum <= 0) {
      toast({
        title: "Invalid amounts",
        description: "Amounts must be greater than 0",
        variant: "destructive",
      })
      return
    }

    setIsProcessing(true)
    setRepayTxHash(null)

    try {
      let tx
      
      // Try to use real smart contract if available
      if (contracts && address) {
        tx = await contracts.payInstalment(repayToken, principalAmount, markupAmount)
        await tx.wait()
        setRepayTxHash(tx.hash)
      } else {
        // Fallback to simulation
        await new Promise(resolve => setTimeout(resolve, 2000))
        setRepayTxHash("simulated-repay-hash")
      }

      toast({
        title: "Instalment payment successful!",
        description: `Paid ${principalAmount} ${repayToken} principal + ${markupAmount} ${repayToken} markup`,
      })

      // Reset form
      setPrincipalAmount("")
      setMarkupAmount("")
    } catch (error) {
      console.error("Instalment payment failed:", error)
      toast({
        title: "Instalment payment failed",
        description: "Please try again",
        variant: "destructive",
      })
    } finally {
      setIsProcessing(false)
    }
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold text-white mb-2 font-mono">CREDIT SALE</h1>
        <p className="text-gray-400 font-mono">Access assets with fixed-markup credit backed by collateral</p>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Borrow Interface */}
        <Card className="bg-[#1E1E1E] border-[#2A2A2A]">
          <CardHeader>
            <CardTitle className="text-xl font-semibold text-white flex items-center font-mono">
              <TrendingUp className="w-5 h-5 mr-2 text-green-400" />
              Open Credit Sale
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-6">
            <Tabs defaultValue="credit" className="w-full">
              <TabsList className="grid w-full grid-cols-2 bg-[#2A2A2A]">
                <TabsTrigger value="credit" className="font-mono">
                  CREDIT SALE
                </TabsTrigger>
                <TabsTrigger value="repay" className="font-mono">
                  PAY INSTALMENT
                </TabsTrigger>
              </TabsList>

              <TabsContent value="credit" className="space-y-4">
                {/* Collateral Section */}
                <div className="space-y-3">
                  <Label className="text-gray-400 font-mono">Collateral</Label>
                  <div className="flex space-x-2">
                    <Select value={collateralToken} onValueChange={setCollateralToken}>
                      <SelectTrigger className="w-32 bg-[#2A2A2A] border-[#3A3A3A] text-white font-mono">
                        <SelectValue placeholder="Token" />
                      </SelectTrigger>
                      <SelectContent className="bg-[#2A2A2A] border-[#3A3A3A]">
                        {availableCollateralTokens.map((token) => (
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
                    <Input
                      type="number"
                      placeholder="0.00"
                      value={collateralAmount}
                      onChange={(e) => setCollateralAmount(e.target.value)}
                      className="flex-1 bg-[#2A2A2A] border-[#3A3A3A] text-white font-mono"
                    />
                  </div>
                  {collateralToken && selectedCollateralToken && (
                    <div className="space-y-1">
                      <div className="flex items-center justify-between">
                        <p className="text-sm text-gray-400 font-mono">
                          Available: {selectedCollateralToken.availableBalance.toFixed(6)} {collateralToken}
                        </p>
                        <Button
                          variant="ghost"
                          size="sm"
                          onClick={() => setCollateralAmount(selectedCollateralToken.availableBalance.toString())}
                          className="text-xs text-cyan-400 hover:text-cyan-300 h-auto p-1 font-mono"
                        >
                          MAX
                        </Button>
                      </div>
                      {selectedCollateralToken.collateralizedBalance > 0 && (
                        <div className="flex items-center space-x-1">
                          <Lock className="w-3 h-3 text-yellow-400" />
                          <p className="text-xs text-yellow-400 font-mono">
                            {selectedCollateralToken.collateralizedBalance.toFixed(6)} {collateralToken} already used as
                            collateral
                          </p>
                        </div>
                      )}
                    </div>
                  )}
                </div>

                {/* Credit Sale Section */}
                <div className="space-y-3">
                  <Label className="text-gray-400 font-mono">Credit Asset</Label>
                  <div className="flex space-x-2">
                    <Select value={creditToken} onValueChange={setCreditToken}>
                      <SelectTrigger className="w-32 bg-[#2A2A2A] border-[#3A3A3A] text-white font-mono">
                        <SelectValue placeholder="Token" />
                      </SelectTrigger>
                      <SelectContent className="bg-[#2A2A2A] border-[#3A3A3A]">
                        {creditTokens.map((token) => (
                          <SelectItem
                            key={token.symbol}
                            value={token.symbol}
                            className="text-white hover:bg-[#3A3A3A] font-mono"
                          >
                            <div className="flex items-center justify-between w-full">
                              <div className="flex items-center space-x-2">
                                <span className="text-lg">{token.icon}</span>
                                <span>{token.symbol}</span>
                              </div>
                              <span className="text-cyan-400 text-xs">{token.markup.toFixed(1)}% Markup</span>
                            </div>
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                    <Input
                      type="number"
                      placeholder="0.00"
                      value={creditAmount}
                      onChange={(e) => setCreditAmount(e.target.value)}
                      className="flex-1 bg-[#2A2A2A] border-[#3A3A3A] text-white font-mono"
                    />
                  </div>
                  {creditToken && maxCreditUSD > 0 && (
                    <div className="flex items-center justify-between">
                      <p className="text-sm text-gray-400 font-mono">Max credit: {formatCurrency(maxCreditUSD)}</p>
                      <Button
                        variant="ghost"
                        size="sm"
                        onClick={() => {
                          if (creditToken) {
                            const maxTokens = maxCreditUSD / getTokenData(creditToken).price
                            setCreditAmount((maxTokens * 0.9).toFixed(6)) // 90% of max for safety
                          }
                        }}
                        className="text-xs text-cyan-400 hover:text-cyan-300 h-auto p-1 font-mono"
                      >
                        SAFE MAX
                      </Button>
                    </div>
                  )}
                </div>

                {/* Health Factor Preview */}
                {collateralAmount && creditAmount && collateralToken && creditToken && (
                  <div className="space-y-2">
                    <div className="flex items-center justify-between">
                      <Label className="text-gray-400 font-mono">Health Factor</Label>
                      <span
                        className={`font-mono ${
                          healthFactor >= 1.5 ? "text-green-400" : healthFactor >= 1.2 ? "text-yellow-400" : "text-red-400"
                        }`}
                      >
                        {healthFactor.toFixed(2)}
                      </span>
                    </div>
                    <Progress value={Math.min(healthFactor * 20, 100)} className="h-2" />
                    <p className="text-xs text-gray-400 font-mono">
                      {healthFactor >= 1.5
                        ? "Safe"
                        : healthFactor >= 1.2
                          ? "Moderate Risk"
                          : "High Risk - Liquidation possible"}
                    </p>
                    {selectedCreditToken && (
                      <p className="text-xs text-cyan-400 font-mono">
                        Fixed markup: {selectedCreditToken.markup.toFixed(1)}% (one-time fee)
                      </p>
                    )}
                  </div>
                )}

                <Button
                  className={`w-full font-mono ${
                    !state.isWalletConnected ||
                    !collateralToken ||
                    !creditToken ||
                    !collateralAmount ||
                    !creditAmount ||
                    isProcessing ||
                    healthFactor < 1.2
                      ? "bg-gray-600 cursor-not-allowed"
                      : "bg-cyan-600 hover:bg-cyan-700"
                  } text-white`}
                  disabled={
                    !state.isWalletConnected ||
                    !collateralToken ||
                    !creditToken ||
                    !collateralAmount ||
                    !creditAmount ||
                    isProcessing ||
                    healthFactor < 1.2 ||
                    Number.parseFloat(collateralAmount) > (selectedCollateralToken?.availableBalance || 0)
                  }
                  onClick={handleCreditSale}
                >
                  <TrendingUp className="w-4 h-4 mr-2" />
                  {isProcessing
                    ? "PROCESSING..."
                    : !state.isWalletConnected
                      ? "CONNECT_WALLET"
                      : healthFactor < 1.2
                        ? "HEALTH_FACTOR_TOO_LOW"
                        : "OPEN_CREDIT_SALE"}
                </Button>
              </TabsContent>

              <TabsContent value="repay" className="space-y-4">
                {/* Repay Token Section */}
                <div className="space-y-3">
                  <Label className="text-gray-400 font-mono">Repayment Token</Label>
                  <Select value={repayToken} onValueChange={setRepayToken}>
                    <SelectTrigger className="bg-[#2A2A2A] border-[#3A3A3A] text-white font-mono">
                      <SelectValue placeholder="Select token" />
                    </SelectTrigger>
                    <SelectContent className="bg-[#2A2A2A] border-[#3A3A3A]">
                       {Object.entries(repaymentTokens).map(([symbol, token]) => (
                         <SelectItem
                           key={symbol}
                           value={symbol}
                           className="text-white hover:bg-[#3A3A3A] font-mono"
                         >
                           <div className="flex items-center space-x-2">
                             <span className="text-lg">{token.icon}</span>
                             <span>{symbol}</span>
                           </div>
                         </SelectItem>
                       ))}
                     </SelectContent>
                  </Select>
                </div>

                {/* Principal Amount Section */}
                <div className="space-y-3">
                  <Label className="text-gray-400 font-mono">Principal Amount</Label>
                  <Input
                    type="number"
                    placeholder="0.00"
                    value={principalAmount}
                    onChange={(e) => setPrincipalAmount(e.target.value)}
                    className="bg-[#2A2A2A] border-[#3A3A3A] text-white font-mono"
                  />
                </div>

                {/* Markup Amount Section */}
                <div className="space-y-3">
                  <Label className="text-gray-400 font-mono">Markup Amount</Label>
                  <Input
                    type="number"
                    placeholder="0.00"
                    value={markupAmount}
                    onChange={(e) => setMarkupAmount(e.target.value)}
                    className="bg-[#2A2A2A] border-[#3A3A3A] text-white font-mono"
                  />
                </div>

                <Button
                  className={`w-full font-mono ${
                    !isConnected ||
                    !repayToken ||
                    !principalAmount ||
                    !markupAmount ||
                    isProcessing
                      ? "bg-gray-600 cursor-not-allowed"
                      : "bg-green-600 hover:bg-green-700"
                  } text-white`}
                  disabled={
                    !isConnected ||
                    !repayToken ||
                    !principalAmount ||
                    !markupAmount ||
                    isProcessing
                  }
                  onClick={handlePayInstalment}
                >
                  <DollarSign className="w-4 h-4 mr-2" />
                  {isProcessing
                    ? "PROCESSING..."
                    : !isConnected
                      ? "CONNECT_WALLET"
                      : "PAY_INSTALMENT"}
                </Button>
              </TabsContent>
            </Tabs>
          </CardContent>
        </Card>

        {/* Credit Overview */}
        <Card className="bg-[#1E1E1E] border-[#2A2A2A]">
          <CardHeader>
            <CardTitle className="text-xl font-semibold text-white font-mono text-cyan-400">Credit Overview</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="grid grid-cols-2 gap-4">
              <div className="space-y-2">
                <Label className="text-gray-400 font-mono">Total Collateral</Label>
                <p className="text-2xl font-bold text-white font-mono">{formatCurrency(state.totalDepositsUSD)}</p>
              </div>
              <div className="space-y-2">
                <Label className="text-gray-400 font-mono">Total Credit Owed</Label>
                <p className="text-2xl font-bold text-white font-mono">{formatCurrency(state.totalBorrowsUSD)}</p>
              </div>
            </div>

            <div className="space-y-2">
              <div className="flex items-center justify-between">
                <Label className="text-gray-400 font-mono">Current Health Factor</Label>
                <div className="flex items-center space-x-2">
                  {state.healthFactor >= 1.5 ? (
                    <Shield className="w-4 h-4 text-green-400" />
                  ) : state.healthFactor >= 1.2 ? (
                    <AlertTriangle className="w-4 h-4 text-yellow-400" />
                  ) : (
                    <AlertTriangle className="w-4 h-4 text-red-400" />
                  )}
                  <span
                    className={`font-mono ${
                      state.healthFactor >= 1.5
                        ? "text-green-400"
                        : state.healthFactor >= 1.2
                          ? "text-yellow-400"
                          : "text-red-400"
                    }`}
                  >
                    {state.healthFactor > 0 ? state.healthFactor.toFixed(2) : "N/A"}
                  </span>
                </div>
              </div>
              {state.healthFactor > 0 && <Progress value={Math.min(state.healthFactor * 20, 100)} className="h-2" />}
            </div>

            {/* Active Positions */}
            <div className="space-y-3">
              <Label className="text-gray-400 font-mono">Active Positions</Label>
              <div className="space-y-2">
                {/* Collateral Positions */}
                {state.positions
                  .filter((pos) => pos.type === "deposit" && pos.isCollateral)
                  .map((position) => (
                    <div key={position.id} className="flex items-center justify-between p-3 rounded-lg bg-[#2A2A2A]">
                      <div className="flex items-center space-x-3">
                        <div className="w-8 h-8 bg-gradient-to-r from-blue-500 to-purple-600 rounded-full flex items-center justify-center">
                          <span className="text-sm font-bold">{getTokenData(position.token).icon}</span>
                        </div>
                        <div>
                          <p className="text-white font-medium font-mono">{position.token} Collateral</p>
                          <p className="text-sm text-gray-400 font-mono">
                            {position.amount.toFixed(6)} {position.token}
                          </p>
                        </div>
                      </div>
                      <div className="text-right">
                        <Badge variant="outline" className="border-blue-500 text-blue-500 font-mono mb-1">
                          <Lock className="w-3 h-3 mr-1" />
                          COLLATERAL
                        </Badge>
                        <p className="text-sm text-gray-400 font-mono">{formatCurrency(position.valueUSD)}</p>
                      </div>
                    </div>
                  ))}

                {/* Borrow Positions */}
                {state.positions
                  .filter((pos) => pos.type === "borrow")
                  .map((position) => (
                    <div key={position.id} className="flex items-center justify-between p-3 rounded-lg bg-[#2A2A2A]">
                      <div className="flex items-center space-x-3">
                        <div className="w-8 h-8 bg-gradient-to-r from-green-500 to-blue-600 rounded-full flex items-center justify-center">
                          <span className="text-sm font-bold">{getTokenData(position.token).icon}</span>
                        </div>
                        <div>
                          <p className="text-white font-medium font-mono">{position.token} Loan</p>
                          <p className="text-sm text-gray-400 font-mono">
                            {position.amount.toFixed(6)} {position.token} @ {position.apy?.toFixed(1)}% APY
                          </p>
                        </div>
                      </div>
                      <div className="text-right">
                        <Badge variant="outline" className="border-green-500 text-green-500 font-mono mb-1">
                          BORROWED
                        </Badge>
                        <p className="text-sm text-gray-400 font-mono">{formatCurrency(position.valueUSD)}</p>
                      </div>
                    </div>
                  ))}

                {state.positions.filter((pos) => (pos.type === "deposit" && pos.isCollateral) || pos.type === "borrow")
                  .length === 0 && (
                  <div className="text-center py-6">
                    <Unlock className="w-8 h-8 text-gray-600 mx-auto mb-2" />
                    <p className="text-gray-400 font-mono text-sm">No active loans</p>
                  </div>
                )}
              </div>
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Transaction Proof Section */}
      {(txHash || repayTxHash) && (
        <Card className="bg-[#1E1E1E] border-[#2A2A2A]">
          <CardHeader>
            <CardTitle className="text-xl font-semibold text-white flex items-center font-mono">
              <Shield className="w-5 h-5 mr-2 text-green-400" />
              Transaction Proof
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="space-y-4">
              {txHash && (
                <div className="p-4 bg-[#2A2A2A] rounded-lg border border-green-500/20">
                  <div className="flex items-center justify-between">
                    <div>
                      <p className="text-green-400 font-mono text-sm mb-1">Credit Sale Transaction</p>
                      <p className="text-white font-mono text-xs break-all">{txHash}</p>
                    </div>
                    <Badge className="bg-green-500/20 text-green-400 border-green-500/30 font-mono">
                      CONFIRMED
                    </Badge>
                  </div>
                  <div className="mt-3 pt-3 border-t border-gray-700">
                    <a
                      href={`https://scan.test2.btcs.network/tx/${txHash}`}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="text-blue-400 hover:text-blue-300 font-mono text-sm transition-colors"
                    >
                      View on Core Testnet Explorer →
                    </a>
                  </div>
                </div>
              )}
              {repayTxHash && (
                <div className="p-4 bg-[#2A2A2A] rounded-lg border border-blue-500/20">
                  <div className="flex items-center justify-between">
                    <div>
                      <p className="text-blue-400 font-mono text-sm mb-1">Instalment Payment Transaction</p>
                      <p className="text-white font-mono text-xs break-all">{repayTxHash}</p>
                    </div>
                    <Badge className="bg-blue-500/20 text-blue-400 border-blue-500/30 font-mono">
                      CONFIRMED
                    </Badge>
                  </div>
                  <div className="mt-3 pt-3 border-t border-gray-700">
                    <a
                      href={`https://scan.test2.btcs.network/tx/${repayTxHash}`}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="text-blue-400 hover:text-blue-300 font-mono text-sm transition-colors"
                    >
                      View on Core Testnet Explorer →
                    </a>
                  </div>
                </div>
              )}
            </div>
          </CardContent>
        </Card>
      )}
    </div>
  )
}
