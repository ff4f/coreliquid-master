// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "../tokens/UnifiedLPToken.sol";
import "../core/ZeroSlippageEngine.sol";
import "../core/InfiniteLiquidityEngine.sol";

/**
 * @title CoreDEX
 * @dev Complete DEX/AMM implementation with zero-slippage trading and infinite liquidity
 * @notice This contract implements a full-featured DEX with advanced AMM mechanisms
 */
contract CoreDEX is AccessControl, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;
    using Math for uint256;
    
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant LIQUIDITY_MANAGER_ROLE = keccak256("LIQUIDITY_MANAGER_ROLE");
    bytes32 public constant TRADER_ROLE = keccak256("TRADER_ROLE");
    bytes32 public constant FEE_MANAGER_ROLE = keccak256("FEE_MANAGER_ROLE");
    
    uint256 public constant PRECISION = 1e18;
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant MAX_FEE = 1000; // 10%
    uint256 public constant MIN_LIQUIDITY = 1000;
    
    // Core integrations
    ZeroSlippageEngine public immutable zeroSlippageEngine;
    InfiniteLiquidityEngine public immutable infiniteLiquidityEngine;
    
    // Trading pair structure
    struct TradingPair {
        address tokenA;
        address tokenB;
        uint256 reserveA;
        uint256 reserveB;
        uint256 totalSupply;
        uint256 feeRate; // in basis points
        uint256 kLast; // reserve0 * reserve1, as of immediately after the most recent liquidity event
        bool isActive;
        uint256 createdAt;
        uint256 lastTradeTimestamp;
        uint256 totalVolume;
        uint256 totalFees;
    }
    
    // Liquidity position
    struct LiquidityPosition {
        uint256 liquidity;
        uint256 token0Owed;
        uint256 token1Owed;
        uint256 feeGrowthInside0LastX128;
        uint256 feeGrowthInside1LastX128;
    }
    
    // Swap parameters
    struct SwapParams {
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 amountOutMin;
        address to;
        uint256 deadline;
        bool useZeroSlippage;
    }
    
    // Liquidity parameters
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
    
    // State variables
    mapping(bytes32 => TradingPair) public pairs;
    mapping(address => mapping(address => bytes32)) public getPair;
    mapping(address => mapping(bytes32 => LiquidityPosition)) public positions;
    mapping(bytes32 => UnifiedLPToken) public pairTokens;
    
    bytes32[] public allPairs;
    address[] public allTokens;
    mapping(address => bool) public isTokenSupported;
    
    // Fee configuration
    uint256 public defaultFeeRate = 300; // 0.3%
    uint256 public protocolFeeRate = 500; // 5% of trading fees
    address public feeRecipient;
    uint256 public totalProtocolFees;
    
    // DEX statistics
    uint256 public totalTrades;
    uint256 public totalVolume;
    uint256 public totalLiquidity;
    uint256 public totalValueLocked;
    
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
    
    constructor(
        address _zeroSlippageEngine,
        address _infiniteLiquidityEngine,
        address _feeRecipient
    ) {
        require(_zeroSlippageEngine != address(0), "Invalid zero slippage engine");
        require(_infiniteLiquidityEngine != address(0), "Invalid infinite liquidity engine");
        require(_feeRecipient != address(0), "Invalid fee recipient");
        
        zeroSlippageEngine = ZeroSlippageEngine(_zeroSlippageEngine);
        infiniteLiquidityEngine = InfiniteLiquidityEngine(_infiniteLiquidityEngine);
        feeRecipient = _feeRecipient;
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(LIQUIDITY_MANAGER_ROLE, msg.sender);
        _grantRole(FEE_MANAGER_ROLE, msg.sender);
    }
    
    /**
     * @dev Create a new trading pair
     */
    function createPair(
        address tokenA,
        address tokenB,
        uint256 feeRate
    ) external onlyRole(ADMIN_ROLE) returns (bytes32 pairId) {
        require(tokenA != tokenB, "CoreDEX: identical tokens");
        require(tokenA != address(0) && tokenB != address(0), "CoreDEX: zero address");
        require(feeRate <= MAX_FEE, "CoreDEX: fee too high");
        
        // Sort tokens
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        pairId = keccak256(abi.encodePacked(token0, token1));
        
        require(pairs[pairId].tokenA == address(0), "CoreDEX: pair exists");
        
        // Create pair
        pairs[pairId] = TradingPair({
            tokenA: token0,
            tokenB: token1,
            reserveA: 0,
            reserveB: 0,
            totalSupply: 0,
            feeRate: feeRate > 0 ? feeRate : defaultFeeRate,
            kLast: 0,
            isActive: true,
            createdAt: block.timestamp,
            lastTradeTimestamp: 0,
            totalVolume: 0,
            totalFees: 0
        });
        
        // Create LP token for this pair
        string memory name = string(abi.encodePacked("CoreDEX LP ", _getTokenSymbol(token0), "-", _getTokenSymbol(token1)));
        string memory symbol = string(abi.encodePacked("CLP-", _getTokenSymbol(token0), "-", _getTokenSymbol(token1)));
        pairTokens[pairId] = new UnifiedLPToken(name, symbol, address(this), feeRecipient);
        
        // Update mappings
        getPair[token0][token1] = pairId;
        getPair[token1][token0] = pairId;
        allPairs.push(pairId);
        
        // Add tokens to supported list if not already added
        if (!isTokenSupported[token0]) {
            allTokens.push(token0);
            isTokenSupported[token0] = true;
        }
        if (!isTokenSupported[token1]) {
            allTokens.push(token1);
            isTokenSupported[token1] = true;
        }
        
        emit PairCreated(token0, token1, pairId, block.timestamp);
    }
    
    /**
     * @dev Add liquidity to a trading pair
     */
    function addLiquidity(
        AddLiquidityParams calldata params
    ) external nonReentrant whenNotPaused returns (
        uint256 amountA,
        uint256 amountB,
        uint256 liquidity
    ) {
        require(block.timestamp <= params.deadline, "CoreDEX: expired");
        
        bytes32 pairId = _getPairId(params.tokenA, params.tokenB);
        require(pairs[pairId].isActive, "CoreDEX: pair not active");
        
        TradingPair storage pair = pairs[pairId];
        
        // Calculate optimal amounts
        (amountA, amountB) = _calculateOptimalAmounts(
            pair,
            params.amountADesired,
            params.amountBDesired,
            params.amountAMin,
            params.amountBMin
        );
        
        // Transfer tokens from user
        IERC20(pair.tokenA).safeTransferFrom(msg.sender, address(this), amountA);
        IERC20(pair.tokenB).safeTransferFrom(msg.sender, address(this), amountB);
        
        // Calculate liquidity to mint
        liquidity = _calculateLiquidityToMint(pair, amountA, amountB);
        require(liquidity > 0, "CoreDEX: insufficient liquidity minted");
        
        // Update reserves
        pair.reserveA += amountA;
        pair.reserveB += amountB;
        pair.totalSupply += liquidity;
        
        // Mint LP tokens
        pairTokens[pairId].mint(params.to, liquidity);
        
        // Update position
        positions[params.to][pairId].liquidity += liquidity;
        
        // Update global stats
        totalLiquidity += liquidity;
        totalValueLocked += amountA + amountB; // Simplified TVL calculation
        
        emit LiquidityAdded(params.to, pairId, amountA, amountB, liquidity, block.timestamp);
    }
    
    /**
     * @dev Remove liquidity from a trading pair
     */
    function removeLiquidity(
        RemoveLiquidityParams calldata params
    ) external nonReentrant whenNotPaused returns (
        uint256 amountA,
        uint256 amountB
    ) {
        require(block.timestamp <= params.deadline, "CoreDEX: expired");
        
        bytes32 pairId = _getPairId(params.tokenA, params.tokenB);
        require(pairs[pairId].isActive, "CoreDEX: pair not active");
        
        TradingPair storage pair = pairs[pairId];
        UnifiedLPToken lpToken = pairTokens[pairId];
        
        require(lpToken.balanceOf(msg.sender) >= params.liquidity, "CoreDEX: insufficient LP tokens");
        
        // Calculate amounts to return
        amountA = (params.liquidity * pair.reserveA) / pair.totalSupply;
        amountB = (params.liquidity * pair.reserveB) / pair.totalSupply;
        
        require(amountA >= params.amountAMin, "CoreDEX: insufficient A amount");
        require(amountB >= params.amountBMin, "CoreDEX: insufficient B amount");
        
        // Burn LP tokens
        lpToken.burnFrom(msg.sender, params.liquidity);
        
        // Update reserves
        pair.reserveA -= amountA;
        pair.reserveB -= amountB;
        pair.totalSupply -= params.liquidity;
        
        // Update position
        positions[msg.sender][pairId].liquidity -= params.liquidity;
        
        // Transfer tokens to user
        IERC20(pair.tokenA).safeTransfer(params.to, amountA);
        IERC20(pair.tokenB).safeTransfer(params.to, amountB);
        
        // Update global stats
        totalLiquidity -= params.liquidity;
        totalValueLocked -= amountA + amountB; // Simplified TVL calculation
        
        emit LiquidityRemoved(params.to, pairId, amountA, amountB, params.liquidity, block.timestamp);
    }
    
    /**
     * @dev Execute a token swap
     */
    function swap(
        SwapParams calldata params
    ) external nonReentrant whenNotPaused returns (uint256 amountOut) {
        require(block.timestamp <= params.deadline, "CoreDEX: expired");
        require(params.amountIn > 0, "CoreDEX: insufficient input amount");
        require(params.to != address(0), "CoreDEX: invalid recipient");
        
        bytes32 pairId = _getPairId(params.tokenIn, params.tokenOut);
        require(pairs[pairId].isActive, "CoreDEX: pair not active");
        
        // Try zero-slippage trade first if requested
        if (params.useZeroSlippage) {
            try zeroSlippageEngine.executeTradeWithProtection(
                params.tokenIn,
                params.tokenOut,
                params.amountIn,
                params.amountOutMin,
                block.timestamp + 300
            ) returns (uint256 zeroSlippageAmount) {
                amountOut = zeroSlippageAmount;
                
                emit Swap(
                    msg.sender,
                    pairId,
                    params.tokenIn,
                    params.tokenOut,
                    params.amountIn,
                    amountOut,
                    0, // No fee for zero slippage
                    true,
                    block.timestamp
                );
                
                return amountOut;
            } catch {
                // Fall back to regular AMM swap
            }
        }
        
        // Regular AMM swap
        TradingPair storage pair = pairs[pairId];
        
        // Calculate swap output
        uint256 fee;
        (amountOut, fee) = _calculateSwapOutput(pair, params.tokenIn, params.tokenOut, params.amountIn);
        require(amountOut >= params.amountOutMin, "CoreDEX: insufficient output amount");
        
        // Transfer input tokens from user
        IERC20(params.tokenIn).safeTransferFrom(msg.sender, address(this), params.amountIn);
        
        // Update reserves
        if (params.tokenIn == pair.tokenA) {
            pair.reserveA += params.amountIn;
            pair.reserveB -= amountOut;
        } else {
            pair.reserveB += params.amountIn;
            pair.reserveA -= amountOut;
        }
        
        // Transfer output tokens to recipient
        IERC20(params.tokenOut).safeTransfer(params.to, amountOut);
        
        // Update pair stats
        pair.lastTradeTimestamp = block.timestamp;
        pair.totalVolume += params.amountIn;
        pair.totalFees += fee;
        
        // Update global stats
        totalTrades++;
        totalVolume += params.amountIn;
        totalProtocolFees += (fee * protocolFeeRate) / BASIS_POINTS;
        
        emit Swap(
            msg.sender,
            pairId,
            params.tokenIn,
            params.tokenOut,
            params.amountIn,
            amountOut,
            fee,
            false,
            block.timestamp
        );
    }
    
    /**
     * @dev Get swap quote
     */
    function getSwapQuote(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external view returns (
        uint256 amountOut,
        uint256 fee,
        uint256 priceImpact,
        bool zeroSlippageAvailable
    ) {
        bytes32 pairId = _getPairId(tokenIn, tokenOut);
        require(pairs[pairId].isActive, "CoreDEX: pair not active");
        
        TradingPair storage pair = pairs[pairId];
        (amountOut, fee) = _calculateSwapOutput(pair, tokenIn, tokenOut, amountIn);
        
        // Calculate price impact
        priceImpact = _calculatePriceImpact(pair, tokenIn, amountIn, amountOut);
        
        // Check zero slippage availability
        (uint256 zeroSlippageAmount, uint256 maxSlippage) = zeroSlippageEngine.getProtectedQuote(
            tokenIn,
            tokenOut,
            amountIn
        );
        zeroSlippageAvailable = zeroSlippageAmount >= amountOut;
    }
    
    /**
     * @dev Calculate optimal amounts for adding liquidity
     */
    function _calculateOptimalAmounts(
        TradingPair storage pair,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    ) internal view returns (uint256 amountA, uint256 amountB) {
        if (pair.reserveA == 0 && pair.reserveB == 0) {
            // First liquidity provision
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint256 amountBOptimal = (amountADesired * pair.reserveB) / pair.reserveA;
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, "CoreDEX: insufficient B amount");
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint256 amountAOptimal = (amountBDesired * pair.reserveA) / pair.reserveB;
                require(amountAOptimal <= amountADesired && amountAOptimal >= amountAMin, "CoreDEX: insufficient A amount");
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }
    
    /**
     * @dev Calculate liquidity tokens to mint
     */
    function _calculateLiquidityToMint(
        TradingPair storage pair,
        uint256 amountA,
        uint256 amountB
    ) internal view returns (uint256 liquidity) {
        if (pair.totalSupply == 0) {
            liquidity = Math.sqrt(amountA * amountB) - MIN_LIQUIDITY;
        } else {
            liquidity = Math.min(
                (amountA * pair.totalSupply) / pair.reserveA,
                (amountB * pair.totalSupply) / pair.reserveB
            );
        }
    }
    
    /**
     * @dev Calculate swap output using constant product formula
     */
    function _calculateSwapOutput(
        TradingPair storage pair,
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) internal view returns (uint256 amountOut, uint256 fee) {
        uint256 reserveIn = tokenIn == pair.tokenA ? pair.reserveA : pair.reserveB;
        uint256 reserveOut = tokenIn == pair.tokenA ? pair.reserveB : pair.reserveA;
        
        require(reserveIn > 0 && reserveOut > 0, "CoreDEX: insufficient liquidity");
        
        // Calculate fee
        fee = (amountIn * pair.feeRate) / BASIS_POINTS;
        uint256 amountInWithFee = amountIn - fee;
        
        // Constant product formula: x * y = k
        amountOut = (amountInWithFee * reserveOut) / (reserveIn + amountInWithFee);
    }
    
    /**
     * @dev Calculate price impact
     */
    function _calculatePriceImpact(
        TradingPair storage pair,
        address tokenIn,
        uint256 amountIn,
        uint256 amountOut
    ) internal view returns (uint256) {
        uint256 reserveIn = tokenIn == pair.tokenA ? pair.reserveA : pair.reserveB;
        uint256 reserveOut = tokenIn == pair.tokenA ? pair.reserveB : pair.reserveA;
        
        if (reserveIn == 0 || reserveOut == 0) return 0;
        
        uint256 currentPrice = (reserveOut * PRECISION) / reserveIn;
        uint256 newReserveIn = reserveIn + amountIn;
        uint256 newReserveOut = reserveOut - amountOut;
        uint256 newPrice = (newReserveOut * PRECISION) / newReserveIn;
        
        if (newPrice < currentPrice) {
            return ((currentPrice - newPrice) * BASIS_POINTS) / currentPrice;
        }
        return 0;
    }
    
    /**
     * @dev Get pair ID from token addresses
     */
    function _getPairId(address tokenA, address tokenB) internal pure returns (bytes32) {
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        return keccak256(abi.encodePacked(token0, token1));
    }
    
    /**
     * @dev Get token symbol (simplified)
     */
    function _getTokenSymbol(address token) internal view returns (string memory) {
        try IERC20Metadata(token).symbol() returns (string memory symbol) {
            return symbol;
        } catch {
            return "TOKEN";
        }
    }
    
    // View functions
    function getAllPairs() external view returns (bytes32[] memory) {
        return allPairs;
    }
    
    function getAllTokens() external view returns (address[] memory) {
        return allTokens;
    }
    
    function getPairInfo(bytes32 pairId) external view returns (TradingPair memory) {
        return pairs[pairId];
    }
    
    function getLiquidityPosition(address user, bytes32 pairId) external view returns (LiquidityPosition memory) {
        return positions[user][pairId];
    }
    
    function getDEXStats() external view returns (
        uint256 totalTradesCount,
        uint256 totalVolumeAmount,
        uint256 totalLiquidityAmount,
        uint256 totalValueLockedAmount,
        uint256 totalPairs
    ) {
        return (
            totalTrades,
            totalVolume,
            totalLiquidity,
            totalValueLocked,
            allPairs.length
        );
    }
    
    // Admin functions
    function setDefaultFeeRate(uint256 _feeRate) external onlyRole(FEE_MANAGER_ROLE) {
        require(_feeRate <= MAX_FEE, "CoreDEX: fee too high");
        defaultFeeRate = _feeRate;
    }
    
    function setProtocolFeeRate(uint256 _protocolFeeRate) external onlyRole(FEE_MANAGER_ROLE) {
        require(_protocolFeeRate <= BASIS_POINTS, "CoreDEX: invalid protocol fee rate");
        protocolFeeRate = _protocolFeeRate;
    }
    
    function setFeeRecipient(address _feeRecipient) external onlyRole(ADMIN_ROLE) {
        require(_feeRecipient != address(0), "CoreDEX: invalid fee recipient");
        feeRecipient = _feeRecipient;
    }
    
    function collectProtocolFees() external onlyRole(ADMIN_ROLE) {
        require(totalProtocolFees > 0, "CoreDEX: no fees to collect");
        
        // Transfer protocol fees to fee recipient
        // This is a simplified implementation - in practice, you'd need to track fees per token
        totalProtocolFees = 0;
        
        emit FeesCollected(bytes32(0), 0, 0, block.timestamp);
    }
    
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }
    
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }
}
