// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./CollateralManager.sol";
import "./InterestRateModel.sol";
import "./LiquidationEngine.sol";

/**
 * @title BorrowEngine
 * @dev Core borrowing functionality with collateral management
 */
contract BorrowEngine is AccessControl, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;
    using Math for uint256;
    
    bytes32 public constant BORROWER_ROLE = keccak256("BORROWER_ROLE");
    bytes32 public constant LIQUIDATOR_ROLE = keccak256("LIQUIDATOR_ROLE");
    bytes32 public constant RISK_MANAGER_ROLE = keccak256("RISK_MANAGER_ROLE");
    
    struct BorrowPosition {
        uint256 positionId;
        address borrower;
        address borrowToken;
        address collateralToken;
        uint256 borrowAmount;
        uint256 collateralAmount;
        uint256 borrowTimestamp;
        uint256 lastInterestUpdate;
        uint256 accruedInterest;
        uint256 liquidationThreshold;
        uint256 ltv; // Loan-to-Value ratio
        bool isActive;
        bool isLiquidated;
    }
    
    struct BorrowConfig {
        uint256 maxLTV; // Maximum Loan-to-Value ratio (basis points)
        uint256 liquidationThreshold; // Liquidation threshold (basis points)
        uint256 liquidationPenalty; // Liquidation penalty (basis points)
        uint256 borrowFee; // Borrow fee (basis points)
        uint256 minBorrowAmount;
        uint256 maxBorrowAmount;
        bool isEnabled;
        bool requiresWhitelist;
    }
    
    struct MarketData {
        uint256 totalBorrowed;
        uint256 totalCollateral;
        uint256 utilizationRate;
        uint256 borrowRate;
        uint256 supplyRate;
        uint256 lastUpdateTime;
        uint256 reserveFactor;
        uint256 totalReserves;
    }
    
    CollateralManager public immutable collateralManager;
    InterestRateModel public immutable interestRateModel;
    LiquidationEngine public immutable liquidationEngine;
    
    mapping(uint256 => BorrowPosition) public borrowPositions;
    mapping(address => BorrowConfig) public borrowConfigs;
    mapping(address => MarketData) public marketData;
    mapping(address => mapping(address => uint256[])) public userPositions; // borrower -> token -> positionIds
    mapping(address => bool) public whitelistedBorrowers;
    mapping(address => uint256) public borrowCaps;
    
    uint256 public nextPositionId = 1;
    uint256 public totalPositions;
    uint256 public totalActiveBorrows;
    
    address public treasury;
    uint256 public protocolFee = 500; // 5%
    
    event BorrowPositionCreated(
        uint256 indexed positionId,
        address indexed borrower,
        address indexed borrowToken,
        address collateralToken,
        uint256 borrowAmount,
        uint256 collateralAmount
    );
    
    event BorrowAmountIncreased(
        uint256 indexed positionId,
        uint256 additionalAmount,
        uint256 newTotalBorrow
    );
    
    event CollateralAdded(
        uint256 indexed positionId,
        uint256 additionalCollateral,
        uint256 newTotalCollateral
    );
    
    event BorrowRepaid(
        uint256 indexed positionId,
        uint256 repayAmount,
        uint256 remainingBorrow
    );
    
    event CollateralWithdrawn(
        uint256 indexed positionId,
        uint256 withdrawAmount,
        uint256 remainingCollateral
    );
    
    event PositionLiquidated(
        uint256 indexed positionId,
        address indexed liquidator,
        uint256 liquidatedAmount,
        uint256 collateralSeized
    );
    
    event InterestAccrued(
        uint256 indexed positionId,
        uint256 interestAmount,
        uint256 totalDebt
    );
    
    event BorrowConfigUpdated(
        address indexed token,
        uint256 maxLTV,
        uint256 liquidationThreshold,
        bool isEnabled
    );
    
    constructor(
        address _collateralManager,
        address _interestRateModel,
        address _liquidationEngine,
        address _treasury
    ) {
        require(_collateralManager != address(0), "Invalid collateral manager");
        require(_interestRateModel != address(0), "Invalid interest rate model");
        require(_liquidationEngine != address(0), "Invalid liquidation engine");
        require(_treasury != address(0), "Invalid treasury");
        
        collateralManager = CollateralManager(_collateralManager);
        interestRateModel = InterestRateModel(_interestRateModel);
        liquidationEngine = LiquidationEngine(_liquidationEngine);
        treasury = _treasury;
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(BORROWER_ROLE, msg.sender);
        _grantRole(RISK_MANAGER_ROLE, msg.sender);
    }
    
    function createBorrowPosition(
        address borrowToken,
        address collateralToken,
        uint256 borrowAmount,
        uint256 collateralAmount
    ) external onlyRole(BORROWER_ROLE) nonReentrant whenNotPaused returns (uint256 positionId) {
        require(borrowAmount > 0, "Invalid borrow amount");
        require(collateralAmount > 0, "Invalid collateral amount");
        
        BorrowConfig memory config = borrowConfigs[borrowToken];
        require(config.isEnabled, "Borrowing not enabled for token");
        require(borrowAmount >= config.minBorrowAmount, "Below minimum borrow");
        require(borrowAmount <= config.maxBorrowAmount, "Above maximum borrow");
        
        if (config.requiresWhitelist) {
            require(whitelistedBorrowers[msg.sender], "Not whitelisted");
        }
        
        // Check borrow cap
        MarketData storage market = marketData[borrowToken];
        require(
            market.totalBorrowed + borrowAmount <= borrowCaps[borrowToken],
            "Borrow cap exceeded"
        );
        
        // Validate collateral
        require(
            collateralManager.isValidCollateral(collateralToken),
            "Invalid collateral token"
        );
        
        // Calculate LTV
        uint256 collateralValue = collateralManager.getCollateralValue(
            collateralToken,
            collateralAmount
        );
        uint256 borrowValue = _getBorrowValue(borrowToken, borrowAmount);
        uint256 ltv = (borrowValue * 10000) / collateralValue;
        
        require(ltv <= config.maxLTV, "LTV too high");
        
        // Transfer collateral
        IERC20(collateralToken).safeTransferFrom(
            msg.sender,
            address(collateralManager),
            collateralAmount
        );
        
        // Calculate and deduct borrow fee
        uint256 borrowFee = (borrowAmount * config.borrowFee) / 10000;
        uint256 netBorrowAmount = borrowAmount - borrowFee;
        
        // Transfer borrowed tokens
        IERC20(borrowToken).safeTransfer(msg.sender, netBorrowAmount);
        
        // Transfer fee to treasury
        if (borrowFee > 0) {
            IERC20(borrowToken).safeTransfer(treasury, borrowFee);
        }
        
        // Create position
        positionId = nextPositionId++;
        
        BorrowPosition storage position = borrowPositions[positionId];
        position.positionId = positionId;
        position.borrower = msg.sender;
        position.borrowToken = borrowToken;
        position.collateralToken = collateralToken;
        position.borrowAmount = borrowAmount;
        position.collateralAmount = collateralAmount;
        position.borrowTimestamp = block.timestamp;
        position.lastInterestUpdate = block.timestamp;
        position.liquidationThreshold = config.liquidationThreshold;
        position.ltv = ltv;
        position.isActive = true;
        
        // Update user positions
        userPositions[msg.sender][borrowToken].push(positionId);
        
        // Update market data
        market.totalBorrowed += borrowAmount;
        market.totalCollateral += collateralValue;
        _updateMarketRates(borrowToken);
        
        totalPositions++;
        totalActiveBorrows++;
        
        emit BorrowPositionCreated(
            positionId,
            msg.sender,
            borrowToken,
            collateralToken,
            borrowAmount,
            collateralAmount
        );
    }
    
    function increaseBorrow(
        uint256 positionId,
        uint256 additionalAmount
    ) external nonReentrant whenNotPaused {
        BorrowPosition storage position = borrowPositions[positionId];
        require(position.isActive, "Position not active");
        require(position.borrower == msg.sender, "Not position owner");
        require(additionalAmount > 0, "Invalid amount");
        
        // Accrue interest first
        _accrueInterest(positionId);
        
        BorrowConfig memory config = borrowConfigs[position.borrowToken];
        require(config.isEnabled, "Borrowing not enabled");
        
        // Check new total doesn't exceed limits
        uint256 newTotalBorrow = position.borrowAmount + position.accruedInterest + additionalAmount;
        require(newTotalBorrow <= config.maxBorrowAmount, "Above maximum borrow");
        
        // Check LTV after increase
        uint256 collateralValue = collateralManager.getCollateralValue(
            position.collateralToken,
            position.collateralAmount
        );
        uint256 newBorrowValue = _getBorrowValue(position.borrowToken, newTotalBorrow);
        uint256 newLTV = (newBorrowValue * 10000) / collateralValue;
        
        require(newLTV <= config.maxLTV, "LTV too high after increase");
        
        // Calculate fee and transfer tokens
        uint256 borrowFee = (additionalAmount * config.borrowFee) / 10000;
        uint256 netAmount = additionalAmount - borrowFee;
        
        IERC20(position.borrowToken).safeTransfer(msg.sender, netAmount);
        
        if (borrowFee > 0) {
            IERC20(position.borrowToken).safeTransfer(treasury, borrowFee);
        }
        
        // Update position
        position.borrowAmount += additionalAmount;
        position.ltv = newLTV;
        
        // Update market data
        marketData[position.borrowToken].totalBorrowed += additionalAmount;
        _updateMarketRates(position.borrowToken);
        
        emit BorrowAmountIncreased(positionId, additionalAmount, position.borrowAmount);
    }
    
    function addCollateral(
        uint256 positionId,
        uint256 additionalCollateral
    ) external nonReentrant whenNotPaused {
        BorrowPosition storage position = borrowPositions[positionId];
        require(position.isActive, "Position not active");
        require(position.borrower == msg.sender, "Not position owner");
        require(additionalCollateral > 0, "Invalid amount");
        
        // Transfer additional collateral
        IERC20(position.collateralToken).safeTransferFrom(
            msg.sender,
            address(collateralManager),
            additionalCollateral
        );
        
        // Update position
        position.collateralAmount += additionalCollateral;
        
        // Recalculate LTV
        uint256 collateralValue = collateralManager.getCollateralValue(
            position.collateralToken,
            position.collateralAmount
        );
        uint256 borrowValue = _getBorrowValue(
            position.borrowToken,
            position.borrowAmount + position.accruedInterest
        );
        position.ltv = (borrowValue * 10000) / collateralValue;
        
        // Update market data
        uint256 additionalCollateralValue = collateralManager.getCollateralValue(
            position.collateralToken,
            additionalCollateral
        );
        marketData[position.borrowToken].totalCollateral += additionalCollateralValue;
        
        emit CollateralAdded(positionId, additionalCollateral, position.collateralAmount);
    }
    
    function repayBorrow(
        uint256 positionId,
        uint256 repayAmount
    ) external nonReentrant whenNotPaused {
        BorrowPosition storage position = borrowPositions[positionId];
        require(position.isActive, "Position not active");
        require(repayAmount > 0, "Invalid repay amount");
        
        // Accrue interest first
        _accrueInterest(positionId);
        
        uint256 totalDebt = position.borrowAmount + position.accruedInterest;
        require(repayAmount <= totalDebt, "Repay amount too high");
        
        // Transfer repayment
        IERC20(position.borrowToken).safeTransferFrom(
            msg.sender,
            address(this),
            repayAmount
        );
        
        // Update position
        if (repayAmount >= totalDebt) {
            // Full repayment
            position.borrowAmount = 0;
            position.accruedInterest = 0;
            position.isActive = false;
            totalActiveBorrows--;
        } else {
            // Partial repayment - pay interest first
            if (repayAmount >= position.accruedInterest) {
                uint256 principalPayment = repayAmount - position.accruedInterest;
                position.accruedInterest = 0;
                position.borrowAmount -= principalPayment;
            } else {
                position.accruedInterest -= repayAmount;
            }
        }
        
        // Update market data
        marketData[position.borrowToken].totalBorrowed -= repayAmount;
        _updateMarketRates(position.borrowToken);
        
        emit BorrowRepaid(positionId, repayAmount, position.borrowAmount + position.accruedInterest);
    }
    
    function withdrawCollateral(
        uint256 positionId,
        uint256 withdrawAmount
    ) external nonReentrant whenNotPaused {
        BorrowPosition storage position = borrowPositions[positionId];
        require(position.isActive, "Position not active");
        require(position.borrower == msg.sender, "Not position owner");
        require(withdrawAmount > 0, "Invalid amount");
        require(withdrawAmount <= position.collateralAmount, "Insufficient collateral");
        
        // Accrue interest first
        _accrueInterest(positionId);
        
        // Check if withdrawal maintains safe LTV
        uint256 newCollateralAmount = position.collateralAmount - withdrawAmount;
        if (newCollateralAmount > 0) {
            uint256 newCollateralValue = collateralManager.getCollateralValue(
                position.collateralToken,
                newCollateralAmount
            );
            uint256 borrowValue = _getBorrowValue(
                position.borrowToken,
                position.borrowAmount + position.accruedInterest
            );
            uint256 newLTV = (borrowValue * 10000) / newCollateralValue;
            
            BorrowConfig memory config = borrowConfigs[position.borrowToken];
            require(newLTV <= config.maxLTV, "LTV too high after withdrawal");
        } else {
            require(
                position.borrowAmount + position.accruedInterest == 0,
                "Cannot withdraw all collateral with debt"
            );
        }
        
        // Withdraw collateral
        collateralManager.withdrawCollateral(
            position.collateralToken,
            withdrawAmount,
            msg.sender
        );
        
        // Update position
        position.collateralAmount = newCollateralAmount;
        
        // Update market data
        uint256 withdrawnValue = collateralManager.getCollateralValue(
            position.collateralToken,
            withdrawAmount
        );
        marketData[position.borrowToken].totalCollateral -= withdrawnValue;
        
        emit CollateralWithdrawn(positionId, withdrawAmount, newCollateralAmount);
    }
    
    function _accrueInterest(uint256 positionId) internal {
        BorrowPosition storage position = borrowPositions[positionId];
        
        if (position.borrowAmount == 0) return;
        
        uint256 timeElapsed = block.timestamp - position.lastInterestUpdate;
        if (timeElapsed == 0) return;
        
        uint256 borrowRate = interestRateModel.getBorrowRate(
            position.borrowToken,
            marketData[position.borrowToken].utilizationRate
        );
        
        uint256 interestAccrued = (position.borrowAmount * borrowRate * timeElapsed) / (365 days * 10000);
        
        position.accruedInterest += interestAccrued;
        position.lastInterestUpdate = block.timestamp;
        
        emit InterestAccrued(positionId, interestAccrued, position.borrowAmount + position.accruedInterest);
    }
    
    function _updateMarketRates(address token) internal {
        MarketData storage market = marketData[token];
        
        // Calculate utilization rate
        uint256 totalSupply = IERC20(token).balanceOf(address(this)) + market.totalBorrowed;
        market.utilizationRate = totalSupply > 0 ? (market.totalBorrowed * 10000) / totalSupply : 0;
        
        // Update rates
        market.borrowRate = interestRateModel.getBorrowRate(token, market.utilizationRate);
        market.supplyRate = interestRateModel.getSupplyRate(token, market.utilizationRate, market.reserveFactor);
        market.lastUpdateTime = block.timestamp;
    }
    
    function _getBorrowValue(address token, uint256 amount) internal pure returns (uint256) {
        // This would typically use a price oracle
        // For now, assume 1:1 with USD
        return amount;
    }
    
    function liquidatePosition(uint256 positionId) external onlyRole(LIQUIDATOR_ROLE) nonReentrant {
        BorrowPosition storage position = borrowPositions[positionId];
        require(position.isActive, "Position not active");
        
        // Accrue interest
        _accrueInterest(positionId);
        
        // Check if position is liquidatable
        require(_isLiquidatable(positionId), "Position not liquidatable");
        
        // Execute liquidation through liquidation engine
        liquidationEngine.executeLiquidation(positionId);
        
        // Mark position as liquidated
        position.isActive = false;
        position.isLiquidated = true;
        totalActiveBorrows--;
    }
    
    function _isLiquidatable(uint256 positionId) internal view returns (bool) {
        BorrowPosition memory position = borrowPositions[positionId];
        
        uint256 collateralValue = collateralManager.getCollateralValue(
            position.collateralToken,
            position.collateralAmount
        );
        uint256 borrowValue = _getBorrowValue(
            position.borrowToken,
            position.borrowAmount + position.accruedInterest
        );
        
        uint256 currentLTV = (borrowValue * 10000) / collateralValue;
        return currentLTV >= position.liquidationThreshold;
    }
    
    function getPositionHealth(uint256 positionId) external view returns (
        uint256 currentLTV,
        uint256 liquidationThreshold,
        uint256 healthFactor,
        bool isLiquidatable
    ) {
        BorrowPosition memory position = borrowPositions[positionId];
        require(position.positionId != 0, "Position does not exist");
        
        uint256 collateralValue = collateralManager.getCollateralValue(
            position.collateralToken,
            position.collateralAmount
        );
        uint256 borrowValue = _getBorrowValue(
            position.borrowToken,
            position.borrowAmount + position.accruedInterest
        );
        
        currentLTV = collateralValue > 0 ? (borrowValue * 10000) / collateralValue : 0;
        liquidationThreshold = position.liquidationThreshold;
        healthFactor = liquidationThreshold > 0 ? (liquidationThreshold * 10000) / currentLTV : type(uint256).max;
        isLiquidatable = currentLTV >= liquidationThreshold;
    }
    
    function getUserPositions(address user, address token) external view returns (uint256[] memory) {
        return userPositions[user][token];
    }
    
    function setBorrowConfig(
        address token,
        BorrowConfig memory config
    ) external onlyRole(RISK_MANAGER_ROLE) {
        require(config.maxLTV <= 9000, "LTV too high"); // Max 90%
        require(config.liquidationThreshold > config.maxLTV, "Invalid liquidation threshold");
        require(config.liquidationPenalty <= 2000, "Penalty too high"); // Max 20%
        
        borrowConfigs[token] = config;
        
        emit BorrowConfigUpdated(
            token,
            config.maxLTV,
            config.liquidationThreshold,
            config.isEnabled
        );
    }
    
    function setBorrowCap(address token, uint256 cap) external onlyRole(RISK_MANAGER_ROLE) {
        borrowCaps[token] = cap;
    }
    
    function setWhitelistStatus(address user, bool status) external onlyRole(DEFAULT_ADMIN_ROLE) {
        whitelistedBorrowers[user] = status;
    }
    
    function setTreasury(address _treasury) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_treasury != address(0), "Invalid treasury");
        treasury = _treasury;
    }
    
    function setProtocolFee(uint256 _fee) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_fee <= 1000, "Fee too high"); // Max 10%
        protocolFee = _fee;
    }
    
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }
    
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
    
    function emergencyWithdraw(address token, uint256 amount) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        IERC20(token).safeTransfer(msg.sender, amount);
    }
}
