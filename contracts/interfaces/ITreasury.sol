// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title ITreasury
 * @dev Interface for Treasury contract
 * @author CoreLiquid Protocol
 */
interface ITreasury {
    // Structs
    struct AssetBalance {
        address asset;
        uint256 totalBalance;
        uint256 availableBalance;
        uint256 allocatedBalance;
        uint256 reservedBalance;
        uint256 lastUpdate;
    }

    struct AllocationStrategy {
        address strategy;
        string name;
        StrategyType strategyType;
        uint256 maxAllocation;
        uint256 totalAllocated;
        address[] supportedAssets;
        uint256 createdAt;
        uint256 lastUpdate;
        bool isActive;
    }

    struct TreasuryProposal {
        bytes32 proposalId;
        ProposalType proposalType;
        address proposer;
        address target;
        uint256 amount;
        bytes data;
        string description;
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 createdAt;
        uint256 executionTime;
        uint256 executionDelay;
        uint256 executedAt;
        address executor;
        ProposalStatus status;
        bool executed;
        bool cancelled;
    }

    struct InvestmentPosition {
        address asset;
        uint256 amount;
        uint256 entryPrice;
        uint256 currentPrice;
        uint256 unrealizedPnL;
        uint256 realizedPnL;
        uint256 entryTime;
        uint256 lastUpdate;
        bool isActive;
    }

    struct Transaction {
        bytes32 txId;
        TransactionType txType;
        address asset;
        uint256 amount;
        address from;
        address to;
        bytes data;
        uint256 timestamp;
        uint256 blockNumber;
    }

    struct ReserveData {
        address asset;
        uint256 totalReserves;
        uint256 availableReserves;
        uint256 utilizationRate;
        uint256 reserveRatio;
        uint256 lastUpdate;
    }

    struct YieldStrategy {
        address strategy;
        string name;
        address[] supportedAssets;
        uint256 totalValueLocked;
        uint256 apy;
        uint256 risk;
        uint256 lastUpdate;
        bool isActive;
    }

    struct Budget {
        bytes32 budgetId;
        string name;
        address[] assets;
        uint256[] amounts;
        uint256[] spent;
        uint256 duration;
        address spender;
        uint256 createdAt;
        uint256 expiresAt;
        bool isActive;
    }

    struct Expense {
        address spender;
        address asset;
        uint256 amount;
        string category;
        string description;
        uint256 timestamp;
        bytes32 budgetId;
        bool approved;
    }

    struct AuditReport {
        bytes32 auditId;
        address auditor;
        string reportHash;
        uint256 timestamp;
        AuditStatus status;
        string findings;
        uint256 riskScore;
    }

    struct TreasuryMetrics {
        uint256 totalAssets;
        uint256 totalStrategies;
        uint256 totalProposals;
        uint256 totalTransactions;
        uint256 totalBudgets;
        uint256 totalTreasuryValue;
        uint256 totalReserves;
        uint256 totalAllocated;
        uint256 totalYield;
        uint256 utilizationRatio;
        uint256 reserveRatio;
        uint256 lastUpdate;
    }
    
    struct TreasuryConfig {
        uint256 minReserveRatio;
        uint256 maxAllocationPercentage;
        uint256 rebalanceThreshold;
        uint256 emergencyWithdrawalDelay;
        uint256 maxAssetsPerStrategy;
        uint256 yieldDistributionRatio;
        uint256 managementFee;
        uint256 performanceFee;
        bool isActive;
    }

    // Enums
    enum TransactionType {
        DEPOSIT,
        WITHDRAWAL,
        ALLOCATION,
        DEALLOCATION,
        YIELD_COLLECTION,
        REBALANCE,
        EMERGENCY_WITHDRAWAL
    }

    enum ProposalType {
        WITHDRAWAL,
        ALLOCATION,
        STRATEGY_UPDATE,
        CONFIG_UPDATE,
        EMERGENCY_ACTION
    }

    enum StrategyType {
        YIELD_FARMING,
        LIQUIDITY_PROVISION,
        LENDING,
        STAKING,
        ARBITRAGE,
        MARKET_MAKING
    }

    enum AuditStatus {
        PENDING,
        IN_PROGRESS,
        COMPLETED,
        FAILED
    }

    enum ProposalStatus {
        PENDING,
        EXECUTING,
        EXECUTED,
        FAILED,
        CANCELLED
    }

