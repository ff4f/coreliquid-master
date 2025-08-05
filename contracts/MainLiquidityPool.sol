// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title MainLiquidityPool
 * @dev Main liquidity pool for DEX functionality
 */
contract MainLiquidityPool is Ownable, ReentrancyGuard {
    mapping(address => uint256) public reserves;
    mapping(address => bool) public supportedTokens;
    
    event LiquidityAdded(address indexed token, uint256 amount);
    event LiquidityRemoved(address indexed token, uint256 amount);
    
    constructor() Ownable(msg.sender) {}
    
    function addLiquidity(address token, uint256 amount) external {
        require(supportedTokens[token], "Token not supported");
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        reserves[token] += amount;
        emit LiquidityAdded(token, amount);
    }
    
    function removeLiquidity(address token, uint256 amount) external onlyOwner {
        require(reserves[token] >= amount, "Insufficient reserves");
        reserves[token] -= amount;
        IERC20(token).transfer(msg.sender, amount);
        emit LiquidityRemoved(token, amount);
    }
    
    function addSupportedToken(address token) external onlyOwner {
        supportedTokens[token] = true;
    }
    
    function getReserve(address token) external view returns (uint256) {
        return reserves[token];
    }
}