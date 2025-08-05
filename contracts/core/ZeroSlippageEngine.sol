// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title ZeroSlippageEngine
 * @dev Advanced slippage protection and MEV resistance for Core protocol
 */
contract ZeroSlippageEngine is Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;
    using Math for uint256;

    struct SlippageProtection {
        uint256 maxSlippage; // Maximum allowed slippage in basis points
        uint256 timeWindow; // Time window for price validation
        uint256 priceThreshold; // Price deviation threshold
        bool isActive;
    }

    struct TradeExecution {
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 expectedAmountOut;
        uint256 actualAmountOut;
        uint256 slippage;
        uint256 timestamp;
        bool isProtected;
    }

    struct MEVProtection {
        uint256 blockDelay; // Minimum blocks between trades
        uint256 gasThreshold; // Maximum gas price threshold
        uint256 frontrunThreshold; // Frontrun detection threshold
        bool sandwichProtection; // Sandwich attack protection
        bool flashloanProtection; // Flashloan MEV protection
    }

    struct PriceOracle {
        address oracle;
        uint256 heartbeat; // Maximum time between updates
        uint256 deviation; // Maximum price deviation
        bool isActive;
    }

    mapping(address => SlippageProtection) public slippageProtection;
    mapping(address => mapping(address => uint256)) public lastTradeBlock;
    mapping(bytes32 => TradeExecution) public tradeExecutions;
    mapping(address => PriceOracle) public priceOracles;
    mapping(address => bool) public authorizedRouters;
    mapping(address => uint256) public userNonces;
    
    MEVProtection public mevProtection;
    
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant MAX_SLIPPAGE = 1000; // 10% max slippage
    uint256 public constant MIN_TIME_WINDOW = 1 minutes;
    uint256 public constant MAX_TIME_WINDOW = 1 hours;
    
    uint256 public defaultMaxSlippage = 50; // 0.5% default
    uint256 public defaultTimeWindow = 5 minutes;
    uint256 public emergencySlippage = 500; // 5% emergency slippage
    
    bool public globalProtectionEnabled = true;
    bool public emergencyMode = false;
    
    address public priceAggregator;
    address public mevDetector;

    event SlippageProtectionUpdated(address indexed token, SlippageProtection protection);
    event TradeExecuted(bytes32 indexed tradeId, address indexed user, TradeExecution execution);
    event MEVDetected(address indexed user, string mevType, uint256 severity);
    event SlippageExceeded(address indexed user, address tokenIn, address tokenOut, uint256 slippage);
    event PriceOracleUpdated(address indexed token, PriceOracle oracle);
    event EmergencyModeToggled(bool enabled);
    event MEVProtectionUpdated(MEVProtection protection);

    modifier onlyAuthorizedRouter() {
        require(authorizedRouters[msg.sender] || msg.sender == owner(), "Not authorized router");
        _;
    }

    modifier slippageProtected(address tokenIn, address tokenOut, uint256 amountIn, uint256 minAmountOut) {
        if (globalProtectionEnabled && !emergencyMode) {
            _validateSlippage(tokenIn, tokenOut, amountIn, minAmountOut);
        }
        _;
    }

    modifier mevProtected(address user) {
        if (globalProtectionEnabled && !emergencyMode) {
            _detectMEV(user);
        }
        _;
    }

    constructor(
        address _priceAggregator,
        address _mevDetector
    ) Ownable(msg.sender) {
        require(_priceAggregator != address(0), "Invalid price aggregator");
        require(_mevDetector != address(0), "Invalid MEV detector");
        
        priceAggregator = _priceAggregator;
        mevDetector = _mevDetector;
        
        // Initialize MEV protection
        mevProtection = MEVProtection({
            blockDelay: 1, // 1 block delay
            gasThreshold: 100 gwei, // 100 gwei max
            frontrunThreshold: 1000, // 10% threshold
            sandwichProtection: true,
            flashloanProtection: true
        });
    }

    /**
     * @dev Execute trade with zero slippage protection
     * @param tokenIn Input token address
     * @param tokenOut Output token address
     * @param amountIn Input amount
     * @param minAmountOut Minimum output amount
     * @param deadline Transaction deadline
     * @return amountOut Actual output amount
     */
    function executeTradeWithProtection(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        uint256 deadline
    ) external 
        nonReentrant 
        whenNotPaused 
        slippageProtected(tokenIn, tokenOut, amountIn, minAmountOut)
        mevProtected(msg.sender)
        returns (uint256 amountOut) 
    {
        require(block.timestamp <= deadline, "Transaction expired");
        require(amountIn > 0, "Invalid input amount");
        require(minAmountOut > 0, "Invalid minimum output");
        
        // Get expected output from price oracle
        uint256 expectedAmountOut = _getExpectedOutput(tokenIn, tokenOut, amountIn);
        
        // Validate slippage
        require(minAmountOut >= expectedAmountOut * (BASIS_POINTS - _getMaxSlippage(tokenIn)) / BASIS_POINTS, "Slippage too high");
        
        // Execute the actual trade (simplified - would integrate with DEX)
        amountOut = _executeTrade(tokenIn, tokenOut, amountIn);
        
        // Validate output amount
        require(amountOut >= minAmountOut, "Insufficient output amount");
        
        // Calculate actual slippage
        uint256 actualSlippage = expectedAmountOut > amountOut ? 
            (expectedAmountOut - amountOut) * BASIS_POINTS / expectedAmountOut : 0;
        
        // Record trade execution
        bytes32 tradeId = _recordTradeExecution(
            tokenIn, 
            tokenOut, 
            amountIn, 
            expectedAmountOut, 
            amountOut, 
            actualSlippage
        );
        
        // Update last trade block
        lastTradeBlock[msg.sender][tokenIn] = block.number;
        lastTradeBlock[msg.sender][tokenOut] = block.number;
        
        emit TradeExecuted(tradeId, msg.sender, tradeExecutions[tradeId]);
    }

    /**
     * @dev Get quote with slippage protection
     * @param tokenIn Input token address
     * @param tokenOut Output token address
     * @param amountIn Input amount
     * @return amountOut Expected output amount
     * @return maxSlippage Maximum slippage for this pair
     */
    function getProtectedQuote(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external view returns (uint256 amountOut, uint256 maxSlippage) {
        amountOut = _getExpectedOutput(tokenIn, tokenOut, amountIn);
        maxSlippage = _getMaxSlippage(tokenIn);
        
        // Apply slippage protection
        amountOut = amountOut * (BASIS_POINTS - maxSlippage) / BASIS_POINTS;
    }

    /**
     * @dev Check if trade is safe from MEV
     * @param user User address
     * @param tokenIn Input token
     * @param tokenOut Output token
     * @param amountIn Input amount
     * @return isSafe True if trade is safe
     * @return reason Reason if not safe
     */
    function checkMEVSafety(
        address user,
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external view returns (bool isSafe, string memory reason) {
        // Check block delay
        if (lastTradeBlock[user][tokenIn] + mevProtection.blockDelay > block.number) {
            return (false, "Block delay not met");
        }
        
        // Check gas price
        if (tx.gasprice > mevProtection.gasThreshold) {
            return (false, "Gas price too high");
        }
        
        // Check for potential sandwich attack
        if (mevProtection.sandwichProtection && _detectSandwichAttack(user, tokenIn, tokenOut, amountIn)) {
            return (false, "Potential sandwich attack");
        }
        
        // Check for flashloan MEV
        if (mevProtection.flashloanProtection && _detectFlashloanMEV(user)) {
            return (false, "Potential flashloan MEV");
        }
        
        return (true, "");
    }

    /**
     * @dev Set slippage protection for a token
     * @param token Token address
     * @param maxSlippage Maximum slippage in basis points
     * @param timeWindow Time window for price validation
     * @param priceThreshold Price deviation threshold
     */
    function setSlippageProtection(
        address token,
        uint256 maxSlippage,
        uint256 timeWindow,
        uint256 priceThreshold
    ) external onlyOwner {
        require(token != address(0), "Invalid token");
        require(maxSlippage <= MAX_SLIPPAGE, "Slippage too high");
        require(timeWindow >= MIN_TIME_WINDOW && timeWindow <= MAX_TIME_WINDOW, "Invalid time window");
        
        slippageProtection[token] = SlippageProtection({
            maxSlippage: maxSlippage,
            timeWindow: timeWindow,
            priceThreshold: priceThreshold,
            isActive: true
        });
        
        emit SlippageProtectionUpdated(token, slippageProtection[token]);
    }

    /**
     * @dev Update MEV protection settings
     * @param blockDelay Minimum blocks between trades
     * @param gasThreshold Maximum gas price threshold
     * @param frontrunThreshold Frontrun detection threshold
     * @param sandwichProtection Sandwich attack protection
     * @param flashloanProtection Flashloan MEV protection
     */
    function updateMEVProtection(
        uint256 blockDelay,
        uint256 gasThreshold,
        uint256 frontrunThreshold,
        bool sandwichProtection,
        bool flashloanProtection
    ) external onlyOwner {
        mevProtection = MEVProtection({
            blockDelay: blockDelay,
            gasThreshold: gasThreshold,
            frontrunThreshold: frontrunThreshold,
            sandwichProtection: sandwichProtection,
            flashloanProtection: flashloanProtection
        });
        
        emit MEVProtectionUpdated(mevProtection);
    }

    /**
     * @dev Set price oracle for a token
     * @param token Token address
     * @param oracle Oracle address
     * @param heartbeat Maximum time between updates
     * @param deviation Maximum price deviation
     */
    function setPriceOracle(
        address token,
        address oracle,
        uint256 heartbeat,
        uint256 deviation
    ) external onlyOwner {
        require(token != address(0), "Invalid token");
        require(oracle != address(0), "Invalid oracle");
        
        priceOracles[token] = PriceOracle({
            oracle: oracle,
            heartbeat: heartbeat,
            deviation: deviation,
            isActive: true
        });
        
        emit PriceOracleUpdated(token, priceOracles[token]);
    }

    /**
     * @dev Set authorized router status
     * @param router Router address
     * @param authorized Authorization status
     */
    function setAuthorizedRouter(address router, bool authorized) external onlyOwner {
        authorizedRouters[router] = authorized;
    }

    /**
     * @dev Toggle global protection
     * @param enabled Protection enabled status
     */
    function setGlobalProtection(bool enabled) external onlyOwner {
        globalProtectionEnabled = enabled;
    }

    /**
     * @dev Toggle emergency mode
     * @param enabled Emergency mode status
     */
    function setEmergencyMode(bool enabled) external onlyOwner {
        emergencyMode = enabled;
        emit EmergencyModeToggled(enabled);
    }

    /**
     * @dev Update default slippage settings
     * @param maxSlippage Default maximum slippage
     * @param timeWindow Default time window
     * @param emergencySlippageValue Emergency slippage value
     */
    function updateDefaultSettings(
        uint256 maxSlippage,
        uint256 timeWindow,
        uint256 emergencySlippageValue
    ) external onlyOwner {
        require(maxSlippage <= MAX_SLIPPAGE, "Slippage too high");
        require(timeWindow >= MIN_TIME_WINDOW && timeWindow <= MAX_TIME_WINDOW, "Invalid time window");
        
        defaultMaxSlippage = maxSlippage;
        defaultTimeWindow = timeWindow;
        emergencySlippage = emergencySlippageValue;
    }

    /**
     * @dev Internal function to validate slippage
     * @param tokenIn Input token
     * @param tokenOut Output token
     * @param amountIn Input amount
     * @param minAmountOut Minimum output amount
     */
    function _validateSlippage(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut
    ) internal view {
        uint256 expectedAmountOut = _getExpectedOutput(tokenIn, tokenOut, amountIn);
        uint256 maxSlippage = _getMaxSlippage(tokenIn);
        
        uint256 minExpected = expectedAmountOut * (BASIS_POINTS - maxSlippage) / BASIS_POINTS;
        require(minAmountOut >= minExpected, "Slippage protection triggered");
    }

    /**
     * @dev Internal function to detect MEV
     * @param user User address
     */
    function _detectMEV(address user) internal {
        // Check gas price
        if (tx.gasprice > mevProtection.gasThreshold) {
            emit MEVDetected(user, "HIGH_GAS_PRICE", 1);
        }
        
        // Additional MEV detection logic would go here
    }

    /**
     * @dev Get expected output amount
     * @param tokenIn Input token
     * @param tokenOut Output token
     * @param amountIn Input amount
     * @return expectedAmount Expected output amount
     */
    function _getExpectedOutput(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) internal view returns (uint256 expectedAmount) {
        // Simplified calculation - in practice would use price oracles
        // For now, assume 1:1 ratio with some variation
        expectedAmount = amountIn * 99 / 100; // 1% fee simulation
    }

    /**
     * @dev Get maximum slippage for a token
     * @param token Token address
     * @return maxSlippage Maximum slippage in basis points
     */
    function _getMaxSlippage(address token) internal view returns (uint256 maxSlippage) {
        SlippageProtection memory protection = slippageProtection[token];
        
        if (protection.isActive) {
            maxSlippage = protection.maxSlippage;
        } else {
            maxSlippage = emergencyMode ? emergencySlippage : defaultMaxSlippage;
        }
    }

    /**
     * @dev Execute the actual trade
     * @param tokenIn Input token
     * @param tokenOut Output token
     * @param amountIn Input amount
     * @return amountOut Output amount
     */
    function _executeTrade(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) internal returns (uint256 amountOut) {
        // Simplified trade execution - in practice would integrate with DEX
        // Transfer tokens from user
        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);
        
        // Calculate output (simplified)
        amountOut = _getExpectedOutput(tokenIn, tokenOut, amountIn);
        
        // Transfer output tokens to user
        IERC20(tokenOut).safeTransfer(msg.sender, amountOut);
    }

    /**
     * @dev Record trade execution
     * @param tokenIn Input token
     * @param tokenOut Output token
     * @param amountIn Input amount
     * @param expectedAmountOut Expected output
     * @param actualAmountOut Actual output
     * @param slippage Actual slippage
     * @return tradeId Trade ID
     */
    function _recordTradeExecution(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 expectedAmountOut,
        uint256 actualAmountOut,
        uint256 slippage
    ) internal returns (bytes32 tradeId) {
        tradeId = keccak256(abi.encodePacked(
            msg.sender,
            tokenIn,
            tokenOut,
            amountIn,
            block.timestamp,
            userNonces[msg.sender]++
        ));
        
        tradeExecutions[tradeId] = TradeExecution({
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            amountIn: amountIn,
            expectedAmountOut: expectedAmountOut,
            actualAmountOut: actualAmountOut,
            slippage: slippage,
            timestamp: block.timestamp,
            isProtected: true
        });
    }

    /**
     * @dev Detect sandwich attack
     * @param user User address
     * @param tokenIn Input token
     * @param tokenOut Output token
     * @param amountIn Input amount
     * @return isSandwich True if sandwich attack detected
     */
    function _detectSandwichAttack(
        address user,
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) internal view returns (bool isSandwich) {
        // Simplified sandwich detection - in practice would be more sophisticated
        // Check if there are large trades in the same block
        return false; // Placeholder
    }

    /**
     * @dev Detect flashloan MEV
     * @param user User address
     * @return isFlashloanMEV True if flashloan MEV detected
     */
    function _detectFlashloanMEV(address user) internal view returns (bool isFlashloanMEV) {
        // Simplified flashloan MEV detection
        // Check if user has unusual balance changes in the same transaction
        return false; // Placeholder
    }

    /**
     * @dev Get trade execution details
     * @param tradeId Trade ID
     * @return execution Trade execution details
     */
    function getTradeExecution(bytes32 tradeId) external view returns (TradeExecution memory execution) {
        return tradeExecutions[tradeId];
    }

    /**
     * @dev Get slippage protection settings
     * @param token Token address
     * @return protection Slippage protection settings
     */
    function getSlippageProtection(address token) external view returns (SlippageProtection memory protection) {
        return slippageProtection[token];
    }

    /**
     * @dev Get MEV protection settings
     * @return protection MEV protection settings
     */
    function getMEVProtection() external view returns (MEVProtection memory protection) {
        return mevProtection;
    }

    /**
     * @dev Pause contract
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev Unpause contract
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @dev Emergency token recovery
     * @param token Token to recover
     * @param amount Amount to recover
     */
    function emergencyRecovery(address token, uint256 amount) external onlyOwner {
        IERC20(token).safeTransfer(owner(), amount);
    }
}