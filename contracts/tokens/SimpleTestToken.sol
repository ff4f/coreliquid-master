// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title SimpleTestToken
 * @dev A simple ERC20-like token for testing deployment to Core testnet
 * @notice This contract is isolated to avoid compilation conflicts
 */
contract SimpleTestToken {
    string public name = "CoreLiquid Test Token";
    string public symbol = "CLT";
    uint8 public decimals = 18;
    uint256 public totalSupply;
    
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    
    address public owner;
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Mint(address indexed to, address indexed by, uint256 value);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }
    
    constructor(uint256 _initialSupply) {
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
        
        emit Mint(to, msg.sender, value);
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
    
    function burn(uint256 value) external {
        require(balanceOf[msg.sender] >= value, "Insufficient balance to burn");
        
        balanceOf[msg.sender] -= value;
        totalSupply -= value;
        
        emit Transfer(msg.sender, address(0), value);
    }
}
