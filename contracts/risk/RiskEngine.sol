// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "../interfaces/IRiskManagement.sol";

/**
 * @title RiskEngine
 * @dev Advanced risk management engine for the Core protocol
 */
contract RiskEngine is IRiskManagement, Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;
    using Math for uint256;

    struct AssetRiskData {
        uint256 volatility; // Annualized volatility in basis points
        uint256 liquidity; // Liquidity score (0-10000)
        uint256 correlation; // Correlation with market in basis points
        uint256 lastUpdate;
        bool isActive;
    }

    struct PositionRisk {
        uint256 exposure; // Total exposure amount
        uint256 leverage; // Leverage ratio in basis points
        uint256 timeDecay; // Time decay factor
        uint256 concentrationRisk; // Concentration risk score
        uint256 liquidationThreshold; // Liquidation threshold
    }

    struct MarketConditions {
        uint256 volatilityIndex; // Market volatility index
        uint256 liquidityIndex; // Market liquidity index
        uint256 stressLevel; // Market stress level (0-100)
        uint256 correlationBreakdown; // Correlation breakdown indicator
        uint256 lastUpdate;
    }

    struct RiskAlertData {
        uint256 alertId;
        address asset;
        uint256 riskLevel; // 1-5 (1=low, 5=critical)
        string alertType;
        string description;
        uint256 timestamp;
        bool isResolved;
    }

    mapping(address => AssetRiskData) public assetRiskData;
    mapping(address => PositionRisk) public positionRisks;
    mapping(address => RiskProfile) public userRiskProfiles;
    mapping(address => RiskLimits) public userRiskLimits;
    mapping(uint256 => RiskAlertData) public riskAlerts;
    mapping(address => bool) public authorizedRiskManagers;
    mapping(address => uint256[]) public userAlerts;
    
    MarketConditions public marketConditions;
    RiskMetrics public globalRiskMetrics;
    
    uint256 public nextAlertId = 1;
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant MAX_LEVERAGE = 50000; // 5x max leverage
    uint256 public constant LIQUIDATION_BUFFER = 500; // 5% buffer
    
    // Risk thresholds
    uint256 public maxPortfolioRisk = 2000; // 20% max portfolio risk
    uint256 public maxConcentrationRisk = 3000; // 30% max concentration
    uint256 public maxVolatilityThreshold = 5000; // 50% max volatility
    uint256 public minLiquidityThreshold = 1000; // 10% min liquidity
    
    // Time windows for risk calculations
    uint256 public riskCalculationWindow = 24 hours;
    uint256 public volatilityWindow = 7 days;
    uint256 public correlationWindow = 30 days;
    
    address public priceOracle;
    address public liquidityOracle;
    bool public emergencyMode = false;

    event RiskProfileUpdated(address indexed user, RiskProfile profile);
    event RiskLimitsUpdated(address indexed user, RiskLimits limits);
    event RiskAlertCreated(uint256 indexed alertId, address indexed asset, uint256 riskLevel);
    event RiskAlertResolved(uint256 indexed alertId);
    event AssetRiskDataUpdated(address indexed asset, AssetRiskData data);
    event MarketConditionsUpdated(MarketConditions conditions);
    event EmergencyModeToggled(bool enabled);
    event RiskThresholdsUpdated(uint256 portfolio, uint256 concentration, uint256 volatility, uint256 liquidity);

    modifier onlyRiskManager() {
        require(authorizedRiskManagers[msg.sender] || msg.sender == owner(), "Not authorized risk manager");
        _;
    }

    modifier notInEmergencyMode() {
        require(!emergencyMode, "Emergency mode active");
        _;
    }

    constructor(
        address _priceOracle,
        address _liquidityOracle
    ) Ownable(msg.sender) {
        require(_priceOracle != address(0), "Invalid price oracle");
        require(_liquidityOracle != address(0), "Invalid liquidity oracle");
        
        priceOracle = _priceOracle;
        liquidityOracle = _liquidityOracle;
        
        // Initialize market conditions
        marketConditions = MarketConditions({
            volatilityIndex: 1000, // 10% baseline
            liquidityIndex: 8000,  // 80% baseline
            stressLevel: 0,        // No stress
            correlationBreakdown: 0,
            lastUpdate: block.timestamp
        });
    }

    /**
     * @dev Assess risk for a specific asset
     * @param asset Asset address to assess
     * @param amount Amount to assess
     * @return riskScore Risk score (0-10000)
     */
    function assessRisk(address asset, uint256 amount) external view override returns (uint256 riskScore) {
        AssetRiskData memory assetData = assetRiskData[asset];
        if (!assetData.isActive) return BASIS_POINTS; // 100% risk for inactive assets
        
        // Base risk from volatility
        uint256 volatilityRisk = assetData.volatility;
        
        // Liquidity risk (inverse of liquidity)
        uint256 liquidityRisk = BASIS_POINTS - assetData.liquidity;
        
        // Market correlation risk
        uint256 correlationRisk = assetData.correlation * marketConditions.stressLevel / 100;
        
        // Size risk (larger positions = higher risk)
        uint256 sizeRisk = _calculateSizeRisk(asset, amount);
        
        // Combine risks with weights
        riskScore = (volatilityRisk * 40 + liquidityRisk * 30 + correlationRisk * 20 + sizeRisk * 10) / 100;
        
        // Cap at maximum
        return riskScore > BASIS_POINTS ? BASIS_POINTS : riskScore;
    }

    /**
     * @dev Calculate portfolio risk for a user
     * @param user User address
     * @param assets Array of asset addresses
     * @param amounts Array of amounts
     * @return portfolioRisk Portfolio risk score
     */
    function calculatePortfolioRisk(
        address user,
        address[] memory assets,
        uint256[] memory amounts
    ) external view override returns (uint256 portfolioRisk) {
        require(assets.length == amounts.length, "Array length mismatch");
        
        uint256 totalValue = 0;
        uint256 weightedRisk = 0;
        
        // Calculate individual asset risks and weights
        for (uint256 i = 0; i < assets.length; i++) {
            uint256 assetValue = amounts[i]; // Simplified - should use price oracle
            uint256 assetRisk = this.assessRisk(assets[i], amounts[i]);
            
            totalValue += assetValue;
            weightedRisk += assetValue * assetRisk;
        }
        
        if (totalValue == 0) return 0;
        
        // Base portfolio risk
        portfolioRisk = weightedRisk / totalValue;
        
        // Apply concentration penalty
        uint256 concentrationPenalty = _calculateConcentrationRisk(assets, amounts);
        portfolioRisk += concentrationPenalty;
        
        // Apply correlation adjustments
        uint256 correlationAdjustment = _calculateCorrelationRisk(assets, amounts);
        portfolioRisk += correlationAdjustment;
        
        // Apply market stress multiplier
        if (marketConditions.stressLevel > 50) {
            portfolioRisk = portfolioRisk * (100 + marketConditions.stressLevel) / 100;
        }
        
        return portfolioRisk > BASIS_POINTS ? BASIS_POINTS : portfolioRisk;
    }

    /**
     * @dev Monitor risk levels and create alerts
     * @param user User address to monitor
     * @param assets Array of assets to monitor
     * @param amounts Array of amounts to monitor
     */
    function monitorRisk(
        address user,
        address[] memory assets,
        uint256[] memory amounts
    ) external override onlyRiskManager {
        uint256 portfolioRisk = this.calculatePortfolioRisk(user, assets, amounts);
        RiskLimits memory limits = userRiskLimits[user];
        
        // Check portfolio risk limit
        if (portfolioRisk > limits.maxPortfolioRisk) {
            _createRiskAlert(
                assets[0], // Use first asset as reference
                4, // High risk level
                "PORTFOLIO_RISK_EXCEEDED",
                "Portfolio risk exceeds user limits"
            );
        }
        
        // Check individual asset risks
        for (uint256 i = 0; i < assets.length; i++) {
            uint256 assetRisk = this.assessRisk(assets[i], amounts[i]);
            
            if (assetRisk > limits.maxAssetRisk) {
                _createRiskAlert(
                    assets[i],
                    3, // Medium-high risk level
                    "ASSET_RISK_EXCEEDED",
                    "Individual asset risk exceeds limits"
                );
            }
        }
        
        // Update global risk metrics
        _updateGlobalRiskMetrics(portfolioRisk);
    }

    /**
     * @dev Calculate Value at Risk (VaR)
     * @param returnValues Array of historical returns
     * @param confidenceLevel Confidence level (e.g., 95 for 95%)
     * @return valueAtRisk VaR value
     */
    function calculateVaR(
        int256[] memory returnValues,
        uint256 confidenceLevel
    ) external pure override returns (uint256 valueAtRisk) {
        require(returnValues.length > 0, "Empty returns array");
        require(confidenceLevel > 0 && confidenceLevel < 100, "Invalid confidence level");
        
        // Sort returns (simplified bubble sort for small arrays)
        int256[] memory sortedReturns = new int256[](returnValues.length);
        for (uint256 i = 0; i < returnValues.length; i++) {
            sortedReturns[i] = returnValues[i];
        }
        
        // Simple sorting algorithm
        for (uint256 i = 0; i < sortedReturns.length - 1; i++) {
            for (uint256 j = 0; j < sortedReturns.length - i - 1; j++) {
                if (sortedReturns[j] > sortedReturns[j + 1]) {
                    int256 temp = sortedReturns[j];
                    sortedReturns[j] = sortedReturns[j + 1];
                    sortedReturns[j + 1] = temp;
                }
            }
        }
        
        // Calculate percentile index
        uint256 index = (100 - confidenceLevel) * sortedReturns.length / 100;
        if (index >= sortedReturns.length) index = sortedReturns.length - 1;
        
        // Return absolute value of the VaR (loss)
        int256 varValue = sortedReturns[index];
        valueAtRisk = varValue < 0 ? uint256(-varValue) : 0;
    }

    /**
     * @dev Get portfolio VaR for a user
     * @param user User address
     * @param assets Array of assets
     * @param amounts Array of amounts
     * @param confidenceLevel Confidence level
     * @return portfolioVaR Portfolio VaR value
     */
    function getPortfolioVaR(
        address user,
        address[] memory assets,
        uint256[] memory amounts,
        uint256 confidenceLevel
    ) external view override returns (uint256 portfolioVaR) {
        // Simplified calculation - in practice would use historical data
        uint256 portfolioRisk = this.calculatePortfolioRisk(user, assets, amounts);
        uint256 totalValue = 0;
        
        for (uint256 i = 0; i < amounts.length; i++) {
            totalValue += amounts[i];
        }
        
        // VaR as percentage of portfolio value based on risk score
        portfolioVaR = totalValue * portfolioRisk / BASIS_POINTS;
        
        // Adjust for confidence level
        if (confidenceLevel > 95) {
            portfolioVaR = portfolioVaR * 150 / 100; // 1.5x for 99% confidence
        } else if (confidenceLevel > 90) {
            portfolioVaR = portfolioVaR * 120 / 100; // 1.2x for 95% confidence
        }
    }

    /**
     * @dev Perform stress testing
     * @param scenario Stress test scenario ID
     * @param assets Array of assets to test
     * @param amounts Array of amounts to test
     * @return stressTestResult Stress test results
     */
    function performStressTest(
        uint256 scenario,
        address[] memory assets,
        uint256[] memory amounts
    ) external view override returns (StressTestResult memory stressTestResult) {
        // Define stress scenarios
        uint256 marketShock;
        uint256 liquidityShock;
        uint256 correlationShock;
        
        if (scenario == 1) { // Mild stress
            marketShock = 1500; // 15% market drop
            liquidityShock = 2000; // 20% liquidity reduction
            correlationShock = 1200; // 20% correlation increase
        } else if (scenario == 2) { // Moderate stress
            marketShock = 3000; // 30% market drop
            liquidityShock = 4000; // 40% liquidity reduction
            correlationShock = 1500; // 50% correlation increase
        } else { // Severe stress
            marketShock = 5000; // 50% market drop
            liquidityShock = 6000; // 60% liquidity reduction
            correlationShock = 2000; // 100% correlation increase
        }
        
        uint256 totalLoss = 0;
        uint256 maxAssetLoss = 0;
        
        for (uint256 i = 0; i < assets.length; i++) {
            AssetRiskData memory assetData = assetRiskData[assets[i]];
            
            // Calculate stressed asset loss
            uint256 assetLoss = amounts[i] * marketShock / BASIS_POINTS;
            
            // Apply liquidity impact
            if (assetData.liquidity < liquidityShock) {
                assetLoss += amounts[i] * (liquidityShock - assetData.liquidity) / BASIS_POINTS;
            }
            
            // Apply correlation impact
            assetLoss += amounts[i] * assetData.correlation * correlationShock / (BASIS_POINTS * BASIS_POINTS);
            
            totalLoss += assetLoss;
            if (assetLoss > maxAssetLoss) {
                maxAssetLoss = assetLoss;
            }
        }
        
        stressTestResult = StressTestResult({
            scenario: scenario,
            totalLoss: totalLoss,
            maxAssetLoss: maxAssetLoss,
            liquidationRisk: totalLoss > _getTotalValue(amounts) * 8000 / BASIS_POINTS, // 80% threshold
            recoveryTime: _estimateRecoveryTime(totalLoss, _getTotalValue(amounts))
        });
    }

    /**
     * @dev Update asset risk data
     * @param asset Asset address
     * @param volatility Asset volatility
     * @param liquidity Asset liquidity score
     * @param correlation Market correlation
     */
    function updateAssetRiskData(
        address asset,
        uint256 volatility,
        uint256 liquidity,
        uint256 correlation
    ) external onlyRiskManager {
        require(asset != address(0), "Invalid asset");
        require(volatility <= BASIS_POINTS, "Invalid volatility");
        require(liquidity <= BASIS_POINTS, "Invalid liquidity");
        require(correlation <= BASIS_POINTS, "Invalid correlation");
        
        assetRiskData[asset] = AssetRiskData({
            volatility: volatility,
            liquidity: liquidity,
            correlation: correlation,
            lastUpdate: block.timestamp,
            isActive: true
        });
        
        emit AssetRiskDataUpdated(asset, assetRiskData[asset]);
    }

    /**
     * @dev Update market conditions
     * @param volatilityIndex New volatility index
     * @param liquidityIndex New liquidity index
     * @param stressLevel New stress level
     */
    function updateMarketConditions(
        uint256 volatilityIndex,
        uint256 liquidityIndex,
        uint256 stressLevel
    ) external onlyRiskManager {
        require(volatilityIndex <= BASIS_POINTS, "Invalid volatility index");
        require(liquidityIndex <= BASIS_POINTS, "Invalid liquidity index");
        require(stressLevel <= 100, "Invalid stress level");
        
        marketConditions = MarketConditions({
            volatilityIndex: volatilityIndex,
            liquidityIndex: liquidityIndex,
            stressLevel: stressLevel,
            correlationBreakdown: marketConditions.correlationBreakdown,
            lastUpdate: block.timestamp
        });
        
        emit MarketConditionsUpdated(marketConditions);
    }

    /**
     * @dev Set user risk profile
     * @param user User address
     * @param profile Risk profile
     */
    function setRiskProfile(address user, RiskProfile memory profile) external override {
        require(msg.sender == user || msg.sender == owner(), "Not authorized");
        userRiskProfiles[user] = profile;
        emit RiskProfileUpdated(user, profile);
    }

    /**
     * @dev Set user risk limits
     * @param user User address
     * @param limits Risk limits
     */
    function setRiskLimits(address user, RiskLimits memory limits) external override {
        require(msg.sender == user || msg.sender == owner(), "Not authorized");
        require(limits.maxPortfolioRisk <= BASIS_POINTS, "Invalid portfolio risk limit");
        require(limits.maxAssetRisk <= BASIS_POINTS, "Invalid asset risk limit");
        
        userRiskLimits[user] = limits;
        emit RiskLimitsUpdated(user, limits);
    }

    /**
     * @dev Set authorized risk manager
     * @param manager Manager address
     * @param authorized Authorization status
     */
    function setAuthorizedRiskManager(address manager, bool authorized) external onlyOwner {
        authorizedRiskManagers[manager] = authorized;
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
     * @dev Update risk thresholds
     * @param portfolio Max portfolio risk
     * @param concentration Max concentration risk
     * @param volatility Max volatility threshold
     * @param liquidity Min liquidity threshold
     */
    function updateRiskThresholds(
        uint256 portfolio,
        uint256 concentration,
        uint256 volatility,
        uint256 liquidity
    ) external onlyOwner {
        maxPortfolioRisk = portfolio;
        maxConcentrationRisk = concentration;
        maxVolatilityThreshold = volatility;
        minLiquidityThreshold = liquidity;
        
        emit RiskThresholdsUpdated(portfolio, concentration, volatility, liquidity);
    }

    /**
     * @dev Resolve a risk alert
     * @param alertId Alert ID to resolve
     */
    function resolveRiskAlert(uint256 alertId) external onlyRiskManager {
        require(alertId < nextAlertId, "Invalid alert ID");
        require(!riskAlerts[alertId].isResolved, "Alert already resolved");
        
        riskAlerts[alertId].isResolved = true;
        emit RiskAlertResolved(alertId);
    }

    /**
     * @dev Get user risk alerts
     * @param user User address
     * @return alertIds Array of alert IDs
     */
    function getUserRiskAlerts(address user) external view returns (uint256[] memory alertIds) {
        return userAlerts[user];
    }

    /**
     * @dev Get risk metrics
     * @return metrics Current risk metrics
     */
    function getRiskMetrics() external view override returns (RiskMetrics memory metrics) {
        return globalRiskMetrics;
    }

    /**
     * @dev Internal function to calculate size risk
     * @param asset Asset address
     * @param amount Amount to assess
     * @return sizeRisk Size-based risk score
     */
    function _calculateSizeRisk(address asset, uint256 amount) internal view returns (uint256 sizeRisk) {
        // Simplified calculation - larger positions have higher risk
        // In practice, this would consider market depth, daily volume, etc.
        uint256 baseAmount = 1000 * 1e18; // Base amount for comparison
        if (amount <= baseAmount) return 0;
        
        uint256 sizeMultiplier = amount / baseAmount;
        sizeRisk = sizeMultiplier > 10 ? 1000 : sizeMultiplier * 100; // Max 10% size risk
    }

    /**
     * @dev Calculate concentration risk
     * @param assets Array of assets
     * @param amounts Array of amounts
     * @return concentrationRisk Concentration risk penalty
     */
    function _calculateConcentrationRisk(
        address[] memory assets,
        uint256[] memory amounts
    ) internal pure returns (uint256 concentrationRisk) {
        if (assets.length <= 1) return 1000; // 10% penalty for single asset
        
        uint256 totalValue = 0;
        uint256 maxAssetValue = 0;
        
        for (uint256 i = 0; i < amounts.length; i++) {
            totalValue += amounts[i];
            if (amounts[i] > maxAssetValue) {
                maxAssetValue = amounts[i];
            }
        }
        
        if (totalValue == 0) return 0;
        
        uint256 concentration = maxAssetValue * BASIS_POINTS / totalValue;
        
        // Apply penalty for high concentration
        if (concentration > 5000) { // >50%
            concentrationRisk = (concentration - 5000) / 2; // Up to 25% penalty
        }
    }

    /**
     * @dev Calculate correlation risk
     * @param assets Array of assets
     * @param amounts Array of amounts
     * @return correlationRisk Correlation-based risk adjustment
     */
    function _calculateCorrelationRisk(
        address[] memory assets,
        uint256[] memory amounts
    ) internal view returns (uint256 correlationRisk) {
        if (assets.length <= 1) return 0;
        
        uint256 avgCorrelation = 0;
        uint256 totalWeight = 0;
        
        for (uint256 i = 0; i < assets.length; i++) {
            AssetRiskData memory assetData = assetRiskData[assets[i]];
            avgCorrelation += assetData.correlation * amounts[i];
            totalWeight += amounts[i];
        }
        
        if (totalWeight == 0) return 0;
        
        avgCorrelation = avgCorrelation / totalWeight;
        
        // Higher correlation = higher risk during stress
        correlationRisk = avgCorrelation * marketConditions.stressLevel / 100;
    }

    /**
     * @dev Create a risk alert
     * @param asset Asset address
     * @param riskLevel Risk level (1-5)
     * @param alertType Alert type string
     * @param description Alert description
     */
    function _createRiskAlert(
        address asset,
        uint256 riskLevel,
        string memory alertType,
        string memory description
    ) internal {
        uint256 alertId = nextAlertId++;
        
        riskAlerts[alertId] = RiskAlertData({
            alertId: alertId,
            asset: asset,
            riskLevel: riskLevel,
            alertType: alertType,
            description: description,
            timestamp: block.timestamp,
            isResolved: false
        });
        
        emit RiskAlertCreated(alertId, asset, riskLevel);
    }

    /**
     * @dev Update global risk metrics
     * @param portfolioRisk Current portfolio risk
     */
    function _updateGlobalRiskMetrics(uint256 portfolioRisk) internal {
        globalRiskMetrics.totalRisk = portfolioRisk;
        globalRiskMetrics.lastUpdate = block.timestamp;
        // Additional metrics would be calculated here
    }

    /**
     * @dev Get total value of amounts array
     * @param amounts Array of amounts
     * @return totalValue Total value
     */
    function _getTotalValue(uint256[] memory amounts) internal pure returns (uint256 totalValue) {
        for (uint256 i = 0; i < amounts.length; i++) {
            totalValue += amounts[i];
        }
    }

    /**
     * @dev Estimate recovery time after stress event
     * @param totalLoss Total loss amount
     * @param totalValue Total portfolio value
     * @return recoveryTime Estimated recovery time in days
     */
    function _estimateRecoveryTime(uint256 totalLoss, uint256 totalValue) internal pure returns (uint256 recoveryTime) {
        if (totalValue == 0) return 0;
        
        uint256 lossPercentage = totalLoss * 100 / totalValue;
        
        if (lossPercentage < 10) {
            recoveryTime = 30; // 1 month
        } else if (lossPercentage < 25) {
            recoveryTime = 90; // 3 months
        } else if (lossPercentage < 50) {
            recoveryTime = 180; // 6 months
        } else {
            recoveryTime = 365; // 1 year
        }
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