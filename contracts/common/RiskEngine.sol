// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title RiskEngine
 * @dev Risk management engine for lending protocol
 */
contract RiskEngine is Ownable {
    using Math for uint256;
    
    struct RiskParameters {
        uint256 collateralFactor; // Basis points
        uint256 liquidationThreshold; // Basis points
        uint256 liquidationPenalty; // Basis points
        uint256 reserveFactor; // Basis points
        bool isActive;
    }
    
    mapping(address => RiskParameters) public assetRiskParams;
    mapping(address => uint256) public assetPrices;
    
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant MAX_COLLATERAL_FACTOR = 9000; // 90%
    uint256 public constant MAX_LIQUIDATION_THRESHOLD = 9500; // 95%
    uint256 public constant MAX_LIQUIDATION_PENALTY = 1500; // 15%
    
    event RiskParametersUpdated(address indexed asset, RiskParameters params);
    event PriceUpdated(address indexed asset, uint256 price);
    
    constructor() Ownable(msg.sender) {}
    
    function setRiskParameters(
        address asset,
        uint256 collateralFactor,
        uint256 liquidationThreshold,
        uint256 liquidationPenalty,
        uint256 reserveFactor
    ) external onlyOwner {
        require(collateralFactor <= MAX_COLLATERAL_FACTOR, "Invalid collateral factor");
        require(liquidationThreshold <= MAX_LIQUIDATION_THRESHOLD, "Invalid liquidation threshold");
        require(liquidationPenalty <= MAX_LIQUIDATION_PENALTY, "Invalid liquidation penalty");
        require(collateralFactor <= liquidationThreshold, "CF must be <= LT");
        
        assetRiskParams[asset] = RiskParameters({
            collateralFactor: collateralFactor,
            liquidationThreshold: liquidationThreshold,
            liquidationPenalty: liquidationPenalty,
            reserveFactor: reserveFactor,
            isActive: true
        });
        
        emit RiskParametersUpdated(asset, assetRiskParams[asset]);
    }
    
    function updatePrice(address asset, uint256 price) external onlyOwner {
        assetPrices[asset] = price;
        emit PriceUpdated(asset, price);
    }
    
    function calculateHealthFactor(
        uint256 totalCollateralETH,
        uint256 totalBorrowsETH,
        uint256 liquidationThreshold
    ) external pure returns (uint256) {
        if (totalBorrowsETH == 0) {
            return type(uint256).max;
        }
        
        return (totalCollateralETH * liquidationThreshold) / (totalBorrowsETH * BASIS_POINTS);
    }
    
    function isLiquidatable(
        uint256 totalCollateralETH,
        uint256 totalBorrowsETH,
        uint256 liquidationThreshold
    ) external pure returns (bool) {
        if (totalBorrowsETH == 0) {
            return false;
        }
        
        uint256 healthFactor = (totalCollateralETH * liquidationThreshold) / (totalBorrowsETH * BASIS_POINTS);
        return healthFactor < 1e18;
    }
    
    function getRiskParameters(address asset) external view returns (RiskParameters memory) {
        return assetRiskParams[asset];
    }
    
    function getAssetPrice(address asset) external view returns (uint256) {
        return assetPrices[asset];
    }
}