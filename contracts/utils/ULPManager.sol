// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./TokenVault.sol";

contract ULPManager is ReentrancyGuard {
    using SafeERC20 for IERC20;
    
    mapping(address => TokenVault) public vaults;
    mapping(address => bool) public supportedTokens;
    mapping(address => uint256) public totalLiquidity;
    
    address public owner;
    uint256 public constant DEPOSIT_FEE = 30; // 0.3%
    uint256 public constant FEE_PRECISION = 10000;
    
    event Deposit(address indexed user, address indexed token, uint256 amount, uint256 shares);
    event Withdraw(address indexed user, address indexed token, uint256 amount, uint256 shares);
    event TokenAdded(address indexed token, address indexed vault);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }
    
    constructor() {
        owner = msg.sender;
    }
    
    function addToken(address token) external onlyOwner {
        require(!supportedTokens[token], "Token already supported");
        
        TokenVault vault = new TokenVault(token, "CoreFluidX Vault Token", "cfxVT");
        vaults[token] = vault;
        supportedTokens[token] = true;
        
        emit TokenAdded(token, address(vault));
    }
    
    function deposit(address token, uint256 amount) external nonReentrant {
        require(supportedTokens[token], "Token not supported");
        require(amount > 0, "Amount must be greater than 0");
        
        TokenVault vault = vaults[token];
        IERC20(token).safeTransferFrom(msg.sender, address(vault), amount);
        
        // Calculate fee
        uint256 fee = (amount * DEPOSIT_FEE) / FEE_PRECISION;
        uint256 netAmount = amount - fee;
        
        // Mint vault shares
        uint256 shares = vault.deposit(netAmount, msg.sender);
        totalLiquidity[token] += netAmount;
        
        emit Deposit(msg.sender, token, netAmount, shares);
    }
    
    function withdraw(address token, uint256 shares) external nonReentrant {
        require(supportedTokens[token], "Token not supported");
        require(shares > 0, "Shares must be greater than 0");
        
        TokenVault vault = vaults[token];
        uint256 amount = vault.redeem(shares, msg.sender, msg.sender);
        totalLiquidity[token] -= amount;
        
        emit Withdraw(msg.sender, token, amount, shares);
    }
    
    function getVaultBalance(address token, address user) external view returns (uint256) {
        if (!supportedTokens[token]) return 0;
        return vaults[token].balanceOf(user);
    }
    
    function getTokenPrice(address token) external view returns (uint256) {
        if (!supportedTokens[token]) return 0;
        return vaults[token].convertToAssets(1e18);
    }
}
