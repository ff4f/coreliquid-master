// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title Simple True Unified Liquidity Layer
 * @dev Simplified version for hackathon demo
 */
contract SimpleTULL is AccessControl, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    bytes32 public constant PROTOCOL_ROLE = keccak256("PROTOCOL_ROLE");
    bytes32 public constant KEEPER_ROLE = keccak256("KEEPER_ROLE");

    struct AssetState {
        uint256 totalLiquidity;
        uint256 availableLiquidity;
        bool isActive;
    }

    struct ProtocolInfo {
        string name;
        uint256 apy;
        uint256 capacity;
        uint256 allocated;
        bool isActive;
    }

    // Storage
    mapping(address => AssetState) public assetStates;
    mapping(address => bool) public supportedAssets;
    mapping(address => mapping(address => uint256)) public userBalances;
    mapping(address => ProtocolInfo) public protocols;
    address[] public assetList;
    address[] public protocolList;
    address public treasury;

    // Events
    event AssetDeposited(address indexed user, address indexed asset, uint256 amount);
    event AssetWithdrawn(address indexed user, address indexed asset, uint256 amount);
    event ProtocolRegistered(address indexed protocol, string name);
    event LiquidityAllocated(address indexed protocol, address indexed asset, uint256 amount);

    constructor(address _treasury) {
        require(_treasury != address(0), "Invalid treasury");
        treasury = _treasury;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(KEEPER_ROLE, msg.sender);
    }

    // Core Functions
    function addSupportedAsset(address asset) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(asset != address(0), "Invalid asset");
        require(!supportedAssets[asset], "Already supported");
        
        supportedAssets[asset] = true;
        assetStates[asset].isActive = true;
        assetList.push(asset);
    }

    function deposit(address asset, uint256 amount, address user) 
        external 
        onlyRole(PROTOCOL_ROLE) 
        nonReentrant 
        whenNotPaused 
    {
        require(supportedAssets[asset], "Asset not supported");
        require(amount > 0, "Invalid amount");
        
        IERC20(asset).safeTransferFrom(user, address(this), amount);
        
        userBalances[user][asset] += amount;
        assetStates[asset].totalLiquidity += amount;
        assetStates[asset].availableLiquidity += amount;
        
        emit AssetDeposited(user, asset, amount);
    }

    function withdraw(address asset, uint256 amount, address user) 
        external 
        onlyRole(PROTOCOL_ROLE) 
        nonReentrant 
        whenNotPaused 
    {
        require(supportedAssets[asset], "Asset not supported");
        require(amount > 0, "Invalid amount");
        require(userBalances[user][asset] >= amount, "Insufficient balance");
        require(assetStates[asset].availableLiquidity >= amount, "Insufficient liquidity");
        
        userBalances[user][asset] -= amount;
        assetStates[asset].totalLiquidity -= amount;
        assetStates[asset].availableLiquidity -= amount;
        
        IERC20(asset).safeTransfer(user, amount);
        
        emit AssetWithdrawn(user, asset, amount);
    }

    function registerProtocol(
        address protocol,
        string memory name,
        uint256 apy,
        uint256 capacity
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(protocol != address(0), "Invalid protocol");
        require(!protocols[protocol].isActive, "Already registered");
        
        protocols[protocol] = ProtocolInfo({
            name: name,
            apy: apy,
            capacity: capacity,
            allocated: 0,
            isActive: true
        });
        
        protocolList.push(protocol);
        _grantRole(PROTOCOL_ROLE, protocol);
        
        emit ProtocolRegistered(protocol, name);
    }

    function allocateToProtocol(
        address protocol,
        address asset,
        uint256 amount
    ) external onlyRole(KEEPER_ROLE) {
        require(protocols[protocol].isActive, "Protocol not active");
        require(supportedAssets[asset], "Asset not supported");
        require(assetStates[asset].availableLiquidity >= amount, "Insufficient liquidity");
        require(protocols[protocol].allocated + amount <= protocols[protocol].capacity, "Exceeds capacity");
        
        assetStates[asset].availableLiquidity -= amount;
        protocols[protocol].allocated += amount;
        
        IERC20(asset).safeTransfer(protocol, amount);
        
        emit LiquidityAllocated(protocol, asset, amount);
    }

    // View Functions
    function getTotalLiquidity(address asset) external view returns (uint256) {
        return assetStates[asset].totalLiquidity;
    }

    function getAvailableLiquidity(address asset) external view returns (uint256) {
        return assetStates[asset].availableLiquidity;
    }

    function getUserBalance(address user, address asset) external view returns (uint256) {
        return userBalances[user][asset];
    }

    function getProtocolInfo(address protocol) external view returns (ProtocolInfo memory) {
        return protocols[protocol];
    }

    function getSupportedAssets() external view returns (address[] memory) {
        return assetList;
    }

    function getRegisteredProtocols() external view returns (address[] memory) {
        return protocolList;
    }

    // Admin Functions
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    function setTreasury(address _treasury) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_treasury != address(0), "Invalid treasury");
        treasury = _treasury;
    }

    function emergencyWithdraw(address asset, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        IERC20(asset).safeTransfer(treasury, amount);
    }
}
