// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
/**
 * @title RiskEngine
 * @dev Manages risk assessment and mitigation across the protocol
 */
contract RiskEngine is AccessControl, ReentrancyGuard, Pausable {
    using Math for uint256;
    
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant RISK_MANAGER_ROLE = keccak256("RISK_MANAGER_ROLE");
    bytes32 public constant LIQUIDATOR_ROLE = keccak256("LIQUIDATOR_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    
    uint256 public constant PRECISION = 1e18;
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant MAX_LIQUIDATION_THRESHOLD = 9500; // 95%
    uint256 public constant MIN_LIQUIDATION_THRESHOLD = 5000; // 50%
    
    // Risk levels
    enum RiskLevel {
        LOW,
        MEDIUM,
        HIGH,
        CRITICAL
    }
    
    // Asset risk parameters
    struct AssetRiskParams {
        uint256 liquidationThreshold; // Basis points
        uint256 liquidationPenalty; // Basis points
        uint256 maxLoanToValue; // Basis points
        uint256 volatilityScore; // 0-100
        uint256 liquidityScore; // 0-100
        bool isActive;
        RiskLevel riskLevel;
    }
    
    // User risk profile
    struct UserRiskProfile {
        uint256 totalCollateral;
        uint256 totalDebt;
        uint256 healthFactor;
        uint256 liquidationPrice;
        RiskLevel riskLevel;
        uint256 lastUpdateTimestamp;
        bool isLiquidatable;
    }
    
    // Market risk parameters
    struct MarketRiskParams {
        uint256 maxUtilizationRate; // Basis points
        uint256 emergencyThreshold; // Basis points
        uint256 pauseThreshold; // Basis points
        uint256 maxBorrowRate; // Basis points
        bool isActive;
    }
    
    // Risk metrics
    struct RiskMetrics {
        uint256 totalValueLocked;
        uint256 totalBorrowed;
        uint256 utilizationRate;
        uint256 averageHealthFactor;
        uint256 liquidationsCount;
        uint256 lastUpdateTimestamp;
    }
    
    mapping(address => AssetRiskParams) public assetRiskParams;
    mapping(address => UserRiskProfile) public userRiskProfiles;
    mapping(address => MarketRiskParams) public marketRiskParams;
    mapping(address => bool) public supportedAssets;
    mapping(address => uint256) public assetPrices;
    mapping(address => uint256) public priceUpdateTimestamps;
    
    RiskMetrics public globalRiskMetrics;
    
    // Risk thresholds
    uint256 public globalHealthFactorThreshold = 1.1e18; // 110%
    uint256 public emergencyHealthFactorThreshold = 1.05e18; // 105%
    uint256 public maxGlobalUtilization = 8000; // 80%
    uint256 public priceValidityPeriod = 3600; // 1 hour
    
    // Oracle and external contracts
    address public priceOracle;
    address public liquidationManager;
    
    // Events
    event RiskParametersUpdated(
        address indexed asset,
        uint256 liquidationThreshold,
        uint256 liquidationPenalty,
        uint256 maxLoanToValue
    );
    
    event UserRiskProfileUpdated(
        address indexed user,
        uint256 healthFactor,
        RiskLevel riskLevel,
        bool isLiquidatable
    );
    
    event LiquidationTriggered(
        address indexed user,
        address indexed asset,
        uint256 amount,
        uint256 penalty
    );
    
    event EmergencyModeActivated(string reason);
    event EmergencyModeDeactivated();
    
    event PriceUpdated(address indexed asset, uint256 price, uint256 timestamp);
    
    constructor(
        address _priceOracle,
        address _liquidationManager
    ) {
        require(_priceOracle != address(0), "RiskEngine: invalid oracle");
        require(_liquidationManager != address(0), "RiskEngine: invalid liquidation manager");
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(RISK_MANAGER_ROLE, msg.sender);
        _grantRole(LIQUIDATOR_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        
        priceOracle = _priceOracle;
        liquidationManager = _liquidationManager;
    }
    
    /**
     * @dev Calculate user health factor
     */
    function calculateHealthFactor(
        address user,
        address[] calldata collateralAssets,
        uint256[] calldata collateralAmounts,
        address[] calldata debtAssets,
        uint256[] calldata debtAmounts
    ) external view returns (uint256 healthFactor) {
        require(
            collateralAssets.length == collateralAmounts.length,
            "RiskEngine: collateral arrays length mismatch"
        );
        require(
            debtAssets.length == debtAmounts.length,
            "RiskEngine: debt arrays length mismatch"
        );
        
        uint256 totalCollateralValue = 0;
        uint256 totalDebtValue = 0;
        
        // Calculate total collateral value with liquidation thresholds
        for (uint256 i = 0; i < collateralAssets.length; i++) {
            address asset = collateralAssets[i];
            uint256 amount = collateralAmounts[i];
            
            if (supportedAssets[asset] && amount > 0) {
                uint256 price = _getAssetPrice(asset);
                uint256 value = (amount * price) / PRECISION;
                
                AssetRiskParams storage params = assetRiskParams[asset];
                uint256 adjustedValue = (value * params.liquidationThreshold) / BASIS_POINTS;
                totalCollateralValue = totalCollateralValue + adjustedValue;
            }
        }
        
        // Calculate total debt value
        for (uint256 i = 0; i < debtAssets.length; i++) {
            address asset = debtAssets[i];
            uint256 amount = debtAmounts[i];
            
            if (supportedAssets[asset] && amount > 0) {
                uint256 price = _getAssetPrice(asset);
                uint256 value = (amount * price) / PRECISION;
                totalDebtValue = totalDebtValue + value;
            }
        }
        
        // Calculate health factor
        if (totalDebtValue == 0) {
            healthFactor = type(uint256).max;
        } else {
            healthFactor = (totalCollateralValue * PRECISION) / totalDebtValue;
        }
    }
    
    /**
     * @dev Update user risk profile
     */
    function updateUserRiskProfile(
        address user,
        uint256 totalCollateral,
        uint256 totalDebt,
        uint256 healthFactor
    ) external onlyRole(RISK_MANAGER_ROLE) {
        UserRiskProfile storage profile = userRiskProfiles[user];
        
        profile.totalCollateral = totalCollateral;
        profile.totalDebt = totalDebt;
        profile.healthFactor = healthFactor;
        profile.lastUpdateTimestamp = block.timestamp;
        
        // Determine risk level
        if (healthFactor >= 1.5e18) {
            profile.riskLevel = RiskLevel.LOW;
        } else if (healthFactor >= 1.25e18) {
            profile.riskLevel = RiskLevel.MEDIUM;
        } else if (healthFactor >= globalHealthFactorThreshold) {
            profile.riskLevel = RiskLevel.HIGH;
        } else {
            profile.riskLevel = RiskLevel.CRITICAL;
        }
        
        // Check if liquidatable
        profile.isLiquidatable = healthFactor < globalHealthFactorThreshold;
        
        // Calculate liquidation price if applicable
        if (totalCollateral > 0 && totalDebt > 0) {
            profile.liquidationPrice = (totalDebt * globalHealthFactorThreshold) / totalCollateral;
        }
        
        emit UserRiskProfileUpdated(
            user,
            healthFactor,
            profile.riskLevel,
            profile.isLiquidatable
        );
        
        // Trigger emergency actions if needed
        _checkEmergencyConditions(user, healthFactor);
    }
    
    /**
     * @dev Check if user is liquidatable
     */
    /**
     * @dev Calculate a simple risk score for an asset using stored risk parameters.
     * @param asset The asset address
     * @return score Risk score scaled by 1e18 (higher = riskier)
     */
    function calculateRiskScore(address asset) external view returns (uint256 score) {
        AssetRiskParams storage params = assetRiskParams[asset];
        if (!params.isActive) {
            return 0; // Unsupported asset => 0 risk score
        }
        // Combine volatility and liquidity scores (0-100 each) into a 0-200 domain
        uint256 combined = params.volatilityScore + (100 - params.liquidityScore);
        // Map RiskLevel to multiplier (LOW=1, MEDIUM=2, HIGH=3, CRITICAL=4)
        uint256 levelMultiplier = uint256(params.riskLevel) + 1;
        // Final score scaled by PRECISION
        score = combined * levelMultiplier * 1e16; // 200 * 4 * 1e16 = 8e18 max
    }

    function isLiquidatable(address user) external view returns (bool) {
        UserRiskProfile storage profile = userRiskProfiles[user];
        return profile.isLiquidatable && profile.healthFactor < globalHealthFactorThreshold;
    }
    
    /**
     * @dev Calculate liquidation amount
     */
    function calculateLiquidationAmount(
        address user,
        address collateralAsset,
        address debtAsset,
        uint256 maxLiquidationRatio
    ) external view returns (
        uint256 liquidationAmount,
        uint256 collateralToSeize,
        uint256 penalty
    ) {
        UserRiskProfile storage profile = userRiskProfiles[user];
        require(profile.isLiquidatable, "RiskEngine: user not liquidatable");
        
        AssetRiskParams storage collateralParams = assetRiskParams[collateralAsset];
        AssetRiskParams storage debtParams = assetRiskParams[debtAsset];
        
        // Calculate maximum liquidation amount (typically 50% of debt)
        uint256 maxLiquidation = (profile.totalDebt * maxLiquidationRatio) / BASIS_POINTS;
        liquidationAmount = Math.min(maxLiquidation, profile.totalDebt);
        
        // Calculate collateral to seize
        uint256 collateralPrice = _getAssetPrice(collateralAsset);
        uint256 debtPrice = _getAssetPrice(debtAsset);
        
        uint256 collateralValue = (liquidationAmount * debtPrice) / collateralPrice;
        
        // Apply liquidation penalty
        penalty = (collateralValue * collateralParams.liquidationPenalty) / BASIS_POINTS;
        collateralToSeize = collateralValue + penalty;
    }
    
    /**
     * @dev Set asset risk parameters
     */
    function setAssetRiskParameters(
        address asset,
        uint256 liquidationThreshold,
        uint256 liquidationPenalty,
        uint256 maxLoanToValue,
        uint256 volatilityScore,
        uint256 liquidityScore,
        RiskLevel riskLevel,
        bool isActive
    ) external onlyRole(ADMIN_ROLE) {
        require(asset != address(0), "RiskEngine: invalid asset");
        require(
            liquidationThreshold >= MIN_LIQUIDATION_THRESHOLD &&
            liquidationThreshold <= MAX_LIQUIDATION_THRESHOLD,
            "RiskEngine: invalid liquidation threshold"
        );
        require(liquidationPenalty <= 2000, "RiskEngine: penalty too high"); // Max 20%
        require(maxLoanToValue <= liquidationThreshold, "RiskEngine: LTV too high");
        require(volatilityScore <= 100, "RiskEngine: invalid volatility score");
        require(liquidityScore <= 100, "RiskEngine: invalid liquidity score");
        
        assetRiskParams[asset] = AssetRiskParams({
            liquidationThreshold: liquidationThreshold,
            liquidationPenalty: liquidationPenalty,
            maxLoanToValue: maxLoanToValue,
            volatilityScore: volatilityScore,
            liquidityScore: liquidityScore,
            isActive: isActive,
            riskLevel: riskLevel
        });
        
        supportedAssets[asset] = isActive;
        
        emit RiskParametersUpdated(
            asset,
            liquidationThreshold,
            liquidationPenalty,
            maxLoanToValue
        );
    }
    
    /**
     * @dev Set market risk parameters
     */
    function setMarketRiskParameters(
        address market,
        uint256 maxUtilizationRate,
        uint256 emergencyThreshold,
        uint256 pauseThreshold,
        uint256 maxBorrowRate,
        bool isActive
    ) external onlyRole(ADMIN_ROLE) {
        require(market != address(0), "RiskEngine: invalid market");
        require(maxUtilizationRate <= BASIS_POINTS, "RiskEngine: invalid utilization rate");
        require(emergencyThreshold <= BASIS_POINTS, "RiskEngine: invalid emergency threshold");
        require(pauseThreshold <= BASIS_POINTS, "RiskEngine: invalid pause threshold");
        
        marketRiskParams[market] = MarketRiskParams({
            maxUtilizationRate: maxUtilizationRate,
            emergencyThreshold: emergencyThreshold,
            pauseThreshold: pauseThreshold,
            maxBorrowRate: maxBorrowRate,
            isActive: isActive
        });
    }
    
    /**
     * @dev Update asset price
     */
    function updateAssetPrice(
        address asset,
        uint256 price
    ) external onlyRole(RISK_MANAGER_ROLE) {
        require(supportedAssets[asset], "RiskEngine: asset not supported");
        require(price > 0, "RiskEngine: invalid price");
        
        assetPrices[asset] = price;
        priceUpdateTimestamps[asset] = block.timestamp;
        
        emit PriceUpdated(asset, price, block.timestamp);
    }
    
    /**
     * @dev Get asset price with validity check
     */
    function getAssetPrice(address asset) external view returns (uint256 price, bool isValid) {
        price = assetPrices[asset];
        uint256 lastUpdate = priceUpdateTimestamps[asset];
        isValid = (block.timestamp - lastUpdate) <= priceValidityPeriod;
    }
    
    /**
     * @dev Update global risk metrics
     */
    function updateGlobalRiskMetrics(
        uint256 totalValueLocked,
        uint256 totalBorrowed,
        uint256 liquidationsCount
    ) external onlyRole(RISK_MANAGER_ROLE) {
        globalRiskMetrics.totalValueLocked = totalValueLocked;
        globalRiskMetrics.totalBorrowed = totalBorrowed;
        globalRiskMetrics.liquidationsCount = liquidationsCount;
        globalRiskMetrics.lastUpdateTimestamp = block.timestamp;
        
        // Calculate utilization rate
        if (totalValueLocked > 0) {
            globalRiskMetrics.utilizationRate = (totalBorrowed * BASIS_POINTS) / totalValueLocked;
        } else {
            globalRiskMetrics.utilizationRate = 0;
        }
        
        // Check if emergency mode should be activated
        if (globalRiskMetrics.utilizationRate > maxGlobalUtilization) {
            emit EmergencyModeActivated("High global utilization");
        }
    }
    
    /**
     * @dev Set global risk thresholds
     */
    function setGlobalRiskThresholds(
        uint256 _globalHealthFactorThreshold,
        uint256 _emergencyHealthFactorThreshold,
        uint256 _maxGlobalUtilization,
        uint256 _priceValidityPeriod
    ) external onlyRole(ADMIN_ROLE) {
        require(_globalHealthFactorThreshold >= PRECISION, "RiskEngine: invalid health factor threshold");
        require(_emergencyHealthFactorThreshold >= PRECISION, "RiskEngine: invalid emergency threshold");
        require(_maxGlobalUtilization <= BASIS_POINTS, "RiskEngine: invalid max utilization");
        
        globalHealthFactorThreshold = _globalHealthFactorThreshold;
        emergencyHealthFactorThreshold = _emergencyHealthFactorThreshold;
        maxGlobalUtilization = _maxGlobalUtilization;
        priceValidityPeriod = _priceValidityPeriod;
    }
    
    /**
     * @dev Get user risk assessment
     */
    function getUserRiskAssessment(address user) external view returns (
        uint256 healthFactor,
        RiskLevel riskLevel,
        bool liquidatable,
        uint256 liquidationPrice,
        uint256 maxBorrowAmount
    ) {
        UserRiskProfile storage profile = userRiskProfiles[user];
        
        healthFactor = profile.healthFactor;
        riskLevel = profile.riskLevel;
        liquidatable = profile.isLiquidatable;
        liquidationPrice = profile.liquidationPrice;
        
        // Calculate max additional borrow amount
        if (profile.totalCollateral > 0 && profile.healthFactor > globalHealthFactorThreshold) {
            uint256 maxDebt = (profile.totalCollateral * BASIS_POINTS) / globalHealthFactorThreshold;
            if (maxDebt > profile.totalDebt) {
                maxBorrowAmount = maxDebt - profile.totalDebt;
            }
        }
    }
    
    /**
     * @dev Internal function to get asset price
     */
    function _getAssetPrice(address asset) internal view returns (uint256) {
        uint256 price = assetPrices[asset];
        require(price > 0, "RiskEngine: price not available");
        
        uint256 lastUpdate = priceUpdateTimestamps[asset];
        require(
            (block.timestamp - lastUpdate) <= priceValidityPeriod,
            "RiskEngine: price too old"
        );
        
        return price;
    }
    
    /**
     * @dev Check emergency conditions and trigger actions
     */
    function _checkEmergencyConditions(address user, uint256 healthFactor) internal {
        if (healthFactor < emergencyHealthFactorThreshold) {
            emit EmergencyModeActivated("Critical health factor detected");
            
            // Additional emergency actions can be implemented here
            // such as pausing certain operations or triggering liquidations
        }
    }
    
    /**
     * @dev Emergency function to pause the contract
     */
    function emergencyPause() external onlyRole(PAUSER_ROLE) {
        _pause();
        emit EmergencyModeActivated("Manual emergency pause");
    }
    
    /**
     * @dev Unpause the contract
     */
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
        emit EmergencyModeDeactivated();
    }
    
    /**
     * @dev Update price oracle address
     */
    function setPriceOracle(address _priceOracle) external onlyRole(ADMIN_ROLE) {
        require(_priceOracle != address(0), "RiskEngine: invalid oracle");
        priceOracle = _priceOracle;
    }
    
    /**
     * @dev Update liquidation manager address
     */
    function setLiquidationManager(address _liquidationManager) external onlyRole(ADMIN_ROLE) {
        require(_liquidationManager != address(0), "RiskEngine: invalid liquidation manager");
        liquidationManager = _liquidationManager;
    }
}
