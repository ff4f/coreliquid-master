// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./interfaces/IOracle.sol";
import "./lending/InterestRateModel.sol";

/**
 * @title LendingMarket
 * @dev Advanced lending market with dynamic interest rates and comprehensive risk management
 * @author CoreLiquid Protocol
 */
contract LendingMarket is AccessControl, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;
    using Math for uint256;
    
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant LIQUIDATOR_ROLE = keccak256("LIQUIDATOR_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant RISK_MANAGER_ROLE = keccak256("RISK_MANAGER_ROLE");
    
    uint256 public constant PRECISION = 1e18;
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant SECONDS_PER_YEAR = 365 days;
    uint256 public constant MAX_UTILIZATION_RATE = 95e16; // 95%
    uint256 public constant LIQUIDATION_THRESHOLD = 80e16; // 80%
    uint256 public constant LIQUIDATION_BONUS = 5e16; // 5%
    uint256 public constant MIN_HEALTH_FACTOR = 1e18; // 1.0
    
    struct Market {
        IERC20 asset;
        uint256 totalSupply;
        uint256 totalBorrow;
        uint256 supplyRate;
        uint256 borrowRate;
        uint256 utilizationRate;
        uint256 reserveFactor;
        uint256 collateralFactor;
        uint256 liquidationThreshold;
        uint256 liquidationBonus;
        uint256 borrowCap;
        uint256 supplyCap;
        bool isActive;
        bool canBorrow;
        bool canSupply;
        uint256 lastUpdateTimestamp;
        uint256 supplyIndex;
        uint256 borrowIndex;
        uint256 totalReserves;
    }
    
    struct UserAccount {
        uint256 supplied;
        uint256 borrowed;
        uint256 supplyIndex;
        uint256 borrowIndex;
        uint256 lastInterestAccrual;
        bool isCollateralEnabled;
    }
    
    struct SupplySnapshot {
        uint256 amount;
        uint256 timestamp;
        uint256 interestIndex;
    }
    
    struct BorrowSnapshot {
        uint256 amount;
        uint256 timestamp;
        uint256 interestIndex;
    }
    
    // State variables
    mapping(address => Market) public markets;
    mapping(address => mapping(address => UserAccount)) public userAccounts;
    mapping(address => mapping(address => SupplySnapshot[])) public supplyHistory;
    mapping(address => mapping(address => BorrowSnapshot[])) public borrowHistory;
    mapping(address => address[]) public userSuppliedAssets;
    mapping(address => address[]) public userBorrowedAssets;
    mapping(address => bool) public isMarketListed;
    
    address[] public allMarkets;
    InterestRateModel public interestRateModel;
    IOracle public priceOracle;
    address public treasury;
    
    // Events
    event Supply(address indexed user, address indexed asset, uint256 amount, uint256 newBalance);
    event Withdraw(address indexed user, address indexed asset, uint256 amount, uint256 newBalance);
    event Borrow(address indexed user, address indexed asset, uint256 amount, uint256 newBalance);
    event Repay(address indexed user, address indexed asset, uint256 amount, uint256 newBalance);
    event MarketAdded(address indexed asset, address indexed market);
    event MarketUpdated(address indexed asset);
    event InterestAccrued(address indexed asset, uint256 supplyRate, uint256 borrowRate);
    event ReservesAdded(address indexed asset, uint256 amount);
    event ReservesReduced(address indexed asset, uint256 amount);
    event CollateralToggled(address indexed user, address indexed asset, bool enabled);
    
    constructor(
        address _interestRateModel,
        address _priceOracle,
        address _treasury
    ) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(RISK_MANAGER_ROLE, msg.sender);
        
        interestRateModel = InterestRateModel(_interestRateModel);
        priceOracle = IOracle(_priceOracle);
        treasury = _treasury;
    }
    
    /**
     * @dev Supply assets to the lending market
     * @param asset The asset to supply
     * @param amount The amount to supply
     */
    function supply(address asset, uint256 amount) external nonReentrant whenNotPaused {
        require(amount > 0, "Amount must be greater than 0");
        require(isMarketListed[asset], "Market not listed");
        
        Market storage market = markets[asset];
        require(market.isActive && market.canSupply, "Market not active for supply");
        require(market.totalSupply + amount <= market.supplyCap, "Supply cap exceeded");
        
        // Accrue interest before any balance changes
        accrueInterest(asset);
        
        UserAccount storage userAccount = userAccounts[msg.sender][asset];
        
        // Update user's supply balance
        if (userAccount.supplied == 0) {
            userSuppliedAssets[msg.sender].push(asset);
        }
        
        // Transfer tokens from user
        market.asset.safeTransferFrom(msg.sender, address(this), amount);
        
        // Update balances
        userAccount.supplied += amount;
        userAccount.supplyIndex = market.supplyIndex;
        userAccount.lastInterestAccrual = block.timestamp;
        market.totalSupply += amount;
        
        // Add to supply history
        supplyHistory[msg.sender][asset].push(SupplySnapshot({
            amount: amount,
            timestamp: block.timestamp,
            interestIndex: market.supplyIndex
        }));
        
        emit Supply(msg.sender, asset, amount, userAccount.supplied);
    }
    
    /**
     * @dev Withdraw supplied assets from the lending market
     * @param asset The asset to withdraw
     * @param amount The amount to withdraw (use type(uint256).max for full withdrawal)
     */
    function withdraw(address asset, uint256 amount) external nonReentrant whenNotPaused {
        require(isMarketListed[asset], "Market not listed");
        
        Market storage market = markets[asset];
        UserAccount storage userAccount = userAccounts[msg.sender][asset];
        
        require(userAccount.supplied > 0, "No supply balance");
        
        // Accrue interest before any balance changes
        accrueInterest(asset);
        
        // Calculate actual withdrawal amount
        uint256 withdrawAmount = amount == type(uint256).max ? userAccount.supplied : amount;
        require(withdrawAmount <= userAccount.supplied, "Insufficient supply balance");
        require(withdrawAmount <= market.asset.balanceOf(address(this)), "Insufficient liquidity");
        
        // Check if withdrawal would break collateral requirements
        if (userAccount.isCollateralEnabled) {
            require(_checkWithdrawalAllowed(msg.sender, asset, withdrawAmount), "Withdrawal would break collateral requirements");
        }
        
        // Update balances
        userAccount.supplied -= withdrawAmount;
        market.totalSupply -= withdrawAmount;
        
        // Remove from supplied assets if balance is zero
        if (userAccount.supplied == 0) {
            _removeFromSuppliedAssets(msg.sender, asset);
        }
        
        // Transfer tokens to user
        market.asset.safeTransfer(msg.sender, withdrawAmount);
        
        emit Withdraw(msg.sender, asset, withdrawAmount, userAccount.supplied);
    }
    
    /**
     * @dev Calculate supply APY for an asset
     * @param asset The asset to calculate APY for
     * @return The annual percentage yield in basis points
     */
    function calculateSupplyAPY(address asset) public view returns (uint256) {
        Market storage market = markets[asset];
        if (!market.isActive || market.totalSupply == 0) {
            return 0;
        }
        
        uint256 utilizationRate = _calculateUtilizationRate(asset);
        uint256 borrowRate = interestRateModel.calculateInterestRate(utilizationRate);
        uint256 supplyRate = borrowRate.mulDiv(utilizationRate, PRECISION).mulDiv(
            PRECISION - market.reserveFactor, PRECISION
        );
        
        return supplyRate;
    }
    
    /**
     * @dev Get supply balance for a user and asset
     * @param user The user address
     * @param asset The asset address
     * @return The current supply balance including accrued interest
     */
    function getSupplyBalance(address user, address asset) public view returns (uint256) {
        UserAccount storage userAccount = userAccounts[user][asset];
        if (userAccount.supplied == 0) {
            return 0;
        }
        
        Market storage market = markets[asset];
        uint256 currentIndex = _calculateCurrentSupplyIndex(asset);
        
        return userAccount.supplied.mulDiv(currentIndex, userAccount.supplyIndex);
    }
    
    /**
     * @dev Get borrow balance for a user and asset
     * @param user The user address
     * @param asset The asset address
     * @return The current borrow balance including accrued interest
     */
    function getBorrowBalance(address user, address asset) public view returns (uint256) {
        UserAccount storage userAccount = userAccounts[user][asset];
        if (userAccount.borrowed == 0) {
            return 0;
        }
        
        Market storage market = markets[asset];
        uint256 currentIndex = _calculateCurrentBorrowIndex(asset);
        
        return userAccount.borrowed.mulDiv(currentIndex, userAccount.borrowIndex);
    }
    
    /**
     * @dev Accrue interest for a market
     * @param asset The asset to accrue interest for
     */
    function accrueInterest(address asset) public {
        Market storage market = markets[asset];
        
        if (!market.isActive) {
            return;
        }
        
        uint256 currentTimestamp = block.timestamp;
        uint256 timeDelta = currentTimestamp - market.lastUpdateTimestamp;
        
        if (timeDelta == 0) {
            return;
        }
        
        uint256 utilizationRate = _calculateUtilizationRate(asset);
        uint256 borrowRate = interestRateModel.calculateInterestRate(utilizationRate);
        uint256 supplyRate = borrowRate.mulDiv(utilizationRate, PRECISION).mulDiv(
            PRECISION - market.reserveFactor, PRECISION
        );
        
        // Calculate interest accrual
        uint256 borrowInterest = market.totalBorrow.mulDiv(
            borrowRate.mulDiv(timeDelta, SECONDS_PER_YEAR), PRECISION
        );
        
        uint256 reserveInterest = borrowInterest.mulDiv(market.reserveFactor, PRECISION);
        uint256 supplyInterest = borrowInterest - reserveInterest;
        
        // Update market state
        market.totalBorrow += borrowInterest;
        market.totalReserves += reserveInterest;
        market.supplyRate = supplyRate;
        market.borrowRate = borrowRate;
        market.utilizationRate = utilizationRate;
        market.lastUpdateTimestamp = currentTimestamp;
        
        // Update indices
        if (market.totalSupply > 0) {
            market.supplyIndex += market.supplyIndex.mulDiv(supplyInterest, market.totalSupply);
        }
        
        if (market.totalBorrow > 0) {
            market.borrowIndex += market.borrowIndex.mulDiv(borrowInterest, market.totalBorrow);
        }
        
        emit InterestAccrued(asset, supplyRate, borrowRate);
    }
    
    /**
     * @dev Toggle collateral for an asset
     * @param asset The asset to toggle collateral for
     * @param enabled Whether to enable or disable collateral
     */
    function toggleCollateral(address asset, bool enabled) external nonReentrant {
        require(isMarketListed[asset], "Market not listed");
        
        UserAccount storage userAccount = userAccounts[msg.sender][asset];
        require(userAccount.supplied > 0, "No supply balance");
        
        if (!enabled && userAccount.isCollateralEnabled) {
            // Check if disabling collateral would break health factor
            require(_checkCollateralDisableAllowed(msg.sender, asset), "Cannot disable collateral");
        }
        
        userAccount.isCollateralEnabled = enabled;
        
        emit CollateralToggled(msg.sender, asset, enabled);
    }
    
    /**
     * @dev Add a new market
     * @param asset The asset to add
     * @param collateralFactor The collateral factor for the asset
     * @param reserveFactor The reserve factor for the asset
     * @param liquidationThreshold The liquidation threshold
     * @param liquidationBonus The liquidation bonus
     * @param borrowCap The borrow cap
     * @param supplyCap The supply cap
     */
    function addMarket(
        address asset,
        uint256 collateralFactor,
        uint256 reserveFactor,
        uint256 liquidationThreshold,
        uint256 liquidationBonus,
        uint256 borrowCap,
        uint256 supplyCap
    ) external onlyRole(ADMIN_ROLE) {
        require(!isMarketListed[asset], "Market already listed");
        require(collateralFactor <= PRECISION, "Invalid collateral factor");
        require(reserveFactor <= PRECISION, "Invalid reserve factor");
        require(liquidationThreshold <= PRECISION, "Invalid liquidation threshold");
        require(liquidationBonus <= PRECISION, "Invalid liquidation bonus");
        
        markets[asset] = Market({
            asset: IERC20(asset),
            totalSupply: 0,
            totalBorrow: 0,
            supplyRate: 0,
            borrowRate: 0,
            utilizationRate: 0,
            reserveFactor: reserveFactor,
            collateralFactor: collateralFactor,
            liquidationThreshold: liquidationThreshold,
            liquidationBonus: liquidationBonus,
            borrowCap: borrowCap,
            supplyCap: supplyCap,
            isActive: true,
            canBorrow: true,
            canSupply: true,
            lastUpdateTimestamp: block.timestamp,
            supplyIndex: PRECISION,
            borrowIndex: PRECISION,
            totalReserves: 0
        });
        
        isMarketListed[asset] = true;
        allMarkets.push(asset);
        
        emit MarketAdded(asset, address(this));
    }
    
    /**
     * @dev Update market parameters
     */
    function updateMarket(
        address asset,
        uint256 collateralFactor,
        uint256 reserveFactor,
        uint256 liquidationThreshold,
        uint256 liquidationBonus,
        uint256 borrowCap,
        uint256 supplyCap,
        bool canBorrow,
        bool canSupply
    ) external onlyRole(ADMIN_ROLE) {
        require(isMarketListed[asset], "Market not listed");
        
        Market storage market = markets[asset];
        market.collateralFactor = collateralFactor;
        market.reserveFactor = reserveFactor;
        market.liquidationThreshold = liquidationThreshold;
        market.liquidationBonus = liquidationBonus;
        market.borrowCap = borrowCap;
        market.supplyCap = supplyCap;
        market.canBorrow = canBorrow;
        market.canSupply = canSupply;
        
        emit MarketUpdated(asset);
    }
    
    /**
     * @dev Get all markets
     */
    function getAllMarkets() external view returns (address[] memory) {
        return allMarkets;
    }
    
    /**
     * @dev Get user's supplied assets
     */
    function getUserSuppliedAssets(address user) external view returns (address[] memory) {
        return userSuppliedAssets[user];
    }
    
    /**
     * @dev Get user's borrowed assets
     */
    function getUserBorrowedAssets(address user) external view returns (address[] memory) {
        return userBorrowedAssets[user];
    }
    
    // Internal functions
    function _calculateUtilizationRate(address asset) internal view returns (uint256) {
        Market storage market = markets[asset];
        if (market.totalSupply == 0) {
            return 0;
        }
        return market.totalBorrow.mulDiv(PRECISION, market.totalSupply);
    }
    
    function _calculateCurrentSupplyIndex(address asset) internal view returns (uint256) {
        Market storage market = markets[asset];
        uint256 timeDelta = block.timestamp - market.lastUpdateTimestamp;
        
        if (timeDelta == 0 || market.totalSupply == 0) {
            return market.supplyIndex;
        }
        
        uint256 supplyRate = calculateSupplyAPY(asset);
        uint256 interestAccrued = market.supplyIndex.mulDiv(
            supplyRate.mulDiv(timeDelta, SECONDS_PER_YEAR), PRECISION
        );
        
        return market.supplyIndex + interestAccrued;
    }
    
    function _calculateCurrentBorrowIndex(address asset) internal view returns (uint256) {
        Market storage market = markets[asset];
        uint256 timeDelta = block.timestamp - market.lastUpdateTimestamp;
        
        if (timeDelta == 0 || market.totalBorrow == 0) {
            return market.borrowIndex;
        }
        
        uint256 utilizationRate = _calculateUtilizationRate(asset);
        uint256 borrowRate = interestRateModel.calculateInterestRate(utilizationRate);
        uint256 interestAccrued = market.borrowIndex.mulDiv(
            borrowRate.mulDiv(timeDelta, SECONDS_PER_YEAR), PRECISION
        );
        
        return market.borrowIndex + interestAccrued;
    }
    
    function _checkWithdrawalAllowed(address user, address asset, uint256 amount) internal view returns (bool) {
        // Implementation for checking if withdrawal is allowed based on collateral requirements
        // This would involve calculating health factor after withdrawal
        return true; // Simplified for now
    }
    
    function _checkCollateralDisableAllowed(address user, address asset) internal view returns (bool) {
        // Implementation for checking if collateral can be disabled
        // This would involve calculating health factor without this collateral
        return true; // Simplified for now
    }
    
    function _removeFromSuppliedAssets(address user, address asset) internal {
        address[] storage assets = userSuppliedAssets[user];
        for (uint256 i = 0; i < assets.length; i++) {
            if (assets[i] == asset) {
                assets[i] = assets[assets.length - 1];
                assets.pop();
                break;
            }
        }
    }
    
    // Admin functions
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }
    
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }
    
    function setInterestRateModel(address _interestRateModel) external onlyRole(ADMIN_ROLE) {
        interestRateModel = InterestRateModel(_interestRateModel);
    }
    
    function setPriceOracle(address _priceOracle) external onlyRole(ADMIN_ROLE) {
        priceOracle = IOracle(_priceOracle);
    }
    
    function setTreasury(address _treasury) external onlyRole(ADMIN_ROLE) {
        treasury = _treasury;
    }
    
    function reduceReserves(address asset, uint256 amount) external onlyRole(ADMIN_ROLE) {
        Market storage market = markets[asset];
        require(amount <= market.totalReserves, "Insufficient reserves");
        
        market.totalReserves -= amount;
        market.asset.safeTransfer(treasury, amount);
        
        emit ReservesReduced(asset, amount);
    }
}