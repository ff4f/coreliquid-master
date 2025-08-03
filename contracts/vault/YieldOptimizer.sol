// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "./YieldAggregator.sol";

/**
 * @title YieldOptimizer
 * @dev Optimizes yield strategies using machine learning algorithms and market analysis
 */
contract YieldOptimizer is AccessControl, ReentrancyGuard {
    using Math for uint256;

    
    bytes32 public constant OPTIMIZER_ROLE = keccak256("OPTIMIZER_ROLE");
    bytes32 public constant STRATEGY_ROLE = keccak256("STRATEGY_ROLE");
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");
    bytes32 public constant KEEPER_ROLE = keccak256("KEEPER_ROLE");
    
    struct OptimizationModel {
        string name;
        string description;
        uint256 version;
        uint256 accuracy; // Accuracy percentage in basis points
        uint256 lastUpdate;
        uint256 totalPredictions;
        uint256 successfulPredictions;
        bool isActive;
        mapping(string => uint256) parameters;
        string[] parameterKeys;
    }
    
    struct MarketCondition {
        uint256 volatility; // Market volatility index
        uint256 liquidityIndex; // Overall liquidity index
        uint256 riskSentiment; // Risk sentiment (1-100)
        uint256 yieldCurve; // Yield curve slope
        uint256 correlationIndex; // Asset correlation index
        uint256 timestamp;
        bool isBullish;
        bool isBearish;
        uint8 marketPhase; // 1=accumulation, 2=markup, 3=distribution, 4=markdown
    }
    
    struct OptimizationResult {
        address[] recommendedSources;
        uint256[] allocations;
        uint256 expectedAPY;
        uint256 riskScore;
        uint256 confidence;
        uint256 timeHorizon;
        string reasoning;
        uint256 timestamp;
    }
    
    struct PerformanceMetrics {
        uint256 totalOptimizations;
        uint256 successfulOptimizations;
        uint256 averageAPYImprovement;
        uint256 averageRiskReduction;
        uint256 totalValueOptimized;
        uint256 lastOptimization;
    }
    
    struct RiskProfile {
        uint8 riskTolerance; // 1-10 scale
        uint256 maxDrawdown; // Maximum acceptable drawdown
        uint256 targetAPY; // Target APY in basis points
        uint256 timeHorizon; // Investment time horizon in seconds
        bool preferStablecoins;
        bool allowLeveraged;
        uint8 diversificationLevel; // 1-10 scale
    }
    
    struct YieldPrediction {
        address source;
        uint256 predictedAPY;
        uint256 confidence;
        uint256 timeframe;
        uint256 riskScore;
        string[] factors;
        uint256 timestamp;
    }
    
    mapping(uint256 => OptimizationModel) public models;
    mapping(uint256 => MarketCondition) public marketHistory;
    mapping(address => OptimizationResult) public lastOptimization;
    mapping(address => PerformanceMetrics) public userMetrics;
    mapping(address => RiskProfile) public userRiskProfiles;
    mapping(address => mapping(uint256 => YieldPrediction)) public predictions;
    mapping(address => uint256) public predictionCounts;
    
    uint256 public modelsCount;
    uint256 public marketHistoryLength;
    uint256 public activeModelId;
    
    YieldAggregator public yieldAggregator;
    
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant MAX_SOURCES = 20;
    uint256 public constant MARKET_HISTORY_LIMIT = 1000;
    uint256 public constant PREDICTION_LIMIT = 100;
    uint256 public constant MIN_CONFIDENCE = 5000; // 50%
    uint256 public constant OPTIMIZATION_COOLDOWN = 3600; // 1 hour
    
    event ModelAdded(
        uint256 indexed modelId,
        string name,
        uint256 version
    );
    
    event ModelUpdated(
        uint256 indexed modelId,
        uint256 accuracy,
        uint256 timestamp
    );
    
    event OptimizationCompleted(
        address indexed user,
        uint256 expectedAPY,
        uint256 riskScore,
        uint256 confidence
    );
    
    event MarketConditionUpdated(
        uint256 volatility,
        uint256 riskSentiment,
        uint8 marketPhase,
        uint256 timestamp
    );
    
    event PredictionMade(
        address indexed source,
        uint256 predictedAPY,
        uint256 confidence,
        uint256 timestamp
    );
    
    event RiskProfileUpdated(
        address indexed user,
        uint8 riskTolerance,
        uint256 targetAPY
    );
    
    constructor(address _yieldAggregator) {
        require(_yieldAggregator != address(0), "Invalid yield aggregator");
        
        yieldAggregator = YieldAggregator(_yieldAggregator);
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(OPTIMIZER_ROLE, msg.sender);
        _grantRole(STRATEGY_ROLE, msg.sender);
        _grantRole(ORACLE_ROLE, msg.sender);
        _grantRole(KEEPER_ROLE, msg.sender);
        
        // Initialize default model
        _addDefaultModel();
    }
    
    function addOptimizationModel(
        string memory name,
        string memory description,
        uint256 version,
        string[] memory parameterKeys,
        uint256[] memory parameterValues
    ) external onlyRole(OPTIMIZER_ROLE) {
        require(bytes(name).length > 0, "Invalid name");
        require(parameterKeys.length == parameterValues.length, "Parameter mismatch");
        
        uint256 modelId = modelsCount;
        OptimizationModel storage model = models[modelId];
        
        model.name = name;
        model.description = description;
        model.version = version;
        model.accuracy = 5000; // Start with 50% accuracy
        model.lastUpdate = block.timestamp;
        model.totalPredictions = 0;
        model.successfulPredictions = 0;
        model.isActive = true;
        model.parameterKeys = parameterKeys;
        
        // Set parameters
        for (uint256 i = 0; i < parameterKeys.length; i++) {
            model.parameters[parameterKeys[i]] = parameterValues[i];
        }
        
        modelsCount++;
        
        emit ModelAdded(modelId, name, version);
    }
    
    function updateMarketConditions(
        uint256 volatility,
        uint256 liquidityIndex,
        uint256 riskSentiment,
        uint256 yieldCurve,
        uint256 correlationIndex,
        bool isBullish,
        bool isBearish,
        uint8 marketPhase
    ) external onlyRole(ORACLE_ROLE) {
        require(riskSentiment <= 100, "Invalid risk sentiment");
        require(marketPhase >= 1 && marketPhase <= 4, "Invalid market phase");
        
        MarketCondition memory condition = MarketCondition({
            volatility: volatility,
            liquidityIndex: liquidityIndex,
            riskSentiment: riskSentiment,
            yieldCurve: yieldCurve,
            correlationIndex: correlationIndex,
            timestamp: block.timestamp,
            isBullish: isBullish,
            isBearish: isBearish,
            marketPhase: marketPhase
        });
        
        marketHistory[marketHistoryLength] = condition;
        marketHistoryLength++;
        
        // Limit history size
        if (marketHistoryLength > MARKET_HISTORY_LIMIT) {
            // Shift array (simplified)
            for (uint256 i = 0; i < MARKET_HISTORY_LIMIT - 1; i++) {
                marketHistory[i] = marketHistory[i + 1];
            }
            marketHistoryLength = MARKET_HISTORY_LIMIT;
        }
        
        emit MarketConditionUpdated(volatility, riskSentiment, marketPhase, block.timestamp);
    }
    
    function optimizeYield(
        address user,
        uint256 amount
    ) external onlyRole(STRATEGY_ROLE) nonReentrant returns (OptimizationResult memory) {
        require(user != address(0), "Invalid user");
        require(amount > 0, "Invalid amount");
        
        // Check cooldown
        require(
            block.timestamp >= userMetrics[user].lastOptimization + OPTIMIZATION_COOLDOWN,
            "Optimization cooldown active"
        );
        
        RiskProfile memory riskProfile = userRiskProfiles[user];
        if (riskProfile.riskTolerance == 0) {
            // Set default risk profile
            riskProfile = _getDefaultRiskProfile();
        }
        
        // Get current market conditions
        MarketCondition memory currentMarket = _getCurrentMarketCondition();
        
        // Get available yield sources
        address[] memory availableSources = yieldAggregator.getAllYieldSources();
        
        // Run optimization algorithm
        OptimizationResult memory result = _runOptimization(
            user,
            amount,
            riskProfile,
            currentMarket,
            availableSources
        );
        
        // Store result
        lastOptimization[user] = result;
        
        // Update metrics
        PerformanceMetrics storage metrics = userMetrics[user];
        metrics.totalOptimizations++;
        metrics.lastOptimization = block.timestamp;
        metrics.totalValueOptimized += amount;
        
        emit OptimizationCompleted(user, result.expectedAPY, result.riskScore, result.confidence);
        
        return result;
    }
    
    function predictYield(
        address source,
        uint256 timeframe
    ) external onlyRole(ORACLE_ROLE) returns (YieldPrediction memory) {
        require(source != address(0), "Invalid source");
        require(timeframe > 0, "Invalid timeframe");
        
        // Get source data
        YieldAggregator.YieldSource memory yieldSource = yieldAggregator.getYieldSource(source);
        require(yieldSource.protocol != address(0), "Source not found");
        
        // Get current market conditions
        MarketCondition memory currentMarket = _getCurrentMarketCondition();
        
        // Run prediction algorithm
        YieldPrediction memory prediction = _runPrediction(
            source,
            yieldSource,
            currentMarket,
            timeframe
        );
        
        // Store prediction
        uint256 predictionId = predictionCounts[source];
        predictions[source][predictionId] = prediction;
        predictionCounts[source]++;
        
        // Limit predictions per source
        if (predictionCounts[source] > PREDICTION_LIMIT) {
            // Remove oldest prediction (simplified)
            delete predictions[source][0];
            predictionCounts[source] = PREDICTION_LIMIT;
        }
        
        emit PredictionMade(source, prediction.predictedAPY, prediction.confidence, block.timestamp);
        
        return prediction;
    }
    
    function updateRiskProfile(
        address user,
        RiskProfile memory profile
    ) external {
        require(msg.sender == user || hasRole(STRATEGY_ROLE, msg.sender), "Unauthorized");
        require(profile.riskTolerance >= 1 && profile.riskTolerance <= 10, "Invalid risk tolerance");
        require(profile.diversificationLevel >= 1 && profile.diversificationLevel <= 10, "Invalid diversification");
        
        userRiskProfiles[user] = profile;
        
        emit RiskProfileUpdated(user, profile.riskTolerance, profile.targetAPY);
    }
    
    function backtestStrategy(
        address[] memory sources,
        uint256[] memory allocations,
        uint256 startTime,
        uint256 endTime
    ) external view returns (
        uint256 totalReturn,
        uint256 maxDrawdown,
        uint256 sharpeRatio,
        uint256 volatility
    ) {
        require(sources.length == allocations.length, "Array length mismatch");
        require(startTime < endTime, "Invalid time range");
        require(endTime <= block.timestamp, "End time in future");
        
        // Simplified backtesting logic
        // In production, this would use historical data
        
        uint256 totalAllocation = 0;
        uint256 weightedReturn = 0;
        uint256 weightedRisk = 0;
        
        for (uint256 i = 0; i < sources.length; i++) {
            require(allocations[i] <= BASIS_POINTS, "Invalid allocation");
            totalAllocation += allocations[i];
            
            YieldAggregator.YieldSource memory source = yieldAggregator.getYieldSource(sources[i]);
            
            // Simulate historical performance
            uint256 sourceReturn = source.apy; // Simplified
            uint256 sourceRisk = source.riskLevel * 1000; // Convert to basis points
            
            weightedReturn += (sourceReturn * allocations[i]) / BASIS_POINTS;
            weightedRisk += (sourceRisk * allocations[i]) / BASIS_POINTS;
        }
        
        require(totalAllocation <= BASIS_POINTS, "Total allocation exceeds 100%");
        
        totalReturn = weightedReturn;
        maxDrawdown = weightedRisk / 2; // Simplified
        volatility = weightedRisk;
        sharpeRatio = weightedRisk > 0 ? (weightedReturn * BASIS_POINTS) / weightedRisk : 0;
    }
    
    function _runOptimization(
        address user,
        uint256 amount,
        RiskProfile memory riskProfile,
        MarketCondition memory marketCondition,
        address[] memory availableSources
    ) internal view returns (OptimizationResult memory) {
        // Get active optimization model
        OptimizationModel storage model = models[activeModelId];
        
        // Filter sources based on risk profile
        address[] memory suitableSources = _filterSourcesByRisk(availableSources, riskProfile);
        
        // Calculate optimal allocations
        uint256[] memory allocations = _calculateOptimalAllocations(
            suitableSources,
            riskProfile,
            marketCondition,
            model
        );
        
        // Calculate expected metrics
        (uint256 expectedAPY, uint256 riskScore) = _calculateExpectedMetrics(
            suitableSources,
            allocations
        );
        
        // Calculate confidence based on model accuracy and market conditions
        uint256 confidence = _calculateConfidence(model, marketCondition);
        
        // Generate reasoning
        string memory reasoning = _generateReasoning(
            riskProfile,
            marketCondition,
            expectedAPY,
            riskScore
        );
        
        return OptimizationResult({
            recommendedSources: suitableSources,
            allocations: allocations,
            expectedAPY: expectedAPY,
            riskScore: riskScore,
            confidence: confidence,
            timeHorizon: riskProfile.timeHorizon,
            reasoning: reasoning,
            timestamp: block.timestamp
        });
    }
    
    function _runPrediction(
        address source,
        YieldAggregator.YieldSource memory yieldSource,
        MarketCondition memory marketCondition,
        uint256 timeframe
    ) internal view returns (YieldPrediction memory) {
        // Get active model
        OptimizationModel storage model = models[activeModelId];
        
        // Base prediction on current APY
        uint256 baseAPY = yieldSource.apy;
        
        // Adjust based on market conditions
        uint256 marketAdjustment = _calculateMarketAdjustment(marketCondition, yieldSource.riskLevel);
        uint256 predictedAPY = (baseAPY * marketAdjustment) / BASIS_POINTS;
        
        // Calculate confidence
        uint256 confidence = _calculatePredictionConfidence(model, marketCondition, timeframe);
        
        // Calculate risk score
        uint256 riskScore = _calculateSourceRiskScore(yieldSource, marketCondition);
        
        // Generate factors
        string[] memory factors = _generatePredictionFactors(marketCondition, yieldSource);
        
        return YieldPrediction({
            source: source,
            predictedAPY: predictedAPY,
            confidence: confidence,
            timeframe: timeframe,
            riskScore: riskScore,
            factors: factors,
            timestamp: block.timestamp
        });
    }
    
    function _filterSourcesByRisk(
        address[] memory sources,
        RiskProfile memory riskProfile
    ) internal view returns (address[] memory) {
        address[] memory filtered = new address[](sources.length);
        uint256 count = 0;
        
        for (uint256 i = 0; i < sources.length; i++) {
            YieldAggregator.YieldSource memory source = yieldAggregator.getYieldSource(sources[i]);
            
            // Check if source matches risk profile
            if (source.riskLevel <= riskProfile.riskTolerance && source.isActive) {
                // Additional filters based on preferences
                if (riskProfile.preferStablecoins) {
                    // Check if source uses stablecoins (simplified check)
                    // In production, this would check token types
                }
                
                filtered[count] = sources[i];
                count++;
            }
        }
        
        // Resize array
        address[] memory result = new address[](count);
        for (uint256 i = 0; i < count; i++) {
            result[i] = filtered[i];
        }
        
        return result;
    }
    
    function _calculateOptimalAllocations(
        address[] memory sources,
        RiskProfile memory riskProfile,
        MarketCondition memory marketCondition,
        OptimizationModel storage model
    ) internal pure returns (uint256[] memory) {
        uint256[] memory allocations = new uint256[](sources.length);
        
        if (sources.length == 0) {
            return allocations;
        }
        
        // Simple equal weight allocation for now
        // In production, this would use sophisticated optimization algorithms
        uint256 baseAllocation = BASIS_POINTS / sources.length;
        uint256 remainingAllocation = BASIS_POINTS;
        
        for (uint256 i = 0; i < sources.length; i++) {
            if (i == sources.length - 1) {
                // Last source gets remaining allocation
                allocations[i] = remainingAllocation;
            } else {
                allocations[i] = baseAllocation;
                remainingAllocation -= baseAllocation;
            }
        }
        
        return allocations;
    }
    
    function _calculateExpectedMetrics(
        address[] memory sources,
        uint256[] memory allocations
    ) internal view returns (uint256 expectedAPY, uint256 riskScore) {
        uint256 totalWeightedAPY = 0;
        uint256 totalWeightedRisk = 0;
        
        for (uint256 i = 0; i < sources.length; i++) {
            YieldAggregator.YieldSource memory source = yieldAggregator.getYieldSource(sources[i]);
            
            totalWeightedAPY += (source.apy * allocations[i]) / BASIS_POINTS;
            totalWeightedRisk += (uint256(source.riskLevel) * 1000 * allocations[i]) / BASIS_POINTS;
        }
        
        expectedAPY = totalWeightedAPY;
        riskScore = totalWeightedRisk;
    }
    
    function _calculateConfidence(
        OptimizationModel storage model,
        MarketCondition memory marketCondition
    ) internal view returns (uint256) {
        // Base confidence on model accuracy
        uint256 baseConfidence = model.accuracy;
        
        // Adjust based on market volatility
        uint256 volatilityAdjustment = BASIS_POINTS;
        if (marketCondition.volatility > 5000) { // High volatility
            volatilityAdjustment = 8000; // Reduce confidence
        } else if (marketCondition.volatility < 2000) { // Low volatility
            volatilityAdjustment = 12000; // Increase confidence
        }
        
        uint256 adjustedConfidence = (baseConfidence * volatilityAdjustment) / BASIS_POINTS;
        
        return Math.min(adjustedConfidence, BASIS_POINTS);
    }
    
    function _calculateMarketAdjustment(
        MarketCondition memory marketCondition,
        uint8 riskLevel
    ) internal pure returns (uint256) {
        uint256 adjustment = BASIS_POINTS;
        
        // Adjust based on market phase
        if (marketCondition.marketPhase == 2) { // Markup phase
            adjustment = 11000; // +10%
        } else if (marketCondition.marketPhase == 4) { // Markdown phase
            adjustment = 9000; // -10%
        }
        
        // Adjust based on risk sentiment
        if (marketCondition.riskSentiment > 70) { // High risk appetite
            if (riskLevel > 5) {
                adjustment = (adjustment * 11000) / BASIS_POINTS; // Boost high-risk sources
            }
        } else if (marketCondition.riskSentiment < 30) { // Low risk appetite
            if (riskLevel <= 3) {
                adjustment = (adjustment * 11000) / BASIS_POINTS; // Boost low-risk sources
            } else {
                adjustment = (adjustment * 9000) / BASIS_POINTS; // Reduce high-risk sources
            }
        }
        
        return adjustment;
    }
    
    function _calculatePredictionConfidence(
        OptimizationModel storage model,
        MarketCondition memory marketCondition,
        uint256 timeframe
    ) internal view returns (uint256) {
        uint256 baseConfidence = model.accuracy;
        
        // Reduce confidence for longer timeframes
        if (timeframe > 30 days) {
            baseConfidence = (baseConfidence * 8000) / BASIS_POINTS;
        } else if (timeframe > 7 days) {
            baseConfidence = (baseConfidence * 9000) / BASIS_POINTS;
        }
        
        // Adjust for market volatility
        if (marketCondition.volatility > 5000) {
            baseConfidence = (baseConfidence * 7000) / BASIS_POINTS;
        }
        
        return Math.max(baseConfidence, MIN_CONFIDENCE);
    }
    
    function _calculateSourceRiskScore(
        YieldAggregator.YieldSource memory source,
        MarketCondition memory marketCondition
    ) internal pure returns (uint256) {
        uint256 baseRisk = uint256(source.riskLevel) * 1000;
        
        // Adjust based on market conditions
        if (marketCondition.volatility > 5000) {
            baseRisk = (baseRisk * 12000) / BASIS_POINTS; // Increase risk in volatile markets
        }
        
        if (marketCondition.liquidityIndex < 5000) {
            baseRisk = (baseRisk * 11000) / BASIS_POINTS; // Increase risk in low liquidity
        }
        
        return baseRisk;
    }
    
    function _generateReasoning(
        RiskProfile memory riskProfile,
        MarketCondition memory marketCondition,
        uint256 expectedAPY,
        uint256 riskScore
    ) internal pure returns (string memory) {
        // Simplified reasoning generation
        // In production, this would be more sophisticated
        
        if (marketCondition.isBullish) {
            return "Bullish market conditions favor higher-yield strategies";
        } else if (marketCondition.isBearish) {
            return "Bearish market conditions favor conservative strategies";
        } else {
            return "Neutral market conditions support balanced allocation";
        }
    }
    
    function _generatePredictionFactors(
        MarketCondition memory marketCondition,
        YieldAggregator.YieldSource memory source
    ) internal pure returns (string[] memory) {
        string[] memory factors = new string[](3);
        
        factors[0] = "Market volatility";
        factors[1] = "Liquidity conditions";
        factors[2] = "Risk sentiment";
        
        return factors;
    }
    
    function _getCurrentMarketCondition() internal view returns (MarketCondition memory) {
        if (marketHistoryLength > 0) {
            return marketHistory[marketHistoryLength - 1];
        }
        
        // Return default market condition
        return MarketCondition({
            volatility: 3000,
            liquidityIndex: 7000,
            riskSentiment: 50,
            yieldCurve: 5000,
            correlationIndex: 5000,
            timestamp: block.timestamp,
            isBullish: false,
            isBearish: false,
            marketPhase: 1
        });
    }
    
    function _getDefaultRiskProfile() internal pure returns (RiskProfile memory) {
        return RiskProfile({
            riskTolerance: 5,
            maxDrawdown: 2000, // 20%
            targetAPY: 1000, // 10%
            timeHorizon: 365 days,
            preferStablecoins: false,
            allowLeveraged: false,
            diversificationLevel: 7
        });
    }
    
    function _addDefaultModel() internal {
        string[] memory keys = new string[](3);
        uint256[] memory values = new uint256[](3);
        
        keys[0] = "riskWeight";
        keys[1] = "yieldWeight";
        keys[2] = "diversificationWeight";
        
        values[0] = 3000; // 30%
        values[1] = 5000; // 50%
        values[2] = 2000; // 20%
        
        OptimizationModel storage model = models[0];
        model.name = "Default Optimizer";
        model.description = "Basic yield optimization model";
        model.version = 1;
        model.accuracy = 7000; // 70%
        model.lastUpdate = block.timestamp;
        model.isActive = true;
        model.parameterKeys = keys;
        
        for (uint256 i = 0; i < keys.length; i++) {
            model.parameters[keys[i]] = values[i];
        }
        
        modelsCount = 1;
        activeModelId = 0;
    }
    
    // View functions
    function getOptimizationResult(address user) external view returns (OptimizationResult memory) {
        return lastOptimization[user];
    }
    
    function getUserMetrics(address user) external view returns (PerformanceMetrics memory) {
        return userMetrics[user];
    }
    
    function getUserRiskProfile(address user) external view returns (RiskProfile memory) {
        return userRiskProfiles[user];
    }
    
    function getMarketCondition() external view returns (MarketCondition memory) {
        return _getCurrentMarketCondition();
    }
    
    function getModel(uint256 modelId) external view returns (
        string memory name,
        string memory description,
        uint256 version,
        uint256 accuracy,
        bool isActive
    ) {
        OptimizationModel storage model = models[modelId];
        return (model.name, model.description, model.version, model.accuracy, model.isActive);
    }
    
    function getPredictions(address source, uint256 limit) external view returns (YieldPrediction[] memory) {
        uint256 count = predictionCounts[source];
        if (limit == 0 || limit > count) {
            limit = count;
        }
        
        YieldPrediction[] memory result = new YieldPrediction[](limit);
        
        for (uint256 i = 0; i < limit; i++) {
            uint256 index = count > limit ? count - limit + i : i;
            result[i] = predictions[source][index];
        }
        
        return result;
    }
    
    // Admin functions
    function setActiveModel(uint256 modelId) external onlyRole(OPTIMIZER_ROLE) {
        require(modelId < modelsCount, "Model not found");
        require(models[modelId].isActive, "Model not active");
        
        activeModelId = modelId;
    }
    
    function updateModelAccuracy(
        uint256 modelId,
        uint256 accuracy
    ) external onlyRole(OPTIMIZER_ROLE) {
        require(modelId < modelsCount, "Model not found");
        require(accuracy <= BASIS_POINTS, "Invalid accuracy");
        
        OptimizationModel storage model = models[modelId];
        model.accuracy = accuracy;
        model.lastUpdate = block.timestamp;
        
        emit ModelUpdated(modelId, accuracy, block.timestamp);
    }
    
    function setYieldAggregator(address _yieldAggregator) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_yieldAggregator != address(0), "Invalid yield aggregator");
        yieldAggregator = YieldAggregator(_yieldAggregator);
    }
}
