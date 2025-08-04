'use client';

import React, { useState, useEffect } from 'react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Input } from '@/components/ui/input';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { Progress } from '@/components/ui/progress';
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle, DialogTrigger } from '@/components/ui/dialog';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { Label } from '@/components/ui/label';
import { useCoreNative } from '@/hooks/use-core-native';
import { toast } from 'sonner';
import { formatEther } from 'viem';
import { 
  Coins, 
  TrendingUp, 
  TrendingDown, 
  Clock, 
  Lock, 
  Unlock, 
  Gift, 
  Target, 
  Award, 
  Calendar, 
  BarChart3, 
  PieChart, 
  Activity, 
  Zap, 
  Shield, 
  Star, 
  Timer, 
  Wallet, 
  ArrowUpRight, 
  ArrowDownRight, 
  Plus, 
  Minus, 
  RefreshCw, 
  Info, 
  AlertTriangle, 
  CheckCircle, 
  XCircle, 
  Eye, 
  Download, 
  Upload, 
  Settings, 
  HelpCircle, 
  ExternalLink, 
  Copy, 
  Search, 
  Filter, 
  SortAsc, 
  SortDesc, 
  Bitcoin, 
  Users, 
  Globe, 
  Database, 
  Network, 
  Cpu, 
  Server, 
  Code, 
  Package, 
  Layers, 
  Monitor
} from 'lucide-react';

