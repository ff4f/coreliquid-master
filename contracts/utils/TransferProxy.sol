// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title TransferProxy
 * @dev Handles safe token transfers with approval management
 */
contract TransferProxy is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;
    
    mapping(address => bool) public authorizedCallers;
    
    event TransferExecuted(address indexed token, address indexed from, address indexed to, uint256 amount);
    event CallerAuthorized(address indexed caller, bool authorized);
    
    modifier onlyAuthorized() {
        require(authorizedCallers[msg.sender] || msg.sender == owner(), "Not authorized");
        _;
    }
    
    constructor(address initialOwner) Ownable(initialOwner) {}
    
    function setAuthorizedCaller(address caller, bool authorized) external onlyOwner {
        authorizedCallers[caller] = authorized;
        emit CallerAuthorized(caller, authorized);
    }
    
    function safeTransferFrom(
        address token,
        address from,
        address to,
        uint256 amount
    ) external onlyAuthorized nonReentrant {
        require(token != address(0), "Invalid token");
        require(from != address(0) && to != address(0), "Invalid addresses");
        require(amount > 0, "Invalid amount");
        
        IERC20(token).safeTransferFrom(from, to, amount);
        emit TransferExecuted(token, from, to, amount);
    }
    
    function safeTransfer(
        address token,
        address to,
        uint256 amount
    ) external onlyAuthorized nonReentrant {
        require(token != address(0), "Invalid token");
        require(to != address(0), "Invalid address");
        require(amount > 0, "Invalid amount");
        
        IERC20(token).safeTransfer(to, amount);
        emit TransferExecuted(token, address(this), to, amount);
    }
    
    function batchTransfer(
        address[] calldata tokens,
        address[] calldata recipients,
        uint256[] calldata amounts
    ) external onlyAuthorized nonReentrant {
        require(tokens.length == recipients.length && recipients.length == amounts.length, "Array length mismatch");
        
        for (uint256 i = 0; i < tokens.length; i++) {
            IERC20(tokens[i]).safeTransfer(recipients[i], amounts[i]);
            emit TransferExecuted(tokens[i], address(this), recipients[i], amounts[i]);
        }
    }
    
    function getTokenBalance(address token) external view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }
}
