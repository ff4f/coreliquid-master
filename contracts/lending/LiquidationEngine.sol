// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./CollateralManager.sol";
import "./BorrowEngine.sol";

/**
 * @title LiquidationEngine
 * @dev Handles liquidation of undercollateralized positions
 */
contract LiquidationEngine is AccessControl, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;
    using Math for uint256;
    
    bytes32 public constant LIQUIDATOR_ROLE = keccak256("LIQUIDATOR_ROLE");
    bytes32 public constant KEEPER_ROLE = keccak256("KEEPER_ROLE");
    bytes32 public constant RISK_MANAGER_ROLE = keccak256("RISK_MANAGER_ROLE");
    
    struct LiquidationConfig {
        uint256 liquidationPenalty; // Penalty for liquidation (basis points)
        uint256 liquidatorReward; // Reward for liquidator (basis points)
        uint256 protocolFee; // Protocol fee from liquidation (basis points)
        uint256 maxLiquidationAmount; // Maximum amount that can be liquidated at once
        uint256 minCollateralRatio; // Minimum collateral ratio to avoid liquidation
        uint256 gracePeriod; // Grace period before liquidation (seconds)
        bool isEnabled; // Whether liquidation is enabled for this market
        bool requiresAuction; // Whether liquidation requires auction
    }
    
    struct LiquidationData {
        uint256 liquidationId;
        uint256 positionId;
        address borrower;
        address liquidator;
        address borrowToken;
        address collateralToken;
        uint256 liquidatedAmount;
        uint256 collateralSeized;
        uint256 liquidatorReward;
        uint256 protocolFee;
        uint256 timestamp;
        bool isCompleted;
        bool isAuction;
    }
    
    struct AuctionData {
        uint256 auctionId;
        uint256 positionId;
        address borrowToken;
        address collateralToken;
        uint256 debtAmount;
        uint256 collateralAmount;
        uint256 startPrice;
        uint256 currentPrice;
        uint256 startTime;
        uint256 endTime;
        address highestBidder;
        uint256 highestBid;
        bool isActive;
        bool isCompleted;
    }
    
    CollateralManager public immutable collateralManager;
    BorrowEngine public immutable borrowEngine;
    
    mapping(address => LiquidationConfig) public liquidationConfigs;
    mapping(uint256 => LiquidationData) public liquidations;
    mapping(uint256 => AuctionData) public auctions;
    mapping(address => uint256[]) public userLiquidations; // borrower -> liquidationIds
    mapping(address => uint256[]) public liquidatorHistory; // liquidator -> liquidationIds
    mapping(uint256 => uint256) public positionToLiquidation; // positionId -> liquidationId
    
    uint256 public nextLiquidationId = 1;
    uint256 public nextAuctionId = 1;
    uint256 public totalLiquidations;
    uint256 public totalLiquidatedValue;
    uint256 public totalProtocolFees;
    
    address public treasury;
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant AUCTION_DURATION = 24 hours;
    uint256 public constant PRICE_DECAY_RATE = 100; // 1% per hour
    
    event LiquidationExecuted(
        uint256 indexed liquidationId,
        uint256 indexed positionId,
        address indexed liquidator,
        address borrower,
        uint256 liquidatedAmount,
        uint256 collateralSeized
    );
    
    event AuctionStarted(
        uint256 indexed auctionId,
        uint256 indexed positionId,
        address borrowToken,
        address collateralToken,
        uint256 debtAmount,
        uint256 collateralAmount
    );
    
    event BidPlaced(
        uint256 indexed auctionId,
        address indexed bidder,
        uint256 bidAmount,
        uint256 timestamp
    );
    
    event AuctionCompleted(
        uint256 indexed auctionId,
        address indexed winner,
        uint256 winningBid,
        uint256 collateralAmount
    );
    
    event LiquidationConfigUpdated(
        address indexed token,
        uint256 liquidationPenalty,
        uint256 liquidatorReward,
        bool isEnabled
    );
    
    event EmergencyLiquidation(
        uint256 indexed positionId,
        address indexed borrower,
        uint256 liquidatedAmount
    );
    
    constructor(
        address _collateralManager,
        address _borrowEngine,
        address _treasury
    ) {
        require(_collateralManager != address(0), "Invalid collateral manager");
        require(_borrowEngine != address(0), "Invalid borrow engine");
        require(_treasury != address(0), "Invalid treasury");
        
        collateralManager = CollateralManager(_collateralManager);
        borrowEngine = BorrowEngine(_borrowEngine);
        treasury = _treasury;
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(LIQUIDATOR_ROLE, msg.sender);
        _grantRole(KEEPER_ROLE, msg.sender);
        _grantRole(RISK_MANAGER_ROLE, msg.sender);
    }
    
    function executeLiquidation(
        address borrower,
        address borrowToken,
        address collateralToken
    ) external onlyRole(LIQUIDATOR_ROLE) nonReentrant whenNotPaused returns (uint256 liquidationId) {
        require(borrower != address(0), "Invalid borrower");
        require(borrowToken != address(0), "Invalid borrow token");
        require(collateralToken != address(0), "Invalid collateral token");
        
        // Get position data from BorrowEngine
        uint256 healthFactor = borrowEngine.getPositionHealth(borrower);
        bool isLiquidatable = borrowEngine.isLiquidatable(borrower);
        
        require(isLiquidatable, "Position not liquidatable");
        
        // Get position details from BorrowEngine
        (uint256 positionBorrowAmount, uint256 positionCollateralAmount, uint256 positionBorrowIndex, uint256 positionLastUpdateTime, address positionCollateralToken, address positionBorrowToken, bool positionIsActive, uint256 positionLiquidationThreshold, uint256 positionHealthFactor) = borrowEngine.borrowPositions(borrower, borrowToken);
        require(positionIsActive, "Position not active");
        
        // Create position struct for easier access
        BorrowEngine.BorrowPosition memory position = BorrowEngine.BorrowPosition({
            borrowAmount: positionBorrowAmount,
            collateralAmount: positionCollateralAmount,
            borrowIndex: positionBorrowIndex,
            lastUpdateTime: positionLastUpdateTime,
            collateralToken: positionCollateralToken,
            borrowToken: positionBorrowToken,
            isActive: positionIsActive,
            liquidationThreshold: positionLiquidationThreshold,
            healthFactor: positionHealthFactor
        });
        
        LiquidationConfig memory config = liquidationConfigs[borrowToken];
        require(config.isEnabled, "Liquidation not enabled");
        
        liquidationId = nextLiquidationId++;
        
        if (config.requiresAuction) {
            // Start auction process
            _startAuction(liquidationId, liquidationId, borrower, position);
        } else {
            // Direct liquidation
            _executeDirectLiquidation(liquidationId, borrower, borrowToken, collateralToken, position, config);
        }
        
        userLiquidations[borrower].push(liquidationId);
        liquidatorHistory[msg.sender].push(liquidationId);
        
        totalLiquidations++;
    }
    
    function _executeDirectLiquidation(
        uint256 liquidationId,
        address borrower,
        address borrowToken,
        address collateralToken,
        BorrowEngine.BorrowPosition memory position,
        LiquidationConfig memory config
    ) internal {
        // Calculate liquidation amounts
        uint256 totalDebt = position.borrowAmount;
        uint256 maxLiquidationAmount = Math.min(totalDebt, config.maxLiquidationAmount);
        
        // Calculate collateral to seize
        uint256 collateralValue = collateralManager.getCollateralValue(
            position.collateralToken,
            position.collateralAmount
        );
        
        uint256 liquidationValue = maxLiquidationAmount;
        uint256 penaltyAmount = (liquidationValue * config.liquidationPenalty) / BASIS_POINTS;
        uint256 totalSeizureValue = liquidationValue + penaltyAmount;
        
        uint256 collateralToSeize = Math.min(
            (totalSeizureValue * position.collateralAmount) / collateralValue,
            position.collateralAmount
        );
        
        // Calculate rewards and fees
        uint256 liquidatorReward = (penaltyAmount * config.liquidatorReward) / BASIS_POINTS;
        uint256 protocolFee = (penaltyAmount * config.protocolFee) / BASIS_POINTS;
        
        // Transfer liquidation payment from liquidator
        IERC20(position.borrowToken).safeTransferFrom(
            msg.sender,
            address(borrowEngine),
            maxLiquidationAmount
        );
        
        // Seize collateral
        uint256 actualSeized = collateralManager.seizeCollateral(
            borrower,
            position.collateralToken,
            collateralToSeize,
            address(this)
        );
        
        // Distribute seized collateral
        uint256 liquidatorCollateral = actualSeized - 
            ((liquidatorReward + protocolFee) * actualSeized) / totalSeizureValue;
        
        // Transfer to liquidator
        IERC20(position.collateralToken).safeTransfer(msg.sender, liquidatorCollateral);
        
        // Transfer protocol fee to treasury
        if (protocolFee > 0) {
            uint256 protocolCollateral = (protocolFee * actualSeized) / totalSeizureValue;
            IERC20(position.collateralToken).safeTransfer(treasury, protocolCollateral);
            totalProtocolFees += protocolFee;
        }
        
        // Store liquidation data
        liquidations[liquidationId] = LiquidationData({
            liquidationId: liquidationId,
            positionId: liquidationId, // Use liquidationId as positionId for now
            borrower: borrower,
            liquidator: msg.sender,
            borrowToken: borrowToken,
            collateralToken: collateralToken,
            liquidatedAmount: maxLiquidationAmount,
            collateralSeized: actualSeized,
            liquidatorReward: liquidatorReward,
            protocolFee: protocolFee,
            timestamp: block.timestamp,
            isCompleted: true,
            isAuction: false
        });
        
        totalLiquidatedValue += liquidationValue;
        
        emit LiquidationExecuted(
            liquidationId,
            liquidationId, // Use liquidationId as positionId for now
            msg.sender,
            borrower,
            maxLiquidationAmount,
            actualSeized
        );
    }
    
    function _startAuction(
        uint256 liquidationId,
        uint256 positionId,
        address borrower,
        BorrowEngine.BorrowPosition memory position
    ) internal {
        uint256 auctionId = nextAuctionId++;
        
        uint256 totalDebt = position.borrowAmount;
        uint256 collateralValue = collateralManager.getCollateralValue(
            position.collateralToken,
            position.collateralAmount
        );
        
        // Start auction at market price
        uint256 startPrice = collateralValue;
        
        auctions[auctionId] = AuctionData({
            auctionId: auctionId,
            positionId: positionId,
            borrowToken: position.borrowToken,
            collateralToken: position.collateralToken,
            debtAmount: totalDebt,
            collateralAmount: position.collateralAmount,
            startPrice: startPrice,
            currentPrice: startPrice,
            startTime: block.timestamp,
            endTime: block.timestamp + AUCTION_DURATION,
            highestBidder: address(0),
            highestBid: 0,
            isActive: true,
            isCompleted: false
        });
        
        // Store liquidation data
        liquidations[liquidationId] = LiquidationData({
            liquidationId: liquidationId,
            positionId: liquidationId,
            borrower: borrower,
            liquidator: address(0), // Will be set when auction completes
            borrowToken: position.borrowToken,
            collateralToken: position.collateralToken,
            liquidatedAmount: 0, // Will be set when auction completes
            collateralSeized: 0, // Will be set when auction completes
            liquidatorReward: 0, // Will be set when auction completes
            protocolFee: 0, // Will be set when auction completes
            timestamp: block.timestamp,
            isCompleted: false,
            isAuction: true
        });
        
        emit AuctionStarted(
            auctionId,
            positionId,
            position.borrowToken,
            position.collateralToken,
            totalDebt,
            position.collateralAmount
        );
    }
    
    function placeBid(
        uint256 auctionId,
        uint256 bidAmount
    ) external nonReentrant whenNotPaused {
        AuctionData storage auction = auctions[auctionId];
        require(auction.isActive, "Auction not active");
        require(block.timestamp < auction.endTime, "Auction ended");
        require(bidAmount > auction.highestBid, "Bid too low");
        require(bidAmount >= auction.debtAmount, "Bid below debt amount");
        
        // Return previous highest bid
        if (auction.highestBidder != address(0)) {
            IERC20(auction.borrowToken).safeTransfer(auction.highestBidder, auction.highestBid);
        }
        
        // Transfer new bid
        IERC20(auction.borrowToken).safeTransferFrom(msg.sender, address(this), bidAmount);
        
        // Update auction
        auction.highestBidder = msg.sender;
        auction.highestBid = bidAmount;
        
        emit BidPlaced(auctionId, msg.sender, bidAmount, block.timestamp);
    }
    
    function finalizeAuction(uint256 auctionId) external nonReentrant {
        AuctionData storage auction = auctions[auctionId];
        require(auction.isActive, "Auction not active");
        require(block.timestamp >= auction.endTime, "Auction still active");
        require(!auction.isCompleted, "Auction already completed");
        
        auction.isActive = false;
        auction.isCompleted = true;
        
        if (auction.highestBidder != address(0)) {
            // Successful auction
            _completeAuctionLiquidation(auctionId);
        } else {
            // No bids - execute emergency liquidation
            _executeEmergencyLiquidation(liquidations[auction.auctionId].borrower, liquidations[auction.auctionId].borrowToken);
        }
    }
    
    function _completeAuctionLiquidation(uint256 auctionId) internal {
        AuctionData storage auction = auctions[auctionId];
        LiquidationData storage liquidation = liquidations[auction.auctionId];
        
        // Transfer bid to repay debt
        IERC20(auction.borrowToken).safeTransfer(address(borrowEngine), auction.debtAmount);
        
        // Calculate surplus
        uint256 surplus = auction.highestBid - auction.debtAmount;
        
        // Seize and transfer collateral
        uint256 seizedCollateral = collateralManager.seizeCollateral(
            liquidation.borrower,
            auction.collateralToken,
            auction.collateralAmount,
            auction.highestBidder
        );
        
        // Transfer surplus to borrower if any
        if (surplus > 0) {
            IERC20(auction.borrowToken).safeTransfer(liquidation.borrower, surplus);
        }
        
        // Update liquidation data
        liquidation.liquidator = auction.highestBidder;
        liquidation.liquidatedAmount = auction.debtAmount;
        liquidation.collateralSeized = seizedCollateral;
        liquidation.isCompleted = true;
        
        totalLiquidatedValue += auction.debtAmount;
        
        emit AuctionCompleted(
            auctionId,
            auction.highestBidder,
            auction.highestBid,
            seizedCollateral
        );
        
        emit LiquidationExecuted(
            liquidation.liquidationId,
            liquidation.positionId,
            auction.highestBidder,
            liquidation.borrower,
            auction.debtAmount,
            seizedCollateral
        );
    }
    
    function _executeEmergencyLiquidation(address borrower, address borrowToken) internal {
        // Emergency liquidation at current market price
        // Get position details from BorrowEngine
        (uint256 positionBorrowAmount, uint256 positionCollateralAmount, uint256 positionBorrowIndex, uint256 positionLastUpdateTime, address positionCollateralToken, address positionBorrowToken, bool positionIsActive, uint256 positionLiquidationThreshold, uint256 positionHealthFactor) = borrowEngine.borrowPositions(borrower, borrowToken);
        
        // Create position struct for easier access
        BorrowEngine.BorrowPosition memory position = BorrowEngine.BorrowPosition({
            borrowAmount: positionBorrowAmount,
            collateralAmount: positionCollateralAmount,
            borrowIndex: positionBorrowIndex,
            lastUpdateTime: positionLastUpdateTime,
            collateralToken: positionCollateralToken,
            borrowToken: positionBorrowToken,
            isActive: positionIsActive,
            liquidationThreshold: positionLiquidationThreshold,
            healthFactor: positionHealthFactor
        });
        require(position.isActive, "Position not active");
        
        uint256 totalDebt = position.borrowAmount;
        
        // Seize all collateral
        uint256 seizedCollateral = collateralManager.seizeCollateral(
            borrower,
            position.collateralToken,
            position.collateralAmount,
            treasury // Send to treasury for emergency liquidation
        );
        
        emit EmergencyLiquidation(0, borrower, totalDebt); // positionId not available in this context
    }
    
    function getCurrentAuctionPrice(uint256 auctionId) external view returns (uint256 currentPrice) {
        AuctionData memory auction = auctions[auctionId];
        require(auction.isActive, "Auction not active");
        
        if (block.timestamp >= auction.endTime) {
            return auction.currentPrice;
        }
        
        // Calculate price decay
        uint256 timeElapsed = block.timestamp - auction.startTime;
        uint256 hoursElapsed = timeElapsed / 1 hours;
        uint256 priceDecay = (auction.startPrice * PRICE_DECAY_RATE * hoursElapsed) / BASIS_POINTS;
        
        currentPrice = auction.startPrice > priceDecay ? auction.startPrice - priceDecay : 0;
    }
    
    function isPositionLiquidatable(address borrower) external view returns (bool) {
        return borrowEngine.isLiquidatable(borrower);
    }
    
    function getLiquidationData(uint256 liquidationId) external view returns (LiquidationData memory) {
        return liquidations[liquidationId];
    }
    
    function getAuctionData(uint256 auctionId) external view returns (AuctionData memory) {
        return auctions[auctionId];
    }
    
    function getUserLiquidations(address user) external view returns (uint256[] memory) {
        return userLiquidations[user];
    }
    
    function getLiquidatorHistory(address liquidator) external view returns (uint256[] memory) {
        return liquidatorHistory[liquidator];
    }
    
    function setLiquidationConfig(
        address token,
        LiquidationConfig memory config
    ) external onlyRole(RISK_MANAGER_ROLE) {
        require(config.liquidationPenalty <= 2000, "Penalty too high"); // Max 20%
        require(config.liquidatorReward <= 1000, "Reward too high"); // Max 10%
        require(config.protocolFee <= 500, "Protocol fee too high"); // Max 5%
        require(config.minCollateralRatio >= 11000, "Min ratio too low"); // Min 110%
        
        liquidationConfigs[token] = config;
        
        emit LiquidationConfigUpdated(
            token,
            config.liquidationPenalty,
            config.liquidatorReward,
            config.isEnabled
        );
    }
    
    function setDefaultLiquidationConfig(address token) external onlyRole(RISK_MANAGER_ROLE) {
        LiquidationConfig memory defaultConfig = LiquidationConfig({
            liquidationPenalty: 1000, // 10%
            liquidatorReward: 500, // 5%
            protocolFee: 200, // 2%
            maxLiquidationAmount: 1000000 * 1e18, // 1M tokens
            minCollateralRatio: 11000, // 110%
            gracePeriod: 1 hours,
            isEnabled: true,
            requiresAuction: false
        });
        
        liquidationConfigs[token] = defaultConfig;
        
        emit LiquidationConfigUpdated(
            token,
            defaultConfig.liquidationPenalty,
            defaultConfig.liquidatorReward,
            defaultConfig.isEnabled
        );
    }
    
    function setTreasury(address _treasury) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_treasury != address(0), "Invalid treasury");
        treasury = _treasury;
    }
    
    function getLiquidationStats() external view returns (
        uint256 totalLiquidationsCount,
        uint256 totalValue,
        uint256 totalFees,
        uint256 averageLiquidationSize
    ) {
        totalLiquidationsCount = totalLiquidations;
        totalValue = totalLiquidatedValue;
        totalFees = totalProtocolFees;
        averageLiquidationSize = totalLiquidations > 0 ? totalLiquidatedValue / totalLiquidations : 0;
    }
    
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }
    
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
    
    function emergencyWithdraw(
        address token,
        uint256 amount
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        IERC20(token).safeTransfer(treasury, amount);
    }
}
