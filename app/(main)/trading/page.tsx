'use client';

import React, { useState, useEffect, useCallback } from 'react';
import { useAccount, useBalance, useContractRead, useContractWrite } from 'wagmi';
import { formatEther, parseEther, formatUnits } from 'viem';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { Badge } from '@/components/ui/badge';
import { Progress } from '@/components/ui/progress';
import { Alert, AlertDescription } from '@/components/ui/alert';
import { Separator } from '@/components/ui/separator';
import { Switch } from '@/components/ui/switch';
import { Slider } from '@/components/ui/slider';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle, DialogTrigger } from '@/components/ui/dialog';
import { Tooltip, TooltipContent, TooltipProvider, TooltipTrigger } from '@/components/ui/tooltip';
import { ArrowUpDownIcon, ArrowRightIcon, TrendingUpIcon, TrendingDownIcon, InfoIcon, AlertTriangleIcon, CheckCircleIcon, XCircleIcon, RefreshCwIcon, BarChart3Icon, PieChartIcon, ActivityIcon, DollarSignIcon, PercentIcon, ClockIcon, ShieldIcon, ZapIcon, SettingsIcon, LineChartIcon, CandlestickChartIcon, Volume2Icon, TimerIcon, TargetIcon } from 'lucide-react';
import { toast } from '@/hooks/use-toast';
import { cn } from '@/lib/utils';

// Contract ABIs and addresses
const UNIFIED_AMM_ABI = [
  {
    "inputs": [{"name": "tokenA", "type": "address"}, {"name": "tokenB", "type": "address"}, {"name": "amountIn", "type": "uint256"}, {"name": "amountOutMin", "type": "uint256"}, {"name": "to", "type": "address"}, {"name": "deadline", "type": "uint256"}],
    "name": "swapExactTokensForTokens",
    "outputs": [{"name": "amounts", "type": "uint256[]"}],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [{"name": "tokenA", "type": "address"}, {"name": "tokenB", "type": "address"}, {"name": "amountIn", "type": "uint256"}],
    "name": "getAmountOut",
    "outputs": [{"name": "amountOut", "type": "uint256"}],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [{"name": "tokenA", "type": "address"}, {"name": "tokenB", "type": "address"}],
    "name": "getPair",
    "outputs": [{"name": "pair", "type": "address"}],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [{"name": "pair", "type": "address"}],
    "name": "getReserves",
    "outputs": [{"name": "reserveA", "type": "uint256"}, {"name": "reserveB", "type": "uint256"}],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [{"name": "tokenA", "type": "address"}, {"name": "tokenB", "type": "address"}, {"name": "amountIn", "type": "uint256"}, {"name": "limitPrice", "type": "uint256"}, {"name": "deadline", "type": "uint256"}],
    "name": "placeLimitOrder",
    "outputs": [{"name": "orderId", "type": "uint256"}],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [{"name": "orderId", "type": "uint256"}],
    "name": "cancelLimitOrder",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [{"name": "user", "type": "address"}],
    "name": "getUserOrders",
    "outputs": [
      {"name": "orderIds", "type": "uint256[]"},
      {"name": "tokenAs", "type": "address[]"},
      {"name": "tokenBs", "type": "address[]"},
      {"name": "amounts", "type": "uint256[]"},
      {"name": "limitPrices", "type": "uint256[]"},
      {"name": "statuses", "type": "uint8[]"}
    ],
    "stateMutability": "view",
    "type": "function"
  }
];

const ERC20_ABI = [
  {
    "inputs": [{"name": "spender", "type": "address"}, {"name": "amount", "type": "uint256"}],
    "name": "approve",
    "outputs": [{"name": "", "type": "bool"}],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [{"name": "account", "type": "address"}],
    "name": "balanceOf",
    "outputs": [{"name": "", "type": "uint256"}],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "decimals",
    "outputs": [{"name": "", "type": "uint8"}],
    "stateMutability": "view",
    "type": "function"
  }
];

// Mock contract addresses
const UNIFIED_AMM_ADDRESS = '0x1234567890123456789012345678901234567890';
const USDC_ADDRESS = '0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174';
const WETH_ADDRESS = '0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619';
const WBTC_ADDRESS = '0x1BFD67037B42Cf73acF2047067bd4F2C47D9BfD6';
const CORE_ADDRESS = '0x40375C92d9FAf44d2f9db9Bd9ba41a3317a2404f';

interface Token {
  address: string;
  symbol: string;
  name: string;
  decimals: number;
  icon: string;
  price: number;
  change24h: number;
  volume24h: string;
  marketCap: string;
  isActive: boolean;
}

interface TradingPair {
  tokenA: Token;
  tokenB: Token;
  price: number;
  change24h: number;
  volume24h: string;
  liquidity: string;
  fee: number;
  apy: number;
}

