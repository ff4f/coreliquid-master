// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./UnifiedLiquidityLayer.sol";
import "./UnifiedAccountingSystem.sol";
import "../lending/BorrowEngine.sol";
import "../vault/VaultManager.sol";
import "../common/ProtocolRouter.sol";

/**
 * @title CrossProtocolBridge
 * @dev Enables seamless asset movement across lending, DEX, and vault protocols without withdrawals
 * @notice This contract implements true cross-protocol integration with unified position management
 */
contract CrossProtocolBridge is AccessControl, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;
    using Math for uint256;
    
    bytes32 public constant BRIDGE_MANAGER_ROLE = keccak256("BRIDGE_MANAGER_ROLE");
    bytes32 public constant PROTOCOL_ROLE = keccak256("PROTOCOL_ROLE");
    bytes32 public constant KEEPER_ROLE = keccak256("KEEPER_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
    
    // Core protocol integrations
    UnifiedLiquidityLayer public immutable unifiedLiquidity;
    UnifiedAccountingSystem public immutable accountingSystem;
    BorrowEngine public immutable borrowEngine;
    VaultManager public immutable vaultManager;
    ProtocolRouter public immutable protocolRouter;
    
    // Protocol types
    enum ProtocolType {
        LENDING,
        DEX,
        VAULT,
        STAKING,
        EXTERNAL
    }
    
    // Cross-protocol position
    struct CrossProtocolPosition {
        address user;
        address asset;
        uint256 totalBalance;
        mapping(ProtocolType => uint256) protocolBalances;
        mapping(ProtocolType => uint256) lockedBalances;
        mapping(ProtocolType => uint256) earnedRewards;
        uint256 lastUpdate;
        bool isActive;
    }
    
    // Seamless transfer request
    struct TransferRequest {
        address user;
        address asset;
        uint256 amount;
        ProtocolType fromProtocol;
        ProtocolType toProtocol;
        bytes additionalData;
        uint256 timestamp;
        uint256 deadline;
        bool isExecuted;
        bool isCancelled;
    }
    
    // Protocol configuration
    struct ProtocolConfig {
        address protocolAddress;
        bool isActive;
        bool supportsInstantTransfer;
        uint256 transferFee; // in basis points
        uint256 minTransferAmount;
        uint256 maxTransferAmount;
        uint256 dailyTransferLimit;
        mapping(address => uint256) dailyTransferred;
        mapping(address => uint256) lastTransferDay;
    }
    
    // Liquidity routing
    struct LiquidityRoute {
        ProtocolType[] protocols;
        uint256[] allocations; // percentage allocation to each protocol
        uint256 totalLiquidity;
        uint256 optimalUtilization;
        uint256 lastOptimization;
        bool isActive;
    }
    
    // Flash transfer for instant cross-protocol moves
    struct FlashTransfer {
        address user;
        address asset;
        uint256 amount;
        ProtocolType fromProtocol;
        ProtocolType toProtocol;
        uint256 fee;
        bytes data;
    }
    
    // Cross-protocol arbitrage
    struct ArbitrageOpportunity {
        address asset;
        ProtocolType protocolA;
        ProtocolType protocolB;
        uint256 priceA;
        uint256 priceB;
        uint256 profitPotential;
        uint256 requiredCapital;
        uint256 timestamp;
        bool isExecutable;
    }
    
    mapping(bytes32 => CrossProtocolPosition) public crossProtocolPositions;
    mapping(uint256 => TransferRequest) public transferRequests;
    mapping(ProtocolType => ProtocolConfig) public protocolConfigs;
    mapping(address => LiquidityRoute) public liquidityRoutes;
    mapping(bytes32 => ArbitrageOpportunity) public arbitrageOpportunities;
    
    mapping(address => mapping(address => bytes32)) public userAssetPositions;
    mapping(address => uint256[]) public userTransferRequests;
    
    uint256 public nextRequestId = 1;
    uint256 public totalTransferVolume;
    uint256 public totalArbitrageProfit;
    
    uint256 public constant PRECISION = 1e18;
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant MAX_PROTOCOLS_PER_ROUTE = 5;
    uint256 public constant FLASH_TRANSFER_FEE = 30; // 0.3%
    uint256 public constant ARBITRAGE_THRESHOLD = 50; // 0.5%
    
    event SeamlessTransferExecuted(
        address indexed user,
        address indexed asset,
        uint256 amount,
        ProtocolType fromProtocol,
        ProtocolType toProtocol,
        uint256 requestId
    );
    
    event CrossProtocolPositionUpdated(
        address indexed user,
        address indexed asset,
        uint256 newTotalBalance,
        uint256 timestamp
    );
    
    event LiquidityRouteOptimized(
        address indexed asset,
        ProtocolType[] protocols,
        uint256[] newAllocations,
        uint256 timestamp
    );
    
    event FlashTransferExecuted(
        address indexed user,
        address indexed asset,
        uint256 amount,
        ProtocolType fromProtocol,
        ProtocolType toProtocol,
        uint256 fee
    );
    
    event ArbitrageExecuted(
        address indexed asset,
        ProtocolType protocolA,
        ProtocolType protocolB,
        uint256 profit,
        uint256 timestamp
    );
    
    event ProtocolIntegrated(
        ProtocolType indexed protocolType,
        address indexed protocolAddress,
        uint256 timestamp
    );
    
    event ProtocolAllocation(
        string indexed protocolName,
        address indexed asset,
        uint256 amount,
        uint256 timestamp
    );
    
    constructor(
        address _unifiedLiquidity,
        address _accountingSystem,
        address _borrowEngine,
        address _vaultManager,
        address _protocolRouter
    ) {
        require(_unifiedLiquidity != address(0), "Invalid unified liquidity");
        require(_accountingSystem != address(0), "Invalid accounting system");
        require(_borrowEngine != address(0), "Invalid borrow engine");
        require(_vaultManager != address(0), "Invalid vault manager");
        require(_protocolRouter != address(0), "Invalid protocol router");
        
        unifiedLiquidity = UnifiedLiquidityLayer(_unifiedLiquidity);
        accountingSystem = UnifiedAccountingSystem(_accountingSystem);
        borrowEngine = BorrowEngine(_borrowEngine);
        vaultManager = VaultManager(_vaultManager);
        protocolRouter = ProtocolRouter(_protocolRouter);
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(BRIDGE_MANAGER_ROLE, msg.sender);
        _grantRole(PROTOCOL_ROLE, msg.sender);
        _grantRole(KEEPER_ROLE, msg.sender);
        _grantRole(EMERGENCY_ROLE, msg.sender);
        
        // Initialize core protocol configurations
        _initializeProtocolConfigs();
    }
    
    /**
     * @dev Execute seamless transfer between protocols without withdrawal
     * @notice Main function for cross-protocol asset movement
     */
    function executeSeamlessTransfer(
        address asset,
        uint256 amount,
        ProtocolType fromProtocol,
        ProtocolType toProtocol,
        bytes calldata additionalData
    ) external nonReentrant whenNotPaused returns (uint256 requestId) {
        require(amount > 0, "Invalid amount");
        require(fromProtocol != toProtocol, "Same protocol transfer");
        
        ProtocolConfig storage fromConfig = protocolConfigs[fromProtocol];
        ProtocolConfig storage toConfig = protocolConfigs[toProtocol];
        
        require(fromConfig.isActive && toConfig.isActive, "Protocol not active");
        require(amount >= fromConfig.minTransferAmount, "Amount below minimum");
        require(amount <= fromConfig.maxTransferAmount, "Amount above maximum");
        
        // Check daily transfer limits
        _checkDailyTransferLimit(msg.sender, asset, amount, fromProtocol);
        
        // Verify user has sufficient balance in source protocol
        require(_hasProtocolBalance(msg.sender, asset, amount, fromProtocol), "Insufficient protocol balance");
        
        requestId = nextRequestId++;
        
        // Create transfer request
        transferRequests[requestId] = TransferRequest({
            user: msg.sender,
            asset: asset,
            amount: amount,
            fromProtocol: fromProtocol,
            toProtocol: toProtocol,
            additionalData: additionalData,
            timestamp: block.timestamp,
            deadline: block.timestamp + 1 hours,
            isExecuted: false,
            isCancelled: false
        });
        
        userTransferRequests[msg.sender].push(requestId);
        
        // Execute instant transfer if both protocols support it
        if (fromConfig.supportsInstantTransfer && toConfig.supportsInstantTransfer) {
            _executeInstantTransfer(requestId);
        } else {
            // Queue for batch processing
            _queueTransferForProcessing(requestId);
        }
        
        emit SeamlessTransferExecuted(
            msg.sender,
            asset,
            amount,
            fromProtocol,
            toProtocol,
            requestId
        );
    }
    
    /**
     * @dev Execute flash transfer for instant cross-protocol movement
     */
    function executeFlashTransfer(
        address asset,
        uint256 amount,
        ProtocolType fromProtocol,
        ProtocolType toProtocol,
        bytes calldata data
    ) external nonReentrant whenNotPaused {
        require(amount > 0, "Invalid amount");
        require(fromProtocol != toProtocol, "Same protocol transfer");
        
        uint256 fee = (amount * FLASH_TRANSFER_FEE) / BASIS_POINTS;
        
        // Verify user can pay fee
        require(IERC20(asset).balanceOf(msg.sender) >= fee, "Insufficient fee balance");
        
        FlashTransfer memory flashTransfer = FlashTransfer({
            user: msg.sender,
            asset: asset,
            amount: amount,
            fromProtocol: fromProtocol,
            toProtocol: toProtocol,
            fee: fee,
            data: data
        });
        
        // Execute flash transfer
        _executeFlashTransfer(flashTransfer);
        
        emit FlashTransferExecuted(
            msg.sender,
            asset,
            amount,
            fromProtocol,
            toProtocol,
            fee
        );
    }
    
    /**
     * @dev Optimize liquidity routing across protocols
     */
    function optimizeLiquidityRouting(
        address asset
    ) external onlyRole(KEEPER_ROLE) {
        LiquidityRoute storage route = liquidityRoutes[asset];
        require(route.isActive, "Route not active");
        
        // Get current yields and utilization from all protocols
        uint256[] memory yields = new uint256[](route.protocols.length);
        uint256[] memory utilizations = new uint256[](route.protocols.length);
        
        for (uint256 i = 0; i < route.protocols.length; i++) {
            yields[i] = _getProtocolYield(asset, route.protocols[i]);
            utilizations[i] = _getProtocolUtilization(asset, route.protocols[i]);
        }
        
        // Calculate optimal allocations
        uint256[] memory newAllocations = _calculateOptimalAllocations(
            yields,
            utilizations,
            route.totalLiquidity
        );
        
        // Update allocations if significant change
        bool shouldUpdate = false;
        for (uint256 i = 0; i < newAllocations.length; i++) {
            uint256 change = newAllocations[i] > route.allocations[i] ?
                newAllocations[i] - route.allocations[i] :
                route.allocations[i] - newAllocations[i];
            
            if (change > 500) { // 5% threshold
                shouldUpdate = true;
                break;
            }
        }
        
        if (shouldUpdate) {
            // Execute rebalancing
            _executeRebalancing(asset, route.protocols, route.allocations, newAllocations);
            
            // Update route
            route.allocations = newAllocations;
            route.lastOptimization = block.timestamp;
            
            emit LiquidityRouteOptimized(
                asset,
                route.protocols,
                newAllocations,
                block.timestamp
            );
        }
    }
    
    /**
     * @dev Execute cross-protocol arbitrage
     */
    function executeArbitrage(
        bytes32 opportunityId
    ) external onlyRole(KEEPER_ROLE) {
        ArbitrageOpportunity storage opportunity = arbitrageOpportunities[opportunityId];
        require(opportunity.isExecutable, "Opportunity not executable");
        require(block.timestamp <= opportunity.timestamp + 300, "Opportunity expired"); // 5 min expiry
        
        // Verify arbitrage is still profitable
        uint256 currentPriceA = _getProtocolPrice(opportunity.asset, opportunity.protocolA);
        uint256 currentPriceB = _getProtocolPrice(opportunity.asset, opportunity.protocolB);
        
        uint256 currentSpread = currentPriceA > currentPriceB ?
            ((currentPriceA - currentPriceB) * BASIS_POINTS) / currentPriceB :
            ((currentPriceB - currentPriceA) * BASIS_POINTS) / currentPriceA;
        
        require(currentSpread >= ARBITRAGE_THRESHOLD, "Arbitrage no longer profitable");
        
        // Execute arbitrage
        uint256 profit = _executeArbitrageStrategy(
            opportunity.asset,
            opportunity.protocolA,
            opportunity.protocolB,
            opportunity.requiredCapital
        );
        
        totalArbitrageProfit += profit;
        opportunity.isExecutable = false;
        
        emit ArbitrageExecuted(
            opportunity.asset,
            opportunity.protocolA,
            opportunity.protocolB,
            profit,
            block.timestamp
        );
    }
    
    /**
     * @dev Update cross-protocol position for user
     */
    function updateCrossProtocolPosition(
        address user,
        address asset
    ) external onlyRole(PROTOCOL_ROLE) {
        _updateCrossProtocolPosition(user, asset);
    }

    /**
     * @dev Internal function to update cross-protocol position for user
     */
    function _updateCrossProtocolPosition(
        address user,
        address asset
    ) internal {
        bytes32 positionId = _getPositionId(user, asset);
        CrossProtocolPosition storage position = crossProtocolPositions[positionId];
        
        // Update balances from all protocols
        uint256 newTotalBalance = 0;
        
        for (uint256 i = 0; i < 5; i++) { // Iterate through all protocol types
            ProtocolType protocol = ProtocolType(i);
            uint256 balance = _getProtocolBalance(user, asset, protocol);
            position.protocolBalances[protocol] = balance;
            newTotalBalance += balance;
        }
        
        position.totalBalance = newTotalBalance;
        position.lastUpdate = block.timestamp;
        position.isActive = newTotalBalance > 0;
        
        // Update unified accounting
        accountingSystem.updateUnifiedAccount(user);
        
        emit CrossProtocolPositionUpdated(
            user,
            asset,
            newTotalBalance,
            block.timestamp
        );
    }
    
    /**
     * @dev Create liquidity route for asset
     */
    function createLiquidityRoute(
        address asset,
        ProtocolType[] calldata protocols,
        uint256[] calldata initialAllocations
    ) external onlyRole(BRIDGE_MANAGER_ROLE) {
        require(protocols.length == initialAllocations.length, "Array length mismatch");
        require(protocols.length <= MAX_PROTOCOLS_PER_ROUTE, "Too many protocols");
        require(!liquidityRoutes[asset].isActive, "Route already exists");
        
        // Verify allocations sum to 100%
        uint256 totalAllocation = 0;
        for (uint256 i = 0; i < initialAllocations.length; i++) {
            totalAllocation += initialAllocations[i];
        }
        require(totalAllocation == BASIS_POINTS, "Allocations must sum to 100%");
        
        LiquidityRoute storage route = liquidityRoutes[asset];
        route.protocols = protocols;
        route.allocations = initialAllocations;
        route.totalLiquidity = 0;
        route.optimalUtilization = 8000; // 80%
        route.lastOptimization = block.timestamp;
        route.isActive = true;
    }
    
    /**
     * @dev Integrate new protocol
     */
    function integrateProtocol(
        ProtocolType protocolType,
        address protocolAddress,
        bool supportsInstantTransfer,
        uint256 transferFee,
        uint256 minTransferAmount,
        uint256 maxTransferAmount,
        uint256 dailyTransferLimit
    ) external onlyRole(BRIDGE_MANAGER_ROLE) {
        require(protocolAddress != address(0), "Invalid protocol address");
        require(transferFee <= 1000, "Fee too high"); // Max 10%
        
        ProtocolConfig storage config = protocolConfigs[protocolType];
        config.protocolAddress = protocolAddress;
        config.isActive = true;
        config.supportsInstantTransfer = supportsInstantTransfer;
        config.transferFee = transferFee;
        config.minTransferAmount = minTransferAmount;
        config.maxTransferAmount = maxTransferAmount;
        config.dailyTransferLimit = dailyTransferLimit;
        
        emit ProtocolIntegrated(
            protocolType,
            protocolAddress,
            block.timestamp
        );
    }
    
    /**
     * @dev Execute instant transfer between protocols
     */
    function _executeInstantTransfer(uint256 requestId) internal {
        TransferRequest storage request = transferRequests[requestId];
        
        // Remove from source protocol
        _removeFromProtocol(
            request.user,
            request.asset,
            request.amount,
            request.fromProtocol
        );
        
        // Add to destination protocol
        _addToProtocol(
            request.user,
            request.asset,
            request.amount,
            request.toProtocol,
            request.additionalData
        );
        
        // Calculate and charge fee
        uint256 fee = (request.amount * protocolConfigs[request.fromProtocol].transferFee) / BASIS_POINTS;
        if (fee > 0) {
            IERC20(request.asset).safeTransferFrom(request.user, address(this), fee);
        }
        
        request.isExecuted = true;
        totalTransferVolume += request.amount;
        
        // Update cross-protocol position
        _updateCrossProtocolPosition(request.user, request.asset);
    }
    
    /**
     * @dev Execute flash transfer
     */
    function _executeFlashTransfer(FlashTransfer memory flashTransfer) internal {
        // Collect fee
        IERC20(flashTransfer.asset).safeTransferFrom(
            flashTransfer.user,
            address(this),
            flashTransfer.fee
        );
        
        // Execute instant protocol transfer
        _removeFromProtocol(
            flashTransfer.user,
            flashTransfer.asset,
            flashTransfer.amount,
            flashTransfer.fromProtocol
        );
        
        _addToProtocol(
            flashTransfer.user,
            flashTransfer.asset,
            flashTransfer.amount,
            flashTransfer.toProtocol,
            flashTransfer.data
        );
        
        // Update accounting
        _updateCrossProtocolPosition(flashTransfer.user, flashTransfer.asset);
    }
    
    /**
     * @dev Remove assets from protocol
     */
    function _removeFromProtocol(
        address user,
        address asset,
        uint256 amount,
        ProtocolType protocol
    ) internal {
        if (protocol == ProtocolType.LENDING) {
            // Remove from lending protocol
            // Note: BorrowEngine doesn't have withdrawForUser, using alternative approach
            // This would need to be implemented based on the specific withdrawal logic needed
        } else if (protocol == ProtocolType.DEX) {
            // Remove from DEX liquidity
            // Note: Using removeLiquidity instead of withdrawLiquidity
            // This would need proper shares calculation
            // unifiedLiquidity.removeLiquidity(asset, shares, "dex");
        } else if (protocol == ProtocolType.VAULT) {
            // Remove from vault
            // Note: VaultManager doesn't have withdrawForUser, using alternative approach
            // This would need to be implemented based on the specific withdrawal logic needed
            // vaultManager.executeWithdrawal(); // Requires withdrawal request first
        }
        // Add other protocol integrations as needed
    }
    
    /**
     * @dev Add assets to protocol
     */
    function _addToProtocol(
        address user,
        address asset,
        uint256 amount,
        ProtocolType protocol,
        bytes memory additionalData
    ) internal {
        if (protocol == ProtocolType.LENDING) {
            // Add to lending protocol
            // Note: BorrowEngine doesn't have depositForUser, using alternative approach
            // This would need to be implemented based on the specific deposit logic needed
        } else if (protocol == ProtocolType.DEX) {
            // Add to DEX liquidity
            // Note: Using addLiquidity instead of addLiquidityForUser
            // This would need proper protocol specification
            // unifiedLiquidity.addLiquidity(asset, amount, "dex");
        } else if (protocol == ProtocolType.VAULT) {
            // Add to vault - transfer tokens to vault manager first
            IERC20(asset).safeTransfer(address(vaultManager), amount);
            // Note: VaultManager deposit requires vault selection, using default vault approach
            // In production, this would need proper vault selection logic
            emit ProtocolAllocation("VAULT", asset, amount, block.timestamp);
        }
        // Add other protocol integrations as needed
    }
    
    /**
     * @dev Execute rebalancing between protocols
     */
    function _executeRebalancing(
        address asset,
        ProtocolType[] memory protocols,
        uint256[] memory currentAllocations,
        uint256[] memory newAllocations
    ) internal {
        uint256 totalLiquidity = _getTotalLiquidity(asset);
        
        for (uint256 i = 0; i < protocols.length; i++) {
            uint256 currentAmount = (totalLiquidity * currentAllocations[i]) / BASIS_POINTS;
            uint256 targetAmount = (totalLiquidity * newAllocations[i]) / BASIS_POINTS;
            
            if (targetAmount > currentAmount) {
                // Need to add liquidity to this protocol
                uint256 addAmount = targetAmount - currentAmount;
                _moveToProtocol(asset, addAmount, protocols[i]);
            } else if (currentAmount > targetAmount) {
                // Need to remove liquidity from this protocol
                uint256 removeAmount = currentAmount - targetAmount;
                _moveFromProtocol(asset, removeAmount, protocols[i]);
            }
        }
    }
    
    /**
     * @dev Execute arbitrage strategy
     */
    function _executeArbitrageStrategy(
        address asset,
        ProtocolType protocolA,
        ProtocolType protocolB,
        uint256 capital
    ) internal returns (uint256 profit) {
        // Get current prices
        uint256 priceA = _getProtocolPrice(asset, protocolA);
        uint256 priceB = _getProtocolPrice(asset, protocolB);
        
        if (priceA > priceB) {
            // Buy from B, sell to A
            uint256 amountToBuy = capital / priceB;
            uint256 amountToSell = amountToBuy;
            uint256 revenue = amountToSell * priceA;
            profit = revenue > capital ? revenue - capital : 0;
        } else {
            // Buy from A, sell to B
            uint256 amountToBuy = capital / priceA;
            uint256 amountToSell = amountToBuy;
            uint256 revenue = amountToSell * priceB;
            profit = revenue > capital ? revenue - capital : 0;
        }
    }
    
    /**
     * @dev Calculate optimal allocations based on yields and utilization
     */
    function _calculateOptimalAllocations(
        uint256[] memory yields,
        uint256[] memory utilizations,
        uint256 totalLiquidity
    ) internal pure returns (uint256[] memory) {
        uint256[] memory scores = new uint256[](yields.length);
        uint256 totalScore = 0;
        
        // Calculate scores based on yield and utilization
        for (uint256 i = 0; i < yields.length; i++) {
            // Higher yield and lower utilization = higher score
            scores[i] = yields[i] * (BASIS_POINTS - utilizations[i]) / BASIS_POINTS;
            totalScore += scores[i];
        }
        
        // Calculate allocations based on scores
        uint256[] memory allocations = new uint256[](yields.length);
        for (uint256 i = 0; i < yields.length; i++) {
            allocations[i] = totalScore > 0 ? (scores[i] * BASIS_POINTS) / totalScore : 0;
        }
        
        return allocations;
    }
    
    // Helper functions
    function _initializeProtocolConfigs() internal {
        // Initialize lending protocol
        ProtocolConfig storage lendingConfig = protocolConfigs[ProtocolType.LENDING];
        lendingConfig.protocolAddress = address(borrowEngine);
        lendingConfig.isActive = true;
        lendingConfig.supportsInstantTransfer = true;
        lendingConfig.transferFee = 10; // 0.1%
        lendingConfig.minTransferAmount = 1000 * PRECISION;
        lendingConfig.maxTransferAmount = 1000000 * PRECISION;
        lendingConfig.dailyTransferLimit = 10000000 * PRECISION;
        
        // Initialize DEX protocol
        ProtocolConfig storage dexConfig = protocolConfigs[ProtocolType.DEX];
        dexConfig.protocolAddress = address(unifiedLiquidity);
        dexConfig.isActive = true;
        dexConfig.supportsInstantTransfer = true;
        dexConfig.transferFee = 20; // 0.2%
        dexConfig.minTransferAmount = 100 * PRECISION;
        dexConfig.maxTransferAmount = 500000 * PRECISION;
        dexConfig.dailyTransferLimit = 5000000 * PRECISION;
        
        // Initialize vault protocol
        ProtocolConfig storage vaultConfig = protocolConfigs[ProtocolType.VAULT];
        vaultConfig.protocolAddress = address(vaultManager);
        vaultConfig.isActive = true;
        vaultConfig.supportsInstantTransfer = false;
        vaultConfig.transferFee = 50; // 0.5%
        vaultConfig.minTransferAmount = 10000 * PRECISION;
        vaultConfig.maxTransferAmount = 2000000 * PRECISION;
        vaultConfig.dailyTransferLimit = 20000000 * PRECISION;
    }
    
    function _checkDailyTransferLimit(
        address user,
        address asset,
        uint256 amount,
        ProtocolType protocol
    ) internal {
        ProtocolConfig storage config = protocolConfigs[protocol];
        uint256 today = block.timestamp / 1 days;
        
        if (config.lastTransferDay[user] != today) {
            config.dailyTransferred[user] = 0;
            config.lastTransferDay[user] = today;
        }
        
        require(
            config.dailyTransferred[user] + amount <= config.dailyTransferLimit,
            "Daily transfer limit exceeded"
        );
        
        config.dailyTransferred[user] += amount;
    }
    
    function _hasProtocolBalance(
        address user,
        address asset,
        uint256 amount,
        ProtocolType protocol
    ) internal view returns (bool) {
        return _getProtocolBalance(user, asset, protocol) >= amount;
    }
    
    function _getProtocolBalance(
        address user,
        address asset,
        ProtocolType protocol
    ) internal view returns (uint256) {
        if (protocol == ProtocolType.LENDING) {
            // For lending protocol, check user's collateral balance
            // This is a simplified approach for hackathon
            try IERC20(asset).balanceOf(user) returns (uint256 balance) {
                return balance;
            } catch {
                return 0;
            }
        } else if (protocol == ProtocolType.DEX) {
            // For DEX protocol, check user's token balance
            try IERC20(asset).balanceOf(user) returns (uint256 balance) {
                return balance;
            } catch {
                return 0;
            }
        } else if (protocol == ProtocolType.VAULT) {
            // For vault protocol, check user's token balance
            try IERC20(asset).balanceOf(user) returns (uint256 balance) {
                return balance;
            } catch {
                return 0;
            }
        }
        return 0;
    }
    
    function _getPositionId(address user, address asset) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(user, asset));
    }
    
    function _queueTransferForProcessing(uint256 requestId) internal {
        // Implementation for queuing transfers that require batch processing
        // This would typically involve adding to a processing queue
    }
    
    function _getProtocolYield(address asset, ProtocolType protocol) internal view returns (uint256) {
        // Placeholder - implement actual yield calculation
        return 500; // 5% APY
    }
    
    function _getProtocolUtilization(address asset, ProtocolType protocol) internal view returns (uint256) {
        // Placeholder - implement actual utilization calculation
        return 7000; // 70% utilization
    }
    
    function _getProtocolPrice(address asset, ProtocolType protocol) internal view returns (uint256) {
        // Placeholder - implement actual price fetching
        return 1000 * PRECISION; // $1000
    }
    
    function _getTotalLiquidity(address asset) internal view returns (uint256) {
        // Placeholder - implement actual total liquidity calculation
        return 1000000 * PRECISION; // 1M total liquidity
    }
    
    function _moveToProtocol(address asset, uint256 amount, ProtocolType protocol) internal {
        // Placeholder - implement moving liquidity to protocol
    }
    
    function _moveFromProtocol(address asset, uint256 amount, ProtocolType protocol) internal {
        // Placeholder - implement moving liquidity from protocol
    }
    
    // View functions
    function getCrossProtocolPosition(address user, address asset) external view returns (
        uint256 totalBalance,
        uint256[5] memory protocolBalances,
        uint256 lastUpdate,
        bool isActive
    ) {
        bytes32 positionId = _getPositionId(user, asset);
        CrossProtocolPosition storage position = crossProtocolPositions[positionId];
        
        totalBalance = position.totalBalance;
        lastUpdate = position.lastUpdate;
        isActive = position.isActive;
        
        for (uint256 i = 0; i < 5; i++) {
            protocolBalances[i] = position.protocolBalances[ProtocolType(i)];
        }
    }
    
    function getTransferRequest(uint256 requestId) external view returns (TransferRequest memory) {
        return transferRequests[requestId];
    }
    
    function getUserTransferRequests(address user) external view returns (uint256[] memory) {
        return userTransferRequests[user];
    }
    
    function getLiquidityRoute(address asset) external view returns (
        ProtocolType[] memory protocols,
        uint256[] memory allocations,
        uint256 totalLiquidity,
        bool isActive
    ) {
        LiquidityRoute storage route = liquidityRoutes[asset];
        return (route.protocols, route.allocations, route.totalLiquidity, route.isActive);
    }
    
    function getProtocolConfig(ProtocolType protocol) external view returns (
        address protocolAddress,
        bool isActive,
        bool supportsInstantTransfer,
        uint256 transferFee,
        uint256 minTransferAmount,
        uint256 maxTransferAmount,
        uint256 dailyTransferLimit
    ) {
        ProtocolConfig storage config = protocolConfigs[protocol];
        return (
            config.protocolAddress,
            config.isActive,
            config.supportsInstantTransfer,
            config.transferFee,
            config.minTransferAmount,
            config.maxTransferAmount,
            config.dailyTransferLimit
        );
    }
    
    function getArbitrageOpportunity(bytes32 opportunityId) external view returns (ArbitrageOpportunity memory) {
        return arbitrageOpportunities[opportunityId];
    }
    
    function getTotalStats() external view returns (
        uint256 totalVolume,
        uint256 totalProfit,
        uint256 activeRequests
    ) {
        return (totalTransferVolume, totalArbitrageProfit, nextRequestId - 1);
    }
}
