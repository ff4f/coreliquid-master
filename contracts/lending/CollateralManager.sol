// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title CollateralManager
 * @dev Manages collateral for lending positions
 */
contract CollateralManager is AccessControl, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;
    using Math for uint256;
    
    bytes32 public constant COLLATERAL_MANAGER_ROLE = keccak256("COLLATERAL_MANAGER_ROLE");
    bytes32 public constant PRICE_ORACLE_ROLE = keccak256("PRICE_ORACLE_ROLE");
    bytes32 public constant LIQUIDATOR_ROLE = keccak256("LIQUIDATOR_ROLE");
    
    struct CollateralConfig {
        uint256 collateralFactor; // Maximum LTV for this collateral (basis points)
        uint256 liquidationThreshold; // Liquidation threshold (basis points)
        uint256 liquidationPenalty; // Liquidation penalty (basis points)
        uint256 minCollateralAmount; // Minimum collateral amount
        uint256 maxCollateralAmount; // Maximum collateral amount
        bool isActive; // Whether this collateral is active
        bool requiresOracle; // Whether this collateral requires price oracle
        address priceOracle; // Price oracle for this collateral
    }
    
    struct CollateralPosition {
        address token;
        uint256 amount;
        uint256 lockedAmount; // Amount locked for borrowing
        uint256 lastUpdateTime;
        uint256 accruedRewards;
        bool isActive;
    }
    
    struct PriceData {
        uint256 price; // Price in USD with 18 decimals
        uint256 lastUpdate;
        uint256 confidence; // Price confidence level (basis points)
        bool isValid;
    }
    
    mapping(address => CollateralConfig) public collateralConfigs;
    mapping(address => mapping(address => CollateralPosition)) public userCollateral; // user -> token -> position
    mapping(address => PriceData) public tokenPrices;
    mapping(address => address[]) public userCollateralTokens; // user -> tokens array
    mapping(address => uint256) public totalCollateralDeposited;
    mapping(address => uint256) public totalCollateralLocked;
    
    address[] public supportedCollaterals;
    
    uint256 public constant PRICE_STALENESS_THRESHOLD = 1 hours;
    uint256 public constant MAX_COLLATERAL_TYPES = 50;
    uint256 public constant BASIS_POINTS = 10000;
    
    event CollateralDeposited(
        address indexed user,
        address indexed token,
        uint256 amount,
        uint256 newBalance
    );
    
    event CollateralWithdrawn(
        address indexed user,
        address indexed token,
        uint256 amount,
        uint256 newBalance
    );
    
    event CollateralLocked(
        address indexed user,
        address indexed token,
        uint256 amount,
        uint256 totalLocked
    );
    
    event CollateralUnlocked(
        address indexed user,
        address indexed token,
        uint256 amount,
        uint256 totalLocked
    );
    
    event CollateralSeized(
        address indexed user,
        address indexed token,
        uint256 amount,
        address indexed liquidator
    );
    
    event CollateralConfigUpdated(
        address indexed token,
        uint256 collateralFactor,
        uint256 liquidationThreshold,
        bool isActive
    );
    
    event PriceUpdated(
        address indexed token,
        uint256 oldPrice,
        uint256 newPrice,
        uint256 confidence
    );
    
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(COLLATERAL_MANAGER_ROLE, msg.sender);
        _grantRole(PRICE_ORACLE_ROLE, msg.sender);
    }
    
    function depositCollateral(
        address token,
        uint256 amount
    ) external nonReentrant whenNotPaused {
        require(amount > 0, "Invalid amount");
        require(isValidCollateral(token), "Invalid collateral token");
        
        CollateralConfig memory config = collateralConfigs[token];
        require(config.isActive, "Collateral not active");
        
        CollateralPosition storage position = userCollateral[msg.sender][token];
        
        // Check minimum amount
        uint256 newAmount = position.amount + amount;
        require(newAmount >= config.minCollateralAmount, "Below minimum collateral");
        require(newAmount <= config.maxCollateralAmount, "Above maximum collateral");
        
        // Transfer tokens
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        
        // Update position
        if (!position.isActive) {
            position.token = token;
            position.isActive = true;
            userCollateralTokens[msg.sender].push(token);
        }
        
        position.amount += amount;
        position.lastUpdateTime = block.timestamp;
        
        // Update global stats
        totalCollateralDeposited[token] += amount;
        
        emit CollateralDeposited(msg.sender, token, amount, position.amount);
    }
    
    function withdrawCollateral(
        address token,
        uint256 amount,
        address to
    ) external nonReentrant whenNotPaused {
        require(amount > 0, "Invalid amount");
        require(to != address(0), "Invalid recipient");
        
        CollateralPosition storage position = userCollateral[msg.sender][token];
        require(position.isActive, "No collateral position");
        require(position.amount >= amount, "Insufficient collateral");
        
        // Check if amount is available (not locked)
        uint256 availableAmount = position.amount - position.lockedAmount;
        require(availableAmount >= amount, "Insufficient available collateral");
        
        // Check minimum remaining amount
        CollateralConfig memory config = collateralConfigs[token];
        uint256 remainingAmount = position.amount - amount;
        if (remainingAmount > 0) {
            require(remainingAmount >= config.minCollateralAmount, "Below minimum collateral");
        }
        
        // Update position
        position.amount -= amount;
        position.lastUpdateTime = block.timestamp;
        
        if (position.amount == 0) {
            position.isActive = false;
            _removeUserCollateralToken(msg.sender, token);
        }
        
        // Update global stats
        totalCollateralDeposited[token] -= amount;
        
        // Transfer tokens
        IERC20(token).safeTransfer(to, amount);
        
        emit CollateralWithdrawn(msg.sender, token, amount, position.amount);
    }
    
    function lockCollateral(
        address user,
        address token,
        uint256 amount
    ) external onlyRole(COLLATERAL_MANAGER_ROLE) {
        require(amount > 0, "Invalid amount");
        
        CollateralPosition storage position = userCollateral[user][token];
        require(position.isActive, "No collateral position");
        require(position.amount >= position.lockedAmount + amount, "Insufficient collateral");
        
        position.lockedAmount += amount;
        totalCollateralLocked[token] += amount;
        
        emit CollateralLocked(user, token, amount, position.lockedAmount);
    }
    
    function unlockCollateral(
        address user,
        address token,
        uint256 amount
    ) external onlyRole(COLLATERAL_MANAGER_ROLE) {
        require(amount > 0, "Invalid amount");
        
        CollateralPosition storage position = userCollateral[user][token];
        require(position.isActive, "No collateral position");
        require(position.lockedAmount >= amount, "Insufficient locked collateral");
        
        position.lockedAmount -= amount;
        totalCollateralLocked[token] -= amount;
        
        emit CollateralUnlocked(user, token, amount, position.lockedAmount);
    }
    
    function seizeCollateral(
        address user,
        address token,
        uint256 amount,
        address liquidator
    ) external onlyRole(LIQUIDATOR_ROLE) returns (uint256 seizedAmount) {
        require(amount > 0, "Invalid amount");
        require(liquidator != address(0), "Invalid liquidator");
        
        CollateralPosition storage position = userCollateral[user][token];
        require(position.isActive, "No collateral position");
        
        // Calculate actual seizable amount
        seizedAmount = Math.min(amount, position.lockedAmount);
        require(seizedAmount > 0, "No collateral to seize");
        
        // Update position
        position.amount -= seizedAmount;
        position.lockedAmount -= seizedAmount;
        position.lastUpdateTime = block.timestamp;
        
        if (position.amount == 0) {
            position.isActive = false;
            _removeUserCollateralToken(user, token);
        }
        
        // Update global stats
        totalCollateralDeposited[token] -= seizedAmount;
        totalCollateralLocked[token] -= seizedAmount;
        
        // Transfer to liquidator
        IERC20(token).safeTransfer(liquidator, seizedAmount);
        
        emit CollateralSeized(user, token, seizedAmount, liquidator);
    }
    
    function getCollateralValue(
        address token,
        uint256 amount
    ) external view returns (uint256 value) {
        require(isValidCollateral(token), "Invalid collateral");
        
        PriceData memory priceData = tokenPrices[token];
        require(priceData.isValid, "Price not available");
        require(
            block.timestamp - priceData.lastUpdate <= PRICE_STALENESS_THRESHOLD,
            "Price too stale"
        );
        
        // Calculate value in USD (18 decimals)
        value = (amount * priceData.price) / 1e18;
    }
    
    function getUserCollateralValue(address user) external view returns (uint256 totalValue) {
        address[] memory tokens = userCollateralTokens[user];
        
        for (uint256 i = 0; i < tokens.length; i++) {
            address token = tokens[i];
            CollateralPosition memory position = userCollateral[user][token];
            
            if (position.isActive && position.amount > 0) {
                uint256 tokenValue = this.getCollateralValue(token, position.amount);
                totalValue += tokenValue;
            }
        }
    }
    
    function getUserAvailableCollateral(
        address user,
        address token
    ) external view returns (uint256 available) {
        CollateralPosition memory position = userCollateral[user][token];
        if (position.isActive) {
            available = position.amount - position.lockedAmount;
        }
    }
    
    function getUserCollateralTokens(address user) external view returns (address[] memory) {
        return userCollateralTokens[user];
    }
    
    function calculateMaxBorrow(
        address user,
        address collateralToken,
        address borrowToken
    ) external view returns (uint256 maxBorrow) {
        CollateralPosition memory position = userCollateral[user][collateralToken];
        if (!position.isActive) return 0;
        
        CollateralConfig memory config = collateralConfigs[collateralToken];
        if (!config.isActive) return 0;
        
        uint256 availableCollateral = position.amount - position.lockedAmount;
        if (availableCollateral == 0) return 0;
        
        uint256 collateralValue = this.getCollateralValue(collateralToken, availableCollateral);
        
        // Apply collateral factor
        uint256 borrowCapacity = (collateralValue * config.collateralFactor) / BASIS_POINTS;
        
        // Convert to borrow token amount (assuming 1:1 for simplicity)
        maxBorrow = borrowCapacity;
    }
    
    function updatePrice(
        address token,
        uint256 price,
        uint256 confidence
    ) external onlyRole(PRICE_ORACLE_ROLE) {
        require(isValidCollateral(token), "Invalid collateral");
        require(price > 0, "Invalid price");
        require(confidence <= BASIS_POINTS, "Invalid confidence");
        
        PriceData storage priceData = tokenPrices[token];
        uint256 oldPrice = priceData.price;
        
        priceData.price = price;
        priceData.lastUpdate = block.timestamp;
        priceData.confidence = confidence;
        priceData.isValid = true;
        
        emit PriceUpdated(token, oldPrice, price, confidence);
    }
    
    function batchUpdatePrices(
        address[] calldata tokens,
        uint256[] calldata prices,
        uint256[] calldata confidences
    ) external onlyRole(PRICE_ORACLE_ROLE) {
        require(
            tokens.length == prices.length && prices.length == confidences.length,
            "Array length mismatch"
        );
        
        for (uint256 i = 0; i < tokens.length; i++) {
            this.updatePrice(tokens[i], prices[i], confidences[i]);
        }
    }
    
    function addCollateralType(
        address token,
        CollateralConfig memory config
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(token != address(0), "Invalid token");
        require(!isValidCollateral(token), "Collateral already exists");
        require(supportedCollaterals.length < MAX_COLLATERAL_TYPES, "Too many collateral types");
        require(config.collateralFactor <= 9000, "Collateral factor too high"); // Max 90%
        require(config.liquidationThreshold > config.collateralFactor, "Invalid liquidation threshold");
        require(config.liquidationPenalty <= 2000, "Penalty too high"); // Max 20%
        
        collateralConfigs[token] = config;
        supportedCollaterals.push(token);
        
        emit CollateralConfigUpdated(
            token,
            config.collateralFactor,
            config.liquidationThreshold,
            config.isActive
        );
    }
    
    function updateCollateralConfig(
        address token,
        CollateralConfig memory config
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(isValidCollateral(token), "Invalid collateral");
        require(config.collateralFactor <= 9000, "Collateral factor too high");
        require(config.liquidationThreshold > config.collateralFactor, "Invalid liquidation threshold");
        require(config.liquidationPenalty <= 2000, "Penalty too high");
        
        collateralConfigs[token] = config;
        
        emit CollateralConfigUpdated(
            token,
            config.collateralFactor,
            config.liquidationThreshold,
            config.isActive
        );
    }
    
    function removeCollateralType(address token) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(isValidCollateral(token), "Invalid collateral");
        require(totalCollateralDeposited[token] == 0, "Collateral still in use");
        
        // Remove from supported collaterals array
        for (uint256 i = 0; i < supportedCollaterals.length; i++) {
            if (supportedCollaterals[i] == token) {
                supportedCollaterals[i] = supportedCollaterals[supportedCollaterals.length - 1];
                supportedCollaterals.pop();
                break;
            }
        }
        
        delete collateralConfigs[token];
        delete tokenPrices[token];
    }
    
    function isValidCollateral(address token) public view returns (bool) {
        return collateralConfigs[token].collateralFactor > 0;
    }
    
    function getSupportedCollaterals() external view returns (address[] memory) {
        return supportedCollaterals;
    }
    
    function getCollateralStats(address token) external view returns (
        uint256 totalDeposited,
        uint256 totalLocked,
        uint256 utilizationRate,
        uint256 currentPrice
    ) {
        totalDeposited = totalCollateralDeposited[token];
        totalLocked = totalCollateralLocked[token];
        utilizationRate = totalDeposited > 0 ? (totalLocked * BASIS_POINTS) / totalDeposited : 0;
        currentPrice = tokenPrices[token].price;
    }
    
    function _removeUserCollateralToken(address user, address token) internal {
        address[] storage tokens = userCollateralTokens[user];
        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i] == token) {
                tokens[i] = tokens[tokens.length - 1];
                tokens.pop();
                break;
            }
        }
    }
    
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }
    
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
    
    function emergencyWithdraw(
        address token,
        uint256 amount,
        address to
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(to != address(0), "Invalid recipient");
        IERC20(token).safeTransfer(to, amount);
    }
}
