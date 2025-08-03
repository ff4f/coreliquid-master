// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract ProtocolRouter {
    mapping(string => address) public modules;
    mapping(address => bool) public authorizedCallers;
    
    address public owner;
    
    event ModuleRegistered(string indexed name, address indexed module);
    event CallerAuthorized(address indexed caller, bool authorized);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }
    
    modifier onlyAuthorized() {
        require(authorizedCallers[msg.sender] || msg.sender == owner, "Not authorized");
        _;
    }
    
    constructor() {
        owner = msg.sender;
        authorizedCallers[msg.sender] = true;
    }
    
    function registerModule(string calldata name, address module) external onlyOwner {
        modules[name] = module;
        emit ModuleRegistered(name, module);
    }
    
    function getModule(string calldata name) external view returns (address) {
        return modules[name];
    }
    
    function setAuthorizedCaller(address caller, bool authorized) external onlyOwner {
        authorizedCallers[caller] = authorized;
        emit CallerAuthorized(caller, authorized);
    }
    
    function delegateCall(string calldata moduleName, bytes calldata data) 
        external 
        onlyAuthorized 
        returns (bytes memory) 
    {
        address module = modules[moduleName];
        require(module != address(0), "Module not found");
        
        (bool success, bytes memory result) = module.delegatecall(data);
        require(success, "Delegate call failed");
        
        return result;
    }
}
