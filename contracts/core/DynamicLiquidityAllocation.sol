// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title DynamicLiquidityAllocation
 * @dev Advanced dynamic liquidity allocation engine for unified liquidity management
 */
contract DynamicLiquidityAllocation is AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using Math for uint256;
    
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant ALLOCATOR_ROLE = keccak256("ALLOCATOR_ROLE");
    bytes32 public constant KEEPER_ROLE = keccak256("KEEPER_ROLE");
    bytes32 public constant PROTOCOL_ROLE = keccak256("PROTOCOL_ROLE");
    
    uint256 public constant PRECISION = 1e18;
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant MAX_PROTOCOLS = 20;
    uint256 public constant MIN_ALLOCATION_THRESHOLD = 1000 * 1e18;
    
    enum ProtocolType {
        LENDING,
        DEX,
        VAULT,
        STAKING,
        FARMING,
        ARBITRAGE,
        INSURANCE,
        DERIVATIVES
    }
    
    enum AllocationStrategy {
        CONSERVATIVE,
        BALANCED,
        AGGRESSIVE,
        YIELD_OPTIMIZED,
        RISK_MINIMIZED,
        DYNAMIC,
        CUSTOM
    }
    
    enum AllocationStatus {
        ACTIVE,
        PAUSED,
        EMERGENCY_WITHDRAW,
        DEPRECATED
    }
    
    struct Protocol {
        uint256 protocolId;
        string name;
        address protocolAddress;
        ProtocolType protocolType;
        address[] supportedAssets;
        uint256 totalAllocated;
        uint256 currentAPY;
        uint256 historicalAPY;
        uint256 riskScore; // 1-100 scale
        uint256 liquidityScore; // 1-100 scale
        uint256 reliabilityScore; // 1-100 scale
        uint256 maxAllocation; // Maximum allocation limit
        uint256 minAllocation; // Minimum allocation threshold
        uint256 lastUpdate;
        AllocationStatus status;
        bool autoCompoundEnabled;
        uint256 withdrawalDelay;
    }
    
    struct Asset {
        address token;
        uint256 totalLiquidity;
        uint256 availableLiquidity;
        uint256 allocatedLiquidity;
        uint256 reservedLiquidity;
        uint256 targetUtilization; // Target utilization rate
        uint256 currentUtilization;
        uint256 optimalAllocation;
        mapping(uint256 => uint256) protocolAllocations; // protocolId => amount
        uint256[] activeProtocols;
        uint256 lastRebalance;
        AllocationStrategy strategy;
    }
    
    struct AllocationTarget {
        uint256 protocolId;
        uint256 targetPercentage; // Percentage of total liquidity
        uint256 minPercentage;
        uint256 maxPercentage;
        uint256 priority; // Higher number = higher priority
        uint256 riskWeight;
        uint256 yieldWeight;
        bool dynamicAdjustment;
    }
    
    struct RebalanceParams {
        uint256 rebalanceThreshold; // Percentage deviation to trigger rebalance
        uint256 maxSlippage;
        uint256 rebalanceInterval;
        uint256 emergencyThreshold;
        bool autoRebalanceEnabled;
        bool emergencyRebalanceEnabled;
        uint256 gasLimit;
    }
    
    struct PerformanceMetrics {
        uint256 totalYield;
        uint256 averageAPY;
        uint256 riskAdjustedReturn;
        uint256 sharpeRatio;
        uint256 maxDrawdown;
        uint256 volatility;
        uint256 liquidityUtilization;
        uint256 protocolDiversification;
        uint256 lastCalculation;
    }
    
    struct RebalanceExecution {
        uint256 executionId;
        address asset;
        uint256 timestamp;
        uint256 totalLiquidityBefore;
        uint256 totalLiquidityAfter;
        uint256 protocolsRebalanced;
        uint256 gasUsed;
        bool successful;
        string reason;
        uint256[] protocolAllocations;
    }
    
    struct LiquidityFlow {
        address asset;
        uint256 protocolId;
        uint256 amount;
        bool isInflow; // true for deposit, false for withdrawal
        uint256 timestamp;
        uint256 newAllocation;
        uint256 utilizationAfter;
    }
    
    // Storage
    mapping(uint256 => Protocol) public protocols;
    mapping(address => Asset) public assets;
    mapping(address => mapping(uint256 => AllocationTarget)) public allocationTargets;
    mapping(address => RebalanceParams) public rebalanceParams;
    mapping(address => PerformanceMetrics) public performanceMetrics;
    mapping(uint256 => RebalanceExecution) public rebalanceHistory;
    mapping(address => LiquidityFlow[]) public liquidityFlows;
    
    // Protocol and asset tracking
    uint256 public protocolCounter;
    uint256 public rebalanceCounter;
    uint256[] public activeProtocols;
    address[] public supportedAssets;
    mapping(address => bool) public assetSupported;
    
    // Global parameters
    uint256 public globalRiskTolerance = 5000; // 50%
    uint256 public maxProtocolConcentration = 3000; // 30%
    uint256 public minLiquidityReserve = 1000; // 10%
    uint256 public rebalanceFrequency = 1 hours;
    
    // Emergency controls
    bool public emergencyMode;
    bool public allocationPaused;
    mapping(uint256 => bool) public protocolEmergencyExit;
    mapping(address => bool) public assetEmergencyWithdraw;
    
    // Fee management
    uint256 public managementFee = 200; // 2%
    uint256 public performanceFee = 1000; // 10%
    address public feeRecipient;
    
    event ProtocolAdded(
        uint256 indexed protocolId,
        string name,
        address protocolAddress,
        ProtocolType protocolType
    );
    
    event LiquidityAllocated(
        address indexed asset,
        uint256 indexed protocolId,
        uint256 amount,
        uint256 newAllocation
    );
    
    event LiquidityDeallocated(
        address indexed asset,
        uint256 indexed protocolId,
        uint256 amount,
        uint256 newAllocation
    );
    
    event RebalanceExecuted(
        uint256 indexed executionId,
        address indexed asset,
        uint256 protocolsRebalanced,
        uint256 totalLiquidity
    );
    
    event EmergencyWithdrawal(
        address indexed asset,
        uint256 indexed protocolId,
        uint256 amount,
        string reason
    );
    
    event PerformanceUpdated(
        address indexed asset,
        uint256 totalYield,
        uint256 averageAPY,
        uint256 riskAdjustedReturn
    );
    
    constructor(address _feeRecipient) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(ALLOCATOR_ROLE, msg.sender);
        _grantRole(KEEPER_ROLE, msg.sender);
        
        feeRecipient = _feeRecipient;
    }
    
    /**
     * @dev Add a new protocol to the allocation system
     */
    function addProtocol(
        string memory name,
        address protocolAddress,
        ProtocolType protocolType,
        address[] memory supportedAssets_,
        uint256 maxAllocation,
        uint256 minAllocation,
        uint256 riskScore,
        uint256 withdrawalDelay
    ) external onlyRole(ALLOCATOR_ROLE) {
        require(protocolAddress != address(0), "Invalid protocol address");
        require(supportedAssets_.length > 0, "No supported assets");
        require(riskScore <= 100, "Invalid risk score");
        require(maxAllocation >= minAllocation, "Invalid allocation bounds");
        
        uint256 protocolId = ++protocolCounter;
        
        protocols[protocolId] = Protocol({
            protocolId: protocolId,
            name: name,
            protocolAddress: protocolAddress,
            protocolType: protocolType,
            supportedAssets: supportedAssets_,
            totalAllocated: 0,
            currentAPY: 0,
            historicalAPY: 0,
            riskScore: riskScore,
            liquidityScore: 50, // Default score
            reliabilityScore: 50, // Default score
            maxAllocation: maxAllocation,
            minAllocation: minAllocation,
            lastUpdate: block.timestamp,
            status: AllocationStatus.ACTIVE,
            autoCompoundEnabled: true,
            withdrawalDelay: withdrawalDelay
        });
        
        activeProtocols.push(protocolId);
        
        // Add supported assets if not already added
        for (uint256 i = 0; i < supportedAssets_.length; i++) {
            if (!assetSupported[supportedAssets_[i]]) {
                supportedAssets.push(supportedAssets_[i]);
                assetSupported[supportedAssets_[i]] = true;
                
                // Initialize asset with default strategy
                assets[supportedAssets_[i]].token = supportedAssets_[i];
                assets[supportedAssets_[i]].strategy = AllocationStrategy.BALANCED;
                assets[supportedAssets_[i]].targetUtilization = 8000; // 80%
            }
        }
        
        emit ProtocolAdded(protocolId, name, protocolAddress, protocolType);
    }
    
    /**
     * @dev Allocate liquidity to protocols based on strategy
     */
    function allocateLiquidity(
        address asset,
        uint256 amount
    ) external onlyRole(PROTOCOL_ROLE) nonReentrant {
        require(!allocationPaused && !emergencyMode, "Allocation paused");
        require(assetSupported[asset], "Asset not supported");
        require(amount >= MIN_ALLOCATION_THRESHOLD, "Amount too small");
        
        Asset storage assetData = assets[asset];
        assetData.totalLiquidity += amount;
        assetData.availableLiquidity += amount;
        
        // Execute allocation based on strategy
        _executeAllocationStrategy(asset, amount);
        
        // Update utilization
        _updateUtilization(asset);
        
        // Record liquidity flow
        liquidityFlows[asset].push(LiquidityFlow({
            asset: asset,
            protocolId: 0, // General allocation
            amount: amount,
            isInflow: true,
            timestamp: block.timestamp,
            newAllocation: assetData.allocatedLiquidity,
            utilizationAfter: assetData.currentUtilization
        }));
    }
    
    /**
     * @dev Execute allocation strategy for an asset
     */
    function _executeAllocationStrategy(address asset, uint256 amount) internal {
        Asset storage assetData = assets[asset];
        AllocationStrategy strategy = assetData.strategy;
        
        if (strategy == AllocationStrategy.DYNAMIC) {
            _executeDynamicAllocation(asset, amount);
        } else if (strategy == AllocationStrategy.YIELD_OPTIMIZED) {
            _executeYieldOptimizedAllocation(asset, amount);
        } else if (strategy == AllocationStrategy.RISK_MINIMIZED) {
            _executeRiskMinimizedAllocation(asset, amount);
        } else {
            _executeBalancedAllocation(asset, amount);
        }
    }
    
    /**
     * @dev Execute dynamic allocation based on market conditions
     */
    function _executeDynamicAllocation(address asset, uint256 amount) internal {
        Asset storage assetData = assets[asset];
        uint256[] memory protocolIds = assetData.activeProtocols;
        
        // Calculate dynamic scores for each protocol
        uint256[] memory dynamicScores = new uint256[](protocolIds.length);
        uint256 totalScore = 0;
        
        for (uint256 i = 0; i < protocolIds.length; i++) {
            uint256 protocolId = protocolIds[i];
            Protocol memory protocol = protocols[protocolId];
            
            if (protocol.status == AllocationStatus.ACTIVE) {
                // Dynamic score based on APY, risk, liquidity, and market conditions
                uint256 score = _calculateDynamicScore(protocol);
                dynamicScores[i] = score;
                totalScore += score;
            }
        }
        
        // Allocate based on dynamic scores
        for (uint256 i = 0; i < protocolIds.length; i++) {
            if (dynamicScores[i] > 0) {
                uint256 allocationAmount = (amount * dynamicScores[i]) / totalScore;
                if (allocationAmount > 0) {
                    _allocateToProtocol(asset, protocolIds[i], allocationAmount);
                }
            }
        }
    }
    
    /**
     * @dev Execute yield-optimized allocation
     */
    function _executeYieldOptimizedAllocation(address asset, uint256 amount) internal {
        Asset storage assetData = assets[asset];
        uint256[] memory protocolIds = assetData.activeProtocols;
        
        // Sort protocols by APY (highest first)
        uint256[] memory sortedProtocols = _sortProtocolsByAPY(protocolIds);
        
        uint256 remainingAmount = amount;
        
        for (uint256 i = 0; i < sortedProtocols.length && remainingAmount > 0; i++) {
            uint256 protocolId = sortedProtocols[i];
            Protocol memory protocol = protocols[protocolId];
            
            if (protocol.status == AllocationStatus.ACTIVE) {
                uint256 maxAllowedAllocation = _calculateMaxAllocation(asset, protocolId);
                uint256 currentAllocation = assetData.protocolAllocations[protocolId];
                uint256 availableCapacity = maxAllowedAllocation > currentAllocation ? 
                    maxAllowedAllocation - currentAllocation : 0;
                
                uint256 allocationAmount = Math.min(remainingAmount, availableCapacity);
                
                if (allocationAmount > 0) {
                    _allocateToProtocol(asset, protocolId, allocationAmount);
                    remainingAmount -= allocationAmount;
                }
            }
        }
    }
    
    /**
     * @dev Execute risk-minimized allocation
     */
    function _executeRiskMinimizedAllocation(address asset, uint256 amount) internal {
        Asset storage assetData = assets[asset];
        uint256[] memory protocolIds = assetData.activeProtocols;
        
        // Sort protocols by risk score (lowest first)
        uint256[] memory sortedProtocols = _sortProtocolsByRisk(protocolIds);
        
        // Distribute evenly among low-risk protocols
        uint256 lowRiskProtocols = 0;
        for (uint256 i = 0; i < sortedProtocols.length; i++) {
            if (protocols[sortedProtocols[i]].riskScore <= 30) { // Low risk threshold
                lowRiskProtocols++;
            }
        }
        
        if (lowRiskProtocols > 0) {
            uint256 amountPerProtocol = amount / lowRiskProtocols;
            
            for (uint256 i = 0; i < lowRiskProtocols; i++) {
                uint256 protocolId = sortedProtocols[i];
                _allocateToProtocol(asset, protocolId, amountPerProtocol);
            }
        }
    }
    
    /**
     * @dev Execute balanced allocation
     */
    function _executeBalancedAllocation(address asset, uint256 amount) internal {
        Asset storage assetData = assets[asset];
        uint256[] memory protocolIds = assetData.activeProtocols;
        
        if (protocolIds.length > 0) {
            uint256 amountPerProtocol = amount / protocolIds.length;
            
            for (uint256 i = 0; i < protocolIds.length; i++) {
                uint256 protocolId = protocolIds[i];
                if (protocols[protocolId].status == AllocationStatus.ACTIVE) {
                    _allocateToProtocol(asset, protocolId, amountPerProtocol);
                }
            }
        }
    }
    
    /**
     * @dev Allocate amount to specific protocol
     */
    function _allocateToProtocol(address asset, uint256 protocolId, uint256 amount) internal {
        Asset storage assetData = assets[asset];
        Protocol storage protocol = protocols[protocolId];
        
        require(amount > 0, "Invalid allocation amount");
        require(protocol.status == AllocationStatus.ACTIVE, "Protocol not active");
        
        // Check allocation limits
        uint256 newAllocation = assetData.protocolAllocations[protocolId] + amount;
        require(newAllocation <= protocol.maxAllocation, "Exceeds max allocation");
        
        // Update allocations
        assetData.protocolAllocations[protocolId] = newAllocation;
        assetData.allocatedLiquidity += amount;
        assetData.availableLiquidity -= amount;
        protocol.totalAllocated += amount;
        
        // Add to active protocols if not already present
        bool isActive = false;
        for (uint256 i = 0; i < assetData.activeProtocols.length; i++) {
            if (assetData.activeProtocols[i] == protocolId) {
                isActive = true;
                break;
            }
        }
        if (!isActive) {
            assetData.activeProtocols.push(protocolId);
        }
        
        emit LiquidityAllocated(asset, protocolId, amount, newAllocation);
    }
    
    /**
     * @dev Execute automated rebalancing
     */
    function executeRebalance(address asset) external onlyRole(KEEPER_ROLE) nonReentrant {
        require(!allocationPaused && !emergencyMode, "Rebalancing disabled");
        
        RebalanceParams memory params = rebalanceParams[asset];
        require(params.autoRebalanceEnabled, "Auto rebalance disabled");
        
        Asset storage assetData = assets[asset];
        require(
            block.timestamp >= assetData.lastRebalance + params.rebalanceInterval,
            "Rebalance interval not met"
        );
        
        uint256 executionId = ++rebalanceCounter;
        uint256 startGas = gasleft();
        uint256 totalLiquidityBefore = assetData.totalLiquidity;
        
        // Execute rebalancing logic
        uint256 protocolsRebalanced = _executeRebalanceLogic(asset);
        
        uint256 totalLiquidityAfter = assetData.totalLiquidity;
        uint256 gasUsed = startGas - gasleft();
        
        // Record rebalance execution
        rebalanceHistory[executionId] = RebalanceExecution({
            executionId: executionId,
            asset: asset,
            timestamp: block.timestamp,
            totalLiquidityBefore: totalLiquidityBefore,
            totalLiquidityAfter: totalLiquidityAfter,
            protocolsRebalanced: protocolsRebalanced,
            gasUsed: gasUsed,
            successful: true,
            reason: "Automated rebalance",
            protocolAllocations: new uint256[](0)
        });
        
        assetData.lastRebalance = block.timestamp;
        
        // Update performance metrics
        _updatePerformanceMetrics(asset);
        
        emit RebalanceExecuted(executionId, asset, protocolsRebalanced, totalLiquidityAfter);
    }
    
    /**
     * @dev Execute rebalancing logic
     */
    function _executeRebalanceLogic(address asset) internal returns (uint256) {
        Asset storage assetData = assets[asset];
        uint256[] memory protocolIds = assetData.activeProtocols;
        uint256 protocolsRebalanced = 0;
        
        // Calculate optimal allocations
        uint256[] memory optimalAllocations = _calculateOptimalAllocations(asset);
        
        for (uint256 i = 0; i < protocolIds.length; i++) {
            uint256 protocolId = protocolIds[i];
            uint256 currentAllocation = assetData.protocolAllocations[protocolId];
            uint256 targetAllocation = optimalAllocations[i];
            
            if (_shouldRebalanceProtocol(currentAllocation, targetAllocation, asset)) {
                _rebalanceProtocol(asset, protocolId, targetAllocation);
                protocolsRebalanced++;
            }
        }
        
        return protocolsRebalanced;
    }
    
    /**
     * @dev Calculate optimal allocations for all protocols
     */
    function _calculateOptimalAllocations(address asset) internal view returns (uint256[] memory) {
        Asset storage assetData = assets[asset];
        uint256[] memory protocolIds = assetData.activeProtocols;
        uint256[] memory allocations = new uint256[](protocolIds.length);
        
        uint256 totalLiquidity = assetData.totalLiquidity;
        uint256 totalScore = 0;
        
        // Calculate scores for each protocol
        uint256[] memory scores = new uint256[](protocolIds.length);
        for (uint256 i = 0; i < protocolIds.length; i++) {
            uint256 protocolId = protocolIds[i];
            Protocol memory protocol = protocols[protocolId];
            
            if (protocol.status == AllocationStatus.ACTIVE) {
                uint256 score = _calculateAllocationScore(protocol);
                scores[i] = score;
                totalScore += score;
            }
        }
        
        // Calculate allocations based on scores
        for (uint256 i = 0; i < protocolIds.length; i++) {
            if (scores[i] > 0) {
                uint256 allocation = (totalLiquidity * scores[i]) / totalScore;
                
                // Apply constraints
                uint256 protocolId = protocolIds[i];
                Protocol memory protocol = protocols[protocolId];
                allocation = Math.max(allocation, protocol.minAllocation);
                allocation = Math.min(allocation, protocol.maxAllocation);
                
                allocations[i] = allocation;
            }
        }
        
        return allocations;
    }
    
    /**
     * @dev Calculate allocation score for a protocol
     */
    function _calculateAllocationScore(Protocol memory protocol) internal pure returns (uint256) {
        // Weighted score: 40% APY, 30% risk-adjusted return, 20% liquidity, 10% reliability
        uint256 apyScore = protocol.currentAPY;
        uint256 riskAdjustedScore = protocol.currentAPY * (100 - protocol.riskScore) / 100;
        uint256 liquidityScore = protocol.liquidityScore;
        uint256 reliabilityScore = protocol.reliabilityScore;
        
        return (apyScore * 40 + riskAdjustedScore * 30 + liquidityScore * 20 + reliabilityScore * 10) / 100;
    }
    
    /**
     * @dev Calculate dynamic score for a protocol
     */
    function _calculateDynamicScore(Protocol memory protocol) internal pure returns (uint256) {
        // More complex scoring that considers market conditions
        uint256 baseScore = _calculateAllocationScore(protocol);
        
        // Apply dynamic adjustments based on market conditions
        uint256 marketMultiplier = _calculateMarketMultiplier(protocol);
        
        // Apply volatility adjustment
        uint256 volatilityAdjustment = _calculateVolatilityAdjustment(protocol);
        marketMultiplier = (marketMultiplier * volatilityAdjustment) / 100;
        
        return (baseScore * marketMultiplier) / 100;
    }
    
    /**
     * @dev Check if protocol should be rebalanced
     */
    function _shouldRebalanceProtocol(
        uint256 currentAllocation,
        uint256 targetAllocation,
        address asset
    ) internal view returns (bool) {
        if (targetAllocation == 0) return currentAllocation > 0;
        
        uint256 deviation = currentAllocation > targetAllocation ?
            ((currentAllocation - targetAllocation) * BASIS_POINTS) / targetAllocation :
            ((targetAllocation - currentAllocation) * BASIS_POINTS) / targetAllocation;
        
        return deviation > rebalanceParams[asset].rebalanceThreshold;
    }
    
    /**
     * @dev Rebalance specific protocol
     */
    function _rebalanceProtocol(address asset, uint256 protocolId, uint256 targetAllocation) internal {
        Asset storage assetData = assets[asset];
        Protocol storage protocol = protocols[protocolId];
        
        uint256 currentAllocation = assetData.protocolAllocations[protocolId];
        
        if (targetAllocation > currentAllocation) {
            // Increase allocation
            uint256 increaseAmount = targetAllocation - currentAllocation;
            require(assetData.availableLiquidity >= increaseAmount, "Insufficient available liquidity");
            
            assetData.protocolAllocations[protocolId] = targetAllocation;
            assetData.allocatedLiquidity += increaseAmount;
            assetData.availableLiquidity -= increaseAmount;
            protocol.totalAllocated += increaseAmount;
            
            emit LiquidityAllocated(asset, protocolId, increaseAmount, targetAllocation);
        } else if (targetAllocation < currentAllocation) {
            // Decrease allocation
            uint256 decreaseAmount = currentAllocation - targetAllocation;
            
            assetData.protocolAllocations[protocolId] = targetAllocation;
            assetData.allocatedLiquidity -= decreaseAmount;
            assetData.availableLiquidity += decreaseAmount;
            protocol.totalAllocated -= decreaseAmount;
            
            emit LiquidityDeallocated(asset, protocolId, decreaseAmount, targetAllocation);
        }
    }
    
    /**
     * @dev Update utilization metrics
     */
    function _updateUtilization(address asset) internal {
        Asset storage assetData = assets[asset];
        
        if (assetData.totalLiquidity > 0) {
            assetData.currentUtilization = (assetData.allocatedLiquidity * BASIS_POINTS) / assetData.totalLiquidity;
        } else {
            assetData.currentUtilization = 0;
        }
    }
    
    /**
     * @dev Update performance metrics
     */
    function _updatePerformanceMetrics(address asset) internal {
        PerformanceMetrics storage metrics = performanceMetrics[asset];
        Asset storage assetData = assets[asset];
        
        uint256 totalYield = 0;
        uint256 weightedAPY = 0;
        uint256 totalRisk = 0;
        
        for (uint256 i = 0; i < assetData.activeProtocols.length; i++) {
            uint256 protocolId = assetData.activeProtocols[i];
            Protocol memory protocol = protocols[protocolId];
            uint256 allocation = assetData.protocolAllocations[protocolId];
            
            if (allocation > 0) {
                weightedAPY += (protocol.currentAPY * allocation);
                totalRisk += (protocol.riskScore * allocation);
            }
        }
        
        if (assetData.allocatedLiquidity > 0) {
            metrics.averageAPY = weightedAPY / assetData.allocatedLiquidity;
            uint256 averageRisk = totalRisk / assetData.allocatedLiquidity;
            metrics.riskAdjustedReturn = metrics.averageAPY * (100 - averageRisk) / 100;
        }
        
        metrics.liquidityUtilization = assetData.currentUtilization;
        metrics.protocolDiversification = assetData.activeProtocols.length;
        metrics.lastCalculation = block.timestamp;
        
        emit PerformanceUpdated(asset, totalYield, metrics.averageAPY, metrics.riskAdjustedReturn);
    }
    
    /**
     * @dev Sort protocols by APY (descending)
     */
    function _sortProtocolsByAPY(uint256[] memory protocolIds) internal view returns (uint256[] memory) {
        uint256[] memory sorted = new uint256[](protocolIds.length);
        for (uint256 i = 0; i < protocolIds.length; i++) {
            sorted[i] = protocolIds[i];
        }
        
        // Simple bubble sort (for small arrays)
        for (uint256 i = 0; i < sorted.length; i++) {
            for (uint256 j = i + 1; j < sorted.length; j++) {
                if (protocols[sorted[i]].currentAPY < protocols[sorted[j]].currentAPY) {
                    uint256 temp = sorted[i];
                    sorted[i] = sorted[j];
                    sorted[j] = temp;
                }
            }
        }
        
        return sorted;
    }
    
    /**
     * @dev Sort protocols by risk (ascending)
     */
    function _sortProtocolsByRisk(uint256[] memory protocolIds) internal view returns (uint256[] memory) {
        uint256[] memory sorted = new uint256[](protocolIds.length);
        for (uint256 i = 0; i < protocolIds.length; i++) {
            sorted[i] = protocolIds[i];
        }
        
        // Simple bubble sort (for small arrays)
        for (uint256 i = 0; i < sorted.length; i++) {
            for (uint256 j = i + 1; j < sorted.length; j++) {
                if (protocols[sorted[i]].riskScore > protocols[sorted[j]].riskScore) {
                    uint256 temp = sorted[i];
                    sorted[i] = sorted[j];
                    sorted[j] = temp;
                }
            }
        }
        
        return sorted;
    }
    
    /**
     * @dev Calculate maximum allocation for a protocol
     */
    function _calculateMaxAllocation(address asset, uint256 protocolId) internal view returns (uint256) {
        Asset storage assetData = assets[asset];
        Protocol memory protocol = protocols[protocolId];
        
        uint256 maxByConcentration = (assetData.totalLiquidity * maxProtocolConcentration) / BASIS_POINTS;
        return Math.min(protocol.maxAllocation, maxByConcentration);
    }
    
    /**
     * @dev Emergency withdraw from protocol
     */
    function emergencyWithdraw(address asset, uint256 protocolId, string memory reason) 
        external 
        onlyRole(ADMIN_ROLE) 
        nonReentrant 
    {
        Asset storage assetData = assets[asset];
        Protocol storage protocol = protocols[protocolId];
        
        uint256 allocation = assetData.protocolAllocations[protocolId];
        require(allocation > 0, "No allocation to withdraw");
        
        // Mark protocol for emergency exit
        protocolEmergencyExit[protocolId] = true;
        protocol.status = AllocationStatus.EMERGENCY_WITHDRAW;
        
        // Update allocations
        assetData.protocolAllocations[protocolId] = 0;
        assetData.allocatedLiquidity -= allocation;
        assetData.availableLiquidity += allocation;
        protocol.totalAllocated -= allocation;
        
        emit EmergencyWithdrawal(asset, protocolId, allocation, reason);
    }
    
    /**
     * @dev Set allocation strategy for an asset
     */
    function setAllocationStrategy(address asset, AllocationStrategy strategy) 
        external 
        onlyRole(ALLOCATOR_ROLE) 
    {
        require(assetSupported[asset], "Asset not supported");
        assets[asset].strategy = strategy;
    }
    
    /**
     * @dev Set rebalance parameters
     */
    function setRebalanceParams(
        address asset,
        uint256 rebalanceThreshold,
        uint256 maxSlippage,
        uint256 rebalanceInterval,
        bool autoRebalanceEnabled
    ) external onlyRole(ALLOCATOR_ROLE) {
        rebalanceParams[asset] = RebalanceParams({
            rebalanceThreshold: rebalanceThreshold,
            maxSlippage: maxSlippage,
            rebalanceInterval: rebalanceInterval,
            emergencyThreshold: 2000, // 20%
            autoRebalanceEnabled: autoRebalanceEnabled,
            emergencyRebalanceEnabled: true,
            gasLimit: 500000
        });
    }
    
    /**
     * @dev Get asset allocation info
     */
    function getAssetAllocation(address asset) 
        external 
        view 
        returns (
            uint256 totalLiquidity,
            uint256 availableLiquidity,
            uint256 allocatedLiquidity,
            uint256 currentUtilization,
            uint256[] memory activeProtocols
        ) 
    {
        Asset storage assetData = assets[asset];
        return (
            assetData.totalLiquidity,
            assetData.availableLiquidity,
            assetData.allocatedLiquidity,
            assetData.currentUtilization,
            assetData.activeProtocols
        );
    }
    
    /**
     * @dev Get protocol allocation for asset
     */
    function getProtocolAllocation(address asset, uint256 protocolId) 
        external 
        view 
        returns (uint256) 
    {
        return assets[asset].protocolAllocations[protocolId];
    }
    
    /**
     * @dev Emergency pause all allocations
     */
    function emergencyPause() external onlyRole(ADMIN_ROLE) {
        allocationPaused = true;
        emergencyMode = true;
    }
    
    /**
     * @dev Resume allocations
     */
    function resumeAllocations() external onlyRole(ADMIN_ROLE) {
        allocationPaused = false;
        emergencyMode = false;
    }
    
    /**
     * @dev Update protocol status
     */
    function updateProtocolStatus(uint256 protocolId, AllocationStatus newStatus) 
        external 
        onlyRole(ALLOCATOR_ROLE) 
    {
        protocols[protocolId].status = newStatus;
    }
    
    /**
     * @dev Update protocol APY
     */
    function updateProtocolAPY(uint256 protocolId, uint256 newAPY) 
        external 
        onlyRole(KEEPER_ROLE) 
    {
        Protocol storage protocol = protocols[protocolId];
        protocol.historicalAPY = protocol.currentAPY;
        protocol.currentAPY = newAPY;
        protocol.lastUpdate = block.timestamp;
    }

    /**
     * @dev Calculate market condition multiplier
     */
    function _calculateMarketMultiplier(Protocol memory protocol) internal view returns (uint256) {
        // Base multiplier
        uint256 multiplier = 100;
        
        // Adjust based on protocol type and current market conditions
        if (protocol.protocolType == ProtocolType.LENDING) {
            // Higher weight during high demand periods
            multiplier = protocol.currentAPY > protocol.historicalAPY ? 110 : 95;
        } else if (protocol.protocolType == ProtocolType.DEX) {
            // Adjust based on trading volume and liquidity
            multiplier = protocol.liquidityScore > 70 ? 105 : 90;
        } else if (protocol.protocolType == ProtocolType.STAKING) {
            // More conservative during volatile periods
            multiplier = protocol.riskScore < 30 ? 110 : 85;
        }
        
        return multiplier;
    }

    /**
     * @dev Calculate volatility adjustment
     */
    function _calculateVolatilityAdjustment(Protocol memory protocol) internal pure returns (uint256) {
        // Adjust allocation based on protocol risk score
        if (protocol.riskScore <= 20) {
            return 110; // Low risk, increase allocation
        } else if (protocol.riskScore <= 50) {
            return 100; // Medium risk, neutral
        } else if (protocol.riskScore <= 80) {
            return 90;  // High risk, reduce allocation
        } else {
            return 75;  // Very high risk, significantly reduce
        }
    }
}