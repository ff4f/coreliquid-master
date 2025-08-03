// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "../interfaces/ICoreDEX.sol";
import "../core/ZeroSlippageEngine.sol";

/**
 * @title CoreDEXRouter
 * @dev Router contract for CoreDEX with advanced trading features
 * @notice Provides convenient functions for multi-hop swaps, liquidity management, and arbitrage
 */
contract CoreDEXRouter is AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using Math for uint256;
    
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant TRADER_ROLE = keccak256("TRADER_ROLE");
    
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant MAX_SLIPPAGE = 5000; // 50%
    
    ICoreDEX public immutable coreDEX;
    ZeroSlippageEngine public immutable zeroSlippageEngine;
    
    // Multi-hop swap path
    struct SwapPath {
        address[] tokens;
        bytes32[] pairs;
        uint256[] fees;
        bool useZeroSlippage;
    }
    
    // Batch swap parameters
    struct BatchSwapParams {
        SwapPath[] paths;
        uint256[] amountsIn;
        uint256[] amountsOutMin;
        address to;
        uint256 deadline;
    }
    
    // Arbitrage parameters
    struct ArbitrageParams {
        address[] tokens;
        bytes32[] pairs;
        uint256 amountIn;
        uint256 minProfit;
        uint256 deadline;
    }
    
    // Liquidity zap parameters
    struct ZapParams {
        address tokenIn;
        address tokenA;
        address tokenB;
        uint256 amountIn;
        uint256 amountAMin;
        uint256 amountBMin;
        address to;
        uint256 deadline;
    }
    
    // Events
    event MultiHopSwap(
        address indexed trader,
        address[] tokens,
        uint256 amountIn,
        uint256 amountOut,
        uint256 timestamp
    );
    
    event BatchSwapExecuted(
        address indexed trader,
        uint256 pathsCount,
        uint256 totalAmountIn,
        uint256 totalAmountOut,
        uint256 timestamp
    );
    
    event ArbitrageExecuted(
        address indexed trader,
        address[] tokens,
        uint256 amountIn,
        uint256 profit,
        uint256 timestamp
    );
    
    event LiquidityZapped(
        address indexed user,
        address tokenIn,
        bytes32 pairId,
        uint256 amountIn,
        uint256 liquidity,
        uint256 timestamp
    );
    
    constructor(
        address _coreDEX,
        address _zeroSlippageEngine
    ) {
        require(_coreDEX != address(0), "Invalid CoreDEX address");
        require(_zeroSlippageEngine != address(0), "Invalid ZeroSlippageEngine address");
        
        coreDEX = ICoreDEX(_coreDEX);
        zeroSlippageEngine = ZeroSlippageEngine(_zeroSlippageEngine);
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }
    
    /**
     * @dev Execute multi-hop swap
     */
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline,
        bool useZeroSlippage
    ) external nonReentrant returns (uint256[] memory amounts) {
        require(path.length >= 2, "CoreDEXRouter: invalid path");
        require(block.timestamp <= deadline, "CoreDEXRouter: expired");
        
        amounts = new uint256[](path.length);
        amounts[0] = amountIn;
        
        // Transfer input tokens from user
        IERC20(path[0]).safeTransferFrom(msg.sender, address(this), amountIn);
        
        // Execute swaps along the path
        for (uint256 i = 0; i < path.length - 1; i++) {
            address tokenIn = path[i];
            address tokenOut = path[i + 1];
            
            // Approve tokens for CoreDEX
            IERC20(tokenIn).approve(address(coreDEX), amounts[i]);
            
            // Execute swap
            ICoreDEX.SwapParams memory swapParams = ICoreDEX.SwapParams({
                tokenIn: tokenIn,
                tokenOut: tokenOut,
                amountIn: amounts[i],
                amountOutMin: 0, // Will check final amount
                to: i == path.length - 2 ? to : address(this), // Send to recipient on last swap
                deadline: deadline,
                useZeroSlippage: useZeroSlippage
            });
            
            amounts[i + 1] = coreDEX.swap(swapParams);
        }
        
        require(amounts[amounts.length - 1] >= amountOutMin, "CoreDEXRouter: insufficient output amount");
        
        emit MultiHopSwap(msg.sender, path, amountIn, amounts[amounts.length - 1], block.timestamp);
    }
    
    /**
     * @dev Execute batch swaps
     */
    function batchSwap(
        BatchSwapParams calldata params
    ) external nonReentrant returns (uint256[] memory totalAmountsOut) {
        require(block.timestamp <= params.deadline, "CoreDEXRouter: expired");
        require(params.paths.length == params.amountsIn.length, "CoreDEXRouter: length mismatch");
        require(params.paths.length == params.amountsOutMin.length, "CoreDEXRouter: length mismatch");
        
        totalAmountsOut = new uint256[](params.paths.length);
        uint256 totalAmountIn = 0;
        uint256 totalAmountOut = 0;
        
        for (uint256 i = 0; i < params.paths.length; i++) {
            SwapPath memory path = params.paths[i];
            uint256 amountIn = params.amountsIn[i];
            uint256 amountOutMin = params.amountsOutMin[i];
            
            totalAmountIn += amountIn;
            
            // Execute multi-hop swap for this path
            uint256[] memory amounts = _executeSwapPath(path, amountIn, amountOutMin, params.to, params.deadline);
            totalAmountsOut[i] = amounts[amounts.length - 1];
            totalAmountOut += totalAmountsOut[i];
        }
        
        emit BatchSwapExecuted(msg.sender, params.paths.length, totalAmountIn, totalAmountOut, block.timestamp);
    }
    
    /**
     * @dev Execute arbitrage opportunity
     */
    function executeArbitrage(
        ArbitrageParams calldata params
    ) external nonReentrant returns (uint256 profit) {
        require(block.timestamp <= params.deadline, "CoreDEXRouter: expired");
        require(params.tokens.length >= 3, "CoreDEXRouter: invalid arbitrage path");
        
        address startToken = params.tokens[0];
        uint256 startBalance = IERC20(startToken).balanceOf(address(this));
        
        // Transfer input tokens
        IERC20(startToken).safeTransferFrom(msg.sender, address(this), params.amountIn);
        
        uint256 currentAmount = params.amountIn;
        
        // Execute arbitrage swaps
        for (uint256 i = 0; i < params.tokens.length - 1; i++) {
            address tokenIn = params.tokens[i];
            address tokenOut = params.tokens[i + 1];
            
            // Approve tokens for CoreDEX
            IERC20(tokenIn).approve(address(coreDEX), currentAmount);
            
            // Execute swap
            ICoreDEX.SwapParams memory swapParams = ICoreDEX.SwapParams({
                tokenIn: tokenIn,
                tokenOut: tokenOut,
                amountIn: currentAmount,
                amountOutMin: 0,
                to: address(this),
                deadline: params.deadline,
                useZeroSlippage: true // Try zero slippage for arbitrage
            });
            
            currentAmount = coreDEX.swap(swapParams);
        }
        
        // Calculate profit
        require(currentAmount > params.amountIn, "CoreDEXRouter: no arbitrage profit");
        profit = currentAmount - params.amountIn;
        require(profit >= params.minProfit, "CoreDEXRouter: insufficient profit");
        
        // Transfer profit to user
        IERC20(startToken).safeTransfer(msg.sender, currentAmount);
        
        emit ArbitrageExecuted(msg.sender, params.tokens, params.amountIn, profit, block.timestamp);
    }
    
    /**
     * @dev Zap into liquidity pool with single token
     */
    function zapIntoLiquidity(
        ZapParams calldata params
    ) external nonReentrant returns (uint256 liquidity) {
        require(block.timestamp <= params.deadline, "CoreDEXRouter: expired");
        
        // Transfer input tokens
        IERC20(params.tokenIn).safeTransferFrom(msg.sender, address(this), params.amountIn);
        
        uint256 halfAmount = params.amountIn / 2;
        uint256 amountA;
        uint256 amountB;
        
        if (params.tokenIn == params.tokenA) {
            // Swap half to tokenB
            amountA = halfAmount;
            amountB = _swapTokens(params.tokenIn, params.tokenB, halfAmount, 0, params.deadline);
        } else if (params.tokenIn == params.tokenB) {
            // Swap half to tokenA
            amountA = _swapTokens(params.tokenIn, params.tokenA, halfAmount, 0, params.deadline);
            amountB = halfAmount;
        } else {
            // Swap half to each token
            uint256 quarterAmount = params.amountIn / 4;
            amountA = _swapTokens(params.tokenIn, params.tokenA, halfAmount, 0, params.deadline);
            amountB = _swapTokens(params.tokenIn, params.tokenB, halfAmount, 0, params.deadline);
        }
        
        require(amountA >= params.amountAMin, "CoreDEXRouter: insufficient A amount");
        require(amountB >= params.amountBMin, "CoreDEXRouter: insufficient B amount");
        
        // Add liquidity
        IERC20(params.tokenA).approve(address(coreDEX), amountA);
        IERC20(params.tokenB).approve(address(coreDEX), amountB);
        
        ICoreDEX.AddLiquidityParams memory addLiqParams = ICoreDEX.AddLiquidityParams({
            tokenA: params.tokenA,
            tokenB: params.tokenB,
            amountADesired: amountA,
            amountBDesired: amountB,
            amountAMin: params.amountAMin,
            amountBMin: params.amountBMin,
            to: params.to,
            deadline: params.deadline
        });
        
        (uint256 actualAmountA, uint256 actualAmountB, uint256 liquidityMinted) = coreDEX.addLiquidity(addLiqParams);
        
        // Refund unused tokens
        if (amountA > actualAmountA) {
            IERC20(params.tokenA).safeTransfer(params.to, amountA - actualAmountA);
        }
        if (amountB > actualAmountB) {
            IERC20(params.tokenB).safeTransfer(params.to, amountB - actualAmountB);
        }
        
        bytes32 pairId = _getPairId(params.tokenA, params.tokenB);
        emit LiquidityZapped(params.to, params.tokenIn, pairId, params.amountIn, liquidityMinted, block.timestamp);
        
        return liquidityMinted;
    }
    
    /**
     * @dev Get optimal swap path between two tokens
     */
    function getOptimalSwapPath(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external view returns (
        address[] memory path,
        uint256 expectedAmountOut,
        uint256 priceImpact
    ) {
        // Try direct swap first
        bytes32 directPairId = _getPairId(tokenIn, tokenOut);
        
        try coreDEX.getPairInfo(directPairId) returns (ICoreDEX.TradingPair memory pair) {
            if (pair.isActive && pair.reserveA > 0 && pair.reserveB > 0) {
                path = new address[](2);
                path[0] = tokenIn;
                path[1] = tokenOut;
                
                (expectedAmountOut, , priceImpact, ) = coreDEX.getSwapQuote(tokenIn, tokenOut, amountIn);
                return (path, expectedAmountOut, priceImpact);
            }
        } catch {
            // Direct pair doesn't exist, try multi-hop
        }
        
        // Try multi-hop through common tokens (simplified implementation)
        address[] memory commonTokens = _getCommonTokens();
        
        for (uint256 i = 0; i < commonTokens.length; i++) {
            address intermediateToken = commonTokens[i];
            
            if (intermediateToken == tokenIn || intermediateToken == tokenOut) continue;
            
            // Check if both pairs exist
            bytes32 pair1Id = _getPairId(tokenIn, intermediateToken);
            bytes32 pair2Id = _getPairId(intermediateToken, tokenOut);
            
            try coreDEX.getPairInfo(pair1Id) returns (ICoreDEX.TradingPair memory pair1) {
                try coreDEX.getPairInfo(pair2Id) returns (ICoreDEX.TradingPair memory pair2) {
                    if (pair1.isActive && pair2.isActive) {
                        // Calculate multi-hop output
                        (uint256 intermediateAmount, , , ) = coreDEX.getSwapQuote(tokenIn, intermediateToken, amountIn);
                        (uint256 finalAmount, , uint256 totalPriceImpact, ) = coreDEX.getSwapQuote(intermediateToken, tokenOut, intermediateAmount);
                        
                        path = new address[](3);
                        path[0] = tokenIn;
                        path[1] = intermediateToken;
                        path[2] = tokenOut;
                        
                        return (path, finalAmount, totalPriceImpact);
                    }
                } catch {}
            } catch {}
        }
        
        // No path found
        path = new address[](0);
        expectedAmountOut = 0;
        priceImpact = 0;
    }
    
    /**
     * @dev Get price impact for a swap
     */
    function getPriceImpact(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external view returns (uint256 priceImpact) {
        (, , priceImpact, ) = coreDEX.getSwapQuote(tokenIn, tokenOut, amountIn);
    }
    
    /**
     * @dev Check if arbitrage opportunity exists
     */
    function checkArbitrageOpportunity(
        address[] calldata tokens,
        uint256 amountIn
    ) external view returns (
        bool exists,
        uint256 expectedProfit,
        uint256 profitPercentage
    ) {
        if (tokens.length < 3) return (false, 0, 0);
        
        uint256 currentAmount = amountIn;
        
        // Simulate the arbitrage path
        for (uint256 i = 0; i < tokens.length - 1; i++) {
            try coreDEX.getSwapQuote(tokens[i], tokens[i + 1], currentAmount) returns (
                uint256 amountOut,
                uint256,
                uint256,
                bool
            ) {
                currentAmount = amountOut;
            } catch {
                return (false, 0, 0);
            }
        }
        
        if (currentAmount > amountIn) {
            exists = true;
            expectedProfit = currentAmount - amountIn;
            profitPercentage = (expectedProfit * BASIS_POINTS) / amountIn;
        }
    }
    
    /**
     * @dev Internal function to execute swap path
     */
    function _executeSwapPath(
        SwapPath memory path,
        uint256 amountIn,
        uint256 amountOutMin,
        address to,
        uint256 deadline
    ) internal returns (uint256[] memory amounts) {
        amounts = new uint256[](path.tokens.length);
        amounts[0] = amountIn;
        
        // Transfer input tokens
        IERC20(path.tokens[0]).safeTransferFrom(msg.sender, address(this), amountIn);
        
        // Execute swaps
        for (uint256 i = 0; i < path.tokens.length - 1; i++) {
            IERC20(path.tokens[i]).approve(address(coreDEX), amounts[i]);
            
            ICoreDEX.SwapParams memory swapParams = ICoreDEX.SwapParams({
                tokenIn: path.tokens[i],
                tokenOut: path.tokens[i + 1],
                amountIn: amounts[i],
                amountOutMin: 0,
                to: i == path.tokens.length - 2 ? to : address(this),
                deadline: deadline,
                useZeroSlippage: path.useZeroSlippage
            });
            
            amounts[i + 1] = coreDEX.swap(swapParams);
        }
        
        require(amounts[amounts.length - 1] >= amountOutMin, "CoreDEXRouter: insufficient output");
    }
    
    /**
     * @dev Internal function to swap tokens
     */
    function _swapTokens(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMin,
        uint256 deadline
    ) internal returns (uint256 amountOut) {
        IERC20(tokenIn).approve(address(coreDEX), amountIn);
        
        ICoreDEX.SwapParams memory swapParams = ICoreDEX.SwapParams({
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            amountIn: amountIn,
            amountOutMin: amountOutMin,
            to: address(this),
            deadline: deadline,
            useZeroSlippage: false
        });
        
        return coreDEX.swap(swapParams);
    }
    
    /**
     * @dev Get pair ID from token addresses
     */
    function _getPairId(address tokenA, address tokenB) internal pure returns (bytes32) {
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        return keccak256(abi.encodePacked(token0, token1));
    }
    
    /**
     * @dev Get common tokens for routing (simplified)
     */
    function _getCommonTokens() internal view returns (address[] memory) {
        address[] memory tokens = coreDEX.getAllTokens();
        
        // Return first few tokens as common tokens (simplified implementation)
        uint256 maxCommon = tokens.length > 5 ? 5 : tokens.length;
        address[] memory commonTokens = new address[](maxCommon);
        
        for (uint256 i = 0; i < maxCommon; i++) {
            commonTokens[i] = tokens[i];
        }
        
        return commonTokens;
    }
    
    // Emergency functions
    function emergencyWithdraw(address token, uint256 amount) external onlyRole(ADMIN_ROLE) {
        IERC20(token).safeTransfer(msg.sender, amount);
    }
    
    function emergencyWithdrawETH(uint256 amount) external onlyRole(ADMIN_ROLE) {
        payable(msg.sender).transfer(amount);
    }
    
    // Receive ETH
    receive() external payable {}
}
