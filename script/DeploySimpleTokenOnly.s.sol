// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../contracts/tokens/SimpleToken.sol";

contract DeploySimpleTokenOnly is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
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
