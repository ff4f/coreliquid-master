"use client";

import { useState, useEffect } from "react";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { useToast } from "@/hooks/use-toast";
import { ethers } from "ethers";
import { 
  BarChart3, 
  TrendingUp, 
  DollarSign, 
  Users, 
  Activity, 
  PieChart, 
  LineChart,
  Download,
  Calendar,
  Filter
} from "lucide-react";

interface AnalyticsData {
  totalValueLocked: number;
  totalVolume24h: number;
  totalUsers: number;
  totalTransactions: number;
  averageAPY: number;
  totalYieldGenerated: number;
  activeStrategies: number;
  totalLiquidations: number;
}

interface ChartData {
  date: string;
  tvl: number;
  volume: number;
  users: number;
  transactions: number;
  apy: number;
}

interface StrategyPerformance {
  name: string;
  tvl: number;
  apy: number;
  volume24h: number;
  users: number;
  risk: 'Low' | 'Medium' | 'High';
  status: 'Active' | 'Paused' | 'Deprecated';
}

interface ContractUsage {
  name: string;
  transactions: number;
  gasUsed: number;
  uniqueUsers: number;
  errorRate: number;
  avgResponseTime: number;
}

export default function AnalyticsPage() {
  const [provider, setProvider] = useState<ethers.BrowserProvider | null>(null);
  const [isConnected, setIsConnected] = useState(false);
  const [activeTab, setActiveTab] = useState("overview");
  const [timeRange, setTimeRange] = useState("7d");
  const [loading, setLoading] = useState(false);
  const { toast } = useToast();

  const [analyticsData, setAnalyticsData] = useState<AnalyticsData>({
    totalValueLocked: 12500000,
    totalVolume24h: 2800000,
    totalUsers: 15420,
    totalTransactions: 89650,
    averageAPY: 12.5,
    totalYieldGenerated: 1850000,
    activeStrategies: 24,
    totalLiquidations: 12
  });

  const [chartData, setChartData] = useState<ChartData[]>([
    { date: "2024-01-08", tvl: 10200000, volume: 1800000, users: 12500, transactions: 65000, apy: 11.2 },
    { date: "2024-01-09", tvl: 10800000, volume: 2100000, users: 13200, transactions: 72000, apy: 11.8 },
    { date: "2024-01-10", tvl: 11200000, volume: 2300000, users: 13800, transactions: 76000, apy: 12.1 },
    { date: "2024-01-11", tvl: 11600000, volume: 2500000, users: 14200, transactions: 81000, apy: 12.3 },
    { date: "2024-01-12", tvl: 12000000, volume: 2600000, users: 14800, transactions: 84000, apy: 12.4 },
    { date: "2024-01-13", tvl: 12300000, volume: 2700000, users: 15100, transactions: 87000, apy: 12.6 },
    { date: "2024-01-14", tvl: 12500000, volume: 2800000, users: 15420, transactions: 89650, apy: 12.5 }
  ]);

  const [strategyPerformance, setStrategyPerformance] = useState<StrategyPerformance[]>([
    {
      name: "ETH-USDC LP Strategy",
      tvl: 3200000,
      apy: 15.2,
      volume24h: 850000,
      users: 2840,
      risk: "Medium",
      status: "Active"
    },
    {
      name: "BTC-ETH LP Strategy",
      tvl: 2800000,
      apy: 13.8,
      volume24h: 720000,
      users: 2150,
      risk: "Medium",
      status: "Active"
    },
    {
      name: "Stable Coin Yield",
      tvl: 2100000,
      apy: 8.5,
      volume24h: 450000,
      users: 3200,
      risk: "Low",
      status: "Active"
    },
    {
      name: "High Yield DeFi",
      tvl: 1800000,
      apy: 22.3,
      volume24h: 380000,
      users: 890,
      risk: "High",
      status: "Active"
    },
    {
      name: "Conservative Bond",
      tvl: 1600000,
      apy: 6.2,
      volume24h: 280000,
      users: 4200,
      risk: "Low",
      status: "Active"
    },
    {
      name: "Arbitrage Strategy",
      tvl: 900000,
      apy: 18.7,
      volume24h: 320000,
      users: 650,
      risk: "High",
      status: "Paused"
    }
  ]);

  const [contractUsage, setContractUsage] = useState<ContractUsage[]>([
    {
      name: "DepositManager",
      transactions: 25680,
      gasUsed: 3200000000,
      uniqueUsers: 8900,
      errorRate: 0.2,
      avgResponseTime: 180
    },
    {
      name: "YieldAggregator",
      transactions: 18450,
      gasUsed: 4100000000,
      uniqueUsers: 6200,
      errorRate: 1.8,
      avgResponseTime: 320
    },
    {
      name: "AutoRebalanceManager",
      transactions: 12300,
      gasUsed: 2800000000,
      uniqueUsers: 4500,
      errorRate: 0.5,
      avgResponseTime: 250
    },
    {
      name: "BorrowEngine",
      transactions: 9800,
      gasUsed: 2200000000,
      uniqueUsers: 3200,
      errorRate: 0.8,
      avgResponseTime: 290
    },
    {
      name: "LiquidationEngine",
      transactions: 450,
      gasUsed: 180000000,
      uniqueUsers: 120,
      errorRate: 2.1,
      avgResponseTime: 400
    }
  ]);

  useEffect(() => {
    connectWallet();
  }, []);

  const connectWallet = async () => {
    try {
      if (typeof window !== "undefined" && window.ethereum) {
        const provider = new ethers.BrowserProvider(window.ethereum);
        await provider.send("eth_requestAccounts", []);
        setProvider(provider);
        setIsConnected(true);
      }
    } catch (error) {
      console.error("Failed to connect wallet:", error);
    }
  };

  const exportData = () => {
    const data = {
      analytics: analyticsData,
      chartData: chartData,
      strategies: strategyPerformance,
      contracts: contractUsage,
      exportedAt: new Date().toISOString()
    };
    
    const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `coreliquid-analytics-${new Date().toISOString().split('T')[0]}.json`;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
    
    toast({
      title: "Data Exported",
      description: "Analytics data has been exported successfully",
    });
  };

  const formatCurrency = (value: number) => {
    if (value >= 1000000) {
      return `$${(value / 1000000).toFixed(1)}M`;
    } else if (value >= 1000) {
      return `$${(value / 1000).toFixed(1)}K`;
    }
    return `$${value.toLocaleString()}`;
  };

  const getRiskColor = (risk: string) => {
    switch (risk) {
      case 'Low': return 'text-green-600 bg-green-100';
      case 'Medium': return 'text-yellow-600 bg-yellow-100';
      case 'High': return 'text-red-600 bg-red-100';
      default: return 'text-gray-600 bg-gray-100';
    }
  };

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'Active': return 'text-green-600 bg-green-100';
      case 'Paused': return 'text-yellow-600 bg-yellow-100';
      case 'Deprecated': return 'text-red-600 bg-red-100';
      default: return 'text-gray-600 bg-gray-100';
    }
  };

  return (
    <div className="container mx-auto p-6 space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold">Protocol Analytics</h1>
          <p className="text-muted-foreground">Comprehensive analytics and insights for CoreLiquid Protocol</p>
        </div>
        <div className="flex items-center gap-2">
          <Select value={timeRange} onValueChange={setTimeRange}>
            <SelectTrigger className="w-[120px]">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="24h">24 Hours</SelectItem>
              <SelectItem value="7d">7 Days</SelectItem>
              <SelectItem value="30d">30 Days</SelectItem>
              <SelectItem value="90d">90 Days</SelectItem>
              <SelectItem value="1y">1 Year</SelectItem>
            </SelectContent>
          </Select>
          <Button onClick={exportData} variant="outline">
            <Download className="w-4 h-4 mr-2" />
            Export
          </Button>
          <Badge variant={isConnected ? "default" : "destructive"}>
            {isConnected ? "Connected" : "Disconnected"}
          </Badge>
        </div>
      </div>

      <Tabs value={activeTab} onValueChange={setActiveTab} className="w-full">
        <TabsList className="grid w-full grid-cols-5">
          <TabsTrigger value="overview">Overview</TabsTrigger>
          <TabsTrigger value="strategies">Strategies</TabsTrigger>
          <TabsTrigger value="contracts">Contracts</TabsTrigger>
          <TabsTrigger value="users">Users</TabsTrigger>
          <TabsTrigger value="performance">Performance</TabsTrigger>
        </TabsList>

        <TabsContent value="overview" className="space-y-6">
          {/* Key Metrics */}
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
            <Card>
              <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                <CardTitle className="text-sm font-medium">Total Value Locked</CardTitle>
                <DollarSign className="h-4 w-4 text-muted-foreground" />
              </CardHeader>
              <CardContent>
                <div className="text-2xl font-bold">{formatCurrency(analyticsData.totalValueLocked)}</div>
                <p className="text-xs text-muted-foreground flex items-center">
                  <TrendingUp className="w-3 h-3 mr-1 text-green-500" />
                  +12.5% from last month
                </p>
              </CardContent>
            </Card>
            
            <Card>
              <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                <CardTitle className="text-sm font-medium">24h Volume</CardTitle>
                <BarChart3 className="h-4 w-4 text-muted-foreground" />
              </CardHeader>
              <CardContent>
                <div className="text-2xl font-bold">{formatCurrency(analyticsData.totalVolume24h)}</div>
                <p className="text-xs text-muted-foreground flex items-center">
                  <TrendingUp className="w-3 h-3 mr-1 text-green-500" />
                  +8.2% from yesterday
                </p>
              </CardContent>
            </Card>
            
            <Card>
              <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                <CardTitle className="text-sm font-medium">Total Users</CardTitle>
                <Users className="h-4 w-4 text-muted-foreground" />
              </CardHeader>
              <CardContent>
                <div className="text-2xl font-bold">{analyticsData.totalUsers.toLocaleString()}</div>
                <p className="text-xs text-muted-foreground flex items-center">
                  <TrendingUp className="w-3 h-3 mr-1 text-green-500" />
                  +320 new users this week
                </p>
              </CardContent>
            </Card>
            
            <Card>
              <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                <CardTitle className="text-sm font-medium">Average APY</CardTitle>
                <Activity className="h-4 w-4 text-muted-foreground" />
              </CardHeader>
              <CardContent>
                <div className="text-2xl font-bold">{analyticsData.averageAPY}%</div>
                <p className="text-xs text-muted-foreground flex items-center">
                  <TrendingUp className="w-3 h-3 mr-1 text-green-500" />
                  +0.8% from last week
                </p>
              </CardContent>
            </Card>
          </div>

          {/* Charts */}
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            <Card>
              <CardHeader>
                <CardTitle>TVL Growth</CardTitle>
                <CardDescription>Total Value Locked over time</CardDescription>
              </CardHeader>
              <CardContent>
                <div className="h-[300px] flex items-center justify-center border-2 border-dashed border-gray-300 rounded-lg">
                  <div className="text-center">
                    <LineChart className="w-12 h-12 mx-auto text-gray-400 mb-2" />
                    <p className="text-sm text-gray-500">TVL Chart Placeholder</p>
                    <p className="text-xs text-gray-400">Chart component would be integrated here</p>
                  </div>
                </div>
              </CardContent>
            </Card>
            
            <Card>
              <CardHeader>
                <CardTitle>Volume Distribution</CardTitle>
                <CardDescription>Trading volume by strategy</CardDescription>
              </CardHeader>
              <CardContent>
                <div className="h-[300px] flex items-center justify-center border-2 border-dashed border-gray-300 rounded-lg">
                  <div className="text-center">
                    <PieChart className="w-12 h-12 mx-auto text-gray-400 mb-2" />
                    <p className="text-sm text-gray-500">Volume Distribution Chart</p>
                    <p className="text-xs text-gray-400">Pie chart component would be integrated here</p>
                  </div>
                </div>
              </CardContent>
            </Card>
          </div>

          {/* Additional Metrics */}
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <Card>
              <CardHeader>
                <CardTitle className="text-lg">Yield Generated</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="text-3xl font-bold text-green-600">
                  {formatCurrency(analyticsData.totalYieldGenerated)}
                </div>
                <p className="text-sm text-muted-foreground mt-2">
                  Total yield generated for users
                </p>
              </CardContent>
            </Card>
            
            <Card>
              <CardHeader>
                <CardTitle className="text-lg">Active Strategies</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="text-3xl font-bold text-blue-600">
                  {analyticsData.activeStrategies}
                </div>
                <p className="text-sm text-muted-foreground mt-2">
                  Currently running strategies
                </p>
              </CardContent>
            </Card>
            
            <Card>
              <CardHeader>
                <CardTitle className="text-lg">Total Transactions</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="text-3xl font-bold text-purple-600">
                  {analyticsData.totalTransactions.toLocaleString()}
                </div>
                <p className="text-sm text-muted-foreground mt-2">
                  All-time transaction count
                </p>
              </CardContent>
            </Card>
          </div>
        </TabsContent>

        <TabsContent value="strategies" className="space-y-4">
          <Card>
            <CardHeader>
              <CardTitle>Strategy Performance</CardTitle>
              <CardDescription>Performance metrics for all active strategies</CardDescription>
            </CardHeader>
            <CardContent>
              <div className="overflow-x-auto">
                <table className="w-full">
                  <thead>
                    <tr className="border-b">
                      <th className="text-left p-2">Strategy</th>
                      <th className="text-left p-2">TVL</th>
                      <th className="text-left p-2">APY</th>
                      <th className="text-left p-2">24h Volume</th>
                      <th className="text-left p-2">Users</th>
                      <th className="text-left p-2">Risk</th>
                      <th className="text-left p-2">Status</th>
                    </tr>
                  </thead>
                  <tbody>
                    {strategyPerformance.map((strategy, index) => (
                      <tr key={index} className="border-b hover:bg-gray-50">
                        <td className="p-2 font-medium">{strategy.name}</td>
                        <td className="p-2">{formatCurrency(strategy.tvl)}</td>
                        <td className="p-2 font-bold text-green-600">{strategy.apy}%</td>
                        <td className="p-2">{formatCurrency(strategy.volume24h)}</td>
                        <td className="p-2">{strategy.users.toLocaleString()}</td>
                        <td className="p-2">
                          <Badge className={getRiskColor(strategy.risk)}>
                            {strategy.risk}
                          </Badge>
                        </td>
                        <td className="p-2">
                          <Badge className={getStatusColor(strategy.status)}>
                            {strategy.status}
                          </Badge>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </CardContent>
          </Card>
        </TabsContent>

        <TabsContent value="contracts" className="space-y-4">
          <Card>
            <CardHeader>
              <CardTitle>Contract Usage Analytics</CardTitle>
              <CardDescription>Usage statistics for all smart contracts</CardDescription>
            </CardHeader>
            <CardContent>
              <div className="overflow-x-auto">
                <table className="w-full">
                  <thead>
                    <tr className="border-b">
                      <th className="text-left p-2">Contract</th>
                      <th className="text-left p-2">Transactions</th>
                      <th className="text-left p-2">Gas Used</th>
                      <th className="text-left p-2">Unique Users</th>
                      <th className="text-left p-2">Error Rate</th>
                      <th className="text-left p-2">Avg Response</th>
                    </tr>
                  </thead>
                  <tbody>
                    {contractUsage.map((contract, index) => (
                      <tr key={index} className="border-b hover:bg-gray-50">
                        <td className="p-2 font-medium">{contract.name}</td>
                        <td className="p-2">{contract.transactions.toLocaleString()}</td>
                        <td className="p-2">{(contract.gasUsed / 1000000).toFixed(1)}M</td>
                        <td className="p-2">{contract.uniqueUsers.toLocaleString()}</td>
                        <td className="p-2">
                          <span className={`font-medium ${
                            contract.errorRate < 1 ? 'text-green-600' :
                            contract.errorRate < 3 ? 'text-yellow-600' : 'text-red-600'
                          }`}>
                            {contract.errorRate}%
                          </span>
                        </td>
                        <td className="p-2">{contract.avgResponseTime}ms</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </CardContent>
          </Card>
        </TabsContent>

        <TabsContent value="users" className="space-y-4">
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            <Card>
              <CardHeader>
                <CardTitle>User Growth</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="text-3xl font-bold">{analyticsData.totalUsers.toLocaleString()}</div>
                <p className="text-sm text-muted-foreground">Total registered users</p>
                <div className="mt-4">
                  <p className="text-sm">New users (7d): <span className="font-bold text-green-600">+320</span></p>
                  <p className="text-sm">Active users (24h): <span className="font-bold">8,450</span></p>
                  <p className="text-sm">Retention rate: <span className="font-bold">78%</span></p>
                </div>
              </CardContent>
            </Card>
            
            <Card>
              <CardHeader>
                <CardTitle>User Distribution</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="space-y-3">
                  <div className="flex justify-between">
                    <span className="text-sm">Retail Users</span>
                    <span className="font-bold">12,850 (83%)</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-sm">Institutional</span>
                    <span className="font-bold">1,890 (12%)</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-sm">Whales (&gt;$1M)</span>
                    <span className="font-bold">680 (5%)</span>
                  </div>
                </div>
              </CardContent>
            </Card>
            
            <Card>
              <CardHeader>
                <CardTitle>Geographic Distribution</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="space-y-3">
                  <div className="flex justify-between">
                    <span className="text-sm">North America</span>
                    <span className="font-bold">35%</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-sm">Europe</span>
                    <span className="font-bold">28%</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-sm">Asia</span>
                    <span className="font-bold">25%</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-sm">Others</span>
                    <span className="font-bold">12%</span>
                  </div>
                </div>
              </CardContent>
            </Card>
          </div>
        </TabsContent>

        <TabsContent value="performance" className="space-y-4">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <Card>
              <CardHeader>
                <CardTitle>Network Performance</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="space-y-4">
                  <div className="flex justify-between items-center">
                    <span>Average Block Time</span>
                    <span className="font-bold">3.2s</span>
                  </div>
                  <div className="flex justify-between items-center">
                    <span>Network Congestion</span>
                    <Badge className="bg-yellow-100 text-yellow-800">Medium</Badge>
                  </div>
                  <div className="flex justify-between items-center">
                    <span>Gas Price (avg)</span>
                    <span className="font-bold">25 gwei</span>
                  </div>
                  <div className="flex justify-between items-center">
                    <span>Success Rate</span>
                    <span className="font-bold text-green-600">98.7%</span>
                  </div>
                </div>
              </CardContent>
            </Card>
            
            <Card>
              <CardHeader>
                <CardTitle>Protocol Health</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="space-y-4">
                  <div className="flex justify-between items-center">
                    <span>System Uptime</span>
                    <span className="font-bold text-green-600">99.9%</span>
                  </div>
                  <div className="flex justify-between items-center">
                    <span>Active Liquidations</span>
                    <span className="font-bold">{analyticsData.totalLiquidations}</span>
                  </div>
                  <div className="flex justify-between items-center">
                    <span>Risk Level</span>
                    <Badge className="bg-green-100 text-green-800">Low</Badge>
                  </div>
                  <div className="flex justify-between items-center">
                    <span>Emergency Stops</span>
                    <span className="font-bold">0</span>
                  </div>
                </div>
              </CardContent>
            </Card>
          </div>
        </TabsContent>
      </Tabs>
    </div>
  );
}