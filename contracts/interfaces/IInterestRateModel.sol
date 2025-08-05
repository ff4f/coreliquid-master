// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IInterestRateModel
 * @dev Interface for interest rate models used in Core protocol lending
 */
interface IInterestRateModel {
    /**
     * @dev Interest rate model parameters
     */
    struct InterestRateParams {
        uint256 baseRate; // Base interest rate (annual)
        uint256 multiplier; // Rate multiplier (slope of interest rate curve)
        uint256 jumpMultiplier; // Jump rate multiplier after optimal utilization
        uint256 kink; // Optimal utilization rate (kink point)
        uint256 reserveFactor; // Reserve factor for protocol reserves
        uint256 maxRate; // Maximum interest rate cap
        bool isActive; // Model active status
    }

    /**
     * @dev Market utilization data
     */
    struct UtilizationData {
        uint256 totalSupply; // Total supplied amount
        uint256 totalBorrows; // Total borrowed amount
        uint256 totalReserves; // Total reserves
        uint256 utilizationRate; // Current utilization rate
        uint256 timestamp; // Last update timestamp
    }

    /**
     * @dev Interest rate calculation result
     */
    struct InterestRates {
        uint256 borrowRate; // Current borrow rate
        uint256 supplyRate; // Current supply rate
        uint256 utilizationRate; // Current utilization rate
        uint256 timestamp; // Calculation timestamp
    }

    /**
     * @dev Events
     */
    event InterestRateModelUpdated(
        address indexed market,
        InterestRateParams params
    );

    event InterestRatesCalculated(
        address indexed market,
        uint256 borrowRate,
        uint256 supplyRate,
        uint256 utilizationRate
    );

    event ParametersUpdated(
        uint256 baseRate,
        uint256 multiplier,
        uint256 jumpMultiplier,
        uint256 kink
    );

    /**
     * @dev Core interest rate calculation functions
     */
    function getBorrowRate(
        uint256 cash,
        uint256 borrows,
        uint256 reserves
    ) external view returns (uint256);

    function getSupplyRate(
        uint256 cash,
        uint256 borrows,
        uint256 reserves,
        uint256 reserveFactorMantissa
    ) external view returns (uint256);

    function getInterestRates(
        uint256 cash,
        uint256 borrows,
        uint256 reserves
    ) external view returns (InterestRates memory);

    /**
     * @dev Utilization rate calculation
     */
    function utilizationRate(
        uint256 cash,
        uint256 borrows,
        uint256 reserves
    ) external pure returns (uint256);

    function getUtilizationData(
        uint256 cash,
        uint256 borrows,
        uint256 reserves
    ) external view returns (UtilizationData memory);

    /**
     * @dev Interest rate model parameters
     */
    function getParameters() external view returns (InterestRateParams memory);

    function setParameters(
        uint256 baseRate,
        uint256 multiplier,
        uint256 jumpMultiplier,
        uint256 kink
    ) external;

    function updateParameters(InterestRateParams calldata params) external;

    /**
     * @dev Rate calculation helpers
     */
    function calculateBorrowRate(uint256 utilizationRate) external view returns (uint256);

    function calculateSupplyRate(
        uint256 borrowRate,
        uint256 utilizationRate,
        uint256 reserveFactor
    ) external pure returns (uint256);

    /**
     * @dev Model configuration
     */
    function baseRatePerYear() external view returns (uint256);

    function multiplierPerYear() external view returns (uint256);

    function jumpMultiplierPerYear() external view returns (uint256);

    function kink() external view returns (uint256);

    function reserveFactor() external view returns (uint256);

    function maxRate() external view returns (uint256);

    /**
     * @dev Rate conversion functions
     */
    function getBlockRate(uint256 annualRate) external view returns (uint256);

    function getAnnualRate(uint256 blockRate) external view returns (uint256);

    function blocksPerYear() external view returns (uint256);

    /**
     * @dev Advanced rate calculations
     */
    function getOptimalUtilizationRate() external view returns (uint256);

