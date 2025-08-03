// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./UnifiedLiquidityLayer.sol";
import "../lending/BorrowEngine.sol";
// removed wrong import of ../MainLiquidityPool.sol
import "../vault/VaultManager.sol";
import "./MainLiquidityPool.sol";

/**
 * @title UnifiedAccountingSystem
 * @dev Unified accounting layer that tracks user positions across lending, borrowing, and DEX activities
 * @notice This contract implements the missing unified accounting system that was identified in the gap analysis
 */
contract UnifiedAccountingSystem is AccessControl, ReentrancyGuard {
    using Math for uint256;
    
    bytes32 public constant ACCOUNTING_MANAGER_ROLE = keccak256("ACCOUNTING_MANAGER_ROLE");
    bytes32 public constant PROTOCOL_ROLE = keccak256("PROTOCOL_ROLE");
    bytes32 public constant KEEPER_ROLE = keccak256("KEEPER_ROLE");
    
    // Protocol integrations
    UnifiedLiquidityLayer public immutable unifiedLiquidity;
    BorrowEngine public immutable borrowEngine;
    MainLiquidityPool public immutable liquidityPool;
    VaultManager public immutable vaultManager;
    
    // Unified account structure
    struct UnifiedAccount {
        uint256 totalNetWorth;
        uint256 totalAssets;
        uint256 totalLiabilities;
        uint256 totalCollateral;
        uint256 availableLiquidity;
        uint256 lockedLiquidity;
        uint256 healthFactor;
        uint256 borrowingPower;
        uint256 lastUpdate;
        bool isActive;
    }
    
    // Cross-protocol position tracking
    struct CrossProtocolPosition {
        // Lending positions
        uint256 lendingDeposits;
        uint256 lendingEarned;
        uint256 borrowedAmount;
        uint256 borrowInterest;
        
        // DEX positions
        uint256 dexLiquidity;
        uint256 dexFees;
        uint256 impermanentLoss;
        
        // Vault positions
        uint256 vaultShares;
        uint256 vaultValue;
        uint256 vaultRewards;
        
        // Staking positions
        uint256 stakedAmount;
        uint256 stakingRewards;
        uint256 unbondingAmount;
        
        uint256 lastSync;
    }
    
    // Asset-specific accounting
    struct AssetAccount {
        uint256 totalBalance;
        uint256 availableBalance;
        uint256 lockedBalance;
        uint256 earnedRewards;
        uint256 paidFees;
        mapping(string => uint256) protocolBalances; // protocol name => balance
        mapping(string => uint256) protocolRewards; // protocol name => rewards
        bool isCollateral;
        uint256 collateralFactor;
    }
    
    // Real-time position tracking
    struct PositionSnapshot {
        uint256 timestamp;
        uint256 totalValue;
        uint256 pnl;
        uint256 apy;
        uint256 riskScore;
        string[] activeProtocols;
    }
    
    // Cross-protocol transaction tracking
    struct CrossProtocolTransaction {
        uint256 txId;
        address user;
        string fromProtocol;
        string toProtocol;
        address asset;
        uint256 amount;
        uint256 timestamp;
        string txType; // "deposit", "withdraw", "swap", "borrow", "repay"
        bool isCompleted;
    }
    
    mapping(address => UnifiedAccount) public unifiedAccounts;
    mapping(address => CrossProtocolPosition) public crossProtocolPositions;
    mapping(address => mapping(address => AssetAccount)) public assetAccounts; // user => asset => account
    mapping(address => PositionSnapshot[]) public positionHistory;
    mapping(uint256 => CrossProtocolTransaction) public crossProtocolTxs;
    mapping(address => uint256[]) public userTransactions;
    
    uint256 public nextTxId = 1;
    uint256 public constant PRECISION = 1e18;
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant MIN_HEALTH_FACTOR = 11e17; // 110%
    
    // Supported protocols
    string[] public supportedProtocols = ["lending", "dex", "vault", "staking"];
    mapping(string => bool) public isProtocolSupported;
    
    event AccountUpdated(
        address indexed user,
        uint256 totalNetWorth,
        uint256 healthFactor,
        uint256 timestamp
    );
    
    event CrossProtocolTransfer(
        address indexed user,
        string fromProtocol,
        string toProtocol,
        address asset,
        uint256 amount,
        uint256 txId
    );
    
    event PositionSynced(
        address indexed user,
        string protocol,
        uint256 newBalance,
        uint256 timestamp
    );
    
    event RiskAlert(
        address indexed user,
        uint256 healthFactor,
        string alertType,
        uint256 timestamp
    );
    
    constructor(
        address _unifiedLiquidity,
        address _borrowEngine,
        address _liquidityPool,
        address _vaultManager
    ) {
        require(_unifiedLiquidity != address(0), "Invalid unified liquidity");
        require(_borrowEngine != address(0), "Invalid borrow engine");
        require(_liquidityPool != address(0), "Invalid liquidity pool");
        require(_vaultManager != address(0), "Invalid vault manager");
        
        unifiedLiquidity = UnifiedLiquidityLayer(_unifiedLiquidity);
        borrowEngine = BorrowEngine(_borrowEngine);
        liquidityPool = MainLiquidityPool(_liquidityPool);
        vaultManager = VaultManager(_vaultManager);
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ACCOUNTING_MANAGER_ROLE, msg.sender);
        _grantRole(PROTOCOL_ROLE, msg.sender);
        _grantRole(KEEPER_ROLE, msg.sender);
        
        // Initialize supported protocols
        for (uint256 i = 0; i < supportedProtocols.length; i++) {
            isProtocolSupported[supportedProtocols[i]] = true;
        }
    }
    
    /**
     * @dev Update user account across all protocols
     * @notice This is the core function that implements unified accounting
     */
    function updateUnifiedAccount(address user) external onlyRole(PROTOCOL_ROLE) {
        _syncAllProtocolPositions(user);
        _calculateUnifiedMetrics(user);
        _checkRiskLevels(user);
        _createPositionSnapshot(user);
    }
    
    /**
     * @dev Execute cross-protocol transfer without withdrawal
     * @notice Enables seamless asset movement between protocols
     */
    function executeCrossProtocolTransfer(
        address user,
        string memory fromProtocol,
        string memory toProtocol,
        address asset,
        uint256 amount
    ) external onlyRole(PROTOCOL_ROLE) returns (uint256 txId) {
        require(isProtocolSupported[fromProtocol], "From protocol not supported");
        require(isProtocolSupported[toProtocol], "To protocol not supported");
        require(amount > 0, "Invalid amount");
        
        // Check if user has sufficient balance in source protocol
        require(
            _getProtocolBalance(user, asset, fromProtocol) >= amount,
            "Insufficient balance in source protocol"
        );
        
        txId = nextTxId++;
        
        // Create transaction record
        crossProtocolTxs[txId] = CrossProtocolTransaction({
            txId: txId,
            user: user,
            fromProtocol: fromProtocol,
            toProtocol: toProtocol,
            asset: asset,
            amount: amount,
            timestamp: block.timestamp,
            txType: "transfer",
            isCompleted: false
        });
        
        userTransactions[user].push(txId);
        
        // Execute the transfer
        _executeProtocolTransfer(user, fromProtocol, toProtocol, asset, amount);
        
        // Mark as completed
        crossProtocolTxs[txId].isCompleted = true;
        
        // Update accounting
        _updateAssetAccount(user, asset, fromProtocol, toProtocol, amount);
        _syncAllProtocolPositions(user);
        _calculateUnifiedMetrics(user);
        
        emit CrossProtocolTransfer(user, fromProtocol, toProtocol, asset, amount, txId);
    }
    
    /**
     * @dev Sync positions across all protocols for a user
     */
    function _syncAllProtocolPositions(address user) internal {
        CrossProtocolPosition storage position = crossProtocolPositions[user];
        
        // Sync lending positions
        (position.lendingDeposits, position.lendingEarned) = _getLendingPosition(user);
        (position.borrowedAmount, position.borrowInterest) = _getBorrowPosition(user);
        
        // Sync DEX positions
        (position.dexLiquidity, position.dexFees, position.impermanentLoss) = _getDexPosition(user);
        
        // Sync vault positions
        (position.vaultShares, position.vaultValue, position.vaultRewards) = _getVaultPosition(user);
        
        // Sync staking positions
        (position.stakedAmount, position.stakingRewards, position.unbondingAmount) = _getStakingPosition(user);
        
        position.lastSync = block.timestamp;
        
        emit PositionSynced(user, "all", 0, block.timestamp);
    }
    
    /**
     * @dev Calculate unified metrics for user account
     */
    function _calculateUnifiedMetrics(address user) internal {
        UnifiedAccount storage account = unifiedAccounts[user];
        CrossProtocolPosition storage position = crossProtocolPositions[user];
        
        // Calculate total assets
        uint256 totalAssets = position.lendingDeposits +
                             position.lendingEarned +
                             position.dexLiquidity +
                             position.dexFees +
                             position.vaultValue +
                             position.vaultRewards +
                             position.stakedAmount +
                             position.stakingRewards;
        
        // Calculate total liabilities
        uint256 totalLiabilities = position.borrowedAmount +
                                  position.borrowInterest +
                                  position.impermanentLoss;
        
        // Calculate net worth
        uint256 totalNetWorth = totalAssets > totalLiabilities ? 
                               totalAssets - totalLiabilities : 0;
        
        // Calculate collateral value
        uint256 totalCollateral = _calculateTotalCollateralValue(user);
        
        // Calculate health factor
        uint256 healthFactor = totalLiabilities > 0 ?
                              (totalCollateral * PRECISION) / totalLiabilities :
                              type(uint256).max;
        
        // Calculate borrowing power
        uint256 borrowingPower = _calculateBorrowingPower(user, totalCollateral);
        
        // Update account
        account.totalNetWorth = totalNetWorth;
        account.totalAssets = totalAssets;
        account.totalLiabilities = totalLiabilities;
        account.totalCollateral = totalCollateral;
        account.healthFactor = healthFactor;
        account.borrowingPower = borrowingPower;
        account.lastUpdate = block.timestamp;
        account.isActive = totalAssets > 0 || totalLiabilities > 0;
        
        emit AccountUpdated(user, totalNetWorth, healthFactor, block.timestamp);
    }
    
    /**
     * @dev Check risk levels and emit alerts if necessary
     */
    function _checkRiskLevels(address user) internal {
        UnifiedAccount storage account = unifiedAccounts[user];
        
        if (account.healthFactor < MIN_HEALTH_FACTOR && account.totalLiabilities > 0) {
            emit RiskAlert(user, account.healthFactor, "LOW_HEALTH_FACTOR", block.timestamp);
        }
        
        // Check for high concentration risk
        uint256 maxProtocolExposure = _getMaxProtocolExposure(user);
        if (maxProtocolExposure > 8000) { // 80%
            emit RiskAlert(user, maxProtocolExposure, "HIGH_CONCENTRATION", block.timestamp);
        }
    }
    
    /**
     * @dev Create position snapshot for historical tracking
     */
    function _createPositionSnapshot(address user) internal {
        UnifiedAccount storage account = unifiedAccounts[user];
        
        // Calculate PnL and APY
        uint256 pnl = _calculatePnL(user);
        uint256 apy = _calculateAPY(user);
        uint256 riskScore = _calculateRiskScore(user);
        
        PositionSnapshot memory snapshot = PositionSnapshot({
            timestamp: block.timestamp,
            totalValue: account.totalNetWorth,
            pnl: pnl,
            apy: apy,
            riskScore: riskScore,
            activeProtocols: _getActiveProtocols(user)
        });
        
        positionHistory[user].push(snapshot);
        
        // Keep only last 100 snapshots
        if (positionHistory[user].length > 100) {
            // Remove oldest snapshot
            for (uint256 i = 0; i < positionHistory[user].length - 1; i++) {
                positionHistory[user][i] = positionHistory[user][i + 1];
            }
            positionHistory[user].pop();
        }
    }
    
    /**
     * @dev Execute transfer between protocols
     */
    function _executeProtocolTransfer(
        address user,
        string memory fromProtocol,
        string memory toProtocol,
        address asset,
        uint256 amount
    ) internal {
        // Withdraw from source protocol
        if (keccak256(bytes(fromProtocol)) == keccak256(bytes("lending"))) {
            _withdrawFromLending(user, asset, amount);
        } else if (keccak256(bytes(fromProtocol)) == keccak256(bytes("dex"))) {
            _withdrawFromDex(user, asset, amount);
        } else if (keccak256(bytes(fromProtocol)) == keccak256(bytes("vault"))) {
            _withdrawFromVault(user, asset, amount);
        } else if (keccak256(bytes(fromProtocol)) == keccak256(bytes("staking"))) {
            _withdrawFromStaking(user, asset, amount);
        }
        
        // Deposit to target protocol
        if (keccak256(bytes(toProtocol)) == keccak256(bytes("lending"))) {
            _depositToLending(user, asset, amount);
        } else if (keccak256(bytes(toProtocol)) == keccak256(bytes("dex"))) {
            _depositToDex(user, asset, amount);
        } else if (keccak256(bytes(toProtocol)) == keccak256(bytes("vault"))) {
            _depositToVault(user, asset, amount);
        } else if (keccak256(bytes(toProtocol)) == keccak256(bytes("staking"))) {
            _depositToStaking(user, asset, amount);
        }
    }
    
    /**
     * @dev Update asset account after transfer
     */
    function _updateAssetAccount(
        address user,
        address asset,
        string memory fromProtocol,
        string memory toProtocol,
        uint256 amount
    ) internal {
        AssetAccount storage assetAccount = assetAccounts[user][asset];
        
        // Update protocol balances
        assetAccount.protocolBalances[fromProtocol] -= amount;
        assetAccount.protocolBalances[toProtocol] += amount;
    }
    
    // Protocol interaction functions (placeholders - implement based on actual interfaces)
    function _getLendingPosition(address user) internal view returns (uint256 deposits, uint256 earned) {
        // Get lending position from BorrowEngine
        return (0, 0); // Placeholder
    }
    
    function _getBorrowPosition(address user) internal view returns (uint256 borrowed, uint256 interest) {
        // Get borrow position from BorrowEngine
        return (0, 0); // Placeholder
    }
    
    function _getDexPosition(address user) internal view returns (uint256 liquidity, uint256 fees, uint256 il) {
        // Get DEX position from MainLiquidityPool
        return (0, 0, 0); // Placeholder
    }
    
    function _getVaultPosition(address user) internal view returns (uint256 shares, uint256 value, uint256 rewards) {
        // Get vault position from VaultManager
        return (0, 0, 0); // Placeholder
    }
    
    function _getStakingPosition(address user) internal view returns (uint256 staked, uint256 rewards, uint256 unbonding) {
        // Get staking position
        return (0, 0, 0); // Placeholder
    }
    
    function _getProtocolBalance(address user, address asset, string memory protocol) internal view returns (uint256) {
        return assetAccounts[user][asset].protocolBalances[protocol];
    }
    
    function _calculateTotalCollateralValue(address user) internal view returns (uint256) {
        // Calculate total collateral value across all assets and protocols
        return 0; // Placeholder
    }
    
    function _calculateBorrowingPower(address user, uint256 collateralValue) internal view returns (uint256) {
        // Calculate borrowing power based on collateral
        return (collateralValue * 8000) / BASIS_POINTS; // 80% LTV
    }
    
    function _getMaxProtocolExposure(address user) internal view returns (uint256) {
        // Calculate maximum exposure to any single protocol
        return 0; // Placeholder
    }
    
    function _calculatePnL(address user) internal view returns (uint256) {
        // Calculate profit and loss
        return 0; // Placeholder
    }
    
    function _calculateAPY(address user) internal view returns (uint256) {
        // Calculate annualized percentage yield
        return 0; // Placeholder
    }
    
    function _calculateRiskScore(address user) internal view returns (uint256) {
        // Calculate risk score (0-100)
        return 50; // Placeholder
    }
    
    function _getActiveProtocols(address user) internal view returns (string[] memory) {
        // Get list of protocols where user has active positions
        string[] memory active = new string[](0);
        return active; // Placeholder
    }
    
    // Protocol withdrawal functions (placeholders)
    function _withdrawFromLending(address user, address asset, uint256 amount) internal {
        // Implement lending withdrawal
    }
    
    function _withdrawFromDex(address user, address asset, uint256 amount) internal {
        // Implement DEX withdrawal
    }
    
    function _withdrawFromVault(address user, address asset, uint256 amount) internal {
        // Implement vault withdrawal
    }
    
    function _withdrawFromStaking(address user, address asset, uint256 amount) internal {
        // Implement staking withdrawal
    }
    
    // Protocol deposit functions (placeholders)
    function _depositToLending(address user, address asset, uint256 amount) internal {
        // Implement lending deposit
    }
    
    function _depositToDex(address user, address asset, uint256 amount) internal {
        // Implement DEX deposit
    }
    
    function _depositToVault(address user, address asset, uint256 amount) internal {
        // Implement vault deposit
    }
    
    function _depositToStaking(address user, address asset, uint256 amount) internal {
        // Implement staking deposit
    }
    
    // View functions
    function getUnifiedAccount(address user) external view returns (UnifiedAccount memory) {
        return unifiedAccounts[user];
    }
    
    function getCrossProtocolPosition(address user) external view returns (CrossProtocolPosition memory) {
        return crossProtocolPositions[user];
    }
    
    function getAssetAccount(address user, address asset) external view returns (
        uint256 totalBalance,
        uint256 availableBalance,
        uint256 lockedBalance,
        uint256 earnedRewards,
        uint256 paidFees,
        bool isCollateral,
        uint256 collateralFactor
    ) {
        AssetAccount storage account = assetAccounts[user][asset];
        return (
            account.totalBalance,
            account.availableBalance,
            account.lockedBalance,
            account.earnedRewards,
            account.paidFees,
            account.isCollateral,
            account.collateralFactor
        );
    }
    
    function getPositionHistory(address user) external view returns (PositionSnapshot[] memory) {
        return positionHistory[user];
    }
    
    function getUserTransactions(address user) external view returns (uint256[] memory) {
        return userTransactions[user];
    }
    
    function getCrossProtocolTransaction(uint256 txId) external view returns (CrossProtocolTransaction memory) {
        return crossProtocolTxs[txId];
    }
    
    /**
     * @dev Update cross-protocol position for user
     */
    function updateCrossProtocolPosition(
        address user,
        address asset,
        uint256 amount,
        bool isInflow
    ) external onlyRole(PROTOCOL_ROLE) {
        AssetAccount storage assetAccount = assetAccounts[user][asset];
        
        if (isInflow) {
            assetAccount.totalBalance += amount;
            assetAccount.availableBalance += amount;
        } else {
            require(assetAccount.availableBalance >= amount, "Insufficient balance");
            assetAccount.totalBalance -= amount;
            assetAccount.availableBalance -= amount;
        }
        
        // Update unified account metrics
        _syncAllProtocolPositions(user);
        _calculateUnifiedMetrics(user);
        
        emit AccountUpdated(
            user,
            unifiedAccounts[user].totalNetWorth,
            unifiedAccounts[user].healthFactor,
            block.timestamp
        );
    }
}
