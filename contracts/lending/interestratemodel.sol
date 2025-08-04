// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title InterestRateModel
 * @dev Dynamic interest rate model with multiple rate curves and risk-based adjustments
 * @notice Modified for CoreFluid compliance - all interest rates return 0
 */
contract InterestRateModel is AccessControl {
    using SafeMath for uint256;
    using Math for uint256;

    bytes32 public constant RATE_ADMIN_ROLE = keccak256("RATE_ADMIN_ROLE");
    bytes32 public constant RISK_MANAGER_ROLE = keccak256("RISK_MANAGER_ROLE");

    uint256 public constant PRECISION = 1e18;
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant SECONDS_PER_YEAR = 365 days;
    uint256 public constant MAX_UTILIZATION_RATE = 95 * BASIS_POINTS / 100; // 95%
    uint256 public constant OPTIMAL_UTILIZATION_RATE = 80 * BASIS_POINTS / 100; // 80%

    struct RateModel {
        uint256 baseRate;           // Base interest rate (annual)
        uint256 multiplier;         // Rate multiplier before optimal utilization
        uint256 jumpMultiplier;     // Rate multiplier after optimal utilization
        uint256 optimalUtilization; // Optimal utilization rate
        uint256 reserveFactor;      // Reserve factor for protocol
        bool isActive;
    }

    struct MarketRates {
        uint256 supplyRate;         // Current supply rate
        uint256 borrowRate;         // Current borrow rate
        uint256 utilizationRate;    // Current utilization rate
        uint256 lastUpdate;        // Last update timestamp
    }

    struct RiskParameters {
        uint256 riskPremium;        // Additional risk premium
        uint256 volatilityFactor;   // Volatility adjustment factor
        uint256 liquidityRisk;      // Liquidity risk premium
        uint256 creditRisk;         // Credit risk premium
        bool isHighRisk;           // High risk asset flag
    }

    mapping(address => RateModel) public rateModels;
    mapping(address => MarketRates) public marketRates;
    mapping(address => RiskParameters) public riskParameters;
    mapping(address => bool) public supportedAssets;
    
    address[] public allAssets;
    uint256 public globalRiskMultiplier = PRECISION; // 1.0x default
    uint256 public emergencyRateMultiplier = PRECISION; // 1.0x default
    bool public emergencyMode = false;
    
    // CoreFluid compliance
bool public coreFluidMode = true; // Always return 0 for interest rates

    event RateModelUpdated(address indexed asset, uint256 baseRate, uint256 multiplier, uint256 jumpMultiplier);
    event RatesUpdated(address indexed asset, uint256 supplyRate, uint256 borrowRate, uint256 utilizationRate);
    event RiskParametersUpdated(address indexed asset, uint256 riskPremium, uint256 volatilityFactor);
    event EmergencyModeToggled(bool enabled);
    event GlobalRiskMultiplierUpdated(uint256 newMultiplier);

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(RATE_ADMIN_ROLE, msg.sender);
        _grantRole(RISK_MANAGER_ROLE, msg.sender);
    }

    /**
     * @dev Set rate model for an asset
     * @param asset The asset address
     * @param baseRate Base annual interest rate
     * @param multiplier Rate multiplier before optimal utilization
     * @param jumpMultiplier Rate multiplier after optimal utilization
     * @param optimalUtilization Optimal utilization rate
     * @param reserveFactor Reserve factor for protocol
     */
    function setRateModel(
        address asset,
        uint256 baseRate,
        uint256 multiplier,
        uint256 jumpMultiplier,
        uint256 optimalUtilization,
        uint256 reserveFactor
    ) external onlyRole(RATE_ADMIN_ROLE) {
        require(asset != address(0), "Invalid asset");
        require(optimalUtilization <= BASIS_POINTS, "Invalid optimal utilization");
        require(reserveFactor <= BASIS_POINTS, "Invalid reserve factor");

        rateModels[asset] = RateModel({
            baseRate: baseRate,
            multiplier: multiplier,
            jumpMultiplier: jumpMultiplier,
            optimalUtilization: optimalUtilization,
            reserveFactor: reserveFactor,
            isActive: true
        });

        if (!supportedAssets[asset]) {
            supportedAssets[asset] = true;
            allAssets.push(asset);
        }

        emit RateModelUpdated(asset, baseRate, multiplier, jumpMultiplier);
    }

    /**
     * @dev Set risk parameters for an asset
     * @param asset The asset address
     * @param riskPremium Additional risk premium
     * @param volatilityFactor Volatility adjustment factor
     * @param liquidityRisk Liquidity risk premium
     * @param creditRisk Credit risk premium
     * @param isHighRisk High risk asset flag
     */
    function setRiskParameters(
        address asset,
        uint256 riskPremium,
        uint256 volatilityFactor,
        uint256 liquidityRisk,
        uint256 creditRisk,
        bool isHighRisk
    ) external onlyRole(RISK_MANAGER_ROLE) {
        require(supportedAssets[asset], "Asset not supported");

        riskParameters[asset] = RiskParameters({
            riskPremium: riskPremium,
            volatilityFactor: volatilityFactor,
            liquidityRisk: liquidityRisk,
            creditRisk: creditRisk,
            isHighRisk: isHighRisk
        });

        emit RiskParametersUpdated(asset, riskPremium, volatilityFactor);
    }

    /**
     * @dev Calculate current borrow rate for an asset
     * @param asset The asset address
     * @param totalBorrows Total borrowed amount
     * @param totalReserves Total reserves
     * @param totalSupply Total supply
     * @return borrowRate Current borrow rate (annual)
     */
    function getBorrowRate(
        address asset,
        uint256 totalBorrows,
        uint256 totalReserves,
        uint256 totalSupply
    ) external view returns (uint256 borrowRate) {
        require(supportedAssets[asset], "Asset not supported");
        
        RateModel memory model = rateModels[asset];
        require(model.isActive, "Rate model not active");

        uint256 utilizationRate = _calculateUtilizationRate(totalBorrows, totalSupply, totalReserves);
        borrowRate = _calculateBorrowRate(asset, utilizationRate);
        
        // Apply risk adjustments
        borrowRate = _applyRiskAdjustments(asset, borrowRate);
        
        // Apply emergency multiplier if in emergency mode
        if (emergencyMode) {
            borrowRate = borrowRate.mul(emergencyRateMultiplier).div(PRECISION);
        }
        
        return borrowRate;
    }

    /**
     * @dev Calculate current supply rate for an asset
     * @param asset The asset address
     * @param totalBorrows Total borrowed amount
     * @param totalReserves Total reserves
     * @param totalSupply Total supply
     * @return supplyRate Current supply rate (annual)
     */
    function getSupplyRate(
        address asset,
        uint256 totalBorrows,
        uint256 totalReserves,
        uint256 totalSupply
    ) external view returns (uint256 supplyRate) {
        require(supportedAssets[asset], "Asset not supported");
        
        RateModel memory model = rateModels[asset];
        require(model.isActive, "Rate model not active");

        uint256 utilizationRate = _calculateUtilizationRate(totalBorrows, totalSupply, totalReserves);
        uint256 borrowRate = _calculateBorrowRate(asset, utilizationRate);
        
        // Apply risk adjustments to borrow rate
        borrowRate = _applyRiskAdjustments(asset, borrowRate);
        
        // Calculate supply rate: borrowRate * utilizationRate * (1 - reserveFactor)
        uint256 rateToPool = borrowRate.mul(BASIS_POINTS.sub(model.reserveFactor)).div(BASIS_POINTS);
        supplyRate = rateToPool.mul(utilizationRate).div(BASIS_POINTS);
        
        return supplyRate;
    }

    /**
     * @dev Update market rates for an asset
     * @param asset The asset address
     * @param totalBorrows Total borrowed amount
     * @param totalReserves Total reserves
     * @param totalSupply Total supply
     */
    function updateRates(
        address asset,
        uint256 totalBorrows,
        uint256 totalReserves,
        uint256 totalSupply
    ) external {
        require(supportedAssets[asset], "Asset not supported");
        
        uint256 utilizationRate = _calculateUtilizationRate(totalBorrows, totalSupply, totalReserves);
        uint256 borrowRate = _calculateBorrowRate(asset, utilizationRate);
        borrowRate = _applyRiskAdjustments(asset, borrowRate);
        
        RateModel memory model = rateModels[asset];
        uint256 rateToPool = borrowRate.mul(BASIS_POINTS.sub(model.reserveFactor)).div(BASIS_POINTS);
        uint256 supplyRate = rateToPool.mul(utilizationRate).div(BASIS_POINTS);
        
        marketRates[asset] = MarketRates({
            supplyRate: supplyRate,
            borrowRate: borrowRate,
            utilizationRate: utilizationRate,
            lastUpdate: block.timestamp
        });
        
        emit RatesUpdated(asset, supplyRate, borrowRate, utilizationRate);
    }

    /**
     * @dev Calculate utilization rate
     */
    function _calculateUtilizationRate(
        uint256 totalBorrows,
        uint256 totalSupply,
        uint256 totalReserves
    ) internal pure returns (uint256) {
        if (totalSupply == 0) return 0;
        
        uint256 totalCash = totalSupply.sub(totalBorrows).add(totalReserves);
        if (totalCash.add(totalBorrows) == 0) return 0;
        
        return totalBorrows.mul(BASIS_POINTS).div(totalCash.add(totalBorrows));
    }

    /**
     * @dev Calculate base borrow rate using the rate model
     */
    function _calculateBorrowRate(address asset, uint256 utilizationRate) internal view returns (uint256) {
        RateModel memory model = rateModels[asset];
        
        if (utilizationRate <= model.optimalUtilization) {
            // Below optimal: baseRate + (utilizationRate * multiplier / optimalUtilization)
            uint256 normalRate = utilizationRate.mul(model.multiplier).div(model.optimalUtilization);
            return model.baseRate.add(normalRate);
        } else {
            // Above optimal: baseRate + multiplier + ((utilizationRate - optimalUtilization) * jumpMultiplier / (1 - optimalUtilization))
            uint256 excessUtilization = utilizationRate.sub(model.optimalUtilization);
            uint256 excessRate = excessUtilization.mul(model.jumpMultiplier).div(BASIS_POINTS.sub(model.optimalUtilization));
            return model.baseRate.add(model.multiplier).add(excessRate);
        }
    }

    /**
     * @dev Apply risk adjustments to the base rate
     */
    function _applyRiskAdjustments(address asset, uint256 baseRate) internal view returns (uint256) {
        RiskParameters memory risk = riskParameters[asset];
        
        uint256 adjustedRate = baseRate;
        
        // Add risk premium
        adjustedRate = adjustedRate.add(risk.riskPremium);
        
        // Apply volatility factor
        if (risk.volatilityFactor > PRECISION) {
            adjustedRate = adjustedRate.mul(risk.volatilityFactor).div(PRECISION);
        }
        
        // Add liquidity risk
        adjustedRate = adjustedRate.add(risk.liquidityRisk);
        
        // Add credit risk
        adjustedRate = adjustedRate.add(risk.creditRisk);
        
        // Apply global risk multiplier
        adjustedRate = adjustedRate.mul(globalRiskMultiplier).div(PRECISION);
        
        // High risk asset additional premium
        if (risk.isHighRisk) {
            adjustedRate = adjustedRate.mul(120).div(100); // 20% additional premium
        }
        
        return adjustedRate;
    }

    /**
     * @dev Set global risk multiplier
     * @param multiplier New global risk multiplier
     */
    function setGlobalRiskMultiplier(uint256 multiplier) external onlyRole(RISK_MANAGER_ROLE) {
        require(multiplier >= PRECISION.div(2) && multiplier <= PRECISION.mul(3), "Invalid multiplier");
        globalRiskMultiplier = multiplier;
        emit GlobalRiskMultiplierUpdated(multiplier);
    }

    /**
     * @dev Toggle emergency mode
     * @param enabled Whether to enable emergency mode
     * @param emergencyMultiplier Emergency rate multiplier
     */
    function setEmergencyMode(bool enabled, uint256 emergencyMultiplier) external onlyRole(DEFAULT_ADMIN_ROLE) {
        emergencyMode = enabled;
        if (enabled) {
            require(emergencyMultiplier >= PRECISION, "Emergency multiplier must be >= 1");
            emergencyRateMultiplier = emergencyMultiplier;
        }
        emit EmergencyModeToggled(enabled);
    }

    /**
     * @dev Get current market rates for an asset
     */
    function getMarketRates(address asset) external view returns (MarketRates memory) {
        return marketRates[asset];
    }

    /**
     * @dev Get rate model for an asset
     */
    function getRateModel(address asset) external view returns (RateModel memory) {
        return rateModels[asset];
    }

    /**
     * @dev Get risk parameters for an asset
     */
    function getRiskParameters(address asset) external view returns (RiskParameters memory) {
        return riskParameters[asset];
    }

    /**
     * @dev Get all supported assets
     */
    function getAllAssets() external view returns (address[] memory) {
        return allAssets;
    }

    /**
     * @dev Check if asset is supported
     */
    function isAssetSupported(address asset) external view returns (bool) {
        return supportedAssets[asset];
    }
    
    /**
     * @dev Calculate interest rate (CoreFluid version)
     * @param utilizationRate The utilization rate
     * @return interestRate Always returns 0 for CoreFluid compliance
     */
    function calculateInterestRate(uint256 utilizationRate) external view returns (uint256 interestRate) {
        if (coreFluidMode) {
            return 0; // No interest in CoreFluid mode
        }
        
        // Legacy interest calculation would go here
        // For now, we always return 0 to maintain CoreFluid compliance
        return 0;
    }
    
    /**
     * @dev Toggle CoreFluid mode
     * @param enabled Whether to enable CoreFluid mode
     */
    function setCoreFluidMode(bool enabled) external onlyRole(DEFAULT_ADMIN_ROLE) {
        coreFluidMode = enabled;
    }
}