import { useState, useEffect, useCallback } from 'react';
import { useAccount, useContractRead, useWriteContract } from 'wagmi';
import { parseEther, formatEther } from 'viem';
import { toast } from 'sonner';

interface ConcentratedLiquidityMetrics {
  totalValue: number;
  currentAPR: number;
  efficiency: number;
  inRange: boolean;
  tickLower: number;
  tickUpper: number;
  currentTick: number;
  feesEarned0: number;
  feesEarned1: number;
  impermanentLoss: number;
  capitalEfficiency: number;
}

interface PositionData {
  tokenId: number;
  liquidity: string;
  token0Amount: string;
  token1Amount: string;
  tickLower: number;
  tickUpper: number;
  feeGrowthInside0LastX128: string;
  feeGrowthInside1LastX128: string;
  tokensOwed0: string;
  tokensOwed1: string;
}

interface OptimalRange {
  tickLower: number;
  tickUpper: number;
  expectedAPR: number;
  capitalEfficiency: number;
  riskScore: number;
}

const UNIFIED_LIQUIDITY_POOL_ABI = [
  {
    "inputs": [{ "name": "user", "type": "address" }],
    "name": "getUserPositions",
    "outputs": [{ "name": "", "type": "tuple[]" }],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [{ "name": "poolId", "type": "bytes32" }],
    "name": "rebalance",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "autoRebalanceAll",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  }
];

const RANGE_CALCULATOR_ABI = [
  {
    "inputs": [
      { "name": "token0", "type": "address" },
      { "name": "token1", "type": "address" },
      { "name": "fee", "type": "uint24" }
    ],
    "name": "selectOptimalTicks",
    "outputs": [
      { "name": "tickLower", "type": "int24" },
      { "name": "tickUpper", "type": "int24" }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      { "name": "token0", "type": "address" },
      { "name": "token1", "type": "address" },
      { "name": "fee", "type": "uint24" },
      { "name": "tickLower", "type": "int24" },
      { "name": "tickUpper", "type": "int24" }
    ],
    "name": "calculateCapitalEfficiency",
    "outputs": [{ "name": "", "type": "uint256" }],
    "stateMutability": "view",
    "type": "function"
  }
];

