// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title ICoreDEX
 * @dev Interface for the CoreDEX contract
 * @author CoreLiquid Protocol
 */
interface ICoreDEX {
    // Structs
    struct TradingPair {
        address tokenA;
        address tokenB;
        uint256 reserveA;
        uint256 reserveB;
        uint256 totalSupply;
        uint256 feeRate;
        uint256 kLast;
        bool isActive;
        uint256 createdAt;
        uint256 lastTradeTimestamp;
        uint256 totalVolume;
        uint256 totalFees;
    }
    
    struct LiquidityPosition {
        uint256 liquidity;
        uint256 token0Owed;
        uint256 token1Owed;
        uint256 feeGrowthInside0LastX128;
        uint256 feeGrowthInside1LastX128;
    }
    
    struct SwapParams {
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 amountOutMin;
        address to;
        uint256 deadline;
        bool useZeroSlippage;
    }
    
    struct AddLiquidityParams {
        address tokenA;
        address tokenB;
        uint256 amountADesired;
        uint256 amountBDesired;
        uint256 amountAMin;
        uint256 amountBMin;
        address to;
        uint256 deadline;
    }
    
    struct RemoveLiquidityParams {
        address tokenA;
        address tokenB;
        uint256 liquidity;
        uint256 amountAMin;
        uint256 amountBMin;
        address to;
        uint256 deadline;
    }
    
    // Events
    event PairCreated(
        address indexed token0,
        address indexed token1,
        bytes32 indexed pairId,
        uint256 timestamp
    );
    
    event LiquidityAdded(
        address indexed provider,
        bytes32 indexed pairId,
        uint256 amountA,
        uint256 amountB,
        uint256 liquidity,
        uint256 timestamp
    );
    
    event LiquidityRemoved(
        address indexed provider,
        bytes32 indexed pairId,
        uint256 amountA,
        uint256 amountB,
        uint256 liquidity,
        uint256 timestamp
    );
    
    event Swap(
        address indexed trader,
        bytes32 indexed pairId,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        uint256 fee,
        bool zeroSlippage,
        uint256 timestamp
    );
    
    event FeesCollected(
        bytes32 indexed pairId,
        uint256 amount0,
        uint256 amount1,
        uint256 timestamp
    );
    
    // Core DEX functions
    function createPair(
        address tokenA,
        address tokenB,
        uint256 feeRate
    ) external returns (bytes32 pairId);
    
    function addLiquidity(
        AddLiquidityParams calldata params
    ) external returns (
        uint256 amountA,
        uint256 amountB,
        uint256 liquidity
    );
    
    function removeLiquidity(
        RemoveLiquidityParams calldata params
    ) external returns (
        uint256 amountA,
        uint256 amountB
    );
    
    function swap(
        SwapParams calldata params
    ) external returns (uint256 amountOut);
    
    // Quote functions
    function getSwapQuote(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external view returns (
        uint256 amountOut,
        uint256 fee,
        uint256 priceImpact,
        bool zeroSlippageAvailable
    );
    
    // View functions
    function getAllPairs() external view returns (bytes32[] memory);
    
    function getAllTokens() external view returns (address[] memory);
    
    function getPairInfo(bytes32 pairId) external view returns (TradingPair memory);
    
    function getLiquidityPosition(address user, bytes32 pairId) external view returns (LiquidityPosition memory);
    
    function getDEXStats() external view returns (
        uint256 totalTradesCount,
        uint256 totalVolumeAmount,
        uint256 totalLiquidityAmount,
        uint256 totalValueLockedAmount,
        uint256 totalPairs
    );
    
    function getPair(address tokenA, address tokenB) external view returns (bytes32);
    
    function isTokenSupported(address token) external view returns (bool);
    
    // Admin functions
    function setDefaultFeeRate(uint256 _feeRate) external;
    
    function setProtocolFeeRate(uint256 _protocolFeeRate) external;
    
    function setFeeRecipient(address _feeRecipient) external;
    
    function collectProtocolFees() external;
    
    function pause() external;
    
    function unpause() external;
}
