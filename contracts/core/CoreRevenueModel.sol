// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./UnifiedLiquidityPool.sol";
// import "./APRCalculator.sol"; // APRCalculator functionality integrated into core contracts

/**
 * @title RevenueModel
 * @dev Comprehensive revenue management and profit-sharing system
 * Implements ethical DeFi revenue streams without interest-based mechanisms
 */
contract CoreRevenueModel is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using Math for uint256;

    // Revenue source types
    enum RevenueSource {
        TRADING_FEES,
        ARBITRAGE_PROFITS,
        LIQUIDATION_FEES,
        YIELD_FARMING,
        PARTNERSHIP_FEES,
        PERFORMANCE_FEES,
        WITHDRAWAL_FEES,
        REBALANCING_PROFITS
    }

    // Revenue stream configuration
    struct RevenueStream {
        RevenueSource source;
        uint256 feePercentage;     // Fee percentage in basis points
        uint256 totalCollected;    // Total revenue collected
        uint256 lastCollection;    // Last collection timestamp
        bool isActive;             // Whether stream is active
        address feeToken;          // Token for fee collection
        uint256 minThreshold;      // Minimum threshold for collection
    }

    // Profit sharing configuration
    struct ProfitSharing {
        uint256 userShare;         // User share percentage (basis points)
        uint256 protocolShare;     // Protocol share percentage
        uint256 developmentShare;  // Development fund share
        uint256 treasuryShare;     // Treasury share
        uint256 stakingRewards;    // Staking rewards share
    }

    // User profit tracking
    struct UserProfit {
        uint256 totalEarned;       // Total profit earned
        uint256 lastClaimed;       // Last claim timestamp
        uint256 pendingRewards;    // Pending unclaimed rewards
        uint256 lifetimeRewards;   // Lifetime rewards earned
        mapping(RevenueSource => uint256) sourceEarnings; // Earnings by source
    }

    // Revenue distribution event
    struct DistributionEvent {
        uint256 timestamp;
        uint256 totalRevenue;
        uint256 userDistribution;
        uint256 protocolFees;
        RevenueSource primarySource;
        uint256 participantCount;
    }

    // Partnership revenue sharing
    struct PartnershipRevenue {
        address partner;
        uint256 sharePercentage;   // Partner's share in basis points
        uint256 totalEarned;
        uint256 lastDistribution;
        bool isActive;
        string partnerType;        // "DEX", "LENDING", "YIELD", etc.
    }

    // Constants
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant MAX_FEE_PERCENTAGE = 1000; // 10% max fee
    uint256 public constant MIN_DISTRIBUTION_INTERVAL = 1 days;
    uint256 public constant MAX_PARTNERS = 50;

    // State variables
    UnifiedLiquidityPool public immutable liquidityPool;
    // APRCalculator public immutable aprCalculator; // Functionality integrated into core contracts
    
    // Revenue tracking
    mapping(RevenueSource => RevenueStream) public revenueStreams;
    mapping(address => UserProfit) public userProfits;
    mapping(address => PartnershipRevenue) public partnerships;
    
    // Distribution tracking
    DistributionEvent[] public distributionHistory;
    ProfitSharing public profitSharingConfig;
    
    // Revenue pools
    mapping(address => uint256) public revenuePool; // token => amount
    mapping(address => uint256) public pendingDistribution; // token => amount
    
    // Configuration
    uint256 public lastDistributionTime;
    uint256 public distributionInterval = 1 days;
    uint256 public minDistributionAmount = 100e18; // Minimum $100 equivalent
    
    // Partner management
    address[] public partnerList;
    uint256 public totalPartnerShares;
    
    // Treasury and development addresses
    address public treasuryAddress;
    address public developmentAddress;
    address public stakingRewardsAddress;
    
    // Events
    event RevenueCollected(
        RevenueSource indexed source,
        address indexed token,
        uint256 amount,
        uint256 timestamp
    );
    
    event ProfitDistributed(
        uint256 totalAmount,
        uint256 userShare,
        uint256 protocolShare,
        uint256 participantCount,
        uint256 timestamp
    );
    
    event UserRewardsClaimed(
        address indexed user,
        uint256 amount,
        address indexed token,
        uint256 timestamp
    );
    
    event PartnershipAdded(
        address indexed partner,
        uint256 sharePercentage,
        string partnerType
    );
    
    event RevenueStreamUpdated(
        RevenueSource indexed source,
        uint256 feePercentage,
        bool isActive
    );

    constructor(
        address _liquidityPool,
        // address _aprCalculator, // APRCalculator functionality integrated
        address _treasuryAddress,
        address _developmentAddress,
        address _stakingRewardsAddress,
        address initialOwner
    ) Ownable(initialOwner) {
        liquidityPool = UnifiedLiquidityPool(_liquidityPool);
        // aprCalculator = APRCalculator(_aprCalculator); // Functionality integrated
        treasuryAddress = _treasuryAddress;
        developmentAddress = _developmentAddress;
        stakingRewardsAddress = _stakingRewardsAddress;
        
        // Initialize default profit sharing configuration
        profitSharingConfig = ProfitSharing({
            userShare: 7000,        // 70% to users
            protocolShare: 1500,    // 15% to protocol
            developmentShare: 800,  // 8% to development
            treasuryShare: 500,     // 5% to treasury
            stakingRewards: 200     // 2% to staking rewards
        });
        
        // Initialize default revenue streams
        _initializeRevenueStreams();
        
        lastDistributionTime = block.timestamp;
    }

    /**
     * @dev Collect revenue from various sources
     */
    function collectRevenue(
        RevenueSource source,
        address token,
        uint256 amount
    ) external nonReentrant {
        require(amount > 0, "Amount must be positive");
        require(revenueStreams[source].isActive, "Revenue stream not active");
        
        // Revenue collected without transfer
        
        // Update revenue stream
        revenueStreams[source].totalCollected += amount;
        revenueStreams[source].lastCollection = block.timestamp;
        
        // Add to revenue pool
        revenuePool[token] += amount;
        pendingDistribution[token] += amount;
        
        emit RevenueCollected(source, token, amount, block.timestamp);
        
        // Auto-distribute if threshold met
        if (_shouldAutoDistribute(token)) {
            _distributeRevenue(token);
        }
    }

    /**
     * @dev Distribute accumulated revenue to stakeholders
     */
    function distributeRevenue(address token) external nonReentrant {
        require(
            block.timestamp >= lastDistributionTime + distributionInterval,
            "Distribution interval not met"
        );
        require(pendingDistribution[token] >= minDistributionAmount, "Below minimum threshold");
        
        _distributeRevenue(token);
    }

    /**
     * @dev Claim pending rewards for user
     */
    function claimRewards(address token) external nonReentrant {
        UserProfit storage userProfit = userProfits[msg.sender];
        require(userProfit.pendingRewards > 0, "No pending rewards");
        
        uint256 claimAmount = userProfit.pendingRewards;
        userProfit.pendingRewards = 0;
        userProfit.lastClaimed = block.timestamp;
        userProfit.lifetimeRewards += claimAmount;
        
        // Transfer rewards to user
        IERC20(token).safeTransfer(msg.sender, claimAmount);
        
        emit UserRewardsClaimed(msg.sender, claimAmount, token, block.timestamp);
    }

    /**
     * @dev Add new partnership for revenue sharing
     */
    function addPartnership(
        address partner,
        uint256 sharePercentage,
        string memory partnerType
    ) external onlyOwner {
        require(partner != address(0), "Invalid partner address");
        require(sharePercentage > 0 && sharePercentage <= 2000, "Invalid share percentage"); // Max 20%
        require(partnerList.length < MAX_PARTNERS, "Too many partners");
        require(!partnerships[partner].isActive, "Partner already exists");
        require(totalPartnerShares + sharePercentage <= 3000, "Total partner shares too high"); // Max 30%
        
        partnerships[partner] = PartnershipRevenue({
            partner: partner,
            sharePercentage: sharePercentage,
            totalEarned: 0,
            lastDistribution: block.timestamp,
            isActive: true,
            partnerType: partnerType
        });
        
        partnerList.push(partner);
        totalPartnerShares += sharePercentage;
        
        emit PartnershipAdded(partner, sharePercentage, partnerType);
    }

    /**
     * @dev Update revenue stream configuration
     */
    function updateRevenueStream(
        RevenueSource source,
        uint256 feePercentage,
        bool isActive,
        address feeToken,
        uint256 minThreshold
    ) external onlyOwner {
        require(feePercentage <= MAX_FEE_PERCENTAGE, "Fee percentage too high");
        
        RevenueStream storage stream = revenueStreams[source];
        stream.feePercentage = feePercentage;
        stream.isActive = isActive;
        stream.feeToken = feeToken;
        stream.minThreshold = minThreshold;
        
        emit RevenueStreamUpdated(source, feePercentage, isActive);
    }

    /**
     * @dev Update profit sharing configuration
     */
    function updateProfitSharing(
        uint256 userShare,
        uint256 protocolShare,
        uint256 developmentShare,
        uint256 treasuryShare,
        uint256 stakingRewards
    ) external onlyOwner {
        require(
            userShare + protocolShare + developmentShare + treasuryShare + stakingRewards == BASIS_POINTS,
            "Shares must sum to 100%"
        );
        require(userShare >= 5000, "User share too low"); // Minimum 50% to users
        
        profitSharingConfig = ProfitSharing({
            userShare: userShare,
            protocolShare: protocolShare,
            developmentShare: developmentShare,
            treasuryShare: treasuryShare,
            stakingRewards: stakingRewards
        });
    }

    /**
     * @dev Get user's pending rewards and earnings breakdown
     */
    function getUserRewardsInfo(address user) external view returns (
        uint256 pendingRewards,
        uint256 totalEarned,
        uint256 lifetimeRewards,
        uint256 lastClaimed,
        uint256[8] memory sourceEarnings // Earnings by each revenue source
    ) {
        UserProfit storage userProfit = userProfits[user];
        
        pendingRewards = userProfit.pendingRewards;
        totalEarned = userProfit.totalEarned;
        lifetimeRewards = userProfit.lifetimeRewards;
        lastClaimed = userProfit.lastClaimed;
        
        // Get earnings by source
        for (uint256 i = 0; i < 8; i++) {
            sourceEarnings[i] = userProfit.sourceEarnings[RevenueSource(i)];
        }
    }

    /**
     * @dev Get revenue analytics and metrics
     */
    function getRevenueAnalytics() external view returns (
        uint256 totalRevenueCollected,
        uint256 totalDistributed,
        uint256 pendingDistributionAmount,
        uint256 averageDailyRevenue,
        uint256 revenueGrowthRate,
        uint256 userParticipationRate
    ) {
        // Calculate total revenue across all sources
        for (uint256 i = 0; i < 8; i++) {
            totalRevenueCollected += revenueStreams[RevenueSource(i)].totalCollected;
        }
        
        // Calculate total distributed from history
        for (uint256 i = 0; i < distributionHistory.length; i++) {
            totalDistributed += distributionHistory[i].totalRevenue;
        }
        
        // Get pending distribution (example with main token)
        pendingDistributionAmount = pendingDistribution[address(0x1234)]; // Replace with actual token
        
        // Calculate average daily revenue (last 30 days)
        if (distributionHistory.length > 0) {
            uint256 recentRevenue = 0;
            uint256 recentDays = 0;
            uint256 cutoffTime = block.timestamp - 30 days;
            
            for (uint256 i = distributionHistory.length; i > 0; i--) {
                if (distributionHistory[i-1].timestamp >= cutoffTime) {
                    recentRevenue += distributionHistory[i-1].totalRevenue;
                    recentDays++;
                }
            }
            
            averageDailyRevenue = recentDays > 0 ? recentRevenue / recentDays : 0;
        }
        
        // Calculate growth rate (simplified)
        revenueGrowthRate = _calculateRevenueGrowthRate();
        
        // Calculate user participation rate
        userParticipationRate = _calculateUserParticipationRate();
    }

    /**
     * @dev Get partnership revenue breakdown
     */
    function getPartnershipBreakdown() external view returns (
        address[] memory partners,
        uint256[] memory sharePercentages,
        uint256[] memory totalEarnings,
        string[] memory partnerTypes
    ) {
        uint256 activePartners = 0;
        
        // Count active partners
        for (uint256 i = 0; i < partnerList.length; i++) {
            if (partnerships[partnerList[i]].isActive) {
                activePartners++;
            }
        }
        
        // Initialize arrays
        partners = new address[](activePartners);
        sharePercentages = new uint256[](activePartners);
        totalEarnings = new uint256[](activePartners);
        partnerTypes = new string[](activePartners);
        
        // Fill arrays with active partner data
        uint256 index = 0;
        for (uint256 i = 0; i < partnerList.length; i++) {
            address partner = partnerList[i];
            if (partnerships[partner].isActive) {
                partners[index] = partner;
                sharePercentages[index] = partnerships[partner].sharePercentage;
                totalEarnings[index] = partnerships[partner].totalEarned;
                partnerTypes[index] = partnerships[partner].partnerType;
                index++;
            }
        }
    }

    /**
     * @dev Simulate revenue projections
     */
    function simulateRevenueProjections(uint256 daysCount) external view returns (
        uint256 projectedDailyRevenue,
        uint256 projectedUserRewards,
        uint256 projectedProtocolFees,
        uint256 projectedPartnerPayouts,
        uint256 confidenceLevel
    ) {
        // Get current revenue metrics
        (, , , uint256 avgDaily, uint256 growthRate, ) = this.getRevenueAnalytics();
        
        // Project daily revenue with growth
        projectedDailyRevenue = avgDaily;
        if (growthRate > 0) {
            // Apply compound growth
            for (uint256 i = 0; i < daysCount; i++) {
                projectedDailyRevenue = (projectedDailyRevenue * (BASIS_POINTS + growthRate)) / BASIS_POINTS;
            }
            projectedDailyRevenue = projectedDailyRevenue / daysCount; // Average over period
        }
        
        // Calculate projected distributions
        projectedUserRewards = (projectedDailyRevenue * profitSharingConfig.userShare) / BASIS_POINTS;
        projectedProtocolFees = (projectedDailyRevenue * profitSharingConfig.protocolShare) / BASIS_POINTS;
        projectedPartnerPayouts = (projectedDailyRevenue * totalPartnerShares) / BASIS_POINTS;
        
        // Calculate confidence based on data availability and consistency
        confidenceLevel = _calculateProjectionConfidence();
    }

    // Internal functions
    function _distributeRevenue(address token) internal {
        uint256 totalAmount = pendingDistribution[token];
        require(totalAmount > 0, "No revenue to distribute");
        
        // Calculate distributions
        uint256 userDistribution = (totalAmount * profitSharingConfig.userShare) / BASIS_POINTS;
        uint256 protocolFees = (totalAmount * profitSharingConfig.protocolShare) / BASIS_POINTS;
        uint256 developmentFees = (totalAmount * profitSharingConfig.developmentShare) / BASIS_POINTS;
        uint256 treasuryFees = (totalAmount * profitSharingConfig.treasuryShare) / BASIS_POINTS;
        uint256 stakingFees = (totalAmount * profitSharingConfig.stakingRewards) / BASIS_POINTS;
        
        // Distribute to protocol addresses
        if (protocolFees > 0) {
            IERC20(token).safeTransfer(owner(), protocolFees);
        }
        if (developmentFees > 0) {
            IERC20(token).safeTransfer(developmentAddress, developmentFees);
        }
        if (treasuryFees > 0) {
            IERC20(token).safeTransfer(treasuryAddress, treasuryFees);
        }
        if (stakingFees > 0) {
            IERC20(token).safeTransfer(stakingRewardsAddress, stakingFees);
        }
        
        // Distribute to partners
        uint256 partnerDistribution = _distributeToPartners(token, totalAmount);
        
        // Distribute to users
        uint256 actualUserDistribution = userDistribution - partnerDistribution;
        _distributeToUsers(actualUserDistribution);
        
        // Record distribution event
        distributionHistory.push(DistributionEvent({
            timestamp: block.timestamp,
            totalRevenue: totalAmount,
            userDistribution: actualUserDistribution,
            protocolFees: protocolFees,
            primarySource: _getPrimaryRevenueSource(),
            participantCount: _getActiveUserCount()
        }));
        
        // Reset pending distribution
        pendingDistribution[token] = 0;
        lastDistributionTime = block.timestamp;
        
        emit ProfitDistributed(
            totalAmount,
            actualUserDistribution,
            protocolFees,
            _getActiveUserCount(),
            block.timestamp
        );
    }

    function _distributeToPartners(address token, uint256 totalAmount) internal returns (uint256) {
        uint256 totalPartnerDistribution = 0;
        
        for (uint256 i = 0; i < partnerList.length; i++) {
            address partner = partnerList[i];
            PartnershipRevenue storage partnerRevenue = partnerships[partner];
            
            if (partnerRevenue.isActive) {
                uint256 partnerAmount = (totalAmount * partnerRevenue.sharePercentage) / BASIS_POINTS;
                
                if (partnerAmount > 0) {
                    IERC20(token).safeTransfer(partner, partnerAmount);
                    partnerRevenue.totalEarned += partnerAmount;
                    partnerRevenue.lastDistribution = block.timestamp;
                    totalPartnerDistribution += partnerAmount;
                }
            }
        }
        
        return totalPartnerDistribution;
    }

    function _distributeToUsers(uint256 totalUserDistribution) internal view {
        // Get total value locked from liquidity pool
        uint256 totalValueLocked = liquidityPool.totalValueLocked();
        if (totalValueLocked == 0) return;
        
        // This is a simplified distribution - in practice, you'd iterate through users
        // For now, we'll track it for claiming later
        // Implementation would depend on how user tracking is done in the liquidity pool
    }

    function _shouldAutoDistribute(address token) internal view returns (bool) {
        return pendingDistribution[token] >= minDistributionAmount * 2 && // 2x threshold for auto
               block.timestamp >= lastDistributionTime + (distributionInterval / 2); // Half interval
    }

    function _initializeRevenueStreams() internal {
        // Initialize all revenue streams with default configurations
        revenueStreams[RevenueSource.TRADING_FEES] = RevenueStream({
            source: RevenueSource.TRADING_FEES,
            feePercentage: 30, // 0.3%
            totalCollected: 0,
            lastCollection: 0,
            isActive: true,
            feeToken: address(0),
            minThreshold: 10e18
        });
        
        revenueStreams[RevenueSource.ARBITRAGE_PROFITS] = RevenueStream({
            source: RevenueSource.ARBITRAGE_PROFITS,
            feePercentage: 500, // 5%
            totalCollected: 0,
            lastCollection: 0,
            isActive: true,
            feeToken: address(0),
            minThreshold: 50e18
        });
        
        revenueStreams[RevenueSource.LIQUIDATION_FEES] = RevenueStream({
            source: RevenueSource.LIQUIDATION_FEES,
            feePercentage: 200, // 2%
            totalCollected: 0,
            lastCollection: 0,
            isActive: true,
            feeToken: address(0),
            minThreshold: 25e18
        });
        
        revenueStreams[RevenueSource.YIELD_FARMING] = RevenueStream({
            source: RevenueSource.YIELD_FARMING,
            feePercentage: 1000, // 10%
            totalCollected: 0,
            lastCollection: 0,
            isActive: true,
            feeToken: address(0),
            minThreshold: 100e18
        });
        
        // Initialize other revenue streams...
    }

    function _getPrimaryRevenueSource() internal view returns (RevenueSource) {
        uint256 maxRevenue = 0;
        RevenueSource primarySource = RevenueSource.TRADING_FEES;
        
        for (uint256 i = 0; i < 8; i++) {
            RevenueSource source = RevenueSource(i);
            if (revenueStreams[source].totalCollected > maxRevenue) {
                maxRevenue = revenueStreams[source].totalCollected;
                primarySource = source;
            }
        }
        
        return primarySource;
    }

    function _getActiveUserCount() internal pure returns (uint256) {
        return 150; // Mock value - would get from liquidity pool
    }

    function _calculateRevenueGrowthRate() internal view returns (uint256) {
        if (distributionHistory.length < 2) return 0;
        
        // Simple growth calculation using last two periods
        uint256 latest = distributionHistory[distributionHistory.length - 1].totalRevenue;
        uint256 previous = distributionHistory[distributionHistory.length - 2].totalRevenue;
        
        if (previous == 0) return 0;
        
        return latest > previous ? 
            ((latest - previous) * BASIS_POINTS) / previous : 0;
    }

    function _calculateUserParticipationRate() internal pure returns (uint256) {
        // Mock calculation - would calculate based on active vs total users
        return 8500; // 85% participation rate
    }

    function _calculateProjectionConfidence() internal view returns (uint256) {
        // Base confidence on data availability
        uint256 dataPoints = distributionHistory.length;
        if (dataPoints < 7) return 3000; // Low confidence
        if (dataPoints < 30) return 6000; // Medium confidence
        return 8500; // High confidence
    }

    // Emergency functions
    function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
        IERC20(token).safeTransfer(owner(), amount);
    }

    function pauseRevenueStream(RevenueSource source) external onlyOwner {
        revenueStreams[source].isActive = false;
    }

    function unpauseRevenueStream(RevenueSource source) external onlyOwner {
        revenueStreams[source].isActive = true;
    }
}