export default function StakingPage() {
  const [activeTab, setActiveTab] = useState('overview');
  const [selectedPool, setSelectedPool] = useState<any>(null);
  const [stakeAmount, setStakeAmount] = useState('');
  const [unstakeAmount, setUnstakeAmount] = useState('');
  const [isStakeDialogOpen, setIsStakeDialogOpen] = useState(false);
  const [isUnstakeDialogOpen, setIsUnstakeDialogOpen] = useState(false);
  const [isClaimDialogOpen, setIsClaimDialogOpen] = useState(false);
  const [userBalance, setUserBalance] = useState(0);
  const [isLoading, setIsLoading] = useState(false);
  
  // Core-native staking states
  const [btcTxHash, setBtcTxHash] = useState('');
  const [btcAmount, setBtcAmount] = useState('');
  const [coreAmount, setCoreAmount] = useState('');
  const [lockDays, setLockDays] = useState(30);
  const [selectedValidator, setSelectedValidator] = useState('');
  const [isBTCStakeDialogOpen, setIsBTCStakeDialogOpen] = useState(false);
  
  // Core-native hooks
  const {
    isLoading: coreNativeLoading,
    stakingInfo,
    dualStakingTiers,
    protocolStats,
    stCoreAPY,
    activeValidators,
    handleBTCStake,
    handleCOREStake,
    handleCOREUnstake,
    handleClaimRewards: handleCoreClaimRewards,
    handleBTCRedeem,
    handleValidatorDelegation,
    calculateDualStakingTier,
    formatStakingValue,
    formatAPY,
  } = useCoreNative();

  // Staking data
  const [stakingData] = useState({
    overview: {
      totalStaked: 45600000,
      totalRewards: 2340000,
      averageAPY: 12.5,
      totalStakers: 8420,
      totalValueLocked: 89200000,
      protocolRevenue: 1560000,
      stakingRatio: 51.2,
      nextRewardDistribution: '2024-01-20T00:00:00Z'
    },
    userStats: {
      totalStaked: 25000,
      pendingRewards: 156.78,
      claimedRewards: 892.45,
      stakingPower: 0.055,
      averageAPY: 13.2,
      stakingSince: '2023-08-15T10:30:00Z',
      lastClaim: '2024-01-10T14:20:00Z',
      nextUnlock: '2024-02-15T10:30:00Z'
    },
    stakingPools: [
      {
        id: 'core-single',
        name: 'CORE Single Staking',
        token: 'CORE',
        apy: 12.5,
        totalStaked: 15600000,
        userStaked: 15000,
        pendingRewards: 89.45,
        lockPeriod: 0, // days
        minStake: 100,
        maxStake: 1000000,
        status: 'Active',
        description: 'Stake CORE tokens to earn protocol rewards with no lock period',
        features: ['No Lock Period', 'Daily Rewards', 'Instant Unstake'],
        riskLevel: 'Low',
        rewardToken: 'CORE',
        multiplier: 1.0,
        poolWeight: 40,
        startDate: '2023-06-01T00:00:00Z',
        endDate: null
      },
      {
        id: 'core-locked-30',
        name: 'CORE Locked 30 Days',
        token: 'CORE',
        apy: 18.5,
        totalStaked: 8900000,
        userStaked: 5000,
        pendingRewards: 34.12,
        lockPeriod: 30,
        minStake: 500,
        maxStake: 500000,
        status: 'Active',
        description: 'Lock CORE tokens for 30 days to earn higher rewards',
        features: ['30-Day Lock', 'Higher APY', 'Bonus Multiplier'],
        riskLevel: 'Low',
        rewardToken: 'CORE',
        multiplier: 1.5,
        poolWeight: 25,
        startDate: '2023-06-01T00:00:00Z',
        endDate: null
      },
      {
        id: 'core-locked-90',
        name: 'CORE Locked 90 Days',
        token: 'CORE',
        apy: 25.0,
        totalStaked: 12100000,
        userStaked: 5000,
        pendingRewards: 33.21,
        lockPeriod: 90,
        minStake: 1000,
        maxStake: 250000,
        status: 'Active',
        description: 'Lock CORE tokens for 90 days to maximize your rewards',
        features: ['90-Day Lock', 'Maximum APY', '2x Multiplier'],
        riskLevel: 'Low',
        rewardToken: 'CORE',
        multiplier: 2.0,
        poolWeight: 20,
        startDate: '2023-06-01T00:00:00Z',
        endDate: null
      },
      {
        id: 'core-lp',
        name: 'CORE-ETH LP Staking',
        token: 'CORE-ETH LP',
        apy: 35.5,
        totalStaked: 5600000,
        userStaked: 0,
        pendingRewards: 0,
        lockPeriod: 0,
        minStake: 0.1,
        maxStake: 10000,
        status: 'Active',
        description: 'Stake CORE-ETH LP tokens to earn trading fees and protocol rewards',
        features: ['LP Rewards', 'Trading Fees', 'High APY'],
        riskLevel: 'Medium',
        rewardToken: 'CORE + ETH',
        multiplier: 3.0,
        poolWeight: 15,
        startDate: '2023-07-01T00:00:00Z',
        endDate: null
      },
      {
        id: 'governance',
        name: 'Governance Staking',
        token: 'CORE',
        apy: 8.5,
        totalStaked: 3400000,
        userStaked: 0,
        pendingRewards: 0,
        lockPeriod: 14,
        minStake: 1000,
        maxStake: 100000,
        status: 'Active',
        description: 'Stake CORE for governance voting power and earn protocol fees',
        features: ['Voting Power', 'Protocol Fees', 'Governance Rights'],
        riskLevel: 'Low',
        rewardToken: 'CORE + Fees',
        multiplier: 1.2,
        poolWeight: 10,
        startDate: '2023-08-01T00:00:00Z',
        endDate: null
      }
    ],
    rewardHistory: [
      {
        date: '2024-01-15T10:00:00Z',
        pool: 'CORE Single Staking',
        amount: 45.67,
        token: 'CORE',
        type: 'Claim',
        txHash: '0x1234...5678'
      },
      {
        date: '2024-01-10T14:20:00Z',
        pool: 'CORE Locked 30 Days',
        amount: 23.45,
        token: 'CORE',
        type: 'Claim',
        txHash: '0x2345...6789'
      },
      {
        date: '2024-01-05T09:15:00Z',
        pool: 'CORE Single Staking',
        amount: 38.92,
        token: 'CORE',
        type: 'Claim',
        txHash: '0x3456...7890'
      },
      {
        date: '2023-12-30T16:45:00Z',
        pool: 'CORE Locked 90 Days',
        amount: 67.89,
        token: 'CORE',
        type: 'Claim',
        txHash: '0x4567...8901'
      },
      {
        date: '2023-12-25T11:30:00Z',
        pool: 'CORE Single Staking',
        amount: 29.34,
        token: 'CORE',
        type: 'Claim',
        txHash: '0x5678...9012'
      }
    ],
    stakingHistory: [
      {
        date: '2024-01-12T08:30:00Z',
        pool: 'CORE Single Staking',
        amount: 5000,
        type: 'Stake',
        txHash: '0x6789...0123'
      },
      {
        date: '2024-01-08T15:45:00Z',
        pool: 'CORE Locked 30 Days',
        amount: 2500,
        type: 'Stake',
        txHash: '0x7890...1234'
      },
      {
        date: '2024-01-03T12:20:00Z',
        pool: 'CORE Single Staking',
        amount: 1000,
        type: 'Unstake',
        txHash: '0x8901...2345'
      },
      {
        date: '2023-12-28T09:10:00Z',
        pool: 'CORE Locked 90 Days',
        amount: 5000,
        type: 'Stake',
        txHash: '0x9012...3456'
      }
    ],
    analytics: {
      stakingTrends: {
        daily: [
          { date: '2024-01-10', staked: 44200000, apy: 12.3 },
          { date: '2024-01-11', staked: 44800000, apy: 12.4 },
          { date: '2024-01-12', staked: 45100000, apy: 12.5 },
          { date: '2024-01-13', staked: 45300000, apy: 12.5 },
          { date: '2024-01-14', staked: 45600000, apy: 12.5 },
          { date: '2024-01-15', staked: 45600000, apy: 12.5 }
        ],
        weekly: [
          { week: 'Week 1', staked: 42000000, rewards: 180000 },
          { week: 'Week 2', staked: 43500000, rewards: 195000 },
          { week: 'Week 3', staked: 44800000, rewards: 210000 },
          { week: 'Week 4', staked: 45600000, rewards: 225000 }
        ]
      },
      poolDistribution: [
        { pool: 'CORE Single', percentage: 34.2, amount: 15600000 },
        { pool: 'CORE 90-Day', percentage: 26.5, amount: 12100000 },
        { pool: 'CORE 30-Day', percentage: 19.5, amount: 8900000 },
        { pool: 'CORE-ETH LP', percentage: 12.3, amount: 5600000 },
        { pool: 'Governance', percentage: 7.5, amount: 3400000 }
      ],
      rewardDistribution: {
        totalDistributed: 2340000,
        thisMonth: 195000,
        lastMonth: 210000,
        averageDaily: 6500,
        topEarners: [
          { address: '0x1111...1111', earned: 12450 },
          { address: '0x2222...2222', earned: 9870 },
          { address: '0x3333...3333', earned: 8650 },
          { address: '0x4444...4444', earned: 7890 },
          { address: '0x5555...5555', earned: 6540 }
        ]
      }
    }
  });

  const getRiskColor = (risk: string) => {
    switch (risk) {
      case 'Low': return 'bg-green-100 text-green-800';
      case 'Medium': return 'bg-yellow-100 text-yellow-800';
      case 'High': return 'bg-red-100 text-red-800';
      default: return 'bg-gray-100 text-gray-800';
    }
  };

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'Active': return 'bg-green-100 text-green-800';
      case 'Paused': return 'bg-yellow-100 text-yellow-800';
      case 'Ended': return 'bg-red-100 text-red-800';
      default: return 'bg-gray-100 text-gray-800';
    }
  };

  const formatCurrency = (value: number) => {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD',
      minimumFractionDigits: 0,
      maximumFractionDigits: 0
    }).format(value);
  };

  const formatTokens = (value: number, decimals: number = 2) => {
    if (value >= 1000000) {
      return `${(value / 1000000).toFixed(1)}M`;
    } else if (value >= 1000) {
      return `${(value / 1000).toFixed(1)}K`;
    }
    return value.toFixed(decimals);
  };

  const calculateDaysRemaining = (endDate: string) => {
    if (!endDate) return null;
    const now = new Date();
    const end = new Date(endDate);
    const diff = end.getTime() - now.getTime();
    const days = Math.ceil(diff / (1000 * 60 * 60 * 24));
    return days > 0 ? days : 0;
  };

  const calculateTimeStaked = (startDate: string) => {
    const now = new Date();
    const start = new Date(startDate);
    const diff = now.getTime() - start.getTime();
    const days = Math.floor(diff / (1000 * 60 * 60 * 24));
    return days;
  };

  const handleStake = async (poolId: string, amount: string) => {
    if (!selectedValidator) {
      toast.error('Please select a validator');
      return;
    }
    
    setIsLoading(true);
    try {
      if (poolId === 'core-single' || poolId === 'core-btc-dual') {
        await handleCOREStake(amount, selectedValidator);
        toast.success('CORE staking successful!');
      } else {
        // For other pools, use mock for now
        await new Promise(resolve => setTimeout(resolve, 2000));
        console.log(`Staked ${amount} tokens in pool ${poolId}`);
        toast.success('Staking successful!');
      }
      
      setIsStakeDialogOpen(false);
      setStakeAmount('');
      setSelectedPool(null);
    } catch (error) {
      console.error('Staking failed:', error);
      toast.error('Staking failed');
    } finally {
      setIsLoading(false);
    }
  };

  const handleUnstake = async (poolId: string, amount: string) => {
    setIsLoading(true);
    try {
      if (poolId === 'core-single' || poolId === 'core-btc-dual') {
        await handleCOREUnstake(amount, 0); // positionIndex 0 for now
        toast.success('CORE unstaking successful!');
      } else {
        // For other pools, use mock for now
        await new Promise(resolve => setTimeout(resolve, 2000));
        console.log(`Unstaked ${amount} tokens from pool ${poolId}`);
        toast.success('Unstaking successful!');
      }
      
      setIsUnstakeDialogOpen(false);
      setUnstakeAmount('');
      setSelectedPool(null);
    } catch (error) {
      console.error('Unstaking failed:', error);
      toast.error('Unstaking failed');
    } finally {
      setIsLoading(false);
    }
  };

  const handleClaimRewards = async (poolId: string) => {
    setIsLoading(true);
    try {
      if (poolId === 'core-single' || poolId === 'core-btc-dual') {
        await handleCoreClaimRewards();
        toast.success('Rewards claimed successfully!');
      } else {
        // For other pools, use mock for now
        await new Promise(resolve => setTimeout(resolve, 1500));
        console.log(`Claimed rewards from pool ${poolId}`);
        toast.success('Rewards claimed successfully!');
      }
      
      setIsClaimDialogOpen(false);
      setSelectedPool(null);
    } catch (error) {
      console.error('Claim failed:', error);
      toast.error('Claim failed');
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-slate-900 via-purple-900 to-slate-900">
      <div className="container mx-auto px-4 py-8">
        {/* Header */}
        <div className="mb-8">
          <div className="flex items-center justify-between">
            <div>
              <h1 className="text-4xl font-bold text-white mb-2">Staking Rewards</h1>
              <p className="text-slate-300">Stake your CORE tokens and earn rewards</p>
            </div>
            <div className="flex items-center space-x-4">
              <div className="text-right">
                <p className="text-slate-400 text-sm">Your Balance</p>
                <p className="text-white font-bold text-lg">{formatTokens(userBalance)} CORE</p>
              </div>
              <Button className="bg-purple-600 hover:bg-purple-700">
                <RefreshCw className="w-4 h-4 mr-2" />
                Refresh
              </Button>
            </div>
          </div>
        </div>

        {/* Overview Stats */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
          <Card className="bg-slate-800/50 border-slate-700">
            <CardContent className="p-4">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-slate-400 text-sm">Total CORE Staked</p>
                  <p className="text-2xl font-bold text-white">
                    {stakingInfo ? formatStakingValue(stakingInfo.coreStaked) : '0'} CORE
                  </p>
                  <p className="text-green-400 text-sm">Your Position</p>
                </div>
                <Coins className="w-8 h-8 text-blue-400" />
              </div>
            </CardContent>
          </Card>

          <Card className="bg-slate-800/50 border-slate-700">
            <CardContent className="p-4">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-slate-400 text-sm">BTC Staked</p>
                  <p className="text-2xl font-bold text-white">
                    {stakingInfo ? formatStakingValue(stakingInfo.btcStaked) : '0'} BTC
                  </p>
                  <p className="text-orange-400 text-sm">Non-Custodial</p>
                </div>
                <Bitcoin className="w-8 h-8 text-orange-400" />
              </div>
            </CardContent>
          </Card>

          <Card className="bg-slate-800/50 border-slate-700">
            <CardContent className="p-4">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-slate-400 text-sm">stCORE APY</p>
                  <p className="text-2xl font-bold text-white">
                    {stCoreAPY && typeof stCoreAPY === 'string' ? formatAPY(BigInt(stCoreAPY)) : '0'}%
                  </p>
                  <p className="text-green-400 text-sm">Liquid Staking</p>
                </div>
                <TrendingUp className="w-8 h-8 text-green-400" />
              </div>
            </CardContent>
          </Card>

          <Card className="bg-slate-800/50 border-slate-700">
            <CardContent className="p-4">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-slate-400 text-sm">Pending Rewards</p>
                  <p className="text-2xl font-bold text-white">
                    {stakingInfo ? formatStakingValue(stakingInfo.pendingReward) : '0'} CORE
                  </p>
                  <p className="text-blue-400 text-sm">Ready to Claim</p>
                </div>
                <Gift className="w-8 h-8 text-purple-400" />
              </div>
            </CardContent>
          </Card>

        </div>

        {/* User Stats */}
        <Card className="bg-slate-800/50 border-slate-700 mb-8">
          <CardHeader>
            <CardTitle className="text-white flex items-center">
              <Award className="w-5 h-5 mr-2" />
              Your Core-Native Staking Overview
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
              <div className="text-center">
                <p className="text-3xl font-bold text-white">
                  {stakingInfo ? formatStakingValue(stakingInfo.coreStaked) : '0'}
                </p>
                <p className="text-slate-400">CORE Staked</p>
                <p className="text-green-400 text-sm">{stCoreAPY && typeof stCoreAPY === 'string' ? formatAPY(BigInt(stCoreAPY)) : '0'}% APY</p>
              </div>
              <div className="text-center">
                <p className="text-3xl font-bold text-orange-400">
                  {stakingInfo ? formatStakingValue(stakingInfo.btcStaked) : '0'}
                </p>
                <p className="text-slate-400">BTC Staked</p>
                <p className="text-orange-400 text-sm">Non-Custodial</p>
              </div>
              <div className="text-center">
                <p className="text-3xl font-bold text-green-400">
                  {stakingInfo ? formatStakingValue(stakingInfo.pendingReward) : '0'}
                </p>
                <p className="text-slate-400">Pending Rewards</p>
                <Button 
                  size="sm" 
                  className="mt-2 bg-green-600 hover:bg-green-700 disabled:opacity-50"
                  onClick={handleCoreClaimRewards}
                  disabled={coreNativeLoading || !stakingInfo?.pendingReward}
                >
                  {coreNativeLoading ? 'Processing...' : 'Claim All'}
                </Button>
              </div>
              <div className="text-center">
                <p className="text-3xl font-bold text-cyan-400">
                  {stakingInfo ? formatStakingValue(stakingInfo.stCoreBalance) : '0'}
                </p>
                <p className="text-slate-400">stCORE Balance</p>
                <p className="text-cyan-400 text-sm">Liquid Staking</p>
              </div>
            </div>
          </CardContent>
        </Card>

        <Tabs value={activeTab} onValueChange={setActiveTab} className="w-full">
          <TabsList className="grid w-full grid-cols-6 bg-slate-800/50">
            <TabsTrigger value="overview" className="data-[state=active]:bg-purple-600">CORE Staking</TabsTrigger>
            <TabsTrigger value="btc-staking" className="data-[state=active]:bg-orange-600">BTC Staking</TabsTrigger>
            <TabsTrigger value="dual-staking" className="data-[state=active]:bg-gradient-to-r from-orange-600 to-purple-600">Dual Staking</TabsTrigger>
            <TabsTrigger value="validators" className="data-[state=active]:bg-blue-600">Validators</TabsTrigger>
            <TabsTrigger value="history" className="data-[state=active]:bg-purple-600">History</TabsTrigger>
            <TabsTrigger value="analytics" className="data-[state=active]:bg-purple-600">Analytics</TabsTrigger>
          </TabsList>

          {/* Staking Pools Tab */}
          <TabsContent value="overview" className="space-y-6">
            <div className="grid gap-6">
              {Array.isArray(stakingData?.stakingPools) && stakingData.stakingPools.map((pool: any) => (
                <Card key={pool.id} className="bg-slate-800/50 border-slate-700 hover:border-purple-500 transition-colors">
                  <CardContent className="p-6">
                    <div className="flex items-start justify-between mb-4">
                      <div className="flex-1">
                        <div className="flex items-center space-x-3 mb-2">
                          <h3 className="text-white font-medium text-xl">{pool.name}</h3>
                          <Badge className={getStatusColor(pool.status)}>
                            {pool.status}
                          </Badge>
                          <Badge className={getRiskColor(pool.riskLevel)}>
                            {pool.riskLevel} Risk
                          </Badge>
                          {pool.lockPeriod > 0 && (
                            <Badge variant="outline" className="border-yellow-500 text-yellow-400">
                              <Lock className="w-3 h-3 mr-1" />
                              {pool.lockPeriod} days
                            </Badge>
                          )}
                        </div>
                        <p className="text-slate-400 text-sm mb-3">{pool.description}</p>
                        <div className="flex flex-wrap gap-2 mb-4">
                          {pool.features.map((feature: string, index: number) => (
                            <Badge key={index} variant="outline" className="text-xs">
                              {feature}
                            </Badge>
                          ))}
                        </div>
                      </div>
                      <div className="text-right">
                        <p className="text-3xl font-bold text-green-400">{pool.apy}%</p>
                        <p className="text-slate-400 text-sm">APY</p>
                      </div>
                    </div>

                    <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-4">
                      <div>
                        <p className="text-slate-400 text-sm">Total Staked</p>
                        <p className="text-white font-medium">{formatTokens(pool.totalStaked)} {pool.token}</p>
                      </div>
                      <div>
                        <p className="text-slate-400 text-sm">Your Stake</p>
                        <p className="text-white font-medium">{formatTokens(pool.userStaked)} {pool.token}</p>
                      </div>
                      <div>
                        <p className="text-slate-400 text-sm">Pending Rewards</p>
                        <p className="text-green-400 font-medium">{formatTokens(pool.pendingRewards)} CORE</p>
                      </div>
                      <div>
                        <p className="text-slate-400 text-sm">Multiplier</p>
                        <p className="text-purple-400 font-medium">{pool.multiplier}x</p>
                      </div>
                    </div>

                    <div className="space-y-2 mb-4">
                      <div className="flex justify-between text-sm">
                        <span className="text-slate-400">Pool Utilization</span>
                        <span className="text-slate-300">
                          {formatTokens(pool.totalStaked)} / {formatTokens(pool.maxStake * 100)} {pool.token}
                        </span>
                      </div>
                      <Progress value={(pool.totalStaked / (pool.maxStake * 100)) * 100} className="h-2" />
                    </div>

                    <div className="flex items-center justify-between">
                      <div className="text-sm text-slate-400">
                        <p>Min: {formatTokens(pool.minStake)} {pool.token}</p>
                        <p>Max: {formatTokens(pool.maxStake)} {pool.token}</p>
                      </div>
                      <div className="flex items-center space-x-2">
                        {pool.pendingRewards > 0 && (
                          <Button 
                            size="sm" 
                            className="bg-green-600 hover:bg-green-700"
                            onClick={() => {
                              setSelectedPool(pool);
                              setIsClaimDialogOpen(true);
                            }}
                          >
                            <Gift className="w-4 h-4 mr-1" />
                            Claim
                          </Button>
                        )}
                        <Button 
                          size="sm" 
                          className="bg-blue-600 hover:bg-blue-700"
                          onClick={() => {
                            setSelectedPool(pool);
                            setIsStakeDialogOpen(true);
                          }}
                        >
                          <Plus className="w-4 h-4 mr-1" />
                          Stake
                        </Button>
                        {pool.userStaked > 0 && (
                          <Button 
                            size="sm" 
                            variant="outline" 
                            className="border-slate-600"
                            onClick={() => {
                              setSelectedPool(pool);
                              setIsUnstakeDialogOpen(true);
                            }}
                          >
                            <Minus className="w-4 h-4 mr-1" />
                            Unstake
                          </Button>
                        )}
                        <Button size="sm" variant="outline" className="border-slate-600">
                          <Eye className="w-4 h-4 mr-1" />
                          Details
                        </Button>
                      </div>
                    </div>
                  </CardContent>
                </Card>
              ))}
            </div>
          </TabsContent>

          {/* BTC Staking Tab */}
          <TabsContent value="btc-staking" className="space-y-6">
            <Card className="bg-gradient-to-br from-orange-900/20 to-yellow-900/20 border-orange-500/20">
              <CardHeader>
                <CardTitle className="text-white flex items-center">
                  <Bitcoin className="w-6 h-6 mr-2 text-orange-400" />
                  Bitcoin Non-Custodial Staking
                </CardTitle>
                <CardDescription className="text-slate-300">
                  Stake your Bitcoin directly from your wallet. No custody required - you maintain full control.
                </CardDescription>
              </CardHeader>
              <CardContent className="space-y-6">
                <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-6">
                  <div className="bg-slate-800/50 p-4 rounded-lg">
                    <p className="text-slate-400 text-sm">Minimum Stake</p>
                    <p className="text-2xl font-bold text-orange-400">0.01 BTC</p>
                  </div>
                  <div className="bg-slate-800/50 p-4 rounded-lg">
                    <p className="text-slate-400 text-sm">Lock Period</p>
                    <p className="text-2xl font-bold text-white">{lockDays} Days</p>
                  </div>
                  <div className="bg-slate-800/50 p-4 rounded-lg">
                    <p className="text-slate-400 text-sm">Estimated APY</p>
                    <p className="text-2xl font-bold text-green-400">8-12%</p>
                  </div>
                </div>

                <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                  <div className="space-y-4">
                    <div>
                      <Label htmlFor="btc-tx-hash" className="text-white">Bitcoin Transaction Hash</Label>
                      <Input
                        id="btc-tx-hash"
                        placeholder="Enter BTC transaction hash"
                        value={btcTxHash}
                        onChange={(e) => setBtcTxHash(e.target.value)}
                        className="bg-slate-800 border-slate-600 text-white"
                      />
                      <p className="text-xs text-slate-400 mt-1">
                        Hash of your BTC time-lock transaction
                      </p>
                    </div>
                    
                    <div>
                      <Label htmlFor="btc-amount" className="text-white">BTC Amount</Label>
                      <Input
                        id="btc-amount"
                        type="number"
                        placeholder="0.01"
                        value={btcAmount}
                        onChange={(e) => setBtcAmount(e.target.value)}
                        className="bg-slate-800 border-slate-600 text-white"
                        step="0.001"
                        min="0.01"
                      />
                    </div>

                    <div>
                      <Label htmlFor="lock-period" className="text-white">Lock Period (Days)</Label>
                      <Select value={lockDays.toString()} onValueChange={(value) => setLockDays(Number(value))}>
                        <SelectTrigger className="bg-slate-800 border-slate-600 text-white">
                          <SelectValue />
                        </SelectTrigger>
                        <SelectContent>
                          <SelectItem value="30">30 Days</SelectItem>
                          <SelectItem value="60">60 Days</SelectItem>
                          <SelectItem value="90">90 Days</SelectItem>
                          <SelectItem value="180">180 Days</SelectItem>
                          <SelectItem value="365">365 Days</SelectItem>
                        </SelectContent>
                      </Select>
                    </div>

                    <div>
                      <Label htmlFor="validator-select" className="text-white">Select Validator</Label>
                      <Select value={selectedValidator} onValueChange={setSelectedValidator}>
                        <SelectTrigger className="bg-slate-800 border-slate-600 text-white">
                          <SelectValue placeholder="Choose a validator" />
                        </SelectTrigger>
                        <SelectContent>
                          {Array.isArray(activeValidators) && activeValidators.map((validator: string, index: number) => (
                            <SelectItem key={index} value={validator}>
                              {validator.slice(0, 10)}...{validator.slice(-8)}
                            </SelectItem>
                          ))}
                        </SelectContent>
                      </Select>
                    </div>
                  </div>

                  <div className="space-y-4">
                    <div className="bg-slate-800/50 p-4 rounded-lg">
                      <h4 className="text-white font-medium mb-3">How BTC Staking Works</h4>
                      <div className="space-y-2 text-sm text-slate-300">
                        <div className="flex items-start space-x-2">
                          <div className="w-2 h-2 bg-orange-400 rounded-full mt-2 flex-shrink-0"></div>
                          <p>Lock your BTC using time-lock scripts</p>
                        </div>
                        <div className="flex items-start space-x-2">
                          <div className="w-2 h-2 bg-orange-400 rounded-full mt-2 flex-shrink-0"></div>
                          <p>Delegate hash power to Core validators</p>
                        </div>
                        <div className="flex items-start space-x-2">
                          <div className="w-2 h-2 bg-orange-400 rounded-full mt-2 flex-shrink-0"></div>
                          <p>Earn CORE token rewards</p>
                        </div>
                        <div className="flex items-start space-x-2">
                          <div className="w-2 h-2 bg-orange-400 rounded-full mt-2 flex-shrink-0"></div>
                          <p>Redeem BTC after lock period</p>
                        </div>
                      </div>
                    </div>

                    <div className="bg-slate-800/50 p-4 rounded-lg">
                      <h4 className="text-white font-medium mb-2">Security Features</h4>
                      <div className="space-y-1 text-sm text-slate-300">
                        <p>✓ Non-custodial - you control your keys</p>
                        <p>✓ Time-lock protection</p>
                        <p>✓ Validator delegation</p>
                        <p>✓ Slashing protection</p>
                      </div>
                    </div>
                  </div>
                </div>

                <Button 
                  onClick={async () => {
                    if (!btcTxHash || !btcAmount || !selectedValidator) {
                      toast.error('Please fill all required fields');
                      return;
                    }
                    await handleBTCStake(btcTxHash, btcAmount, lockDays, selectedValidator, '0');
                  }}
                  disabled={coreNativeLoading || !btcTxHash || !btcAmount || !selectedValidator}
                  className="w-full bg-gradient-to-r from-orange-600 to-yellow-600 hover:from-orange-700 hover:to-yellow-700 disabled:opacity-50"
                >
                  {coreNativeLoading ? 'Processing...' : 'Stake Bitcoin'}
                </Button>
              </CardContent>
            </Card>
          </TabsContent>

          {/* Dual Staking Tab */}
          <TabsContent value="dual-staking" className="space-y-6">
            <Card className="bg-gradient-to-br from-orange-900/20 via-purple-900/20 to-blue-900/20 border-gradient-to-r from-orange-500/20 to-purple-500/20">
              <CardHeader>
                <CardTitle className="text-white flex items-center">
                  <div className="flex items-center space-x-2">
                    <Bitcoin className="w-5 h-5 text-orange-400" />
                    <span className="text-slate-400">+</span>
                    <Coins className="w-5 h-5 text-purple-400" />
                  </div>
                  <span className="ml-2">Dual Staking - BTC + CORE</span>
                </CardTitle>
                <CardDescription className="text-slate-300">
                  Boost your BTC staking rewards by also staking CORE tokens. Higher CORE:BTC ratio = higher rewards multiplier.
                </CardDescription>
              </CardHeader>
              <CardContent className="space-y-6">
                {dualStakingTiers.length > 0 && (
                  <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-6">
                    {dualStakingTiers.map((tier, index) => (
                      <div key={index} className={`p-4 rounded-lg border ${
                        index === calculateDualStakingTier(btcAmount, coreAmount) 
                          ? 'bg-gradient-to-br from-purple-600/20 to-orange-600/20 border-purple-500' 
                          : 'bg-slate-800/50 border-slate-600'
                      }`}>
                        <div className="text-center">
                          <h4 className="text-white font-medium">{tier.tierName}</h4>
                          <p className="text-2xl font-bold text-purple-400">{Number(tier.multiplier) / 100}x</p>
                          <p className="text-slate-400 text-sm">
                            {formatStakingValue(tier.corePerBTC)} CORE per BTC
                          </p>
                        </div>
                      </div>
                    ))}
                  </div>
                )}

                <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                  <div className="space-y-4">
                    <div>
                      <Label htmlFor="dual-btc-tx" className="text-white">Bitcoin Transaction Hash</Label>
                      <Input
                        id="dual-btc-tx"
                        placeholder="Enter BTC transaction hash"
                        value={btcTxHash}
                        onChange={(e) => setBtcTxHash(e.target.value)}
                        className="bg-slate-800 border-slate-600 text-white"
                      />
                    </div>
                    
                    <div>
                      <Label htmlFor="dual-btc-amount" className="text-white">BTC Amount</Label>
                      <Input
                        id="dual-btc-amount"
                        type="number"
                        placeholder="0.01"
                        value={btcAmount}
                        onChange={(e) => setBtcAmount(e.target.value)}
                        className="bg-slate-800 border-slate-600 text-white"
                        step="0.001"
                        min="0.01"
                      />
                    </div>

                    <div>
                      <Label htmlFor="dual-core-amount" className="text-white">CORE Amount (Optional for Boost)</Label>
                      <Input
                        id="dual-core-amount"
                        type="number"
                        placeholder="1.0"
                        value={coreAmount}
                        onChange={(e) => setCoreAmount(e.target.value)}
                        className="bg-slate-800 border-slate-600 text-white"
                        step="0.1"
                        min="1"
                      />
                      <p className="text-xs text-slate-400 mt-1">
                        Add CORE to boost your BTC staking rewards
                      </p>
                    </div>

                    <div>
                      <Label htmlFor="dual-validator" className="text-white">Select Validator</Label>
                      <Select value={selectedValidator} onValueChange={setSelectedValidator}>
                        <SelectTrigger className="bg-slate-800 border-slate-600 text-white">
                          <SelectValue placeholder="Choose a validator" />
                        </SelectTrigger>
                        <SelectContent>
                          {Array.isArray(activeValidators) && activeValidators.map((validator: string, index: number) => (
                            <SelectItem key={index} value={validator}>
                              {validator.slice(0, 10)}...{validator.slice(-8)}
                            </SelectItem>
                          ))}
                        </SelectContent>
                      </Select>
                    </div>
                  </div>

                  <div className="space-y-4">
                    <div className="bg-slate-800/50 p-4 rounded-lg">
                      <h4 className="text-white font-medium mb-3">Current Tier Calculation</h4>
                      {btcAmount && coreAmount ? (
                        <div className="space-y-2">
                          <p className="text-slate-300">BTC: {btcAmount}</p>
                          <p className="text-slate-300">CORE: {coreAmount}</p>
                          <p className="text-slate-300">
                            Ratio: {coreAmount && btcAmount ? (Number(coreAmount) / Number(btcAmount)).toFixed(2) : '0'} CORE/BTC
                          </p>
                          <div className="border-t border-slate-600 pt-2">
                            <p className="text-purple-400 font-medium">
                              Tier: {dualStakingTiers[calculateDualStakingTier(btcAmount, coreAmount)]?.tierName || 'Basic'}
                            </p>
                            <p className="text-green-400 font-medium">
                              Multiplier: {dualStakingTiers[calculateDualStakingTier(btcAmount, coreAmount)] ? 
                                Number(dualStakingTiers[calculateDualStakingTier(btcAmount, coreAmount)].multiplier) / 100 : 1}x
                            </p>
                          </div>
                        </div>
                      ) : (
                        <p className="text-slate-400">Enter amounts to see tier calculation</p>
                      )}
                    </div>

                    <div className="bg-slate-800/50 p-4 rounded-lg">
                      <h4 className="text-white font-medium mb-2">Dual Staking Benefits</h4>
                      <div className="space-y-1 text-sm text-slate-300">
                        <p>✓ Higher rewards than single BTC staking</p>
                        <p>✓ Tier-based multiplier system</p>
                        <p>✓ Flexible CORE amount</p>
                        <p>✓ Compound earning potential</p>
                      </div>
                    </div>
                  </div>
                </div>

                <Button 
                  onClick={async () => {
                    if (!btcTxHash || !btcAmount || !selectedValidator) {
                      toast.error('Please fill all required fields');
                      return;
                    }
                    await handleBTCStake(btcTxHash, btcAmount, lockDays, selectedValidator, coreAmount || '0');
                  }}
                  disabled={coreNativeLoading || !btcTxHash || !btcAmount || !selectedValidator}
                  className="w-full bg-gradient-to-r from-orange-600 via-purple-600 to-blue-600 hover:from-orange-700 hover:via-purple-700 hover:to-blue-700 disabled:opacity-50"
                >
                  {coreNativeLoading ? 'Processing...' : 'Start Dual Staking'}
                </Button>
              </CardContent>
            </Card>
          </TabsContent>

          {/* Validators Tab */}
          <TabsContent value="validators" className="space-y-6">
            <Card className="bg-slate-800/50 border-slate-700">
              <CardHeader>
                <CardTitle className="text-white flex items-center">
                  <Users className="w-6 h-6 mr-2 text-blue-400" />
                  Core Chain Validators
                </CardTitle>
                <CardDescription className="text-slate-300">
                  Choose validators to delegate your staking power and earn rewards.
                </CardDescription>
              </CardHeader>
              <CardContent>
                <div className="space-y-4">
                  {Array.isArray(activeValidators) && activeValidators.length > 0 ? (
                     activeValidators.map((validator: string, index: number) => (
                      <div key={index} className="bg-slate-700/30 p-4 rounded-lg">
                        <div className="flex items-center justify-between">
                          <div>
                            <p className="text-white font-medium">
                              {validator.slice(0, 10)}...{validator.slice(-8)}
                            </p>
                            <p className="text-slate-400 text-sm">Validator Address</p>
                          </div>
                          <Button 
                            size="sm"
                            onClick={() => setSelectedValidator(validator)}
                            className={selectedValidator === validator ? 
                              'bg-blue-600 hover:bg-blue-700' : 
                              'bg-slate-600 hover:bg-slate-700'
                            }
                          >
                            {selectedValidator === validator ? 'Selected' : 'Select'}
                          </Button>
                        </div>
                      </div>
                    ))
                  ) : (
                    <div className="text-center py-8">
                      <p className="text-slate-400">No validators available</p>
                    </div>
                  )}
                </div>
              </CardContent>
            </Card>
          </TabsContent>

          {/* History Tab */}
          <TabsContent value="history" className="space-y-6">
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
              <Card className="bg-slate-800/50 border-slate-700">
                <CardHeader>
                  <CardTitle className="text-white">Staking History</CardTitle>
                </CardHeader>
                <CardContent>
                  <div className="space-y-4">
                    {Array.isArray(stakingData?.stakingHistory) && stakingData.stakingHistory.map((entry: any, index: number) => (
                      <div key={index} className="flex items-center justify-between p-3 bg-slate-700/30 rounded-lg">
                        <div className="flex items-center space-x-3">
                          {entry.type === 'Stake' ? (
                            <ArrowUpRight className="w-5 h-5 text-green-400" />
                          ) : (
                            <ArrowDownRight className="w-5 h-5 text-red-400" />
                          )}
                          <div>
                            <p className="text-white font-medium">{entry.type} {formatTokens(entry.amount)} CORE</p>
                            <p className="text-slate-400 text-sm">{entry.pool}</p>
                          </div>
                        </div>
                        <div className="text-right">
                          <p className="text-slate-300 text-sm">{new Date(entry.date).toLocaleDateString()}</p>
                          <p className="text-slate-500 text-xs">{entry.txHash.slice(0, 10)}...</p>
                        </div>
                      </div>
                    ))}
                  </div>
                </CardContent>
              </Card>

              <Card className="bg-slate-800/50 border-slate-700">
                <CardHeader>
                  <CardTitle className="text-white">Reward Claims</CardTitle>
                </CardHeader>
                <CardContent>
                  <div className="space-y-4">
                    {stakingData.rewardHistory.map((entry, index) => (
                      <div key={index} className="flex items-center justify-between p-3 bg-slate-700/30 rounded-lg">
                        <div className="flex items-center space-x-3">
                          <Gift className="w-5 h-5 text-purple-400" />
                          <div>
                            <p className="text-white font-medium">+{formatTokens(entry.amount)} {entry.token}</p>
                            <p className="text-slate-400 text-sm">{entry.pool}</p>
                          </div>
                        </div>
                        <div className="text-right">
                          <p className="text-slate-300 text-sm">{new Date(entry.date).toLocaleDateString()}</p>
                          <p className="text-slate-500 text-xs">{entry.txHash.slice(0, 10)}...</p>
                        </div>
                      </div>
                    ))}
                  </div>
                </CardContent>
              </Card>
            </div>
          </TabsContent>

          {/* Rewards Tab */}
          <TabsContent value="rewards" className="space-y-6">
            <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
              <Card className="bg-slate-800/50 border-slate-700">
                <CardHeader>
                  <CardTitle className="text-white">Reward Summary</CardTitle>
                </CardHeader>
                <CardContent>
                  <div className="space-y-4">
                    <div className="text-center">
                      <p className="text-3xl font-bold text-green-400">{formatTokens(stakingData.userStats.pendingRewards)}</p>
                      <p className="text-slate-400">Pending Rewards</p>
                      <Button className="mt-3 w-full bg-green-600 hover:bg-green-700">
                        <Gift className="w-4 h-4 mr-2" />
                        Claim All Rewards
                      </Button>
                    </div>
                    <div className="border-t border-slate-700 pt-4">
                      <div className="flex justify-between mb-2">
                        <span className="text-slate-400">Total Claimed</span>
                        <span className="text-white">{formatTokens(stakingData.userStats.claimedRewards)} CORE</span>
                      </div>
                      <div className="flex justify-between mb-2">
                        <span className="text-slate-400">Last Claim</span>
                        <span className="text-white">{new Date(stakingData.userStats.lastClaim).toLocaleDateString()}</span>
                      </div>
                      <div className="flex justify-between">
                        <span className="text-slate-400">Next Distribution</span>
                        <span className="text-white">{new Date(stakingData.overview.nextRewardDistribution).toLocaleDateString()}</span>
                      </div>
                    </div>
                  </div>
                </CardContent>
              </Card>

              <Card className="bg-slate-800/50 border-slate-700 lg:col-span-2">
                <CardHeader>
                  <CardTitle className="text-white">Reward Breakdown by Pool</CardTitle>
                </CardHeader>
                <CardContent>
                  <div className="space-y-4">
                    {Array.isArray(stakingData?.stakingPools) && stakingData.stakingPools.filter((pool: any) => pool.pendingRewards > 0).map((pool: any) => (
                      <div key={pool.id} className="flex items-center justify-between p-4 bg-slate-700/30 rounded-lg">
                        <div className="flex items-center space-x-4">
                          <div className={`w-3 h-3 rounded-full ${
                            pool.id === 'core-single' ? 'bg-blue-400' :
                            pool.id === 'core-locked-30' ? 'bg-green-400' :
                            pool.id === 'core-locked-90' ? 'bg-purple-400' :
                            pool.id === 'core-lp' ? 'bg-yellow-400' :
                            'bg-red-400'
                          }`}></div>
                          <div>
                            <p className="text-white font-medium">{pool.name}</p>
                            <p className="text-slate-400 text-sm">{formatTokens(pool.userStaked)} {pool.token} staked</p>
                          </div>
                        </div>
                        <div className="text-right">
                          <p className="text-green-400 font-medium">{formatTokens(pool.pendingRewards)} CORE</p>
                          <p className="text-slate-400 text-sm">{pool.apy}% APY</p>
                        </div>
                      </div>
                    ))}
                  </div>
                </CardContent>
              </Card>
            </div>
          </TabsContent>

          {/* CORE Staking Tab */}
          <TabsContent value="core-staking" className="space-y-6">
            <Card className="bg-gradient-to-br from-purple-900/20 to-blue-900/20 border-purple-500/20">
              <CardHeader>
                <CardTitle className="text-white flex items-center">
                  <Coins className="w-6 h-6 mr-2 text-purple-400" />
                  CORE Token Staking
                </CardTitle>
                <CardDescription className="text-slate-300">
                  Stake CORE tokens to earn rewards and participate in governance. Get liquid stCORE tokens in return.
                </CardDescription>
              </CardHeader>
              <CardContent className="space-y-6">
                <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-6">
                  <div className="bg-slate-800/50 p-4 rounded-lg">
                    <p className="text-slate-400 text-sm">Current APY</p>
                    <p className="text-2xl font-bold text-purple-400">{stCoreAPY && typeof stCoreAPY === 'string' ? formatStakingValue(BigInt(stCoreAPY)) : '0'}%</p>
                  </div>
                  <div className="bg-slate-800/50 p-4 rounded-lg">
                    <p className="text-slate-400 text-sm">Exchange Rate</p>
                    <p className="text-2xl font-bold text-white">1 stCORE = {protocolStats?.exchangeRate ? formatStakingValue(protocolStats.exchangeRate) : '1.0'} CORE</p>
                  </div>
                  <div className="bg-slate-800/50 p-4 rounded-lg">
                    <p className="text-slate-400 text-sm">Total Staked</p>
                    <p className="text-2xl font-bold text-green-400">{protocolStats?.totalStaked ? formatStakingValue(protocolStats.totalStaked) : '0'} CORE</p>
                  </div>
                </div>

                <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                  <div className="space-y-4">
                    <div>
                      <Label htmlFor="core-stake-amount" className="text-white">CORE Amount to Stake</Label>
                      <Input
                        id="core-stake-amount"
                        type="number"
                        placeholder="1.0"
                        value={coreAmount}
                        onChange={(e) => setCoreAmount(e.target.value)}
                        className="bg-slate-800 border-slate-600 text-white"
                        step="0.1"
                        min="1"
                      />
                      <p className="text-xs text-slate-400 mt-1">
                        Minimum: 1 CORE
                      </p>
                    </div>
                    
                    <div className="bg-slate-800/50 p-4 rounded-lg">
                      <h4 className="text-white font-medium mb-2">You will receive:</h4>
                      <p className="text-2xl font-bold text-purple-400">
                         {coreAmount && protocolStats?.exchangeRate ? 
                           (Number(coreAmount) / Number(formatEther(protocolStats.exchangeRate))).toFixed(4) : '0'
                         } stCORE
                       </p>
                      <p className="text-slate-400 text-sm mt-1">
                        Liquid staking tokens that earn rewards automatically
                      </p>
                    </div>

                    <div className="bg-slate-800/50 p-4 rounded-lg">
                      <h4 className="text-white font-medium mb-2">Estimated Annual Rewards</h4>
                      <p className="text-xl font-bold text-green-400">
                         {coreAmount && stCoreAPY ? 
                           (Number(coreAmount) * Number(formatEther(BigInt(stCoreAPY && typeof stCoreAPY === 'string' ? stCoreAPY : '0'))) / 100).toFixed(4) : '0'
                         } CORE
                       </p>
                    </div>
                  </div>

                  <div className="space-y-4">
                    <div className="bg-slate-800/50 p-4 rounded-lg">
                      <h4 className="text-white font-medium mb-3">stCORE Benefits</h4>
                      <div className="space-y-2 text-sm text-slate-300">
                        <div className="flex items-start space-x-2">
                          <div className="w-2 h-2 bg-purple-400 rounded-full mt-2 flex-shrink-0"></div>
                          <p>Liquid staking - trade anytime</p>
                        </div>
                        <div className="flex items-start space-x-2">
                          <div className="w-2 h-2 bg-purple-400 rounded-full mt-2 flex-shrink-0"></div>
                          <p>Auto-compounding rewards</p>
                        </div>
                        <div className="flex items-start space-x-2">
                          <div className="w-2 h-2 bg-purple-400 rounded-full mt-2 flex-shrink-0"></div>
                          <p>Use in DeFi protocols</p>
                        </div>
                        <div className="flex items-start space-x-2">
                          <div className="w-2 h-2 bg-purple-400 rounded-full mt-2 flex-shrink-0"></div>
                          <p>Governance participation</p>
                        </div>
                      </div>
                    </div>

                    <div className="bg-slate-800/50 p-4 rounded-lg">
                      <h4 className="text-white font-medium mb-2">Your stCORE Balance</h4>
                      <p className="text-2xl font-bold text-purple-400">
                         {stakingInfo?.stCoreBalance ? formatStakingValue(stakingInfo.stCoreBalance) : '0'} stCORE
                       </p>
                       <p className="text-slate-400 text-sm">
                         ≈ {stakingInfo?.stCoreBalance && protocolStats?.exchangeRate ? 
                           (Number(formatEther(stakingInfo.stCoreBalance)) * Number(formatEther(protocolStats.exchangeRate))).toFixed(4) : '0'
                         } CORE
                       </p>
                    </div>

                    <div className="bg-slate-800/50 p-4 rounded-lg">
                      <h4 className="text-white font-medium mb-2">Unstake stCORE</h4>
                      <div className="space-y-2">
                        <Input
                          type="number"
                          placeholder="Amount to unstake"
                          value={unstakeAmount}
                          onChange={(e) => setUnstakeAmount(e.target.value)}
                          className="bg-slate-700 border-slate-600 text-white text-sm"
                          step="0.1"
                        />
                        <Button 
                          size="sm"
                          onClick={async () => {
                            if (!unstakeAmount) {
                              toast.error('Please enter amount to unstake');
                              return;
                            }
                            await handleCOREUnstake(unstakeAmount, 0);
                          }}
                          disabled={coreNativeLoading || !unstakeAmount}
                          className="w-full bg-red-600 hover:bg-red-700 disabled:opacity-50"
                        >
                          {coreNativeLoading ? 'Processing...' : 'Unstake stCORE'}
                        </Button>
                      </div>
                    </div>
                  </div>
                </div>

                <Button 
                  onClick={async () => {
                    if (!coreAmount) {
                      toast.error('Please enter CORE amount to stake');
                      return;
                    }
                    await handleCOREStake(coreAmount, selectedValidator || '0x0000000000000000000000000000000000000000');
                  }}
                  disabled={coreNativeLoading || !coreAmount}
                  className="w-full bg-gradient-to-r from-purple-600 to-blue-600 hover:from-purple-700 hover:to-blue-700 disabled:opacity-50"
                >
                  {coreNativeLoading ? 'Processing...' : 'Stake CORE'}
                </Button>
              </CardContent>
            </Card>
          </TabsContent>

          {/* Analytics Tab */}
          <TabsContent value="analytics" className="space-y-6">
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
              <Card className="bg-slate-800/50 border-slate-700">
                <CardHeader>
                  <CardTitle className="text-white">Pool Distribution</CardTitle>
                </CardHeader>
                <CardContent>
                  <div className="h-64 flex items-center justify-center">
                    <div className="text-center">
                      <PieChart className="w-16 h-16 text-slate-600 mx-auto mb-4" />
                      <p className="text-slate-400">Pool distribution chart would be rendered here</p>
                      <p className="text-slate-500 text-sm">Using libraries like Chart.js or Recharts</p>
                    </div>
                  </div>
                  <div className="space-y-2 mt-4">
                    {stakingData.analytics.poolDistribution.map((pool, index) => (
                      <div key={index} className="flex items-center justify-between">
                        <div className="flex items-center space-x-2">
                          <div className={`w-3 h-3 rounded-full ${
                            index === 0 ? 'bg-blue-400' :
                            index === 1 ? 'bg-green-400' :
                            index === 2 ? 'bg-purple-400' :
                            index === 3 ? 'bg-yellow-400' :
                            'bg-red-400'
                          }`}></div>
                          <span className="text-slate-300">{pool.pool}</span>
                        </div>
                        <div className="text-right">
                          <span className="text-white">{pool.percentage}%</span>
                          <p className="text-slate-400 text-sm">{formatTokens(pool.amount)}</p>
                        </div>
                      </div>
                    ))}
                  </div>
                </CardContent>
              </Card>

              <Card className="bg-slate-800/50 border-slate-700">
                <CardHeader>
                  <CardTitle className="text-white">Staking Trends</CardTitle>
                </CardHeader>
                <CardContent>
                  <div className="h-64 flex items-center justify-center">
                    <div className="text-center">
                      <BarChart3 className="w-16 h-16 text-slate-600 mx-auto mb-4" />
                      <p className="text-slate-400">Staking trends chart would be rendered here</p>
                      <p className="text-slate-500 text-sm">Showing staking volume over time</p>
                    </div>
                  </div>
                </CardContent>
              </Card>
            </div>

            <Card className="bg-slate-800/50 border-slate-700">
              <CardHeader>
                <CardTitle className="text-white">Top Reward Earners</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="space-y-3">
                  {stakingData.analytics.rewardDistribution.topEarners.map((earner, index) => (
                    <div key={index} className="flex items-center justify-between p-3 bg-slate-700/30 rounded-lg">
                      <div className="flex items-center space-x-3">
                        <div className="flex items-center justify-center w-8 h-8 bg-purple-600 rounded-full">
                          <span className="text-white font-bold text-sm">#{index + 1}</span>
                        </div>
                        <span className="text-slate-300 font-mono">{earner.address}</span>
                      </div>
                      <div className="text-right">
                        <p className="text-green-400 font-medium">{formatTokens(earner.earned)} CORE</p>
                        <p className="text-slate-400 text-sm">Total earned</p>
                      </div>
                    </div>
                  ))}
                </div>
              </CardContent>
            </Card>
          </TabsContent>

          {/* Calculator Tab */}
          <TabsContent value="calculator" className="space-y-6">
            <Card className="bg-slate-800/50 border-slate-700">
              <CardHeader>
                <CardTitle className="text-white">Staking Rewards Calculator</CardTitle>
                <CardDescription className="text-slate-400">
                  Calculate potential rewards based on staking amount and duration
                </CardDescription>
              </CardHeader>
              <CardContent>
                <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
                  <div className="space-y-4">
                    <div>
                      <label className="text-slate-300 text-sm font-medium">Staking Amount</label>
                      <Input 
                        type="number" 
                        placeholder="Enter amount to stake" 
                        className="bg-slate-700 border-slate-600 text-white"
                      />
                    </div>
                    <div>
                      <label className="text-slate-300 text-sm font-medium">Staking Pool</label>
                      <Select>
                        <SelectTrigger className="bg-slate-700 border-slate-600 text-white">
                          <SelectValue placeholder="Select pool" />
                        </SelectTrigger>
                        <SelectContent>
                          {Array.isArray(stakingData?.stakingPools) && stakingData.stakingPools.map((pool: any) => (
                            <SelectItem key={pool.id} value={pool.id}>
                              {pool.name} ({pool.apy}% APY)
                            </SelectItem>
                          ))}
                        </SelectContent>
                      </Select>
                    </div>
                    <div>
                      <label className="text-slate-300 text-sm font-medium">Staking Duration (days)</label>
                      <Input 
                        type="number" 
                        placeholder="Enter duration" 
                        className="bg-slate-700 border-slate-600 text-white"
                      />
                    </div>
                    <Button className="w-full bg-purple-600 hover:bg-purple-700">
                      <Target className="w-4 h-4 mr-2" />
                      Calculate Rewards
                    </Button>
                  </div>
                  <div className="space-y-4">
                    <div className="p-4 bg-slate-700/30 rounded-lg">
                      <h3 className="text-white font-medium mb-3">Estimated Rewards</h3>
                      <div className="space-y-2">
                        <div className="flex justify-between">
                          <span className="text-slate-400">Daily Rewards:</span>
                          <span className="text-white">0.00 CORE</span>
                        </div>
                        <div className="flex justify-between">
                          <span className="text-slate-400">Weekly Rewards:</span>
                          <span className="text-white">0.00 CORE</span>
                        </div>
                        <div className="flex justify-between">
                          <span className="text-slate-400">Monthly Rewards:</span>
                          <span className="text-white">0.00 CORE</span>
                        </div>
                        <div className="flex justify-between border-t border-slate-600 pt-2">
                          <span className="text-slate-400">Total Rewards:</span>
                          <span className="text-green-400 font-medium">0.00 CORE</span>
                        </div>
                      </div>
                    </div>
                    <div className="p-4 bg-slate-700/30 rounded-lg">
                      <h3 className="text-white font-medium mb-3">Breakdown</h3>
                      <div className="space-y-2 text-sm">
                        <div className="flex justify-between">
                          <span className="text-slate-400">Principal:</span>
                          <span className="text-white">0.00 CORE</span>
                        </div>
                        <div className="flex justify-between">
                          <span className="text-slate-400">APY:</span>
                          <span className="text-white">0.00%</span>
                        </div>
                        <div className="flex justify-between">
                          <span className="text-slate-400">Duration:</span>
                          <span className="text-white">0 days</span>
                        </div>
                        <div className="flex justify-between">
                          <span className="text-slate-400">Multiplier:</span>
                          <span className="text-white">1.0x</span>
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              </CardContent>
            </Card>
          </TabsContent>
        </Tabs>

        {/* Stake Dialog */}
        <Dialog open={isStakeDialogOpen} onOpenChange={setIsStakeDialogOpen}>
          <DialogContent className="bg-slate-800 border-slate-700 text-white">
            <DialogHeader>
              <DialogTitle>Stake Tokens</DialogTitle>
              <DialogDescription className="text-slate-400">
                {selectedPool && `Stake ${selectedPool.token} tokens in ${selectedPool.name}`}
              </DialogDescription>
            </DialogHeader>
            <div className="space-y-4">
              <div>
                <label className="text-slate-300 text-sm font-medium">Amount to Stake</label>
                <Input
                  type="number"
                  placeholder="Enter amount"
                  value={stakeAmount}
                  onChange={(e) => setStakeAmount(e.target.value)}
                  className="bg-slate-700 border-slate-600 text-white"
                />
                {selectedPool && (
                  <p className="text-slate-400 text-sm mt-1">
                    Min: {formatTokens(selectedPool.minStake)} - Max: {formatTokens(selectedPool.maxStake)} {selectedPool.token}
                  </p>
                )}
              </div>
              {selectedPool && selectedPool.lockPeriod > 0 && (
                <div className="p-3 bg-yellow-500/10 rounded-lg border border-yellow-500/20">
                  <div className="flex items-center space-x-2">
                    <Lock className="w-4 h-4 text-yellow-400" />
                    <p className="text-yellow-400 text-sm">
                      Tokens will be locked for {selectedPool.lockPeriod} days
                    </p>
                  </div>
                </div>
              )}
              <div className="flex justify-end space-x-2">
                <Button variant="outline" onClick={() => setIsStakeDialogOpen(false)}>
                  Cancel
                </Button>
                <Button 
                  className="bg-blue-600 hover:bg-blue-700"
                  onClick={() => selectedPool && handleStake(selectedPool.id, stakeAmount)}
                  disabled={isLoading || !stakeAmount}
                >
                  {isLoading ? 'Staking...' : 'Stake Tokens'}
                </Button>
              </div>
            </div>
          </DialogContent>
        </Dialog>

        {/* Unstake Dialog */}
        <Dialog open={isUnstakeDialogOpen} onOpenChange={setIsUnstakeDialogOpen}>
          <DialogContent className="bg-slate-800 border-slate-700 text-white">
            <DialogHeader>
              <DialogTitle>Unstake Tokens</DialogTitle>
              <DialogDescription className="text-slate-400">
                {selectedPool && `Unstake ${selectedPool.token} tokens from ${selectedPool.name}`}
              </DialogDescription>
            </DialogHeader>
            <div className="space-y-4">
              <div>
                <label className="text-slate-300 text-sm font-medium">Amount to Unstake</label>
                <Input
                  type="number"
                  placeholder="Enter amount"
                  value={unstakeAmount}
                  onChange={(e) => setUnstakeAmount(e.target.value)}
                  className="bg-slate-700 border-slate-600 text-white"
                />
                {selectedPool && (
                  <p className="text-slate-400 text-sm mt-1">
                    Available: {formatTokens(selectedPool.userStaked)} {selectedPool.token}
                  </p>
                )}
              </div>
              <div className="flex justify-end space-x-2">
                <Button variant="outline" onClick={() => setIsUnstakeDialogOpen(false)}>
                  Cancel
                </Button>
                <Button 
                  className="bg-red-600 hover:bg-red-700"
                  onClick={() => selectedPool && handleUnstake(selectedPool.id, unstakeAmount)}
                  disabled={isLoading || !unstakeAmount}
                >
                  {isLoading ? 'Unstaking...' : 'Unstake Tokens'}
                </Button>
              </div>
            </div>
          </DialogContent>
        </Dialog>

        {/* Claim Dialog */}
        <Dialog open={isClaimDialogOpen} onOpenChange={setIsClaimDialogOpen}>
          <DialogContent className="bg-slate-800 border-slate-700 text-white">
            <DialogHeader>
              <DialogTitle>Claim Rewards</DialogTitle>
              <DialogDescription className="text-slate-400">
                {selectedPool && `Claim pending rewards from ${selectedPool.name}`}
              </DialogDescription>
            </DialogHeader>
            <div className="space-y-4">
              {selectedPool && (
                <div className="p-4 bg-slate-700/30 rounded-lg">
                  <div className="text-center">
                    <p className="text-3xl font-bold text-green-400">{formatTokens(selectedPool.pendingRewards)}</p>
                    <p className="text-slate-400">CORE Rewards</p>
                  </div>
                </div>
              )}
              <div className="flex justify-end space-x-2">
                <Button variant="outline" onClick={() => setIsClaimDialogOpen(false)}>
                  Cancel
                </Button>
                <Button 
                  className="bg-green-600 hover:bg-green-700"
                  onClick={() => selectedPool && handleClaimRewards(selectedPool.id)}
                  disabled={isLoading}
                >
                  {isLoading ? 'Claiming...' : 'Claim Rewards'}
                </Button>
              </div>
            </div>
          </DialogContent>
        </Dialog>
      </div>
    </div>
  );
}