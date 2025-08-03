// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "../interfaces/ITreasury.sol";
import "../interfaces/IOracle.sol";
import "../interfaces/IGovernance.sol";

/**
 * @title Treasury
 * @dev Treasury management system for CoreLiquid Protocol
 * @author CoreLiquid Protocol
 */
contract Treasury is ITreasury, AccessControl, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;
    using Math for uint256;

    // Roles
    bytes32 public constant TREASURY_MANAGER_ROLE = keccak256("TREASURY_MANAGER_ROLE");
    bytes32 public constant FUND_MANAGER_ROLE = keccak256("FUND_MANAGER_ROLE");
    bytes32 public constant ALLOCATOR_ROLE = keccak256("ALLOCATOR_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
    bytes32 public constant AUDITOR_ROLE = keccak256("AUDITOR_ROLE");
    bytes32 public constant WITHDRAWAL_ROLE = keccak256("WITHDRAWAL_ROLE");

    // Constants
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant PRECISION = 1e18;
    uint256 public constant MAX_ALLOCATION_PERCENTAGE = 5000; // 50%
    uint256 public constant MIN_RESERVE_RATIO = 1000; // 10%
    uint256 public constant MAX_ASSETS = 100;
    uint256 public constant MAX_STRATEGIES = 50;
    uint256 public constant MAX_PROPOSALS = 1000;
    uint256 public constant REBALANCE_THRESHOLD = 500; // 5%
    uint256 public constant EMERGENCY_WITHDRAWAL_DELAY = 24 hours;

    // External contracts
    IOracle public immutable oracle;
    IGovernance public governance;

    // Storage mappings
    mapping(address => AssetBalance) public assetBalances;
    mapping(address => AllocationStrategy) public allocationStrategies;
    mapping(bytes32 => TreasuryProposal) public treasuryProposals;
    mapping(address => InvestmentPosition) public investmentPositions;
    mapping(bytes32 => Transaction) public transactions;
    mapping(address => ReserveData) public reserveData;
    mapping(address => YieldStrategy) public yieldStrategies;
    mapping(bytes32 => Budget) public budgets;
    mapping(address => Expense) public expenses;
    mapping(bytes32 => AuditReport) public auditReports;
    mapping(address => address[]) public assetStrategies;
    mapping(address => bytes32[]) public assetTransactions;
    mapping(address => uint256) public lastRebalance;
    mapping(address => bool) public isApprovedAsset;
    mapping(bytes32 => bool) public isActiveProposal;
    mapping(address => bool) public isActiveStrategy;
    mapping(bytes32 => bool) public isExecutedTransaction;
    mapping(address => uint256) public assetAllocationLimits;
    mapping(bytes32 => uint256) public proposalVotes;
    mapping(bytes32 => mapping(address => bool)) public hasVotedOnProposal;
    
    // Global arrays
    address[] public allAssets;
    address[] public activeStrategies;
    bytes32[] public allProposals;
    bytes32[] public pendingProposals;
    bytes32[] public executedProposals;
    bytes32[] public allTransactions;
    bytes32[] public allBudgets;
    address[] public allExpenses;
    bytes32[] public allAudits;
    address[] public approvedAssets;
    
    // Treasury configuration
    TreasuryConfig public config;
    
    // Counters
    uint256 public totalAssets;
    uint256 public totalStrategies;
    uint256 public totalProposals;
    uint256 public totalTransactions;
    uint256 public totalBudgets;
    uint256 public proposalCounter;
    uint256 public transactionCounter;
    uint256 public budgetCounter;
    uint256 public auditCounter;
    
    // State variables
    bool public emergencyMode;
    uint256 public lastGlobalRebalance;
    uint256 public totalTreasuryValue;
    uint256 public totalReserves;
    uint256 public totalAllocated;
    uint256 public totalYield;
    mapping(address => uint256) public emergencyWithdrawalRequests;
    mapping(address => uint256) public lastEmergencyRequest;
    mapping(address => bool) public isEmergencyWithdrawalPending;
    mapping(bytes32 => bool) public isBudgetActive;
    mapping(address => bool) public isAuthorizedSpender;

    constructor(
        address _oracle,
        address _governance,
        uint256 _minReserveRatio,
        uint256 _maxAllocationPercentage
    ) {
        require(_oracle != address(0), "Invalid oracle");
        require(_governance != address(0), "Invalid governance");
        require(_minReserveRatio >= 500, "Reserve ratio too low"); // Min 5%
        require(_maxAllocationPercentage <= 5000, "Allocation percentage too high"); // Max 50%
        
        oracle = IOracle(_oracle);
        governance = IGovernance(_governance);
        
        config = TreasuryConfig({
            minReserveRatio: _minReserveRatio,
            maxAllocationPercentage: _maxAllocationPercentage,
            rebalanceThreshold: REBALANCE_THRESHOLD,
            emergencyWithdrawalDelay: EMERGENCY_WITHDRAWAL_DELAY,
            maxAssetsPerStrategy: 10,
            yieldDistributionRatio: 7000, // 70% to treasury, 30% to stakers
            managementFee: 200, // 2%
            performanceFee: 1000, // 10%
            isActive: true
        });
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(TREASURY_MANAGER_ROLE, msg.sender);
        _grantRole(FUND_MANAGER_ROLE, msg.sender);
        _grantRole(ALLOCATOR_ROLE, msg.sender);
        _grantRole(EMERGENCY_ROLE, msg.sender);
        _grantRole(AUDITOR_ROLE, msg.sender);
        _grantRole(WITHDRAWAL_ROLE, msg.sender);
    }

    // Core treasury functions
    function deposit(
        address asset,
        uint256 amount,
        bytes calldata data
    ) external override nonReentrant whenNotPaused {
        require(asset != address(0), "Invalid asset");
        require(amount > 0, "Invalid amount");
        require(isApprovedAsset[asset], "Asset not approved");
        
        // Transfer tokens to treasury
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
        
        // Update asset balance
        AssetBalance storage balance = assetBalances[asset];
        balance.asset = asset;
        balance.totalBalance += amount;
        balance.availableBalance += amount;
        balance.lastUpdate = block.timestamp;
        
        // Add to assets if new
        if (balance.totalBalance == amount) {
            allAssets.push(asset);
            totalAssets++;
        }
        
        // Update total treasury value
        _updateTotalTreasuryValue();
        
        // Record transaction
        bytes32 txId = _recordTransaction(
            TransactionType.DEPOSIT,
            asset,
            amount,
            msg.sender,
            address(this),
            data
        );
        
        emit Deposit(asset, amount, msg.sender, txId, block.timestamp);
    }

    function withdraw(
        address asset,
        uint256 amount,
        address to,
        bytes calldata data
    ) external override onlyRole(WITHDRAWAL_ROLE) nonReentrant {
        require(asset != address(0), "Invalid asset");
        require(amount > 0, "Invalid amount");
        require(to != address(0), "Invalid recipient");
        
        AssetBalance storage balance = assetBalances[asset];
        require(balance.availableBalance >= amount, "Insufficient balance");
        
        // Check reserve requirements
        uint256 totalValue = _getAssetValue(asset, balance.totalBalance);
        uint256 withdrawalValue = _getAssetValue(asset, amount);
        require(_checkReserveRequirements(totalValue, withdrawalValue), "Reserve requirements not met");
        
        // Update balance
        balance.totalBalance -= amount;
        balance.availableBalance -= amount;
        balance.lastUpdate = block.timestamp;
        
        // Transfer tokens
        IERC20(asset).safeTransfer(to, amount);
        
        // Update total treasury value
        _updateTotalTreasuryValue();
        
        // Record transaction
        bytes32 txId = _recordTransaction(
            TransactionType.WITHDRAWAL,
            asset,
            amount,
            address(this),
            to,
            data
        );
        
        emit Withdrawal(asset, amount, to, msg.sender, txId, block.timestamp);
    }

    function allocate(
        address asset,
        address strategy,
        uint256 amount
    ) external override onlyRole(ALLOCATOR_ROLE) nonReentrant {
        require(asset != address(0), "Invalid asset");
        require(strategy != address(0), "Invalid strategy");
        require(amount > 0, "Invalid amount");
        require(isActiveStrategy[strategy], "Strategy not active");
        
        AssetBalance storage balance = assetBalances[asset];
        require(balance.availableBalance >= amount, "Insufficient available balance");
        
        AllocationStrategy storage strategyData = allocationStrategies[strategy];
        require(strategyData.isActive, "Strategy not active");
        
        // Check allocation limits
        uint256 totalAssetValue = _getAssetValue(asset, balance.totalBalance);
        uint256 allocationValue = _getAssetValue(asset, amount);
        uint256 allocationPercentage = (allocationValue * BASIS_POINTS) / totalTreasuryValue;
        require(allocationPercentage <= config.maxAllocationPercentage, "Allocation exceeds limit");
        
        // Update balances
        balance.availableBalance -= amount;
        balance.allocatedBalance += amount;
        balance.lastUpdate = block.timestamp;
        
        // Update strategy allocation
        strategyData.totalAllocated += allocationValue;
        strategyData.assetAllocations[asset] += amount;
        strategyData.lastUpdate = block.timestamp;
        
        // Update global allocation
        totalAllocated += allocationValue;
        
        // Transfer to strategy
        IERC20(asset).safeTransfer(strategy, amount);
        
        // Record transaction
        bytes32 txId = _recordTransaction(
            TransactionType.ALLOCATION,
            asset,
            amount,
            address(this),
            strategy,
            abi.encode(strategy)
        );
        
        emit Allocation(asset, strategy, amount, msg.sender, txId, block.timestamp);
    }

    function deallocate(
        address asset,
        address strategy,
        uint256 amount
    ) external override onlyRole(ALLOCATOR_ROLE) nonReentrant {
        require(asset != address(0), "Invalid asset");
        require(strategy != address(0), "Invalid strategy");
        require(amount > 0, "Invalid amount");
        
        AllocationStrategy storage strategyData = allocationStrategies[strategy];
        require(strategyData.assetAllocations[asset] >= amount, "Insufficient allocation");
        
        // Transfer back from strategy
        IERC20(asset).safeTransferFrom(strategy, address(this), amount);
        
        // Update balances
        AssetBalance storage balance = assetBalances[asset];
        balance.availableBalance += amount;
        balance.allocatedBalance -= amount;
        balance.lastUpdate = block.timestamp;
        
        // Update strategy allocation
        uint256 allocationValue = _getAssetValue(asset, amount);
        strategyData.totalAllocated -= allocationValue;
        strategyData.assetAllocations[asset] -= amount;
        strategyData.lastUpdate = block.timestamp;
        
        // Update global allocation
        totalAllocated -= allocationValue;
        
        // Record transaction
        bytes32 txId = _recordTransaction(
            TransactionType.DEALLOCATION,
            asset,
            amount,
            strategy,
            address(this),
            abi.encode(strategy)
        );
        
        emit Deallocation(asset, strategy, amount, msg.sender, txId, block.timestamp);
    }

    function rebalance(
        address[] calldata assets,
        uint256[] calldata targetAllocations
    ) external override onlyRole(FUND_MANAGER_ROLE) {
        require(assets.length == targetAllocations.length, "Length mismatch");
        require(assets.length > 0, "Empty arrays");
        
        uint256 totalTargetAllocation = 0;
        for (uint256 i = 0; i < targetAllocations.length; i++) {
            totalTargetAllocation += targetAllocations[i];
        }
        require(totalTargetAllocation == BASIS_POINTS, "Invalid total allocation");
        
        // Perform rebalancing
        for (uint256 i = 0; i < assets.length; i++) {
            address asset = assets[i];
            uint256 targetAllocation = targetAllocations[i];
            
            AssetBalance storage balance = assetBalances[asset];
            uint256 currentValue = _getAssetValue(asset, balance.totalBalance);
            uint256 targetValue = (totalTreasuryValue * targetAllocation) / BASIS_POINTS;
            
            if (currentValue > targetValue) {
                // Need to reduce allocation
                uint256 excessValue = currentValue - targetValue;
                uint256 excessAmount = _getAssetAmount(asset, excessValue);
                
                if (balance.availableBalance >= excessAmount) {
                    // Can withdraw from available balance
                    _redistributeAsset(asset, excessAmount);
                } else {
                    // Need to deallocate from strategies
                    _deallocateFromStrategies(asset, excessAmount);
                }
            } else if (currentValue < targetValue) {
                // Need to increase allocation
                uint256 deficitValue = targetValue - currentValue;
                uint256 deficitAmount = _getAssetAmount(asset, deficitValue);
                
                _acquireAsset(asset, deficitAmount);
            }
            
            lastRebalance[asset] = block.timestamp;
        }
        
        lastGlobalRebalance = block.timestamp;
        
        emit Rebalance(assets, targetAllocations, msg.sender, block.timestamp);
    }

    function createProposal(
        ProposalType proposalType,
        address target,
        uint256 amount,
        bytes calldata data,
        string calldata description
    ) external override onlyRole(TREASURY_MANAGER_ROLE) returns (bytes32) {
        require(target != address(0), "Invalid target");
        require(bytes(description).length > 0, "Empty description");
        require(allProposals.length < MAX_PROPOSALS, "Too many proposals");
        
        bytes32 proposalId = keccak256(abi.encodePacked(
            proposalType,
            target,
            amount,
            data,
            description,
            block.timestamp,
            ++proposalCounter
        ));
        
        TreasuryProposal storage proposal = treasuryProposals[proposalId];
        proposal.proposalId = proposalId;
        proposal.proposalType = proposalType;
        proposal.proposer = msg.sender;
        proposal.target = target;
        proposal.amount = amount;
        proposal.data = data;
        proposal.description = description;
        proposal.createdAt = block.timestamp;
        proposal.executionDelay = 7 days; // Default delay
        proposal.status = ProposalStatus.PENDING;
        
        // Add to tracking arrays
        allProposals.push(proposalId);
        pendingProposals.push(proposalId);
        isActiveProposal[proposalId] = true;
        totalProposals++;
        
        emit ProposalCreated(
            proposalId,
            proposalType,
            target,
            amount,
            description,
            msg.sender,
            block.timestamp
        );
        
        return proposalId;
    }

    function executeProposal(
        bytes32 proposalId
    ) external override onlyRole(TREASURY_MANAGER_ROLE) nonReentrant {
        require(isActiveProposal[proposalId], "Proposal not active");
        
        TreasuryProposal storage proposal = treasuryProposals[proposalId];
        require(proposal.status == ProposalStatus.PENDING, "Proposal not pending");
        require(block.timestamp >= proposal.createdAt + proposal.executionDelay, "Too early");
        
        // Check if proposal has enough votes (if governance is enabled)
        if (address(governance) != address(0)) {
            require(proposalVotes[proposalId] >= _getRequiredVotes(), "Insufficient votes");
        }
        
        proposal.status = ProposalStatus.EXECUTING;
        proposal.executedAt = block.timestamp;
        proposal.executor = msg.sender;
        
        // Execute proposal based on type
        bool success = _executeProposalAction(proposal);
        
        if (success) {
            proposal.status = ProposalStatus.EXECUTED;
            _removeFromPendingProposals(proposalId);
            executedProposals.push(proposalId);
        } else {
            proposal.status = ProposalStatus.FAILED;
        }
        
        isActiveProposal[proposalId] = false;
        
        emit ProposalExecuted(
            proposalId,
            success,
            msg.sender,
            block.timestamp
        );
    }

    function addStrategy(
        address strategy,
        string calldata name,
        StrategyType strategyType,
        uint256 maxAllocation,
        address[] calldata supportedAssets
    ) external override onlyRole(FUND_MANAGER_ROLE) {
        require(strategy != address(0), "Invalid strategy");
        require(bytes(name).length > 0, "Empty name");
        require(maxAllocation > 0, "Invalid max allocation");
        require(supportedAssets.length > 0, "No supported assets");
        require(supportedAssets.length <= config.maxAssetsPerStrategy, "Too many assets");
        
        AllocationStrategy storage strategyData = allocationStrategies[strategy];
        strategyData.strategy = strategy;
        strategyData.name = name;
        strategyData.strategyType = strategyType;
        strategyData.maxAllocation = maxAllocation;
        strategyData.supportedAssets = supportedAssets;
        strategyData.createdAt = block.timestamp;
        strategyData.lastUpdate = block.timestamp;
        strategyData.isActive = true;
        
        // Add to tracking
        activeStrategies.push(strategy);
        isActiveStrategy[strategy] = true;
        totalStrategies++;
        
        // Initialize asset allocations
        for (uint256 i = 0; i < supportedAssets.length; i++) {
            assetStrategies[supportedAssets[i]].push(strategy);
        }
        
        emit StrategyAdded(
            strategy,
            name,
            strategyType,
            maxAllocation,
            msg.sender,
            block.timestamp
        );
    }

    function removeStrategy(
        address strategy
    ) external override onlyRole(FUND_MANAGER_ROLE) {
        require(isActiveStrategy[strategy], "Strategy not active");
        
        AllocationStrategy storage strategyData = allocationStrategies[strategy];
        require(strategyData.totalAllocated == 0, "Strategy has active allocations");
        
        strategyData.isActive = false;
        strategyData.lastUpdate = block.timestamp;
        isActiveStrategy[strategy] = false;
        
        // Remove from active strategies
        _removeFromActiveStrategies(strategy);
        
        emit StrategyRemoved(strategy, msg.sender, block.timestamp);
    }

    function createBudget(
        string calldata name,
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256 duration,
        address spender
    ) external override onlyRole(TREASURY_MANAGER_ROLE) returns (bytes32) {
        require(bytes(name).length > 0, "Empty name");
        require(assets.length == amounts.length, "Length mismatch");
        require(assets.length > 0, "Empty arrays");
        require(duration > 0, "Invalid duration");
        require(spender != address(0), "Invalid spender");
        
        bytes32 budgetId = keccak256(abi.encodePacked(
            name,
            assets,
            amounts,
            duration,
            spender,
            block.timestamp,
            ++budgetCounter
        ));
        
        Budget storage budget = budgets[budgetId];
        budget.budgetId = budgetId;
        budget.name = name;
        budget.assets = assets;
        budget.amounts = amounts;
        budget.duration = duration;
        budget.spender = spender;
        budget.createdAt = block.timestamp;
        budget.expiresAt = block.timestamp + duration;
        budget.isActive = true;
        
        // Check if assets are available
        for (uint256 i = 0; i < assets.length; i++) {
            require(assetBalances[assets[i]].availableBalance >= amounts[i], "Insufficient balance");
            
            // Reserve the budget amount
            assetBalances[assets[i]].availableBalance -= amounts[i];
            assetBalances[assets[i]].reservedBalance += amounts[i];
        }
        
        allBudgets.push(budgetId);
        isBudgetActive[budgetId] = true;
        isAuthorizedSpender[spender] = true;
        totalBudgets++;
        
        emit BudgetCreated(
            budgetId,
            name,
            assets,
            amounts,
            duration,
            spender,
            msg.sender,
            block.timestamp
        );
        
        return budgetId;
    }

    function spendFromBudget(
        bytes32 budgetId,
        address asset,
        uint256 amount,
        address to,
        bytes calldata data
    ) external nonReentrant {
        require(isBudgetActive[budgetId], "Budget not active");
        
        Budget storage budget = budgets[budgetId];
        require(budget.spender == msg.sender, "Not authorized spender");
        require(block.timestamp <= budget.expiresAt, "Budget expired");
        require(to != address(0), "Invalid recipient");
        
        // Find asset in budget
        bool assetFound = false;
        uint256 assetIndex;
        for (uint256 i = 0; i < budget.assets.length; i++) {
            if (budget.assets[i] == asset) {
                assetFound = true;
                assetIndex = i;
                break;
            }
        }
        require(assetFound, "Asset not in budget");
        require(budget.spent[assetIndex] + amount <= budget.amounts[assetIndex], "Exceeds budget");
        
        // Update budget spending
        budget.spent[assetIndex] += amount;
        budget.lastSpent = block.timestamp;
        
        // Update asset balances
        AssetBalance storage balance = assetBalances[asset];
        balance.reservedBalance -= amount;
        balance.totalBalance -= amount;
        balance.lastUpdate = block.timestamp;
        
        // Transfer tokens
        IERC20(asset).safeTransfer(to, amount);
        
        // Record transaction
        bytes32 txId = _recordTransaction(
            TransactionType.BUDGET_SPENDING,
            asset,
            amount,
            address(this),
            to,
            abi.encode(budgetId, data)
        );
        
        emit BudgetSpent(
            budgetId,
            asset,
            amount,
            to,
            msg.sender,
            txId,
            block.timestamp
        );
    }

    function collectYield(
        address strategy,
        address asset,
        uint256 amount
    ) external override onlyRole(FUND_MANAGER_ROLE) nonReentrant {
        require(isActiveStrategy[strategy], "Strategy not active");
        require(asset != address(0), "Invalid asset");
        require(amount > 0, "Invalid amount");
        
        // Transfer yield from strategy
        IERC20(asset).safeTransferFrom(strategy, address(this), amount);
        
        // Update asset balance
        AssetBalance storage balance = assetBalances[asset];
        balance.totalBalance += amount;
        balance.availableBalance += amount;
        balance.yieldEarned += amount;
        balance.lastUpdate = block.timestamp;
        
        // Update strategy data
        AllocationStrategy storage strategyData = allocationStrategies[strategy];
        strategyData.totalYield += _getAssetValue(asset, amount);
        strategyData.lastUpdate = block.timestamp;
        
        // Update global yield
        totalYield += _getAssetValue(asset, amount);
        
        // Calculate fees
        uint256 managementFee = (amount * config.managementFee) / BASIS_POINTS;
        uint256 performanceFee = (amount * config.performanceFee) / BASIS_POINTS;
        uint256 netYield = amount - managementFee - performanceFee;
        
        // Distribute yield according to configuration
        uint256 treasuryShare = (netYield * config.yieldDistributionRatio) / BASIS_POINTS;
        uint256 stakersShare = netYield - treasuryShare;
        
        // Record transaction
        bytes32 txId = _recordTransaction(
            TransactionType.YIELD_COLLECTION,
            asset,
            amount,
            strategy,
            address(this),
            abi.encode(managementFee, performanceFee, treasuryShare, stakersShare)
        );
        
        emit YieldCollected(
            strategy,
            asset,
            amount,
            managementFee,
            performanceFee,
            msg.sender,
            txId,
            block.timestamp
        );
    }

    // Emergency functions
    function emergencyWithdraw(
        address asset,
        uint256 amount
    ) external override onlyRole(EMERGENCY_ROLE) nonReentrant {
        require(emergencyMode, "Not in emergency mode");
        require(asset != address(0), "Invalid asset");
        require(amount > 0, "Invalid amount");
        
        AssetBalance storage balance = assetBalances[asset];
        require(balance.totalBalance >= amount, "Insufficient balance");
        
        // Update balance
        balance.totalBalance -= amount;
        if (balance.availableBalance >= amount) {
            balance.availableBalance -= amount;
        } else {
            // Need to withdraw from allocations
            uint256 fromAllocated = amount - balance.availableBalance;
            balance.availableBalance = 0;
            balance.allocatedBalance -= fromAllocated;
        }
        balance.lastUpdate = block.timestamp;
        
        // Transfer to emergency role holder
        IERC20(asset).safeTransfer(msg.sender, amount);
        
        // Record transaction
        bytes32 txId = _recordTransaction(
            TransactionType.EMERGENCY_WITHDRAWAL,
            asset,
            amount,
            address(this),
            msg.sender,
            abi.encode("Emergency withdrawal")
        );
        
        emit EmergencyWithdrawal(
            asset,
            amount,
            msg.sender,
            txId,
            block.timestamp
        );
    }

    function enableEmergencyMode() external override onlyRole(EMERGENCY_ROLE) {
        emergencyMode = true;
        _pause();
        
        emit EmergencyModeEnabled(msg.sender, block.timestamp);
    }

    function disableEmergencyMode() external override onlyRole(EMERGENCY_ROLE) {
        emergencyMode = false;
        _unpause();
        
        emit EmergencyModeDisabled(msg.sender, block.timestamp);
    }

    function requestEmergencyWithdrawal(
        address asset,
        uint256 amount
    ) external override {
        require(asset != address(0), "Invalid asset");
        require(amount > 0, "Invalid amount");
        require(!isEmergencyWithdrawalPending[msg.sender], "Request already pending");
        
        emergencyWithdrawalRequests[msg.sender] = amount;
        lastEmergencyRequest[msg.sender] = block.timestamp;
        isEmergencyWithdrawalPending[msg.sender] = true;
        
        emit EmergencyWithdrawalRequested(
            msg.sender,
            asset,
            amount,
            block.timestamp
        );
    }

    // View functions
    function getAssetBalance(address asset) external view override returns (AssetBalance memory) {
        return assetBalances[asset];
    }

    function getAllocationStrategy(address strategy) external view override returns (AllocationStrategy memory) {
        return allocationStrategies[strategy];
    }

    function getTreasuryProposal(bytes32 proposalId) external view override returns (TreasuryProposal memory) {
        return treasuryProposals[proposalId];
    }

    function getInvestmentPosition(address asset) external view override returns (InvestmentPosition memory) {
        return investmentPositions[asset];
    }

    function getTransaction(bytes32 txId) external view override returns (Transaction memory) {
        return transactions[txId];
    }

    function getReserveData(address asset) external view override returns (ReserveData memory) {
        return reserveData[asset];
    }

    function getYieldStrategy(address strategy) external view override returns (YieldStrategy memory) {
        return yieldStrategies[strategy];
    }

    function getBudget(bytes32 budgetId) external view override returns (Budget memory) {
        return budgets[budgetId];
    }

    function getExpense(address spender) external view override returns (Expense memory) {
        return expenses[spender];
    }

    function getAuditReport(bytes32 auditId) external view override returns (AuditReport memory) {
        return auditReports[auditId];
    }

    function getTreasuryConfig() external view override returns (TreasuryConfig memory) {
        return config;
    }

    function getAllAssets() external view override returns (address[] memory) {
        return allAssets;
    }

    function getActiveStrategies() external view override returns (address[] memory) {
        return activeStrategies;
    }

    function getPendingProposals() external view override returns (bytes32[] memory) {
        return pendingProposals;
    }

    function getExecutedProposals() external view override returns (bytes32[] memory) {
        return executedProposals;
    }

    function getAllBudgets() external view returns (bytes32[] memory) {
        return allBudgets;
    }

    function getTreasuryMetrics() external view override returns (TreasuryMetrics memory) {
        return TreasuryMetrics({
            totalAssets: totalAssets,
            totalStrategies: totalStrategies,
            totalProposals: totalProposals,
            totalTransactions: totalTransactions,
            totalBudgets: totalBudgets,
            totalTreasuryValue: totalTreasuryValue,
            totalReserves: totalReserves,
            totalAllocated: totalAllocated,
            totalYield: totalYield,
            utilizationRatio: totalTreasuryValue > 0 ? (totalAllocated * BASIS_POINTS) / totalTreasuryValue : 0,
            reserveRatio: totalTreasuryValue > 0 ? (totalReserves * BASIS_POINTS) / totalTreasuryValue : 0,
            lastUpdate: block.timestamp
        });
    }

    function getTotalValue() external view returns (uint256) {
        return totalTreasuryValue;
    }

    function getAvailableBalance(address asset) external view returns (uint256) {
        return assetBalances[asset].availableBalance;
    }

    function getAllocatedBalance(address asset) external view returns (uint256) {
        return assetBalances[asset].allocatedBalance;
    }

    function getReserveRatio() external view returns (uint256) {
        return totalTreasuryValue > 0 ? (totalReserves * BASIS_POINTS) / totalTreasuryValue : 0;
    }

    function getUtilizationRatio() external view returns (uint256) {
        return totalTreasuryValue > 0 ? (totalAllocated * BASIS_POINTS) / totalTreasuryValue : 0;
    }

    // Internal functions
    function _recordTransaction(
        TransactionType txType,
        address asset,
        uint256 amount,
        address from,
        address to,
        bytes memory data
    ) internal returns (bytes32) {
        bytes32 txId = keccak256(abi.encodePacked(
            txType,
            asset,
            amount,
            from,
            to,
            data,
            block.timestamp,
            ++transactionCounter
        ));
        
        Transaction storage transaction = transactions[txId];
        transaction.txId = txId;
        transaction.txType = txType;
        transaction.asset = asset;
        transaction.amount = amount;
        transaction.from = from;
        transaction.to = to;
        transaction.data = data;
        transaction.timestamp = block.timestamp;
        transaction.blockNumber = block.number;
        
        allTransactions.push(txId);
        assetTransactions[asset].push(txId);
        isExecutedTransaction[txId] = true;
        totalTransactions++;
        
        return txId;
    }

    function _updateTotalTreasuryValue() internal {
        uint256 newTotalValue = 0;
        
        for (uint256 i = 0; i < allAssets.length; i++) {
            address asset = allAssets[i];
            AssetBalance storage balance = assetBalances[asset];
            uint256 assetValue = _getAssetValue(asset, balance.totalBalance);
            newTotalValue += assetValue;
        }
        
        totalTreasuryValue = newTotalValue;
        
        // Update reserves (available + reserved balances)
        uint256 newTotalReserves = 0;
        for (uint256 i = 0; i < allAssets.length; i++) {
            address asset = allAssets[i];
            AssetBalance storage balance = assetBalances[asset];
            uint256 reserveValue = _getAssetValue(asset, balance.availableBalance + balance.reservedBalance);
            newTotalReserves += reserveValue;
        }
        
        totalReserves = newTotalReserves;
    }

    function _getAssetValue(address asset, uint256 amount) internal view returns (uint256) {
        if (amount == 0) return 0;
        
        (uint256 price,) = oracle.getPrice(asset);
        return (amount * price) / PRECISION;
    }

    function _getAssetAmount(address asset, uint256 value) internal view returns (uint256) {
        if (value == 0) return 0;
        
        (uint256 price,) = oracle.getPrice(asset);
        return (value * PRECISION) / price;
    }

    function _checkReserveRequirements(uint256 totalValue, uint256 withdrawalValue) internal view returns (bool) {
        if (totalValue == 0) return true;
        
        uint256 remainingValue = totalValue - withdrawalValue;
        uint256 remainingRatio = (remainingValue * BASIS_POINTS) / totalValue;
        
        return remainingRatio >= config.minReserveRatio;
    }

    function _executeProposalAction(TreasuryProposal memory proposal) internal returns (bool) {
        if (proposal.proposalType == ProposalType.WITHDRAWAL) {
            // Execute withdrawal
            try IERC20(proposal.target).transfer(proposal.target, proposal.amount) {
                return true;
            } catch {
                return false;
            }
        } else if (proposal.proposalType == ProposalType.ALLOCATION) {
            // Execute allocation
            return true; // Simplified
        } else if (proposal.proposalType == ProposalType.STRATEGY_UPDATE) {
            // Execute strategy update
            return true; // Simplified
        } else if (proposal.proposalType == ProposalType.CONFIG_UPDATE) {
            // Execute config update
            return true; // Simplified
        }
        
        return false;
    }

    function _getRequiredVotes() internal view returns (uint256) {
        // Get required votes from governance contract
        if (address(governance) != address(0)) {
            // This would call governance contract to get quorum
            return 1; // Simplified
        }
        return 1;
    }

    function _removeFromPendingProposals(bytes32 proposalId) internal {
        for (uint256 i = 0; i < pendingProposals.length; i++) {
            if (pendingProposals[i] == proposalId) {
                pendingProposals[i] = pendingProposals[pendingProposals.length - 1];
                pendingProposals.pop();
                break;
            }
        }
    }

    function _removeFromActiveStrategies(address strategy) internal {
        for (uint256 i = 0; i < activeStrategies.length; i++) {
            if (activeStrategies[i] == strategy) {
                activeStrategies[i] = activeStrategies[activeStrategies.length - 1];
                activeStrategies.pop();
                break;
            }
        }
    }

    function _redistributeAsset(address asset, uint256 amount) internal {
        // Redistribute excess asset to other assets or strategies
        // Simplified implementation
    }

    function _deallocateFromStrategies(address asset, uint256 amount) internal {
        // Deallocate from strategies to free up the required amount
        // Simplified implementation
    }

    function _acquireAsset(address asset, uint256 amount) internal {
        // Acquire asset through swaps or other means
        // Simplified implementation
    }

    // Configuration update functions
    function updateTreasuryConfig(
        TreasuryConfig calldata newConfig
    ) external onlyRole(TREASURY_MANAGER_ROLE) {
        require(newConfig.minReserveRatio >= 500, "Reserve ratio too low");
        require(newConfig.maxAllocationPercentage <= 5000, "Allocation percentage too high");
        require(newConfig.rebalanceThreshold > 0, "Invalid rebalance threshold");
        require(newConfig.emergencyWithdrawalDelay > 0, "Invalid emergency withdrawal delay");
        require(newConfig.maxAssetsPerStrategy > 0, "Invalid max assets per strategy");
        require(newConfig.yieldDistributionRatio <= BASIS_POINTS, "Invalid yield distribution ratio");
        require(newConfig.managementFee <= 1000, "Management fee too high"); // Max 10%
        require(newConfig.performanceFee <= 2000, "Performance fee too high"); // Max 20%
        
        config = newConfig;
        
        emit TreasuryConfigUpdated(block.timestamp);
    }

    function addApprovedAsset(address asset) external onlyRole(TREASURY_MANAGER_ROLE) {
        require(asset != address(0), "Invalid asset");
        require(!isApprovedAsset[asset], "Asset already approved");
        
        isApprovedAsset[asset] = true;
        approvedAssets.push(asset);
        
        emit AssetApproved(asset, msg.sender, block.timestamp);
    }

    function removeApprovedAsset(address asset) external onlyRole(TREASURY_MANAGER_ROLE) {
        require(isApprovedAsset[asset], "Asset not approved");
        require(assetBalances[asset].totalBalance == 0, "Asset has balance");
        
        isApprovedAsset[asset] = false;
        
        // Remove from approved assets array
        for (uint256 i = 0; i < approvedAssets.length; i++) {
            if (approvedAssets[i] == asset) {
                approvedAssets[i] = approvedAssets[approvedAssets.length - 1];
                approvedAssets.pop();
                break;
            }
        }
        
        emit AssetRemoved(asset, msg.sender, block.timestamp);
    }

    // Voting functions
    function vote(bytes32 proposalId, bool support) external override {
        require(isActiveProposal[proposalId], "Proposal not active");
        require(!hasVotedOnProposal[proposalId][msg.sender], "Already voted");
        
        TreasuryProposal storage proposal = treasuryProposals[proposalId];
        require(proposal.status == ProposalStatus.PENDING, "Proposal not pending");
        
        hasVotedOnProposal[proposalId][msg.sender] = true;
        
        if (support) {
            proposal.votesFor++;
        } else {
            proposal.votesAgainst++;
        }
        
        emit ProposalVoted(proposalId, msg.sender, support, block.timestamp);
    }
    
    function submitAuditReport(
        string calldata reportHash,
        string calldata findings,
        uint256 riskScore
    ) external override onlyRole(AUDITOR_ROLE) returns (bytes32) {
        require(bytes(reportHash).length > 0, "Invalid report hash");
        require(riskScore <= 100, "Invalid risk score");
        
        bytes32 auditId = keccak256(abi.encodePacked(
            reportHash,
            findings,
            riskScore,
            msg.sender,
            block.timestamp,
            ++auditCounter
        ));
        
        AuditReport storage report = auditReports[auditId];
        report.auditId = auditId;
        report.auditor = msg.sender;
        report.reportHash = reportHash;
        report.timestamp = block.timestamp;
        report.status = AuditStatus.COMPLETED;
        report.findings = findings;
        report.riskScore = riskScore;
        
        allAudits.push(auditId);
        
        emit AuditReportSubmitted(auditId, msg.sender, reportHash, riskScore, block.timestamp);
        
        return auditId;
    }

    // Admin functions
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    // Additional view functions
    function getTotalTreasuryValue() external view override returns (uint256) {
        return totalTreasuryValue;
    }
    
    function isAssetApproved(address asset) external view override returns (bool) {
        return isApprovedAsset[asset];
    }
    
    function isStrategyActive(address strategy) external view override returns (bool) {
        return isActiveStrategy[strategy];
    }
    
    function isProposalActive(bytes32 proposalId) external view override returns (bool) {
        return isActiveProposal[proposalId];
    }
    
    function recordExpense(
        bytes32 budgetId,
        address asset,
        uint256 amount,
        string calldata category,
        string calldata description
    ) external override {
        require(isBudgetActive[budgetId], "Budget not active");
        require(isAuthorizedSpender[msg.sender], "Not authorized spender");
        require(amount > 0, "Invalid amount");
        
        Budget storage budget = budgets[budgetId];
        require(budget.isActive, "Budget inactive");
        require(block.timestamp <= budget.expiresAt, "Budget expired");
        
        // Find asset index in budget
        uint256 assetIndex = type(uint256).max;
        for (uint256 i = 0; i < budget.assets.length; i++) {
            if (budget.assets[i] == asset) {
                assetIndex = i;
                break;
            }
        }
        require(assetIndex != type(uint256).max, "Asset not in budget");
        require(budget.spent[assetIndex] + amount <= budget.amounts[assetIndex], "Budget exceeded");
        
        budget.spent[assetIndex] += amount;
        
        emit BudgetSpent(budgetId, msg.sender, asset, amount, category, block.timestamp);
    }
    
    function getTotalReserves() external view override returns (uint256) {
        return totalReserves;
    }
    
    function getTotalAllocated() external view override returns (uint256) {
        return totalAllocated;
    }
    
    function getProposalVotes(bytes32 proposalId) external view override returns (uint256 votesFor, uint256 votesAgainst) {
        TreasuryProposal storage proposal = treasuryProposals[proposalId];
        return (proposal.votesFor, proposal.votesAgainst);
    }
    
    function cancelProposal(bytes32 proposalId) external override {
        require(isActiveProposal[proposalId], "Proposal not active");
        TreasuryProposal storage proposal = treasuryProposals[proposalId];
        require(proposal.proposer == msg.sender || hasRole(TREASURY_MANAGER_ROLE, msg.sender), "Not authorized");
        require(proposal.status == ProposalStatus.PENDING, "Proposal not pending");
        
        proposal.status = ProposalStatus.CANCELLED;
        proposal.cancelled = true;
        isActiveProposal[proposalId] = false;
        
        _removeFromPendingProposals(proposalId);
        
        emit ProposalCancelled(proposalId, msg.sender, block.timestamp);
    }
    
    function approveBudgetExpense(address spender, bytes32 expenseId) external override onlyRole(TREASURY_MANAGER_ROLE) {
        require(spender != address(0), "Invalid spender");
        require(expenses[spender].spender == spender, "Expense not found");
        
        expenses[spender].approved = true;
        
        emit BudgetSpent(expenses[spender].budgetId, spender, expenses[spender].asset, expenses[spender].amount, expenses[spender].category, block.timestamp);
    }
    
    function approveAuditReport(bytes32 auditId) external override onlyRole(TREASURY_MANAGER_ROLE) {
        require(auditReports[auditId].auditId == auditId, "Audit report not found");
        
        auditReports[auditId].status = AuditStatus.COMPLETED;
        
        emit AuditReportSubmitted(auditId, auditReports[auditId].auditor, auditReports[auditId].reportHash, auditReports[auditId].riskScore, block.timestamp);
    }

    // Receive function to accept ETH
    receive() external payable {
        emit EthReceived(msg.sender, msg.value, block.timestamp);
    }

    // Fallback function
    fallback() external payable {
        emit EthReceived(msg.sender, msg.value, block.timestamp);
    }
}
