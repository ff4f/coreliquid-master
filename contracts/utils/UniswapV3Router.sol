// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title UniswapV3Router
 * @dev Router contract for Uniswap V3 integration
 */
contract UniswapV3Router is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    struct SwapParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    struct ExactInputParams {
        bytes path;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
    }

    event SwapExecuted(
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        address indexed recipient
    );

    constructor() Ownable(msg.sender) {}

    /**
     * @dev Execute exact input single swap
     * @param params Swap parameters
     * @return amountOut Amount of tokens received
     */
    function exactInputSingle(SwapParams calldata params)
        external
        payable
        nonReentrant
        returns (uint256 amountOut)
    {
        require(params.deadline >= block.timestamp, "Transaction too old");
        require(params.amountIn > 0, "Invalid amount");

        // Transfer tokens from sender
        IERC20(params.tokenIn).safeTransferFrom(
            msg.sender,
            address(this),
            params.amountIn
        );

        // For demo purposes, return a simulated amount
        // In real implementation, this would interact with Uniswap V3
        amountOut = params.amountIn * 99 / 100; // Simulate 1% slippage
        require(amountOut >= params.amountOutMinimum, "Insufficient output");

        // Transfer output tokens to recipient
        IERC20(params.tokenOut).safeTransfer(params.recipient, amountOut);

        emit SwapExecuted(
            params.tokenIn,
            params.tokenOut,
            params.amountIn,
            amountOut,
            params.recipient
        );
    }

    /**
     * @dev Execute exact input multi-hop swap
     * @param params Swap parameters
     * @return amountOut Amount of tokens received
     */
    function exactInput(ExactInputParams calldata params)
        external
        payable
        nonReentrant
        returns (uint256 amountOut)
    {
        require(params.deadline >= block.timestamp, "Transaction too old");
        require(params.amountIn > 0, "Invalid amount");

        // For demo purposes, return a simulated amount
        amountOut = params.amountIn * 98 / 100; // Simulate 2% slippage for multi-hop
        require(amountOut >= params.amountOutMinimum, "Insufficient output");

        // In real implementation, this would parse the path and execute swaps
        // For now, just return the simulated amount
    }

    /**
     * @dev Get quote for swap
     * @param tokenIn Input token
     * @param tokenOut Output token
     * @param amountIn Input amount
     * @return amountOut Expected output amount
     */
    function getAmountOut(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external pure returns (uint256 amountOut) {
        require(tokenIn != tokenOut, "Same token");
        require(amountIn > 0, "Invalid amount");
        
        // Simulate price calculation
        amountOut = amountIn * 99 / 100;
    }

    /**
     * @dev Emergency withdraw function
     * @param token Token to withdraw
     * @param amount Amount to withdraw
     */
    function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
        IERC20(token).safeTransfer(owner(), amount);
    }
}