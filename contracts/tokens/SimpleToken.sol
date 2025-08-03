// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title SimpleToken
 * @dev Enhanced ERC20 token with cross-protocol access capabilities for Core Connect Hackathon
 * @notice Supports shared pool access without withdrawal for cross-protocol interoperability
 */
contract SimpleToken {
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;
    
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    
    address public owner;
    
    // Cross-protocol access state
    mapping(address => bool) public authorizedProtocols;
    mapping(address => uint256) public sharedPoolBalance;
    uint256 public totalSharedPool;
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Mint(address indexed to, uint256 value);
    event AccessAssets(address indexed protocol, address indexed token, uint256 amount, address indexed user, bytes data);
    event ProtocolAuthorized(address indexed protocol, bool authorized);
    event SharedPoolDeposit(address indexed user, uint256 amount);
    event SharedPoolWithdraw(address indexed user, uint256 amount);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }
    
    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        uint256 _initialSupply
    ) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        owner = msg.sender;
        
        if (_initialSupply > 0) {
            totalSupply = _initialSupply;
            balanceOf[msg.sender] = _initialSupply;
            emit Transfer(address(0), msg.sender, _initialSupply);
        }
    }
    
    function transfer(address to, uint256 value) external returns (bool) {
        require(to != address(0), "Transfer to zero address");
        require(balanceOf[msg.sender] >= value, "Insufficient balance");
        
        balanceOf[msg.sender] -= value;
        balanceOf[to] += value;
        
        emit Transfer(msg.sender, to, value);
        return true;
    }
    
    function approve(address spender, uint256 value) external returns (bool) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }
    
    function transferFrom(address from, address to, uint256 value) external returns (bool) {
        require(to != address(0), "Transfer to zero address");
        require(balanceOf[from] >= value, "Insufficient balance");
        require(allowance[from][msg.sender] >= value, "Insufficient allowance");
        
        balanceOf[from] -= value;
        balanceOf[to] += value;
        allowance[from][msg.sender] -= value;
        
        emit Transfer(from, to, value);
        return true;
    }
    
    function mint(address to, uint256 value) external onlyOwner {
        require(to != address(0), "Mint to zero address");
        
        totalSupply += value;
        balanceOf[to] += value;
        
        emit Mint(to, value);
        emit Transfer(address(0), to, value);
    }
    
    function getInfo() external view returns (
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        uint256 _totalSupply,
        address _owner
    ) {
        return (name, symbol, decimals, totalSupply, owner);
    }
    
    // ============ CROSS-PROTOCOL ACCESS FUNCTIONS ============
    
    /**
     * @dev CRITICAL: Main function for cross-protocol access without withdrawal
     * @param token The token address to access (should be this contract for native access)
     * @param amount The amount to access from shared pool
     * @param user The user whose assets are being accessed
     * @param data Additional data for protocol-specific logic
     */
    function accessAssets(
        address token,
        uint256 amount,
        address user,
        bytes calldata data
    ) external returns (bool) {
        require(authorizedProtocols[msg.sender], "Protocol not authorized");
        require(token == address(this), "Invalid token address");
        require(sharedPoolBalance[user] >= amount, "Insufficient shared pool balance");
        
        // Temporarily reduce user's shared pool balance
        sharedPoolBalance[user] -= amount;
        totalSharedPool -= amount;
        
        emit AccessAssets(msg.sender, token, amount, user, data);
        
        // Protocol can now use the assets without actual transfer
        // Assets remain in the contract but are "virtually" accessible
        
        return true;
    }
    
    /**
     * @dev Return assets back to shared pool after protocol usage
     * @param user The user to return assets to
     * @param amount The amount to return
     */
    function returnAssets(address user, uint256 amount) external {
        require(authorizedProtocols[msg.sender], "Protocol not authorized");
        
        sharedPoolBalance[user] += amount;
        totalSharedPool += amount;
    }
    
    /**
     * @dev Deposit tokens to shared pool for cross-protocol access
     * @param amount Amount to deposit to shared pool
     */
    function depositToSharedPool(uint256 amount) external {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        
        balanceOf[msg.sender] -= amount;
        sharedPoolBalance[msg.sender] += amount;
        totalSharedPool += amount;
        
        emit SharedPoolDeposit(msg.sender, amount);
    }
    
    /**
     * @dev Withdraw tokens from shared pool back to regular balance
     * @param amount Amount to withdraw from shared pool
     */
    function withdrawFromSharedPool(uint256 amount) external {
        require(sharedPoolBalance[msg.sender] >= amount, "Insufficient shared pool balance");
        
        sharedPoolBalance[msg.sender] -= amount;
        totalSharedPool -= amount;
        balanceOf[msg.sender] += amount;
        
        emit SharedPoolWithdraw(msg.sender, amount);
    }
    
    /**
     * @dev Authorize a protocol to access shared pool assets
     * @param protocol Protocol address to authorize
     * @param authorized Whether to authorize or revoke
     */
    function authorizeProtocol(address protocol, bool authorized) external onlyOwner {
        authorizedProtocols[protocol] = authorized;
        emit ProtocolAuthorized(protocol, authorized);
    }
    
    /**
     * @dev Get user's total accessible balance (regular + shared pool)
     * @param user User address
     * @return total Total accessible balance
     */
    function getTotalAccessibleBalance(address user) external view returns (uint256 total) {
        return balanceOf[user] + sharedPoolBalance[user];
    }
    
    /**
     * @dev Check if a protocol can access user's assets
     * @param protocol Protocol address
     * @param user User address
     * @param amount Amount to check
     * @return canAccess Whether access is possible
     */
    function canAccessAssets(
        address protocol,
        address user,
        uint256 amount
    ) external view returns (bool canAccess) {
        return authorizedProtocols[protocol] && sharedPoolBalance[user] >= amount;
    }
}
