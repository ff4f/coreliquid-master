// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title FeeSpreadModel
 * @dev CoreFluid fee spread model that replaces interest-based calculations
 * with fixed markup percentages for asset-backed credit sales
 */
contract FeeSpreadModel is Ownable, ReentrancyGuard {
    
    // Events
    event FeeSpreadUpdated(address indexed asset, uint256 oldSpread, uint256 newSpread);
    event GlobalFeeSpreadUpdated(uint256 oldSpread, uint256 newSpread);
    event AssetRiskFactorUpdated(address indexed asset, uint256 oldFactor, uint256 newFactor);
    
    // Constants
    uint256 public constant MAX_FEE_SPREAD = 5000; // 50% maximum
    uint256 public constant BASIS_POINTS = 10000; // 100%
    
    // State variables
    uint256 public globalBaseFeeSpread; // Global base fee spread in basis points
    
    // Asset-specific fee spreads (basis points)
    mapping(address => uint256) public assetFeeSpread;
    
    // Asset risk factors (basis points) - additional markup for risky assets
    mapping(address => uint256) public assetRiskFactor;
    
    // Supported assets
    mapping(address => bool) public supportedAssets;
    address[] public assetList;
    
    constructor(uint256 _globalBaseFeeSpread) Ownable(msg.sender) {
        require(_globalBaseFeeSpread <= MAX_FEE_SPREAD, "Fee spread too high");
        globalBaseFeeSpread = _globalBaseFeeSpread;
    }
    
    /**
     * @dev Calculate fee spread for a specific asset
     * @param asset The asset address
     * @return feeSpread The calculated fee spread in basis points
     */
    function calculateFeeSpread(address asset) external view returns (uint256 feeSpread) {
        require(supportedAssets[asset], "Asset not supported");
        
        // Base fee spread (asset-specific or global)
        uint256 baseFee = assetFeeSpread[asset] > 0 ? assetFeeSpread[asset] : globalBaseFeeSpread;
        
        // Add risk factor
        uint256 riskFactor = assetRiskFactor[asset];
        
        feeSpread = baseFee + riskFactor;
        
        // Ensure it doesn't exceed maximum
        if (feeSpread > MAX_FEE_SPREAD) {
            feeSpread = MAX_FEE_SPREAD;
        }
        
        return feeSpread;
    }
    
    /**
     * @dev Calculate fixed price for credit sale (principal + markup)
     * @param principal The principal amount
     * @param asset The collateral asset
     * @return totalPrice The total fixed price to be paid
     */
    function calculateFixedPrice(uint256 principal, address asset) external view returns (uint256 totalPrice) {
        uint256 feeSpread = this.calculateFeeSpread(asset);
        uint256 markup = (principal * feeSpread) / BASIS_POINTS;
        return principal + markup;
    }
    
    /**
     * @dev Set fee spread for a specific asset
     * @param asset The asset address
     * @param feeSpread The fee spread in basis points
     */
    function setAssetFeeSpread(address asset, uint256 feeSpread) external onlyOwner {
        require(feeSpread <= MAX_FEE_SPREAD, "Fee spread too high");
        require(supportedAssets[asset], "Asset not supported");
        
        uint256 oldSpread = assetFeeSpread[asset];
        assetFeeSpread[asset] = feeSpread;
        
        emit FeeSpreadUpdated(asset, oldSpread, feeSpread);
    }
    
    /**
     * @dev Set global base fee spread
     * @param feeSpread The global fee spread in basis points
     */
    function setGlobalBaseFeeSpread(uint256 feeSpread) external onlyOwner {
        require(feeSpread <= MAX_FEE_SPREAD, "Fee spread too high");
        
        uint256 oldSpread = globalBaseFeeSpread;
        globalBaseFeeSpread = feeSpread;
        
        emit GlobalFeeSpreadUpdated(oldSpread, feeSpread);
    }
    
    /**
     * @dev Set risk factor for an asset
     * @param asset The asset address
     * @param riskFactor The risk factor in basis points
     */
    function setAssetRiskFactor(address asset, uint256 riskFactor) external onlyOwner {
        require(supportedAssets[asset], "Asset not supported");
        require(riskFactor <= MAX_FEE_SPREAD, "Risk factor too high");
        
        uint256 oldFactor = assetRiskFactor[asset];
        assetRiskFactor[asset] = riskFactor;
        
        emit AssetRiskFactorUpdated(asset, oldFactor, riskFactor);
    }
    
    /**
     * @dev Add a supported asset
     * @param asset The asset address to add
     * @param initialFeeSpread Initial fee spread for this asset
     * @param initialRiskFactor Initial risk factor for this asset
     */
    function addSupportedAsset(
        address asset, 
        uint256 initialFeeSpread, 
        uint256 initialRiskFactor
    ) external onlyOwner {
        require(asset != address(0), "Invalid asset address");
        require(!supportedAssets[asset], "Asset already supported");
        require(initialFeeSpread <= MAX_FEE_SPREAD, "Fee spread too high");
        require(initialRiskFactor <= MAX_FEE_SPREAD, "Risk factor too high");
        
        supportedAssets[asset] = true;
        assetList.push(asset);
        
        if (initialFeeSpread > 0) {
            assetFeeSpread[asset] = initialFeeSpread;
        }
        
        if (initialRiskFactor > 0) {
            assetRiskFactor[asset] = initialRiskFactor;
        }
    }
    
    /**
     * @dev Remove a supported asset
     * @param asset The asset address to remove
     */
    function removeSupportedAsset(address asset) external onlyOwner {
        require(supportedAssets[asset], "Asset not supported");
        
        supportedAssets[asset] = false;
        assetFeeSpread[asset] = 0;
        assetRiskFactor[asset] = 0;
        
        // Remove from asset list
        for (uint256 i = 0; i < assetList.length; i++) {
            if (assetList[i] == asset) {
                assetList[i] = assetList[assetList.length - 1];
                assetList.pop();
                break;
            }
        }
    }
    
    /**
     * @dev Get all supported assets
     * @return assets Array of supported asset addresses
     */
    function getSupportedAssets() external view returns (address[] memory assets) {
        return assetList;
    }
    
    /**
     * @dev Check if an asset is supported
     * @param asset The asset address to check
     * @return supported True if asset is supported
     */
    function isAssetSupported(address asset) external view returns (bool supported) {
        return supportedAssets[asset];
    }
    
    /**
     * @dev Get fee spread details for an asset
     * @param asset The asset address
     * @return baseFee The base fee spread
     * @return riskFactor The risk factor
     * @return totalFee The total calculated fee spread
     */
    function getFeeSpreadDetails(address asset) external view returns (
        uint256 baseFee,
        uint256 riskFactor,
        uint256 totalFee
    ) {
        require(supportedAssets[asset], "Asset not supported");
        
        baseFee = assetFeeSpread[asset] > 0 ? assetFeeSpread[asset] : globalBaseFeeSpread;
        riskFactor = assetRiskFactor[asset];
        totalFee = this.calculateFeeSpread(asset);
        
        return (baseFee, riskFactor, totalFee);
    }
}