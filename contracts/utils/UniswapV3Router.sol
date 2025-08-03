// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../interfaces/IUniswapV3Pool.sol";
import "../interfaces/INonfungiblePositionManager.sol";

/**
 * @title UniswapV3Router
 * @dev Router contract for interacting with Uniswap V3
 */
contract UniswapV3Router is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    
    // Uniswap V3 contracts
    INonfungiblePositionManager public immutable positionManager;
    address public immutable factory;
    address public immutable WETH9;
    
    // Events
    event LiquidityAdded(
        uint256 indexed tokenId,
        address indexed token0,
        address indexed token1,
        uint256 amount0,
        uint256 amount1,
        uint256 liquidity
    );
    
    event LiquidityRemoved(
        uint256 indexed tokenId,
        uint256 amount0,
        uint256 amount1
    );
    
    event FeesCollected(
        uint256 indexed tokenId,
        uint256 amount0,
        uint256 amount1
    );
    
    struct MintParams {
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        address recipient;
        uint256 deadline;
    }
    
    struct IncreaseLiquidityParams {
        uint256 tokenId;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        uint256 deadline;
    }
    
    struct DecreaseLiquidityParams {
        uint256 tokenId;
        uint128 liquidity;
        uint256 amount0Min;
        uint256 amount1Min;
        uint256 deadline;
    }
    
    constructor(
        address _positionManager,
        address _factory,
        address _WETH9
    ) Ownable(msg.sender) {
        positionManager = INonfungiblePositionManager(_positionManager);
        factory = _factory;
        WETH9 = _WETH9;
    }
    
    /**
     * @dev Add liquidity to a Uniswap V3 pool
     */
    function addLiquidity(
        MintParams calldata params
    ) external nonReentrant returns (
        uint256 tokenId,
        uint128 liquidity,
        uint256 amount0,
        uint256 amount1
    ) {
        // Transfer tokens from user
        IERC20(params.token0).safeTransferFrom(
            msg.sender,
            address(this),
            params.amount0Desired
        );
        IERC20(params.token1).safeTransferFrom(
            msg.sender,
            address(this),
            params.amount1Desired
        );
        
        // Approve position manager
        IERC20(params.token0).forceApprove(address(positionManager), params.amount0Desired);
        IERC20(params.token1).forceApprove(address(positionManager), params.amount1Desired);
        
        // Mint position
        INonfungiblePositionManager.MintParams memory mintParams = INonfungiblePositionManager.MintParams({
            token0: params.token0,
            token1: params.token1,
            fee: params.fee,
            tickLower: params.tickLower,
            tickUpper: params.tickUpper,
            amount0Desired: params.amount0Desired,
            amount1Desired: params.amount1Desired,
            amount0Min: params.amount0Min,
            amount1Min: params.amount1Min,
            recipient: params.recipient,
            deadline: params.deadline
        });
        
        (tokenId, liquidity, amount0, amount1) = positionManager.mint(mintParams);
        
        // Refund unused tokens
        if (params.amount0Desired > amount0) {
            IERC20(params.token0).safeTransfer(msg.sender, params.amount0Desired - amount0);
        }
        if (params.amount1Desired > amount1) {
            IERC20(params.token1).safeTransfer(msg.sender, params.amount1Desired - amount1);
        }
        
        emit LiquidityAdded(tokenId, params.token0, params.token1, amount0, amount1, liquidity);
    }
    
    /**
     * @dev Increase liquidity in an existing position
     */
    function increaseLiquidity(
        IncreaseLiquidityParams calldata params
    ) external nonReentrant returns (
        uint128 liquidity,
        uint256 amount0,
        uint256 amount1
    ) {
        // Get position info to determine tokens
        (,, address token0, address token1,,,,,,,,) = positionManager.positions(params.tokenId);
        
        // Transfer tokens from user
        IERC20(token0).safeTransferFrom(msg.sender, address(this), params.amount0Desired);
        IERC20(token1).safeTransferFrom(msg.sender, address(this), params.amount1Desired);
        
        // Approve position manager
        IERC20(token0).forceApprove(address(positionManager), params.amount0Desired);
        IERC20(token1).forceApprove(address(positionManager), params.amount1Desired);
        
        // Increase liquidity
        INonfungiblePositionManager.IncreaseLiquidityParams memory increaseParams = 
            INonfungiblePositionManager.IncreaseLiquidityParams({
                tokenId: params.tokenId,
                amount0Desired: params.amount0Desired,
                amount1Desired: params.amount1Desired,
                amount0Min: params.amount0Min,
                amount1Min: params.amount1Min,
                deadline: params.deadline
            });
        
        (liquidity, amount0, amount1) = positionManager.increaseLiquidity(increaseParams);
        
        // Refund unused tokens
        if (params.amount0Desired > amount0) {
            IERC20(token0).safeTransfer(msg.sender, params.amount0Desired - amount0);
        }
        if (params.amount1Desired > amount1) {
            IERC20(token1).safeTransfer(msg.sender, params.amount1Desired - amount1);
        }
    }
    
    /**
     * @dev Decrease liquidity in a position
     */
    function decreaseLiquidity(
        DecreaseLiquidityParams calldata params
    ) external nonReentrant returns (
        uint256 amount0,
        uint256 amount1
    ) {
        INonfungiblePositionManager.DecreaseLiquidityParams memory decreaseParams = 
            INonfungiblePositionManager.DecreaseLiquidityParams({
                tokenId: params.tokenId,
                liquidity: params.liquidity,
                amount0Min: params.amount0Min,
                amount1Min: params.amount1Min,
                deadline: params.deadline
            });
        
        (amount0, amount1) = positionManager.decreaseLiquidity(decreaseParams);
        
        emit LiquidityRemoved(params.tokenId, amount0, amount1);
    }
    
    /**
     * @dev Collect fees from a position
     */
    function collectFees(
        uint256 tokenId,
        address recipient
    ) external nonReentrant returns (
        uint256 amount0,
        uint256 amount1
    ) {
        INonfungiblePositionManager.CollectParams memory collectParams = 
            INonfungiblePositionManager.CollectParams({
                tokenId: tokenId,
                recipient: recipient,
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            });
        
        (amount0, amount1) = positionManager.collect(collectParams);
        
        emit FeesCollected(tokenId, amount0, amount1);
    }
    
    /**
     * @dev Burn a position NFT
     */
    function burnPosition(uint256 tokenId) external nonReentrant {
        positionManager.burn(tokenId);
    }
    
    /**
     * @dev Get pool address for token pair
     */
    function getPool(
        address tokenA,
        address tokenB,
        uint24 fee
    ) external pure returns (address pool) {
        // This would typically call the factory to get pool address
        // For now, return zero address as placeholder
        return address(0);
    }
    
    /**
     * @dev Emergency function to recover stuck tokens
     */
    function emergencyWithdraw(
        address token,
        uint256 amount,
        address to
    ) external onlyOwner {
        IERC20(token).safeTransfer(to, amount);
    }
}
