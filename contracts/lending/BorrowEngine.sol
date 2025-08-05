// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "../interfaces/ipriceoracle.sol";
import "../interfaces/IInterestRateModel.sol";

/**
 * @title BorrowEngine
 * @dev Core borrowing engine for Core protocol lending system
 */
contract BorrowEngine is Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;
    using Math for uint256;

    struct BorrowPosition {
        uint256 borrowAmount; // Amount borrowed
        uint256 collateralAmount; // Collateral deposited
        uint256 borrowIndex; // Interest index at borrow time
        uint256 lastUpdateTime; // Last interest update
        address collateralToken; // Collateral token address
        address borrowToken; // Borrowed token address
        bool isActive; // Position status
        uint256 liquidationThreshold; // Liquidation threshold
        uint256 healthFactor; // Current health factor
    }

    struct MarketConfig {
        uint256 collateralFactor; // Collateral factor (basis points)
        uint256 liquidationThreshold; // Liquidation threshold (basis points)
        uint256 liquidationBonus; // Liquidation bonus (basis points)
        uint256 borrowCap; // Maximum borrow amount
        uint256 supplyCap; // Maximum supply amount
        uint256 reserveFactor; // Reserve factor (basis points)
        bool isActive; // Market active status
        bool borrowEnabled; // Borrowing enabled
        bool collateralEnabled; // Collateral enabled
        address interestRateModel; // Interest rate model
    }

    struct UserAccountData {
        uint256 totalCollateralETH; // Total collateral in ETH
        uint256 totalBorrowsETH; // Total borrows in ETH
        uint256 availableBorrowsETH; // Available borrows in ETH
        uint256 currentLiquidationThreshold; // Current liquidation threshold
        uint256 ltv; // Loan to value ratio
        uint256 healthFactor; // Health factor
    }

    struct InterestRateData {
        uint256 borrowRate; // Current borrow rate
        uint256 supplyRate; // Current supply rate
        uint256 borrowIndex; // Cumulative borrow index
        uint256 supplyIndex; // Cumulative supply index
        uint256 lastUpdateTimestamp; // Last update timestamp
        uint256 totalBorrows; // Total borrows
        uint256 totalSupply; // Total supply
        uint256 totalReserves; // Total reserves
    }

    mapping(address => mapping(address => BorrowPosition)) public borrowPositions;
    mapping(address => MarketConfig) public marketConfigs;
    mapping(address => InterestRateData) public interestRates;
    mapping(address => mapping(address => uint256)) public userBorrows;
    mapping(address => mapping(address => uint256)) public userCollateral;
    mapping(address => bool) public authorizedLiquidators;
    mapping(address => uint256) public borrowCaps;
    mapping(address => uint256) public supplyCaps;
    
    address public priceOracle;
    address public liquidationEngine;
    address public treasury;
    
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant HEALTH_FACTOR_LIQUIDATION_THRESHOLD = 1e18;
    uint256 public constant MAX_COLLATERAL_FACTOR = 9000; // 90%
    uint256 public constant MAX_LIQUIDATION_THRESHOLD = 9500; // 95%
    uint256 public constant MAX_LIQUIDATION_BONUS = 1500; // 15%
    uint256 public constant MAX_RESERVE_FACTOR = 2000; // 20%
    
    uint256 public defaultCollateralFactor = 7500; // 75%
    uint256 public defaultLiquidationThreshold = 8500; // 85%
    uint256 public defaultLiquidationBonus = 500; // 5%
    uint256 public defaultReserveFactor = 1000; // 10%
    
    bool public borrowingEnabled = true;
    bool public liquidationEnabled = true;
    
    event Borrow(
        address indexed user,
        address indexed borrowToken,
        address indexed collateralToken,
        uint256 borrowAmount,
        uint256 collateralAmount
    );
    
    event Repay(
        address indexed user,
        address indexed borrowToken,
        uint256 repayAmount,
        uint256 remainingBorrow
    );
    
    event CollateralDeposited(
        address indexed user,
        address indexed token,
        uint256 amount
    );
    
    event CollateralWithdrawn(
        address indexed user,
        address indexed token,
        uint256 amount
    );
    
    event MarketConfigUpdated(
        address indexed token,
        MarketConfig config
    );
    
    event InterestAccrued(
        address indexed token,
        uint256 borrowIndex,
        uint256 totalBorrows
    );
    
    event LiquidationCall(
        address indexed liquidator,
        address indexed borrower,
        address indexed collateralToken,
        uint256 liquidatedAmount,
        uint256 collateralSeized
    );

    modifier onlyLiquidationEngine() {
        require(msg.sender == liquidationEngine, "Only liquidation engine");
        _;
    }

    modifier marketActive(address token) {
        require(marketConfigs[token].isActive, "Market not active");
        _;
    }

    modifier borrowingAllowed(address token) {
        require(borrowingEnabled && marketConfigs[token].borrowEnabled, "Borrowing not allowed");
        _;
    }

    constructor(
        address _priceOracle,
        address _treasury
    ) Ownable(msg.sender) {
        require(_priceOracle != address(0), "Invalid price oracle");
        require(_treasury != address(0), "Invalid treasury");
        
        priceOracle = _priceOracle;
        treasury = _treasury;
    }

    /**
     * @dev Borrow tokens against collateral
     * @param borrowToken Token to borrow
     * @param collateralToken Collateral token
     * @param borrowAmount Amount to borrow
     * @param collateralAmount Collateral amount
     */
    function borrow(
        address borrowToken,
        address collateralToken,
        uint256 borrowAmount,
        uint256 collateralAmount
    ) external 
        nonReentrant 
        whenNotPaused 
        marketActive(borrowToken)
        marketActive(collateralToken)
        borrowingAllowed(borrowToken)
    {
        require(borrowAmount > 0, "Invalid borrow amount");
        require(collateralAmount > 0, "Invalid collateral amount");
        
        // Update interest rates
        _accrueInterest(borrowToken);
        _accrueInterest(collateralToken);
        
        // Check borrow cap
        require(
            interestRates[borrowToken].totalBorrows + borrowAmount <= borrowCaps[borrowToken],
            "Borrow cap exceeded"
        );
        
        // Transfer collateral from user
        IERC20(collateralToken).safeTransferFrom(msg.sender, address(this), collateralAmount);
        
        // Validate borrow capacity
        require(_validateBorrow(msg.sender, borrowToken, collateralToken, borrowAmount, collateralAmount), "Insufficient collateral");
        
        // Update user position
        BorrowPosition storage position = borrowPositions[msg.sender][borrowToken];
        position.borrowAmount += borrowAmount;
        position.collateralAmount += collateralAmount;
        position.borrowIndex = interestRates[borrowToken].borrowIndex;
        position.lastUpdateTime = block.timestamp;
        position.collateralToken = collateralToken;
        position.borrowToken = borrowToken;
        position.isActive = true;
        position.liquidationThreshold = marketConfigs[collateralToken].liquidationThreshold;
        
        // Update global state
        userBorrows[msg.sender][borrowToken] += borrowAmount;
        userCollateral[msg.sender][collateralToken] += collateralAmount;
        interestRates[borrowToken].totalBorrows += borrowAmount;
        
        // Transfer borrowed tokens to user
        IERC20(borrowToken).safeTransfer(msg.sender, borrowAmount);
        
        // Update health factor
        position.healthFactor = _calculateHealthFactor(msg.sender);
        
        emit Borrow(msg.sender, borrowToken, collateralToken, borrowAmount, collateralAmount);
        emit CollateralDeposited(msg.sender, collateralToken, collateralAmount);
    }

    /**
     * @dev Repay borrowed tokens
     * @param borrowToken Token to repay
     * @param repayAmount Amount to repay
     */
    function repay(
        address borrowToken,
        uint256 repayAmount
    ) external nonReentrant whenNotPaused {
        require(repayAmount > 0, "Invalid repay amount");
        
        // Update interest rates
        _accrueInterest(borrowToken);
        
        BorrowPosition storage position = borrowPositions[msg.sender][borrowToken];
        require(position.isActive, "No active borrow position");
        
        // Calculate current borrow balance with interest
        uint256 currentBorrowBalance = _getBorrowBalance(msg.sender, borrowToken);
        
        // Determine actual repay amount
        uint256 actualRepayAmount = Math.min(repayAmount, currentBorrowBalance);
        
        // Transfer repay amount from user
        IERC20(borrowToken).safeTransferFrom(msg.sender, address(this), actualRepayAmount);
        
        // Update position
        position.borrowAmount = currentBorrowBalance - actualRepayAmount;
        position.borrowIndex = interestRates[borrowToken].borrowIndex;
        position.lastUpdateTime = block.timestamp;
        
        // Update global state
        userBorrows[msg.sender][borrowToken] = position.borrowAmount;
        interestRates[borrowToken].totalBorrows -= actualRepayAmount;
        
        // Update health factor
        position.healthFactor = _calculateHealthFactor(msg.sender);
        
        // If fully repaid, mark as inactive
        if (position.borrowAmount == 0) {
            position.isActive = false;
        }
        
        emit Repay(msg.sender, borrowToken, actualRepayAmount, position.borrowAmount);
    }

    /**
     * @dev Withdraw collateral
     * @param collateralToken Collateral token to withdraw
     * @param withdrawAmount Amount to withdraw
     */
    function withdrawCollateral(
        address collateralToken,
        uint256 withdrawAmount
    ) external nonReentrant whenNotPaused {
        require(withdrawAmount > 0, "Invalid withdraw amount");
        require(userCollateral[msg.sender][collateralToken] >= withdrawAmount, "Insufficient collateral");
        
        // Update interest rates for all borrowed tokens
        _accrueAllInterests(msg.sender);
        
        // Check if withdrawal maintains health factor
        require(_validateCollateralWithdrawal(msg.sender, collateralToken, withdrawAmount), "Would cause liquidation");
        
        // Update collateral
        userCollateral[msg.sender][collateralToken] -= withdrawAmount;
        
        // Update position collateral
        // Note: This is simplified - in practice would need to handle multiple positions
        BorrowPosition storage position = borrowPositions[msg.sender][collateralToken];
        if (position.isActive && position.collateralToken == collateralToken) {
            position.collateralAmount -= withdrawAmount;
            position.healthFactor = _calculateHealthFactor(msg.sender);
        }
        
        // Transfer collateral to user
        IERC20(collateralToken).safeTransfer(msg.sender, withdrawAmount);
        
        emit CollateralWithdrawn(msg.sender, collateralToken, withdrawAmount);
    }

    /**
     * @dev Liquidate undercollateralized position
     * @param borrower Borrower to liquidate
     * @param borrowToken Borrowed token
     * @param collateralToken Collateral token
     * @param repayAmount Amount to repay
     */
    function liquidate(
        address borrower,
        address borrowToken,
        address collateralToken,
        uint256 repayAmount
    ) external nonReentrant whenNotPaused onlyLiquidationEngine {
        require(liquidationEnabled, "Liquidation disabled");
        require(borrower != msg.sender, "Cannot liquidate self");
        
        // Update interest rates
        _accrueInterest(borrowToken);
        _accrueInterest(collateralToken);
        
        BorrowPosition storage position = borrowPositions[borrower][borrowToken];
        require(position.isActive, "No active position");
        
        // Check if position is liquidatable
        uint256 healthFactor = _calculateHealthFactor(borrower);
        require(healthFactor < HEALTH_FACTOR_LIQUIDATION_THRESHOLD, "Position not liquidatable");
        
        // Calculate liquidation amounts
        (uint256 actualRepayAmount, uint256 collateralSeized) = _calculateLiquidationAmounts(
            borrower,
            borrowToken,
            collateralToken,
            repayAmount
        );
        
        // Transfer repay amount from liquidator
        IERC20(borrowToken).safeTransferFrom(msg.sender, address(this), actualRepayAmount);
        
        // Update borrower position
        uint256 currentBorrowBalance = _getBorrowBalance(borrower, borrowToken);
        position.borrowAmount = currentBorrowBalance - actualRepayAmount;
        position.collateralAmount -= collateralSeized;
        position.borrowIndex = interestRates[borrowToken].borrowIndex;
        position.lastUpdateTime = block.timestamp;
        
        // Update global state
        userBorrows[borrower][borrowToken] = position.borrowAmount;
        userCollateral[borrower][collateralToken] -= collateralSeized;
        interestRates[borrowToken].totalBorrows -= actualRepayAmount;
        
        // Transfer seized collateral to liquidator
        IERC20(collateralToken).safeTransfer(msg.sender, collateralSeized);
        
        // Update health factor
        position.healthFactor = _calculateHealthFactor(borrower);
        
        // If fully repaid, mark as inactive
        if (position.borrowAmount == 0) {
            position.isActive = false;
        }
        
        emit LiquidationCall(msg.sender, borrower, collateralToken, actualRepayAmount, collateralSeized);
    }

    /**
     * @dev Get user account data
     * @param user User address
     * @return accountData User account data
     */
    function getUserAccountData(address user) external view returns (UserAccountData memory accountData) {
        // This would calculate comprehensive user data across all positions
        // Simplified implementation
        accountData.healthFactor = _calculateHealthFactor(user);
        // Additional calculations would go here
    }

    /**
     * @dev Get borrow balance with accrued interest
     * @param user User address
     * @param token Borrow token
     * @return balance Current borrow balance
     */
    function getBorrowBalance(address user, address token) external view returns (uint256 balance) {
        return _getBorrowBalance(user, token);
    }

    /**
     * @dev Get user collateral balance
     * @param user User address
     * @param token Collateral token
     * @return balance Collateral balance
     */
    function getCollateralBalance(address user, address token) external view returns (uint256 balance) {
        return userCollateral[user][token];
    }

    /**
     * @dev Get user health factor
     * @param user User address
     * @return healthFactor Current health factor
     */
    function getHealthFactor(address user) external view returns (uint256 healthFactor) {
        return _calculateHealthFactor(user);
    }

    /**
     * @dev Get position health (alias for getHealthFactor)
     * @param user User address
     * @return healthFactor Current health factor
     */
    function getPositionHealth(address user) external view returns (uint256 healthFactor) {
        return _calculateHealthFactor(user);
    }

    /**
     * @dev Check if position is liquidatable
     * @param user User address
     * @return isLiquidatable True if liquidatable
     */
    function isLiquidatable(address user) external view returns (bool) {
        uint256 healthFactor = _calculateHealthFactor(user);
        return healthFactor < HEALTH_FACTOR_LIQUIDATION_THRESHOLD;
    }

    /**
     * @dev Set market configuration
     * @param token Token address
     * @param config Market configuration
     */
    function setMarketConfig(address token, MarketConfig memory config) external onlyOwner {
        require(token != address(0), "Invalid token");
        require(config.collateralFactor <= MAX_COLLATERAL_FACTOR, "Collateral factor too high");
        require(config.liquidationThreshold <= MAX_LIQUIDATION_THRESHOLD, "Liquidation threshold too high");
        require(config.liquidationBonus <= MAX_LIQUIDATION_BONUS, "Liquidation bonus too high");
        require(config.reserveFactor <= MAX_RESERVE_FACTOR, "Reserve factor too high");
        
        marketConfigs[token] = config;
        emit MarketConfigUpdated(token, config);
    }

    /**
     * @dev Set price oracle
     * @param newPriceOracle New price oracle address
     */
    function setPriceOracle(address newPriceOracle) external onlyOwner {
        require(newPriceOracle != address(0), "Invalid price oracle");
        priceOracle = newPriceOracle;
    }

    /**
     * @dev Set liquidation engine
     * @param newLiquidationEngine New liquidation engine address
     */
    function setLiquidationEngine(address newLiquidationEngine) external onlyOwner {
        require(newLiquidationEngine != address(0), "Invalid liquidation engine");
        liquidationEngine = newLiquidationEngine;
    }

    /**
     * @dev Set borrow cap
     * @param token Token address
     * @param newBorrowCap New borrow cap
     */
    function setBorrowCap(address token, uint256 newBorrowCap) external onlyOwner {
        borrowCaps[token] = newBorrowCap;
    }

    /**
     * @dev Set supply cap
     * @param token Token address
     * @param newSupplyCap New supply cap
     */
    function setSupplyCap(address token, uint256 newSupplyCap) external onlyOwner {
        supplyCaps[token] = newSupplyCap;
    }

    /**
     * @dev Toggle borrowing enabled
     * @param enabled Borrowing enabled status
     */
    function setBorrowingEnabled(bool enabled) external onlyOwner {
        borrowingEnabled = enabled;
    }

    /**
     * @dev Toggle liquidation enabled
     * @param enabled Liquidation enabled status
     */
    function setLiquidationEnabled(bool enabled) external onlyOwner {
        liquidationEnabled = enabled;
    }

    /**
     * @dev Accrue interest for a token
     * @param token Token address
     */
    function accrueInterest(address token) external {
        _accrueInterest(token);
    }

    /**
     * @dev Internal function to validate borrow
     * @param user User address
     * @param borrowToken Borrow token
     * @param collateralToken Collateral token
     * @param borrowAmount Borrow amount
     * @param collateralAmount Collateral amount
     * @return isValid True if valid
     */
    function _validateBorrow(
        address user,
        address borrowToken,
        address collateralToken,
        uint256 borrowAmount,
        uint256 collateralAmount
    ) internal view returns (bool isValid) {
        // Get token prices
        (uint256 borrowPrice,) = IPriceOracle(priceOracle).getPrice(borrowToken);
        (uint256 collateralPrice,) = IPriceOracle(priceOracle).getPrice(collateralToken);
        
        // Calculate values in ETH
        uint256 borrowValueETH = borrowAmount * borrowPrice / 1e18;
        uint256 collateralValueETH = collateralAmount * collateralPrice / 1e18;
        
        // Apply collateral factor
        uint256 collateralFactor = marketConfigs[collateralToken].collateralFactor;
        uint256 maxBorrowValueETH = collateralValueETH * collateralFactor / BASIS_POINTS;
        
        return borrowValueETH <= maxBorrowValueETH;
    }

    /**
     * @dev Internal function to validate collateral withdrawal
     * @param user User address
     * @param collateralToken Collateral token
     * @param withdrawAmount Withdraw amount
     * @return isValid True if valid
     */
    function _validateCollateralWithdrawal(
        address user,
        address collateralToken,
        uint256 withdrawAmount
    ) internal view returns (bool isValid) {
        // Calculate health factor after withdrawal
        // Simplified implementation
        uint256 currentHealthFactor = _calculateHealthFactor(user);
        
        // For simplicity, require health factor > 1.2 after withdrawal
        return currentHealthFactor > 12e17; // 1.2
    }

    /**
     * @dev Internal function to calculate health factor
     * @param user User address
     * @return healthFactor Health factor
     */
    function _calculateHealthFactor(address user) internal view returns (uint256 healthFactor) {
        // Simplified health factor calculation
        // In practice, would iterate through all user positions
        return 15e17; // 1.5 - placeholder
    }

    /**
     * @dev Internal function to get borrow balance with interest
     * @param user User address
     * @param token Borrow token
     * @return balance Current balance
     */
    function _getBorrowBalance(address user, address token) internal view returns (uint256 balance) {
        BorrowPosition memory position = borrowPositions[user][token];
        if (!position.isActive) {
            return 0;
        }
        
        // Calculate accrued interest
        uint256 currentIndex = interestRates[token].borrowIndex;
        uint256 positionIndex = position.borrowIndex;
        
        if (currentIndex == 0 || positionIndex == 0) {
            return position.borrowAmount;
        }
        
        return position.borrowAmount * currentIndex / positionIndex;
    }

    /**
     * @dev Internal function to accrue interest
     * @param token Token address
     */
    function _accrueInterest(address token) internal {
        InterestRateData storage rateData = interestRates[token];
        
        if (rateData.lastUpdateTimestamp == block.timestamp) {
            return;
        }
        
        uint256 timeDelta = block.timestamp - rateData.lastUpdateTimestamp;
        
        if (timeDelta > 0 && rateData.totalBorrows > 0) {
            // Get current borrow rate from interest rate model
            uint256 borrowRate = rateData.borrowRate;
            
            // Calculate interest
            uint256 interestAccumulated = rateData.totalBorrows * borrowRate * timeDelta / (365 days * 1e18);
            
            // Update borrow index
            rateData.borrowIndex = rateData.borrowIndex * (1e18 + borrowRate * timeDelta / (365 days)) / 1e18;
            
            // Update total borrows
            rateData.totalBorrows += interestAccumulated;
            
            // Update reserves
            uint256 reserveFactor = marketConfigs[token].reserveFactor;
            uint256 reserveAmount = interestAccumulated * reserveFactor / BASIS_POINTS;
            rateData.totalReserves += reserveAmount;
        }
        
        rateData.lastUpdateTimestamp = block.timestamp;
        
        emit InterestAccrued(token, rateData.borrowIndex, rateData.totalBorrows);
    }

    /**
     * @dev Internal function to accrue interest for all user positions
     * @param user User address
     */
    function _accrueAllInterests(address user) internal {
        // In practice, would iterate through all user positions
        // Simplified for now
    }

    /**
     * @dev Internal function to calculate liquidation amounts
     * @param borrower Borrower address
     * @param borrowToken Borrow token
     * @param collateralToken Collateral token
     * @param repayAmount Repay amount
     * @return actualRepayAmount Actual repay amount
     * @return collateralSeized Collateral seized
     */
    function _calculateLiquidationAmounts(
        address borrower,
        address borrowToken,
        address collateralToken,
        uint256 repayAmount
    ) internal view returns (uint256 actualRepayAmount, uint256 collateralSeized) {
        // Get current borrow balance
        uint256 borrowBalance = _getBorrowBalance(borrower, borrowToken);
        
        // Limit repay amount to 50% of borrow balance
        actualRepayAmount = Math.min(repayAmount, borrowBalance / 2);
        
        // Get token prices
        (uint256 borrowPrice,) = IPriceOracle(priceOracle).getPrice(borrowToken);
        (uint256 collateralPrice,) = IPriceOracle(priceOracle).getPrice(collateralToken);
        
        // Calculate collateral to seize
        uint256 liquidationBonus = marketConfigs[collateralToken].liquidationBonus;
        uint256 repayValueETH = actualRepayAmount * borrowPrice / 1e18;
        uint256 collateralValueETH = repayValueETH * (BASIS_POINTS + liquidationBonus) / BASIS_POINTS;
        
        collateralSeized = collateralValueETH * 1e18 / collateralPrice;
        
        // Ensure we don't seize more collateral than available
        uint256 availableCollateral = userCollateral[borrower][collateralToken];
        collateralSeized = Math.min(collateralSeized, availableCollateral);
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