// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title CoreRevenueModel
 * @dev Revenue distribution and fee management for the Core protocol
 */
contract CoreRevenueModel is Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;
    using Math for uint256;

    struct RevenueStream {
        string name;
        uint256 totalRevenue;
        uint256 distributedRevenue;
        uint256 pendingRevenue;
        uint256 feeRate; // in basis points
        bool isActive;
        address revenueToken;
    }

    struct FeeStructure {
        uint256 protocolFee; // Protocol fee in basis points
        uint256 stakingRewards; // Staking rewards allocation in basis points
        uint256 liquidityIncentives; // Liquidity incentives in basis points
        uint256 treasury; // Treasury allocation in basis points
        uint256 development; // Development fund in basis points
        uint256 governance; // Governance rewards in basis points
    }

    struct RevenueDistribution {
        uint256 timestamp;
        uint256 totalAmount;
        uint256 protocolShare;
        uint256 stakingShare;
        uint256 liquidityShare;
        uint256 treasuryShare;
        uint256 developmentShare;
        uint256 governanceShare;
    }

    struct UserRevenueInfo {
        uint256 totalEarned;
        uint256 totalClaimed;
        uint256 pendingRewards;
        uint256 lastClaimTime;
        mapping(uint256 => uint256) streamRewards;
    }

    mapping(uint256 => RevenueStream) public revenueStreams;
    mapping(address => UserRevenueInfo) public userRevenueInfo;
    mapping(address => bool) public authorizedDistributors;
    mapping(uint256 => RevenueDistribution) public distributions;
    mapping(address => mapping(uint256 => uint256)) public userStreamClaimed;
    
    FeeStructure public feeStructure;
    
    uint256 public nextStreamId = 1;
    uint256 public nextDistributionId = 1;
    uint256 public totalRevenue;
    uint256 public totalDistributed;
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant MAX_FEE_RATE = 1000; // 10% max fee
    
    address public treasury;
    address public stakingContract;
    address public liquidityPool;
    address public developmentFund;
    address public governanceContract;
    
    bool public distributionEnabled = true;
    uint256 public minDistributionAmount = 1000 * 1e18; // 1000 tokens minimum
    uint256 public distributionInterval = 1 days;
    uint256 public lastDistributionTime;

    event RevenueStreamCreated(uint256 indexed streamId, string name, address token, uint256 feeRate);
    event RevenueStreamUpdated(uint256 indexed streamId, uint256 newFeeRate, bool isActive);
    event RevenueAdded(uint256 indexed streamId, uint256 amount, address token);
    event RevenueDistributed(uint256 indexed distributionId, uint256 totalAmount, uint256 timestamp);
    event RewardsClaimed(address indexed user, uint256 amount, address token);
    event FeeStructureUpdated(FeeStructure newStructure);
    event TreasuryUpdated(address indexed newTreasury);
    event StakingContractUpdated(address indexed newStaking);
    event LiquidityPoolUpdated(address indexed newPool);
    event DevelopmentFundUpdated(address indexed newFund);
    event GovernanceContractUpdated(address indexed newGovernance);
    event DistributionToggled(bool enabled);
    event MinDistributionAmountUpdated(uint256 newAmount);
    event DistributionIntervalUpdated(uint256 newInterval);

    modifier onlyAuthorizedDistributor() {
        require(authorizedDistributors[msg.sender] || msg.sender == owner(), "Not authorized distributor");
        _;
    }

    modifier validStreamId(uint256 streamId) {
        require(streamId > 0 && streamId < nextStreamId, "Invalid stream ID");
        _;
    }

    constructor(
        address _treasury,
        address _stakingContract,
        address _liquidityPool,
        address _developmentFund,
        address _governanceContract
    ) Ownable(msg.sender) {
        require(_treasury != address(0), "Invalid treasury");
        require(_stakingContract != address(0), "Invalid staking contract");
        require(_liquidityPool != address(0), "Invalid liquidity pool");
        require(_developmentFund != address(0), "Invalid development fund");
        require(_governanceContract != address(0), "Invalid governance contract");
        
        treasury = _treasury;
        stakingContract = _stakingContract;
        liquidityPool = _liquidityPool;
        developmentFund = _developmentFund;
        governanceContract = _governanceContract;
        
        // Initialize default fee structure
        feeStructure = FeeStructure({
            protocolFee: 1000,        // 10%
            stakingRewards: 4000,     // 40%
            liquidityIncentives: 2000, // 20%
            treasury: 1500,           // 15%
            development: 1000,        // 10%
            governance: 500           // 5%
        });
        
        lastDistributionTime = block.timestamp;
    }

    /**
     * @dev Create a new revenue stream
     * @param name Name of the revenue stream
     * @param token Token address for this stream
     * @param feeRate Fee rate in basis points
     * @return streamId ID of the created stream
     */
    function createRevenueStream(
        string memory name,
        address token,
        uint256 feeRate
    ) external onlyOwner returns (uint256 streamId) {
        require(bytes(name).length > 0, "Invalid name");
        require(token != address(0), "Invalid token");
        require(feeRate <= MAX_FEE_RATE, "Fee rate too high");
        
        streamId = nextStreamId++;
        
        revenueStreams[streamId] = RevenueStream({
            name: name,
            totalRevenue: 0,
            distributedRevenue: 0,
            pendingRevenue: 0,
            feeRate: feeRate,
            isActive: true,
            revenueToken: token
        });
        
        emit RevenueStreamCreated(streamId, name, token, feeRate);
    }

    /**
     * @dev Update revenue stream parameters
     * @param streamId Stream ID to update
     * @param newFeeRate New fee rate
     * @param isActive Active status
     */
    function updateRevenueStream(
        uint256 streamId,
        uint256 newFeeRate,
        bool isActive
    ) external onlyOwner validStreamId(streamId) {
        require(newFeeRate <= MAX_FEE_RATE, "Fee rate too high");
        
        RevenueStream storage stream = revenueStreams[streamId];
        stream.feeRate = newFeeRate;
        stream.isActive = isActive;
        
        emit RevenueStreamUpdated(streamId, newFeeRate, isActive);
    }

    /**
     * @dev Add revenue to a specific stream
     * @param streamId Stream ID to add revenue to
     * @param amount Amount of revenue to add
     */
    function addRevenue(
        uint256 streamId,
        uint256 amount
    ) external onlyAuthorizedDistributor validStreamId(streamId) {
        require(amount > 0, "Invalid amount");
        
        RevenueStream storage stream = revenueStreams[streamId];
        require(stream.isActive, "Stream not active");
        
        // Transfer tokens to contract
        IERC20(stream.revenueToken).safeTransferFrom(msg.sender, address(this), amount);
        
        // Update stream data
        stream.totalRevenue += amount;
        stream.pendingRevenue += amount;
        totalRevenue += amount;
        
        emit RevenueAdded(streamId, amount, stream.revenueToken);
        
        // Auto-distribute if conditions are met
        if (shouldDistribute()) {
            _distributeRevenue();
        }
    }

    /**
     * @dev Distribute pending revenue according to fee structure
     */
    function distributeRevenue() external onlyAuthorizedDistributor {
        require(distributionEnabled, "Distribution disabled");
        require(shouldDistribute(), "Distribution conditions not met");
        _distributeRevenue();
    }

    /**
     * @dev Internal revenue distribution logic
     */
    function _distributeRevenue() internal {
        uint256 totalPending = getTotalPendingRevenue();
        require(totalPending >= minDistributionAmount, "Amount below minimum");
        
        uint256 distributionId = nextDistributionId++;
        
        // Calculate distribution amounts
        uint256 protocolShare = totalPending * feeStructure.protocolFee / BASIS_POINTS;
        uint256 stakingShare = totalPending * feeStructure.stakingRewards / BASIS_POINTS;
        uint256 liquidityShare = totalPending * feeStructure.liquidityIncentives / BASIS_POINTS;
        uint256 treasuryShare = totalPending * feeStructure.treasury / BASIS_POINTS;
        uint256 developmentShare = totalPending * feeStructure.development / BASIS_POINTS;
        uint256 governanceShare = totalPending * feeStructure.governance / BASIS_POINTS;
        
        // Store distribution record
        distributions[distributionId] = RevenueDistribution({
            timestamp: block.timestamp,
            totalAmount: totalPending,
            protocolShare: protocolShare,
            stakingShare: stakingShare,
            liquidityShare: liquidityShare,
            treasuryShare: treasuryShare,
            developmentShare: developmentShare,
            governanceShare: governanceShare
        });
        
        // Distribute to different components
        _distributeToComponents(
            protocolShare,
            stakingShare,
            liquidityShare,
            treasuryShare,
            developmentShare,
            governanceShare
        );
        
        // Update stream states
        _updateStreamStates();
        
        totalDistributed += totalPending;
        lastDistributionTime = block.timestamp;
        
        emit RevenueDistributed(distributionId, totalPending, block.timestamp);
    }

    /**
     * @dev Distribute revenue to different protocol components
     */
    function _distributeToComponents(
        uint256 protocolShare,
        uint256 stakingShare,
        uint256 liquidityShare,
        uint256 treasuryShare,
        uint256 developmentShare,
        uint256 governanceShare
    ) internal {
        // Get the main revenue token (assuming CORE for now)
        address mainToken = getMainRevenueToken();
        
        if (stakingShare > 0) {
            IERC20(mainToken).safeTransfer(stakingContract, stakingShare);
        }
        
        if (liquidityShare > 0) {
            IERC20(mainToken).safeTransfer(liquidityPool, liquidityShare);
        }
        
        if (treasuryShare > 0) {
            IERC20(mainToken).safeTransfer(treasury, treasuryShare);
        }
        
        if (developmentShare > 0) {
            IERC20(mainToken).safeTransfer(developmentFund, developmentShare);
        }
        
        if (governanceShare > 0) {
            IERC20(mainToken).safeTransfer(governanceContract, governanceShare);
        }
        
        // Protocol share stays in contract for further distribution
    }

    /**
     * @dev Update stream states after distribution
     */
    function _updateStreamStates() internal {
        for (uint256 i = 1; i < nextStreamId; i++) {
            RevenueStream storage stream = revenueStreams[i];
            if (stream.pendingRevenue > 0) {
                stream.distributedRevenue += stream.pendingRevenue;
                stream.pendingRevenue = 0;
            }
        }
    }

    /**
     * @dev Claim user rewards from revenue distribution
     * @param streamId Stream ID to claim from
     */
    function claimRewards(uint256 streamId) external nonReentrant validStreamId(streamId) {
        UserRevenueInfo storage userInfo = userRevenueInfo[msg.sender];
        uint256 claimableAmount = getClaimableRewards(msg.sender, streamId);
        
        require(claimableAmount > 0, "No rewards to claim");
        
        RevenueStream storage stream = revenueStreams[streamId];
        
        // Update user info
        userInfo.totalClaimed += claimableAmount;
        userInfo.lastClaimTime = block.timestamp;
        userStreamClaimed[msg.sender][streamId] += claimableAmount;
        
        // Transfer rewards
        IERC20(stream.revenueToken).safeTransfer(msg.sender, claimableAmount);
        
        emit RewardsClaimed(msg.sender, claimableAmount, stream.revenueToken);
    }

    /**
     * @dev Update fee structure
     * @param newStructure New fee structure
     */
    function updateFeeStructure(FeeStructure memory newStructure) external onlyOwner {
        require(
            newStructure.protocolFee + 
            newStructure.stakingRewards + 
            newStructure.liquidityIncentives + 
            newStructure.treasury + 
            newStructure.development + 
            newStructure.governance == BASIS_POINTS,
            "Invalid fee structure"
        );
        
        feeStructure = newStructure;
        emit FeeStructureUpdated(newStructure);
    }

    /**
     * @dev Set authorized distributor status
     * @param distributor Distributor address
     * @param authorized Authorization status
     */
    function setAuthorizedDistributor(address distributor, bool authorized) external onlyOwner {
        authorizedDistributors[distributor] = authorized;
    }

    /**
     * @dev Update treasury address
     * @param newTreasury New treasury address
     */
    function setTreasury(address newTreasury) external onlyOwner {
        require(newTreasury != address(0), "Invalid treasury");
        treasury = newTreasury;
        emit TreasuryUpdated(newTreasury);
    }

    /**
     * @dev Update staking contract address
     * @param newStaking New staking contract address
     */
    function setStakingContract(address newStaking) external onlyOwner {
        require(newStaking != address(0), "Invalid staking contract");
        stakingContract = newStaking;
        emit StakingContractUpdated(newStaking);
    }

    /**
     * @dev Update liquidity pool address
     * @param newPool New liquidity pool address
     */
    function setLiquidityPool(address newPool) external onlyOwner {
        require(newPool != address(0), "Invalid liquidity pool");
        liquidityPool = newPool;
        emit LiquidityPoolUpdated(newPool);
    }

    /**
     * @dev Update development fund address
     * @param newFund New development fund address
     */
    function setDevelopmentFund(address newFund) external onlyOwner {
        require(newFund != address(0), "Invalid development fund");
        developmentFund = newFund;
        emit DevelopmentFundUpdated(newFund);
    }

    /**
     * @dev Update governance contract address
     * @param newGovernance New governance contract address
     */
    function setGovernanceContract(address newGovernance) external onlyOwner {
        require(newGovernance != address(0), "Invalid governance contract");
        governanceContract = newGovernance;
        emit GovernanceContractUpdated(newGovernance);
    }

    /**
     * @dev Toggle distribution enabled/disabled
     * @param enabled Distribution enabled status
     */
    function setDistributionEnabled(bool enabled) external onlyOwner {
        distributionEnabled = enabled;
        emit DistributionToggled(enabled);
    }

    /**
     * @dev Update minimum distribution amount
     * @param newAmount New minimum amount
     */
    function setMinDistributionAmount(uint256 newAmount) external onlyOwner {
        minDistributionAmount = newAmount;
        emit MinDistributionAmountUpdated(newAmount);
    }

    /**
     * @dev Update distribution interval
     * @param newInterval New interval in seconds
     */
    function setDistributionInterval(uint256 newInterval) external onlyOwner {
        require(newInterval >= 1 hours, "Interval too short");
        distributionInterval = newInterval;
        emit DistributionIntervalUpdated(newInterval);
    }

    /**
     * @dev Check if distribution should occur
     * @return shouldDist True if distribution conditions are met
     */
    function shouldDistribute() public view returns (bool shouldDist) {
        return distributionEnabled && 
               block.timestamp >= lastDistributionTime + distributionInterval &&
               getTotalPendingRevenue() >= minDistributionAmount;
    }

    /**
     * @dev Get total pending revenue across all streams
     * @return totalPending Total pending revenue amount
     */
    function getTotalPendingRevenue() public view returns (uint256 totalPending) {
        for (uint256 i = 1; i < nextStreamId; i++) {
            totalPending += revenueStreams[i].pendingRevenue;
        }
    }

    /**
     * @dev Get claimable rewards for a user from a specific stream
     * @param user User address
     * @param streamId Stream ID
     * @return claimableAmount Claimable reward amount
     */
    function getClaimableRewards(address user, uint256 streamId) public view returns (uint256 claimableAmount) {
        // This is a simplified calculation - in practice, this would be based on
        // user's stake, participation, or other factors
        UserRevenueInfo storage userInfo = userRevenueInfo[user];
        RevenueStream storage stream = revenueStreams[streamId];
        
        if (stream.distributedRevenue == 0) return 0;
        
        // Calculate based on user's share (simplified)
        uint256 userShare = getUserShare(user, streamId);
        uint256 totalEarned = stream.distributedRevenue * userShare / BASIS_POINTS;
        uint256 alreadyClaimed = userStreamClaimed[user][streamId];
        
        return totalEarned > alreadyClaimed ? totalEarned - alreadyClaimed : 0;
    }

    /**
     * @dev Get user's share in a revenue stream
     * @param user User address
     * @param streamId Stream ID
     * @return userShare User's share in basis points
     */
    function getUserShare(address user, uint256 streamId) public view returns (uint256 userShare) {
        // This is a placeholder - actual implementation would depend on
        // staking amounts, liquidity provision, governance participation, etc.
        return 100; // 1% as example
    }

    /**
     * @dev Get main revenue token address
     * @return tokenAddress Main revenue token address
     */
    function getMainRevenueToken() public view returns (address tokenAddress) {
        // Return the token from the first active stream as main token
        for (uint256 i = 1; i < nextStreamId; i++) {
            if (revenueStreams[i].isActive) {
                return revenueStreams[i].revenueToken;
            }
        }
        return address(0);
    }

    /**
     * @dev Get revenue stream information
     * @param streamId Stream ID
     * @return stream Revenue stream data
     */
    function getRevenueStream(uint256 streamId) external view returns (RevenueStream memory stream) {
        return revenueStreams[streamId];
    }

    /**
     * @dev Get distribution information
     * @param distributionId Distribution ID
     * @return distribution Distribution data
     */
    function getDistribution(uint256 distributionId) external view returns (RevenueDistribution memory distribution) {
        return distributions[distributionId];
    }

    /**
     * @dev Get user revenue information
     * @param user User address
     * @return totalEarned Total earned amount
     * @return totalClaimed Total claimed amount
     * @return pendingRewards Pending rewards
     * @return lastClaimTime Last claim timestamp
     */
    function getUserRevenueInfo(address user) external view returns (
        uint256 totalEarned,
        uint256 totalClaimed,
        uint256 pendingRewards,
        uint256 lastClaimTime
    ) {
        UserRevenueInfo storage info = userRevenueInfo[user];
        return (info.totalEarned, info.totalClaimed, info.pendingRewards, info.lastClaimTime);
    }

    /**
     * @dev Pause contract
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev Unpause contract
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @dev Emergency token recovery
     * @param token Token to recover
     * @param amount Amount to recover
     */
    function emergencyRecovery(address token, uint256 amount) external onlyOwner {
        IERC20(token).safeTransfer(owner(), amount);
    }
}