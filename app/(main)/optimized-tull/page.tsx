"use client";

import React, { useState, useEffect } from 'react';
import { useAccount } from 'wagmi';
import { BrowserProvider, JsonRpcSigner } from 'ethers';
import { CoreFluidXContracts } from '@/lib/contracts';
import { CONTRACT_ADDRESSES } from '@/lib/wagmi';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Badge } from "@/components/ui/badge";
import { Progress } from "@/components/ui/progress";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Alert, AlertDescription } from "@/components/ui/alert";
import { Separator } from "@/components/ui/separator";
import { 
  ArrowUpRight, 
  ArrowDownLeft, 
  Zap, 
  Target, 
  BarChart3, 
  RefreshCw, 
  Copy, 
  CheckCircle,
  AlertTriangle,
  TrendingUp,
  Layers,
  Activity
} from "lucide-react";

interface AssetState {
  totalDeposited: string;
  totalUtilized: string;
  idleThreshold: string;
  lastRebalanceTimestamp: string;
}

interface ProtocolInfo {
  isActive: boolean;
  yieldRate: number;
  maxCapacity: string;
  currentAllocation: string;
}

export default function OptimizedTULLPage() {
  const { address, isConnected } = useAccount();
  const [contracts, setContracts] = useState<CoreFluidXContracts | null>(null);
  const [loading, setLoading] = useState(false);
  const [txHash, setTxHash] = useState<string>('');
  const [error, setError] = useState<string>('');
  
  // Form states
  const [selectedAsset, setSelectedAsset] = useState<string>('');
  const [amount, setAmount] = useState<string>('');
  const [selectedProtocol, setSelectedProtocol] = useState<string>('');
  
  // Data states
  const [supportedAssets, setSupportedAssets] = useState<string[]>([]);
  const [registeredProtocols, setRegisteredProtocols] = useState<string[]>([]);
  const [userBalance, setUserBalance] = useState<string>('0');
  const [totalLiquidity, setTotalLiquidity] = useState<string>('0');
  const [availableLiquidity, setAvailableLiquidity] = useState<string>('0');
  const [assetState, setAssetState] = useState<AssetState | null>(null);
  const [protocolInfos, setProtocolInfos] = useState<{[key: string]: ProtocolInfo}>({});
  
  // Initialize contracts
  useEffect(() => {
    const initContracts = async () => {
      if (typeof window !== 'undefined' && window.ethereum && isConnected) {
        try {
          const provider = new BrowserProvider(window.ethereum);
          const signer = await provider.getSigner();
          const contractsInstance = new CoreFluidXContracts(provider, signer);
          setContracts(contractsInstance);
        } catch (err) {
          console.error('Failed to initialize contracts:', err);
          setError('Failed to initialize contracts');
        }
      }
    };
    
    initContracts();
  }, [isConnected]);
  
  // Load data
  useEffect(() => {
    if (contracts && selectedAsset) {
      loadData();
    }
  }, [contracts, selectedAsset, address]);
  
  const loadData = async () => {
    if (!contracts || !selectedAsset) return;
    
    try {
      setLoading(true);
      
      // Load supported assets and protocols
      const assets = await contracts.getOptimizedTULLSupportedAssets();
      const protocols = await contracts.getOptimizedTULLRegisteredProtocols();
      setSupportedAssets(assets);
      setRegisteredProtocols(protocols);
      
      if (address) {
        // Load user balance
        const balance = await contracts.getOptimizedTULLUserBalance(address, selectedAsset);
        setUserBalance(balance);
      }
      
      // Load asset data
      const total = await contracts.getOptimizedTULLTotalLiquidity(selectedAsset);
      const available = await contracts.getOptimizedTULLAvailableLiquidity(selectedAsset);
      const state = await contracts.getOptimizedTULLAssetState(selectedAsset);
      
      setTotalLiquidity(total);
      setAvailableLiquidity(available);
      setAssetState({
        totalDeposited: state[0].toString(),
        totalUtilized: state[1].toString(),
        idleThreshold: state[2].toString(),
        lastRebalanceTimestamp: state[3].toString()
      });
      
      // Load protocol infos
      const protocolData: {[key: string]: ProtocolInfo} = {};
      for (const protocol of protocols) {
        const info = await contracts.getOptimizedTULLProtocolInfo(protocol);
        const allocation = await contracts.getOptimizedTULLProtocolAllocation(protocol, selectedAsset);
        protocolData[protocol] = {
          isActive: info[0],
          yieldRate: info[1],
          maxCapacity: info[2].toString(),
          currentAllocation: allocation
        };
      }
      setProtocolInfos(protocolData);
      
    } catch (err) {
      console.error('Failed to load data:', err);
      setError('Failed to load data');
    } finally {
      setLoading(false);
    }
  };
  
  const handleDeposit = async () => {
    if (!contracts || !selectedAsset || !amount || !address) return;
    
    try {
      setLoading(true);
      setError('');
      
      const tx = await contracts.depositToOptimizedTULL(selectedAsset, amount, address);
      setTxHash(tx.hash);
      
      await tx.wait();
      await loadData();
      setAmount('');
      
    } catch (err: any) {
      console.error('Deposit failed:', err);
      setError(err.message || 'Deposit failed');
    } finally {
      setLoading(false);
    }
  };
  
  const handleWithdraw = async () => {
    if (!contracts || !selectedAsset || !amount || !address) return;
    
    try {
      setLoading(true);
      setError('');
      
      const tx = await contracts.withdrawFromOptimizedTULL(selectedAsset, amount, address);
      setTxHash(tx.hash);
      
      await tx.wait();
      await loadData();
      setAmount('');
      
    } catch (err: any) {
      console.error('Withdraw failed:', err);
      setError(err.message || 'Withdraw failed');
    } finally {
      setLoading(false);
    }
  };
  
  const handleReallocate = async () => {
    if (!contracts || !selectedAsset) return;
    
    try {
      setLoading(true);
      setError('');
      
      const tx = await contracts.detectAndReallocate(selectedAsset);
      setTxHash(tx.hash);
      
      await tx.wait();
      await loadData();
      
    } catch (err: any) {
      console.error('Reallocation failed:', err);
      setError(err.message || 'Reallocation failed');
    } finally {
      setLoading(false);
    }
  };
  
  const copyToClipboard = (text: string) => {
    navigator.clipboard.writeText(text);
  };
  
  const formatAddress = (addr: string | undefined) => {
    if (!addr || typeof addr !== 'string') return 'N/A';
    return `${addr.slice(0, 6)}...${addr.slice(-4)}`;
  };
  
  const calculateUtilizationRate = () => {
    if (!assetState) return 0;
    const total = parseFloat(assetState.totalDeposited);
    const utilized = parseFloat(assetState.totalUtilized);
    return total > 0 ? (utilized / total) * 100 : 0;
  };
  
  if (!isConnected) {
    return (
      <div className="container mx-auto p-6">
        <Card>
          <CardContent className="flex items-center justify-center h-64">
            <div className="text-center">
              <h3 className="text-lg font-semibold mb-2">Wallet Not Connected</h3>
              <p className="text-muted-foreground">Please connect your wallet to access OptimizedTULL</p>
            </div>
          </CardContent>
        </Card>
      </div>
    );
  }
  
  return (
    <div className="container mx-auto p-6 space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold">OptimizedTULL</h1>
          <p className="text-muted-foreground">True Unified Liquidity Layer with Cross-Protocol Asset Sharing</p>
        </div>
        <Badge variant="outline" className="text-green-600 border-green-600">
          <Activity className="w-4 h-4 mr-1" />
          Auto-Reallocation Active
        </Badge>
      </div>
      
      {/* Contract Info */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Layers className="w-5 h-5" />
            Contract Information
          </CardTitle>
        </CardHeader>
        <CardContent>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div className="flex items-center justify-between p-3 bg-muted rounded-lg">
              <span className="text-sm font-medium">OptimizedTULL</span>
              <div className="flex items-center gap-2">
                <span className="text-xs font-mono">{formatAddress(CONTRACT_ADDRESSES.OPTIMIZED_TULL)}</span>
                <Button
                  variant="ghost"
                  size="sm"
                  onClick={() => copyToClipboard(CONTRACT_ADDRESSES.OPTIMIZED_TULL)}
                >
                  <Copy className="w-3 h-3" />
                </Button>
              </div>
            </div>
            <div className="flex items-center justify-between p-3 bg-muted rounded-lg">
              <span className="text-sm font-medium">CORE Liquid Token</span>
              <div className="flex items-center gap-2">
                <span className="text-xs font-mono">{formatAddress(CONTRACT_ADDRESSES.CORE_LIQUID_TOKEN)}</span>
                <Button
                  variant="ghost"
                  size="sm"
                  onClick={() => copyToClipboard(CONTRACT_ADDRESSES.CORE_LIQUID_TOKEN)}
                >
                  <Copy className="w-3 h-3" />
                </Button>
              </div>
            </div>
            <div className="flex items-center justify-between p-3 bg-muted rounded-lg">
              <span className="text-sm font-medium">BTC Token</span>
              <div className="flex items-center gap-2">
                <span className="text-xs font-mono">{formatAddress(CONTRACT_ADDRESSES.BTC_TOKEN)}</span>
                <Button
                  variant="ghost"
                  size="sm"
                  onClick={() => copyToClipboard(CONTRACT_ADDRESSES.BTC_TOKEN)}
                >
                  <Copy className="w-3 h-3" />
                </Button>
              </div>
            </div>
          </div>
        </CardContent>
      </Card>
      
      {/* Asset Selection */}
      <Card>
        <CardHeader>
          <CardTitle>Select Asset</CardTitle>
          <CardDescription>Choose an asset to interact with OptimizedTULL</CardDescription>
        </CardHeader>
        <CardContent>
          <Select value={selectedAsset} onValueChange={setSelectedAsset}>
            <SelectTrigger>
              <SelectValue placeholder="Select an asset" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value={CONTRACT_ADDRESSES.CORE_LIQUID_TOKEN}>CORE Liquid Token</SelectItem>
              <SelectItem value={CONTRACT_ADDRESSES.BTC_TOKEN}>BTC Token</SelectItem>
            </SelectContent>
          </Select>
        </CardContent>
      </Card>
      
      {selectedAsset && (
        <>
          {/* Asset Overview */}
          <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
            <Card>
              <CardHeader className="pb-2">
                <CardTitle className="text-sm font-medium">Your Balance</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="text-2xl font-bold">{parseFloat(userBalance).toFixed(4)}</div>
                <p className="text-xs text-muted-foreground">Tokens</p>
              </CardContent>
            </Card>
            
            <Card>
              <CardHeader className="pb-2">
                <CardTitle className="text-sm font-medium">Total Liquidity</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="text-2xl font-bold">{parseFloat(totalLiquidity).toFixed(4)}</div>
                <p className="text-xs text-muted-foreground">Tokens</p>
              </CardContent>
            </Card>
            
            <Card>
              <CardHeader className="pb-2">
                <CardTitle className="text-sm font-medium">Available Liquidity</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="text-2xl font-bold">{parseFloat(availableLiquidity).toFixed(4)}</div>
                <p className="text-xs text-muted-foreground">Tokens</p>
              </CardContent>
            </Card>
            
            <Card>
              <CardHeader className="pb-2">
                <CardTitle className="text-sm font-medium">Utilization Rate</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="text-2xl font-bold">{calculateUtilizationRate().toFixed(2)}%</div>
                <Progress value={calculateUtilizationRate()} className="mt-2" />
              </CardContent>
            </Card>
          </div>
          
          {/* Main Interface */}
          <Tabs defaultValue="deposit" className="space-y-4">
            <TabsList className="grid w-full grid-cols-3">
              <TabsTrigger value="deposit">Deposit</TabsTrigger>
              <TabsTrigger value="withdraw">Withdraw</TabsTrigger>
              <TabsTrigger value="manage">Manage</TabsTrigger>
            </TabsList>
            
            <TabsContent value="deposit">
              <Card>
                <CardHeader>
                  <CardTitle className="flex items-center gap-2">
                    <ArrowUpRight className="w-5 h-5" />
                    Deposit Assets
                  </CardTitle>
                  <CardDescription>
                    Deposit assets to OptimizedTULL for automatic yield optimization
                  </CardDescription>
                </CardHeader>
                <CardContent className="space-y-4">
                  <div className="space-y-2">
                    <label className="text-sm font-medium">Amount</label>
                    <Input
                      type="number"
                      placeholder="Enter amount"
                      value={amount}
                      onChange={(e) => setAmount(e.target.value)}
                    />
                  </div>
                  
                  <Button 
                    onClick={handleDeposit} 
                    disabled={loading || !amount}
                    className="w-full"
                  >
                    {loading ? (
                      <RefreshCw className="w-4 h-4 mr-2 animate-spin" />
                    ) : (
                      <ArrowUpRight className="w-4 h-4 mr-2" />
                    )}
                    Deposit
                  </Button>
                </CardContent>
              </Card>
            </TabsContent>
            
            <TabsContent value="withdraw">
              <Card>
                <CardHeader>
                  <CardTitle className="flex items-center gap-2">
                    <ArrowDownLeft className="w-5 h-5" />
                    Withdraw Assets
                  </CardTitle>
                  <CardDescription>
                    Withdraw your assets from OptimizedTULL
                  </CardDescription>
                </CardHeader>
                <CardContent className="space-y-4">
                  <div className="space-y-2">
                    <label className="text-sm font-medium">Amount</label>
                    <Input
                      type="number"
                      placeholder="Enter amount"
                      value={amount}
                      onChange={(e) => setAmount(e.target.value)}
                    />
                  </div>
                  
                  <Button 
                    onClick={handleWithdraw} 
                    disabled={loading || !amount}
                    className="w-full"
                    variant="outline"
                  >
                    {loading ? (
                      <RefreshCw className="w-4 h-4 mr-2 animate-spin" />
                    ) : (
                      <ArrowDownLeft className="w-4 h-4 mr-2" />
                    )}
                    Withdraw
                  </Button>
                </CardContent>
              </Card>
            </TabsContent>
            
            <TabsContent value="manage">
              <div className="space-y-4">
                {/* Auto-Reallocation */}
                <Card>
                  <CardHeader>
                    <CardTitle className="flex items-center gap-2">
                      <Zap className="w-5 h-5" />
                      Auto-Reallocation
                    </CardTitle>
                    <CardDescription>
                      Trigger automatic reallocation to highest yield protocols
                    </CardDescription>
                  </CardHeader>
                  <CardContent>
                    <Button 
                      onClick={handleReallocate} 
                      disabled={loading}
                      className="w-full"
                    >
                      {loading ? (
                        <RefreshCw className="w-4 h-4 mr-2 animate-spin" />
                      ) : (
                        <Target className="w-4 h-4 mr-2" />
                      )}
                      Trigger Reallocation
                    </Button>
                  </CardContent>
                </Card>
                
                {/* Protocol Information */}
                <Card>
                  <CardHeader>
                    <CardTitle className="flex items-center gap-2">
                      <BarChart3 className="w-5 h-5" />
                      Protocol Allocations
                    </CardTitle>
                  </CardHeader>
                  <CardContent>
                    <div className="space-y-4">
                      {registeredProtocols.map((protocol, index) => {
                        const info = protocolInfos[protocol];
                        if (!info) return null;
                        
                        return (
                          <div key={protocol} className="p-4 border rounded-lg">
                            <div className="flex items-center justify-between mb-2">
                              <div className="flex items-center gap-2">
                                <span className="font-medium">Protocol {index + 1}</span>
                                <Badge variant={info.isActive ? "default" : "secondary"}>
                                  {info.isActive ? "Active" : "Inactive"}
                                </Badge>
                              </div>
                              <div className="flex items-center gap-2">
                                <TrendingUp className="w-4 h-4 text-green-600" />
                                <span className="text-sm font-medium">{(info.yieldRate / 100).toFixed(2)}% APR</span>
                              </div>
                            </div>
                            
                            <div className="grid grid-cols-2 gap-4 text-sm">
                              <div>
                                <span className="text-muted-foreground">Current Allocation:</span>
                                <div className="font-medium">{parseFloat(info.currentAllocation).toFixed(4)} tokens</div>
                              </div>
                              <div>
                                <span className="text-muted-foreground">Max Capacity:</span>
                                <div className="font-medium">{parseFloat(info.maxCapacity).toFixed(0)} tokens</div>
                              </div>
                            </div>
                            
                            <div className="mt-2">
                              <div className="flex justify-between text-xs mb-1">
                                <span>Utilization</span>
                                <span>{((parseFloat(info.currentAllocation) / parseFloat(info.maxCapacity)) * 100).toFixed(1)}%</span>
                              </div>
                              <Progress 
                                value={(parseFloat(info.currentAllocation) / parseFloat(info.maxCapacity)) * 100} 
                                className="h-2"
                              />
                            </div>
                          </div>
                        );
                      })}
                    </div>
                  </CardContent>
                </Card>
              </div>
            </TabsContent>
          </Tabs>
          
          {/* Transaction Status */}
          {txHash && (
            <Alert>
              <CheckCircle className="h-4 w-4" />
              <AlertDescription>
                Transaction successful! Hash: 
                <button 
                  onClick={() => copyToClipboard(txHash)}
                  className="ml-1 text-blue-600 hover:underline"
                >
                  {formatAddress(txHash)}
                </button>
              </AlertDescription>
            </Alert>
          )}
          
          {/* Error Display */}
          {error && (
            <Alert variant="destructive">
              <AlertTriangle className="h-4 w-4" />
              <AlertDescription>{error}</AlertDescription>
            </Alert>
          )}
        </>
      )}
    </div>
  );
}