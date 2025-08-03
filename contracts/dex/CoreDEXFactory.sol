// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./CoreDEX.sol";
import "./CoreDEXRouter.sol";
import "../core/ZeroSlippageEngine.sol";
import "../core/InfiniteLiquidityEngine.sol";

/**
 * @title CoreDEXFactory
 * @dev Factory contract for deploying and managing CoreDEX instances
 * @notice Handles deployment, configuration, and management of DEX components
 */
contract CoreDEXFactory is AccessControl, ReentrancyGuard {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant DEPLOYER_ROLE = keccak256("DEPLOYER_ROLE");
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    
    // DEX deployment configuration
    struct DEXConfig {
        uint256 defaultFeeRate;
        uint256 protocolFeeRate;
        address feeRecipient;
        bool isActive;
        uint256 createdAt;
    }
    
    // DEX instance information
    struct DEXInstance {
        address dexAddress;
        address routerAddress;
        address zeroSlippageEngine;
        address infiniteLiquidityEngine;
        DEXConfig config;
        uint256 deploymentBlock;
        string name;
        string version;
    }
    
    // State variables
    mapping(bytes32 => DEXInstance) public dexInstances;
    mapping(address => bytes32) public dexAddressToId;
    bytes32[] public allDEXIds;
    
    // Default configurations
    uint256 public defaultFeeRate = 300; // 0.3%
    uint256 public defaultProtocolFeeRate = 500; // 5%
    address public defaultFeeRecipient;
    
    // Template addresses for cloning
    address public zeroSlippageEngineTemplate;
    address public infiniteLiquidityEngineTemplate;
    
    // Factory statistics
    uint256 public totalDEXDeployed;
    uint256 public totalTradingVolume;
    uint256 public totalLiquidity;
    
    // Events
    event DEXDeployed(
        bytes32 indexed dexId,
        address indexed dexAddress,
        address indexed routerAddress,
        string name,
        uint256 timestamp
    );
    
    event DEXConfigUpdated(
        bytes32 indexed dexId,
        uint256 newFeeRate,
        uint256 newProtocolFeeRate,
        address newFeeRecipient,
        uint256 timestamp
    );
    
    event DEXStatusChanged(
        bytes32 indexed dexId,
        bool isActive,
        uint256 timestamp
    );
    
    event TemplateUpdated(
        address indexed oldTemplate,
        address indexed newTemplate,
        string templateType,
        uint256 timestamp
    );
    
    constructor(
        address _defaultFeeRecipient,
        address _zeroSlippageEngineTemplate,
        address _infiniteLiquidityEngineTemplate
    ) {
        require(_defaultFeeRecipient != address(0), "Invalid fee recipient");
        require(_zeroSlippageEngineTemplate != address(0), "Invalid zero slippage template");
        require(_infiniteLiquidityEngineTemplate != address(0), "Invalid infinite liquidity template");
        
        defaultFeeRecipient = _defaultFeeRecipient;
        zeroSlippageEngineTemplate = _zeroSlippageEngineTemplate;
        infiniteLiquidityEngineTemplate = _infiniteLiquidityEngineTemplate;
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(DEPLOYER_ROLE, msg.sender);
        _grantRole(MANAGER_ROLE, msg.sender);
    }
    
    /**
     * @dev Deploy a new CoreDEX instance
     */
    function deployDEX(
        string calldata name,
        string calldata version,
        uint256 feeRate,
        uint256 protocolFeeRate,
        address feeRecipient
    ) external onlyRole(DEPLOYER_ROLE) returns (
        bytes32 dexId,
        address dexAddress,
        address routerAddress
    ) {
        require(bytes(name).length > 0, "Invalid name");
        require(feeRate <= 1000, "Fee rate too high"); // Max 10%
        require(protocolFeeRate <= 10000, "Protocol fee rate too high");
        require(feeRecipient != address(0), "Invalid fee recipient");
        
        // Generate unique DEX ID
        dexId = keccak256(abi.encodePacked(name, version, block.timestamp, msg.sender));
        require(dexInstances[dexId].dexAddress == address(0), "DEX ID already exists");
        
        // Deploy ZeroSlippageEngine (simplified - in practice you might clone)
        address zeroSlippageEngine = _deployZeroSlippageEngine();
        
        // Deploy InfiniteLiquidityEngine (simplified - in practice you might clone)
        address infiniteLiquidityEngine = _deployInfiniteLiquidityEngine();
        
        // Deploy CoreDEX
        CoreDEX dex = new CoreDEX(
            zeroSlippageEngine,
            infiniteLiquidityEngine,
            feeRecipient
        );
        dexAddress = address(dex);
        
        // Deploy CoreDEXRouter
        CoreDEXRouter router = new CoreDEXRouter(
            dexAddress,
            zeroSlippageEngine
        );
        routerAddress = address(router);
        
        // Configure DEX
        dex.setDefaultFeeRate(feeRate);
        dex.setProtocolFeeRate(protocolFeeRate);
        
        // Store DEX instance
        dexInstances[dexId] = DEXInstance({
            dexAddress: dexAddress,
            routerAddress: routerAddress,
            zeroSlippageEngine: zeroSlippageEngine,
            infiniteLiquidityEngine: infiniteLiquidityEngine,
            config: DEXConfig({
                defaultFeeRate: feeRate,
                protocolFeeRate: protocolFeeRate,
                feeRecipient: feeRecipient,
                isActive: true,
                createdAt: block.timestamp
            }),
            deploymentBlock: block.number,
            name: name,
            version: version
        });
        
        // Update mappings
        dexAddressToId[dexAddress] = dexId;
        allDEXIds.push(dexId);
        
        // Update statistics
        totalDEXDeployed++;
        
        emit DEXDeployed(dexId, dexAddress, routerAddress, name, block.timestamp);
    }
    
    /**
     * @dev Update DEX configuration
     */
    function updateDEXConfig(
        bytes32 dexId,
        uint256 newFeeRate,
        uint256 newProtocolFeeRate,
        address newFeeRecipient
    ) external onlyRole(MANAGER_ROLE) {
        require(dexInstances[dexId].dexAddress != address(0), "DEX not found");
        require(newFeeRate <= 1000, "Fee rate too high");
        require(newProtocolFeeRate <= 10000, "Protocol fee rate too high");
        require(newFeeRecipient != address(0), "Invalid fee recipient");
        
        DEXInstance storage instance = dexInstances[dexId];
        CoreDEX dex = CoreDEX(instance.dexAddress);
        
        // Update DEX contract
        dex.setDefaultFeeRate(newFeeRate);
        dex.setProtocolFeeRate(newProtocolFeeRate);
        dex.setFeeRecipient(newFeeRecipient);
        
        // Update stored config
        instance.config.defaultFeeRate = newFeeRate;
        instance.config.protocolFeeRate = newProtocolFeeRate;
        instance.config.feeRecipient = newFeeRecipient;
        
        emit DEXConfigUpdated(dexId, newFeeRate, newProtocolFeeRate, newFeeRecipient, block.timestamp);
    }
    
    /**
     * @dev Activate or deactivate a DEX
     */
    function setDEXStatus(
        bytes32 dexId,
        bool isActive
    ) external onlyRole(MANAGER_ROLE) {
        require(dexInstances[dexId].dexAddress != address(0), "DEX not found");
        
        DEXInstance storage instance = dexInstances[dexId];
        CoreDEX dex = CoreDEX(instance.dexAddress);
        
        if (isActive && !instance.config.isActive) {
            dex.unpause();
        } else if (!isActive && instance.config.isActive) {
            dex.pause();
        }
        
        instance.config.isActive = isActive;
        
        emit DEXStatusChanged(dexId, isActive, block.timestamp);
    }
    
    /**
     * @dev Create trading pair on specific DEX
     */
    function createTradingPair(
        bytes32 dexId,
        address tokenA,
        address tokenB,
        uint256 feeRate
    ) external onlyRole(MANAGER_ROLE) returns (bytes32 pairId) {
        require(dexInstances[dexId].dexAddress != address(0), "DEX not found");
        require(dexInstances[dexId].config.isActive, "DEX not active");
        
        CoreDEX dex = CoreDEX(dexInstances[dexId].dexAddress);
        pairId = dex.createPair(tokenA, tokenB, feeRate);
    }
    
    /**
     * @dev Batch create multiple trading pairs
     */
    function batchCreateTradingPairs(
        bytes32 dexId,
        address[] calldata tokensA,
        address[] calldata tokensB,
        uint256[] calldata feeRates
    ) external onlyRole(MANAGER_ROLE) returns (bytes32[] memory pairIds) {
        require(tokensA.length == tokensB.length, "Length mismatch");
        require(tokensA.length == feeRates.length, "Length mismatch");
        require(dexInstances[dexId].dexAddress != address(0), "DEX not found");
        require(dexInstances[dexId].config.isActive, "DEX not active");
        
        CoreDEX dex = CoreDEX(dexInstances[dexId].dexAddress);
        pairIds = new bytes32[](tokensA.length);
        
        for (uint256 i = 0; i < tokensA.length; i++) {
            pairIds[i] = dex.createPair(tokensA[i], tokensB[i], feeRates[i]);
        }
    }
    
    /**
     * @dev Get DEX instance information
     */
    function getDEXInstance(bytes32 dexId) external view returns (DEXInstance memory) {
        return dexInstances[dexId];
    }
    
    /**
     * @dev Get DEX ID from address
     */
    function getDEXId(address dexAddress) external view returns (bytes32) {
        return dexAddressToId[dexAddress];
    }
    
    /**
     * @dev Get all DEX IDs
     */
    function getAllDEXIds() external view returns (bytes32[] memory) {
        return allDEXIds;
    }
    
    /**
     * @dev Get active DEX instances
     */
    function getActiveDEXInstances() external view returns (DEXInstance[] memory activeDEXs) {
        uint256 activeCount = 0;
        
        // Count active DEXs
        for (uint256 i = 0; i < allDEXIds.length; i++) {
            if (dexInstances[allDEXIds[i]].config.isActive) {
                activeCount++;
            }
        }
        
        // Populate active DEXs array
        activeDEXs = new DEXInstance[](activeCount);
        uint256 index = 0;
        
        for (uint256 i = 0; i < allDEXIds.length; i++) {
            if (dexInstances[allDEXIds[i]].config.isActive) {
                activeDEXs[index] = dexInstances[allDEXIds[i]];
                index++;
            }
        }
    }
    
    /**
     * @dev Get factory statistics
     */
    function getFactoryStats() external view returns (
        uint256 totalDEXs,
        uint256 activeDEXs,
        uint256 totalVolume,
        uint256 totalLiq
    ) {
        uint256 activeCount = 0;
        
        for (uint256 i = 0; i < allDEXIds.length; i++) {
            if (dexInstances[allDEXIds[i]].config.isActive) {
                activeCount++;
            }
        }
        
        return (
            totalDEXDeployed,
            activeCount,
            totalTradingVolume,
            totalLiquidity
        );
    }
    
    /**
     * @dev Update template addresses
     */
    function updateZeroSlippageEngineTemplate(
        address newTemplate
    ) external onlyRole(ADMIN_ROLE) {
        require(newTemplate != address(0), "Invalid template");
        
        address oldTemplate = zeroSlippageEngineTemplate;
        zeroSlippageEngineTemplate = newTemplate;
        
        emit TemplateUpdated(oldTemplate, newTemplate, "ZeroSlippageEngine", block.timestamp);
    }
    
    function updateInfiniteLiquidityEngineTemplate(
        address newTemplate
    ) external onlyRole(ADMIN_ROLE) {
        require(newTemplate != address(0), "Invalid template");
        
        address oldTemplate = infiniteLiquidityEngineTemplate;
        infiniteLiquidityEngineTemplate = newTemplate;
        
        emit TemplateUpdated(oldTemplate, newTemplate, "InfiniteLiquidityEngine", block.timestamp);
    }
    
    /**
     * @dev Update default configurations
     */
    function updateDefaultConfig(
        uint256 newDefaultFeeRate,
        uint256 newDefaultProtocolFeeRate,
        address newDefaultFeeRecipient
    ) external onlyRole(ADMIN_ROLE) {
        require(newDefaultFeeRate <= 1000, "Fee rate too high");
        require(newDefaultProtocolFeeRate <= 10000, "Protocol fee rate too high");
        require(newDefaultFeeRecipient != address(0), "Invalid fee recipient");
        
        defaultFeeRate = newDefaultFeeRate;
        defaultProtocolFeeRate = newDefaultProtocolFeeRate;
        defaultFeeRecipient = newDefaultFeeRecipient;
    }
    
    /**
     * @dev Emergency pause all DEXs
     */
    function emergencyPauseAll() external onlyRole(ADMIN_ROLE) {
        for (uint256 i = 0; i < allDEXIds.length; i++) {
            bytes32 dexId = allDEXIds[i];
            if (dexInstances[dexId].config.isActive) {
                CoreDEX dex = CoreDEX(dexInstances[dexId].dexAddress);
                dex.pause();
                dexInstances[dexId].config.isActive = false;
                
                emit DEXStatusChanged(dexId, false, block.timestamp);
            }
        }
    }
    
    /**
     * @dev Emergency unpause all DEXs
     */
    function emergencyUnpauseAll() external onlyRole(ADMIN_ROLE) {
        for (uint256 i = 0; i < allDEXIds.length; i++) {
            bytes32 dexId = allDEXIds[i];
            if (!dexInstances[dexId].config.isActive) {
                CoreDEX dex = CoreDEX(dexInstances[dexId].dexAddress);
                dex.unpause();
                dexInstances[dexId].config.isActive = true;
                
                emit DEXStatusChanged(dexId, true, block.timestamp);
            }
        }
    }
    
    /**
     * @dev Internal function to deploy ZeroSlippageEngine
     * @notice In production, this would use a more sophisticated cloning mechanism
     */
    function _deployZeroSlippageEngine() internal returns (address) {
        // Simplified deployment - in practice, you'd use CREATE2 or cloning
        // For now, return the template address
        return zeroSlippageEngineTemplate;
    }
    
    /**
     * @dev Internal function to deploy InfiniteLiquidityEngine
     * @notice In production, this would use a more sophisticated cloning mechanism
     */
    function _deployInfiniteLiquidityEngine() internal returns (address) {
        // Simplified deployment - in practice, you'd use CREATE2 or cloning
        // For now, return the template address
        return infiniteLiquidityEngineTemplate;
    }
    
    /**
     * @dev Collect fees from all DEXs
     */
    function collectAllProtocolFees() external onlyRole(ADMIN_ROLE) {
        for (uint256 i = 0; i < allDEXIds.length; i++) {
            bytes32 dexId = allDEXIds[i];
            if (dexInstances[dexId].config.isActive) {
                CoreDEX dex = CoreDEX(dexInstances[dexId].dexAddress);
                try dex.collectProtocolFees() {
                    // Fee collection successful
                } catch {
                    // Fee collection failed, continue with next DEX
                }
            }
        }
    }
    
    /**
     * @dev Update statistics (called by DEX instances)
     */
    function updateStatistics(
        uint256 volumeIncrease,
        uint256 liquidityIncrease
    ) external {
        // Only allow calls from deployed DEX instances
        require(dexAddressToId[msg.sender] != bytes32(0), "Unauthorized caller");
        
        totalTradingVolume += volumeIncrease;
        totalLiquidity += liquidityIncrease;
    }
}
