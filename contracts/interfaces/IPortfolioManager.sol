// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IPortfolioManager
 * @dev Interface for portfolio management functionality
 */
interface IPortfolioManager {
    struct Portfolio {
        uint256 totalValue;
        uint256 riskScore;
        uint256 lastUpdated;
    }
    
    function getPortfolio(address user) external view returns (Portfolio memory);
    function updatePortfolio(address user) external;
    function calculateRiskScore(address user) external view returns (uint256);
    function rebalancePortfolio(address user) external;
    function getAssetAllocation(address user) external view returns (address[] memory, uint256[] memory);
}