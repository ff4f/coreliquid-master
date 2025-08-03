// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./UnifiedLiquidityLayer.sol";
import "./CrossProtocolBridge.sol";
import "./AdvancedRebalancer.sol";
import "../lending/BorrowEngine.sol";
import "../vault/VaultManager.sol";
import "../common/OracleRouter.sol";

/**
 * @title IdleCapitalManager
 * @dev Automatically detects and reallocates idle capital across protocols for optimal yield
 * @notice This contract implements intelligent idle capital detection and automated reallocation
 */
contract IdleCapitalManager is AccessControl, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;
    using Math for uint256;
    
    bytes32 public constant CAPITAL_MANAGER_ROLE = keccak256("CAPITAL_MANAGER_ROLE");
    bytes32 public constant KEEPER_ROLE = keccak256("KEEPER_ROLE");
    bytes32 public constant STRATEGY_ROLE = keccak256("STRATEGY_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
    
    // Core integrations
    UnifiedLiquidityLayer public immutable unifiedLiquidity;
    CrossProtocolBridge public immutable crossProtocolBridge;
    AdvancedRebalancer public immutable advancedRebalancer;
    BorrowEngine public immutable borrowEngine;
    VaultManager public immutable vaultManager;
    OracleRouter public immutable oracleRouter;
    
    // Protocol types for idle capital management
    enum ProtocolType {
        LENDING,
        DEX,
        VAULT,
        STAKING,
        EXTERNAL
    }
    
    // Idle capital detection parameters
    struct IdleCapitalConfig {
        uint256 idleThreshold; // Minimum amount to consider as idle
        uint256 utilizationThreshold; // Below this utilization, capital is considered idle
        uint256 yieldThreshold; // Minimum yield difference to trigger reallocation
        uint256 timeThreshold; // Time capital must be idle before reallocation
        uint256 maxReallocationPercentage; // Max % of idle capital to reallocate at once
        uint256 cooldownPeriod; // Minimum time between reallocations
        bool autoReallocationEnabled;
        bool emergencyModeEnabled;
    }
    
    // Idle capital detection result
    struct IdleCapitalDetection {
        address asset;
        ProtocolType protocol;
        uint256 totalCapital;
        uint256 activeCapital;
        uint256 idleCapital;
        uint256 utilizationRate;
        uint256 currentYield;
        uint256 opportunityCost;
        uint256 detectionTimestamp;
        bool isIdle;
        bool isReallocatable;
    }
    
    // Reallocation opportunity
    struct ReallocationOpportunity {
        address asset;
        ProtocolType fromProtocol;
        ProtocolType toProtocol;
        uint256 amount;
        uint256 currentYield;
        uint256 targetYield;
        uint256 yieldImprovement;
        uint256 estimatedGasCost;
        uint256 netBenefit;
        uint256 riskScore;
        uint256 confidence;
        uint256 timestamp;
        bool isExecutable;
    }
    
    // Automated reallocation strategy
    struct ReallocationStrategy {
        address asset;
        ProtocolType[] sourceProtocols;
        ProtocolType[] targetProtocols;
        uint256[] targetAllocations;
        uint256 minYieldImprovement;
        uint256 maxRiskIncrease;
        uint256 executionFrequency;
        uint256 lastExecution;
        bool isActive;
        bool isConservative;
    }
    
    // Capital efficiency metrics
    struct CapitalEfficiency {
        uint256 totalManagedCapital;
        uint256 activeCapital;
        uint256 idleCapital;
        uint256 reallocatedCapital;
        uint256 totalYieldGenerated;
        uint256 opportunityCostSaved;
        uint256 efficiencyScore;
        uint256 lastUpdate;
    }
    
    // Real-time monitoring data
    struct MonitoringData {
        mapping(ProtocolType => uint256) protocolUtilization;
        mapping(ProtocolType => uint256) protocolYields;
        mapping(ProtocolType => uint256) protocolRisks;
        mapping(ProtocolType => uint256) lastUpdate;
        uint256 marketVolatility;
        uint256 liquidityConditions;
        uint256 yieldEnvironment;
        bool isHighVolatility;
        bool isLowLiquidity;
    }
    
    mapping(address => IdleCapitalConfig) public idleCapitalConfigs;
    mapping(bytes32 => IdleCapitalDetection) public idleCapitalDetections;
    mapping(bytes32 => ReallocationOpportunity) public reallocationOpportunities;
    mapping(uint256 => ReallocationStrategy) public reallocationStrategies;
    mapping(address => CapitalEfficiency) public capitalEfficiencies;
    mapping(address => MonitoringData) public monitoringData;
    
    mapping(address => bytes32[]) public assetIdleDetections;
    mapping(address => bytes32[]) public assetOpportunities;
    mapping(address => uint256[]) public assetStrategies;
    
    bytes32[] public activeDetections;
    bytes32[] public activeOpportunities;
    uint256 public nextStrategyId = 1;
    
    uint256 public totalIdleCapitalDetected;
    uint256 public totalCapitalReallocated;
    uint256 public totalYieldImprovement;
    uint256 public totalGasSaved;
    
    uint256 public constant PRECISION = 1e18;
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant DEFAULT_IDLE_THRESHOLD = 1000 * PRECISION; // 1000 tokens
    uint256 public constant DEFAULT_UTILIZATION_THRESHOLD = 5000; // 50%
    uint256 public constant DEFAULT_YIELD_THRESHOLD = 100; // 1%
    uint256 public constant DEFAULT_TIME_THRESHOLD = 1 hours;
    uint256 public constant MAX_REALLOCATION_PERCENTAGE = 5000; // 50%
    uint256 public constant MIN_YIELD_IMPROVEMENT = 50; // 0.5%
    
    event IdleCapitalDetected(
        address indexed asset,
        ProtocolType indexed protocol,
        uint256 idleAmount,
        uint256 utilizationRate,
        uint256 opportunityCost,
        bytes32 detectionId
    );
    
    event ReallocationOpportunityIdentified(
        address indexed asset,
        ProtocolType fromProtocol,
        ProtocolType toProtocol,
        uint256 amount,
        uint256 yieldImprovement,
        bytes32 opportunityId
    );
    
    event AutoReallocationExecuted(
        address indexed asset,
        ProtocolType fromProtocol,
        ProtocolType toProtocol,
        uint256 amount,
        uint256 actualYieldImprovement,
        uint256 gasCost,
        bytes32 opportunityId
    );
    
    event CapitalEfficiencyUpdated(
        address indexed asset,
        uint256 oldEfficiencyScore,
        uint256 newEfficiencyScore,
        uint256 totalIdleCapital,
        uint256 timestamp
    );
    
    event EmergencyReallocationTriggered(
        address indexed asset,
        ProtocolType fromProtocol,
        uint256 amount,
        uint256 riskScore,
        uint256 timestamp
    );
    
    event StrategyCreated(
        uint256 indexed strategyId,
        address indexed asset,
        ProtocolType[] sourceProtocols,
        ProtocolType[] targetProtocols,
        uint256 timestamp
    );
    
    constructor(
        address _unifiedLiquidity,
        address _crossProtocolBridge,
        address _advancedRebalancer,
        address _borrowEngine,
        address _vaultManager,
        address _oracleRouter
    ) {
        require(_unifiedLiquidity != address(0), "Invalid unified liquidity");
        require(_crossProtocolBridge != address(0), "Invalid cross protocol bridge");
        require(_advancedRebalancer != address(0), "Invalid advanced rebalancer");
        require(_borrowEngine != address(0), "Invalid borrow engine");
        require(_vaultManager != address(0), "Invalid vault manager");
        require(_oracleRouter != address(0), "Invalid oracle router");
        
        unifiedLiquidity = UnifiedLiquidityLayer(_unifiedLiquidity);
        crossProtocolBridge = CrossProtocolBridge(_crossProtocolBridge);
        advancedRebalancer = AdvancedRebalancer(_advancedRebalancer);
        borrowEngine = BorrowEngine(_borrowEngine);
        vaultManager = VaultManager(_vaultManager);
        oracleRouter = OracleRouter(_oracleRouter);
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(CAPITAL_MANAGER_ROLE, msg.sender);
        _grantRole(KEEPER_ROLE, msg.sender);
        _grantRole(STRATEGY_ROLE, msg.sender);
        _grantRole(EMERGENCY_ROLE, msg.sender);
    }
    
    /**
     * @dev Detect idle capital across all protocols for an asset
     * @notice Main function for idle capital detection
     */
    function detectIdleCapital(
        address asset
    ) external onlyRole(KEEPER_ROLE) returns (bytes32[] memory detectionIds) {
        require(asset != address(0), "Invalid asset");
        
        // Update monitoring data
        _updateMonitoringData(asset);
        
        // Detect idle capital in each protocol
        ProtocolType[] memory protocols = _getAllProtocols();
        detectionIds = new bytes32[](protocols.length);
        uint256 detectionCount = 0;
        
        for (uint256 i = 0; i < protocols.length; i++) {
            bytes32 detectionId = _detectProtocolIdleCapital(asset, protocols[i]);
            if (detectionId != bytes32(0)) {
                detectionIds[detectionCount] = detectionId;
                detectionCount++;
            }
        }
        
        // Resize array to actual detection count
        assembly {
            mstore(detectionIds, detectionCount)
        }
        
        // Update capital efficiency metrics
        _updateCapitalEfficiency(asset);
    }
    
    /**
     * @dev Identify reallocation opportunities for idle capital
     */
    function identifyReallocationOpportunities(
        address asset
    ) external onlyRole(KEEPER_ROLE) returns (bytes32[] memory opportunityIds) {
        require(asset != address(0), "Invalid asset");
        
        bytes32[] memory detectionIds = assetIdleDetections[asset];
        opportunityIds = new bytes32[](detectionIds.length * 4); // Max 4 target protocols per detection
        uint256 opportunityCount = 0;
        
        for (uint256 i = 0; i < detectionIds.length; i++) {
            IdleCapitalDetection storage detection = idleCapitalDetections[detectionIds[i]];
            
            if (detection.isIdle && detection.isReallocatable) {
                // Find best reallocation targets
                bytes32[] memory opportunities = _findReallocationTargets(
                    asset,
                    detection.protocol,
                    detection.idleCapital
                );
                
                for (uint256 j = 0; j < opportunities.length; j++) {
                    if (opportunities[j] != bytes32(0)) {
                        opportunityIds[opportunityCount] = opportunities[j];
                        opportunityCount++;
                    }
                }
            }
        }
        
        // Resize array to actual opportunity count
        assembly {
            mstore(opportunityIds, opportunityCount)
        }
    }
    
    /**
     * @dev Execute automatic reallocation of idle capital
     */
    function executeAutoReallocation(
        bytes32 opportunityId
    ) external onlyRole(KEEPER_ROLE) nonReentrant whenNotPaused {
        ReallocationOpportunity storage opportunity = reallocationOpportunities[opportunityId];
        require(opportunity.isExecutable, "Opportunity not executable");
        require(block.timestamp <= opportunity.timestamp + 1 hours, "Opportunity expired");
        
        IdleCapitalConfig storage config = idleCapitalConfigs[opportunity.asset];
        require(config.autoReallocationEnabled, "Auto reallocation disabled");
        
        // Verify opportunity is still valid
        require(_validateOpportunity(opportunityId), "Opportunity no longer valid");
        
        uint256 gasStart = gasleft();
        
        // Execute reallocation through cross-protocol bridge
        try crossProtocolBridge.executeSeamlessTransfer(
            opportunity.asset,
            opportunity.amount,
            CrossProtocolBridge.ProtocolType(uint8(opportunity.fromProtocol)),
            CrossProtocolBridge.ProtocolType(uint8(opportunity.toProtocol)),
            ""
        ) {
            uint256 gasUsed = gasStart - gasleft();
            uint256 gasCost = gasUsed * tx.gasprice;
            
            // Calculate actual yield improvement
            uint256 actualYieldImprovement = _calculateActualYieldImprovement(
                opportunity.asset,
                opportunity.amount,
                opportunity.fromProtocol,
                opportunity.toProtocol
            );
            
            // Update metrics
            totalCapitalReallocated += opportunity.amount;
            totalYieldImprovement += actualYieldImprovement;
            totalGasSaved += (opportunity.estimatedGasCost > gasCost) ? 
                opportunity.estimatedGasCost - gasCost : 0;
            
            // Mark opportunity as executed
            opportunity.isExecutable = false;
            
            emit AutoReallocationExecuted(
                opportunity.asset,
                opportunity.fromProtocol,
                opportunity.toProtocol,
                opportunity.amount,
                actualYieldImprovement,
                gasCost,
                opportunityId
            );
            
        } catch Error(string memory reason) {
            // Handle execution failure
            opportunity.isExecutable = false;
            revert(string(abi.encodePacked("Reallocation failed: ", reason)));
        }
    }
    
    /**
     * @dev Create automated reallocation strategy
     */
    function createReallocationStrategy(
        address asset,
        ProtocolType[] calldata sourceProtocols,
        ProtocolType[] calldata targetProtocols,
        uint256[] calldata targetAllocations,
        uint256 minYieldImprovement,
        uint256 maxRiskIncrease,
        uint256 executionFrequency,
        bool isConservative
    ) external onlyRole(STRATEGY_ROLE) returns (uint256 strategyId) {
        require(asset != address(0), "Invalid asset");
        require(sourceProtocols.length > 0, "No source protocols");
        require(targetProtocols.length > 0, "No target protocols");
        require(targetProtocols.length == targetAllocations.length, "Array length mismatch");
        require(minYieldImprovement >= MIN_YIELD_IMPROVEMENT, "Yield improvement too low");
        
        // Verify allocations sum to 100%
        uint256 totalAllocation = 0;
        for (uint256 i = 0; i < targetAllocations.length; i++) {
            totalAllocation += targetAllocations[i];
        }
        require(totalAllocation == BASIS_POINTS, "Allocations must sum to 100%");
        
        strategyId = nextStrategyId++;
        
        reallocationStrategies[strategyId] = ReallocationStrategy({
            asset: asset,
            sourceProtocols: sourceProtocols,
            targetProtocols: targetProtocols,
            targetAllocations: targetAllocations,
            minYieldImprovement: minYieldImprovement,
            maxRiskIncrease: maxRiskIncrease,
            executionFrequency: executionFrequency,
            lastExecution: 0,
            isActive: true,
            isConservative: isConservative
        });
        
        assetStrategies[asset].push(strategyId);
        
        emit StrategyCreated(
            strategyId,
            asset,
            sourceProtocols,
            targetProtocols,
            block.timestamp
        );
    }
    
    /**
     * @dev Execute strategy-based reallocation
     */
    function executeStrategyReallocation(
        uint256 strategyId
    ) external onlyRole(KEEPER_ROLE) {
        ReallocationStrategy storage strategy = reallocationStrategies[strategyId];
        require(strategy.isActive, "Strategy not active");
        require(
            block.timestamp >= strategy.lastExecution + strategy.executionFrequency,
            "Execution frequency not met"
        );
        
        // Detect idle capital in source protocols
        uint256 totalIdleCapital = 0;
        for (uint256 i = 0; i < strategy.sourceProtocols.length; i++) {
            uint256 idleAmount = _getProtocolIdleCapital(strategy.asset, strategy.sourceProtocols[i]);
            totalIdleCapital += idleAmount;
        }
        
        if (totalIdleCapital < DEFAULT_IDLE_THRESHOLD) {
            return; // Not enough idle capital to reallocate
        }
        
        // Calculate reallocation amounts based on target allocations
        uint256[] memory reallocationAmounts = new uint256[](strategy.targetProtocols.length);
        for (uint256 i = 0; i < strategy.targetProtocols.length; i++) {
            reallocationAmounts[i] = (totalIdleCapital * strategy.targetAllocations[i]) / BASIS_POINTS;
        }
        
        // Execute reallocations
        _executeStrategyReallocations(
            strategyId,
            strategy.sourceProtocols,
            strategy.targetProtocols,
            reallocationAmounts
        );
        
        strategy.lastExecution = block.timestamp;
    }
    
    /**
     * @dev Configure idle capital detection parameters
     */
    function configureIdleCapitalDetection(
        address asset,
        uint256 idleThreshold,
        uint256 utilizationThreshold,
        uint256 yieldThreshold,
        uint256 timeThreshold,
        uint256 maxReallocationPercentage,
        uint256 cooldownPeriod,
        bool autoReallocationEnabled
    ) external onlyRole(CAPITAL_MANAGER_ROLE) {
        require(asset != address(0), "Invalid asset");
        require(utilizationThreshold <= BASIS_POINTS, "Invalid utilization threshold");
        require(maxReallocationPercentage <= MAX_REALLOCATION_PERCENTAGE, "Reallocation percentage too high");
        
        idleCapitalConfigs[asset] = IdleCapitalConfig({
            idleThreshold: idleThreshold > 0 ? idleThreshold : DEFAULT_IDLE_THRESHOLD,
            utilizationThreshold: utilizationThreshold > 0 ? utilizationThreshold : DEFAULT_UTILIZATION_THRESHOLD,
            yieldThreshold: yieldThreshold > 0 ? yieldThreshold : DEFAULT_YIELD_THRESHOLD,
            timeThreshold: timeThreshold > 0 ? timeThreshold : DEFAULT_TIME_THRESHOLD,
            maxReallocationPercentage: maxReallocationPercentage,
            cooldownPeriod: cooldownPeriod,
            autoReallocationEnabled: autoReallocationEnabled,
            emergencyModeEnabled: false
        });
    }
    
    /**
     * @dev Trigger emergency reallocation
     */
    function triggerEmergencyReallocation(
        address asset,
        ProtocolType fromProtocol,
        uint256 amount
    ) external onlyRole(EMERGENCY_ROLE) {
        require(asset != address(0), "Invalid asset");
        require(amount > 0, "Invalid amount");
        
        IdleCapitalConfig storage config = idleCapitalConfigs[asset];
        config.emergencyModeEnabled = true;
        
        // Find safest protocol to move capital to
        ProtocolType safeProtocol = _findSafestProtocol(asset);
        
        // Execute emergency reallocation
        crossProtocolBridge.executeSeamlessTransfer(
            asset,
            amount,
            CrossProtocolBridge.ProtocolType(uint8(fromProtocol)),
            CrossProtocolBridge.ProtocolType(uint8(safeProtocol)),
            ""
        );
        
        uint256 riskScore = _getProtocolRiskScore(asset, fromProtocol);
        
        emit EmergencyReallocationTriggered(
            asset,
            fromProtocol,
            amount,
            riskScore,
            block.timestamp
        );
    }
    
    /**
     * @dev Detect idle capital in a specific protocol
     */
    function _detectProtocolIdleCapital(
        address asset,
        ProtocolType protocol
    ) internal returns (bytes32 detectionId) {
        uint256 totalCapital = _getProtocolTotalCapital(asset, protocol);
        uint256 activeCapital = _getProtocolActiveCapital(asset, protocol);
        uint256 idleCapital = totalCapital > activeCapital ? totalCapital - activeCapital : 0;
        
        if (idleCapital < idleCapitalConfigs[asset].idleThreshold) {
            return bytes32(0); // Not enough idle capital
        }
        
        uint256 utilizationRate = totalCapital > 0 ? (activeCapital * BASIS_POINTS) / totalCapital : 0;
        
        if (utilizationRate >= idleCapitalConfigs[asset].utilizationThreshold) {
            return bytes32(0); // Utilization is acceptable
        }
        
        uint256 currentYield = _getProtocolYield(asset, protocol);
        uint256 opportunityCost = _calculateOpportunityCost(asset, protocol, idleCapital);
        
        detectionId = keccak256(abi.encodePacked(asset, protocol, block.timestamp));
        
        idleCapitalDetections[detectionId] = IdleCapitalDetection({
            asset: asset,
            protocol: protocol,
            totalCapital: totalCapital,
            activeCapital: activeCapital,
            idleCapital: idleCapital,
            utilizationRate: utilizationRate,
            currentYield: currentYield,
            opportunityCost: opportunityCost,
            detectionTimestamp: block.timestamp,
            isIdle: true,
            isReallocatable: _isReallocatable(asset, protocol, idleCapital)
        });
        
        assetIdleDetections[asset].push(detectionId);
        activeDetections.push(detectionId);
        totalIdleCapitalDetected += idleCapital;
        
        emit IdleCapitalDetected(
            asset,
            protocol,
            idleCapital,
            utilizationRate,
            opportunityCost,
            detectionId
        );
    }
    
    /**
     * @dev Find reallocation targets for idle capital
     */
    function _findReallocationTargets(
        address asset,
        ProtocolType fromProtocol,
        uint256 idleAmount
    ) internal returns (bytes32[] memory opportunityIds) {
        ProtocolType[] memory targetProtocols = _getTargetProtocols(fromProtocol);
        opportunityIds = new bytes32[](targetProtocols.length);
        uint256 opportunityCount = 0;
        
        uint256 currentYield = _getProtocolYield(asset, fromProtocol);
        
        for (uint256 i = 0; i < targetProtocols.length; i++) {
            ProtocolType toProtocol = targetProtocols[i];
            uint256 targetYield = _getProtocolYield(asset, toProtocol);
            
            // Check if yield improvement meets threshold
            if (targetYield <= currentYield + idleCapitalConfigs[asset].yieldThreshold) {
                continue;
            }
            
            uint256 yieldImprovement = targetYield - currentYield;
            uint256 estimatedGasCost = _estimateGasCost(asset, idleAmount, fromProtocol, toProtocol);
            uint256 netBenefit = _calculateNetBenefit(idleAmount, yieldImprovement, estimatedGasCost);
            
            if (netBenefit > 0) {
                bytes32 opportunityId = keccak256(abi.encodePacked(
                    asset, fromProtocol, toProtocol, idleAmount, block.timestamp
                ));
                
                reallocationOpportunities[opportunityId] = ReallocationOpportunity({
                    asset: asset,
                    fromProtocol: fromProtocol,
                    toProtocol: toProtocol,
                    amount: idleAmount,
                    currentYield: currentYield,
                    targetYield: targetYield,
                    yieldImprovement: yieldImprovement,
                    estimatedGasCost: estimatedGasCost,
                    netBenefit: netBenefit,
                    riskScore: _getProtocolRiskScore(asset, toProtocol),
                    confidence: _calculateConfidence(asset, fromProtocol, toProtocol),
                    timestamp: block.timestamp,
                    isExecutable: true
                });
                
                assetOpportunities[asset].push(opportunityId);
                activeOpportunities.push(opportunityId);
                opportunityIds[opportunityCount] = opportunityId;
                opportunityCount++;
                
                emit ReallocationOpportunityIdentified(
                    asset,
                    fromProtocol,
                    toProtocol,
                    idleAmount,
                    yieldImprovement,
                    opportunityId
                );
            }
        }
        
        // Resize array to actual opportunity count
        assembly {
            mstore(opportunityIds, opportunityCount)
        }
    }
    
    /**
     * @dev Execute strategy-based reallocations
     */
    function _executeStrategyReallocations(
        uint256 strategyId,
        ProtocolType[] memory sourceProtocols,
        ProtocolType[] memory targetProtocols,
        uint256[] memory amounts
    ) internal {
        ReallocationStrategy storage strategy = reallocationStrategies[strategyId];
        
        for (uint256 i = 0; i < targetProtocols.length; i++) {
            if (amounts[i] > 0) {
                // Find best source protocol for this amount
                ProtocolType bestSource = _findBestSourceProtocol(
                    strategy.asset,
                    sourceProtocols,
                    amounts[i]
                );
                
                // Execute reallocation
                crossProtocolBridge.executeSeamlessTransfer(
                    strategy.asset,
                    amounts[i],
                    CrossProtocolBridge.ProtocolType(uint8(bestSource)),
                    CrossProtocolBridge.ProtocolType(uint8(targetProtocols[i])),
                    ""
                );
            }
        }
    }
    
    /**
     * @dev Update monitoring data for asset
     */
    function _updateMonitoringData(address asset) internal {
        MonitoringData storage data = monitoringData[asset];
        
        ProtocolType[] memory protocols = _getAllProtocols();
        
        for (uint256 i = 0; i < protocols.length; i++) {
            data.protocolUtilization[protocols[i]] = _getProtocolUtilization(asset, protocols[i]);
            data.protocolYields[protocols[i]] = _getProtocolYield(asset, protocols[i]);
            data.protocolRisks[protocols[i]] = _getProtocolRiskScore(asset, protocols[i]);
            data.lastUpdate[protocols[i]] = block.timestamp;
        }
        
        data.marketVolatility = _getMarketVolatility(asset);
        data.liquidityConditions = _getLiquidityConditions(asset);
        data.yieldEnvironment = _getYieldEnvironment(asset);
        data.isHighVolatility = data.marketVolatility > 2000; // 20%
        data.isLowLiquidity = data.liquidityConditions < 5000; // 50%
    }
    
    /**
     * @dev Update capital efficiency metrics
     */
    function _updateCapitalEfficiency(address asset) internal {
        CapitalEfficiency storage efficiency = capitalEfficiencies[asset];
        
        uint256 totalManaged = _getTotalManagedCapital(asset);
        uint256 totalActive = _getTotalActiveCapital(asset);
        uint256 totalIdle = totalManaged > totalActive ? totalManaged - totalActive : 0;
        
        uint256 oldEfficiencyScore = efficiency.efficiencyScore;
        uint256 newEfficiencyScore = totalManaged > 0 ? 
            (totalActive * BASIS_POINTS) / totalManaged : 0;
        
        efficiency.totalManagedCapital = totalManaged;
        efficiency.activeCapital = totalActive;
        efficiency.idleCapital = totalIdle;
        efficiency.efficiencyScore = newEfficiencyScore;
        efficiency.lastUpdate = block.timestamp;
        
        emit CapitalEfficiencyUpdated(
            asset,
            oldEfficiencyScore,
            newEfficiencyScore,
            totalIdle,
            block.timestamp
        );
    }
    
    // Helper functions
    function _getAllProtocols() internal pure returns (ProtocolType[] memory) {
        ProtocolType[] memory protocols = new ProtocolType[](4);
        protocols[0] = ProtocolType.LENDING;
        protocols[1] = ProtocolType.DEX;
        protocols[2] = ProtocolType.VAULT;
        protocols[3] = ProtocolType.STAKING;
        return protocols;
    }
    
    function _getTargetProtocols(ProtocolType fromProtocol) internal pure returns (ProtocolType[] memory) {
        ProtocolType[] memory targets = new ProtocolType[](3);
        uint256 count = 0;
        
        for (uint256 i = 0; i < 4; i++) {
            ProtocolType protocol = ProtocolType(i);
            if (protocol != fromProtocol) {
                targets[count] = protocol;
                count++;
            }
        }
        
        // Resize array
        assembly {
            mstore(targets, count)
        }
        
        return targets;
    }
    
    function _validateOpportunity(bytes32 opportunityId) internal view returns (bool) {
        ReallocationOpportunity storage opportunity = reallocationOpportunities[opportunityId];
        
        // Check if yield improvement is still valid
        uint256 currentFromYield = _getProtocolYield(opportunity.asset, opportunity.fromProtocol);
        uint256 currentToYield = _getProtocolYield(opportunity.asset, opportunity.toProtocol);
        
        return currentToYield > currentFromYield + idleCapitalConfigs[opportunity.asset].yieldThreshold;
    }
    
    function _calculateActualYieldImprovement(
        address asset,
        uint256 amount,
        ProtocolType fromProtocol,
        ProtocolType toProtocol
    ) internal view returns (uint256) {
        uint256 fromYield = _getProtocolYield(asset, fromProtocol);
        uint256 toYield = _getProtocolYield(asset, toProtocol);
        
        return toYield > fromYield ? 
            ((toYield - fromYield) * amount) / BASIS_POINTS : 0;
    }
    
    function _findSafestProtocol(address asset) internal view returns (ProtocolType) {
        ProtocolType[] memory protocols = _getAllProtocols();
        ProtocolType safest = protocols[0];
        uint256 lowestRisk = _getProtocolRiskScore(asset, protocols[0]);
        
        for (uint256 i = 1; i < protocols.length; i++) {
            uint256 risk = _getProtocolRiskScore(asset, protocols[i]);
            if (risk < lowestRisk) {
                lowestRisk = risk;
                safest = protocols[i];
            }
        }
        
        return safest;
    }
    
    function _findBestSourceProtocol(
        address asset,
        ProtocolType[] memory sourceProtocols,
        uint256 amount
    ) internal view returns (ProtocolType) {
        ProtocolType best = sourceProtocols[0];
        uint256 maxIdle = _getProtocolIdleCapital(asset, sourceProtocols[0]);
        
        for (uint256 i = 1; i < sourceProtocols.length; i++) {
            uint256 idle = _getProtocolIdleCapital(asset, sourceProtocols[i]);
            if (idle >= amount && idle > maxIdle) {
                maxIdle = idle;
                best = sourceProtocols[i];
            }
        }
        
        return best;
    }
    
    // Placeholder functions for external data
    function _getProtocolTotalCapital(address asset, ProtocolType protocol) internal view returns (uint256) {
        return 1000000 * PRECISION; // 1M total capital placeholder
    }
    
    function _getProtocolActiveCapital(address asset, ProtocolType protocol) internal view returns (uint256) {
        return 600000 * PRECISION; // 600K active capital placeholder
    }
    
    function _getProtocolIdleCapital(address asset, ProtocolType protocol) internal view returns (uint256) {
        return 400000 * PRECISION; // 400K idle capital placeholder
    }
    
    function _getProtocolYield(address asset, ProtocolType protocol) internal view returns (uint256) {
        return 500; // 5% APY placeholder
    }
    
    function _getProtocolUtilization(address asset, ProtocolType protocol) internal view returns (uint256) {
        return 6000; // 60% utilization placeholder
    }
    
    function _getProtocolRiskScore(address asset, ProtocolType protocol) internal view returns (uint256) {
        return 3000; // 30% risk score placeholder
    }
    
    function _calculateOpportunityCost(address asset, ProtocolType protocol, uint256 amount) internal view returns (uint256) {
        return (amount * 200) / BASIS_POINTS; // 2% opportunity cost placeholder
    }
    
    function _isReallocatable(address asset, ProtocolType protocol, uint256 amount) internal view returns (bool) {
        return amount >= idleCapitalConfigs[asset].idleThreshold;
    }
    
    function _estimateGasCost(address asset, uint256 amount, ProtocolType from, ProtocolType to) internal view returns (uint256) {
        return 100000 * 20 gwei; // 100K gas * 20 gwei placeholder
    }
    
    function _calculateNetBenefit(uint256 amount, uint256 yieldImprovement, uint256 gasCost) internal pure returns (uint256) {
        uint256 annualBenefit = (amount * yieldImprovement) / BASIS_POINTS;
        return annualBenefit > gasCost ? annualBenefit - gasCost : 0;
    }
    
    function _calculateConfidence(address asset, ProtocolType from, ProtocolType to) internal view returns (uint256) {
        return 8000; // 80% confidence placeholder
    }
    
    function _getTotalManagedCapital(address asset) internal view returns (uint256) {
        return 10000000 * PRECISION; // 10M total managed placeholder
    }
    
    function _getTotalActiveCapital(address asset) internal view returns (uint256) {
        return 7000000 * PRECISION; // 7M total active placeholder
    }
    
    function _getMarketVolatility(address asset) internal view returns (uint256) {
        return 1500; // 15% volatility placeholder
    }
    
    function _getLiquidityConditions(address asset) internal view returns (uint256) {
        return 7000; // 70% liquidity conditions placeholder
    }
    
    function _getYieldEnvironment(address asset) internal view returns (uint256) {
        return 500; // 5% yield environment placeholder
    }
    
    // View functions
    function getIdleCapitalConfig(address asset) external view returns (IdleCapitalConfig memory) {
        return idleCapitalConfigs[asset];
    }
    
    function getIdleCapitalDetection(bytes32 detectionId) external view returns (IdleCapitalDetection memory) {
        return idleCapitalDetections[detectionId];
    }
    
    function getReallocationOpportunity(bytes32 opportunityId) external view returns (ReallocationOpportunity memory) {
        return reallocationOpportunities[opportunityId];
    }
    
    function getReallocationStrategy(uint256 strategyId) external view returns (ReallocationStrategy memory) {
        return reallocationStrategies[strategyId];
    }
    
    function getCapitalEfficiency(address asset) external view returns (CapitalEfficiency memory) {
        return capitalEfficiencies[asset];
    }
    
    function getAssetIdleDetections(address asset) external view returns (bytes32[] memory) {
        return assetIdleDetections[asset];
    }
    
    function getAssetOpportunities(address asset) external view returns (bytes32[] memory) {
        return assetOpportunities[asset];
    }
    
    function getAssetStrategies(address asset) external view returns (uint256[] memory) {
        return assetStrategies[asset];
    }
    
    function getActiveDetections() external view returns (bytes32[] memory) {
        return activeDetections;
    }
    
    function getActiveOpportunities() external view returns (bytes32[] memory) {
        return activeOpportunities;
    }
    
    function getTotalStats() external view returns (
        uint256 totalIdleDetected,
        uint256 totalReallocated,
        uint256 totalYieldImproved,
        uint256 totalGasSavedAmount
    ) {
        return (
            totalIdleCapitalDetected,
            totalCapitalReallocated,
            totalYieldImprovement,
            totalGasSaved
        );
    }
}
