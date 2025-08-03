// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "../lib/forge-std/src/Script.sol";
import {SimpleToken} from "../src/SimpleToken.sol";

contract Deploy is Script {
    function run() external {
        uint256 deployerPrivateKey = 0x16b71b93de162f7af28c557d3248560461d20e1547adb86f01a31acb05cc9c07;
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy SimpleToken
        SimpleToken token = new SimpleToken(
            "CoreLiquid Test Token",
            "CLT",
            18,
            1000000 * 10**18 // 1M tokens
        );
        
        console.log("SimpleToken deployed at:", address(token));
        console.log("Token name:", token.name());
        console.log("Token symbol:", token.symbol());
        console.log("Total supply:", token.totalSupply());
        
        vm.stopBroadcast();
    }
}
