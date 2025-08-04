// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./FeeSpreadModel.sol";

/**
 * @title CreditSaleManager
 * @dev CoreFluid credit sale system that replaces interest-based lending
 * with fixed-price asset-backed credit sales
 */
contract CreditSaleManager is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    
    // Structs
    struct CreditOrder {
        uint256 orderId;
        address buyer; // The credit buyer (borrower in traditional terms)
        address collateralAsset;
        uint256 collateralAmount;
        uint256 creditAmount; // Principal amount
        uint256 fixedTotalPrice; // Principal + markup (fixed at creation)
        uint256 paidAmount; // Amount paid so far
        uint256 instalmentAmount; // Fixed instalment amount
        uint256 instalmentCount; // Total number of instalments
        uint256 paidInstalments; // Number of instalments paid
        uint256 createdAt;
        uint256 dueDate; // Final due date
        CreditStatus status;
        bool isCollateralLocked;
    }
    
    enum CreditStatus {
        PENDING_QUOTE,
        ACTIVE,
        COMPLETED,
        DEFAULTED,
        RECOVERED
    }
    
    // Events
    event CreditQuoteRequested(uint256 indexed orderId, address indexed buyer, address collateralAsset, uint256 collateralAmount, uint256 creditAmount);
    event CreditSaleOpened(uint256 indexed orderId, address indexed buyer, uint256 fixedTotalPrice, uint256 instalmentAmount, uint256 instalmentCount);
    event InstalmentPaid(uint256 indexed orderId, address indexed buyer, uint256 amount, uint256 instalmentNumber);
    event CreditCompleted(uint256 indexed orderId, address indexed buyer, uint256 totalPaid);
    event CollateralRecovered(uint256 indexed orderId, address indexed buyer, uint256 collateralAmount);
    event CreditDefaulted(uint256 indexed orderId, address indexed buyer);
    
    // State variables
    FeeSpreadModel public feeSpreadModel;
    uint256 public nextOrderId = 1;
    uint256 public constant MAX_INSTALMENT_PERIOD = 365 days; // Maximum 1 year
    uint256 public constant MIN_INSTALMENT_COUNT = 1;
    uint256 public constant MAX_INSTALMENT_COUNT = 52; // Weekly instalments for 1 year
    
    // Mappings
    mapping(uint256 => CreditOrder) public creditOrders;
    mapping(address => uint256[]) public userOrders;
    mapping(address => bool) public authorizedAssets;
    
    // Treasury and fee collection
    address public treasury;
    uint256 public totalFeesCollected;
    
    constructor(address _feeSpreadModel, address _treasury) {
        require(_feeSpreadModel != address(0), "Invalid fee spread model");
        require(_treasury != address(0), "Invalid treasury address");
        
        feeSpreadModel = FeeSpreadModel(_feeSpreadModel);
        treasury = _treasury;
    }
    
    /**
     * @dev Request a quote for credit sale
     * @param collateralAsset The collateral asset address
     * @param collateralAmount The amount of collateral to lock
     * @param creditAmount The desired credit amount
     * @param instalmentCount Number of instalments (1 for lump sum)
     * @return orderId The created order ID
     * @return fixedTotalPrice The total fixed price to be paid
     */
    function requestQuote(
        address collateralAsset,
        uint256 collateralAmount,
        uint256 creditAmount,
        uint256 instalmentCount
    ) external nonReentrant returns (uint256 orderId, uint256 fixedTotalPrice) {
        require(authorizedAssets[collateralAsset], "Collateral asset not authorized");
        require(collateralAmount > 0, "Invalid collateral amount");
        require(creditAmount > 0, "Invalid credit amount");
        require(instalmentCount >= MIN_INSTALMENT_COUNT && instalmentCount <= MAX_INSTALMENT_COUNT, "Invalid instalment count");
        
        // Calculate fixed total price using fee spread model
        fixedTotalPrice = feeSpreadModel.calculateFixedPrice(creditAmount, collateralAsset);
        
        orderId = nextOrderId++;
        
        CreditOrder storage order = creditOrders[orderId];
        order.orderId = orderId;
        order.buyer = msg.sender;
        order.collateralAsset = collateralAsset;
        order.collateralAmount = collateralAmount;
        order.creditAmount = creditAmount;
        order.fixedTotalPrice = fixedTotalPrice;
        order.instalmentCount = instalmentCount;
        order.instalmentAmount = fixedTotalPrice / instalmentCount;
        order.createdAt = block.timestamp;
        order.status = CreditStatus.PENDING_QUOTE;
        
        userOrders[msg.sender].push(orderId);
        
        emit CreditQuoteRequested(orderId, msg.sender, collateralAsset, collateralAmount, creditAmount);
        
        return (orderId, fixedTotalPrice);
    }
    
    /**
     * @dev Open a credit sale after quote acceptance
     * @param orderId The order ID from quote
     * @param durationDays Duration in days for the credit
     */
    function openCreditSale(uint256 orderId, uint256 durationDays) external nonReentrant {
        CreditOrder storage order = creditOrders[orderId];
        require(order.buyer == msg.sender, "Not order owner");
        require(order.status == CreditStatus.PENDING_QUOTE, "Invalid order status");
        require(durationDays > 0 && durationDays <= MAX_INSTALMENT_PERIOD / 1 days, "Invalid duration");
        
        // Lock collateral
        IERC20(order.collateralAsset).safeTransferFrom(msg.sender, address(this), order.collateralAmount);
        order.isCollateralLocked = true;
        
        // Set due date
        order.dueDate = block.timestamp + (durationDays * 1 days);
        order.status = CreditStatus.ACTIVE;
        
        // Transfer credit amount to buyer
        // Note: In production, this would come from liquidity pool
        // For now, we assume the contract has sufficient balance
        require(address(this).balance >= order.creditAmount, "Insufficient liquidity");
        payable(msg.sender).transfer(order.creditAmount);
        
        emit CreditSaleOpened(orderId, msg.sender, order.fixedTotalPrice, order.instalmentAmount, order.instalmentCount);
    }
    
    /**
     * @dev Pay an instalment
     * @param orderId The order ID
     */
    function payInstalment(uint256 orderId) external payable nonReentrant {
        CreditOrder storage order = creditOrders[orderId];
        require(order.buyer == msg.sender, "Not order owner");
        require(order.status == CreditStatus.ACTIVE, "Order not active");
        require(block.timestamp <= order.dueDate, "Order overdue");
        require(order.paidInstalments < order.instalmentCount, "All instalments paid");
        
        uint256 expectedAmount = order.instalmentAmount;
        
        // For the last instalment, pay the remaining amount
        if (order.paidInstalments == order.instalmentCount - 1) {
            expectedAmount = order.fixedTotalPrice - order.paidAmount;
        }
        
        require(msg.value >= expectedAmount, "Insufficient payment");
        
        order.paidAmount += expectedAmount;
        order.paidInstalments++;
        
        // Return excess payment
        if (msg.value > expectedAmount) {
            payable(msg.sender).transfer(msg.value - expectedAmount);
        }
        
        emit InstalmentPaid(orderId, msg.sender, expectedAmount, order.paidInstalments);
        
        // Check if fully paid
        if (order.paidAmount >= order.fixedTotalPrice) {
            _completeCreditSale(orderId);
        }
    }
    
    /**
     * @dev Complete a credit sale and release collateral
     * @param orderId The order ID
     */
    function _completeCreditSale(uint256 orderId) internal {
        CreditOrder storage order = creditOrders[orderId];
        require(order.status == CreditStatus.ACTIVE, "Order not active");
        require(order.paidAmount >= order.fixedTotalPrice, "Payment incomplete");
        
        order.status = CreditStatus.COMPLETED;
        
        // Release collateral
        if (order.isCollateralLocked) {
            IERC20(order.collateralAsset).safeTransfer(order.buyer, order.collateralAmount);
            order.isCollateralLocked = false;
        }
        
        // Calculate and transfer fees to treasury
        uint256 fees = order.paidAmount - order.creditAmount;
        totalFeesCollected += fees;
        
        if (fees > 0) {
            payable(treasury).transfer(fees);
        }
        
        emit CreditCompleted(orderId, order.buyer, order.paidAmount);
    }
    
    /**
     * @dev Recover collateral for defaulted orders
     * @param orderId The order ID
     */
    function recoverCollateral(uint256 orderId) external onlyOwner {
        CreditOrder storage order = creditOrders[orderId];
        require(order.status == CreditStatus.ACTIVE, "Order not active");
        require(block.timestamp > order.dueDate, "Order not overdue");
        require(order.paidAmount < order.fixedTotalPrice, "Order fully paid");
        
        order.status = CreditStatus.DEFAULTED;
        
        // Transfer collateral to treasury for recovery
        if (order.isCollateralLocked) {
            IERC20(order.collateralAsset).safeTransfer(treasury, order.collateralAmount);
            order.isCollateralLocked = false;
        }
        
        emit CreditDefaulted(orderId, order.buyer);
        emit CollateralRecovered(orderId, order.buyer, order.collateralAmount);
    }
    
    /**
     * @dev Add authorized collateral asset
     * @param asset The asset address
     */
    function addAuthorizedAsset(address asset) external onlyOwner {
        require(asset != address(0), "Invalid asset address");
        require(feeSpreadModel.isAssetSupported(asset), "Asset not supported by fee model");
        
        authorizedAssets[asset] = true;
    }
    
    /**
     * @dev Remove authorized collateral asset
     * @param asset The asset address
     */
    function removeAuthorizedAsset(address asset) external onlyOwner {
        authorizedAssets[asset] = false;
    }
    
    /**
     * @dev Update treasury address
     * @param newTreasury The new treasury address
     */
    function updateTreasury(address newTreasury) external onlyOwner {
        require(newTreasury != address(0), "Invalid treasury address");
        treasury = newTreasury;
    }
    
    /**
     * @dev Get user's credit orders
     * @param user The user address
     * @return orderIds Array of order IDs
     */
    function getUserOrders(address user) external view returns (uint256[] memory orderIds) {
        return userOrders[user];
    }
    
    /**
     * @dev Get order details
     * @param orderId The order ID
     * @return order The credit order struct
     */
    function getOrder(uint256 orderId) external view returns (CreditOrder memory order) {
        return creditOrders[orderId];
    }
    
    /**
     * @dev Check if order is overdue
     * @param orderId The order ID
     * @return isOverdue True if order is overdue
     */
    function isOrderOverdue(uint256 orderId) external view returns (bool isOverdue) {
        CreditOrder storage order = creditOrders[orderId];
        return (order.status == CreditStatus.ACTIVE && block.timestamp > order.dueDate && order.paidAmount < order.fixedTotalPrice);
    }
    
    /**
     * @dev Get remaining payment for an order
     * @param orderId The order ID
     * @return remainingAmount The remaining amount to be paid
     */
    function getRemainingPayment(uint256 orderId) external view returns (uint256 remainingAmount) {
        CreditOrder storage order = creditOrders[orderId];
        if (order.paidAmount >= order.fixedTotalPrice) {
            return 0;
        }
        return order.fixedTotalPrice - order.paidAmount;
    }
    
    // Function to receive Ether
    receive() external payable {}
    
    // Emergency withdrawal function
    function emergencyWithdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
}