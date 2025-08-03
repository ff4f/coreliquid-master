// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../lib/forge-std/src/Script.sol";
import "../src/CoreBitcoinDualStaking.sol";
import "../src/SimpleToken.sol";

contract DeployDualStaking is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy CORE and BTC tokens
        SimpleToken coreToken = new SimpleToken(
            "Core Token",
            "CORE",
            18, // decimals
            1000000 * 1e18 // 1M CORE
        );
        
        SimpleToken btcToken = new SimpleToken(
            "Bitcoin Token",
            "BTC",
            18, // decimals
            10000 * 1e18 // 10K BTC
        );

        // Deploy CoreBitcoinDualStaking
        CoreBitcoinDualStaking dualStaking = new CoreBitcoinDualStaking(
            address(coreToken),
            address(btcToken)
        );

        console.log("CORE Token deployed to:", address(coreToken));
        console.log("BTC Token deployed to:", address(btcToken));
        console.log("CoreBitcoinDualStaking deployed to:", address(dualStaking));

        vm.stopBroadcast();
    }
}
