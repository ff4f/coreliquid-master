// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title DepositGuard
 * @dev Validates deposits before processing
 */
contract DepositGuard is ReentrancyGuard, Ownable {
    mapping(address => bool) public supportedTokens;
    uint256 public minDepositAmount = 1e6; // 1 USDC minimum
    uint256 public maxDepositAmount = 1000000e6; // 1M USDC maximum
    
    event TokenSupported(address indexed token, bool supported);
    event DepositValidated(address indexed user, address tokenA, address tokenB, uint256 amtA, uint256 amtB);
    
    constructor(address initialOwner) Ownable(initialOwner) {}
    
    function setSupportedToken(address token, bool supported) external onlyOwner {
        supportedTokens[token] = supported;
        emit TokenSupported(token, supported);
    }
    
    function setDepositLimits(uint256 _min, uint256 _max) external onlyOwner {
        require(_min < _max, "Invalid limits");
        minDepositAmount = _min;
        maxDepositAmount = _max;
    }
    
    function validateDeposit(
        address tokenA,
        address tokenB,
        uint256 amtA,
        uint256 amtB
    ) external view returns (bool) {
        require(tokenA != address(0) && tokenB != address(0), "Invalid tokens");
        require(tokenA != tokenB, "Same tokens");
        require(supportedTokens[tokenA] && supportedTokens[tokenB], "Unsupported tokens");
        require(amtA >= minDepositAmount && amtB >= minDepositAmount, "Below minimum");
        require(amtA <= maxDepositAmount && amtB <= maxDepositAmount, "Above maximum");
        
        return true;
    }
    
    function validateSingleDeposit(address token, uint256 amount) external view returns (bool) {
        require(token != address(0), "Invalid token");
        require(supportedTokens[token], "Unsupported token");
        require(amount >= minDepositAmount && amount <= maxDepositAmount, "Invalid amount");
        
        return true;
    }
}
