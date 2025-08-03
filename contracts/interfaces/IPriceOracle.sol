// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IPriceOracle
 * @dev Interface for price oracle contracts
 */
interface IPriceOracle {
    /**
     * @dev Get the current price of an asset
     * @param asset The address of the asset
     * @return price The current price of the asset
     * @return confidence The confidence level of the price (0-100%)
     */
    function getPrice(address asset) external view returns (uint256 price, uint256 confidence);
    
    /**
     * @dev Update the price of an asset
     * @param asset The address of the asset
     * @param price The new price of the asset
     */
    function updatePrice(address asset, uint256 price) external;
    
    /**
     * @dev Check if an asset is supported by the oracle
     * @param asset The address of the asset
     * @return supported True if the asset is supported
     */
    function isAssetSupported(address asset) external view returns (bool supported);
    
    /**
     * @dev Get aggregated price from multiple oracle sources
     * @param asset The address of the asset
     * @return price The aggregated price
     * @return confidence The aggregated confidence level
     */
    function getAggregatedPrice(address asset) external view returns (uint256 price, uint256 confidence);
    
    /**
     * @dev Calculate volatility for an asset
     * @param asset The address of the asset
     * @return volatility The calculated volatility
     */
    function calculateVolatility(address asset) external view returns (uint256 volatility);
    

}