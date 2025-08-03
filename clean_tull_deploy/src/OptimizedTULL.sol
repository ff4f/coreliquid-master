// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title OptimizedTULL - True Unified Liquidity Layer
 * @dev Cross-protocol asset sharing with automatic reallocation
 */
contract OptimizedTULL is AccessControl, ReentrancyGuard {
    bytes32 public constant PROTOCOL_ROLE = keccak256("PROTOCOL_ROLE");
    bytes32 public constant KEEPER_ROLE = keccak256("KEEPER_ROLE");
    
    struct AssetState {
        uint256 totalDeposited;
        uint256 totalUtilized;
        uint256 idleThreshold;
        uint256 lastRebalanceTimestamp;
    }
    
    struct ProtocolInfo {
        bool isActive;
        uint256 yieldRate; // basis points
        uint256 maxCapacity;
        uint256 currentAllocation;
    }
    
    // Core storage
    mapping(address => AssetState) public assetStates;
    mapping(address => mapping(address => uint256)) public userBalances; // user -> asset -> balance
    mapping(address => mapping(address => uint256)) public protocolAllocations; // protocol -> asset -> allocated
    mapping(address => ProtocolInfo) public protocols;
    
    address[] public registeredProtocols;
    address[] public supportedAssets;
    
    uint256 public constant REBALANCE_THRESHOLD = 1000; // 10%
    uint256 public constant MIN_IDLE_TIME = 1 hours;
    
    // Events
    event Deposited(address indexed user, address indexed asset, uint256 amount);
    event Withdrawn(address indexed user, address indexed asset, uint256 amount);
    event AssetAccessed(address indexed protocol, address indexed asset, uint256 amount);
    event AssetReturned(address indexed protocol, address indexed asset, uint256 amount);
    event IdleDetected(address indexed asset, uint256 idleAmount, address indexed targetProtocol);
    event Reallocated(address indexed fromProtocol, address indexed toProtocol, address indexed asset, uint256 amount);
    event ProtocolRegistered(address indexed protocol, uint256 yieldRate);
    
    constructor(address _treasury) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(KEEPER_ROLE, msg.sender);
        _grantRole(PROTOCOL_ROLE, _treasury);
    }
    
    /// @dev Deposit assets to unified storage
    function deposit(address asset, uint256 amount, address user) external onlyRole(PROTOCOL_ROLE) nonReentrant {
        require(amount > 0, "Invalid amount");
        require(_isAssetSupported(asset), "Asset not supported");
        
        IERC20(asset).transferFrom(msg.sender, address(this), amount);
        
        userBalances[user][asset] += amount;
        assetStates[asset].totalDeposited += amount;
        
        emit Deposited(user, asset, amount);
        
        // Auto-trigger reallocation if conditions met
        _autoReallocate(asset);
    }
    
    /// @dev Withdraw assets from unified storage
    function withdraw(address asset, uint256 amount, address user) external onlyRole(PROTOCOL_ROLE) nonReentrant {
        require(amount > 0, "Invalid amount");
        require(userBalances[user][asset] >= amount, "Insufficient balance");
        
        userBalances[user][asset] -= amount;
        assetStates[asset].totalDeposited -= amount;
        
        IERC20(asset).transfer(user, amount);
        
        emit Withdrawn(user, asset, amount);
    }
    
    /// @dev Cross-protocol asset access WITHOUT token transfer
    function accessAssets(address protocol, address asset, uint256 amount) external onlyRole(PROTOCOL_ROLE) {
        require(protocols[protocol].isActive, "Protocol not active");
        require(_getAvailableAssets(asset) >= amount, "Insufficient available assets");
        
        protocolAllocations[protocol][asset] += amount;
        assetStates[asset].totalUtilized += amount;
        protocols[protocol].currentAllocation += amount;
        
        emit AssetAccessed(protocol, asset, amount);
    }
    
    /// @dev Return assets after protocol use
    function returnAssets(address protocol, address asset, uint256 amount, uint256 yield) external onlyRole(PROTOCOL_ROLE) {
        require(protocolAllocations[protocol][asset] >= amount, "Invalid return amount");
        
        protocolAllocations[protocol][asset] -= amount;
        assetStates[asset].totalUtilized -= amount;
        protocols[protocol].currentAllocation -= amount;
        
        // Add yield to total deposited
        if (yield > 0) {
            assetStates[asset].totalDeposited += yield;
        }
        
        emit AssetReturned(protocol, asset, amount);
    }
    
    /// @dev Detect and reallocate idle capital
    function detectAndReallocate(address asset) external onlyRole(KEEPER_ROLE) {
        require(_canRebalance(asset), "Rebalance not needed");
        
        uint256 idleCapital = _calculateIdleCapital(asset);
        if (idleCapital > assetStates[asset].idleThreshold) {
            address bestProtocol = _findBestYieldProtocol(asset);
            if (bestProtocol != address(0)) {
                _reallocateToProtocol(bestProtocol, asset, idleCapital);
                assetStates[asset].lastRebalanceTimestamp = block.timestamp;
                
                emit IdleDetected(asset, idleCapital, bestProtocol);
            }
        }
    }
    
    /// @dev Register new protocol
    function registerProtocol(address protocol, uint256 yieldRate, uint256 maxCapacity) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(protocol != address(0), "Invalid protocol");
        require(!protocols[protocol].isActive, "Protocol already registered");
        
        protocols[protocol] = ProtocolInfo({
            isActive: true,
            yieldRate: yieldRate,
            maxCapacity: maxCapacity,
            currentAllocation: 0
        });
        
        registeredProtocols.push(protocol);
        
        emit ProtocolRegistered(protocol, yieldRate);
    }
    
    /// @dev Add supported asset
    function addSupportedAsset(address asset, uint256 idleThreshold) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(asset != address(0), "Invalid asset");
        require(!_isAssetSupported(asset), "Asset already supported");
        
        supportedAssets.push(asset);
        assetStates[asset].idleThreshold = idleThreshold;
    }
    
    // View functions
    function getTotalLiquidity(address asset) external view returns (uint256) {
        return assetStates[asset].totalDeposited;
    }
    
    function getAvailableLiquidity(address asset) external view returns (uint256) {
        return _getAvailableAssets(asset);
    }
    
    function getUserBalance(address user, address asset) external view returns (uint256) {
        return userBalances[user][asset];
    }
    
    function getProtocolAllocation(address protocol, address asset) external view returns (uint256) {
        return protocolAllocations[protocol][asset];
    }
    
    function getSupportedAssets() external view returns (address[] memory) {
        return supportedAssets;
    }
    
    function getRegisteredProtocols() external view returns (address[] memory) {
        return registeredProtocols;
    }
    
    // Internal functions
    function _autoReallocate(address asset) internal {
        if (_canRebalance(asset)) {
            uint256 idleCapital = _calculateIdleCapital(asset);
            if (idleCapital > assetStates[asset].idleThreshold) {
                address bestProtocol = _findBestYieldProtocol(asset);
                if (bestProtocol != address(0)) {
                    _reallocateToProtocol(bestProtocol, asset, idleCapital / 2); // Partial allocation
                }
            }
        }
    }
    
    function _calculateIdleCapital(address asset) internal view returns (uint256) {
        uint256 total = assetStates[asset].totalDeposited;
        uint256 utilized = assetStates[asset].totalUtilized;
        return total > utilized ? total - utilized : 0;
    }
    
    function _findBestYieldProtocol(address asset) internal view returns (address) {
        uint256 maxYield = 0;
        address bestProtocol = address(0);
        
        for (uint256 i = 0; i < registeredProtocols.length; i++) {
            address protocol = registeredProtocols[i];
            ProtocolInfo memory info = protocols[protocol];
            
            if (info.isActive && info.yieldRate > maxYield && info.currentAllocation < info.maxCapacity) {
                maxYield = info.yieldRate;
                bestProtocol = protocol;
            }
        }
        
        return bestProtocol;
    }
    
    function _reallocateToProtocol(address protocol, address asset, uint256 amount) internal {
        uint256 available = _getAvailableAssets(asset);
        uint256 allocateAmount = amount > available ? available : amount;
        
        if (allocateAmount > 0) {
            protocolAllocations[protocol][asset] += allocateAmount;
            assetStates[asset].totalUtilized += allocateAmount;
            protocols[protocol].currentAllocation += allocateAmount;
            
            emit Reallocated(address(0), protocol, asset, allocateAmount);
        }
    }
    
    function _getAvailableAssets(address asset) internal view returns (uint256) {
        uint256 total = assetStates[asset].totalDeposited;
        uint256 utilized = assetStates[asset].totalUtilized;
        return total > utilized ? total - utilized : 0;
    }
    
    function _canRebalance(address asset) internal view returns (bool) {
        return block.timestamp >= assetStates[asset].lastRebalanceTimestamp + MIN_IDLE_TIME;
    }
    
    function _isAssetSupported(address asset) internal view returns (bool) {
        for (uint256 i = 0; i < supportedAssets.length; i++) {
            if (supportedAssets[i] == asset) {
                return true;
            }
        }
        return false;
    }
    
    // Emergency functions
    function emergencyWithdraw(address asset, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        IERC20(asset).transfer(msg.sender, amount);
    }
    
    function updateProtocolYield(address protocol, uint256 newYieldRate) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(protocols[protocol].isActive, "Protocol not active");
        protocols[protocol].yieldRate = newYieldRate;
    }
    
    function deactivateProtocol(address protocol) external onlyRole(DEFAULT_ADMIN_ROLE) {
        protocols[protocol].isActive = false;
    }
}
