// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "../interfaces/IPriceOracle.sol";

/**
 * @title PriceOracle
 * @dev Advanced price oracle with multiple data sources and volatility tracking
 */
contract PriceOracle is IPriceOracle, AccessControl, ReentrancyGuard, Pausable {
    bytes32 public constant ORACLE_UPDATER_ROLE = keccak256("ORACLE_UPDATER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");

    // Constants
    uint256 public constant PRECISION = 1e18;
    uint256 public constant MAX_PRICE_DEVIATION = 5000; // 50%
    uint256 public constant STALE_PRICE_THRESHOLD = 3600; // 1 hour
    uint256 public constant MIN_PRICE = 1e6; // Minimum price to prevent manipulation
    uint256 public constant MAX_PRICE = 1e30; // Maximum price cap
    uint256 public constant VOLATILITY_WINDOW = 24 hours;
    uint256 public constant MAX_ORACLE_SOURCES = 10;

    // Structs
    struct PriceData {
        uint256 price;
        uint256 timestamp;
        uint256 confidence;
        bool isActive;
        uint256 volatility;
        uint256 volume24h;
    }

    struct OracleSource {
        address oracle;
        uint256 weight;
        bool isActive;
        uint256 lastUpdate;
        string name;
    }

    struct PriceHistory {
        uint256[] prices;
        uint256[] timestamps;
        uint256 currentIndex;
        bool isFull;
    }

    struct VolatilityData {
        uint256 shortTermVol; // 1 hour
        uint256 mediumTermVol; // 6 hours
        uint256 longTermVol; // 24 hours
        uint256 lastCalculated;
    }

    struct MarketData {
        uint256 marketCap;
        uint256 volume24h;
        uint256 circulatingSupply;
        uint256 lastUpdated;
    }

    // Storage
    mapping(address => PriceData) public assetPrices;
    mapping(address => OracleSource[]) public oracleSources;
    mapping(address => PriceHistory) private priceHistory;
    mapping(address => VolatilityData) public volatilityData;
    mapping(address => MarketData) public marketData;
    mapping(address => bool) public supportedAssets;
    mapping(address => uint256) public priceDeviationThreshold;
    mapping(address => uint256) public assetWeights;

    address[] public allAssets;
    uint256 public totalWeight;
    uint256 public priceHistoryLength;
    bool public emergencyMode;
    address public fallbackOracle;

    // Events
    event PriceUpdated(address indexed asset, uint256 oldPrice, uint256 newPrice, uint256 timestamp);
    event OracleSourceAdded(address indexed asset, address indexed oracle, uint256 weight);
    event OracleSourceRemoved(address indexed asset, address indexed oracle);
    event AssetAdded(address indexed asset, uint256 initialPrice);
    event AssetRemoved(address indexed asset);
    event VolatilityCalculated(address indexed asset, uint256 volatility);
    event EmergencyModeToggled(bool enabled);
    event FallbackOracleSet(address indexed oracle);
    event PriceDeviationDetected(address indexed asset, uint256 deviation);

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(ORACLE_UPDATER_ROLE, msg.sender);
        _grantRole(EMERGENCY_ROLE, msg.sender);
        
        priceHistoryLength = 100; // Store last 100 price points
    }

    /**
     * @dev Get current price of an asset
     */
    function getPrice(address asset) external view override returns (uint256, uint256) {
        require(supportedAssets[asset], "Asset not supported");
        
        PriceData memory data = assetPrices[asset];
        require(data.isActive, "Asset price not active");
        require(block.timestamp - data.timestamp <= STALE_PRICE_THRESHOLD, "Price data stale");
        
        return (data.price, data.confidence);
    }

    /**
     * @dev Update price for an asset
     */
    function updatePrice(address asset, uint256 price) external override onlyRole(ORACLE_UPDATER_ROLE) whenNotPaused {
        require(supportedAssets[asset], "Asset not supported");
        require(price >= MIN_PRICE && price <= MAX_PRICE, "Price out of bounds");
        
        uint256 oldPrice = assetPrices[asset].price;
        
        // Check for price deviation
        if (oldPrice > 0) {
            uint256 deviation = _calculateDeviation(oldPrice, price);
            uint256 threshold = priceDeviationThreshold[asset];
            if (threshold == 0) threshold = MAX_PRICE_DEVIATION;
            
            if (deviation > threshold && !emergencyMode) {
                emit PriceDeviationDetected(asset, deviation);
                return; // Reject extreme price changes
            }
        }
        
        // Update price data
        assetPrices[asset] = PriceData({
            price: price,
            timestamp: block.timestamp,
            confidence: _calculateConfidence(asset, price),
            isActive: true,
            volatility: _calculateVolatility(asset, price),
            volume24h: marketData[asset].volume24h
        });
        
        // Update price history
        _updatePriceHistory(asset, price);
        
        emit PriceUpdated(asset, oldPrice, price, block.timestamp);
    }

    /**
     * @dev Get aggregated price from multiple oracle sources
     */
    function getAggregatedPrice(address asset) external view returns (uint256, uint256) {
        require(supportedAssets[asset], "Asset not supported");
        
        OracleSource[] memory sources = oracleSources[asset];
        require(sources.length > 0, "No oracle sources");
        
        uint256 weightedSum = 0;
        uint256 totalActiveWeight = 0;
        uint256 minConfidence = type(uint256).max;
        
        for (uint256 i = 0; i < sources.length; i++) {
            if (sources[i].isActive) {
                try IPriceOracle(sources[i].oracle).getPrice(asset) returns (uint256 price, uint256 confidence) {
                    weightedSum += price * sources[i].weight;
                    totalActiveWeight += sources[i].weight;
                    if (confidence < minConfidence) {
                        minConfidence = confidence;
                    }
                } catch {
                    // Skip failed oracle
                    continue;
                }
            }
        }
        
        require(totalActiveWeight > 0, "No active oracles");
        
        uint256 aggregatedPrice = weightedSum / totalActiveWeight;
        return (aggregatedPrice, minConfidence);
    }

    /**
     * @dev Calculate asset volatility
     */
    function calculateVolatility(address asset) external view returns (uint256) {
        return _calculateCurrentVolatility(asset);
    }

    /**
     * @dev Get price history for an asset
     */
    function getPriceHistory(address asset, uint256 count) external view returns (uint256[] memory prices, uint256[] memory timestamps) {
        PriceHistory storage history = priceHistory[asset];
        
        uint256 length = history.isFull ? priceHistoryLength : history.currentIndex;
        if (count > length) count = length;
        
        prices = new uint256[](count);
        timestamps = new uint256[](count);
        
        for (uint256 i = 0; i < count; i++) {
            uint256 index = (history.currentIndex - 1 - i + priceHistoryLength) % priceHistoryLength;
            prices[i] = history.prices[index];
            timestamps[i] = history.timestamps[index];
        }
    }

    /**
     * @dev Get market data for an asset
     */
    function getMarketData(address asset) external view returns (MarketData memory) {
        return marketData[asset];
    }

    /**
     * @dev Add new asset to oracle
     */
    function addAsset(address asset, uint256 initialPrice, uint256 weight) external onlyRole(ADMIN_ROLE) {
        require(!supportedAssets[asset], "Asset already supported");
        require(initialPrice >= MIN_PRICE && initialPrice <= MAX_PRICE, "Invalid initial price");
        
        supportedAssets[asset] = true;
        assetWeights[asset] = weight;
        totalWeight += weight;
        allAssets.push(asset);
        
        assetPrices[asset] = PriceData({
            price: initialPrice,
            timestamp: block.timestamp,
            confidence: PRECISION,
            isActive: true,
            volatility: 0,
            volume24h: 0
        });
        
        // Initialize price history
        priceHistory[asset].prices = new uint256[](priceHistoryLength);
        priceHistory[asset].timestamps = new uint256[](priceHistoryLength);
        
        emit AssetAdded(asset, initialPrice);
    }

    /**
     * @dev Remove asset from oracle
     */
    function removeAsset(address asset) external onlyRole(ADMIN_ROLE) {
        require(supportedAssets[asset], "Asset not supported");
        
        supportedAssets[asset] = false;
        assetPrices[asset].isActive = false;
        totalWeight -= assetWeights[asset];
        assetWeights[asset] = 0;
        
        // Remove from allAssets array
        for (uint256 i = 0; i < allAssets.length; i++) {
            if (allAssets[i] == asset) {
                allAssets[i] = allAssets[allAssets.length - 1];
                allAssets.pop();
                break;
            }
        }
        
        emit AssetRemoved(asset);
    }

    /**
     * @dev Add oracle source for an asset
     */
    function addOracleSource(address asset, address oracle, uint256 weight, string memory name) external onlyRole(ADMIN_ROLE) {
        require(supportedAssets[asset], "Asset not supported");
        require(oracle != address(0), "Invalid oracle address");
        require(oracleSources[asset].length < MAX_ORACLE_SOURCES, "Too many oracle sources");
        
        oracleSources[asset].push(OracleSource({
            oracle: oracle,
            weight: weight,
            isActive: true,
            lastUpdate: block.timestamp,
            name: name
        }));
        
        emit OracleSourceAdded(asset, oracle, weight);
    }

    /**
     * @dev Remove oracle source
     */
    function removeOracleSource(address asset, address oracle) external onlyRole(ADMIN_ROLE) {
        OracleSource[] storage sources = oracleSources[asset];
        
        for (uint256 i = 0; i < sources.length; i++) {
            if (sources[i].oracle == oracle) {
                sources[i] = sources[sources.length - 1];
                sources.pop();
                emit OracleSourceRemoved(asset, oracle);
                break;
            }
        }
    }

    /**
     * @dev Update market data for an asset
     */
    function updateMarketData(address asset, uint256 marketCap, uint256 volume24h, uint256 circulatingSupply) external onlyRole(ORACLE_UPDATER_ROLE) {
        require(supportedAssets[asset], "Asset not supported");
        
        marketData[asset] = MarketData({
            marketCap: marketCap,
            volume24h: volume24h,
            circulatingSupply: circulatingSupply,
            lastUpdated: block.timestamp
        });
    }

    /**
     * @dev Set price deviation threshold for an asset
     */
    function setPriceDeviationThreshold(address asset, uint256 threshold) external onlyRole(ADMIN_ROLE) {
        require(threshold <= MAX_PRICE_DEVIATION, "Threshold too high");
        priceDeviationThreshold[asset] = threshold;
    }

    /**
     * @dev Toggle emergency mode
     */
    function toggleEmergencyMode() external onlyRole(EMERGENCY_ROLE) {
        emergencyMode = !emergencyMode;
        emit EmergencyModeToggled(emergencyMode);
    }

    /**
     * @dev Set fallback oracle
     */
    function setFallbackOracle(address oracle) external onlyRole(ADMIN_ROLE) {
        fallbackOracle = oracle;
        emit FallbackOracleSet(oracle);
    }

    /**
     * @dev Pause oracle updates
     */
    function pause() external onlyRole(EMERGENCY_ROLE) {
        _pause();
    }

    /**
     * @dev Unpause oracle updates
     */
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    // Internal functions
    function _calculateDeviation(uint256 oldPrice, uint256 newPrice) internal pure returns (uint256) {
        if (oldPrice == 0) return 0;
        
        uint256 diff = oldPrice > newPrice ? oldPrice - newPrice : newPrice - oldPrice;
        return (diff * 10000) / oldPrice; // Return in basis points
    }

    function _calculateConfidence(address asset, uint256 price) internal view returns (uint256) {
        OracleSource[] memory sources = oracleSources[asset];
        if (sources.length == 0) return PRECISION;
        
        uint256 activeCount = 0;
        for (uint256 i = 0; i < sources.length; i++) {
            if (sources[i].isActive) activeCount++;
        }
        
        // Higher confidence with more active sources
        return (PRECISION * activeCount) / sources.length;
    }

    function _calculateVolatility(address asset, uint256 currentPrice) internal view returns (uint256) {
        PriceHistory storage history = priceHistory[asset];
        
        if (!history.isFull && history.currentIndex < 2) {
            return 0;
        }
        
        uint256 length = history.isFull ? priceHistoryLength : history.currentIndex;
        if (length < 2) return 0;
        
        uint256 sum = 0;
        uint256 sumSquares = 0;
        uint256 count = length > 20 ? 20 : length; // Use last 20 prices for volatility
        
        for (uint256 i = 0; i < count; i++) {
            uint256 index = (history.currentIndex - 1 - i + priceHistoryLength) % priceHistoryLength;
            uint256 price = history.prices[index];
            sum += price;
            sumSquares += price * price;
        }
        
        uint256 mean = sum / count;
        uint256 variance = (sumSquares / count) - (mean * mean);
        
        // Return volatility as percentage (scaled by PRECISION)
        return (variance * PRECISION) / (mean * mean);
    }

    function _calculateCurrentVolatility(address asset) internal view returns (uint256) {
        VolatilityData memory volData = volatilityData[asset];
        
        // Return cached volatility if recent
        if (block.timestamp - volData.lastCalculated < 300) { // 5 minutes
            return volData.longTermVol;
        }
        
        return _calculateVolatility(asset, assetPrices[asset].price);
    }

    function _updatePriceHistory(address asset, uint256 price) internal {
        PriceHistory storage history = priceHistory[asset];
        
        history.prices[history.currentIndex] = price;
        history.timestamps[history.currentIndex] = block.timestamp;
        
        history.currentIndex = (history.currentIndex + 1) % priceHistoryLength;
        
        if (history.currentIndex == 0) {
            history.isFull = true;
        }
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
     * @dev Get oracle sources for an asset
     */
    function getOracleSources(address asset) external view returns (OracleSource[] memory) {
        return oracleSources[asset];
    }
}
