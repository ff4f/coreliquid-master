// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title DynamicInterestRateModel
 * @dev Advanced interest rate model with dynamic adjustments based on utilization and market conditions
 */
contract DynamicInterestRateModel is AccessControl {
    using Math for uint256;
    
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant RATE_MANAGER_ROLE = keccak256("RATE_MANAGER_ROLE");
    
    uint256 public constant PRECISION = 1e18;
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant SECONDS_PER_YEAR = 365 days;
    
    struct RateModel {
        uint256 baseRate; // Base interest rate (annual)
        uint256 multiplier; // Rate multiplier for utilization
        uint256 jumpMultiplier; // Jump rate multiplier after optimal utilization
        uint256 optimalUtilization; // Optimal utilization rate
        uint256 reserveFactor; // Reserve factor for protocol
        uint256 lastUpdateTime;
        bool isActive;
    }
    
    struct MarketConditions {
        uint256 totalSupply;
        uint256 totalBorrow;
        uint256 totalReserves;
        uint256 utilizationRate;
        uint256 supplyRate;
        uint256 borrowRate;
        uint256 lastUpdate;
    }
    
    struct DynamicFactors {
        uint256 volatilityFactor; // Market volatility adjustment
        uint256 liquidityFactor; // Liquidity depth adjustment
        uint256 demandFactor; // Demand pressure adjustment
        uint256 riskFactor; // Risk assessment adjustment
        uint256 lastCalculation;
    }
    
    mapping(address => RateModel) public rateModels;
    mapping(address => MarketConditions) public marketConditions;
    mapping(address => DynamicFactors) public dynamicFactors;
    mapping(address => bool) public supportedAssets;
    
    address[] public assetList;
    
    uint256 public globalRiskMultiplier = PRECISION;
    uint256 public maxBorrowRate = 5000; // 50% max annual rate
    uint256 public updateFrequency = 1 hours;
    
    event RateModelUpdated(address indexed asset, uint256 baseRate, uint256 multiplier, uint256 jumpMultiplier);
    event RatesCalculated(address indexed asset, uint256 supplyRate, uint256 borrowRate, uint256 utilization);
    event DynamicFactorsUpdated(address indexed asset, uint256 volatility, uint256 liquidity, uint256 demand);
    
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(RATE_MANAGER_ROLE, msg.sender);
    }
    
    /**
     * @dev Initialize rate model for an asset
     */
    function initializeRateModel(
        address asset,
        uint256 baseRate,
        uint256 multiplier,
        uint256 jumpMultiplier,
        uint256 optimalUtilization,
        uint256 reserveFactor
    ) external onlyRole(ADMIN_ROLE) {
        require(asset != address(0), "Invalid asset");
        require(baseRate <= maxBorrowRate, "Base rate too high");
        require(optimalUtilization <= PRECISION, "Invalid optimal utilization");
        require(reserveFactor <= BASIS_POINTS, "Invalid reserve factor");
        
        if (!supportedAssets[asset]) {
            supportedAssets[asset] = true;
            assetList.push(asset);
        }
        
        rateModels[asset] = RateModel({
            baseRate: baseRate,
            multiplier: multiplier,
            jumpMultiplier: jumpMultiplier,
            optimalUtilization: optimalUtilization,
            reserveFactor: reserveFactor,
            lastUpdateTime: block.timestamp,
            isActive: true
        });
        
        emit RateModelUpdated(asset, baseRate, multiplier, jumpMultiplier);
    }
    
    /**
     * @dev Calculate current borrow rate for an asset
     */
    function getBorrowRate(
        address asset,
        uint256 totalSupply,
        uint256 totalBorrow,
        uint256 totalReserves
    ) external view returns (uint256) {
        if (!supportedAssets[asset] || !rateModels[asset].isActive) {
            return 0;
        }
        
        uint256 utilizationRate = _calculateUtilizationRate(totalSupply, totalBorrow, totalReserves);
        return _calculateBorrowRate(asset, utilizationRate);
    }
    
    /**
     * @dev Calculate current supply rate for an asset
     */
    function getSupplyRate(
        address asset,
        uint256 totalSupply,
        uint256 totalBorrow,
        uint256 totalReserves
    ) external view returns (uint256) {
        if (!supportedAssets[asset] || !rateModels[asset].isActive) {
            return 0;
        }
        
        uint256 utilizationRate = _calculateUtilizationRate(totalSupply, totalBorrow, totalReserves);
        uint256 borrowRate = _calculateBorrowRate(asset, utilizationRate);
        
        return _calculateSupplyRate(asset, borrowRate, utilizationRate);
    }
    
    /**
     * @dev Update market conditions and recalculate rates
     */
    function updateMarketConditions(
        address asset,
        uint256 totalSupply,
        uint256 totalBorrow,
        uint256 totalReserves
    ) external onlyRole(RATE_MANAGER_ROLE) {
        require(supportedAssets[asset], "Asset not supported");
        
        uint256 utilizationRate = _calculateUtilizationRate(totalSupply, totalBorrow, totalReserves);
        uint256 borrowRate = _calculateBorrowRate(asset, utilizationRate);
        uint256 supplyRate = _calculateSupplyRate(asset, borrowRate, utilizationRate);
        
        marketConditions[asset] = MarketConditions({
            totalSupply: totalSupply,
            totalBorrow: totalBorrow,
            totalReserves: totalReserves,
            utilizationRate: utilizationRate,
            supplyRate: supplyRate,
            borrowRate: borrowRate,
            lastUpdate: block.timestamp
        });
        
        emit RatesCalculated(asset, supplyRate, borrowRate, utilizationRate);
    }
    
    /**
     * @dev Update dynamic factors affecting interest rates
     */
    function updateDynamicFactors(
        address asset,
        uint256 volatilityFactor,
        uint256 liquidityFactor,
        uint256 demandFactor,
        uint256 riskFactor
    ) external onlyRole(RATE_MANAGER_ROLE) {
        require(supportedAssets[asset], "Asset not supported");
        
        dynamicFactors[asset] = DynamicFactors({
            volatilityFactor: volatilityFactor,
            liquidityFactor: liquidityFactor,
            demandFactor: demandFactor,
            riskFactor: riskFactor,
            lastCalculation: block.timestamp
        });
        
        emit DynamicFactorsUpdated(asset, volatilityFactor, liquidityFactor, demandFactor);
    }
    
    /**
     * @dev Calculate utilization rate
     */
    function _calculateUtilizationRate(
        uint256 totalSupply,
        uint256 totalBorrow,
        uint256 totalReserves
    ) internal pure returns (uint256) {
        if (totalSupply == 0) return 0;
        
        uint256 availableLiquidity = totalSupply - totalBorrow - totalReserves;
        if (availableLiquidity == 0) return PRECISION;
        
        return (totalBorrow * PRECISION) / (totalBorrow + availableLiquidity);
    }
    
    /**
     * @dev Calculate borrow rate based on utilization and dynamic factors
     */
    function _calculateBorrowRate(address asset, uint256 utilizationRate) internal view returns (uint256) {
        RateModel memory model = rateModels[asset];
        DynamicFactors memory factors = dynamicFactors[asset];
        
        uint256 baseRate = model.baseRate;
        
        // Apply dynamic factors
        if (factors.lastCalculation > 0) {
            baseRate = (baseRate * factors.volatilityFactor * factors.riskFactor) / (PRECISION * PRECISION);
        }
        
        if (utilizationRate <= model.optimalUtilization) {
            // Normal rate calculation
            uint256 utilizationMultiplier = (utilizationRate * model.multiplier) / model.optimalUtilization;
            return baseRate + utilizationMultiplier;
        } else {
            // Jump rate calculation
            uint256 normalRate = baseRate + model.multiplier;
            uint256 excessUtilization = utilizationRate - model.optimalUtilization;
            uint256 jumpRate = (excessUtilization * model.jumpMultiplier) / (PRECISION - model.optimalUtilization);
            
            uint256 totalRate = normalRate + jumpRate;
            return Math.min(totalRate, maxBorrowRate);
        }
    }
    
    /**
     * @dev Calculate supply rate based on borrow rate and utilization
     */
    function _calculateSupplyRate(
        address asset,
        uint256 borrowRate,
        uint256 utilizationRate
    ) internal view returns (uint256) {
        RateModel memory model = rateModels[asset];
        
        uint256 rateToPool = borrowRate * (BASIS_POINTS - model.reserveFactor) / BASIS_POINTS;
        return (utilizationRate * rateToPool) / PRECISION;
    }
    
    /**
     * @dev Get current market conditions for an asset
     */
    function getMarketConditions(address asset) external view returns (MarketConditions memory) {
        return marketConditions[asset];
    }
    
    /**
     * @dev Get dynamic factors for an asset
     */
    function getDynamicFactors(address asset) external view returns (DynamicFactors memory) {
        return dynamicFactors[asset];
    }
    
    /**
     * @dev Get all supported assets
     */
    function getSupportedAssets() external view returns (address[] memory) {
        return assetList;
    }
    
    /**
     * @dev Update global risk multiplier
     */
    function updateGlobalRiskMultiplier(uint256 newMultiplier) external onlyRole(ADMIN_ROLE) {
        require(newMultiplier > 0 && newMultiplier <= 2 * PRECISION, "Invalid multiplier");
        globalRiskMultiplier = newMultiplier;
    }
    
    /**
     * @dev Emergency pause for rate calculations
     */
    function pauseRateModel(address asset) external onlyRole(ADMIN_ROLE) {
        rateModels[asset].isActive = false;
    }
    
    /**
     * @dev Resume rate calculations
     */
    function resumeRateModel(address asset) external onlyRole(ADMIN_ROLE) {
        rateModels[asset].isActive = true;
    }
}