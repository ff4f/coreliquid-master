// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title UnifiedAccountingSystem
 * @dev Centralized accounting system for all protocol components
 */
contract UnifiedAccountingSystem is AccessControl, ReentrancyGuard {
    using Math for uint256;
    
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant PROTOCOL_ROLE = keccak256("PROTOCOL_ROLE");
    bytes32 public constant ACCOUNTING_ROLE = keccak256("ACCOUNTING_ROLE");
    
    uint256 public constant PRECISION = 1e18;
    uint256 public constant BASIS_POINTS = 10000;
    
    enum ProtocolComponent {
        LENDING,
        BORROWING,
        DEX,
        VAULT,
        STAKING,
        GOVERNANCE
    }
    
    enum TransactionType {
        DEPOSIT,
        WITHDRAW,
        BORROW,
        REPAY,
        SWAP,
        STAKE,
        UNSTAKE,
        REWARD,
        FEE,
        LIQUIDATION
    }
    
    struct AccountBalance {
        uint256 totalDeposits;
        uint256 totalBorrows;
        uint256 totalCollateral;
        uint256 totalRewards;
        uint256 totalFees;
        uint256 netPosition; // Can be positive or negative
        uint256 lastUpdateTime;
        bool isActive;
    }
    
    struct ProtocolBalance {
        uint256 totalAssets;
        uint256 totalLiabilities;
        uint256 totalReserves;
        uint256 totalRevenue;
        uint256 totalExpenses;
        uint256 netWorth;
        uint256 lastUpdateTime;
    }
    
    struct AssetBalance {
        uint256 totalSupply;
        uint256 totalBorrow;
        uint256 totalReserves;
        uint256 totalFees;
        uint256 utilizationRate;
        uint256 lastUpdateTime;
    }
    
    struct Transaction {
        uint256 transactionId;
        address user;
        address asset;
        ProtocolComponent component;
        TransactionType txType;
        uint256 amount;
        uint256 timestamp;
        bytes32 referenceHash;
        bool isProcessed;
    }
    
    struct PositionSummary {
        uint256 totalValue;
        uint256 totalDebt;
        uint256 netWorth;
        uint256 healthFactor;
        uint256 collateralRatio;
        uint256 borrowingPower;
        uint256 lastCalculation;
    }
    
    // User accounting
    mapping(address => mapping(address => AccountBalance)) public userBalances; // user -> asset -> balance
    mapping(address => PositionSummary) public userPositions;
    mapping(address => address[]) public userAssets;
    
    // Protocol accounting
    mapping(ProtocolComponent => mapping(address => ProtocolBalance)) public protocolBalances; // component -> asset -> balance
    mapping(address => AssetBalance) public assetBalances;
    
    // Transaction tracking
    mapping(uint256 => Transaction) public transactions;
    mapping(address => uint256[]) public userTransactions;
    uint256 public transactionCounter;
    
    // Cross-component tracking
    mapping(address => mapping(ProtocolComponent => uint256)) public userComponentBalances; // user -> component -> total value
    mapping(ProtocolComponent => uint256) public componentTotalValues;
    
    // Price and valuation
    mapping(address => uint256) public assetPrices; // Asset prices in USD (18 decimals)
    mapping(address => uint256) public priceLastUpdate;
    address public priceOracle;
    
    uint256 public totalProtocolValue;
    uint256 public totalUserDeposits;
    uint256 public totalProtocolRevenue;
    
    event BalanceUpdated(
        address indexed user,
        address indexed asset,
        ProtocolComponent component,
        uint256 newBalance,
        uint256 timestamp
    );
    
    event TransactionRecorded(
        uint256 indexed transactionId,
        address indexed user,
        address indexed asset,
        ProtocolComponent component,
        TransactionType txType,
        uint256 amount
    );
    
    event PositionUpdated(
        address indexed user,
        uint256 totalValue,
        uint256 totalDebt,
        uint256 healthFactor
    );
    
    constructor(address _priceOracle) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(PROTOCOL_ROLE, msg.sender);
        _grantRole(ACCOUNTING_ROLE, msg.sender);
        
        priceOracle = _priceOracle;
    }
    
    /**
     * @dev Record a transaction in the unified accounting system
     */
    function recordTransaction(
        address user,
        address asset,
        ProtocolComponent component,
        TransactionType txType,
        uint256 amount,
        bytes32 referenceHash
    ) external onlyRole(PROTOCOL_ROLE) returns (uint256) {
        uint256 transactionId = ++transactionCounter;
        
        transactions[transactionId] = Transaction({
            transactionId: transactionId,
            user: user,
            asset: asset,
            component: component,
            txType: txType,
            amount: amount,
            timestamp: block.timestamp,
            referenceHash: referenceHash,
            isProcessed: false
        });
        
        userTransactions[user].push(transactionId);
        
        // Update balances based on transaction type
        _updateBalances(user, asset, component, txType, amount);
        
        transactions[transactionId].isProcessed = true;
        
        emit TransactionRecorded(transactionId, user, asset, component, txType, amount);
        
        return transactionId;
    }
    
    /**
     * @dev Update user balances based on transaction
     */
    function _updateBalances(
        address user,
        address asset,
        ProtocolComponent component,
        TransactionType txType,
        uint256 amount
    ) internal {
        AccountBalance storage balance = userBalances[user][asset];
        
        if (!balance.isActive) {
            balance.isActive = true;
            userAssets[user].push(asset);
        }
        
        // Update user balances based on transaction type
        if (txType == TransactionType.DEPOSIT) {
            balance.totalDeposits += amount;
            balance.netPosition += amount;
        } else if (txType == TransactionType.WITHDRAW) {
            balance.totalDeposits = balance.totalDeposits > amount ? balance.totalDeposits - amount : 0;
            balance.netPosition = balance.netPosition > amount ? balance.netPosition - amount : 0;
        } else if (txType == TransactionType.BORROW) {
            balance.totalBorrows += amount;
            balance.netPosition = balance.netPosition > amount ? balance.netPosition - amount : 0;
        } else if (txType == TransactionType.REPAY) {
            balance.totalBorrows = balance.totalBorrows > amount ? balance.totalBorrows - amount : 0;
            balance.netPosition += amount;
        } else if (txType == TransactionType.REWARD) {
            balance.totalRewards += amount;
            balance.netPosition += amount;
        } else if (txType == TransactionType.FEE) {
            balance.totalFees += amount;
            balance.netPosition = balance.netPosition > amount ? balance.netPosition - amount : 0;
        }
        
        balance.lastUpdateTime = block.timestamp;
        
        // Update protocol balances
        _updateProtocolBalances(asset, component, txType, amount);
        
        // Update component balances
        _updateComponentBalances(user, asset, component);
        
        emit BalanceUpdated(user, asset, component, balance.netPosition, block.timestamp);
    }
    
    /**
     * @dev Update protocol-level balances
     */
    function _updateProtocolBalances(
        address asset,
        ProtocolComponent component,
        TransactionType txType,
        uint256 amount
    ) internal {
        ProtocolBalance storage protocolBalance = protocolBalances[component][asset];
        AssetBalance storage assetBalance = assetBalances[asset];
        
        if (txType == TransactionType.DEPOSIT) {
            protocolBalance.totalAssets += amount;
            assetBalance.totalSupply += amount;
        } else if (txType == TransactionType.WITHDRAW) {
            protocolBalance.totalAssets = protocolBalance.totalAssets > amount ? protocolBalance.totalAssets - amount : 0;
            assetBalance.totalSupply = assetBalance.totalSupply > amount ? assetBalance.totalSupply - amount : 0;
        } else if (txType == TransactionType.BORROW) {
            protocolBalance.totalLiabilities += amount;
            assetBalance.totalBorrow += amount;
        } else if (txType == TransactionType.REPAY) {
            protocolBalance.totalLiabilities = protocolBalance.totalLiabilities > amount ? protocolBalance.totalLiabilities - amount : 0;
            assetBalance.totalBorrow = assetBalance.totalBorrow > amount ? assetBalance.totalBorrow - amount : 0;
        } else if (txType == TransactionType.FEE) {
            protocolBalance.totalRevenue += amount;
            assetBalance.totalFees += amount;
        }
        
        protocolBalance.netWorth = protocolBalance.totalAssets > protocolBalance.totalLiabilities ? 
            protocolBalance.totalAssets - protocolBalance.totalLiabilities : 0;
        protocolBalance.lastUpdateTime = block.timestamp;
        
        // Update utilization rate
        if (assetBalance.totalSupply > 0) {
            assetBalance.utilizationRate = (assetBalance.totalBorrow * PRECISION) / assetBalance.totalSupply;
        }
        assetBalance.lastUpdateTime = block.timestamp;
    }
    
    /**
     * @dev Update component-specific balances for user
     */
    function _updateComponentBalances(address user, address asset, ProtocolComponent component) internal {
        uint256 assetPrice = assetPrices[asset];
        if (assetPrice == 0) assetPrice = PRECISION; // Default to 1:1 if no price
        
        AccountBalance memory balance = userBalances[user][asset];
        uint256 valueInUSD = (balance.netPosition * assetPrice) / PRECISION;
        
        userComponentBalances[user][component] = valueInUSD;
        
        // Recalculate total component value
        uint256 totalValue = 0;
        for (uint256 i = 0; i < userAssets[user].length; i++) {
            address userAsset = userAssets[user][i];
            AccountBalance memory userBalance = userBalances[user][userAsset];
            uint256 price = assetPrices[userAsset] > 0 ? assetPrices[userAsset] : PRECISION;
            totalValue += (userBalance.netPosition * price) / PRECISION;
        }
        
        componentTotalValues[component] = totalValue;
    }
    
    /**
     * @dev Calculate user position summary
     */
    function calculateUserPosition(address user) external onlyRole(ACCOUNTING_ROLE) returns (PositionSummary memory) {
        uint256 totalValue = 0;
        uint256 totalDebt = 0;
        uint256 totalCollateral = 0;
        
        address[] memory assets = userAssets[user];
        
        for (uint256 i = 0; i < assets.length; i++) {
            address asset = assets[i];
            AccountBalance memory balance = userBalances[user][asset];
            uint256 price = assetPrices[asset] > 0 ? assetPrices[asset] : PRECISION;
            
            uint256 depositValue = (balance.totalDeposits * price) / PRECISION;
            uint256 borrowValue = (balance.totalBorrows * price) / PRECISION;
            uint256 collateralValue = (balance.totalCollateral * price) / PRECISION;
            
            totalValue += depositValue;
            totalDebt += borrowValue;
            totalCollateral += collateralValue;
        }
        
        uint256 netWorth = totalValue > totalDebt ? totalValue - totalDebt : 0;
        uint256 healthFactor = totalDebt > 0 ? (totalCollateral * PRECISION) / totalDebt : type(uint256).max;
        uint256 collateralRatio = totalDebt > 0 ? (totalCollateral * BASIS_POINTS) / totalDebt : 0;
        uint256 borrowingPower = totalCollateral > totalDebt ? 
            ((totalCollateral - totalDebt) * 8000) / BASIS_POINTS : 0; // 80% LTV
        
        PositionSummary memory position = PositionSummary({
            totalValue: totalValue,
            totalDebt: totalDebt,
            netWorth: netWorth,
            healthFactor: healthFactor,
            collateralRatio: collateralRatio,
            borrowingPower: borrowingPower,
            lastCalculation: block.timestamp
        });
        
        userPositions[user] = position;
        
        emit PositionUpdated(user, totalValue, totalDebt, healthFactor);
        
        return position;
    }
    
    /**
     * @dev Update asset prices from oracle
     */
    function updateAssetPrices(address[] calldata assets, uint256[] calldata prices) external onlyRole(ACCOUNTING_ROLE) {
        require(assets.length == prices.length, "Arrays length mismatch");
        
        for (uint256 i = 0; i < assets.length; i++) {
            assetPrices[assets[i]] = prices[i];
            priceLastUpdate[assets[i]] = block.timestamp;
        }
    }
    
    /**
     * @dev Get user balance for specific asset
     */
    function getUserBalance(address user, address asset) external view returns (AccountBalance memory) {
        return userBalances[user][asset];
    }
    
    /**
     * @dev Get protocol balance for component and asset
     */
    function getProtocolBalance(ProtocolComponent component, address asset) external view returns (ProtocolBalance memory) {
        return protocolBalances[component][asset];
    }
    
    /**
     * @dev Get user's assets list
     */
    function getUserAssets(address user) external view returns (address[] memory) {
        return userAssets[user];
    }
    
    /**
     * @dev Get user's transaction history
     */
    function getUserTransactions(address user) external view returns (uint256[] memory) {
        return userTransactions[user];
    }
    
    /**
     * @dev Get total protocol statistics
     */
    function getProtocolStats() external view returns (
        uint256 totalValue,
        uint256 totalDeposits,
        uint256 totalRevenue,
        uint256 activeUsers
    ) {
        return (totalProtocolValue, totalUserDeposits, totalProtocolRevenue, transactionCounter);
    }
    
    /**
     * @dev Emergency function to update balances manually
     */
    function emergencyUpdateBalance(
        address user,
        address asset,
        uint256 deposits,
        uint256 borrows,
        uint256 collateral
    ) external onlyRole(ADMIN_ROLE) {
        AccountBalance storage balance = userBalances[user][asset];
        balance.totalDeposits = deposits;
        balance.totalBorrows = borrows;
        balance.totalCollateral = collateral;
        balance.netPosition = deposits + collateral > borrows ? deposits + collateral - borrows : 0;
        balance.lastUpdateTime = block.timestamp;
    }
}