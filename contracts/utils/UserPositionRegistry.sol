// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../risk/RiskEngine.sol";

contract UserPositionRegistry {
    struct UserPosition {
        uint256 totalDeposits;
        uint256 totalBorrows;
        uint256 lpPositions;
        uint256 vaultAllocations;
        uint256 lastUpdated;
    }
    
    mapping(address => UserPosition) public positions;
    mapping(address => mapping(address => uint256)) public tokenDeposits;
    mapping(address => mapping(address => uint256)) public tokenBorrows;
    
    RiskEngine public immutable riskEngine;
    
    event PositionUpdated(address indexed user, uint256 totalDeposits, uint256 totalBorrows);
    
    constructor(address _riskEngine) {
        riskEngine = RiskEngine(_riskEngine);
    }
    
    function getUserPositions(address user) external view returns (UserPosition memory) {
        return positions[user];
    }
    
    function updateDeposit(address user, address token, uint256 amount, bool isDeposit) external {
        if (isDeposit) {
            tokenDeposits[user][token] += amount;
            positions[user].totalDeposits += amount;
        } else {
            tokenDeposits[user][token] -= amount;
            positions[user].totalDeposits -= amount;
        }
        
        positions[user].lastUpdated = block.timestamp;
        emit PositionUpdated(user, positions[user].totalDeposits, positions[user].totalBorrows);
    }
    
    function updateBorrow(address user, address token, uint256 amount, bool isBorrow) external {
        if (isBorrow) {
            tokenBorrows[user][token] += amount;
            positions[user].totalBorrows += amount;
        } else {
            tokenBorrows[user][token] -= amount;
            positions[user].totalBorrows -= amount;
        }
        
        positions[user].lastUpdated = block.timestamp;
        emit PositionUpdated(user, positions[user].totalDeposits, positions[user].totalBorrows);
    }
    
    function getHealthFactor(address user) external view returns (uint256) {
        return riskEngine.getHealthFactor(user);
    }
    
    function getUserTokenDeposit(address user, address token) external view returns (uint256) {
        return tokenDeposits[user][token];
    }
    
    function getUserTokenBorrow(address user, address token) external view returns (uint256) {
        return tokenBorrows[user][token];
    }
}
