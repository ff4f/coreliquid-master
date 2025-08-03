// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title YieldAggregator
 * @dev Aggregates yield from multiple DeFi protocols and strategies
 */
contract YieldAggregator is AccessControl, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;
    using Math for uint256;
    
    bytes32 public constant YIELD_MANAGER_ROLE = keccak256("YIELD_MANAGER_ROLE");
    bytes32 public constant STRATEGY_ROLE = keccak256("STRATEGY_ROLE");
    bytes32 public constant HARVESTER_ROLE = keccak256("HARVESTER_ROLE");
    bytes32 public constant KEEPER_ROLE = keccak256("KEEPER_ROLE");
    
    struct YieldSource {
        address protocol; // Protocol contract address
        address token; // Yield token
        string name;
        string protocolName;
        uint256 allocation; // Allocation percentage in basis points
        uint256 maxAllocation; // Maximum allocation allowed
        uint256 minAllocation; // Minimum allocation required
        uint256 totalDeposited;
        uint256 totalHarvested;
        uint256 lastHarvest;
        uint256 apy; // Annual Percentage Yield
        uint256 tvl; // Total Value Locked
        bool isActive;
        bool isEmergencyExit;
        uint8 riskLevel; // 1-10 risk scale
    }
    
    struct HarvestData {
        uint256 timestamp;
        address source;
        uint256 amount;
        uint256 gasUsed;
        uint256 profit;
        bool successful;
    }
    
    struct AllocationStrategy {
        uint256 riskTolerance; // 1-10 scale
        uint256 yieldTarget; // Target APY in basis points
        uint256 maxSingleAllocation; // Max allocation to single source
        uint256 rebalanceThreshold; // Threshold for rebalancing
        bool autoRebalance;
        bool emergencyMode;
    }
    
    struct UserPosition {
        uint256 totalDeposited;
        uint256 totalWithdrawn;
        uint256 totalYieldEarned;
        uint256 lastDeposit;
        uint256 lastWithdraw;
        uint256 shares;
        mapping(address => uint256) sourceAllocations;
    }
    
    struct ProtocolMetrics {
        uint256 totalTVL;
        uint256 averageAPY;
        uint256 totalHarvested;
        uint256 totalUsers;
        uint256 lastUpdate;
        uint256 riskScore;
        bool isHealthy;
    }
    
    mapping(address => YieldSource) public yieldSources;
    mapping(uint256 => address) public sourceList;
    mapping(address => uint256) public sourceIndex;
    mapping(address => UserPosition) public userPositions;
    mapping(uint256 => HarvestData) public harvestHistory;
    mapping(address => ProtocolMetrics) public protocolMetrics;
    mapping(address => bool) public authorizedProtocols;
    
    uint256 public sourcesCount;
    uint256 public totalAssets;
    uint256 public totalShares;
    uint256 public harvestHistoryLength;
    uint256 public lastGlobalHarvest;
    uint256 public totalYieldGenerated;
    
    AllocationStrategy public strategy;
    
    address public treasury;
    address public feeRecipient;
    uint256 public performanceFee; // Performance fee in basis points
    uint256 public managementFee; // Management fee in basis points
    
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant MAX_SOURCES = 50;
    uint256 public constant MAX_PERFORMANCE_FEE = 2000; // 20%
    uint256 public constant MAX_MANAGEMENT_FEE = 200; // 2%
    uint256 public constant HARVEST_HISTORY_LIMIT = 1000;
    uint256 public constant MIN_HARVEST_AMOUNT = 1e15; // 0.001 tokens
    
    event YieldSourceAdded(
        address indexed protocol,
        address indexed token,
        string name,
        uint256 allocation
    );
    
    event YieldSourceRemoved(
        address indexed protocol,
        uint256 timestamp
    );
    
    event YieldHarvested(
        address indexed source,
        uint256 amount,
        uint256 profit,
        uint256 fee,
        uint256 timestamp
    );
    
    event AllocationUpdated(
        address indexed source,
        uint256 oldAllocation,
        uint256 newAllocation
    );
    
    event Deposited(
        address indexed user,
        uint256 amount,
        uint256 shares
    );
    
    event Withdrawn(
        address indexed user,
        uint256 amount,
        uint256 shares,
        uint256 yield
    );
    
    event Rebalanced(
        uint256 timestamp,
        uint256 totalAssets,
        uint256 sourcesRebalanced
    );
    
    event EmergencyExit(
        address indexed source,
        uint256 amount,
        uint256 timestamp
    );
    
    event StrategyUpdated(
        uint256 riskTolerance,
        uint256 yieldTarget,
        bool autoRebalance
    );
    
    modifier validSource(address source) {
        require(yieldSources[source].protocol != address(0), "Source not found");
        _;
    }
    
    modifier onlyAuthorizedProtocol() {
        require(authorizedProtocols[msg.sender], "Not authorized protocol");
        _;
    }
    
    constructor(
        AllocationStrategy memory _strategy,
        address _treasury,
        address _feeRecipient,
        uint256 _performanceFee,
        uint256 _managementFee
    ) {
        require(_treasury != address(0), "Invalid treasury");
        require(_feeRecipient != address(0), "Invalid fee recipient");
        require(_performanceFee <= MAX_PERFORMANCE_FEE, "Performance fee too high");
        require(_managementFee <= MAX_MANAGEMENT_FEE, "Management fee too high");
        
        strategy = _strategy;
        treasury = _treasury;
        feeRecipient = _feeRecipient;
        performanceFee = _performanceFee;
        managementFee = _managementFee;
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(YIELD_MANAGER_ROLE, msg.sender);
        _grantRole(STRATEGY_ROLE, msg.sender);
        _grantRole(HARVESTER_ROLE, msg.sender);
        _grantRole(KEEPER_ROLE, msg.sender);
        
        lastGlobalHarvest = block.timestamp;
    }
    
    function addYieldSource(
        address protocol,
        address token,
        string memory name,
        string memory protocolName,
        uint256 allocation,
        uint256 maxAllocation,
        uint256 minAllocation,
        uint8 riskLevel
    ) external onlyRole(YIELD_MANAGER_ROLE) {
        require(protocol != address(0), "Invalid protocol");
        require(token != address(0), "Invalid token");
        require(yieldSources[protocol].protocol == address(0), "Source already exists");
        require(sourcesCount < MAX_SOURCES, "Too many sources");
        require(allocation <= maxAllocation, "Allocation exceeds maximum");
        require(minAllocation <= maxAllocation, "Invalid allocation range");
        require(riskLevel >= 1 && riskLevel <= 10, "Invalid risk level");
        
        // Check total allocation
        uint256 totalAllocation = _getTotalAllocation() + allocation;
        require(totalAllocation <= BASIS_POINTS, "Total allocation exceeds 100%");
        
        yieldSources[protocol] = YieldSource({
            protocol: protocol,
            token: token,
            name: name,
            protocolName: protocolName,
            allocation: allocation,
            maxAllocation: maxAllocation,
            minAllocation: minAllocation,
            totalDeposited: 0,
            totalHarvested: 0,
            lastHarvest: block.timestamp,
            apy: 0,
            tvl: 0,
            isActive: true,
            isEmergencyExit: false,
            riskLevel: riskLevel
        });
        
        sourceList[sourcesCount] = protocol;
        sourceIndex[protocol] = sourcesCount;
        sourcesCount++;
        
        authorizedProtocols[protocol] = true;
        
        emit YieldSourceAdded(protocol, token, name, allocation);
    }
    
    function removeYieldSource(address source) external onlyRole(YIELD_MANAGER_ROLE) validSource(source) {
        // First harvest any pending yield
        _harvestFromSource(source);
        
        // Withdraw all funds
        _withdrawFromSource(source, type(uint256).max);
        
        // Remove from arrays
        uint256 index = sourceIndex[source];
        if (index < sourcesCount - 1) {
            address lastSource = sourceList[sourcesCount - 1];
            sourceList[index] = lastSource;
            sourceIndex[lastSource] = index;
        }
        
        // Clean up
        delete yieldSources[source];
        delete sourceIndex[source];
        delete sourceList[sourcesCount - 1];
        delete authorizedProtocols[source];
        sourcesCount--;
        
        emit YieldSourceRemoved(source, block.timestamp);
    }
    
    function deposit(uint256 amount) external nonReentrant whenNotPaused {
        require(amount > 0, "Invalid amount");
        require(!strategy.emergencyMode, "Emergency mode active");
        
        // Transfer tokens from user
        // Note: Assuming a base token for simplicity
        // In production, this would handle multiple tokens
        
        // Calculate shares to mint
        uint256 shares = _calculateShares(amount);
        
        // Update user position
        UserPosition storage position = userPositions[msg.sender];
        position.totalDeposited += amount;
        position.lastDeposit = block.timestamp;
        position.shares += shares;
        
        // Update global state
        totalAssets += amount;
        totalShares += shares;
        
        // Allocate funds to yield sources
        _allocateFunds(amount);
        
        emit Deposited(msg.sender, amount, shares);
    }
    
    function withdraw(uint256 shares) external nonReentrant whenNotPaused {
        require(shares > 0, "Invalid shares");
        
        UserPosition storage position = userPositions[msg.sender];
        require(position.shares >= shares, "Insufficient shares");
        
        // Calculate withdrawal amount
        uint256 amount = _calculateWithdrawalAmount(shares);
        
        // Harvest yield before withdrawal
        uint256 yieldEarned = _harvestUserYield(msg.sender, shares);
        
        // Withdraw funds from sources if needed
        uint256 availableBalance = _getAvailableBalance();
        if (availableBalance < amount) {
            _withdrawFromSources(amount - availableBalance);
        }
        
        // Update user position
        position.shares -= shares;
        position.totalWithdrawn += amount;
        position.totalYieldEarned += yieldEarned;
        position.lastWithdraw = block.timestamp;
        
        // Update global state
        totalShares -= shares;
        totalAssets = totalAssets > amount ? totalAssets - amount : 0;
        
        // Transfer tokens to user
        // Note: Implementation depends on token handling strategy
        
        emit Withdrawn(msg.sender, amount, shares, yieldEarned);
    }
    
    function harvestAll() external onlyRole(HARVESTER_ROLE) nonReentrant whenNotPaused {
        uint256 totalHarvested = 0;
        uint256 totalProfit = 0;
        
        for (uint256 i = 0; i < sourcesCount; i++) {
            address source = sourceList[i];
            YieldSource storage yieldSource = yieldSources[source];
            
            if (!yieldSource.isActive || yieldSource.isEmergencyExit) {
                continue;
            }
            
            (uint256 harvested, uint256 profit) = _harvestFromSource(source);
            totalHarvested += harvested;
            totalProfit += profit;
        }
        
        // Update global harvest time
        lastGlobalHarvest = block.timestamp;
        totalYieldGenerated += totalProfit;
        
        // Trigger rebalance if needed
        if (strategy.autoRebalance && _shouldRebalance()) {
            _rebalance();
        }
    }
    
    function harvestSource(address source) external onlyRole(HARVESTER_ROLE) nonReentrant whenNotPaused validSource(source) {
        _harvestFromSource(source);
    }
    
    function rebalance() external onlyRole(KEEPER_ROLE) nonReentrant whenNotPaused {
        require(!strategy.emergencyMode, "Emergency mode active");
        _rebalance();
    }
    
    function updateAllocation(
        address source,
        uint256 newAllocation
    ) external onlyRole(STRATEGY_ROLE) validSource(source) {
        YieldSource storage yieldSource = yieldSources[source];
        require(newAllocation <= yieldSource.maxAllocation, "Allocation exceeds maximum");
        require(newAllocation >= yieldSource.minAllocation, "Allocation below minimum");
        
        // Check total allocation
        uint256 totalAllocation = _getTotalAllocation() - yieldSource.allocation + newAllocation;
        require(totalAllocation <= BASIS_POINTS, "Total allocation exceeds 100%");
        
        uint256 oldAllocation = yieldSource.allocation;
        yieldSource.allocation = newAllocation;
        
        emit AllocationUpdated(source, oldAllocation, newAllocation);
        
        // Trigger rebalance if auto-rebalance is enabled
        if (strategy.autoRebalance) {
            _rebalanceSource(source, oldAllocation, newAllocation);
        }
    }
    
    function setSourceActive(
        address source,
        bool active
    ) external onlyRole(YIELD_MANAGER_ROLE) validSource(source) {
        yieldSources[source].isActive = active;
        
        if (!active) {
            // Harvest and withdraw all funds from inactive source
            _harvestFromSource(source);
            _withdrawFromSource(source, type(uint256).max);
        }
    }
    
    function emergencyExit(address source) external onlyRole(DEFAULT_ADMIN_ROLE) validSource(source) {
        YieldSource storage yieldSource = yieldSources[source];
        yieldSource.isEmergencyExit = true;
        yieldSource.isActive = false;
        
        // Attempt to withdraw all funds
        uint256 amount = _withdrawFromSource(source, type(uint256).max);
        
        emit EmergencyExit(source, amount, block.timestamp);
    }
    
    function emergencyShutdown() external onlyRole(DEFAULT_ADMIN_ROLE) {
        strategy.emergencyMode = true;
        
        // Exit all sources
        for (uint256 i = 0; i < sourcesCount; i++) {
            address source = sourceList[i];
            if (yieldSources[source].isActive) {
                try this.emergencyExit(source) {
                    // Emergency exit successful
                } catch {
                    // Continue with other sources
                }
            }
        }
    }
    
    function _allocateFunds(uint256 amount) internal {
        uint256 remainingAmount = amount;
        
        // Allocate based on current allocation percentages
        for (uint256 i = 0; i < sourcesCount && remainingAmount > 0; i++) {
            address source = sourceList[i];
            YieldSource storage yieldSource = yieldSources[source];
            
            if (!yieldSource.isActive || yieldSource.isEmergencyExit) {
                continue;
            }
            
            uint256 allocationAmount = (amount * yieldSource.allocation) / BASIS_POINTS;
            allocationAmount = Math.min(allocationAmount, remainingAmount);
            
            if (allocationAmount > 0) {
                _depositToSource(source, allocationAmount);
                remainingAmount -= allocationAmount;
            }
        }
    }
    
    function _withdrawFromSources(uint256 amount) internal {
        uint256 remainingAmount = amount;
        
        // Withdraw from sources in reverse order of risk (safest first)
        for (uint256 i = sourcesCount; i > 0 && remainingAmount > 0; i--) {
            address source = sourceList[i - 1];
            YieldSource storage yieldSource = yieldSources[source];
            
            if (!yieldSource.isActive) {
                continue;
            }
            
            uint256 sourceBalance = _getSourceBalance(source);
            uint256 withdrawAmount = Math.min(remainingAmount, sourceBalance);
            
            if (withdrawAmount > 0) {
                _withdrawFromSource(source, withdrawAmount);
                remainingAmount -= withdrawAmount;
            }
        }
    }
    
    function _harvestFromSource(address source) internal returns (uint256 harvested, uint256 profit) {
        YieldSource storage yieldSource = yieldSources[source];
        
        uint256 beforeBalance = _getSourceBalance(source);
        
        // Call protocol-specific harvest function
        // This would be implemented based on each protocol's interface
        // For now, we'll simulate the harvest
        
        uint256 afterBalance = _getSourceBalance(source);
        harvested = afterBalance > beforeBalance ? afterBalance - beforeBalance : 0;
        
        if (harvested >= MIN_HARVEST_AMOUNT) {
            // Calculate performance fee
            uint256 fee = (harvested * performanceFee) / BASIS_POINTS;
            profit = harvested - fee;
            
            // Update source data
            yieldSource.totalHarvested += harvested;
            yieldSource.lastHarvest = block.timestamp;
            
            // Store harvest data
            harvestHistory[harvestHistoryLength] = HarvestData({
                timestamp: block.timestamp,
                source: source,
                amount: harvested,
                gasUsed: 0, // Would be calculated in real implementation
                profit: profit,
                successful: true
            });
            
            harvestHistoryLength++;
            
            // Limit history size
            if (harvestHistoryLength > HARVEST_HISTORY_LIMIT) {
                // Shift array (simplified)
                for (uint256 i = 0; i < HARVEST_HISTORY_LIMIT - 1; i++) {
                    harvestHistory[i] = harvestHistory[i + 1];
                }
                harvestHistoryLength = HARVEST_HISTORY_LIMIT;
            }
            
            emit YieldHarvested(source, harvested, profit, fee, block.timestamp);
        }
    }
    
    function _harvestUserYield(address user, uint256 shares) internal view returns (uint256) {
        // Calculate user's share of total yield
        uint256 userShare = (shares * BASIS_POINTS) / totalShares;
        uint256 yieldEarned = (totalYieldGenerated * userShare) / BASIS_POINTS;
        
        return yieldEarned;
    }
    
    function _rebalance() internal {
        uint256 currentTotalAssets = _calculateTotalAssets();
        uint256 sourcesRebalanced = 0;
        
        for (uint256 i = 0; i < sourcesCount; i++) {
            address source = sourceList[i];
            YieldSource storage yieldSource = yieldSources[source];
            
            if (!yieldSource.isActive || yieldSource.isEmergencyExit) {
                continue;
            }
            
            uint256 targetAmount = (currentTotalAssets * yieldSource.allocation) / BASIS_POINTS;
            uint256 currentAmount = _getSourceBalance(source);
            
            if (_shouldRebalanceSource(currentAmount, targetAmount)) {
                if (currentAmount > targetAmount) {
                    _withdrawFromSource(source, currentAmount - targetAmount);
                } else {
                    uint256 availableBalance = _getAvailableBalance();
                    uint256 depositAmount = Math.min(targetAmount - currentAmount, availableBalance);
                    if (depositAmount > 0) {
                        _depositToSource(source, depositAmount);
                    }
                }
                sourcesRebalanced++;
            }
        }
        
        emit Rebalanced(block.timestamp, currentTotalAssets, sourcesRebalanced);
    }
    
    function _rebalanceSource(
        address source,
        uint256 oldAllocation,
        uint256 newAllocation
    ) internal {
        uint256 currentBalance = _getSourceBalance(source);
        uint256 targetBalance = (totalAssets * newAllocation) / BASIS_POINTS;
        
        if (currentBalance > targetBalance) {
            _withdrawFromSource(source, currentBalance - targetBalance);
        } else if (currentBalance < targetBalance) {
            uint256 availableBalance = _getAvailableBalance();
            uint256 depositAmount = Math.min(targetBalance - currentBalance, availableBalance);
            if (depositAmount > 0) {
                _depositToSource(source, depositAmount);
            }
        }
    }
    
    function _depositToSource(address source, uint256 amount) internal {
        YieldSource storage yieldSource = yieldSources[source];
        
        // Protocol-specific deposit logic would go here
        // For now, we'll just update the accounting
        yieldSource.totalDeposited += amount;
    }
    
    function _withdrawFromSource(address source, uint256 amount) internal returns (uint256) {
        YieldSource storage yieldSource = yieldSources[source];
        
        uint256 sourceBalance = _getSourceBalance(source);
        uint256 withdrawAmount = Math.min(amount, sourceBalance);
        
        if (withdrawAmount > 0) {
            // Protocol-specific withdrawal logic would go here
            // For now, we'll just update the accounting
            yieldSource.totalDeposited = yieldSource.totalDeposited > withdrawAmount ? 
                yieldSource.totalDeposited - withdrawAmount : 0;
        }
        
        return withdrawAmount;
    }
    
    function _shouldRebalance() internal view returns (bool) {
        // Check if any source deviates significantly from target allocation
        for (uint256 i = 0; i < sourcesCount; i++) {
            address source = sourceList[i];
            YieldSource memory yieldSource = yieldSources[source];
            
            if (!yieldSource.isActive) continue;
            
            uint256 currentAmount = _getSourceBalance(source);
            uint256 targetAmount = (totalAssets * yieldSource.allocation) / BASIS_POINTS;
            
            if (_shouldRebalanceSource(currentAmount, targetAmount)) {
                return true;
            }
        }
        
        return false;
    }
    
    function _shouldRebalanceSource(uint256 current, uint256 target) internal view returns (bool) {
        if (target == 0) return current > 0;
        
        uint256 deviation = current > target ? current - target : target - current;
        uint256 deviationPercentage = (deviation * BASIS_POINTS) / target;
        
        return deviationPercentage >= strategy.rebalanceThreshold;
    }
    
    function _calculateShares(uint256 amount) internal view returns (uint256) {
        if (totalShares == 0) {
            return amount;
        }
        return (amount * totalShares) / totalAssets;
    }
    
    function _calculateWithdrawalAmount(uint256 shares) internal view returns (uint256) {
        return (shares * totalAssets) / totalShares;
    }
    
    function _getTotalAllocation() internal view returns (uint256) {
        uint256 total = 0;
        for (uint256 i = 0; i < sourcesCount; i++) {
            total += yieldSources[sourceList[i]].allocation;
        }
        return total;
    }
    
    function _calculateTotalAssets() internal view returns (uint256) {
        uint256 total = _getAvailableBalance();
        
        for (uint256 i = 0; i < sourcesCount; i++) {
            address source = sourceList[i];
            if (yieldSources[source].isActive) {
                total += _getSourceBalance(source);
            }
        }
        
        return total;
    }
    
    function _getSourceBalance(address source) internal view returns (uint256) {
        // This would call the protocol-specific balance function
        // For now, return the deposited amount (simplified)
        return yieldSources[source].totalDeposited;
    }
    
    function _getAvailableBalance() internal pure returns (uint256) {
        // Return balance of base tokens held by this contract
        // Implementation depends on token handling strategy
        return 0;
    }
    
    // View functions
    function getYieldSource(address source) external view returns (YieldSource memory) {
        return yieldSources[source];
    }
    
    function getAllYieldSources() external view returns (address[] memory) {
        address[] memory sources = new address[](sourcesCount);
        for (uint256 i = 0; i < sourcesCount; i++) {
            sources[i] = sourceList[i];
        }
        return sources;
    }
    
    function getUserPosition(address user) external view returns (
        uint256 totalDeposited,
        uint256 totalWithdrawn,
        uint256 totalYieldEarned,
        uint256 shares,
        uint256 currentValue
    ) {
        UserPosition storage position = userPositions[user];
        totalDeposited = position.totalDeposited;
        totalWithdrawn = position.totalWithdrawn;
        totalYieldEarned = position.totalYieldEarned;
        shares = position.shares;
        currentValue = _calculateWithdrawalAmount(shares);
    }
    
    function getTotalAssets() external view returns (uint256) {
        return _calculateTotalAssets();
    }
    
    function getHarvestHistory(uint256 limit) external view returns (HarvestData[] memory) {
        if (limit == 0 || limit > harvestHistoryLength) {
            limit = harvestHistoryLength;
        }
        
        HarvestData[] memory history = new HarvestData[](limit);
        
        for (uint256 i = 0; i < limit; i++) {
            uint256 index = harvestHistoryLength > limit ? 
                harvestHistoryLength - limit + i : i;
            history[i] = harvestHistory[index];
        }
        
        return history;
    }
    
    function getAverageAPY() external view returns (uint256) {
        if (sourcesCount == 0) return 0;
        
        uint256 totalWeightedAPY = 0;
        uint256 totalWeight = 0;
        
        for (uint256 i = 0; i < sourcesCount; i++) {
            address source = sourceList[i];
            YieldSource memory yieldSource = yieldSources[source];
            
            if (yieldSource.isActive) {
                totalWeightedAPY += yieldSource.apy * yieldSource.allocation;
                totalWeight += yieldSource.allocation;
            }
        }
        
        return totalWeight > 0 ? totalWeightedAPY / totalWeight : 0;
    }
    
    // Admin functions
    function updateStrategy(
        AllocationStrategy memory newStrategy
    ) external onlyRole(STRATEGY_ROLE) {
        strategy = newStrategy;
        
        emit StrategyUpdated(
            newStrategy.riskTolerance,
            newStrategy.yieldTarget,
            newStrategy.autoRebalance
        );
    }
    
    function updateFees(
        uint256 _performanceFee,
        uint256 _managementFee
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_performanceFee <= MAX_PERFORMANCE_FEE, "Performance fee too high");
        require(_managementFee <= MAX_MANAGEMENT_FEE, "Management fee too high");
        
        performanceFee = _performanceFee;
        managementFee = _managementFee;
    }
    
    function setTreasury(address _treasury) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_treasury != address(0), "Invalid treasury");
        treasury = _treasury;
    }
    
    function setFeeRecipient(address _feeRecipient) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_feeRecipient != address(0), "Invalid fee recipient");
        feeRecipient = _feeRecipient;
    }
    
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }
    
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
}
