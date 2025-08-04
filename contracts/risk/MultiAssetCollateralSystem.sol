// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title MultiAssetCollateralSystem
 * @dev Advanced multi-asset collateral management system with cross-collateral support
 */
contract MultiAssetCollateralSystem is AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using Math for uint256;
    
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant RISK_MANAGER_ROLE = keccak256("RISK_MANAGER_ROLE");
    bytes32 public constant LIQUIDATOR_ROLE = keccak256("LIQUIDATOR_ROLE");
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");
    bytes32 public constant KEEPER_ROLE = keccak256("KEEPER_ROLE");
    
    uint256 public constant PRECISION = 1e18;
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant MAX_COLLATERAL_TYPES = 50;
    uint256 public constant MIN_COLLATERAL_RATIO = 11000; // 110%
    uint256 public constant LIQUIDATION_THRESHOLD = 10500; // 105%
    
    enum CollateralType {
        STABLE,
        VOLATILE,
        LP_TOKEN,
        SYNTHETIC,
        YIELD_BEARING,
        NFT,
        CROSS_CHAIN
    }
    
    enum CollateralStatus {
        ACTIVE,
        DEPRECATED,
        EMERGENCY_FROZEN,
        LIQUIDATION_ONLY
    }
    
    enum PositionStatus {
        HEALTHY,
        WARNING,
        LIQUIDATABLE,
        LIQUIDATING,
        CLOSED
    }
    
    struct CollateralAsset {
        address token;
        CollateralType collateralType;
        uint256 collateralFactor; // Loan-to-value ratio in basis points
        uint256 liquidationThreshold;
        uint256 liquidationPenalty;
        uint256 maxSupply; // Maximum total collateral allowed
        uint256 currentSupply;
        uint256 priceVolatility; // Historical volatility
        uint256 liquidityScore; // 1-100 scale
        uint256 lastPriceUpdate;
        uint256 price; // Current price in USD (18 decimals)
        CollateralStatus status;
        bool crossCollateralEnabled;
        uint256 haircut; // Risk adjustment factor
        uint256 concentrationLimit; // Max percentage of total collateral
    }
    
    struct UserPosition {
        address user;
        mapping(address => uint256) collateralBalances; // token => amount
        mapping(address => uint256) borrowBalances; // token => amount
        uint256 totalCollateralValue; // USD value
        uint256 totalBorrowValue; // USD value
        uint256 healthFactor;
        uint256 liquidationPrice; // Price at which position becomes liquidatable
        uint256 lastUpdate;
        PositionStatus status;
        bool crossCollateralEnabled;
        uint256 riskScore; // Calculated risk score
    }
    
    struct LiquidationData {
        address user;
        address collateralAsset;
        address debtAsset;
        uint256 collateralAmount;
        uint256 debtAmount;
        uint256 liquidationPrice;
        uint256 penalty;
        uint256 timestamp;
        address liquidator;
        bool completed;
    }
    
    struct RiskParameters {
        uint256 maxLeverage; // Maximum leverage allowed
        uint256 diversificationBonus; // Bonus for diversified collateral
        uint256 concentrationPenalty; // Penalty for concentrated positions
        uint256 volatilityAdjustment; // Adjustment based on asset volatility
        uint256 correlationDiscount; // Discount for correlated assets
        uint256 liquidityDiscount; // Discount for illiquid assets
        uint256 timeDecayFactor; // Time-based risk adjustment
    }
    
    struct CrossCollateralPool {
        address[] assets;
        uint256[] weights; // Relative weights for each asset
        uint256 totalValue;
        uint256 utilizationRate;
        uint256 riskScore;
        bool active;
        mapping(address => uint256) userShares; // user => shares
        uint256 totalShares;
    }
    
    struct LiquidationIncentive {
        uint256 baseIncentive; // Base liquidation incentive
        uint256 sizeMultiplier; // Multiplier based on liquidation size
        uint256 urgencyMultiplier; // Multiplier based on urgency
        uint256 gasCompensation; // Gas compensation for liquidators
        uint256 maxIncentive; // Maximum total incentive
    }
    
    // Storage
    mapping(address => CollateralAsset) public collateralAssets;
    mapping(address => UserPosition) public userPositions;
    mapping(uint256 => LiquidationData) public liquidations;
    mapping(address => bool) public supportedAssets;
    mapping(address => uint256[]) public userLiquidationHistory;
    
    // Cross-collateral pools
    mapping(uint256 => CrossCollateralPool) public crossCollateralPools;
    uint256 public poolCounter;
    
    // Risk management
    RiskParameters public riskParams;
    LiquidationIncentive public liquidationIncentive;
    
    // Asset tracking
    address[] public allCollateralAssets;
    uint256 public liquidationCounter;
    
    // Global parameters
    uint256 public globalCollateralCap = 1000000000 * 1e18; // $1B cap
    uint256 public systemUtilizationRate;
    uint256 public totalCollateralValue;
    uint256 public totalBorrowValue;
    
    // Emergency controls
    bool public emergencyMode;
    bool public liquidationsEnabled = true;
    mapping(address => bool) public assetEmergencyFrozen;
    
    // Oracle integration
    mapping(address => address) public priceOracles;
    uint256 public priceValidityPeriod = 1 hours;
    
    event CollateralDeposited(
        address indexed user,
        address indexed asset,
        uint256 amount,
        uint256 newBalance
    );
    
    event CollateralWithdrawn(
        address indexed user,
        address indexed asset,
        uint256 amount,
        uint256 newBalance
    );
    
    event LiquidationExecuted(
        uint256 indexed liquidationId,
        address indexed user,
        address indexed liquidator,
        address collateralAsset,
        uint256 collateralAmount,
        uint256 debtRepaid
    );
    
    event HealthFactorUpdated(
        address indexed user,
        uint256 oldHealthFactor,
        uint256 newHealthFactor,
        PositionStatus status
    );
    
    event CrossCollateralPoolCreated(
        uint256 indexed poolId,
        address[] assets,
        uint256[] weights
    );
    
    event RiskParametersUpdated(
        uint256 maxLeverage,
        uint256 diversificationBonus,
        uint256 concentrationPenalty
    );
    
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(RISK_MANAGER_ROLE, msg.sender);
        _grantRole(KEEPER_ROLE, msg.sender);
        
        // Initialize default risk parameters
        riskParams = RiskParameters({
            maxLeverage: 500, // 5x leverage
            diversificationBonus: 500, // 5% bonus
            concentrationPenalty: 1000, // 10% penalty
            volatilityAdjustment: 2000, // 20% adjustment
            correlationDiscount: 500, // 5% discount
            liquidityDiscount: 1000, // 10% discount
            timeDecayFactor: 100 // 1% per day
        });
        
        // Initialize liquidation incentives
        liquidationIncentive = LiquidationIncentive({
            baseIncentive: 500, // 5%
            sizeMultiplier: 100, // 1% per $100k
            urgencyMultiplier: 200, // 2% per hour overdue
            gasCompensation: 50 * 1e18, // 50 tokens
            maxIncentive: 2000 // 20% max
        });
    }
    
    /**
     * @dev Add a new collateral asset
     */
    function addCollateralAsset(
        address token,
        CollateralType collateralType,
        uint256 collateralFactor,
        uint256 liquidationThreshold,
        uint256 liquidationPenalty,
        uint256 maxSupply,
        address priceOracle
    ) external onlyRole(RISK_MANAGER_ROLE) {
        require(token != address(0), "Invalid token address");
        require(!supportedAssets[token], "Asset already supported");
        require(collateralFactor <= BASIS_POINTS, "Invalid collateral factor");
        require(liquidationThreshold <= BASIS_POINTS, "Invalid liquidation threshold");
        require(allCollateralAssets.length < MAX_COLLATERAL_TYPES, "Too many collateral types");
        
        collateralAssets[token] = CollateralAsset({
            token: token,
            collateralType: collateralType,
            collateralFactor: collateralFactor,
            liquidationThreshold: liquidationThreshold,
            liquidationPenalty: liquidationPenalty,
            maxSupply: maxSupply,
            currentSupply: 0,
            priceVolatility: 0,
            liquidityScore: 50, // Default score
            lastPriceUpdate: 0,
            price: 0,
            status: CollateralStatus.ACTIVE,
            crossCollateralEnabled: true,
            haircut: _calculateDefaultHaircut(collateralType),
            concentrationLimit: 2000 // 20% default limit
        });
        
        supportedAssets[token] = true;
        allCollateralAssets.push(token);
        priceOracles[token] = priceOracle;
    }
    
    /**
     * @dev Deposit collateral
     */
    function depositCollateral(
        address asset,
        uint256 amount
    ) external nonReentrant {
        require(!emergencyMode, "Emergency mode active");
        require(supportedAssets[asset], "Asset not supported");
        require(amount > 0, "Invalid amount");
        
        CollateralAsset storage collateral = collateralAssets[asset];
        require(collateral.status == CollateralStatus.ACTIVE, "Asset not active");
        require(!assetEmergencyFrozen[asset], "Asset frozen");
        require(
            collateral.currentSupply + amount <= collateral.maxSupply,
            "Exceeds max supply"
        );
        
        // Update price before calculations
        _updateAssetPrice(asset);
        
        // Transfer tokens
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
        
        // Update user position
        UserPosition storage position = userPositions[msg.sender];
        position.user = msg.sender;
        position.collateralBalances[asset] += amount;
        
        // Update collateral supply
        collateral.currentSupply += amount;
        
        // Recalculate position metrics
        _updateUserPosition(msg.sender);
        
        emit CollateralDeposited(msg.sender, asset, amount, position.collateralBalances[asset]);
    }
    
    /**
     * @dev Withdraw collateral
     */
    function withdrawCollateral(
        address asset,
        uint256 amount
    ) external nonReentrant {
        require(!emergencyMode, "Emergency mode active");
        require(amount > 0, "Invalid amount");
        
        UserPosition storage position = userPositions[msg.sender];
        require(position.collateralBalances[asset] >= amount, "Insufficient collateral");
        
        // Update price before calculations
        _updateAssetPrice(asset);
        
        // Calculate new position after withdrawal
        uint256 newCollateralBalance = position.collateralBalances[asset] - amount;
        uint256 assetPrice = collateralAssets[asset].price;
        uint256 withdrawnValue = (amount * assetPrice) / PRECISION;
        
        // Check if withdrawal maintains healthy position
        uint256 newTotalCollateralValue = position.totalCollateralValue - withdrawnValue;
        uint256 newHealthFactor = _calculateHealthFactor(
            newTotalCollateralValue,
            position.totalBorrowValue
        );
        
        require(
            newHealthFactor >= MIN_COLLATERAL_RATIO || position.totalBorrowValue == 0,
            "Withdrawal would make position unhealthy"
        );
        
        // Update balances
        position.collateralBalances[asset] = newCollateralBalance;
        collateralAssets[asset].currentSupply -= amount;
        
        // Recalculate position metrics
        _updateUserPosition(msg.sender);
        
        // Transfer tokens
        IERC20(asset).safeTransfer(msg.sender, amount);
        
        emit CollateralWithdrawn(msg.sender, asset, amount, newCollateralBalance);
    }
    
    /**
     * @dev Liquidate an unhealthy position
     */
    function liquidatePosition(
        address user,
        address collateralAsset,
        address debtAsset,
        uint256 maxDebtToCover
    ) external onlyRole(LIQUIDATOR_ROLE) nonReentrant {
        require(liquidationsEnabled, "Liquidations disabled");
        require(supportedAssets[collateralAsset], "Invalid collateral asset");
        
        UserPosition storage position = userPositions[user];
        require(position.status == PositionStatus.LIQUIDATABLE, "Position not liquidatable");
        
        // Update prices
        _updateAssetPrice(collateralAsset);
        _updateAssetPrice(debtAsset);
        
        // Calculate liquidation amounts
        (uint256 collateralToSeize, uint256 debtToRepay) = _calculateLiquidationAmounts(
            user,
            collateralAsset,
            debtAsset,
            maxDebtToCover
        );
        
        require(collateralToSeize > 0 && debtToRepay > 0, "Invalid liquidation amounts");
        
        // Execute liquidation
        uint256 liquidationId = ++liquidationCounter;
        
        // Transfer debt repayment from liquidator
        IERC20(debtAsset).safeTransferFrom(msg.sender, address(this), debtToRepay);
        
        // Transfer collateral to liquidator (with penalty)
        uint256 penalty = (collateralToSeize * collateralAssets[collateralAsset].liquidationPenalty) / BASIS_POINTS;
        uint256 liquidatorReward = collateralToSeize + penalty;
        
        IERC20(collateralAsset).safeTransfer(msg.sender, liquidatorReward);
        
        // Update user position
        position.collateralBalances[collateralAsset] -= collateralToSeize;
        position.borrowBalances[debtAsset] -= debtToRepay;
        
        // Update collateral supply
        collateralAssets[collateralAsset].currentSupply -= collateralToSeize;
        
        // Record liquidation
        liquidations[liquidationId] = LiquidationData({
            user: user,
            collateralAsset: collateralAsset,
            debtAsset: debtAsset,
            collateralAmount: collateralToSeize,
            debtAmount: debtToRepay,
            liquidationPrice: collateralAssets[collateralAsset].price,
            penalty: penalty,
            timestamp: block.timestamp,
            liquidator: msg.sender,
            completed: true
        });
        
        userLiquidationHistory[user].push(liquidationId);
        
        // Recalculate position
        _updateUserPosition(user);
        
        emit LiquidationExecuted(
            liquidationId,
            user,
            msg.sender,
            collateralAsset,
            collateralToSeize,
            debtToRepay
        );
    }
    
    /**
     * @dev Create cross-collateral pool
     */
    function createCrossCollateralPool(
        address[] memory assets,
        uint256[] memory weights
    ) external onlyRole(RISK_MANAGER_ROLE) returns (uint256 poolId) {
        require(assets.length == weights.length, "Arrays length mismatch");
        require(assets.length >= 2 && assets.length <= 10, "Invalid pool size");
        
        // Validate assets and weights
        uint256 totalWeight = 0;
        for (uint256 i = 0; i < assets.length; i++) {
            require(supportedAssets[assets[i]], "Asset not supported");
            require(weights[i] > 0, "Invalid weight");
            totalWeight += weights[i];
        }
        require(totalWeight == BASIS_POINTS, "Weights must sum to 100%");
        
        poolId = ++poolCounter;
        CrossCollateralPool storage pool = crossCollateralPools[poolId];
        pool.assets = assets;
        pool.weights = weights;
        pool.active = true;
        
        emit CrossCollateralPoolCreated(poolId, assets, weights);
    }
    
    /**
     * @dev Update user position metrics
     */
    function _updateUserPosition(address user) internal {
        UserPosition storage position = userPositions[user];
        
        // Calculate total collateral value
        uint256 totalCollateralValue = 0;
        for (uint256 i = 0; i < allCollateralAssets.length; i++) {
            address asset = allCollateralAssets[i];
            uint256 balance = position.collateralBalances[asset];
            if (balance > 0) {
                uint256 assetValue = _calculateAssetValue(asset, balance);
                totalCollateralValue += assetValue;
            }
        }
        
        // Calculate total borrow value from all borrowed assets
        uint256 totalBorrowValue = _calculateTotalBorrowValue(user);
        
        // Calculate health factor
        uint256 healthFactor = _calculateHealthFactor(totalCollateralValue, totalBorrowValue);
        
        // Calculate risk score
        uint256 riskScore = _calculateRiskScore(user);
        
        // Update position
        uint256 oldHealthFactor = position.healthFactor;
        position.totalCollateralValue = totalCollateralValue;
        position.healthFactor = healthFactor;
        position.riskScore = riskScore;
        position.lastUpdate = block.timestamp;
        
        // Update position status
        PositionStatus oldStatus = position.status;
        if (totalBorrowValue == 0) {
            position.status = PositionStatus.HEALTHY;
        } else if (healthFactor >= MIN_COLLATERAL_RATIO) {
            position.status = PositionStatus.HEALTHY;
        } else if (healthFactor >= LIQUIDATION_THRESHOLD) {
            position.status = PositionStatus.WARNING;
        } else {
            position.status = PositionStatus.LIQUIDATABLE;
        }
        
        // Update global metrics
        _updateGlobalMetrics();
        
        if (oldHealthFactor != healthFactor || oldStatus != position.status) {
            emit HealthFactorUpdated(user, oldHealthFactor, healthFactor, position.status);
        }
    }
    
    /**
     * @dev Calculate asset value with risk adjustments
     */
    function _calculateAssetValue(address asset, uint256 amount) internal view returns (uint256) {
        CollateralAsset memory collateral = collateralAssets[asset];
        
        // Base value
        uint256 baseValue = (amount * collateral.price) / PRECISION;
        
        // Apply collateral factor
        uint256 adjustedValue = (baseValue * collateral.collateralFactor) / BASIS_POINTS;
        
        // Apply haircut for risk
        adjustedValue = (adjustedValue * (BASIS_POINTS - collateral.haircut)) / BASIS_POINTS;
        
        return adjustedValue;
    }
    
    /**
     * @dev Calculate health factor
     */
    function _calculateHealthFactor(
        uint256 totalCollateralValue,
        uint256 totalBorrowValue
    ) internal pure returns (uint256) {
        if (totalBorrowValue == 0) {
            return type(uint256).max; // Infinite health factor
        }
        
        return (totalCollateralValue * BASIS_POINTS) / totalBorrowValue;
    }
    
    /**
     * @dev Calculate user risk score
     */
    function _calculateRiskScore(address user) internal view returns (uint256) {
        UserPosition storage position = userPositions[user];
        
        if (position.totalCollateralValue == 0) {
            return 0;
        }
        
        uint256 riskScore = 0;
        uint256 totalValue = position.totalCollateralValue;
        
        // Calculate concentration risk
        uint256 maxAssetConcentration = 0;
        for (uint256 i = 0; i < allCollateralAssets.length; i++) {
            address asset = allCollateralAssets[i];
            uint256 balance = position.collateralBalances[asset];
            if (balance > 0) {
                uint256 assetValue = _calculateAssetValue(asset, balance);
                uint256 concentration = (assetValue * BASIS_POINTS) / totalValue;
                if (concentration > maxAssetConcentration) {
                    maxAssetConcentration = concentration;
                }
                
                // Add asset-specific risk
                CollateralAsset memory collateral = collateralAssets[asset];
                riskScore += (concentration * collateral.priceVolatility) / BASIS_POINTS;
            }
        }
        
        // Add concentration penalty
        if (maxAssetConcentration > 5000) { // > 50%
            riskScore += riskParams.concentrationPenalty;
        }
        
        // Add leverage risk
        if (position.totalBorrowValue > 0) {
            uint256 leverage = (position.totalBorrowValue * BASIS_POINTS) / position.totalCollateralValue;
            riskScore += (leverage * riskParams.maxLeverage) / BASIS_POINTS;
        }
        
        return Math.min(riskScore, 10000); // Cap at 100%
    }
    
    /**
     * @dev Calculate liquidation amounts
     */
    function _calculateLiquidationAmounts(
        address user,
        address collateralAsset,
        address debtAsset,
        uint256 maxDebtToCover
    ) internal view returns (uint256 collateralToSeize, uint256 debtToRepay) {
        UserPosition storage position = userPositions[user];
        
        uint256 userDebt = position.borrowBalances[debtAsset];
        uint256 userCollateral = position.collateralBalances[collateralAsset];
        
        // Calculate maximum debt that can be repaid (50% of total debt)
        uint256 maxRepayableDebt = userDebt / 2;
        debtToRepay = Math.min(maxDebtToCover, maxRepayableDebt);
        
        // Calculate collateral to seize
        uint256 collateralPrice = collateralAssets[collateralAsset].price;
        uint256 debtPrice = collateralAssets[debtAsset].price; // Assuming debt asset is also collateral
        
        uint256 collateralValueToSeize = (debtToRepay * debtPrice) / collateralPrice;
        collateralToSeize = Math.min(collateralValueToSeize, userCollateral);
    }
    
    /**
     * @dev Update asset price from oracle
     */
    function _updateAssetPrice(address asset) internal {
        address oracle = priceOracles[asset];
        if (oracle != address(0)) {
            CollateralAsset storage collateral = collateralAssets[asset];
            
            // Get price from oracle
            try IPriceOracle(oracle).getPrice(asset) returns (uint256 newPrice) {
                collateral.price = newPrice;
                collateral.lastPriceUpdate = block.timestamp;
                
                emit AssetPriceUpdated(asset, newPrice, block.timestamp);
            } catch {
                // Oracle call failed, keep existing price
                emit OracleUpdateFailed(asset, oracle);
            }
        }
    }
    
    /**
     * @dev Calculate default haircut based on collateral type
     */
    function _calculateDefaultHaircut(CollateralType collateralType) internal pure returns (uint256) {
        if (collateralType == CollateralType.STABLE) {
            return 100; // 1%
        } else if (collateralType == CollateralType.VOLATILE) {
            return 1000; // 10%
        } else if (collateralType == CollateralType.LP_TOKEN) {
            return 1500; // 15%
        } else if (collateralType == CollateralType.YIELD_BEARING) {
            return 500; // 5%
        } else {
            return 2000; // 20% for other types
        }
    }
    
    /**
     * @dev Update global system metrics
     */
    function _updateGlobalMetrics() internal {
        uint256 totalCollateral = 0;
        uint256 totalBorrow = 0;
        
        // Iterate through all user positions to calculate global metrics
        for (uint256 i = 0; i < allUsers.length; i++) {
            address user = allUsers[i];
            CollateralPosition storage position = collateralPositions[user];
            
            // Sum collateral values
            for (uint256 j = 0; j < position.collateralAssets.length; j++) {
                address asset = position.collateralAssets[j];
                uint256 balance = position.collateralBalances[asset];
                totalCollateral += _calculateAssetValue(asset, balance);
            }
            
            // Sum borrow values
            totalBorrow += _calculateTotalBorrowValue(user);
        }
        
        totalCollateralValue = totalCollateral;
        totalBorrowValue = totalBorrow;
        
        if (totalCollateral > 0) {
            systemUtilizationRate = (totalBorrow * BASIS_POINTS) / totalCollateral;
        } else {
            systemUtilizationRate = 0;
        }
    }
    
    /**
     * @dev Get user position info
     */
    function getUserPosition(address user) 
        external 
        view 
        returns (
            uint256 totalCollateralValue,
            uint256 totalBorrowValue,
            uint256 healthFactor,
            uint256 riskScore,
            PositionStatus status
        ) 
    {
        UserPosition storage position = userPositions[user];
        return (
            position.totalCollateralValue,
            position.totalBorrowValue,
            position.healthFactor,
            position.riskScore,
            position.status
        );
    }
    
    /**
     * @dev Get user collateral balance
     */
    function getUserCollateralBalance(address user, address asset) 
        external 
        view 
        returns (uint256) 
    {
        return userPositions[user].collateralBalances[asset];
    }
    
    /**
     * @dev Get collateral asset info
     */
    function getCollateralAssetInfo(address asset) 
        external 
        view 
        returns (
            CollateralType collateralType,
            uint256 collateralFactor,
            uint256 liquidationThreshold,
            uint256 currentSupply,
            uint256 maxSupply,
            uint256 price,
            CollateralStatus status
        ) 
    {
        CollateralAsset memory collateral = collateralAssets[asset];
        return (
            collateral.collateralType,
            collateral.collateralFactor,
            collateral.liquidationThreshold,
            collateral.currentSupply,
            collateral.maxSupply,
            collateral.price,
            collateral.status
        );
    }
    
    /**
     * @dev Update collateral factor
     */
    function updateCollateralFactor(address asset, uint256 newFactor) 
        external 
        onlyRole(RISK_MANAGER_ROLE) 
    {
        require(supportedAssets[asset], "Asset not supported");
        require(newFactor <= BASIS_POINTS, "Invalid factor");
        
        collateralAssets[asset].collateralFactor = newFactor;
    }
    
    /**
     * @dev Update liquidation threshold
     */
    function updateLiquidationThreshold(address asset, uint256 newThreshold) 
        external 
        onlyRole(RISK_MANAGER_ROLE) 
    {
        require(supportedAssets[asset], "Asset not supported");
        require(newThreshold <= BASIS_POINTS, "Invalid threshold");
        
        collateralAssets[asset].liquidationThreshold = newThreshold;
    }
    
    /**
     * @dev Update risk parameters
     */
    function updateRiskParameters(
        uint256 maxLeverage,
        uint256 diversificationBonus,
        uint256 concentrationPenalty
    ) external onlyRole(RISK_MANAGER_ROLE) {
        riskParams.maxLeverage = maxLeverage;
        riskParams.diversificationBonus = diversificationBonus;
        riskParams.concentrationPenalty = concentrationPenalty;
        
        emit RiskParametersUpdated(maxLeverage, diversificationBonus, concentrationPenalty);
    }
    
    /**
     * @dev Emergency freeze asset
     */
    function emergencyFreezeAsset(address asset) external onlyRole(ADMIN_ROLE) {
        assetEmergencyFrozen[asset] = true;
        collateralAssets[asset].status = CollateralStatus.EMERGENCY_FROZEN;
    }
    
    /**
     * @dev Unfreeze asset
     */
    function unfreezeAsset(address asset) external onlyRole(ADMIN_ROLE) {
        assetEmergencyFrozen[asset] = false;
        collateralAssets[asset].status = CollateralStatus.ACTIVE;
    }
    
    /**
     * @dev Enable/disable liquidations
     */
    function setLiquidationsEnabled(bool enabled) external onlyRole(ADMIN_ROLE) {
        liquidationsEnabled = enabled;
    }
    
    /**
     * @dev Set emergency mode
     */
    function setEmergencyMode(bool enabled) external onlyRole(ADMIN_ROLE) {
        emergencyMode = enabled;
    }
    
    /**
     * @dev Update price oracle for asset
     */
    function updatePriceOracle(address asset, address oracle) 
        external 
        onlyRole(ADMIN_ROLE) 
    {
        require(supportedAssets[asset], "Asset not supported");
        priceOracles[asset] = oracle;
    }
    
    /**
     * @dev Get all supported assets
     */
    function getAllSupportedAssets() external view returns (address[] memory) {
        return allCollateralAssets;
    }
    
    /**
     * @dev Get liquidation history for user
     */
    function getUserLiquidationHistory(address user) 
        external 
        view 
        returns (uint256[] memory) 
    {
        return userLiquidationHistory[user];
    }

    /**
     * @dev Calculate total borrow value for a user
     */
    function _calculateTotalBorrowValue(address user) internal view returns (uint256) {
        CollateralPosition storage position = collateralPositions[user];
        
        // In a real implementation, this would integrate with lending protocols
        // to get actual borrowed amounts and calculate their USD value
        // For now, return the stored total borrow value
        return position.totalBorrowValue;
    }

    /**
     * @dev Add missing events
     */
    event AssetPriceUpdated(address indexed asset, uint256 newPrice, uint256 timestamp);
    event OracleUpdateFailed(address indexed asset, address indexed oracle);
}