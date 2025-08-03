// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./InterestRateModel.sol";
import "../interfaces/IOracle.sol";
import "./LendingMarket.sol";

/**
 * @title BorrowingEngine
 * @dev Advanced borrowing engine with multi-collateral support and sophisticated risk management
 * @author CoreLiquid Protocol
 */
contract BorrowingEngine is AccessControl, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;
    using Math for uint256;
    
    bytes32 public constant BORROWER_ROLE = keccak256("BORROWER_ROLE");
    bytes32 public constant LIQUIDATOR_ROLE = keccak256("LIQUIDATOR_ROLE");
    bytes32 public constant RISK_MANAGER_ROLE = keccak256("RISK_MANAGER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    
    uint256 public constant PRECISION = 1e18;
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant MIN_HEALTH_FACTOR = 1e18; // 1.0
    uint256 public constant LIQUIDATION_THRESHOLD = 80e16; // 80%
    uint256 public constant LIQUIDATION_BONUS = 5e16; // 5%
    uint256 public constant MAX_LTV = 90e16; // 90%
    uint256 public constant CLOSE_FACTOR = 50e16; // 50%
    
    struct BorrowPosition {
        uint256 positionId;
        address borrower;
        address borrowToken;
        address collateralToken;
        uint256 borrowAmount;
        uint256 collateralAmount;
        uint256 borrowTimestamp;
        uint256 lastInterestUpdate;
        uint256 accruedInterest;
        uint256 liquidationThreshold;
        uint256 ltv; // Loan-to-Value ratio
        bool isActive;
        bool isLiquidated;
        uint256 healthFactor;
    }
    
    struct BorrowConfig {
        uint256 maxLTV; // Maximum Loan-to-Value ratio (basis points)
        uint256 liquidationThreshold; // Liquidation threshold (basis points)
        uint256 liquidationPenalty; // Liquidation penalty (basis points)
        uint256 borrowFee; // Borrow fee (basis points)
        uint256 minBorrowAmount;
        uint256 maxBorrowAmount;
        uint256 borrowCap; // Total borrow cap for this asset
        uint256 totalBorrowed; // Current total borrowed
        bool isEnabled;
        bool requiresWhitelist;
        uint256 interestRateModel; // Interest rate model type
    }
    
    struct UserBorrowData {
        uint256 totalBorrowed; // Total borrowed across all assets
        uint256 totalCollateral; // Total collateral value
        uint256 healthFactor; // Current health factor
        uint256 borrowPower; // Available borrow power
        uint256 liquidationPrice; // Price at which liquidation occurs
        uint256[] activePositions; // Array of active position IDs
        mapping(address => uint256) assetBorrowed; // Amount borrowed per asset
        mapping(address => uint256) assetCollateral; // Collateral amount per asset
        bool isLiquidatable;
    }
    
    struct LiquidationData {
        address liquidator;
        address borrower;
        address collateralAsset;
        address debtAsset;
        uint256 collateralSeized;
        uint256 debtRepaid;
        uint256 liquidationBonus;
        uint256 timestamp;
        uint256 healthFactorBefore;
        uint256 healthFactorAfter;
    }
    
    struct CollateralInfo {
        uint256 collateralFactor; // Collateral factor (basis points)
        uint256 liquidationThreshold; // Liquidation threshold (basis points)
        uint256 liquidationPenalty; // Liquidation penalty (basis points)
        uint256 maxCollateralAmount; // Maximum collateral amount
        bool isActive;
        bool canBeCollateral;
        uint256 totalCollateral; // Total collateral deposited
        uint256 priceVolatility; // Price volatility measure
    }
    
    // State variables
    mapping(address => BorrowConfig) public borrowConfigs;
    mapping(address => CollateralInfo) public collateralInfo;
    mapping(address => UserBorrowData) public userBorrowData;
    mapping(uint256 => BorrowPosition) public borrowPositions;
    mapping(address => mapping(address => uint256)) public userCollateralBalance;
    mapping(address => mapping(address => uint256)) public userBorrowBalance;
    mapping(address => bool) public supportedBorrowAssets;
    mapping(address => bool) public supportedCollateralAssets;
    mapping(address => uint256[]) public userPositions;
    
    LiquidationData[] public liquidationHistory;
    address[] public borrowAssets;
    address[] public collateralAssets;
    
    uint256 public nextPositionId = 1;
    uint256 public totalPositions;
    uint256 public totalLiquidations;
    
    // External contracts
    InterestRateModel public interestRateModel;
    IOracle public priceOracle;
    LendingMarket public lendingMarket;
    address public treasury;
    address public liquidationReserve;
    
    // Risk parameters
    uint256 public globalBorrowCap;
    uint256 public globalCollateralCap;
    uint256 public emergencyLiquidationThreshold = 95e16; // 95%
    bool public borrowingPaused;
    bool public liquidationsPaused;
    
    // Events
    event Borrow(address indexed user, address indexed asset, uint256 amount, uint256 positionId);
    event Repay(address indexed user, address indexed asset, uint256 amount, uint256 positionId);
    event AddCollateral(address indexed user, address indexed asset, uint256 amount);
    event RemoveCollateral(address indexed user, address indexed asset, uint256 amount);
    event Liquidate(
        address indexed liquidator,
        address indexed borrower,
        address indexed collateralAsset,
        address debtAsset,
        uint256 collateralSeized,
        uint256 debtRepaid
    );
    event PositionCreated(uint256 indexed positionId, address indexed borrower);
    event PositionClosed(uint256 indexed positionId, address indexed borrower);
    event HealthFactorUpdated(address indexed user, uint256 healthFactor);
    event BorrowConfigUpdated(address indexed asset, BorrowConfig config);
    event CollateralConfigUpdated(address indexed asset, CollateralInfo info);
    event EmergencyLiquidation(address indexed borrower, uint256 totalDebt, uint256 totalCollateral);
    
    constructor(
        address _interestRateModel,
        address _priceOracle,
        address _lendingMarket,
        address _treasury,
        address _liquidationReserve
    ) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(RISK_MANAGER_ROLE, msg.sender);
        _grantRole(LIQUIDATOR_ROLE, msg.sender);
        
        interestRateModel = InterestRateModel(_interestRateModel);
        priceOracle = IOracle(_priceOracle);
        lendingMarket = LendingMarket(_lendingMarket);
        treasury = _treasury;
        liquidationReserve = _liquidationReserve;
    }
    
    /**
     * @dev Borrow assets against collateral
     * @param asset The asset to borrow
     * @param amount The amount to borrow
     */
    function borrow(address asset, uint256 amount) external nonReentrant whenNotPaused {
        require(!borrowingPaused, "Borrowing is paused");
        require(amount > 0, "Amount must be greater than 0");
        require(supportedBorrowAssets[asset], "Asset not supported for borrowing");
        
        BorrowConfig storage config = borrowConfigs[asset];
        require(config.isEnabled, "Borrowing not enabled for this asset");
        require(amount >= config.minBorrowAmount, "Amount below minimum");
        require(amount <= config.maxBorrowAmount, "Amount above maximum");
        require(config.totalBorrowed + amount <= config.borrowCap, "Borrow cap exceeded");
        
        // Check user's borrow capacity
        _updateUserHealthFactor(msg.sender);
        UserBorrowData storage userData = userBorrowData[msg.sender];
        require(userData.healthFactor >= MIN_HEALTH_FACTOR, "Insufficient health factor");
        
        // Calculate required collateral
        uint256 requiredCollateralValue = _calculateRequiredCollateral(asset, amount);
        require(userData.totalCollateral >= requiredCollateralValue, "Insufficient collateral");
        
        // Create new position
        uint256 positionId = _createBorrowPosition(msg.sender, asset, amount);
        
        // Update user data
        userData.totalBorrowed += amount;
        userData.assetBorrowed[asset] += amount;
        userBorrowBalance[msg.sender][asset] += amount;
        
        // Update global data
        config.totalBorrowed += amount;
        totalPositions++;
        
        // Transfer borrowed asset to user
        IERC20(asset).safeTransfer(msg.sender, amount);
        
        // Update health factor
        _updateUserHealthFactor(msg.sender);
        
        emit Borrow(msg.sender, asset, amount, positionId);
    }
    
    /**
     * @dev Repay borrowed assets
     * @param asset The asset to repay
     * @param amount The amount to repay (use type(uint256).max for full repayment)
     */
    function repay(address asset, uint256 amount) external nonReentrant {
        require(amount > 0, "Amount must be greater than 0");
        require(supportedBorrowAssets[asset], "Asset not supported");
        
        UserBorrowData storage userData = userBorrowData[msg.sender];
        uint256 currentDebt = _getCurrentDebt(msg.sender, asset);
        require(currentDebt > 0, "No debt to repay");
        
        // Calculate actual repay amount
        uint256 repayAmount = amount == type(uint256).max ? currentDebt : amount;
        require(repayAmount <= currentDebt, "Repay amount exceeds debt");
        
        // Transfer repayment from user
        IERC20(asset).safeTransferFrom(msg.sender, address(this), repayAmount);
        
        // Update user data
        userData.totalBorrowed -= repayAmount;
        userData.assetBorrowed[asset] -= repayAmount;
        userBorrowBalance[msg.sender][asset] -= repayAmount;
        
        // Update global data
        borrowConfigs[asset].totalBorrowed -= repayAmount;
        
        // Update positions
        _updatePositionsAfterRepay(msg.sender, asset, repayAmount);
        
        // Update health factor
        _updateUserHealthFactor(msg.sender);
        
        emit Repay(msg.sender, asset, repayAmount, 0); // Position ID can be determined from positions
    }
    
    /**
     * @dev Add collateral to increase borrowing capacity
     * @param asset The collateral asset
     * @param amount The amount of collateral to add
     */
    function addCollateral(address asset, uint256 amount) external nonReentrant whenNotPaused {
        require(amount > 0, "Amount must be greater than 0");
        require(supportedCollateralAssets[asset], "Asset not supported as collateral");
        
        CollateralInfo storage info = collateralInfo[asset];
        require(info.isActive && info.canBeCollateral, "Collateral not active");
        require(info.totalCollateral + amount <= info.maxCollateralAmount, "Collateral cap exceeded");
        
        // Transfer collateral from user
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
        
        // Update user collateral
        UserBorrowData storage userData = userBorrowData[msg.sender];
        userData.assetCollateral[asset] += amount;
        userCollateralBalance[msg.sender][asset] += amount;
        
        // Update global collateral
        info.totalCollateral += amount;
        
        // Update user's total collateral value
        _updateUserHealthFactor(msg.sender);
        
        emit AddCollateral(msg.sender, asset, amount);
    }
    
    /**
     * @dev Remove collateral (if health factor allows)
     * @param asset The collateral asset
     * @param amount The amount of collateral to remove
     */
    function removeCollateral(address asset, uint256 amount) external nonReentrant {
        require(amount > 0, "Amount must be greater than 0");
        require(supportedCollateralAssets[asset], "Asset not supported");
        
        UserBorrowData storage userData = userBorrowData[msg.sender];
        require(userData.assetCollateral[asset] >= amount, "Insufficient collateral balance");
        
        // Check if removal would break health factor
        uint256 collateralValue = _getAssetValue(asset, amount);
        require(userData.totalCollateral > collateralValue, "Cannot remove all collateral");
        
        // Simulate health factor after removal
        uint256 newCollateralValue = userData.totalCollateral - collateralValue;
        uint256 newHealthFactor = _calculateHealthFactor(newCollateralValue, userData.totalBorrowed);
        require(newHealthFactor >= MIN_HEALTH_FACTOR, "Would break health factor");
        
        // Update user collateral
        userData.assetCollateral[asset] -= amount;
        userCollateralBalance[msg.sender][asset] -= amount;
        
        // Update global collateral
        collateralInfo[asset].totalCollateral -= amount;
        
        // Transfer collateral to user
        IERC20(asset).safeTransfer(msg.sender, amount);
        
        // Update health factor
        _updateUserHealthFactor(msg.sender);
        
        emit RemoveCollateral(msg.sender, asset, amount);
    }
    
    /**
     * @dev Liquidate an undercollateralized position
     * @param user The borrower to liquidate
     * @param collateralAsset The collateral asset to seize
     * @param debtAsset The debt asset to repay
     */
    function liquidate(
        address user,
        address collateralAsset,
        address debtAsset
    ) external nonReentrant onlyRole(LIQUIDATOR_ROLE) {
        require(!liquidationsPaused, "Liquidations are paused");
        require(user != msg.sender, "Cannot liquidate yourself");
        require(supportedCollateralAssets[collateralAsset], "Invalid collateral asset");
        require(supportedBorrowAssets[debtAsset], "Invalid debt asset");
        
        // Update user's health factor
        _updateUserHealthFactor(user);
        UserBorrowData storage userData = userBorrowData[user];
        
        require(userData.isLiquidatable || userData.healthFactor < MIN_HEALTH_FACTOR, "Position not liquidatable");
        
        uint256 debtAmount = _getCurrentDebt(user, debtAsset);
        require(debtAmount > 0, "No debt to liquidate");
        
        uint256 collateralAmount = userData.assetCollateral[collateralAsset];
        require(collateralAmount > 0, "No collateral to seize");
        
        // Calculate liquidation amounts
        uint256 maxRepayAmount = debtAmount.mulDiv(CLOSE_FACTOR, PRECISION);
        uint256 collateralValue = _getAssetValue(collateralAsset, collateralAmount);
        uint256 debtValue = _getAssetValue(debtAsset, maxRepayAmount);
        
        // Calculate collateral to seize (with bonus)
        CollateralInfo storage collInfo = collateralInfo[collateralAsset];
        uint256 liquidationBonus = collInfo.liquidationPenalty;
        uint256 collateralToSeize = debtValue.mulDiv(PRECISION + liquidationBonus, PRECISION);
        collateralToSeize = _convertValueToAsset(collateralAsset, collateralToSeize);
        
        // Ensure we don't seize more than available
        if (collateralToSeize > collateralAmount) {
            collateralToSeize = collateralAmount;
            maxRepayAmount = _convertValueToAsset(debtAsset, 
                collateralValue.mulDiv(PRECISION, PRECISION + liquidationBonus)
            );
        }
        
        // Transfer debt repayment from liquidator
        IERC20(debtAsset).safeTransferFrom(msg.sender, address(this), maxRepayAmount);
        
        // Transfer collateral to liquidator
        IERC20(collateralAsset).safeTransfer(msg.sender, collateralToSeize);
        
        // Update user data
        userData.totalBorrowed -= maxRepayAmount;
        userData.assetBorrowed[debtAsset] -= maxRepayAmount;
        userData.assetCollateral[collateralAsset] -= collateralToSeize;
        userBorrowBalance[user][debtAsset] -= maxRepayAmount;
        userCollateralBalance[user][collateralAsset] -= collateralToSeize;
        
        // Update global data
        borrowConfigs[debtAsset].totalBorrowed -= maxRepayAmount;
        collateralInfo[collateralAsset].totalCollateral -= collateralToSeize;
        
        // Update positions
        _updatePositionsAfterLiquidation(user, debtAsset, maxRepayAmount);
        
        // Record liquidation
        uint256 healthFactorBefore = userData.healthFactor;
        _updateUserHealthFactor(user);
        
        liquidationHistory.push(LiquidationData({
            liquidator: msg.sender,
            borrower: user,
            collateralAsset: collateralAsset,
            debtAsset: debtAsset,
            collateralSeized: collateralToSeize,
            debtRepaid: maxRepayAmount,
            liquidationBonus: liquidationBonus,
            timestamp: block.timestamp,
            healthFactorBefore: healthFactorBefore,
            healthFactorAfter: userData.healthFactor
        }));
        
        totalLiquidations++;
        
        emit Liquidate(msg.sender, user, collateralAsset, debtAsset, collateralToSeize, maxRepayAmount);
    }
    
    // View functions
    function getUserBorrowData(address user) external view returns (
        uint256 totalBorrowed,
        uint256 totalCollateral,
        uint256 healthFactor,
        uint256 borrowPower,
        bool isLiquidatable
    ) {
        UserBorrowData storage userData = userBorrowData[user];
        return (
            userData.totalBorrowed,
            userData.totalCollateral,
            userData.healthFactor,
            userData.borrowPower,
            userData.isLiquidatable
        );
    }
    
    function getUserPositions(address user) external view returns (uint256[] memory) {
        return userPositions[user];
    }
    
    function getBorrowPosition(uint256 positionId) external view returns (BorrowPosition memory) {
        return borrowPositions[positionId];
    }
    
    function getLiquidationHistory(uint256 count) external view returns (LiquidationData[] memory) {
        uint256 length = liquidationHistory.length;
        if (count > length) count = length;
        
        LiquidationData[] memory history = new LiquidationData[](count);
        for (uint256 i = 0; i < count; i++) {
            history[i] = liquidationHistory[length - count + i];
        }
        return history;
    }
    
    // Internal functions
    function _createBorrowPosition(
        address borrower,
        address asset,
        uint256 amount
    ) internal returns (uint256 positionId) {
        positionId = nextPositionId++;
        
        borrowPositions[positionId] = BorrowPosition({
            positionId: positionId,
            borrower: borrower,
            borrowToken: asset,
            collateralToken: address(0), // Multi-collateral support
            borrowAmount: amount,
            collateralAmount: 0,
            borrowTimestamp: block.timestamp,
            lastInterestUpdate: block.timestamp,
            accruedInterest: 0,
            liquidationThreshold: borrowConfigs[asset].liquidationThreshold,
            ltv: 0, // Will be calculated
            isActive: true,
            isLiquidated: false,
            healthFactor: 0 // Will be calculated
        });
        
        userPositions[borrower].push(positionId);
        userBorrowData[borrower].activePositions.push(positionId);
        
        emit PositionCreated(positionId, borrower);
    }
    
    function _updateUserHealthFactor(address user) internal {
        UserBorrowData storage userData = userBorrowData[user];
        
        // Calculate total collateral value
        uint256 totalCollateralValue = 0;
        for (uint256 i = 0; i < collateralAssets.length; i++) {
            address asset = collateralAssets[i];
            uint256 balance = userData.assetCollateral[asset];
            if (balance > 0) {
                uint256 value = _getAssetValue(asset, balance);
                uint256 collateralFactor = collateralInfo[asset].collateralFactor;
                totalCollateralValue += value.mulDiv(collateralFactor, PRECISION);
            }
        }
        
        // Calculate total borrowed value
        uint256 totalBorrowedValue = 0;
        for (uint256 i = 0; i < borrowAssets.length; i++) {
            address asset = borrowAssets[i];
            uint256 debt = _getCurrentDebt(user, asset);
            if (debt > 0) {
                totalBorrowedValue += _getAssetValue(asset, debt);
            }
        }
        
        // Update user data
        userData.totalCollateral = totalCollateralValue;
        userData.totalBorrowed = totalBorrowedValue;
        userData.healthFactor = _calculateHealthFactor(totalCollateralValue, totalBorrowedValue);
        userData.borrowPower = totalCollateralValue > totalBorrowedValue ? 
            totalCollateralValue - totalBorrowedValue : 0;
        userData.isLiquidatable = userData.healthFactor < MIN_HEALTH_FACTOR;
        
        emit HealthFactorUpdated(user, userData.healthFactor);
    }
    
    function _calculateHealthFactor(
        uint256 totalCollateralValue,
        uint256 totalBorrowedValue
    ) internal pure returns (uint256) {
        if (totalBorrowedValue == 0) {
            return type(uint256).max;
        }
        return totalCollateralValue.mulDiv(PRECISION, totalBorrowedValue);
    }
    
    function _calculateRequiredCollateral(
        address asset,
        uint256 borrowAmount
    ) internal view returns (uint256) {
        uint256 borrowValue = _getAssetValue(asset, borrowAmount);
        uint256 maxLTV = borrowConfigs[asset].maxLTV;
        return borrowValue.mulDiv(PRECISION, maxLTV);
    }
    
    function _getCurrentDebt(address user, address asset) internal view returns (uint256) {
        // This would include accrued interest calculation
        return userBorrowBalance[user][asset]; // Simplified
    }
    
    function _getAssetValue(address asset, uint256 amount) internal view returns (uint256) {
        (uint256 price, ) = priceOracle.getPrice(asset);
        return amount.mulDiv(price, PRECISION);
    }
    
    function _convertValueToAsset(address asset, uint256 value) internal view returns (uint256) {
        (uint256 price, ) = priceOracle.getPrice(asset);
        return value.mulDiv(PRECISION, price);
    }
    
    function _updatePositionsAfterRepay(
        address user,
        address asset,
        uint256 repayAmount
    ) internal {
        // Update relevant positions - simplified implementation
        uint256[] storage positions = userPositions[user];
        for (uint256 i = 0; i < positions.length; i++) {
            BorrowPosition storage position = borrowPositions[positions[i]];
            if (position.borrowToken == asset && position.isActive) {
                if (position.borrowAmount <= repayAmount) {
                    position.borrowAmount = 0;
                    position.isActive = false;
                    emit PositionClosed(position.positionId, user);
                } else {
                    position.borrowAmount -= repayAmount;
                }
                break;
            }
        }
    }
    
    function _updatePositionsAfterLiquidation(
        address user,
        address asset,
        uint256 liquidatedAmount
    ) internal {
        // Similar to repay but for liquidation
        _updatePositionsAfterRepay(user, asset, liquidatedAmount);
    }
    
    // Admin functions
    function addBorrowAsset(
        address asset,
        uint256 maxLTV,
        uint256 liquidationThreshold,
        uint256 liquidationPenalty,
        uint256 borrowFee,
        uint256 minBorrowAmount,
        uint256 maxBorrowAmount,
        uint256 borrowCap
    ) external onlyRole(ADMIN_ROLE) {
        require(!supportedBorrowAssets[asset], "Asset already supported");
        
        borrowConfigs[asset] = BorrowConfig({
            maxLTV: maxLTV,
            liquidationThreshold: liquidationThreshold,
            liquidationPenalty: liquidationPenalty,
            borrowFee: borrowFee,
            minBorrowAmount: minBorrowAmount,
            maxBorrowAmount: maxBorrowAmount,
            borrowCap: borrowCap,
            totalBorrowed: 0,
            isEnabled: true,
            requiresWhitelist: false,
            interestRateModel: 0
        });
        
        supportedBorrowAssets[asset] = true;
        borrowAssets.push(asset);
        
        emit BorrowConfigUpdated(asset, borrowConfigs[asset]);
    }
    
    function addCollateralAsset(
        address asset,
        uint256 collateralFactor,
        uint256 liquidationThreshold,
        uint256 liquidationPenalty,
        uint256 maxCollateralAmount
    ) external onlyRole(ADMIN_ROLE) {
        require(!supportedCollateralAssets[asset], "Asset already supported");
        
        collateralInfo[asset] = CollateralInfo({
            collateralFactor: collateralFactor,
            liquidationThreshold: liquidationThreshold,
            liquidationPenalty: liquidationPenalty,
            maxCollateralAmount: maxCollateralAmount,
            isActive: true,
            canBeCollateral: true,
            totalCollateral: 0,
            priceVolatility: 0
        });
        
        supportedCollateralAssets[asset] = true;
        collateralAssets.push(asset);
        
        emit CollateralConfigUpdated(asset, collateralInfo[asset]);
    }
    
    function pauseBorrowing() external onlyRole(RISK_MANAGER_ROLE) {
        borrowingPaused = true;
    }
    
    function unpauseBorrowing() external onlyRole(RISK_MANAGER_ROLE) {
        borrowingPaused = false;
    }
    
    function pauseLiquidations() external onlyRole(RISK_MANAGER_ROLE) {
        liquidationsPaused = true;
    }
    
    function unpauseLiquidations() external onlyRole(RISK_MANAGER_ROLE) {
        liquidationsPaused = false;
    }
    
    function setInterestRateModel(address _interestRateModel) external onlyRole(ADMIN_ROLE) {
        interestRateModel = InterestRateModel(_interestRateModel);
    }
    
    function setPriceOracle(address _priceOracle) external onlyRole(ADMIN_ROLE) {
        priceOracle = IOracle(_priceOracle);
    }
    
    function setLendingMarket(address _lendingMarket) external onlyRole(ADMIN_ROLE) {
        lendingMarket = LendingMarket(_lendingMarket);
    }
}
