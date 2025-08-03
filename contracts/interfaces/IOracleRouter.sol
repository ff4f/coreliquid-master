// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IOracleRouter
 * @dev Interface for the Oracle Router contract
 * @author CoreLiquid Protocol
 */
interface IOracleRouter {
    // Events
    event PriceUpdated(
        address indexed asset,
        uint256 price,
        uint256 timestamp
    );
    
    event OracleAdded(
        address indexed oracle,
        address indexed asset,
        uint256 priority
    );
    
    event OracleRemoved(
        address indexed oracle,
        address indexed asset
    );
    
    event EmergencyPriceSet(
        address indexed asset,
        uint256 price,
        uint256 timestamp
    );

    // Structs
    struct PriceData {
        uint256 price;
        uint256 timestamp;
        uint256 confidence;
        bool isValid;
    }
    
    struct OracleConfig {
        address oracleAddress;
        uint256 priority;
        uint256 maxDelay;
        uint256 minConfidence;
        bool isActive;
    }

    // Core functions
    function getPrice(address asset) external view returns (uint256 price);
    
    function getPriceWithConfidence(address asset) external view returns (
        uint256 price,
        uint256 confidence
    );
    
    function getPriceData(address asset) external view returns (PriceData memory);
    
    function getMultiplePrices(address[] calldata assets) external view returns (
        uint256[] memory prices
    );
    
    function getTWAP(address asset, uint256 period) external view returns (uint256 price);
    
    function getVolatility(address asset, uint256 period) external view returns (uint256 volatility);
    
    // Oracle management
    function addOracle(
        address oracle,
        address asset,
        uint256 priority,
        uint256 maxDelay,
        uint256 minConfidence
    ) external;
    
    function removeOracle(address oracle, address asset) external;
    
    function updateOraclePriority(address oracle, address asset, uint256 newPriority) external;
    
    function pauseOracle(address oracle, address asset) external;
    
    function unpauseOracle(address oracle, address asset) external;
    
    // Emergency functions
    function setEmergencyPrice(address asset, uint256 price) external;
    
    function removeEmergencyPrice(address asset) external;
    
    // View functions
    function isAssetSupported(address asset) external view returns (bool);
    
    function getOracleConfig(address oracle, address asset) external view returns (OracleConfig memory);
    
    function getSupportedAssets() external view returns (address[] memory);
    
    function getActiveOracles(address asset) external view returns (address[] memory);
    
    function isPriceStale(address asset) external view returns (bool);
    
    function getLastUpdateTime(address asset) external view returns (uint256);
    
    // Price validation
    function validatePrice(address asset, uint256 price) external view returns (bool);
    
    function getPriceDeviation(address asset, uint256 referencePrice) external view returns (uint256);
    
    function isWithinDeviationThreshold(address asset, uint256 price) external view returns (bool);
}