    function getExcessUtilizationRate(uint256 utilizationRate) external view returns (uint256);

    function getNormalRate(uint256 utilizationRate) external view returns (uint256);

    function getExcessRate(uint256 utilizationRate) external view returns (uint256);

    /**
     * @dev Rate bounds and validation
     */
    function validateRate(uint256 rate) external view returns (bool);

    function getMinRate() external view returns (uint256);

    function getMaxRate() external view returns (uint256);

    function isRateWithinBounds(uint256 rate) external view returns (bool);

    /**
     * @dev Historical rate functions
     */
    function getHistoricalRate(
        uint256 timestamp,
        uint256 cash,
        uint256 borrows,
        uint256 reserves
    ) external view returns (uint256 borrowRate, uint256 supplyRate);

    function getRateHistory(
        uint256 fromTimestamp,
        uint256 toTimestamp
    ) external view returns (
        uint256[] memory borrowRates,
        uint256[] memory supplyRates,
        uint256[] memory timestamps
    );

    /**
     * @dev Rate prediction functions
     */
    function predictBorrowRate(
        uint256 additionalBorrow,
        uint256 cash,
        uint256 borrows,
        uint256 reserves
    ) external view returns (uint256);

    function predictSupplyRate(
        uint256 additionalSupply,
        uint256 cash,
        uint256 borrows,
        uint256 reserves
    ) external view returns (uint256);

    /**
     * @dev Rate impact analysis
     */
    function getBorrowRateImpact(
        uint256 borrowAmount,
        uint256 cash,
        uint256 borrows,
        uint256 reserves
    ) external view returns (uint256 newRate, uint256 rateChange);

    function getSupplyRateImpact(
        uint256 supplyAmount,
        uint256 cash,
        uint256 borrows,
        uint256 reserves
    ) external view returns (uint256 newRate, uint256 rateChange);

    /**
     * @dev Model type and version
     */
    function modelType() external view returns (string memory);

    function version() external view returns (string memory);

    function isInterestRateModel() external view returns (bool);

    /**
     * @dev Administrative functions
     */
    function owner() external view returns (address);

    function transferOwnership(address newOwner) external;

    function pause() external;

    function unpause() external;

    function paused() external view returns (bool);

    /**
     * @dev Emergency functions
     */
    function setEmergencyRate(uint256 emergencyRate) external;

    function removeEmergencyRate() external;

    function isEmergencyRateSet() external view returns (bool);

    function getEmergencyRate() external view returns (uint256);

    /**
     * @dev Rate smoothing functions
     */
    function enableRateSmoothing(bool enabled) external;

    function isRateSmoothingEnabled() external view returns (bool);

    function getSmoothingFactor() external view returns (uint256);

    function setSmoothingFactor(uint256 factor) external;

    /**
     * @dev Dynamic rate adjustment
     */
    function enableDynamicRates(bool enabled) external;

    function isDynamicRatesEnabled() external view returns (bool);

    function getVolatilityFactor() external view returns (uint256);

    function setVolatilityFactor(uint256 factor) external;

    /**
     * @dev Rate calculation with custom parameters
     */
    function calculateRatesWithParams(
        uint256 cash,
        uint256 borrows,
        uint256 reserves,
        InterestRateParams calldata params
    ) external view returns (InterestRates memory);

    /**
     * @dev Compound interest calculations
     */
    function getCompoundInterest(
        uint256 principal,
        uint256 rate,
        uint256 periods
    ) external pure returns (uint256);

    function getSimpleInterest(
        uint256 principal,
        uint256 rate,
        uint256 periods
    ) external pure returns (uint256);

    /**
     * @dev APY calculations
     */
    function getAPY(uint256 rate) external view returns (uint256);

    function getAPR(uint256 rate) external view returns (uint256);

    function convertAPRtoAPY(uint256 apr) external view returns (uint256);

    function convertAPYtoAPR(uint256 apy) external view returns (uint256);
}