interface LimitOrder {
  id: string;
  tokenA: Token;
  tokenB: Token;
  type: 'buy' | 'sell';
  amount: string;
  limitPrice: string;
  currentPrice: string;
  status: 'pending' | 'filled' | 'cancelled' | 'expired';
  createdAt: Date;
  expiresAt: Date;
  filled: string;
  remaining: string;
}

interface TradeHistory {
  id: string;
  pair: string;
  type: 'buy' | 'sell';
  amount: string;
  price: string;
  total: string;
  fee: string;
  timestamp: Date;
  txHash: string;
}

const SUPPORTED_TOKENS: Token[] = [
  {
    address: USDC_ADDRESS,
    symbol: 'USDC',
    name: 'USD Coin',
    decimals: 6,
    icon: '💵',
    price: 1.00,
    change24h: 0.02,
    volume24h: '125000000',
    marketCap: '32500000000',
    isActive: true
  },
  {
    address: WETH_ADDRESS,
    symbol: 'WETH',
    name: 'Wrapped Ethereum',
    decimals: 18,
    icon: '⚡',
    price: 2340.50,
    change24h: 2.45,
    volume24h: '890000000',
    marketCap: '281000000000',
    isActive: true
  },
  {
    address: WBTC_ADDRESS,
    symbol: 'WBTC',
    name: 'Wrapped Bitcoin',
    decimals: 8,
    icon: '₿',
    price: 43250.75,
    change24h: -1.23,
    volume24h: '1200000000',
    marketCap: '850000000000',
    isActive: true
  },
  {
    address: CORE_ADDRESS,
    symbol: 'CORE',
    name: 'Core DAO Token',
    decimals: 18,
    icon: '🔥',
    price: 1.85,
    change24h: 8.92,
    volume24h: '45000000',
    marketCap: '1850000000',
    isActive: true
  }
];

const TRADING_PAIRS: TradingPair[] = [
  {
    tokenA: SUPPORTED_TOKENS[1], // WETH
    tokenB: SUPPORTED_TOKENS[0], // USDC
    price: 2340.50,
    change24h: 2.45,
    volume24h: '125000000',
    liquidity: '45000000',
    fee: 0.3,
    apy: 12.5
  },
  {
    tokenA: SUPPORTED_TOKENS[2], // WBTC
    tokenB: SUPPORTED_TOKENS[0], // USDC
    price: 43250.75,
    change24h: -1.23,
    volume24h: '89000000',
    liquidity: '32000000',
    fee: 0.3,
    apy: 8.9
  },
  {
    tokenA: SUPPORTED_TOKENS[3], // CORE
    tokenB: SUPPORTED_TOKENS[0], // USDC
    price: 1.85,
    change24h: 8.92,
    volume24h: '12000000',
    liquidity: '8500000',
    fee: 0.25,
    apy: 25.8
  }
];

