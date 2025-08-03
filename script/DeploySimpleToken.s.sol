// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../contracts/SimpleTestToken.sol";

contract DeploySimpleTokenScript is Script {
    function run() external {
        uint256 deployerPrivateKey = 0x4f3edf983ac636a65a842ce7c78d9aa706d3b113bce9c46f30d7d21715b23b1d;
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy SimpleTestToken with 1M initial supply
        SimpleTestToken token = new SimpleTestToken(1000000 * 10**18);
        
        console.log("SimpleTestToken deployed to:", address(token));
        console.log("Deployer:", vm.addr(deployerPrivateKey));
        console.log("Initial supply:", token.totalSupply());
        console.log("Token name:", token.name());
        console.log("Token symbol:", token.symbol());
        
        vm.stopBroadcast();
    }
}
