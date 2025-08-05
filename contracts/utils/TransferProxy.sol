// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title TransferProxy
 * @dev Proxy contract for handling token transfers with additional security and batching
 */
contract TransferProxy is Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    struct TransferRequest {
        address token;
        address from;
        address to;
        uint256 amount;
        uint256 nonce;
        uint256 deadline;
        bytes signature;
    }

    struct BatchTransfer {
        address token;
        address[] recipients;
        uint256[] amounts;
    }

    mapping(address => bool) public authorizedCallers;
    mapping(address => uint256) public nonces;
    mapping(bytes32 => bool) public executedTransfers;
    mapping(address => bool) public supportedTokens;
    mapping(address => uint256) public transferLimits; // Per-token transfer limits
    
    uint256 public defaultTransferLimit = 1000000 * 1e18; // 1M tokens
    uint256 public maxBatchSize = 100;
    uint256 public transferFee = 10; // 0.1% in basis points
    uint256 public constant BASIS_POINTS = 10000;
    
    address public feeRecipient;
    bool public feeEnabled = false;

    event TransferExecuted(
        bytes32 indexed transferId,
        address indexed token,
        address indexed from,
        address to,
        uint256 amount
    );

    event BatchTransferExecuted(
        address indexed token,
        address indexed from,
        uint256 totalAmount,
        uint256 recipientCount
    );

    event AuthorizedCallerUpdated(address indexed caller, bool authorized);
    event TokenSupportUpdated(address indexed token, bool supported);
    event TransferLimitUpdated(address indexed token, uint256 limit);
    event FeeConfigUpdated(uint256 fee, address recipient, bool enabled);

    modifier onlyAuthorized() {
        require(authorizedCallers[msg.sender] || msg.sender == owner(), "Not authorized");
        _;
    }

    modifier validToken(address token) {
        require(supportedTokens[token], "Token not supported");
        _;
    }

    constructor(address _feeRecipient) Ownable(msg.sender) {
        require(_feeRecipient != address(0), "Invalid fee recipient");
        feeRecipient = _feeRecipient;
    }

    /**
     * @dev Execute a single token transfer
     * @param token Token address
     * @param from Sender address
     * @param to Recipient address
     * @param amount Transfer amount
     * @return success True if transfer successful
     */
    function executeTransfer(
        address token,
        address from,
        address to,
        uint256 amount
    ) external onlyAuthorized nonReentrant whenNotPaused validToken(token) returns (bool success) {
        require(from != address(0) && to != address(0), "Invalid addresses");
        require(amount > 0, "Invalid amount");
        require(amount <= getTransferLimit(token), "Amount exceeds limit");

        bytes32 transferId = keccak256(abi.encodePacked(token, from, to, amount, block.timestamp));
        require(!executedTransfers[transferId], "Transfer already executed");

        uint256 fee = 0;
        uint256 netAmount = amount;

        if (feeEnabled && transferFee > 0) {
            fee = amount * transferFee / BASIS_POINTS;
            netAmount = amount - fee;
        }

        // Mark transfer as executed
        executedTransfers[transferId] = true;

        // Execute transfer
        IERC20(token).safeTransferFrom(from, to, netAmount);
        
        // Transfer fee if applicable
        if (fee > 0) {
            IERC20(token).safeTransferFrom(from, feeRecipient, fee);
        }

        emit TransferExecuted(transferId, token, from, to, netAmount);
        return true;
    }

    /**
     * @dev Execute batch transfers
     * @param token Token address
     * @param from Sender address
     * @param recipients Array of recipient addresses
     * @param amounts Array of transfer amounts
     * @return success True if all transfers successful
     */
    function executeBatchTransfer(
        address token,
        address from,
        address[] calldata recipients,
        uint256[] calldata amounts
    ) external onlyAuthorized nonReentrant whenNotPaused validToken(token) returns (bool success) {
        require(recipients.length == amounts.length, "Array length mismatch");
        require(recipients.length <= maxBatchSize, "Batch size too large");
        require(recipients.length > 0, "Empty batch");

        uint256 totalAmount = 0;
        for (uint256 i = 0; i < amounts.length; i++) {
            require(recipients[i] != address(0), "Invalid recipient");
            require(amounts[i] > 0, "Invalid amount");
            totalAmount += amounts[i];
        }

        require(totalAmount <= getTransferLimit(token), "Total amount exceeds limit");

        uint256 totalFee = 0;
        if (feeEnabled && transferFee > 0) {
            totalFee = totalAmount * transferFee / BASIS_POINTS;
        }

        // Execute individual transfers
        for (uint256 i = 0; i < recipients.length; i++) {
            uint256 fee = 0;
            uint256 netAmount = amounts[i];
            
            if (feeEnabled && transferFee > 0) {
                fee = amounts[i] * transferFee / BASIS_POINTS;
                netAmount = amounts[i] - fee;
            }
            
            IERC20(token).safeTransferFrom(from, recipients[i], netAmount);
        }

        // Transfer total fee if applicable
        if (totalFee > 0) {
            IERC20(token).safeTransferFrom(from, feeRecipient, totalFee);
        }

        emit BatchTransferExecuted(token, from, totalAmount, recipients.length);
        return true;
    }

    /**
     * @dev Execute transfer with signature verification
     * @param request Transfer request with signature
     * @return success True if transfer successful
     */
    function executeSignedTransfer(
        TransferRequest calldata request
    ) external onlyAuthorized nonReentrant whenNotPaused validToken(request.token) returns (bool success) {
        require(block.timestamp <= request.deadline, "Transfer expired");
        require(request.nonce == nonces[request.from], "Invalid nonce");
        require(request.amount <= getTransferLimit(request.token), "Amount exceeds limit");

        bytes32 transferHash = keccak256(
            abi.encodePacked(
                request.token,
                request.from,
                request.to,
                request.amount,
                request.nonce,
                request.deadline
            )
        );

        require(!executedTransfers[transferHash], "Transfer already executed");
        
        // Verify signature (simplified - in production use proper ECDSA verification)
        require(request.signature.length == 65, "Invalid signature length");

        // Increment nonce
        nonces[request.from]++;
        executedTransfers[transferHash] = true;

        uint256 fee = 0;
        uint256 netAmount = request.amount;

        if (feeEnabled && transferFee > 0) {
            fee = request.amount * transferFee / BASIS_POINTS;
            netAmount = request.amount - fee;
        }

        // Execute transfer
        IERC20(request.token).safeTransferFrom(request.from, request.to, netAmount);
        
        // Transfer fee if applicable
        if (fee > 0) {
            IERC20(request.token).safeTransferFrom(request.from, feeRecipient, fee);
        }

        emit TransferExecuted(transferHash, request.token, request.from, request.to, netAmount);
        return true;
    }

    /**
     * @dev Emergency transfer function (owner only)
     * @param token Token address
     * @param from Sender address
     * @param to Recipient address
     * @param amount Transfer amount
     */
    function emergencyTransfer(
        address token,
        address from,
        address to,
        uint256 amount
    ) external onlyOwner nonReentrant {
        require(from != address(0) && to != address(0), "Invalid addresses");
        require(amount > 0, "Invalid amount");

        IERC20(token).safeTransferFrom(from, to, amount);
        
        bytes32 transferId = keccak256(abi.encodePacked("emergency", token, from, to, amount, block.timestamp));
        emit TransferExecuted(transferId, token, from, to, amount);
    }

    /**
     * @dev Set authorized caller status
     * @param caller Caller address
     * @param authorized Authorization status
     */
    function setAuthorizedCaller(address caller, bool authorized) external onlyOwner {
        require(caller != address(0), "Invalid caller");
        authorizedCallers[caller] = authorized;
        emit AuthorizedCallerUpdated(caller, authorized);
    }

    /**
     * @dev Set token support status
     * @param token Token address
     * @param supported Support status
     */
    function setTokenSupport(address token, bool supported) external onlyOwner {
        require(token != address(0), "Invalid token");
        supportedTokens[token] = supported;
        emit TokenSupportUpdated(token, supported);
    }

    /**
     * @dev Set transfer limit for a token
     * @param token Token address
     * @param limit Transfer limit
     */
    function setTransferLimit(address token, uint256 limit) external onlyOwner {
        require(token != address(0), "Invalid token");
        transferLimits[token] = limit;
        emit TransferLimitUpdated(token, limit);
    }

    /**
     * @dev Update fee configuration
     * @param fee New transfer fee (basis points)
     * @param recipient New fee recipient
     * @param enabled Fee enabled status
     */
    function updateFeeConfig(uint256 fee, address recipient, bool enabled) external onlyOwner {
        require(fee <= 1000, "Fee too high"); // Max 10%
        require(recipient != address(0), "Invalid recipient");
        
        transferFee = fee;
        feeRecipient = recipient;
        feeEnabled = enabled;
        
        emit FeeConfigUpdated(fee, recipient, enabled);
    }

    /**
     * @dev Update batch size limit
     * @param newLimit New batch size limit
     */
    function setMaxBatchSize(uint256 newLimit) external onlyOwner {
        require(newLimit > 0 && newLimit <= 1000, "Invalid batch size");
        maxBatchSize = newLimit;
    }

    /**
     * @dev Get transfer limit for a token
     * @param token Token address
     * @return limit Transfer limit
     */
    function getTransferLimit(address token) public view returns (uint256 limit) {
        uint256 tokenLimit = transferLimits[token];
        return tokenLimit > 0 ? tokenLimit : defaultTransferLimit;
    }

    /**
     * @dev Get user nonce
     * @param user User address
     * @return nonce Current nonce
     */
    function getUserNonce(address user) external view returns (uint256 nonce) {
        return nonces[user];
    }

    /**
     * @dev Check if transfer was executed
     * @param transferId Transfer ID
     * @return executed True if executed
     */
    function isTransferExecuted(bytes32 transferId) external view returns (bool executed) {
        return executedTransfers[transferId];
    }

    /**
     * @dev Calculate transfer fee
     * @param amount Transfer amount
     * @return fee Fee amount
     */
    function calculateFee(uint256 amount) external view returns (uint256 fee) {
        if (!feeEnabled || transferFee == 0) {
            return 0;
        }
        return amount * transferFee / BASIS_POINTS;
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