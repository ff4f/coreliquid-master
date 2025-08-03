// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "../interfaces/IOracle.sol";

/**
 * @title Oracle
 * @dev Comprehensive oracle system for CoreLiquid Protocol
 * @author CoreLiquid Protocol
 */
contract Oracle is IOracle, AccessControl, ReentrancyGuard, Pausable {
    using Math for uint256;

    // Events
    event ValidationConfigUpdated(
        address indexed asset,
        uint256 timestamp
    );
    
    event TWAPUpdated(
        address indexed asset,
        uint256 period,
        uint256 timestamp
    );
    
    event VolatilityUpdated(
        address indexed asset,
        uint256 period,
        uint256 timestamp
    );

    // Roles
    bytes32 public constant ORACLE_MANAGER_ROLE = keccak256("ORACLE_MANAGER_ROLE");
    bytes32 public constant PRICE_FEEDER_ROLE = keccak256("PRICE_FEEDER_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
    bytes32 public constant VALIDATOR_ROLE = keccak256("VALIDATOR_ROLE");

    // Constants
    uint256 public constant PRECISION = 1e18;
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant MAX_PRICE_DEVIATION = 1000; // 10%
    uint256 public constant MIN_UPDATE_INTERVAL = 1 minutes;
    uint256 public constant MAX_UPDATE_INTERVAL = 1 hours;
    uint256 public constant STALE_PRICE_THRESHOLD = 3600; // 1 hour
    uint256 public constant MAX_SOURCES = 10;

    // Storage mappings
    mapping(address => PriceData) public priceData;
    mapping(address => PriceSource[]) public priceSources;
    mapping(address => PriceFeed) public priceFeeds;
    mapping(address => AggregationConfig) public aggregationConfigs;
    mapping(address => ValidationRule[]) public validationRules;
    mapping(address => PriceHistory[]) public priceHistory;
    mapping(address => EmergencyPrice) public emergencyPrices;
    mapping(address => OracleMetrics) public oracleMetrics;
    mapping(address => address[]) public assetSources;
    mapping(bytes32 => PriceUpdate) public priceUpdates;
    
    // Global arrays
    address[] public supportedAssets;
    address[] public activeSources;
    bytes32[] public allPriceUpdates;
    
    // Oracle configuration
    OracleConfig public config;
    
    // Counters
    uint256 public totalPriceUpdates;
    uint256 public totalValidations;
    uint256 public totalEmergencyOverrides;

    // State variables
    bool public emergencyMode;
    uint256 public lastGlobalUpdate;
    mapping(address => uint256) public lastAssetUpdate;
    mapping(address => bool) public isAssetSupported;

    constructor(
        uint256 _maxPriceDeviation,
        uint256 _staleThreshold,
        uint256 _minSources
    ) {
        require(_maxPriceDeviation <= 5000, "Max deviation too high"); // Max 50%
        require(_staleThreshold >= 300, "Stale threshold too low"); // Min 5 minutes
        require(_minSources > 0 && _minSources <= MAX_SOURCES, "Invalid min sources");
        
        config = OracleConfig({
            maxPriceDeviation: _maxPriceDeviation,
            staleThreshold: _staleThreshold,
            minSources: _minSources,
            updateInterval: 300, // 5 minutes
            emergencyThreshold: 2000, // 20%
            validationThreshold: 500, // 5%
            aggregationMethod: AggregationMethod.MEDIAN,
            isActive: true
        });
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ORACLE_MANAGER_ROLE, msg.sender);
        _grantRole(PRICE_FEEDER_ROLE, msg.sender);
        _grantRole(EMERGENCY_ROLE, msg.sender);
        _grantRole(VALIDATOR_ROLE, msg.sender);
    }

    // Core oracle functions
    function updatePrice(
        address asset,
        uint256 price,
        uint256 confidence,
        bytes calldata data
    ) external override onlyRole(PRICE_FEEDER_ROLE) {
        require(asset != address(0), "Invalid asset");
        require(price > 0, "Invalid price");
        require(confidence <= BASIS_POINTS, "Invalid confidence");
        require(isAssetSupported[asset], "Asset not supported");
        
        // Validate price update
        _validatePriceUpdate(asset, price);
        
        // Update price data
        PriceData storage priceInfo = priceData[asset];
        uint256 previousPrice = priceInfo.price;
        
        priceInfo.asset = asset;
        priceInfo.price = price;
        priceInfo.timestamp = block.timestamp;
        priceInfo.confidence = confidence;
        priceInfo.source = msg.sender;
        priceInfo.isValid = true;
        
        // Add to price history
        _addToPriceHistory(asset, price, block.timestamp);
        
        // Update metrics
        _updateOracleMetrics(asset, price, previousPrice);
        
        // Create price update record
        bytes32 updateId = keccak256(abi.encodePacked(asset, price, block.timestamp));
        PriceUpdate storage update = priceUpdates[updateId];
        update.updateId = updateId;
        update.asset = asset;
        update.price = price;
        update.timestamp = block.timestamp;
        update.source = msg.sender;
        update.confidence = confidence;
        update.data = data;
        
        allPriceUpdates.push(updateId);
        totalPriceUpdates++;
        lastAssetUpdate[asset] = block.timestamp;
        lastGlobalUpdate = block.timestamp;
        
        emit PriceUpdated(asset, price, confidence, msg.sender, block.timestamp);
    }

    function batchUpdatePrices(
        address[] calldata assets,
        uint256[] calldata prices,
        uint256[] calldata confidences
    ) external override onlyRole(PRICE_FEEDER_ROLE) {
        require(assets.length == prices.length && prices.length == confidences.length, "Array length mismatch");
        require(assets.length > 0 && assets.length <= 50, "Invalid batch size");
        
        for (uint256 i = 0; i < assets.length; i++) {
            this.updatePrice(assets[i], prices[i], confidences[i], "");
        }
        
        emit BatchPriceUpdated(assets, prices, block.timestamp);
    }

    function getPrice(address asset) external view override returns (uint256) {
        require(asset != address(0), "Invalid asset");
        require(isAssetSupported[asset], "Asset not supported");
        
        PriceData storage priceInfo = priceData[asset];
        require(priceInfo.isValid, "Price not available");
        require(!_isPriceStale(asset), "Price is stale");
        
        return priceInfo.price;
    }

    function getPriceWithTimestamp(address asset) external view override returns (uint256 price, uint256 timestamp) {
        require(asset != address(0), "Invalid asset");
        require(isAssetSupported[asset], "Asset not supported");
        
        PriceData storage priceInfo = priceData[asset];
        require(priceInfo.isValid, "Price not available");
        
        return (priceInfo.price, priceInfo.timestamp);
    }

    function getLatestPrice(address asset) external view override returns (PriceData memory) {
        require(asset != address(0), "Invalid asset");
        require(isAssetSupported[asset], "Asset not supported");
        
        return priceData[asset];
    }

    function validatePrice(
        address asset,
        uint256 price
    ) external override onlyRole(VALIDATOR_ROLE) returns (bool isValid) {
        require(asset != address(0), "Invalid asset");
        require(price > 0, "Invalid price");
        
        isValid = _validatePriceUpdate(asset, price);
        totalValidations++;
        
        emit PriceValidated(asset, price, isValid, msg.sender, block.timestamp);
        
        return isValid;
    }

    function addPriceSource(
        address asset,
        address source,
        uint256 weight,
        SourceType sourceType
    ) external override onlyRole(ORACLE_MANAGER_ROLE) {
        require(asset != address(0), "Invalid asset");
        require(source != address(0), "Invalid source");
        require(weight > 0 && weight <= BASIS_POINTS, "Invalid weight");
        require(priceSources[asset].length < MAX_SOURCES, "Too many sources");
        
        PriceSource memory newSource = PriceSource({
            source: source,
            weight: weight,
            sourceType: sourceType,
            isActive: true,
            lastUpdate: block.timestamp,
            reliability: BASIS_POINTS // 100% initially
        });
        
        priceSources[asset].push(newSource);
        assetSources[asset].push(source);
        
        if (!_isInActiveSources(source)) {
            activeSources.push(source);
        }
        
        emit PriceSourceAdded(asset, source, weight, sourceType, block.timestamp);
    }

    function removePriceSource(
        address asset,
        address source
    ) external override onlyRole(ORACLE_MANAGER_ROLE) {
        require(asset != address(0), "Invalid asset");
        require(source != address(0), "Invalid source");
        
        PriceSource[] storage sources = priceSources[asset];
        for (uint256 i = 0; i < sources.length; i++) {
            if (sources[i].source == source) {
                sources[i] = sources[sources.length - 1];
                sources.pop();
                break;
            }
        }
        
        // Remove from asset sources
        address[] storage assetSourceList = assetSources[asset];
        for (uint256 i = 0; i < assetSourceList.length; i++) {
            if (assetSourceList[i] == source) {
                assetSourceList[i] = assetSourceList[assetSourceList.length - 1];
                assetSourceList.pop();
                break;
            }
        }
        
        emit PriceSourceRemoved(asset, source, block.timestamp);
    }

    function updateAggregationConfig(
        address asset,
        AggregationConfig calldata newConfig
    ) external override onlyRole(ORACLE_MANAGER_ROLE) {
        require(asset != address(0), "Invalid asset");
        require(newConfig.minSources > 0 && newConfig.minSources <= MAX_SOURCES, "Invalid min sources");
        require(newConfig.maxDeviation <= 5000, "Max deviation too high");
        
        aggregationConfigs[asset] = newConfig;
        
        emit AggregationConfigUpdated(asset, block.timestamp);
    }

    function aggregatePrices(
        address asset
    ) external override returns (uint256 aggregatedPrice) {
        require(asset != address(0), "Invalid asset");
        require(isAssetSupported[asset], "Asset not supported");
        
        PriceSource[] storage sources = priceSources[asset];
        require(sources.length >= config.minSources, "Insufficient sources");
        
        AggregationConfig storage aggConfig = aggregationConfigs[asset];
        
        if (aggConfig.method == AggregationMethod.WEIGHTED_AVERAGE) {
            aggregatedPrice = _calculateWeightedAverage(asset);
        } else if (aggConfig.method == AggregationMethod.MEDIAN) {
            aggregatedPrice = _calculateMedian(asset);
        } else {
            aggregatedPrice = _calculateMean(asset);
        }
        
        // Update aggregated price
        this.updatePrice(asset, aggregatedPrice, BASIS_POINTS, abi.encode("aggregated"));
        
        emit PriceAggregated(asset, aggregatedPrice, sources.length, block.timestamp);
        
        return aggregatedPrice;
    }

    function addValidationRule(
        address asset,
        ValidationRule calldata rule
    ) external override onlyRole(ORACLE_MANAGER_ROLE) {
        require(asset != address(0), "Invalid asset");
        
        validationRules[asset].push(rule);
        
        emit ValidationRuleAdded(asset, rule.ruleType, block.timestamp);
    }

    function removeValidationRule(
        address asset,
        uint256 ruleIndex
    ) external override onlyRole(ORACLE_MANAGER_ROLE) {
        require(asset != address(0), "Invalid asset");
        require(ruleIndex < validationRules[asset].length, "Invalid rule index");
        
        ValidationRule[] storage rules = validationRules[asset];
        rules[ruleIndex] = rules[rules.length - 1];
        rules.pop();
        
        emit ValidationRuleRemoved(asset, ruleIndex, block.timestamp);
    }

    // Emergency functions
    function setEmergencyPrice(
        address asset,
        uint256 price,
        string calldata reason
    ) external override onlyRole(EMERGENCY_ROLE) {
        require(asset != address(0), "Invalid asset");
        require(price > 0, "Invalid price");
        
        EmergencyPrice storage emergencyPrice = emergencyPrices[asset];
        emergencyPrice.asset = asset;
        emergencyPrice.price = price;
        emergencyPrice.timestamp = block.timestamp;
        emergencyPrice.reason = reason;
        emergencyPrice.isActive = true;
        emergencyPrice.setBy = msg.sender;
        
        // Override current price
        PriceData storage priceInfo = priceData[asset];
        priceInfo.price = price;
        priceInfo.timestamp = block.timestamp;
        priceInfo.source = msg.sender;
        priceInfo.isValid = true;
        
        totalEmergencyOverrides++;
        
        emit EmergencyPriceSet(asset, price, reason, msg.sender, block.timestamp);
    }

    function clearEmergencyPrice(
        address asset
    ) external override onlyRole(EMERGENCY_ROLE) {
        require(asset != address(0), "Invalid asset");
        require(emergencyPrices[asset].isActive, "No active emergency price");
        
        emergencyPrices[asset].isActive = false;
        emergencyPrices[asset].clearedAt = block.timestamp;
        
        emit EmergencyPriceCleared(asset, block.timestamp);
    }

    function pauseOracle() external override onlyRole(EMERGENCY_ROLE) {
        _pause();
    }

    function enableEmergencyMode() external onlyRole(EMERGENCY_ROLE) {
        emergencyMode = true;
        _pause();
        
        emit EmergencyModeEnabled(block.timestamp);
    }

    function disableEmergencyMode() external onlyRole(EMERGENCY_ROLE) {
        emergencyMode = false;
        _unpause();
        
        emit EmergencyModeDisabled(block.timestamp);
    }

    // Configuration functions
    function updateOracleConfig(
        OracleConfig calldata newConfig
    ) external onlyRole(ORACLE_MANAGER_ROLE) {
        require(newConfig.maxPriceDeviation <= 5000, "Max deviation too high");
        require(newConfig.staleThreshold >= 300, "Stale threshold too low");
        require(newConfig.minSources > 0 && newConfig.minSources <= MAX_SOURCES, "Invalid min sources");
        
        config = newConfig;
        
        emit OracleConfigUpdated(block.timestamp);
    }

    function addSupportedAsset(
        address asset
    ) external onlyRole(ORACLE_MANAGER_ROLE) {
        require(asset != address(0), "Invalid asset");
        require(!isAssetSupported[asset], "Asset already supported");
        
        isAssetSupported[asset] = true;
        supportedAssets.push(asset);
        
        // Initialize aggregation config
        aggregationConfigs[asset] = AggregationConfig({
            method: AggregationMethod.MEDIAN,
            minSources: config.minSources,
            maxDeviation: config.maxPriceDeviation,
            isActive: true
        });
        
        emit AssetAdded(asset, block.timestamp);
    }

    function removeSupportedAsset(
        address asset
    ) external onlyRole(ORACLE_MANAGER_ROLE) {
        require(asset != address(0), "Invalid asset");
        require(isAssetSupported[asset], "Asset not supported");
        
        isAssetSupported[asset] = false;
        
        // Remove from supported assets array
        for (uint256 i = 0; i < supportedAssets.length; i++) {
            if (supportedAssets[i] == asset) {
                supportedAssets[i] = supportedAssets[supportedAssets.length - 1];
                supportedAssets.pop();
                break;
            }
        }
        
        emit AssetRemoved(asset, block.timestamp);
    }

    // View functions
    function getPriceData(address asset) external view override returns (PriceData memory) {
        return priceData[asset];
    }

    function getPriceSources(address asset) external view override returns (PriceSource[] memory) {
        return priceSources[asset];
    }

    function getPriceFeed(address asset) external view override returns (PriceFeed memory) {
        return priceFeeds[asset];
    }

    function getAggregationConfig(address asset) external view override returns (AggregationConfig memory) {
        return aggregationConfigs[asset];
    }

    function getValidationRules(address asset) external view override returns (ValidationRule[] memory) {
        return validationRules[asset];
    }

    function getPriceHistory(address asset) external view override returns (PriceHistory[] memory) {
        return priceHistory[asset];
    }

    function getEmergencyPrice(address asset) external view override returns (EmergencyPrice memory) {
        return emergencyPrices[asset];
    }

    function getOracleMetrics(address asset) external view override returns (OracleMetrics memory) {
        return oracleMetrics[asset];
    }

    function getOracleConfig() external view override returns (OracleConfig memory) {
        return config;
    }

    function getSupportedAssets() external view override returns (address[] memory) {
        return supportedAssets;
    }

    function getActiveSources() external view override returns (address[] memory) {
        return activeSources;
    }

    function isPriceStale(address asset) external view override returns (bool) {
        return _isPriceStale(asset);
    }

    function getSystemMetrics() external view override returns (SystemMetrics memory) {
        return SystemMetrics({
            totalAssets: supportedAssets.length,
            totalSources: activeSources.length,
            totalUpdates: totalPriceUpdates,
            totalValidations: totalValidations,
            emergencyOverrides: totalEmergencyOverrides,
            lastGlobalUpdate: lastGlobalUpdate,
            systemHealth: _calculateSystemHealth(),
            averageConfidence: _calculateAverageConfidence()
        });
    }

    // Internal functions
    function _validatePriceUpdate(address asset, uint256 price) internal view returns (bool) {
        // Check if price deviates too much from current price
        PriceData storage currentPrice = priceData[asset];
        if (currentPrice.price > 0) {
            uint256 deviation = price > currentPrice.price 
                ? ((price - currentPrice.price) * BASIS_POINTS) / currentPrice.price
                : ((currentPrice.price - price) * BASIS_POINTS) / currentPrice.price;
            
            if (deviation > config.maxPriceDeviation) {
                return false;
            }
        }
        
        // Apply validation rules
        ValidationRule[] storage rules = validationRules[asset];
        for (uint256 i = 0; i < rules.length; i++) {
            if (!_applyValidationRule(asset, price, rules[i])) {
                return false;
            }
        }
        
        return true;
    }

    function _applyValidationRule(
        address asset,
        uint256 price,
        ValidationRule memory rule
    ) internal view returns (bool) {
        if (rule.ruleType == ValidationType.MIN_PRICE) {
            return price >= rule.threshold;
        } else if (rule.ruleType == ValidationType.MAX_PRICE) {
            return price <= rule.threshold;
        } else if (rule.ruleType == ValidationType.MAX_DEVIATION) {
            PriceData storage currentPrice = priceData[asset];
            if (currentPrice.price > 0) {
                uint256 deviation = price > currentPrice.price 
                    ? ((price - currentPrice.price) * BASIS_POINTS) / currentPrice.price
                    : ((currentPrice.price - price) * BASIS_POINTS) / currentPrice.price;
                return deviation <= rule.threshold;
            }
        }
        
        return true;
    }

    function _addToPriceHistory(address asset, uint256 price, uint256 timestamp) internal {
        PriceHistory[] storage history = priceHistory[asset];
        
        // Keep only last 100 entries
        if (history.length >= 100) {
            for (uint256 i = 0; i < history.length - 1; i++) {
                history[i] = history[i + 1];
            }
            history.pop();
        }
        
        history.push(PriceHistory({
            price: price,
            timestamp: timestamp,
            blockNumber: block.number
        }));
    }

    function _updateOracleMetrics(address asset, uint256 newPrice, uint256 previousPrice) internal {
        OracleMetrics storage metrics = oracleMetrics[asset];
        metrics.asset = asset;
        metrics.totalUpdates++;
        metrics.lastUpdate = block.timestamp;
        
        if (previousPrice > 0) {
            uint256 deviation = newPrice > previousPrice 
                ? ((newPrice - previousPrice) * BASIS_POINTS) / previousPrice
                : ((previousPrice - newPrice) * BASIS_POINTS) / previousPrice;
            
            metrics.averageDeviation = (metrics.averageDeviation + deviation) / 2;
            metrics.maxDeviation = Math.max(metrics.maxDeviation, deviation);
        }
        
        metrics.reliability = _calculateReliability(asset);
    }

    function _calculateWeightedAverage(address asset) internal view returns (uint256) {
        PriceSource[] storage sources = priceSources[asset];
        uint256 weightedSum = 0;
        uint256 totalWeight = 0;
        
        for (uint256 i = 0; i < sources.length; i++) {
            if (sources[i].isActive) {
                PriceData storage sourcePrice = priceData[sources[i].source];
                if (sourcePrice.isValid && !_isPriceStale(sources[i].source)) {
                    weightedSum += sourcePrice.price * sources[i].weight;
                    totalWeight += sources[i].weight;
                }
            }
        }
        
        return totalWeight > 0 ? weightedSum / totalWeight : 0;
    }

    function _calculateMedian(address asset) internal view returns (uint256) {
        PriceSource[] storage sources = priceSources[asset];
        uint256[] memory prices = new uint256[](sources.length);
        uint256 validPrices = 0;
        
        for (uint256 i = 0; i < sources.length; i++) {
            if (sources[i].isActive) {
                PriceData storage sourcePrice = priceData[sources[i].source];
                if (sourcePrice.isValid && !_isPriceStale(sources[i].source)) {
                    prices[validPrices] = sourcePrice.price;
                    validPrices++;
                }
            }
        }
        
        if (validPrices == 0) return 0;
        
        // Sort prices
        for (uint256 i = 0; i < validPrices - 1; i++) {
            for (uint256 j = 0; j < validPrices - i - 1; j++) {
                if (prices[j] > prices[j + 1]) {
                    uint256 temp = prices[j];
                    prices[j] = prices[j + 1];
                    prices[j + 1] = temp;
                }
            }
        }
        
        // Return median
        if (validPrices % 2 == 0) {
            return (prices[validPrices / 2 - 1] + prices[validPrices / 2]) / 2;
        } else {
            return prices[validPrices / 2];
        }
    }

    function _calculateMean(address asset) internal view returns (uint256) {
        PriceSource[] storage sources = priceSources[asset];
        uint256 sum = 0;
        uint256 validPrices = 0;
        
        for (uint256 i = 0; i < sources.length; i++) {
            if (sources[i].isActive) {
                PriceData storage sourcePrice = priceData[sources[i].source];
                if (sourcePrice.isValid && !_isPriceStale(sources[i].source)) {
                    sum += sourcePrice.price;
                    validPrices++;
                }
            }
        }
        
        return validPrices > 0 ? sum / validPrices : 0;
    }

    function _isPriceStale(address asset) internal view returns (bool) {
        PriceData storage priceInfo = priceData[asset];
        return block.timestamp - priceInfo.timestamp > config.staleThreshold;
    }

    function _isInActiveSources(address source) internal view returns (bool) {
        for (uint256 i = 0; i < activeSources.length; i++) {
            if (activeSources[i] == source) {
                return true;
            }
        }
        return false;
    }

    function _calculateReliability(address asset) internal view returns (uint256) {
        OracleMetrics storage metrics = oracleMetrics[asset];
        if (metrics.totalUpdates == 0) return BASIS_POINTS;
        
        // Simple reliability calculation based on update frequency and deviation
        uint256 timeSinceLastUpdate = block.timestamp - metrics.lastUpdate;
        uint256 timeScore = timeSinceLastUpdate < config.updateInterval ? BASIS_POINTS : 
            BASIS_POINTS * config.updateInterval / timeSinceLastUpdate;
        
        uint256 deviationScore = metrics.averageDeviation < config.validationThreshold ? BASIS_POINTS :
            BASIS_POINTS * config.validationThreshold / metrics.averageDeviation;
        
        return (timeScore + deviationScore) / 2;
    }

    function _calculateSystemHealth() internal view returns (uint256) {
        if (supportedAssets.length == 0) return BASIS_POINTS;
        
        uint256 healthyAssets = 0;
        for (uint256 i = 0; i < supportedAssets.length; i++) {
            if (!_isPriceStale(supportedAssets[i]) && priceData[supportedAssets[i]].isValid) {
                healthyAssets++;
            }
        }
        
        return (healthyAssets * BASIS_POINTS) / supportedAssets.length;
    }

    function _calculateAverageConfidence() internal view returns (uint256) {
        if (supportedAssets.length == 0) return 0;
        
        uint256 totalConfidence = 0;
        uint256 validAssets = 0;
        
        for (uint256 i = 0; i < supportedAssets.length; i++) {
            PriceData storage priceInfo = priceData[supportedAssets[i]];
            if (priceInfo.isValid) {
                totalConfidence += priceInfo.confidence;
                validAssets++;
            }
        }
        
        return validAssets > 0 ? totalConfidence / validAssets : 0;
    }

    // TWAP functions
    function updateTWAP(
        address asset,
        uint256 period
    ) external override onlyRole(PRICE_FEEDER_ROLE) {
        require(isAssetSupported[asset], "Asset not supported");
        require(period > 0, "Invalid period");
        
        // Implementation for TWAP update
        emit TWAPUpdated(asset, period, block.timestamp);
    }
    
    // Volatility functions
    function updateVolatility(
        address asset,
        uint256 period
    ) external override onlyRole(PRICE_FEEDER_ROLE) {
        require(isAssetSupported[asset], "Asset not supported");
        require(period > 0, "Invalid period");
        
        // Implementation for volatility update
        emit VolatilityUpdated(asset, period, block.timestamp);
    }
    
    // Price feed functions
    function updatePriceFeed(
        bytes32 feedId,
        uint256 price,
        uint256 confidence
    ) external override onlyRole(PRICE_FEEDER_ROLE) {
        require(price > 0, "Invalid price");
        require(confidence <= BASIS_POINTS, "Invalid confidence");
        
        // Implementation for price feed update
        emit PriceFeedUpdated(feedId, price, confidence, block.timestamp, msg.sender);
    }
    
    // Validation functions
    function updateValidationConfig(
        address asset,
        ValidationConfig calldata config
    ) external override onlyRole(ORACLE_MANAGER_ROLE) {
        require(isAssetSupported[asset], "Asset not supported");
        
        // Implementation for validation config update
        emit ValidationConfigUpdated(asset, block.timestamp);
    }
    
    function validatePriceUpdate(
        address asset,
        uint256 newPrice,
        uint256 currentPrice
    ) external view override returns (bool valid, string memory reason) {
        require(isAssetSupported[asset], "Asset not supported");
        
        if (newPrice == 0) {
            return (false, "Price cannot be zero");
        }
        
        if (currentPrice > 0) {
            uint256 deviation = newPrice > currentPrice 
                ? ((newPrice - currentPrice) * BASIS_POINTS) / currentPrice
                : ((currentPrice - newPrice) * BASIS_POINTS) / currentPrice;
            
            if (deviation > 1000) { // 10% deviation threshold
                return (false, "Price deviation too high");
            }
        }
        
        return (true, "Valid price update");
    }

    function updateFeedConfig(
        address asset,
        uint256 heartbeat,
        uint256 deviation,
        bool isActive
    ) external override onlyRole(ORACLE_MANAGER_ROLE) {
        require(asset != address(0), "Oracle: Invalid asset");
        
        emit PriceFeedCreated(asset, address(0), block.timestamp);
    }

    function updateGlobalConfig(
        uint256 maxPriceAge,
        uint256 minConfidence,
        uint256 maxDeviation
    ) external override onlyRole(ORACLE_MANAGER_ROLE) {
        require(maxPriceAge > 0, "Oracle: Invalid max price age");
        require(minConfidence > 0, "Oracle: Invalid min confidence");
        require(maxDeviation > 0, "Oracle: Invalid max deviation");
        
        emit ValidationConfigUpdated(address(0), block.timestamp);
    }

    function updateOracleConfig(
        address oracle,
        uint256 weight,
        bool isActive
    ) external override onlyRole(ORACLE_MANAGER_ROLE) {
        require(oracle != address(0), "Oracle: Invalid oracle");
        
        emit OracleAdded(oracle, weight, block.timestamp);
    }

    function updateOracleWeight(
        address oracle,
        uint256 newWeight
    ) external override onlyRole(ORACLE_MANAGER_ROLE) {
        require(oracle != address(0), "Oracle: Invalid oracle");
        require(newWeight > 0, "Oracle: Invalid weight");
        
        emit OracleWeightUpdated(oracle, newWeight, block.timestamp);
    }

    function updateCircuitBreakerThreshold(
        address asset,
        uint256 threshold
    ) external override onlyRole(ORACLE_MANAGER_ROLE) {
        require(asset != address(0), "Oracle: Invalid asset");
        require(threshold > 0, "Oracle: Invalid threshold");
        
        emit ValidationConfigUpdated(asset, block.timestamp);
    }

    function updateAggregationMethod(
        AggregationMethod method
    ) external override onlyRole(ORACLE_MANAGER_ROLE) {
        require(uint8(method) <= 2, "Oracle: Invalid aggregation method");
        
        config.aggregationMethod = method;
        emit ValidationConfigUpdated(address(0), block.timestamp);
    }

    // Emergency functions
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
}
