// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title ILendingMarket
 * @dev Interface for the lending market functionality in CoreLiquid protocol
 */
interface ILendingMarket {
    struct LendingPosition {
        uint256 principal;
        uint256 interest;
        uint256 timestamp;
        uint256 maturity;
        bool isActive;
    }
    
    struct BorrowPosition {
        uint256 borrowed;
        uint256 collateral;
        uint256 interestRate;
        uint256 timestamp;
        uint256 liquidationThreshold;
        bool isActive;
    }
    
    struct MarketData {
        uint256 totalSupply;
        uint256 totalBorrow;
        uint256 utilizationRate;
        uint256 supplyRate;
        uint256 borrowRate;
        uint256 reserveFactor;
    }
    
    /**
     * @dev Emitted when tokens are supplied to the market
     */
    event Supply(
        address indexed user,
        address indexed token,
        uint256 amount,
        uint256 shares
    );
    
    /**
     * @dev Emitted when tokens are withdrawn from the market
     */
    event Withdraw(
        address indexed user,
        address indexed token,
        uint256 amount,
        uint256 shares
    );
    
    /**
     * @dev Emitted when tokens are borrowed
     */
    event Borrow(
        address indexed user,
        address indexed token,
        uint256 amount,
        uint256 interestRate
    );
    
    /**
     * @dev Emitted when borrowed tokens are repaid
     */
    event Repay(
        address indexed user,
        address indexed token,
        uint256 amount
    );
    
    /**
     * @dev Emitted when a position is liquidated
     */
    event Liquidation(
        address indexed borrower,
        address indexed liquidator,
        address indexed collateralToken,
        uint256 collateralAmount,
        uint256 debtAmount
    );
    
    /**
     * @dev Supplies tokens to the lending market
     * @param token The token address to supply
     * @param amount The amount to supply
     * @return shares The number of shares minted
     */
    function supply(address token, uint256 amount) external returns (uint256 shares);
    
    /**
     * @dev Withdraws tokens from the lending market
     * @param token The token address to withdraw
     * @param shares The number of shares to burn
     * @return amount The amount withdrawn
     */
    function withdraw(address token, uint256 shares) external returns (uint256 amount);
    
    /**
     * @dev Borrows tokens from the lending market
     * @param token The token address to borrow
     * @param amount The amount to borrow
     * @param collateralToken The collateral token address
     * @param collateralAmount The collateral amount
     */
    function borrow(
        address token,
        uint256 amount,
        address collateralToken,
        uint256 collateralAmount
    ) external;
    
    /**
     * @dev Repays borrowed tokens
     * @param token The token address to repay
     * @param amount The amount to repay
     */
    function repay(address token, uint256 amount) external;
    
    /**
     * @dev Liquidates an undercollateralized position
     * @param borrower The borrower address
     * @param collateralToken The collateral token address
     * @param debtToken The debt token address
     * @param debtAmount The debt amount to liquidate
     */
    function liquidate(
        address borrower,
        address collateralToken,
        address debtToken,
        uint256 debtAmount
    ) external;
    
    /**
     * @dev Gets the current supply rate for a token
     * @param token The token address
     * @return rate The supply rate (annual percentage)
     */
    function getSupplyRate(address token) external view returns (uint256 rate);
    
    /**
     * @dev Gets the current borrow rate for a token
     * @param token The token address
     * @return rate The borrow rate (annual percentage)
     */
    function getBorrowRate(address token) external view returns (uint256 rate);
    
    /**
     * @dev Gets the utilization rate for a token
     * @param token The token address
     * @return rate The utilization rate (percentage)
     */
    function getUtilizationRate(address token) external view returns (uint256 rate);
    
    /**
     * @dev Gets user's lending position
     * @param user The user address
     * @param token The token address
     * @return position The lending position data
     */
    function getLendingPosition(
        address user,
        address token
    ) external view returns (LendingPosition memory position);
    
    /**
     * @dev Gets user's borrow position
     * @param user The user address
     * @param token The token address
     * @return position The borrow position data
     */
    function getBorrowPosition(
        address user,
        address token
    ) external view returns (BorrowPosition memory position);
    
    /**
     * @dev Gets market data for a token
     * @param token The token address
     * @return data The market data
     */
    function getMarketData(address token) external view returns (MarketData memory data);
    
    /**
     * @dev Checks if a position is liquidatable
     * @param user The user address
     * @param token The token address
     * @return isLiquidatable True if position can be liquidated
     */
    function isLiquidatable(address user, address token) external view returns (bool isLiquidatable);
    
    /**
     * @dev Gets the health factor of a user's position
     * @param user The user address
     * @return healthFactor The health factor (1e18 = 100%)
     */
    function getHealthFactor(address user) external view returns (uint256 healthFactor);
    
    /**
     * @dev Gets the maximum borrowable amount for a user
     * @param user The user address
     * @param token The token address
     * @return maxBorrow The maximum borrowable amount
     */
    function getMaxBorrowAmount(
        address user,
        address token
    ) external view returns (uint256 maxBorrow);
}