export function useConcentratedLiquidity() {
  const { address, isConnected } = useAccount();
  const [positionData, setPositionData] = useState<PositionData[]>([]);
  const [concentratedLiquidityMetrics, setConcentratedLiquidityMetrics] = useState<ConcentratedLiquidityMetrics | null>(null);
  const [optimalRange, setOptimalRange] = useState<OptimalRange | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const { writeContract } = useWriteContract();

  const unifiedLiquidityPoolAddress = process.env.NEXT_PUBLIC_UNIFIED_LIQUIDITY_POOL_ADDRESS as `0x${string}`;
  const rangeCalculatorAddress = process.env.NEXT_PUBLIC_RANGE_CALCULATOR_ADDRESS as `0x${string}`;

  // Read user positions
  const { data: userPositions, refetch: refetchPositions } = useContractRead({
    address: unifiedLiquidityPoolAddress,
    abi: UNIFIED_LIQUIDITY_POOL_ABI,
    functionName: 'getUserPositions',
    args: address ? [address] : undefined,
    query: {
       enabled: !!address && isConnected
     }
  });

  // Get optimal tick range
  const { data: optimalTicks, refetch: refetchOptimalTicks } = useContractRead({
    address: rangeCalculatorAddress,
    abi: RANGE_CALCULATOR_ABI,
    functionName: 'selectOptimalTicks',
    args: [
      '0x40375C92d9FAf44d2f9db9Bd9ba41a3317a2404f', // USDC on Core
      '0x7448c7456a97769F6cD04F1E83A4a23cCdC46aBD', // WETH on Core
      3000 // 0.3% fee tier
    ],
    query: {
      enabled: isConnected
    }
  });

  const fetchMetrics = useCallback(async () => {
    if (!address || !userPositions) return;

    try {
      setLoading(true);
      
      // Calculate metrics from position data
      const positions = userPositions as any[];
      let totalValue = 0;
      let totalFeesEarned0 = 0;
      let totalFeesEarned1 = 0;
      let inRangePositions = 0;
      
      for (const position of positions) {
        // Calculate position value (simplified)
        const token0Value = parseFloat(formatEther(BigInt(position.token0Amount || '0'))) * 1; // Assume $1 per token0
        const token1Value = parseFloat(formatEther(BigInt(position.token1Amount || '0'))) * 2000; // Assume $2000 per token1
        totalValue += token0Value + token1Value;
        
        totalFeesEarned0 += parseFloat(formatEther(BigInt(position.accumulatedFees0 || '0')));
        totalFeesEarned1 += parseFloat(formatEther(BigInt(position.accumulatedFees1 || '0')));
        
        // Check if position is in range (simplified)
        const currentTick = 0; // Should get from pool
        if (position.tickLower <= currentTick && currentTick <= position.tickUpper) {
          inRangePositions++;
        }
      }
      
      const efficiency = positions.length > 0 ? inRangePositions / positions.length : 0;
      const currentAPR = totalValue > 0 ? ((totalFeesEarned0 + totalFeesEarned1 * 2000) / totalValue) * 365 * 100 : 0;
      
      setConcentratedLiquidityMetrics({
        totalValue,
        currentAPR,
        efficiency,
        inRange: efficiency > 0.8,
        tickLower: positions[0]?.tickLower || 0,
        tickUpper: positions[0]?.tickUpper || 0,
        currentTick: 0, // Should get from pool
        feesEarned0: totalFeesEarned0,
        feesEarned1: totalFeesEarned1,
        impermanentLoss: 0, // Calculate based on price changes
        capitalEfficiency: efficiency * 100
      });
      
      setPositionData(positions.map(p => ({
        tokenId: p.tokenId || 0,
        liquidity: p.liquidity || '0',
        token0Amount: p.token0Amount || '0',
        token1Amount: p.token1Amount || '0',
        tickLower: p.tickLower || 0,
        tickUpper: p.tickUpper || 0,
        feeGrowthInside0LastX128: p.feeGrowthInside0LastX128 || '0',
        feeGrowthInside1LastX128: p.feeGrowthInside1LastX128 || '0',
        tokensOwed0: p.tokensOwed0 || '0',
        tokensOwed1: p.tokensOwed1 || '0'
      })));
      
    } catch (err) {
      console.error('Error fetching metrics:', err);
      setError('Failed to fetch concentrated liquidity metrics');
    } finally {
      setLoading(false);
    }
  }, [address, userPositions]);

  const calculateOptimalRange = useCallback(async () => {
    if (!optimalTicks) return;

    try {
      const [tickLower, tickUpper] = optimalTicks as [number, number];
      
      // Calculate expected metrics for optimal range
      const expectedAPR = 15.5; // Placeholder - should calculate based on historical data
      const capitalEfficiency = 85.2; // Placeholder
      const riskScore = 7.3; // Placeholder
      
      setOptimalRange({
        tickLower,
        tickUpper,
        expectedAPR,
        capitalEfficiency,
        riskScore
      });
    } catch (err) {
      console.error('Error calculating optimal range:', err);
    }
  }, [optimalTicks]);

  const updatePosition = useCallback(async () => {
    if (!writeContract) {
      toast.error('Rebalance function not available');
      return;
    }
    
    try {
      await writeContract({
        address: unifiedLiquidityPoolAddress,
        abi: UNIFIED_LIQUIDITY_POOL_ABI,
        functionName: 'rebalance',
        args: ['0x0000000000000000000000000000000000000000000000000000000000000001'], // Default pool ID
      });
      toast.success('Position rebalanced successfully!');
      refetchPositions();
      fetchMetrics();
    } catch (err) {
      console.error('Error updating position:', err);
      toast.error(`Rebalance failed: ${(err as Error).message}`);
    }
  }, [writeContract, refetchPositions, fetchMetrics]);

  const optimizeRange = useCallback(async () => {
    if (!writeContract) {
      toast.error('Auto-rebalance function not available');
      return;
    }
    
    try {
      await writeContract({
        address: unifiedLiquidityPoolAddress,
        abi: UNIFIED_LIQUIDITY_POOL_ABI,
        functionName: 'autoRebalanceAll',
      });
      toast.success('Auto-rebalance executed successfully!');
      refetchPositions();
      fetchMetrics();
    } catch (err) {
      console.error('Error optimizing range:', err);
      toast.error(`Auto-rebalance failed: ${(err as Error).message}`);
    }
  }, [writeContract, refetchPositions, fetchMetrics]);

  const collectFees = useCallback(async () => {
    // Implementation for collecting fees
    toast.info('Fee collection not yet implemented');
  }, []);

  const adjustRange = useCallback(async (newTickLower: number, newTickUpper: number) => {
    // Implementation for manually adjusting range
    toast.info('Manual range adjustment not yet implemented');
  }, []);

  // Fetch metrics when positions change
  useEffect(() => {
    if (userPositions) {
      fetchMetrics();
    }
  }, [userPositions, fetchMetrics]);

  // Calculate optimal range when ticks are available
  useEffect(() => {
    if (optimalTicks) {
      calculateOptimalRange();
    }
  }, [optimalTicks, calculateOptimalRange]);

  // Refresh data periodically
  useEffect(() => {
    if (!isConnected || !address) return;

    const interval = setInterval(() => {
      refetchPositions();
      refetchOptimalTicks();
    }, 30000); // Refresh every 30 seconds

    return () => clearInterval(interval);
  }, [isConnected, address, refetchPositions, refetchOptimalTicks]);

  return {
    positionData,
    concentratedLiquidityMetrics,
    optimalRange,
    loading,
    error,
    updatePosition,
    optimizeRange,
    collectFees,
    adjustRange,
    refetchData: () => {
      refetchPositions();
      refetchOptimalTicks();
    }
  };
}

export type { ConcentratedLiquidityMetrics, PositionData, OptimalRange };