// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IPriceOracle
 * @dev Interface for price oracle contracts
 */
interface IPriceOracle {
    struct PriceData {
        uint256 price;
        uint256 timestamp;
        uint256 confidence;
        bool isValid;
    }

    struct OracleSource {
        address oracle;
        uint256 weight;
        bool isActive;
        uint256 lastUpdate;
    }

    /**
     * @dev Get the latest price for an asset
     * @param asset The asset address
     * @return price The latest price
     * @return timestamp The timestamp of the price
     */
    function getPrice(address asset) external view returns (uint256 price, uint256 timestamp);

    /**
     * @dev Get detailed price data for an asset
     * @param asset The asset address
     * @return priceData The detailed price data
     */
    function getPriceData(address asset) external view returns (PriceData memory priceData);

    /**
     * @dev Check if price data is valid and not stale
     * @param asset The asset address
     * @return isValid True if price is valid
     */
    function isPriceValid(address asset) external view returns (bool isValid);

    /**
     * @dev Update price for an asset (only oracle updaters)
     * @param asset The asset address
     * @param price The new price
     * @param confidence The confidence level
     */
    function updatePrice(address asset, uint256 price, uint256 confidence) external;

    /**
     * @dev Add a new oracle source
     * @param asset The asset address
     * @param oracle The oracle address
     * @param weight The weight of this oracle
     */
    function addOracleSource(address asset, address oracle, uint256 weight) external;

    /**
     * @dev Remove an oracle source
     * @param asset The asset address
     * @param oracle The oracle address
     */
    function removeOracleSource(address asset, address oracle) external;

    /**
     * @dev Get all oracle sources for an asset
     * @param asset The asset address
     * @return sources Array of oracle sources
     */
    function getOracleSources(address asset) external view returns (OracleSource[] memory sources);

    // Events
    event PriceUpdated(address indexed asset, uint256 price, uint256 timestamp, uint256 confidence);
    event OracleSourceAdded(address indexed asset, address indexed oracle, uint256 weight);
    event OracleSourceRemoved(address indexed asset, address indexed oracle);
    event PriceValidationFailed(address indexed asset, string reason);
}