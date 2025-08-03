// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./UnifiedLiquidityPool.sol";

/**
 * @title DynamicRebalancer
 * @dev Advanced rebalancing engine with volatility-based adjustments
 * and automated risk management for optimal yield generation
 */
contract DynamicRebalancer is Ownable {
    using Math for uint256;

    // Rebalancing strategy configuration
    struct RebalanceStrategy {
        uint256 volatilityThreshold;    // Volatility threshold for strategy activation
        uint256 maxSlippage;           // Maximum allowed slippage
        uint256 rebalanceInterval;     // Minimum time between rebalances
        uint256 emergencyThreshold;    // Emergency rebalance threshold
        bool isActive;                 // Strategy activation status
    }

    // Market condition assessment
    struct MarketCondition {
        uint256 volatilityIndex;       // Current market volatility (0-10000)
        uint256 trendDirection;        // 0=bearish, 5000=neutral, 10000=bullish
        uint256 liquidityDepth;        // Available liquidity depth
        uint256 correlationMatrix;     // Asset correlation strength
        uint256 timestamp;             // Last update timestamp
    }

    // Rebalancing action
    struct RebalanceAction {
        address tokenFrom;
        address tokenTo;
        uint256 amount;
        uint256 expectedReturn;
        uint256 riskScore;
    }

    // Constants
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant VOLATILITY_PRECISION = 1e18;
    uint256 public constant MIN_REBALANCE_AMOUNT = 100e18; // $100 minimum
    uint256 public constant MAX_SINGLE_REBALANCE = 5000; // 50% max in single action
    
    // State variables
    UnifiedLiquidityPool public immutable liquidityPool;
    mapping(string => RebalanceStrategy) public strategies;
    MarketCondition public currentMarketCondition;
    mapping(address => uint256) public tokenVolatility;
    mapping(address => uint256) public lastPrices;
    
    // Historical data for volatility calculation
    mapping(address => uint256[]) public priceHistory;
    mapping(address => uint256) public priceHistoryIndex;
    uint256 public constant PRICE_HISTORY_LENGTH = 24; // 24 data points
    
    // Events
    event RebalanceExecuted(
        string strategy,
        address tokenFrom,
        address tokenTo,
        uint256 amount,
        uint256 timestamp
    );
    event VolatilityUpdated(address indexed token, uint256 volatility);
    event MarketConditionUpdated(uint256 volatilityIndex, uint256 trendDirection);
    event EmergencyRebalance(address indexed token, uint256 amount, string reason);

    constructor(address _liquidityPool, address initialOwner) Ownable(initialOwner) {
        liquidityPool = UnifiedLiquidityPool(_liquidityPool);
        _initializeStrategies();
    }

    /**
     * @dev Initialize default rebalancing strategies
     */
    function _initializeStrategies() internal {
        // Conservative strategy for low volatility
        strategies["conservative"] = RebalanceStrategy({
            volatilityThreshold: 1000,  // 10% volatility threshold
            maxSlippage: 50,           // 0.5% max slippage
            rebalanceInterval: 6 hours,
            emergencyThreshold: 2000,   // 20% emergency threshold
            isActive: true
        });
        
        // Aggressive strategy for high volatility
        strategies["aggressive"] = RebalanceStrategy({
            volatilityThreshold: 2000,  // 20% volatility threshold
            maxSlippage: 200,          // 2% max slippage
            rebalanceInterval: 1 hours,
            emergencyThreshold: 3000,   // 30% emergency threshold
            isActive: true
        });
        
        // Defensive strategy for extreme conditions
        strategies["defensive"] = RebalanceStrategy({
            volatilityThreshold: 3000,  // 30% volatility threshold
            maxSlippage: 100,          // 1% max slippage
            rebalanceInterval: 30 minutes,
            emergencyThreshold: 5000,   // 50% emergency threshold
            isActive: true
        });
    }

    /**
     * @dev Update market conditions and trigger rebalancing if needed
     */
    function updateMarketConditions(
        address[] calldata tokens,
        uint256[] calldata prices
    ) external {
        require(tokens.length == prices.length, "Array length mismatch");
        
        // Update price history and calculate volatility
        for (uint256 i = 0; i < tokens.length; i++) {
            _updatePriceHistory(tokens[i], prices[i]);
            _calculateVolatility(tokens[i]);
        }
        
        // Assess overall market condition
        _assessMarketCondition();
        
        // Determine and execute optimal rebalancing strategy
        _executeOptimalRebalancing();
    }

    /**
     * @dev Calculate and execute optimal rebalancing based on current conditions
     */
    function _executeOptimalRebalancing() internal {
        string memory optimalStrategy = _selectOptimalStrategy();
        RebalanceStrategy memory strategy = strategies[optimalStrategy];
        
        if (!strategy.isActive) return;
        
        // Generate rebalancing actions
        RebalanceAction[] memory actions = _generateRebalanceActions(strategy);
        
        // Execute actions
        for (uint256 i = 0; i < actions.length; i++) {
            if (actions[i].amount >= MIN_REBALANCE_AMOUNT) {
                _executeRebalanceAction(actions[i], optimalStrategy);
            }
        }
    }

    /**
     * @dev Select optimal strategy based on market conditions
     */
    function _selectOptimalStrategy() internal view returns (string memory) {
        uint256 avgVolatility = _calculateAverageVolatility();
        
        if (avgVolatility >= strategies["defensive"].volatilityThreshold) {
            return "defensive";
        } else if (avgVolatility >= strategies["aggressive"].volatilityThreshold) {
            return "aggressive";
        } else {
            return "conservative";
        }
    }

    /**
     * @dev Generate rebalancing actions based on strategy
     */
    function _generateRebalanceActions(RebalanceStrategy memory strategy) 
        internal 
        view 
        returns (RebalanceAction[] memory) 
    {
        // Get supported tokens from liquidity pool
        address[] memory tokens = _getSupportedTokens();
        RebalanceAction[] memory actions = new RebalanceAction[](tokens.length * tokens.length);
        uint256 actionCount = 0;
        
        for (uint256 i = 0; i < tokens.length; i++) {
            for (uint256 j = 0; j < tokens.length; j++) {
                if (i != j) {
                    RebalanceAction memory action = _calculateRebalanceAction(
                        tokens[i], 
                        tokens[j], 
                        strategy
                    );
                    
                    if (action.amount > 0) {
                        actions[actionCount] = action;
                        actionCount++;
                    }
                }
            }
        }
        
        // Resize array to actual action count
        RebalanceAction[] memory finalActions = new RebalanceAction[](actionCount);
        for (uint256 k = 0; k < actionCount; k++) {
            finalActions[k] = actions[k];
        }
        
        return finalActions;
    }

    /**
     * @dev Calculate specific rebalancing action between two tokens
     */
    function _calculateRebalanceAction(
        address tokenFrom,
        address tokenTo,
        RebalanceStrategy memory strategy
    ) internal view returns (RebalanceAction memory) {
        // Get current weights and target weights
        uint256 currentWeightFrom = _getCurrentWeight(tokenFrom);
        uint256 targetWeightFrom = _getTargetWeight(tokenFrom);
        uint256 currentWeightTo = _getCurrentWeight(tokenTo);
        uint256 targetWeightTo = _getTargetWeight(tokenTo);
        
        // Calculate if rebalancing is needed
        bool fromOverweight = currentWeightFrom > targetWeightFrom + strategy.volatilityThreshold;
        bool toUnderweight = currentWeightTo < targetWeightTo - strategy.volatilityThreshold;
        
        if (fromOverweight && toUnderweight) {
            uint256 excessFrom = currentWeightFrom - targetWeightFrom;
            uint256 deficitTo = targetWeightTo - currentWeightTo;
            uint256 rebalanceAmount = Math.min(excessFrom, deficitTo);
            
            // Limit rebalance amount based on strategy
            uint256 maxAmount = (_getTotalPoolValue() * MAX_SINGLE_REBALANCE) / BASIS_POINTS;
            rebalanceAmount = Math.min(rebalanceAmount, maxAmount);
            
            return RebalanceAction({
                tokenFrom: tokenFrom,
                tokenTo: tokenTo,
                amount: rebalanceAmount,
                expectedReturn: _calculateExpectedReturn(tokenFrom, tokenTo, rebalanceAmount),
                riskScore: _calculateRiskScore(tokenFrom, tokenTo)
            });
        }
        
        return RebalanceAction(address(0), address(0), 0, 0, 0);
    }

    /**
     * @dev Execute a specific rebalancing action
     */
    function _executeRebalanceAction(RebalanceAction memory action, string memory strategy) internal {
        // This would integrate with DEX protocols for actual token swapping
        // For now, we emit an event to track the action
        
        emit RebalanceExecuted(
            strategy,
            action.tokenFrom,
            action.tokenTo,
            action.amount,
            block.timestamp
        );
    }

    /**
     * @dev Update price history for volatility calculation
     */
    function _updatePriceHistory(address token, uint256 price) internal {
        uint256 index = priceHistoryIndex[token];
        
        // Initialize price history array if needed
        if (priceHistory[token].length < PRICE_HISTORY_LENGTH) {
            priceHistory[token].push(price);
        } else {
            priceHistory[token][index] = price;
        }
        
        priceHistoryIndex[token] = (index + 1) % PRICE_HISTORY_LENGTH;
        lastPrices[token] = price;
    }

    /**
     * @dev Calculate volatility for a token based on price history
     */
    function _calculateVolatility(address token) internal {
        uint256[] memory prices = priceHistory[token];
        if (prices.length < 2) return;
        
        // Calculate standard deviation of price changes
        uint256 mean = 0;
        for (uint256 i = 0; i < prices.length; i++) {
            mean += prices[i];
        }
        mean = mean / prices.length;
        
        uint256 variance = 0;
        for (uint256 i = 0; i < prices.length; i++) {
            uint256 diff = prices[i] > mean ? prices[i] - mean : mean - prices[i];
            variance += (diff * diff);
        }
        variance = variance / prices.length;
        
        // Convert to volatility percentage (simplified square root)
        uint256 volatility = _sqrt(variance) * BASIS_POINTS / mean;
        tokenVolatility[token] = volatility;
        
        emit VolatilityUpdated(token, volatility);
    }

    /**
     * @dev Assess overall market condition
     */
    function _assessMarketCondition() internal {
        uint256 avgVolatility = _calculateAverageVolatility();
        uint256 trendDirection = _calculateTrendDirection();
        
        currentMarketCondition = MarketCondition({
            volatilityIndex: avgVolatility,
            trendDirection: trendDirection,
            liquidityDepth: _calculateLiquidityDepth(),
            correlationMatrix: _calculateCorrelationMatrix(),
            timestamp: block.timestamp
        });
        
        emit MarketConditionUpdated(avgVolatility, trendDirection);
    }

    // Helper functions
    function _calculateAverageVolatility() internal view returns (uint256) {
        address[] memory tokens = _getSupportedTokens();
        uint256 totalVolatility = 0;
        uint256 activeTokens = 0;
        
        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokenVolatility[tokens[i]] > 0) {
                totalVolatility += tokenVolatility[tokens[i]];
                activeTokens++;
            }
        }
        
        return activeTokens > 0 ? totalVolatility / activeTokens : 0;
    }

    function _calculateTrendDirection() internal pure returns (uint256) {
        // Simplified trend calculation based on recent price movements
        // In production, this would use more sophisticated technical analysis
        return 5000; // Neutral trend for demo
    }

    function _calculateLiquidityDepth() internal pure returns (uint256) {
        // Calculate available liquidity across all supported tokens
        return _getTotalPoolValue();
    }

    function _calculateCorrelationMatrix() internal pure returns (uint256) {
        // Simplified correlation calculation
        // In production, this would calculate actual correlations between assets
        return 3000; // 30% correlation for demo
    }

    function _getCurrentWeight(address token) internal pure returns (uint256) {
        // This would integrate with the liquidity pool to get current weights
        return 2500; // 25% weight for demo
    }

    function _getTargetWeight(address token) internal pure returns (uint256) {
        // This would get target weights from pool configuration
        return 2500; // 25% target weight for demo
    }

    function _getTotalPoolValue() internal pure returns (uint256) {
        // Get total pool value from liquidity pool
        return 1000000e18; // $1M for demo
    }

    function _calculateExpectedReturn(address tokenFrom, address tokenTo, uint256 amount) 
        internal 
        pure 
        returns (uint256) 
    {
        // Calculate expected return from rebalancing action
        return amount * 105 / 100; // 5% expected return for demo
    }

    function _calculateRiskScore(address tokenFrom, address tokenTo) internal view returns (uint256) {
        uint256 volatilityFrom = tokenVolatility[tokenFrom];
        uint256 volatilityTo = tokenVolatility[tokenTo];
        return (volatilityFrom + volatilityTo) / 2;
    }

    function _getSupportedTokens() internal pure returns (address[] memory) {
        // This would get supported tokens from the liquidity pool
        address[] memory tokens = new address[](4);
        // Mock addresses for demo
        return tokens;
    }

    function _sqrt(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        uint256 y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
        return y;
    }

    // Admin functions
    function updateStrategy(
        string calldata strategyName,
        uint256 volatilityThreshold,
        uint256 maxSlippage,
        uint256 rebalanceInterval,
        uint256 emergencyThreshold,
        bool isActive
    ) external onlyOwner {
        strategies[strategyName] = RebalanceStrategy({
            volatilityThreshold: volatilityThreshold,
            maxSlippage: maxSlippage,
            rebalanceInterval: rebalanceInterval,
            emergencyThreshold: emergencyThreshold,
            isActive: isActive
        });
    }

    // View functions
    function getMarketCondition() external view returns (MarketCondition memory) {
        return currentMarketCondition;
    }

    function getTokenVolatility(address token) external view returns (uint256) {
        return tokenVolatility[token];
    }

    function getOptimalStrategy() external view returns (string memory) {
        return _selectOptimalStrategy();
    }
    
    /**
     * @dev Get rebalancing actions for the liquidity pool
     */
    function getRebalanceActions() external view returns (RebalanceAction[] memory) {
        string memory strategy = _selectOptimalStrategy();
        return _generateRebalanceActions(strategies[strategy]);
    }
    
    /**
     * @dev Check if rebalancing is needed
     */
    function shouldRebalance() external view returns (bool, string memory) {
        string memory strategy = _selectOptimalStrategy();
        RebalanceStrategy memory strategyConfig = strategies[strategy];
        
        if (!strategyConfig.isActive) {
            return (false, "Strategy inactive");
        }
        
        // Check if enough time has passed
        if (block.timestamp < currentMarketCondition.timestamp + strategyConfig.rebalanceInterval) {
            return (false, "Cooldown active");
        }
        
        // Check if volatility threshold is met
        uint256 avgVolatility = _calculateAverageVolatility();
        if (avgVolatility < strategyConfig.volatilityThreshold) {
            return (false, "Volatility below threshold");
        }
        
        return (true, strategy);
    }
    
    /**
     * @dev Get current market metrics
     */
    function getMarketMetrics() external view returns (
        uint256 volatilityIndex,
        uint256 trendDirection,
        uint256 liquidityDepth,
        uint256 correlationMatrix,
        string memory recommendedStrategy
    ) {
        volatilityIndex = currentMarketCondition.volatilityIndex;
        trendDirection = currentMarketCondition.trendDirection;
        liquidityDepth = currentMarketCondition.liquidityDepth;
        correlationMatrix = currentMarketCondition.correlationMatrix;
        recommendedStrategy = _selectOptimalStrategy();
    }
}
