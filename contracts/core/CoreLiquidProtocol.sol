// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";


// Import all major components
import "../utils/DepositManager.sol";
import "../rebalancing/AutoRebalanceManager.sol";
import "../rebalancing/RebalanceFlow.sol";
import "../lending/BorrowEngine.sol";
import "../lending/CollateralManager.sol";
import "../lending/InterestRateModel.sol";
import "../lending/LiquidationEngine.sol";
import "../vault/VaultManager.sol";
import "../vault/VaultStrategyBase.sol";
import "../vault/YieldAggregator.sol";
import "../vault/YieldOptimizer.sol";
import "../vault/YieldStrategy.sol";
// import "../utils/APRCalculator.sol"; // APRCalculator functionality integrated into core contracts
import "../utils/APROptimizer.sol";

// Import Core Chain native integrations
import "./CoreNativeStaking.sol";
import "../staking/StCOREToken.sol";

/**
 * @title CoreLiquidProtocol
 * @dev Main protocol contract that orchestrates all CoreLiquid components
 * @notice This contract serves as the central hub for the CoreLiquid DeFi protocol
 */
contract CoreLiquidProtocol is AccessControl, ReentrancyGuard, Pausable, Initializable {
    using Math for uint256;
    
    
    // Role definitions
    bytes32 public constant PROTOCOL_ADMIN_ROLE = keccak256("PROTOCOL_ADMIN_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant KEEPER_ROLE = keccak256("KEEPER_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    
    // Protocol components
    DepositManager public depositManager;
    AutoRebalanceManager public autoRebalanceManager;
    RebalanceFlow public rebalanceFlow;
    BorrowEngine public borrowEngine;
    CollateralManager public collateralManager;
    InterestRateModel public interestRateModel;
    LiquidationEngine public liquidationEngine;
    VaultManager public vaultManager;
    YieldAggregator public yieldAggregator;
    YieldOptimizer public yieldOptimizer;
    YieldStrategy public yieldStrategy;
    // APRCalculator public aprCalculator; // Functionality integrated into core contracts
    APROptimizer public aprOptimizer;
    
    // Core Chain native components
    CoreNativeStaking public coreNativeStaking;
    StCOREToken public stCoreToken;
    CoreValidatorIntegration public coreValidatorIntegration;
    
    // Protocol state
    struct ProtocolMetrics {
        uint256 totalValueLocked;
        uint256 totalBorrowed;
        uint256 totalCollateral;
        uint256 totalYieldGenerated;
        uint256 totalFeesCollected;
        uint256 activeUsers;
        uint256 activePositions;
        uint256 protocolRevenue;
        uint256 lastUpdate;
        // Core Chain specific metrics
        uint256 totalBTCStaked;
        uint256 totalCoreStaked;
        uint256 totalStCoreSupply;
        uint256 totalHashPowerDelegated;
        uint256 totalValidators;
        uint256 btcStakingRewards;
        uint256 coreStakingRewards;
        uint256 dualStakingBonuses;
    }
    
    struct ProtocolConfig {
        uint256 protocolFee; // in basis points
        uint256 treasuryFee; // in basis points
        uint256 maxLeverage; // maximum leverage allowed
        uint256 liquidationThreshold; // liquidation threshold
        uint256 minCollateralRatio; // minimum collateral ratio
        bool emergencyMode;
        bool depositsEnabled;
        bool withdrawalsEnabled;
        bool borrowingEnabled;
        bool liquidationsEnabled;
    }
    
    struct UserProfile {
        uint256 totalDeposited;
        uint256 totalBorrowed;
        uint256 totalCollateral;
        uint256 totalYieldEarned;
        uint256 totalFeePaid;
        uint256 riskScore;
        uint256 lastActivity;
        bool isActive;
        uint256[] activePositions;
        uint256[] activeStrategies;
    }
    
    struct GlobalLimits {
        uint256 maxTotalSupply;
        uint256 maxUserDeposit;
        uint256 maxUserBorrow;
        uint256 maxProtocolUtilization;
        uint256 maxStrategyAllocation;
        uint256 dailyWithdrawLimit;
        uint256 dailyBorrowLimit;
    }
    
    ProtocolMetrics public protocolMetrics;
    ProtocolConfig public protocolConfig;
    GlobalLimits public globalLimits;
    
    mapping(address => UserProfile) public userProfiles;
    mapping(address => bool) public authorizedContracts;
    mapping(address => uint256) public userRiskScores;
    mapping(uint256 => address) public positionOwners;
    mapping(address => mapping(uint256 => bool)) public userPositions;
    
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant MAX_PROTOCOL_FEE = 1000; // 10%
    uint256 public constant MAX_TREASURY_FEE = 500; // 5%
    uint256 public constant VERSION = 1;
    
    address public treasury;
    address public governance;
    address public emergencyCouncil;
    
    // Events
    event ProtocolInitialized(
        address indexed admin,
        uint256 version,
        uint256 timestamp
    );
    
    event ComponentUpdated(
        string indexed componentName,
        address indexed oldAddress,
        address indexed newAddress
    );
    
    event ProtocolConfigUpdated(
        uint256 protocolFee,
        uint256 treasuryFee,
        uint256 maxLeverage
    );
    
    event UserProfileUpdated(
        address indexed user,
        uint256 totalDeposited,
        uint256 totalBorrowed,
        uint256 riskScore
    );
    
    event EmergencyModeActivated(
        address indexed activator,
        string reason,
        uint256 timestamp
    );
    
    event EmergencyModeDeactivated(
        address indexed deactivator,
        uint256 timestamp
    );
    
    event ProtocolMetricsUpdated(
        uint256 totalValueLocked,
        uint256 totalBorrowed,
        uint256 totalYieldGenerated,
        uint256 timestamp
    );
    
    modifier onlyAuthorizedContract() {
        require(authorizedContracts[msg.sender], "Unauthorized contract");
        _;
    }
    
    modifier notInEmergencyMode() {
        require(!protocolConfig.emergencyMode, "Protocol in emergency mode");
        _;
    }
    
    modifier onlyGovernance() {
        require(msg.sender == governance, "Only governance");
        _;
    }
    
    constructor() {
        // Grant roles to deployer
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PROTOCOL_ADMIN_ROLE, msg.sender);
        _grantRole(OPERATOR_ROLE, msg.sender);
        _grantRole(KEEPER_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE, msg.sender);
        
        _disableInitializers();
    }
    
    function initialize(
        address _treasury,
        address _governance,
        address _emergencyCouncil
    ) external initializer {
        require(_treasury != address(0), "Invalid treasury");
        require(_governance != address(0), "Invalid governance");
        require(_emergencyCouncil != address(0), "Invalid emergency council");
        
        treasury = _treasury;
        governance = _governance;
        emergencyCouncil = _emergencyCouncil;
        
        // Setup roles
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PROTOCOL_ADMIN_ROLE, msg.sender);
        _grantRole(OPERATOR_ROLE, msg.sender);
        _grantRole(KEEPER_ROLE, msg.sender);
        _grantRole(EMERGENCY_ROLE, _emergencyCouncil);
        _grantRole(UPGRADER_ROLE, _governance);
        
        // Initialize default config
        protocolConfig = ProtocolConfig({
            protocolFee: 100, // 1%
            treasuryFee: 50, // 0.5%
            maxLeverage: 500, // 5x
            liquidationThreshold: 8000, // 80%
            minCollateralRatio: 12000, // 120%
            emergencyMode: false,
            depositsEnabled: true,
            withdrawalsEnabled: true,
            borrowingEnabled: true,
            liquidationsEnabled: true
        });
        
        // Initialize global limits
        globalLimits = GlobalLimits({
            maxTotalSupply: 1000000 ether, // 1M tokens
            maxUserDeposit: 10000 ether, // 10K tokens per user
            maxUserBorrow: 5000 ether, // 5K tokens per user
            maxProtocolUtilization: 9000, // 90%
            maxStrategyAllocation: 2000, // 20% per strategy
            dailyWithdrawLimit: 100000 ether, // 100K tokens per day
            dailyBorrowLimit: 50000 ether // 50K tokens per day
        });
        
        emit ProtocolInitialized(msg.sender, VERSION, block.timestamp);
    }
    
    function initializeComponents(
        address _depositManager,
        address _autoRebalanceManager,
        address _rebalanceFlow,
        address _borrowEngine,
        address _collateralManager,
        address _interestRateModel,
        address _liquidationEngine,
        address _vaultManager,
        address _yieldAggregator,
        address _yieldOptimizer,
        address _yieldStrategy,
        // address _aprCalculator, // APRCalculator functionality integrated
        address _aprOptimizer
    ) external onlyRole(PROTOCOL_ADMIN_ROLE) {
        require(_depositManager != address(0), "Invalid deposit manager");
        require(_autoRebalanceManager != address(0), "Invalid auto rebalance manager");
        require(_rebalanceFlow != address(0), "Invalid rebalance flow");
        require(_borrowEngine != address(0), "Invalid borrow engine");
        require(_collateralManager != address(0), "Invalid collateral manager");
        require(_interestRateModel != address(0), "Invalid interest rate model");
        require(_liquidationEngine != address(0), "Invalid liquidation engine");
        require(_vaultManager != address(0), "Invalid vault manager");
        require(_yieldAggregator != address(0), "Invalid yield aggregator");
        require(_yieldOptimizer != address(0), "Invalid yield optimizer");
        require(_yieldStrategy != address(0), "Invalid yield strategy");
        // require(_aprCalculator != address(0), "Invalid APR calculator"); // Functionality integrated
        require(_aprOptimizer != address(0), "Invalid APR optimizer");
        
        depositManager = DepositManager(_depositManager);
        autoRebalanceManager = AutoRebalanceManager(_autoRebalanceManager);
        rebalanceFlow = RebalanceFlow(_rebalanceFlow);
        borrowEngine = BorrowEngine(_borrowEngine);
        collateralManager = CollateralManager(_collateralManager);
        interestRateModel = InterestRateModel(_interestRateModel);
        liquidationEngine = LiquidationEngine(_liquidationEngine);
        vaultManager = VaultManager(_vaultManager);
        yieldAggregator = YieldAggregator(_yieldAggregator);
        yieldOptimizer = YieldOptimizer(_yieldOptimizer);
        yieldStrategy = YieldStrategy(_yieldStrategy);
        // aprCalculator = APRCalculator(_aprCalculator); // Functionality integrated
        aprOptimizer = APROptimizer(_aprOptimizer);
        
        // Authorize all components
        authorizedContracts[_depositManager] = true;
        authorizedContracts[_autoRebalanceManager] = true;
        authorizedContracts[_rebalanceFlow] = true;
        authorizedContracts[_borrowEngine] = true;
        authorizedContracts[_collateralManager] = true;
        authorizedContracts[_interestRateModel] = true;
        authorizedContracts[_liquidationEngine] = true;
        authorizedContracts[_vaultManager] = true;
        authorizedContracts[_yieldAggregator] = true;
        authorizedContracts[_yieldOptimizer] = true;
        authorizedContracts[_yieldStrategy] = true;
        // authorizedContracts[_aprCalculator] = true; // APRCalculator functionality integrated
        authorizedContracts[_aprOptimizer] = true;
    }
    
    function deposit(
        address token,
        uint256 amount,
        uint256 minLPTokens
    ) external nonReentrant whenNotPaused notInEmergencyMode {
        require(protocolConfig.depositsEnabled, "Deposits disabled");
        require(amount > 0, "Invalid amount");
        
        UserProfile storage profile = userProfiles[msg.sender];
        
        // Check user limits
        require(
            profile.totalDeposited + amount <= globalLimits.maxUserDeposit,
            "Exceeds user deposit limit"
        );
        
        // Check protocol limits
        require(
            protocolMetrics.totalValueLocked + amount <= globalLimits.maxTotalSupply,
            "Exceeds protocol limit"
        );
        
        // Execute deposit through DepositManager (simplified interface)
        bytes32 depositId = depositManager.deposit(token, amount);
        // For now, assume LP tokens equal deposited amount (placeholder logic)
        uint256 lpTokens = amount;
        // Silence unused variable warning for minLPTokens until full LP logic implemented
        minLPTokens;
        
        // Update user profile
        profile.totalDeposited += amount;
        profile.lastActivity = block.timestamp;
        profile.isActive = true;
        
        // Update protocol metrics
        protocolMetrics.totalValueLocked += amount;
        if (!profile.isActive) {
            protocolMetrics.activeUsers++;
        }
        
        _updateUserRiskScore(msg.sender);
        _updateProtocolMetrics();
    }
    
    function withdraw(
        uint256 lpTokens,
        address token,
        uint256 minAmount
    ) external nonReentrant whenNotPaused {
        require(protocolConfig.withdrawalsEnabled, "Withdrawals disabled");
        require(lpTokens > 0, "Invalid LP tokens");
        
        UserProfile storage profile = userProfiles[msg.sender];
        require(profile.isActive, "User not active");
        
        // For now, we'll use a simplified withdrawal approach
        // In production, this should integrate with the actual withdrawal mechanism
        uint256 amount = lpTokens; // Simplified - calculate actual withdrawal amount
        
        // Update user profile
        profile.totalDeposited = profile.totalDeposited > amount ? profile.totalDeposited - amount : 0;
        profile.lastActivity = block.timestamp;
        
        // Update protocol metrics
        protocolMetrics.totalValueLocked = protocolMetrics.totalValueLocked > amount ? protocolMetrics.totalValueLocked - amount : 0;
        
        _updateUserRiskScore(msg.sender);
        _updateProtocolMetrics();
    }
    
    function borrow(
        address asset,
        uint256 amount,
        address collateralAsset,
        uint256 collateralAmount
    ) external nonReentrant whenNotPaused notInEmergencyMode {
        require(protocolConfig.borrowingEnabled, "Borrowing disabled");
        require(amount > 0, "Invalid amount");
        
        UserProfile storage profile = userProfiles[msg.sender];
        
        // Check user limits
        require(
            profile.totalBorrowed + amount <= globalLimits.maxUserBorrow,
            "Exceeds user borrow limit"
        );
        
        // Execute borrow through BorrowEngine
        uint256 positionId = borrowEngine.createBorrowPosition(
            asset,
            collateralAsset,
            amount,
            collateralAmount
        );
        
        // Update user profile
        profile.totalBorrowed += amount;
        profile.totalCollateral += collateralAmount;
        profile.activePositions.push(positionId);
        profile.lastActivity = block.timestamp;
        profile.isActive = true;
        
        // Update protocol metrics
        protocolMetrics.totalBorrowed += amount;
        protocolMetrics.totalCollateral += collateralAmount;
        protocolMetrics.activePositions++;
        
        positionOwners[positionId] = msg.sender;
        userPositions[msg.sender][positionId] = true;
        
        _updateUserRiskScore(msg.sender);
        _updateProtocolMetrics();
    }
    
    function repay(
        uint256 positionId,
        uint256 amount
    ) external nonReentrant whenNotPaused {
        require(userPositions[msg.sender][positionId], "Not position owner");
        require(amount > 0, "Invalid amount");
        
        UserProfile storage profile = userProfiles[msg.sender];
        
        // Execute repayment through BorrowEngine
        borrowEngine.repayBorrow(positionId, amount);
        uint256 repaidAmount = amount; // Simplified - in production get actual repaid amount
        
        // Update user profile
        profile.totalBorrowed = profile.totalBorrowed > repaidAmount ? profile.totalBorrowed - repaidAmount : 0;
        profile.lastActivity = block.timestamp;
        
        // Update protocol metrics
        protocolMetrics.totalBorrowed = protocolMetrics.totalBorrowed > repaidAmount ? protocolMetrics.totalBorrowed - repaidAmount : 0;
        
        _updateUserRiskScore(msg.sender);
        _updateProtocolMetrics();
    }
    
    function liquidate(
        uint256 positionId,
        uint256 amount
    ) external nonReentrant whenNotPaused {
        require(protocolConfig.liquidationsEnabled, "Liquidations disabled");
        require(amount > 0, "Invalid amount");
        
        address positionOwner = positionOwners[positionId];
        require(positionOwner != address(0), "Position not found");
        
        // Execute liquidation through LiquidationEngine
        borrowEngine.liquidatePosition(positionId);
        
        UserProfile storage profile = userProfiles[positionOwner];
        profile.lastActivity = block.timestamp;
        
        _updateUserRiskScore(positionOwner);
        _updateProtocolMetrics();
    }
    
    function optimizeYield(
        address user,
        uint256 amount
    ) external onlyRole(KEEPER_ROLE) nonReentrant {
        require(user != address(0), "Invalid user");
        require(amount > 0, "Invalid amount");
        
        // Execute yield optimization
        YieldOptimizer.OptimizationResult memory result = yieldOptimizer.optimizeYield(user, amount);
        
        UserProfile storage profile = userProfiles[user];
        profile.lastActivity = block.timestamp;
        
        _updateProtocolMetrics();
    }
    
    function rebalancePosition(
        uint256 positionId
    ) external onlyRole(KEEPER_ROLE) nonReentrant {
        require(positionOwners[positionId] != address(0), "Position not found");
        
        // Execute rebalancing through RebalanceFlow
        rebalanceFlow.initiateRebalanceFlow(positionId);
        
        address positionOwner = positionOwners[positionId];
        UserProfile storage profile = userProfiles[positionOwner];
        profile.lastActivity = block.timestamp;
        
        _updateProtocolMetrics();
    }
    
    function harvestYield(
        uint256 strategyId
    ) external onlyRole(KEEPER_ROLE) nonReentrant {
        // Execute harvest through YieldStrategy
        yieldStrategy.harvest(strategyId);
        
        _updateProtocolMetrics();
    }
    
    function _updateUserRiskScore(address user) internal {
        UserProfile storage profile = userProfiles[user];
        
        uint256 riskScore = 5000; // Base risk score (50%)
        
        // Adjust based on leverage
        if (profile.totalBorrowed > 0 && profile.totalCollateral > 0) {
            uint256 leverage = (profile.totalBorrowed * BASIS_POINTS) / profile.totalCollateral;
            if (leverage > 8000) { // > 80% LTV
                riskScore += 2000; // Increase risk
            } else if (leverage < 5000) { // < 50% LTV
                riskScore -= 1000; // Decrease risk
            }
        }
        
        // Adjust based on activity
        uint256 timeSinceActivity = block.timestamp - profile.lastActivity;
        if (timeSinceActivity > 30 days) {
            riskScore += 500; // Increase risk for inactive users
        }
        
        // Ensure risk score is within bounds
        riskScore = Math.min(riskScore, BASIS_POINTS);
        
        profile.riskScore = riskScore;
        userRiskScores[user] = riskScore;
        
        emit UserProfileUpdated(
            user,
            profile.totalDeposited,
            profile.totalBorrowed,
            riskScore
        );
    }
    
    function _updateProtocolMetrics() internal {
        protocolMetrics.lastUpdate = block.timestamp;
        
        emit ProtocolMetricsUpdated(
            protocolMetrics.totalValueLocked,
            protocolMetrics.totalBorrowed,
            protocolMetrics.totalYieldGenerated,
            block.timestamp
        );
    }
    
    // View functions
    function getProtocolMetrics() external view returns (ProtocolMetrics memory) {
        return protocolMetrics;
    }
    
    function getUserProfile(address user) external view returns (UserProfile memory) {
        return userProfiles[user];
    }
    
    function getProtocolConfig() external view returns (ProtocolConfig memory) {
        return protocolConfig;
    }
    
    function getGlobalLimits() external view returns (GlobalLimits memory) {
        return globalLimits;
    }
    
    function isAuthorizedContract(address contractAddress) external view returns (bool) {
        return authorizedContracts[contractAddress];
    }
    
    function getUserRiskScore(address user) external view returns (uint256) {
        return userRiskScores[user];
    }
    
    function getPositionOwner(uint256 positionId) external view returns (address) {
        return positionOwners[positionId];
    }
    
    function getUserPositions(address user) external view returns (uint256[] memory) {
        return userProfiles[user].activePositions;
    }
    
    function getUserStrategies(address user) external view returns (uint256[] memory) {
        return userProfiles[user].activeStrategies;
    }
    
    // Admin functions
    function updateProtocolConfig(
        ProtocolConfig memory newConfig
    ) external onlyRole(PROTOCOL_ADMIN_ROLE) {
        require(newConfig.protocolFee <= MAX_PROTOCOL_FEE, "Protocol fee too high");
        require(newConfig.treasuryFee <= MAX_TREASURY_FEE, "Treasury fee too high");
        require(newConfig.maxLeverage >= 100, "Max leverage too low"); // At least 1x
        require(newConfig.liquidationThreshold <= BASIS_POINTS, "Invalid liquidation threshold");
        require(newConfig.minCollateralRatio >= BASIS_POINTS, "Invalid collateral ratio");
        
        protocolConfig = newConfig;
        
        emit ProtocolConfigUpdated(
            newConfig.protocolFee,
            newConfig.treasuryFee,
            newConfig.maxLeverage
        );
    }
    
    function updateGlobalLimits(
        GlobalLimits memory newLimits
    ) external onlyRole(PROTOCOL_ADMIN_ROLE) {
        require(newLimits.maxTotalSupply > 0, "Invalid max total supply");
        require(newLimits.maxUserDeposit > 0, "Invalid max user deposit");
        require(newLimits.maxUserBorrow > 0, "Invalid max user borrow");
        require(newLimits.maxProtocolUtilization <= BASIS_POINTS, "Invalid max utilization");
        
        globalLimits = newLimits;
    }
    
    function updateComponent(
        string memory componentName,
        address newAddress
    ) external onlyRole(UPGRADER_ROLE) {
        require(newAddress != address(0), "Invalid address");
        
        address oldAddress;
        
        if (keccak256(bytes(componentName)) == keccak256(bytes("depositManager"))) {
            oldAddress = address(depositManager);
            depositManager = DepositManager(newAddress);
        } else if (keccak256(bytes(componentName)) == keccak256(bytes("borrowEngine"))) {
            oldAddress = address(borrowEngine);
            borrowEngine = BorrowEngine(newAddress);
        } else if (keccak256(bytes(componentName)) == keccak256(bytes("yieldAggregator"))) {
            oldAddress = address(yieldAggregator);
            yieldAggregator = YieldAggregator(newAddress);
        }
        // Add more components as needed
        
        // Update authorization
        if (oldAddress != address(0)) {
            authorizedContracts[oldAddress] = false;
        }
        authorizedContracts[newAddress] = true;
        
        emit ComponentUpdated(componentName, oldAddress, newAddress);
    }
    
    function setAuthorizedContract(
        address contractAddress,
        bool authorized
    ) external onlyRole(PROTOCOL_ADMIN_ROLE) {
        authorizedContracts[contractAddress] = authorized;
    }
    
    function activateEmergencyMode(
        string memory reason
    ) external onlyRole(EMERGENCY_ROLE) {
        protocolConfig.emergencyMode = true;
        protocolConfig.depositsEnabled = false;
        protocolConfig.borrowingEnabled = false;
        
        emit EmergencyModeActivated(msg.sender, reason, block.timestamp);
    }
    
    function deactivateEmergencyMode() external onlyRole(EMERGENCY_ROLE) {
        protocolConfig.emergencyMode = false;
        protocolConfig.depositsEnabled = true;
        protocolConfig.withdrawalsEnabled = true;
        protocolConfig.borrowingEnabled = true;
        protocolConfig.liquidationsEnabled = true;
        
        emit EmergencyModeDeactivated(msg.sender, block.timestamp);
    }
    
    function updateTreasury(address newTreasury) external onlyGovernance {
        require(newTreasury != address(0), "Invalid treasury");
        treasury = newTreasury;
    }
    
    function updateGovernance(address newGovernance) external onlyGovernance {
        require(newGovernance != address(0), "Invalid governance");
        governance = newGovernance;
    }
    
    function updateEmergencyCouncil(address newEmergencyCouncil) external onlyGovernance {
        require(newEmergencyCouncil != address(0), "Invalid emergency council");
        
        _revokeRole(EMERGENCY_ROLE, emergencyCouncil);
        emergencyCouncil = newEmergencyCouncil;
        _grantRole(EMERGENCY_ROLE, newEmergencyCouncil);
    }
    
    function pause() external onlyRole(EMERGENCY_ROLE) {
        _pause();
    }
    
    function unpause() external onlyRole(EMERGENCY_ROLE) {
        _unpause();
    }
    
    // Emergency functions
    function emergencyWithdraw(
        address token,
        uint256 amount,
        address to
    ) external onlyRole(EMERGENCY_ROLE) {
        require(protocolConfig.emergencyMode, "Not in emergency mode");
        require(to != address(0), "Invalid recipient");
        
        IERC20(token).transfer(to, amount);
    }
    
    function emergencyPause() external onlyRole(EMERGENCY_ROLE) {
        _pause();
        protocolConfig.emergencyMode = true;
        protocolConfig.depositsEnabled = false;
        protocolConfig.borrowingEnabled = false;
        
        emit EmergencyModeActivated(msg.sender, "Emergency pause activated", block.timestamp);
    }
    
    // Callback functions for authorized contracts
    function updateUserProfile(
        address user,
        uint256 depositDelta,
        uint256 borrowDelta,
        uint256 collateralDelta,
        bool isIncrease
    ) external onlyAuthorizedContract {
        UserProfile storage profile = userProfiles[user];
        
        if (isIncrease) {
            profile.totalDeposited += depositDelta;
            profile.totalBorrowed += borrowDelta;
            profile.totalCollateral += collateralDelta;
        } else {
            profile.totalDeposited = profile.totalDeposited > depositDelta ? profile.totalDeposited - depositDelta : 0;
            profile.totalBorrowed = profile.totalBorrowed > borrowDelta ? profile.totalBorrowed - borrowDelta : 0;
            profile.totalCollateral = profile.totalCollateral > collateralDelta ? profile.totalCollateral - collateralDelta : 0;
        }
        
        profile.lastActivity = block.timestamp;
        _updateUserRiskScore(user);
    }
    
    function updateProtocolMetrics(
        uint256 tvlDelta,
        uint256 borrowDelta,
        uint256 yieldDelta,
        uint256 feeDelta,
        bool isIncrease
    ) external onlyAuthorizedContract {
        if (isIncrease) {
            protocolMetrics.totalValueLocked += tvlDelta;
            protocolMetrics.totalBorrowed += borrowDelta;
            protocolMetrics.totalYieldGenerated += yieldDelta;
            protocolMetrics.totalFeesCollected += feeDelta;
        } else {
            protocolMetrics.totalValueLocked = protocolMetrics.totalValueLocked > tvlDelta ? protocolMetrics.totalValueLocked - tvlDelta : 0;
            protocolMetrics.totalBorrowed = protocolMetrics.totalBorrowed > borrowDelta ? protocolMetrics.totalBorrowed - borrowDelta : 0;
            protocolMetrics.totalYieldGenerated = protocolMetrics.totalYieldGenerated > yieldDelta ? protocolMetrics.totalYieldGenerated - yieldDelta : 0;
            protocolMetrics.totalFeesCollected = protocolMetrics.totalFeesCollected > feeDelta ? protocolMetrics.totalFeesCollected - feeDelta : 0;
        }
        
        _updateProtocolMetrics();
    }
}
