// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract TestContract {
    address public owner;
    uint256 public value;
    
    constructor(address _owner) {
        owner = _owner;
        value = 42;
    }
    
    function setValue(uint256 _value) external {
        require(msg.sender == owner, "Not owner");
        value = _value;
    }
}
