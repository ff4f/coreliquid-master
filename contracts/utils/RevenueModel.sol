// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title RevenueModel
 * @dev Manages revenue distribution and fee collection across the protocol
 */
contract RevenueModel is AccessControl, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;
    using Math for uint256;
    
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant REVENUE_MANAGER_ROLE = keccak256("REVENUE_MANAGER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    
    uint256 public constant PRECISION = 1e18;
    uint256 public constant MAX_FEE_RATE = 10e16; // 10%
    uint256 public constant BASIS_POINTS = 10000;
    
    // Revenue streams
    enum RevenueStream {
        TRADING_FEES,
        LENDING_INTEREST,
        STAKING_REWARDS,
        LIQUIDATION_FEES,
        PROTOCOL_FEES
    }
    
    // Revenue distribution configuration
    struct RevenueDistribution {
        uint256 treasuryShare; // Basis points
        uint256 stakersShare; // Basis points
        uint256 liquidityProvidersShare; // Basis points
        uint256 developmentShare; // Basis points
        uint256 reserveShare; // Basis points
        bool isActive;
    }
    
    // Revenue tracking
    struct RevenueData {
        uint256 totalCollected;
        uint256 totalDistributed;
        uint256 pendingDistribution;
        uint256 lastUpdateTimestamp;
        mapping(address => uint256) tokenBalances;
    }
    
    // Fee configuration
    struct FeeConfig {
        uint256 rate; // Basis points
        uint256 minAmount;
        uint256 maxAmount;
        bool isActive;
    }
    
    mapping(RevenueStream => RevenueData) public revenueStreams;
    mapping(RevenueStream => RevenueDistribution) public distributions;
    mapping(address => FeeConfig) public tokenFees;
    mapping(address => bool) public supportedTokens;
    
    // Addresses for revenue distribution
    address public treasury;
    address public stakingContract;
    address public liquidityPool;
    address public developmentFund;
    address public reserveFund;
    
    // Revenue tracking
    uint256 public totalRevenueCollected;
    uint256 public totalRevenueDistributed;
    
    // Events
    event RevenueCollected(
        RevenueStream indexed stream,
        address indexed token,
        uint256 amount,
        uint256 timestamp
    );
    
    event RevenueDistributed(
        RevenueStream indexed stream,
        address indexed token,
        uint256 amount,
        uint256 timestamp
    );
    
    event FeeConfigUpdated(
        address indexed token,
        uint256 rate,
        uint256 minAmount,
        uint256 maxAmount
    );
    
    event DistributionConfigUpdated(
        RevenueStream indexed stream,
        uint256 treasuryShare,
        uint256 stakersShare,
        uint256 liquidityProvidersShare
    );
    
    event AddressUpdated(string indexed role, address oldAddress, address newAddress);
    
    constructor(
        address _treasury,
        address _stakingContract,
        address _liquidityPool,
        address _developmentFund,
        address _reserveFund
    ) {
        require(_treasury != address(0), "RevenueModel: invalid treasury");
        require(_stakingContract != address(0), "RevenueModel: invalid staking contract");
        require(_liquidityPool != address(0), "RevenueModel: invalid liquidity pool");
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(REVENUE_MANAGER_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        
        treasury = _treasury;
        stakingContract = _stakingContract;
        liquidityPool = _liquidityPool;
        developmentFund = _developmentFund;
        reserveFund = _reserveFund;
        
        _initializeDefaultDistributions();
    }
    
    /**
     * @dev Collect revenue from a specific stream
     */
    function collectRevenue(
        RevenueStream stream,
        address token,
        uint256 amount
    ) external onlyRole(REVENUE_MANAGER_ROLE) nonReentrant whenNotPaused {
        require(supportedTokens[token], "RevenueModel: token not supported");
        require(amount > 0, "RevenueModel: invalid amount");
        
        RevenueData storage data = revenueStreams[stream];
        
        // Revenue collected without transfer
        
        // Update revenue tracking
        data.totalCollected += amount;
        data.pendingDistribution += amount;
        data.tokenBalances[token] += amount;
        data.lastUpdateTimestamp = block.timestamp;
        
        totalRevenueCollected += amount;
        
        emit RevenueCollected(stream, token, amount, block.timestamp);
    }
    
    /**
     * @dev Distribute revenue for a specific stream
     */
    function distributeRevenue(
        RevenueStream stream,
        address token
    ) external onlyRole(REVENUE_MANAGER_ROLE) nonReentrant whenNotPaused {
        require(supportedTokens[token], "RevenueModel: token not supported");
        
        RevenueData storage data = revenueStreams[stream];
        RevenueDistribution storage dist = distributions[stream];
        
        require(dist.isActive, "RevenueModel: distribution not active");
        require(data.pendingDistribution > 0, "RevenueModel: no pending distribution");
        require(data.tokenBalances[token] > 0, "RevenueModel: no token balance");
        
        uint256 amount = data.tokenBalances[token];
        
        // Calculate distribution amounts
        uint256 treasuryAmount = (amount * dist.treasuryShare) / BASIS_POINTS;
        uint256 stakersAmount = (amount * dist.stakersShare) / BASIS_POINTS;
        uint256 liquidityAmount = (amount * dist.liquidityProvidersShare) / BASIS_POINTS;
        uint256 developmentAmount = (amount * dist.developmentShare) / BASIS_POINTS;
        uint256 reserveAmount = (amount * dist.reserveShare) / BASIS_POINTS;
        
        // Distribute to respective addresses
        if (treasuryAmount > 0 && treasury != address(0)) {
            IERC20(token).safeTransfer(treasury, treasuryAmount);
        }
        
        if (stakersAmount > 0 && stakingContract != address(0)) {
            IERC20(token).safeTransfer(stakingContract, stakersAmount);
        }
        
        if (liquidityAmount > 0 && liquidityPool != address(0)) {
            IERC20(token).safeTransfer(liquidityPool, liquidityAmount);
        }
        
        if (developmentAmount > 0 && developmentFund != address(0)) {
            IERC20(token).safeTransfer(developmentFund, developmentAmount);
        }
        
        if (reserveAmount > 0 && reserveFund != address(0)) {
            IERC20(token).safeTransfer(reserveFund, reserveAmount);
        }
        
        // Update tracking
        data.totalDistributed += amount;
        data.pendingDistribution -= Math.min(data.pendingDistribution, amount);
        data.tokenBalances[token] = 0;
        
        totalRevenueDistributed += amount;
        
        emit RevenueDistributed(stream, token, amount, block.timestamp);
    }
    
    /**
     * @dev Calculate fee for a transaction
     */
    function calculateFee(
        address token,
        uint256 amount
    ) external view returns (uint256 fee) {
        if (!supportedTokens[token]) {
            return 0;
        }
        
        FeeConfig storage config = tokenFees[token];
        if (!config.isActive) {
            return 0;
        }
        
        fee = (amount * config.rate) / BASIS_POINTS;
        
        // Apply min/max limits
        if (config.minAmount > 0 && fee < config.minAmount) {
            fee = config.minAmount;
        }
        
        if (config.maxAmount > 0 && fee > config.maxAmount) {
            fee = config.maxAmount;
        }
        
        // Ensure fee doesn't exceed amount
        if (fee > amount) {
            fee = amount;
        }
    }
    
    /**
     * @dev Set fee configuration for a token
     */
    function setTokenFeeConfig(
        address token,
        uint256 rate,
        uint256 minAmount,
        uint256 maxAmount,
        bool isActive
    ) external onlyRole(ADMIN_ROLE) {
        require(token != address(0), "RevenueModel: invalid token");
        require(rate <= MAX_FEE_RATE, "RevenueModel: fee rate too high");
        
        tokenFees[token] = FeeConfig({
            rate: rate,
            minAmount: minAmount,
            maxAmount: maxAmount,
            isActive: isActive
        });
        
        if (!supportedTokens[token]) {
            supportedTokens[token] = true;
        }
        
        emit FeeConfigUpdated(token, rate, minAmount, maxAmount);
    }
    
    /**
     * @dev Set revenue distribution configuration
     */
    function setDistributionConfig(
        RevenueStream stream,
        uint256 treasuryShare,
        uint256 stakersShare,
        uint256 liquidityProvidersShare,
        uint256 developmentShare,
        uint256 reserveShare,
        bool isActive
    ) external onlyRole(ADMIN_ROLE) {
        uint256 totalShare = treasuryShare + stakersShare + liquidityProvidersShare + 
                           developmentShare + reserveShare;
        require(totalShare == BASIS_POINTS, "RevenueModel: invalid distribution shares");
        
        distributions[stream] = RevenueDistribution({
            treasuryShare: treasuryShare,
            stakersShare: stakersShare,
            liquidityProvidersShare: liquidityProvidersShare,
            developmentShare: developmentShare,
            reserveShare: reserveShare,
            isActive: isActive
        });
        
        emit DistributionConfigUpdated(
            stream,
            treasuryShare,
            stakersShare,
            liquidityProvidersShare
        );
    }
    
    /**
     * @dev Update treasury address
     */
    function setTreasury(address _treasury) external onlyRole(ADMIN_ROLE) {
        require(_treasury != address(0), "RevenueModel: invalid treasury");
        address oldTreasury = treasury;
        treasury = _treasury;
        emit AddressUpdated("treasury", oldTreasury, _treasury);
    }
    
    /**
     * @dev Update staking contract address
     */
    function setStakingContract(address _stakingContract) external onlyRole(ADMIN_ROLE) {
        require(_stakingContract != address(0), "RevenueModel: invalid staking contract");
        address oldStaking = stakingContract;
        stakingContract = _stakingContract;
        emit AddressUpdated("stakingContract", oldStaking, _stakingContract);
    }
    
    /**
     * @dev Update liquidity pool address
     */
    function setLiquidityPool(address _liquidityPool) external onlyRole(ADMIN_ROLE) {
        require(_liquidityPool != address(0), "RevenueModel: invalid liquidity pool");
        address oldPool = liquidityPool;
        liquidityPool = _liquidityPool;
        emit AddressUpdated("liquidityPool", oldPool, _liquidityPool);
    }
    
    /**
     * @dev Set supported token status
     */
    function setSupportedToken(address token, bool supported) external onlyRole(ADMIN_ROLE) {
        supportedTokens[token] = supported;
    }
    
    /**
     * @dev Get revenue stream data
     */
    function getRevenueStreamData(
        RevenueStream stream,
        address token
    ) external view returns (
        uint256 totalCollected,
        uint256 totalDistributed,
        uint256 pendingDistribution,
        uint256 tokenBalance,
        uint256 lastUpdateTimestamp
    ) {
        RevenueData storage data = revenueStreams[stream];
        return (
            data.totalCollected,
            data.totalDistributed,
            data.pendingDistribution,
            data.tokenBalances[token],
            data.lastUpdateTimestamp
        );
    }
    
    /**
     * @dev Simulate revenue projections
     */
    function simulateRevenueProjections(
        RevenueStream stream,
        uint256 daysCount,
        uint256 dailyVolume
    ) external view returns (uint256 projectedRevenue) {
        // Simple projection based on historical data and volume
        RevenueData storage data = revenueStreams[stream];
        
        if (data.lastUpdateTimestamp == 0) {
            return 0;
        }
        
        uint256 daysSinceStart = (block.timestamp - data.lastUpdateTimestamp) / 86400;
        if (daysSinceStart == 0) {
            daysSinceStart = 1;
        }
        
        uint256 avgDailyRevenue = data.totalCollected / daysSinceStart;
        
        // Adjust based on projected volume
        if (dailyVolume > 0) {
            projectedRevenue = (avgDailyRevenue * dailyVolume * daysCount) / 1e18;
        } else {
            projectedRevenue = avgDailyRevenue * daysCount;
        }
    }
    
    /**
     * @dev Initialize default distribution configurations
     */
    function _initializeDefaultDistributions() internal {
        // Trading fees: 40% treasury, 30% stakers, 20% LP, 5% dev, 5% reserve
        distributions[RevenueStream.TRADING_FEES] = RevenueDistribution({
            treasuryShare: 4000,
            stakersShare: 3000,
            liquidityProvidersShare: 2000,
            developmentShare: 500,
            reserveShare: 500,
            isActive: true
        });
        
        // Lending interest: 50% treasury, 25% stakers, 15% LP, 5% dev, 5% reserve
        distributions[RevenueStream.LENDING_INTEREST] = RevenueDistribution({
            treasuryShare: 5000,
            stakersShare: 2500,
            liquidityProvidersShare: 1500,
            developmentShare: 500,
            reserveShare: 500,
            isActive: true
        });
        
        // Staking rewards: 20% treasury, 60% stakers, 10% LP, 5% dev, 5% reserve
        distributions[RevenueStream.STAKING_REWARDS] = RevenueDistribution({
            treasuryShare: 2000,
            stakersShare: 6000,
            liquidityProvidersShare: 1000,
            developmentShare: 500,
            reserveShare: 500,
            isActive: true
        });
        
        // Liquidation fees: 60% treasury, 20% stakers, 10% LP, 5% dev, 5% reserve
        distributions[RevenueStream.LIQUIDATION_FEES] = RevenueDistribution({
            treasuryShare: 6000,
            stakersShare: 2000,
            liquidityProvidersShare: 1000,
            developmentShare: 500,
            reserveShare: 500,
            isActive: true
        });
        
        // Protocol fees: 70% treasury, 15% stakers, 5% LP, 5% dev, 5% reserve
        distributions[RevenueStream.PROTOCOL_FEES] = RevenueDistribution({
            treasuryShare: 7000,
            stakersShare: 1500,
            liquidityProvidersShare: 500,
            developmentShare: 500,
            reserveShare: 500,
            isActive: true
        });
    }
    
    /**
     * @dev Emergency function to recover stuck tokens
     */
    function emergencyWithdraw(
        address token,
        uint256 amount,
        address to
    ) external onlyRole(ADMIN_ROLE) {
        IERC20(token).safeTransfer(to, amount);
    }
    
    /**
     * @dev Pause the contract
     */
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }
    
    /**
     * @dev Unpause the contract
     */
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }
}
