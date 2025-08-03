// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/OptimizedTULL.sol";
import "../src/SimpleToken.sol";

contract OptimizedTULLDeploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy treasury address (using deployer for simplicity)
        address treasury = vm.addr(deployerPrivateKey);
        
        // Deploy OptimizedTULL
        OptimizedTULL optimizedTULL = new OptimizedTULL(treasury);
        console.log("OptimizedTULL deployed at:", address(optimizedTULL));
        
        // Deploy test tokens
        SimpleToken coreToken = new SimpleToken("CORE Token", "CORE", 18, 1000000 * 10**18);
        SimpleToken btcToken = new SimpleToken("BTC Token", "BTC", 8, 21000000 * 10**8);
        
        console.log("CORE Token deployed at:", address(coreToken));
        console.log("BTC Token deployed at:", address(btcToken));
        
        // Add supported assets
        optimizedTULL.addSupportedAsset(address(coreToken), 1000 * 10**18); // 1000 CORE idle threshold
        optimizedTULL.addSupportedAsset(address(btcToken), 1 * 10**8); // 1 BTC idle threshold
        
        // Register mock protocols with different yield rates
        address mockProtocol1 = address(0x1111111111111111111111111111111111111111);
        address mockProtocol2 = address(0x2222222222222222222222222222222222222222);
        address mockProtocol3 = address(0x3333333333333333333333333333333333333333);
        
        optimizedTULL.registerProtocol(mockProtocol1, 500, 100000 * 10**18); // 5% APR, 100k capacity
        optimizedTULL.registerProtocol(mockProtocol2, 800, 50000 * 10**18);  // 8% APR, 50k capacity
        optimizedTULL.registerProtocol(mockProtocol3, 1200, 25000 * 10**18); // 12% APR, 25k capacity
        
        // Grant protocol role to treasury for testing
        optimizedTULL.grantRole(optimizedTULL.PROTOCOL_ROLE(), treasury);
        optimizedTULL.grantRole(optimizedTULL.KEEPER_ROLE(), treasury);
        
        console.log("Setup completed!");
        console.log("Treasury address:", treasury);
        console.log("Mock Protocol 1:", mockProtocol1);
        console.log("Mock Protocol 2:", mockProtocol2);
        console.log("Mock Protocol 3:", mockProtocol3);
        
        vm.stopBroadcast();
    }
}