    // Events
    event Deposit(address indexed asset, uint256 amount, address indexed depositor, bytes32 txId, uint256 timestamp);
    event Withdrawal(address indexed asset, uint256 amount, address indexed recipient, address withdrawer, bytes32 txId, uint256 timestamp);
    event Allocation(address indexed asset, address indexed strategy, uint256 amount, address allocator, bytes32 txId, uint256 timestamp);
    event Deallocation(address indexed asset, address indexed strategy, uint256 amount, address deallocator, bytes32 txId, uint256 timestamp);
    event Rebalance(address[] assets, uint256[] targetAllocations, address indexed rebalancer, uint256 timestamp);
    event ProposalCreated(bytes32 indexed proposalId, ProposalType indexed proposalType, address indexed proposer, uint256 timestamp);
    event ProposalExecuted(bytes32 indexed proposalId, address indexed executor, uint256 timestamp);
    event ProposalCancelled(bytes32 indexed proposalId, address indexed canceller, uint256 timestamp);
    event Vote(bytes32 indexed proposalId, address indexed voter, bool support, uint256 weight, uint256 timestamp);
    event ProposalVoted(bytes32 indexed proposalId, address indexed voter, bool support, uint256 timestamp);
    event StrategyAdded(address indexed strategy, string name, StrategyType strategyType, uint256 maxAllocation, address indexed manager, uint256 timestamp);
    event StrategyRemoved(address indexed strategy, address indexed manager, uint256 timestamp);
    event BudgetCreated(bytes32 indexed budgetId, string name, address indexed spender, uint256 timestamp);
    event BudgetExpenseRecorded(bytes32 indexed budgetId, address indexed spender, address asset, uint256 amount, uint256 timestamp);
    event YieldCollected(address indexed strategy, address indexed asset, uint256 amount, uint256 managementFee, uint256 performanceFee, address collector, bytes32 txId, uint256 timestamp);
    event EmergencyModeEnabled(address indexed enabler, uint256 timestamp);
    event EmergencyModeDisabled(address indexed disabler, uint256 timestamp);
    event EmergencyWithdrawalRequested(address indexed requester, address asset, uint256 amount, uint256 timestamp);
    event EmergencyWithdrawalExecuted(address indexed executor, address asset, uint256 amount, uint256 timestamp);
    event TreasuryConfigUpdated(uint256 timestamp);
    event AssetApproved(address indexed asset, address indexed approver, uint256 timestamp);
    event AssetRemoved(address indexed asset, address indexed remover, uint256 timestamp);
    event AuditReportSubmitted(bytes32 indexed auditId, address indexed auditor, string reportHash, uint256 riskScore, uint256 timestamp);
    event BudgetSpent(bytes32 indexed budgetId, address indexed spender, address asset, uint256 amount, string category, uint256 timestamp);
    event EmergencyWithdrawal(address indexed asset, uint256 amount, address indexed withdrawer, bytes32 txId, uint256 timestamp);
    event EthReceived(address indexed sender, uint256 amount, uint256 timestamp);

    // Core treasury functions
    function deposit(address asset, uint256 amount, bytes calldata data) external;
    function withdraw(address asset, uint256 amount, address to, bytes calldata data) external;
    function allocate(address asset, address strategy, uint256 amount) external;
    function deallocate(address asset, address strategy, uint256 amount) external;
    function rebalance(address[] calldata assets, uint256[] calldata targetAllocations) external;

    // Proposal management
    function createProposal(ProposalType proposalType, address target, uint256 amount, bytes calldata data, string calldata description) external returns (bytes32);
    function executeProposal(bytes32 proposalId) external;
    function cancelProposal(bytes32 proposalId) external;
    function vote(bytes32 proposalId, bool support) external;

    // Strategy management
    function addStrategy(address strategy, string calldata name, StrategyType strategyType, uint256 maxAllocation, address[] calldata supportedAssets) external;
    function removeStrategy(address strategy) external;

    // Budget management
    function createBudget(string calldata name, address[] calldata assets, uint256[] calldata amounts, uint256 duration, address spender) external returns (bytes32);
    function recordExpense(bytes32 budgetId, address asset, uint256 amount, string calldata category, string calldata description) external;
    function approveBudgetExpense(address spender, bytes32 expenseId) external;

    // Yield management
    function collectYield(address strategy, address asset, uint256 amount) external;

    // Emergency functions
    function enableEmergencyMode() external;
    function disableEmergencyMode() external;
    function emergencyWithdraw(address asset, uint256 amount) external;
    function requestEmergencyWithdrawal(address asset, uint256 amount) external;

    // Audit functions
    function submitAuditReport(string calldata reportHash, string calldata findings, uint256 riskScore) external returns (bytes32);
    function approveAuditReport(bytes32 auditId) external;

    // View functions
    function getAssetBalance(address asset) external view returns (AssetBalance memory);
    function getAllocationStrategy(address strategy) external view returns (AllocationStrategy memory);
    function getTreasuryProposal(bytes32 proposalId) external view returns (TreasuryProposal memory);
    function getInvestmentPosition(address asset) external view returns (InvestmentPosition memory);
    function getTransaction(bytes32 txId) external view returns (Transaction memory);
    function getReserveData(address asset) external view returns (ReserveData memory);
    function getYieldStrategy(address strategy) external view returns (YieldStrategy memory);
    function getBudget(bytes32 budgetId) external view returns (Budget memory);
    function getExpense(address spender) external view returns (Expense memory);
    function getAuditReport(bytes32 auditId) external view returns (AuditReport memory);
    function getTreasuryConfig() external view returns (TreasuryConfig memory);
    function getTreasuryMetrics() external view returns (TreasuryMetrics memory);
    function getTotalTreasuryValue() external view returns (uint256);
    function getTotalReserves() external view returns (uint256);
    function getTotalAllocated() external view returns (uint256);
    function getAllAssets() external view returns (address[] memory);
    function getActiveStrategies() external view returns (address[] memory);
    function getPendingProposals() external view returns (bytes32[] memory);
    function getExecutedProposals() external view returns (bytes32[] memory);
    function isAssetApproved(address asset) external view returns (bool);
    function isStrategyActive(address strategy) external view returns (bool);
    function isProposalActive(bytes32 proposalId) external view returns (bool);
    function getProposalVotes(bytes32 proposalId) external view returns (uint256 votesFor, uint256 votesAgainst);
    function hasVotedOnProposal(bytes32 proposalId, address voter) external view returns (bool);
}