export default function TradingPage() {
  const { address, isConnected } = useAccount();
  const [selectedPair, setSelectedPair] = useState<TradingPair>(TRADING_PAIRS[0]);
  const [fromToken, setFromToken] = useState<Token>(SUPPORTED_TOKENS[1]);
  const [toToken, setToToken] = useState<Token>(SUPPORTED_TOKENS[0]);
  const [fromAmount, setFromAmount] = useState('');
  const [toAmount, setToAmount] = useState('');
  const [slippageTolerance, setSlippageTolerance] = useState(0.5);
  const [deadline, setDeadline] = useState(20);
  const [isLoading, setIsLoading] = useState(false);
  const [refreshing, setRefreshing] = useState(false);
  const [autoRefresh, setAutoRefresh] = useState(true);
  const [showAdvanced, setShowAdvanced] = useState(false);
  const [tradeType, setTradeType] = useState<'market' | 'limit'>('market');
  const [limitPrice, setLimitPrice] = useState('');
  const [orderExpiry, setOrderExpiry] = useState('1d');
  const [userOrders, setUserOrders] = useState<LimitOrder[]>([]);
  const [tradeHistory, setTradeHistory] = useState<TradeHistory[]>([]);
  const [chartTimeframe, setChartTimeframe] = useState('1h');
  const [chartType, setChartType] = useState<'line' | 'candle'>('line');

  // Contract reads
  const { data: fromTokenBalance } = useBalance({
    address: address,
    token: fromToken.address as `0x${string}`
  });

  const { data: toTokenBalance } = useBalance({
    address: address,
    token: toToken.address as `0x${string}`
  });

  const { data: estimatedOutput } = useContractRead({
    address: UNIFIED_AMM_ADDRESS as `0x${string}`,
    abi: UNIFIED_AMM_ABI,
    functionName: 'getAmountOut',
    args: [fromToken.address, toToken.address, parseEther(fromAmount || '0')]
  });

  // Contract writes
  const { writeContract: executeSwap, isPending: isSwapping } = useContractWrite({
    mutation: {
      onSuccess: () => {
        toast({
          title: "Swap Successful",
          description: `Successfully swapped ${fromAmount} ${fromToken.symbol} for ${toAmount} ${toToken.symbol}`,
        });
        setFromAmount('');
        setToAmount('');
        refreshData();
      },
      onError: (error: any) => {
        toast({
          title: "Swap Failed",
          description: error.message,
          variant: "destructive"
        });
      }
    }
  });

  const { writeContract: placeLimitOrder, isPending: isPlacingOrder } = useContractWrite({
    mutation: {
      onSuccess: () => {
        toast({
          title: "Limit Order Placed",
          description: `Limit order placed for ${fromAmount} ${fromToken.symbol} at ${limitPrice} ${toToken.symbol}`,
        });
        setFromAmount('');
        setLimitPrice('');
        refreshData();
      },
      onError: (error: any) => {
        toast({
          title: "Order Failed",
          description: error.message,
          variant: "destructive"
        });
      }
    }
  });

  // Approve token spending
  const { writeContract: approve, isPending: isApproving } = useContractWrite({
    mutation: {
      onSuccess: () => {
        toast({
          title: "Approval Successful",
          description: `Approved ${fromToken.symbol} spending`,
        });
      },
      onError: (error: any) => {
        toast({
          title: "Approval Failed",
          description: error.message,
          variant: "destructive"
        });
      }
    }
  });

  const refreshData = useCallback(async () => {
    if (!address) return;
    
    setRefreshing(true);
    try {
      // Simulate API calls to refresh data
      await new Promise(resolve => setTimeout(resolve, 1000));
      
      // Update estimated output
      if (estimatedOutput) {
        setToAmount(formatEther(estimatedOutput as bigint));
      }
    } catch (error) {
      console.error('Error refreshing data:', error);
    } finally {
      setRefreshing(false);
    }
  }, [address, estimatedOutput]);

  useEffect(() => {
    refreshData();
  }, [refreshData]);

  useEffect(() => {
    if (!autoRefresh) return;
    
    const interval = setInterval(refreshData, 10000); // Refresh every 10 seconds
    return () => clearInterval(interval);
  }, [autoRefresh, refreshData]);

  useEffect(() => {
    if (estimatedOutput && fromAmount) {
      const output = formatEther(estimatedOutput as bigint);
      setToAmount(output);
    }
  }, [estimatedOutput, fromAmount]);

  const getExpirySeconds = (expiry: string): number => {
    switch (expiry) {
      case '1h': return 3600;
      case '1d': return 86400;
      case '1w': return 604800;
      case '1m': return 2592000;
      default: return 86400;
    }
  };

  const handleSwapTokens = () => {
    const tempToken = fromToken;
    setFromToken(toToken);
    setToToken(tempToken);
    setFromAmount(toAmount);
    setToAmount(fromAmount);
  };

  const handleMaxAmount = () => {
    if (fromTokenBalance) {
      setFromAmount(formatUnits(fromTokenBalance.value, fromToken.decimals));
    }
  };

  const calculatePriceImpact = (): number => {
    if (!fromAmount || !toAmount) return 0;
    const expectedPrice = fromToken.price / toToken.price;
    const actualPrice = parseFloat(fromAmount) / parseFloat(toAmount);
    return Math.abs((actualPrice - expectedPrice) / expectedPrice) * 100;
  };

  const calculateMinReceived = (): string => {
    if (!toAmount) return '0';
    const minAmount = parseFloat(toAmount) * (1 - slippageTolerance / 100);
    return minAmount.toFixed(6);
  };

  const handleTrade = () => {
    if (!fromAmount || parseFloat(fromAmount) <= 0) {
      toast({
        title: "Invalid Amount",
        description: "Please enter a valid trade amount",
        variant: "destructive"
      });
      return;
    }

    try {
      // First approve if needed
      if (approve) {
        approve({
          address: fromToken.address as `0x${string}`,
          abi: ERC20_ABI,
          functionName: 'approve',
          args: [UNIFIED_AMM_ADDRESS, parseEther(fromAmount || '0')]
        });
      }
      
      // Then execute trade
      if (tradeType === 'market' && executeSwap) {
        executeSwap({
          address: UNIFIED_AMM_ADDRESS as `0x${string}`,
          abi: UNIFIED_AMM_ABI,
          functionName: 'swapExactTokensForTokens',
          args: [
            fromToken.address,
            toToken.address,
            parseEther(fromAmount || '0'),
            parseEther(toAmount || '0'),
            address,
            Math.floor(Date.now() / 1000) + (deadline * 60)
          ]
        });
      } else if (tradeType === 'limit' && placeLimitOrder) {
        placeLimitOrder({
          address: UNIFIED_AMM_ADDRESS as `0x${string}`,
          abi: UNIFIED_AMM_ABI,
          functionName: 'placeLimitOrder',
          args: [
            fromToken.address,
            toToken.address,
            parseEther(fromAmount || '0'),
            parseEther(limitPrice || '0'),
            Math.floor(Date.now() / 1000) + getExpirySeconds(orderExpiry)
          ]
        });
      }
    } catch (error) {
      console.error('Trade error:', error);
    }
  };

  const formatNumber = (num: number | string, decimals: number = 2): string => {
    const n = typeof num === 'string' ? parseFloat(num) : num;
    if (n >= 1e9) return (n / 1e9).toFixed(decimals) + 'B';
    if (n >= 1e6) return (n / 1e6).toFixed(decimals) + 'M';
    if (n >= 1e3) return (n / 1e3).toFixed(decimals) + 'K';
    return n.toFixed(decimals);
  };

  if (!isConnected) {
    return (
      <div className="container mx-auto px-4 py-8">
        <div className="text-center">
          <h1 className="text-4xl font-bold mb-4">CoreLiquid Trading</h1>
          <p className="text-muted-foreground mb-8">Connect your wallet to start trading</p>
          <Card className="max-w-md mx-auto">
            <CardContent className="pt-6">
              <div className="text-center">
                <ShieldIcon className="h-12 w-12 mx-auto mb-4 text-muted-foreground" />
                <h3 className="text-lg font-semibold mb-2">Wallet Connection Required</h3>
                <p className="text-sm text-muted-foreground mb-4">
                  Please connect your wallet to access trading features
                </p>
                <Button className="w-full">
                  Connect Wallet
                </Button>
              </div>
            </CardContent>
          </Card>
        </div>
      </div>
    );
  }

  return (
    <div className="container mx-auto px-4 py-8 space-y-8">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-4xl font-bold">Trading</h1>
          <p className="text-muted-foreground mt-2">
            Trade tokens with advanced AMM and limit order features
          </p>
        </div>
        <div className="flex items-center space-x-4">
          <TooltipProvider>
            <Tooltip>
              <TooltipTrigger asChild>
                <Button
                  variant="outline"
                  size="icon"
                  onClick={refreshData}
                  disabled={refreshing}
                >
                  <RefreshCwIcon className={cn("h-4 w-4", refreshing && "animate-spin")} />
                </Button>
              </TooltipTrigger>
              <TooltipContent>
                <p>Refresh prices</p>
              </TooltipContent>
            </Tooltip>
          </TooltipProvider>
          
          <Dialog>
            <DialogTrigger asChild>
              <Button variant="outline">
                <SettingsIcon className="h-4 w-4 mr-2" />
                Settings
              </Button>
            </DialogTrigger>
            <DialogContent>
              <DialogHeader>
                <DialogTitle>Trading Settings</DialogTitle>
                <DialogDescription>
                  Customize your trading experience
                </DialogDescription>
              </DialogHeader>
              <div className="space-y-6">
                <div className="flex items-center justify-between">
                  <Label htmlFor="auto-refresh">Auto Refresh Prices</Label>
                  <Switch
                    id="auto-refresh"
                    checked={autoRefresh}
                    onCheckedChange={setAutoRefresh}
                  />
                </div>
                <div className="space-y-2">
                  <Label>Default Slippage Tolerance</Label>
                  <Slider
                    value={[slippageTolerance]}
                    onValueChange={(value) => setSlippageTolerance(value[0])}
                    max={5}
                    min={0.1}
                    step={0.1}
                    className="w-full"
                  />
                  <div className="text-sm text-muted-foreground">
                    {slippageTolerance}%
                  </div>
                </div>
                <div className="space-y-2">
                  <Label>Default Deadline</Label>
                  <Slider
                    value={[deadline]}
                    onValueChange={(value) => setDeadline(value[0])}
                    max={60}
                    min={5}
                    step={5}
                    className="w-full"
                  />
                  <div className="text-sm text-muted-foreground">
                    {deadline} minutes
                  </div>
                </div>
              </div>
            </DialogContent>
          </Dialog>
        </div>
      </div>

      {/* Market Overview */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">24h Volume</CardTitle>
            <Volume2Icon className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">
              ${formatNumber(1250000000)}
            </div>
            <p className="text-xs text-muted-foreground">
              +12.5% from yesterday
            </p>
          </CardContent>
        </Card>
        
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Total Liquidity</CardTitle>
            <DollarSignIcon className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">
              ${formatNumber(85500000)}
            </div>
            <p className="text-xs text-muted-foreground">
              Across all pairs
            </p>
          </CardContent>
        </Card>
        
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Active Pairs</CardTitle>
            <ActivityIcon className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">
              {TRADING_PAIRS.length}
            </div>
            <p className="text-xs text-muted-foreground">
              Trading pairs available
            </p>
          </CardContent>
        </Card>
        
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Avg APY</CardTitle>
            <PercentIcon className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-green-600">
              {(TRADING_PAIRS.reduce((sum, pair) => sum + pair.apy, 0) / TRADING_PAIRS.length).toFixed(1)}%
            </div>
            <p className="text-xs text-muted-foreground">
              Liquidity provider rewards
            </p>
          </CardContent>
        </Card>
      </div>

      {/* Main Trading Interface */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
        {/* Trading Panel */}
        <div className="lg:col-span-1">
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center">
                <ArrowUpDownIcon className="h-5 w-5 mr-2" />
                Trade
              </CardTitle>
              <CardDescription>
                Swap tokens instantly or place limit orders
              </CardDescription>
            </CardHeader>
            <CardContent>
              <Tabs value={tradeType} onValueChange={(value: any) => setTradeType(value)} className="w-full">
                <TabsList className="grid w-full grid-cols-2">
                  <TabsTrigger value="market">Market</TabsTrigger>
                  <TabsTrigger value="limit">Limit</TabsTrigger>
                </TabsList>
                
                <TabsContent value="market" className="space-y-6">
                  <div className="space-y-4">
                    {/* From Token */}
                    <div className="space-y-2">
                      <div className="flex items-center justify-between">
                        <Label>From</Label>
                        <div className="text-sm text-muted-foreground">
                          Balance: {fromTokenBalance ? formatUnits(fromTokenBalance.value, fromToken.decimals) : '0'}
                        </div>
                      </div>
                      <div className="flex space-x-2">
                        <Select
                          value={fromToken.address}
                          onValueChange={(value) => {
                            const token = SUPPORTED_TOKENS.find(t => t.address === value);
                            if (token) setFromToken(token);
                          }}
                        >
                          <SelectTrigger className="w-32">
                            <SelectValue />
                          </SelectTrigger>
                          <SelectContent>
                            {SUPPORTED_TOKENS.map((token) => (
                              <SelectItem key={token.address} value={token.address}>
                                <div className="flex items-center">
                                  <span className="mr-2">{token.icon}</span>
                                  <span>{token.symbol}</span>
                                </div>
                              </SelectItem>
                            ))}
                          </SelectContent>
                        </Select>
                        <Input
                          type="number"
                          placeholder="0.0"
                          value={fromAmount}
                          onChange={(e) => setFromAmount(e.target.value)}
                          className="flex-1"
                        />
                        <Button variant="outline" size="sm" onClick={handleMaxAmount}>
                          MAX
                        </Button>
                      </div>
                    </div>
                    
                    {/* Swap Button */}
                    <div className="flex justify-center">
                      <Button
                        variant="outline"
                        size="icon"
                        onClick={handleSwapTokens}
                        className="rounded-full"
                      >
                        <ArrowUpDownIcon className="h-4 w-4" />
                      </Button>
                    </div>
                    
                    {/* To Token */}
                    <div className="space-y-2">
                      <div className="flex items-center justify-between">
                        <Label>To</Label>
                        <div className="text-sm text-muted-foreground">
                          Balance: {toTokenBalance ? formatUnits(toTokenBalance.value, toToken.decimals) : '0'}
                        </div>
                      </div>
                      <div className="flex space-x-2">
                        <Select
                          value={toToken.address}
                          onValueChange={(value) => {
                            const token = SUPPORTED_TOKENS.find(t => t.address === value);
                            if (token) setToToken(token);
                          }}
                        >
                          <SelectTrigger className="w-32">
                            <SelectValue />
                          </SelectTrigger>
                          <SelectContent>
                            {SUPPORTED_TOKENS.map((token) => (
                              <SelectItem key={token.address} value={token.address}>
                                <div className="flex items-center">
                                  <span className="mr-2">{token.icon}</span>
                                  <span>{token.symbol}</span>
                                </div>
                              </SelectItem>
                            ))}
                          </SelectContent>
                        </Select>
                        <Input
                          type="number"
                          placeholder="0.0"
                          value={toAmount}
                          onChange={(e) => setToAmount(e.target.value)}
                          className="flex-1"
                          readOnly
                        />
                      </div>
                    </div>
                    
                    {/* Trade Details */}
                    {fromAmount && toAmount && (
                      <div className="bg-muted p-4 rounded-lg space-y-2">
                        <div className="flex justify-between text-sm">
                          <span>Rate:</span>
                          <span>1 {fromToken.symbol} = {(parseFloat(toAmount) / parseFloat(fromAmount)).toFixed(6)} {toToken.symbol}</span>
                        </div>
                        <div className="flex justify-between text-sm">
                          <span>Price Impact:</span>
                          <span className={cn(
                            calculatePriceImpact() > 3 ? 'text-red-600' : 
                            calculatePriceImpact() > 1 ? 'text-yellow-600' : 'text-green-600'
                          )}>
                            {calculatePriceImpact().toFixed(2)}%
                          </span>
                        </div>
                        <div className="flex justify-between text-sm">
                          <span>Minimum received:</span>
                          <span>{calculateMinReceived()} {toToken.symbol}</span>
                        </div>
                        <div className="flex justify-between text-sm">
                          <span>Network fee:</span>
                          <span>~$2.50</span>
                        </div>
                      </div>
                    )}
                    
                    {/* Advanced Settings */}
                    <div className="space-y-4">
                      <Button
                        variant="ghost"
                        onClick={() => setShowAdvanced(!showAdvanced)}
                        className="w-full"
                      >
                        {showAdvanced ? 'Hide' : 'Show'} Advanced Settings
                      </Button>
                      
                      {showAdvanced && (
                        <div className="space-y-4 p-4 border rounded-lg">
                          <div className="space-y-2">
                            <Label>Slippage Tolerance</Label>
                            <div className="flex space-x-2">
                              {[0.1, 0.5, 1.0].map((value) => (
                                <Button
                                  key={value}
                                  variant={slippageTolerance === value ? "default" : "outline"}
                                  size="sm"
                                  onClick={() => setSlippageTolerance(value)}
                                >
                                  {value}%
                                </Button>
                              ))}
                              <Input
                                type="number"
                                placeholder="Custom"
                                value={slippageTolerance}
                                onChange={(e) => setSlippageTolerance(parseFloat(e.target.value) || 0.5)}
                                className="w-20"
                              />
                            </div>
                          </div>
                          
                          <div className="space-y-2">
                            <Label>Transaction Deadline</Label>
                            <div className="flex items-center space-x-2">
                              <Input
                                type="number"
                                value={deadline}
                                onChange={(e) => setDeadline(parseInt(e.target.value) || 20)}
                                className="w-20"
                              />
                              <span className="text-sm text-muted-foreground">minutes</span>
                            </div>
                          </div>
                        </div>
                      )}
                    </div>
                    
                    <Button
                      onClick={handleTrade}
                      disabled={!fromAmount || parseFloat(fromAmount) <= 0 || isSwapping || isApproving}
                      className="w-full"
                      size="lg"
                    >
                      {isApproving ? (
                        <>
                          <RefreshCwIcon className="h-4 w-4 mr-2 animate-spin" />
                          Approving...
                        </>
                      ) : isSwapping ? (
                        <>
                          <RefreshCwIcon className="h-4 w-4 mr-2 animate-spin" />
                          Swapping...
                        </>
                      ) : (
                        <>
                          <ZapIcon className="h-4 w-4 mr-2" />
                          Swap {fromToken.symbol}
                        </>
                      )}
                    </Button>
                  </div>
                </TabsContent>
                
                <TabsContent value="limit" className="space-y-6">
                  <div className="space-y-4">
                    {/* From Token */}
                    <div className="space-y-2">
                      <div className="flex items-center justify-between">
                        <Label>Sell</Label>
                        <div className="text-sm text-muted-foreground">
                          Balance: {fromTokenBalance ? formatUnits(fromTokenBalance.value, fromToken.decimals) : '0'}
                        </div>
                      </div>
                      <div className="flex space-x-2">
                        <Select
                          value={fromToken.address}
                          onValueChange={(value) => {
                            const token = SUPPORTED_TOKENS.find(t => t.address === value);
                            if (token) setFromToken(token);
                          }}
                        >
                          <SelectTrigger className="w-32">
                            <SelectValue />
                          </SelectTrigger>
                          <SelectContent>
                            {SUPPORTED_TOKENS.map((token) => (
                              <SelectItem key={token.address} value={token.address}>
                                <div className="flex items-center">
                                  <span className="mr-2">{token.icon}</span>
                                  <span>{token.symbol}</span>
                                </div>
                              </SelectItem>
                            ))}
                          </SelectContent>
                        </Select>
                        <Input
                          type="number"
                          placeholder="0.0"
                          value={fromAmount}
                          onChange={(e) => setFromAmount(e.target.value)}
                          className="flex-1"
                        />
                        <Button variant="outline" size="sm" onClick={handleMaxAmount}>
                          MAX
                        </Button>
                      </div>
                    </div>
                    
                    {/* To Token */}
                    <div className="space-y-2">
                      <Label>For</Label>
                      <Select
                        value={toToken.address}
                        onValueChange={(value) => {
                          const token = SUPPORTED_TOKENS.find(t => t.address === value);
                          if (token) setToToken(token);
                        }}
                      >
                        <SelectTrigger>
                          <SelectValue />
                        </SelectTrigger>
                        <SelectContent>
                          {SUPPORTED_TOKENS.map((token) => (
                            <SelectItem key={token.address} value={token.address}>
                              <div className="flex items-center">
                                <span className="mr-2">{token.icon}</span>
                                <span>{token.symbol}</span>
                              </div>
                            </SelectItem>
                          ))}
                        </SelectContent>
                      </Select>
                    </div>
                    
                    {/* Limit Price */}
                    <div className="space-y-2">
                      <div className="flex items-center justify-between">
                        <Label>Limit Price</Label>
                        <div className="text-sm text-muted-foreground">
                          Current: {(fromToken.price / toToken.price).toFixed(6)}
                        </div>
                      </div>
                      <div className="flex space-x-2">
                        <Input
                          type="number"
                          placeholder="0.0"
                          value={limitPrice}
                          onChange={(e) => setLimitPrice(e.target.value)}
                          className="flex-1"
                        />
                        <Button
                          variant="outline"
                          size="sm"
                          onClick={() => setLimitPrice((fromToken.price / toToken.price).toString())}
                        >
                          Market
                        </Button>
                      </div>
                    </div>
                    
                    {/* Order Expiry */}
                    <div className="space-y-2">
                      <Label>Expires In</Label>
                      <Select value={orderExpiry} onValueChange={setOrderExpiry}>
                        <SelectTrigger>
                          <SelectValue />
                        </SelectTrigger>
                        <SelectContent>
                          <SelectItem value="1h">1 Hour</SelectItem>
                          <SelectItem value="1d">1 Day</SelectItem>
                          <SelectItem value="1w">1 Week</SelectItem>
                          <SelectItem value="1m">1 Month</SelectItem>
                        </SelectContent>
                      </Select>
                    </div>
                    
                    {/* Order Summary */}
                    {fromAmount && limitPrice && (
                      <div className="bg-muted p-4 rounded-lg space-y-2">
                        <div className="flex justify-between text-sm">
                          <span>You will receive:</span>
                          <span>{(parseFloat(fromAmount) * parseFloat(limitPrice)).toFixed(6)} {toToken.symbol}</span>
                        </div>
                        <div className="flex justify-between text-sm">
                          <span>Order type:</span>
                          <span>Limit Order</span>
                        </div>
                        <div className="flex justify-between text-sm">
                          <span>Expires:</span>
                          <span>{orderExpiry === '1h' ? '1 Hour' : orderExpiry === '1d' ? '1 Day' : orderExpiry === '1w' ? '1 Week' : '1 Month'}</span>
                        </div>
                      </div>
                    )}
                    
                    <Button
                      onClick={handleTrade}
                      disabled={!fromAmount || !limitPrice || parseFloat(fromAmount) <= 0 || parseFloat(limitPrice) <= 0 || isPlacingOrder || isApproving}
                      className="w-full"
                      size="lg"
                    >
                      {isApproving ? (
                        <>
                          <RefreshCwIcon className="h-4 w-4 mr-2 animate-spin" />
                          Approving...
                        </>
                      ) : isPlacingOrder ? (
                        <>
                          <RefreshCwIcon className="h-4 w-4 mr-2 animate-spin" />
                          Placing Order...
                        </>
                      ) : (
                        <>
                          <TargetIcon className="h-4 w-4 mr-2" />
                          Place Limit Order
                        </>
                      )}
                    </Button>
                  </div>
                </TabsContent>
              </Tabs>
            </CardContent>
          </Card>
        </div>
        
        {/* Chart and Market Data */}
        <div className="lg:col-span-2 space-y-6">
          {/* Price Chart */}
          <Card>
            <CardHeader>
              <div className="flex items-center justify-between">
                <div>
                  <CardTitle className="flex items-center">
                    {selectedPair.tokenA.icon} {selectedPair.tokenA.symbol}/{selectedPair.tokenB.symbol}
                    <Badge variant={selectedPair.change24h >= 0 ? "default" : "destructive"} className="ml-2">
                      {selectedPair.change24h >= 0 ? '+' : ''}{selectedPair.change24h.toFixed(2)}%
                    </Badge>
                  </CardTitle>
                  <div className="text-2xl font-bold">
                    ${selectedPair.price.toLocaleString()}
                  </div>
                </div>
                <div className="flex items-center space-x-2">
                  <Select value={chartTimeframe} onValueChange={setChartTimeframe}>
                    <SelectTrigger className="w-20">
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="1m">1m</SelectItem>
                      <SelectItem value="5m">5m</SelectItem>
                      <SelectItem value="15m">15m</SelectItem>
                      <SelectItem value="1h">1h</SelectItem>
                      <SelectItem value="4h">4h</SelectItem>
                      <SelectItem value="1d">1d</SelectItem>
                    </SelectContent>
                  </Select>
                  <Button
                    variant={chartType === 'line' ? 'default' : 'outline'}
                    size="sm"
                    onClick={() => setChartType('line')}
                  >
                    <LineChartIcon className="h-4 w-4" />
                  </Button>
                  <Button
                    variant={chartType === 'candle' ? 'default' : 'outline'}
                    size="sm"
                    onClick={() => setChartType('candle')}
                  >
                    <CandlestickChartIcon className="h-4 w-4" />
                  </Button>
                </div>
              </div>
            </CardHeader>
            <CardContent>
              <div className="h-64 bg-muted rounded-lg flex items-center justify-center">
                <div className="text-center">
                  <BarChart3Icon className="h-12 w-12 mx-auto mb-2 text-muted-foreground" />
                  <p className="text-muted-foreground">Price Chart</p>
                  <p className="text-sm text-muted-foreground">Chart integration coming soon</p>
                </div>
              </div>
            </CardContent>
          </Card>
          
          {/* Trading Pairs */}
          <Card>
            <CardHeader>
              <CardTitle>Trading Pairs</CardTitle>
              <CardDescription>
                Available trading pairs with real-time data
              </CardDescription>
            </CardHeader>
            <CardContent>
              <div className="space-y-4">
                {TRADING_PAIRS.map((pair, index) => (
                  <div
                    key={index}
                    className={cn(
                      "flex items-center justify-between p-4 rounded-lg border cursor-pointer transition-colors",
                      selectedPair === pair ? "bg-primary/10 border-primary" : "hover:bg-muted"
                    )}
                    onClick={() => setSelectedPair(pair)}
                  >
                    <div className="flex items-center space-x-3">
                      <div className="flex items-center">
                        <span className="text-lg">{pair.tokenA.icon}</span>
                        <span className="text-lg ml-1">{pair.tokenB.icon}</span>
                      </div>
                      <div>
                        <div className="font-medium">
                          {pair.tokenA.symbol}/{pair.tokenB.symbol}
                        </div>
                        <div className="text-sm text-muted-foreground">
                          ${formatNumber(pair.price)}
                        </div>
                      </div>
                    </div>
                    
                    <div className="text-right">
                      <div className={cn(
                        "font-medium",
                        pair.change24h >= 0 ? "text-green-600" : "text-red-600"
                      )}>
                        {pair.change24h >= 0 ? '+' : ''}{pair.change24h.toFixed(2)}%
                      </div>
                      <div className="text-sm text-muted-foreground">
                        Vol: ${formatNumber(pair.volume24h)}
                      </div>
                    </div>
                    
                    <div className="text-right">
                      <div className="font-medium">
                        {pair.apy.toFixed(1)}% APY
                      </div>
                      <div className="text-sm text-muted-foreground">
                        Liquidity: ${formatNumber(pair.liquidity)}
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            </CardContent>
          </Card>
        </div>
      </div>
      
      {/* Orders and History */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
        {/* Open Orders */}
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center">
              <ClockIcon className="h-5 w-5 mr-2" />
              Open Orders
            </CardTitle>
            <CardDescription>
              Your active limit orders
            </CardDescription>
          </CardHeader>
          <CardContent>
            {userOrders.length === 0 ? (
              <div className="text-center py-8">
                <TimerIcon className="h-12 w-12 mx-auto mb-4 text-muted-foreground" />
                <p className="text-muted-foreground">No open orders</p>
                <p className="text-sm text-muted-foreground">Place a limit order to see it here</p>
              </div>
            ) : (
              <div className="space-y-4">
                {userOrders.map((order) => (
                  <div key={order.id} className="flex items-center justify-between p-4 border rounded-lg">
                    <div>
                      <div className="font-medium">
                        {order.type === 'buy' ? 'Buy' : 'Sell'} {order.tokenA.symbol}
                      </div>
                      <div className="text-sm text-muted-foreground">
                        {order.amount} at ${order.limitPrice}
                      </div>
                    </div>
                    <div className="text-right">
                      <Badge variant={order.status === 'pending' ? 'default' : order.status === 'filled' ? 'default' : 'destructive'}>
                        {order.status}
                      </Badge>
                      <div className="text-sm text-muted-foreground mt-1">
                        {order.filled}/{order.amount}
                      </div>
                    </div>
                    <Button variant="outline" size="sm">
                      Cancel
                    </Button>
                  </div>
                ))}
              </div>
            )}
          </CardContent>
        </Card>
        
        {/* Trade History */}
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center">
              <ActivityIcon className="h-5 w-5 mr-2" />
              Trade History
            </CardTitle>
            <CardDescription>
              Your recent trading activity
            </CardDescription>
          </CardHeader>
          <CardContent>
            {tradeHistory.length === 0 ? (
              <div className="text-center py-8">
                <ActivityIcon className="h-12 w-12 mx-auto mb-4 text-muted-foreground" />
                <p className="text-muted-foreground">No trade history</p>
                <p className="text-sm text-muted-foreground">Your completed trades will appear here</p>
              </div>
            ) : (
              <div className="space-y-4">
                {tradeHistory.map((trade) => (
                  <div key={trade.id} className="flex items-center justify-between p-4 border rounded-lg">
                    <div>
                      <div className="font-medium">
                        {trade.type === 'buy' ? 'Bought' : 'Sold'} {trade.pair}
                      </div>
                      <div className="text-sm text-muted-foreground">
                        {trade.amount} at ${trade.price}
                      </div>
                    </div>
                    <div className="text-right">
                      <div className="font-medium">
                        ${trade.total}
                      </div>
                      <div className="text-sm text-muted-foreground">
                        Fee: ${trade.fee}
                      </div>
                    </div>
                    <div className="text-sm text-muted-foreground">
                      {trade.timestamp.toLocaleDateString()}
                    </div>
                  </div>
                ))}
              </div>
            )}
          </CardContent>
        </Card>
      </div>
    </div>
  );
}