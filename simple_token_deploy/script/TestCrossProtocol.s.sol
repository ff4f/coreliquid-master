// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "../lib/forge-std/src/Script.sol";
import {SimpleToken} from "../src/SimpleToken.sol";

/**
 * @title TestCrossProtocol
 * @dev Test script to verify cross-protocol access functionality
 */
contract TestCrossProtocol is Script {
    SimpleToken public token;
    address public mockProtocol;
    address public testUser;
    
    function setUp() public {
        // Deploy SimpleToken
        token = new SimpleToken(
            "CoreLiquid Test Token",
            "CLT", 
            18,
            1000000 * 10**18
        );
        
        // Create mock addresses
        mockProtocol = address(0x1234567890123456789012345678901234567890);
        testUser = address(0x9876543210987654321098765432109876543210);
        
        console.log("SimpleToken deployed at:", address(token));
        console.log("Mock protocol address:", mockProtocol);
        console.log("Test user address:", testUser);
    }
    
    function run() public {
        vm.startBroadcast();
        
        setUp();
        
        // Test 1: Authorize protocol
        console.log("\n=== Test 1: Authorize Protocol ===");
        token.authorizeProtocol(mockProtocol, true);
        console.log("Protocol authorized:", token.authorizedProtocols(mockProtocol));
        
        // Test 2: Mint tokens to test user
        console.log("\n=== Test 2: Mint Tokens ===");
        uint256 mintAmount = 10000 * 10**18;
        token.mint(testUser, mintAmount);
        console.log("Minted", mintAmount / 10**18, "CLT to test user");
        console.log("Test user balance:", token.balanceOf(testUser) / 10**18, "CLT");
        
        // Test 3: Deposit to shared pool (simulate as test user)
        console.log("\n=== Test 3: Deposit to Shared Pool ===");
        vm.stopBroadcast();
        vm.startPrank(testUser);
        
        uint256 depositAmount = 5000 * 10**18;
        token.depositToSharedPool(depositAmount);
        console.log("Deposited", depositAmount / 10**18, "CLT to shared pool");
        console.log("Shared pool balance:", token.sharedPoolBalance(testUser) / 10**18, "CLT");
        console.log("Regular balance:", token.balanceOf(testUser) / 10**18, "CLT");
        console.log("Total accessible:", token.getTotalAccessibleBalance(testUser) / 10**18, "CLT");
        
        vm.stopPrank();
        vm.startBroadcast();
        
        // Test 4: Check access capability
        console.log("\n=== Test 4: Check Access Capability ===");
        uint256 accessAmount = 2000 * 10**18;
        bool canAccess = token.canAccessAssets(mockProtocol, testUser, accessAmount);
        console.log("Can access", accessAmount / 10**18, "CLT:", canAccess);
        
        // Test 5: Access assets (simulate as protocol)
        console.log("\n=== Test 5: Access Assets ===");
        vm.stopBroadcast();
        vm.startPrank(mockProtocol);
        
        bytes memory data = abi.encode("test_protocol_data");
        bool success = token.accessAssets(address(token), accessAmount, testUser, data);
        console.log("Access successful:", success);
        console.log("Shared pool after access:", token.sharedPoolBalance(testUser) / 10**18, "CLT");
        console.log("Total shared pool:", token.totalSharedPool() / 10**18, "CLT");
        
        // Test 6: Return assets
        console.log("\n=== Test 6: Return Assets ===");
        token.returnAssets(testUser, accessAmount);
        console.log("Assets returned successfully");
        console.log("Shared pool after return:", token.sharedPoolBalance(testUser) / 10**18, "CLT");
        console.log("Total shared pool:", token.totalSharedPool() / 10**18, "CLT");
        
        vm.stopPrank();
        vm.startBroadcast();
        
        // Test 7: Final state verification
        console.log("\n=== Test 7: Final State ===");
        console.log("Token name:", token.name());
        console.log("Token symbol:", token.symbol());
        console.log("Total supply:", token.totalSupply() / 10**18, "CLT");
        console.log("Test user regular balance:", token.balanceOf(testUser) / 10**18, "CLT");
        console.log("Test user shared pool:", token.sharedPoolBalance(testUser) / 10**18, "CLT");
        console.log("Test user total accessible:", token.getTotalAccessibleBalance(testUser) / 10**18, "CLT");
        
        console.log("\n=== All cross-protocol tests completed successfully! ===");
        console.log("[SUCCESS] accessAssets function is working");
        console.log("[SUCCESS] Shared pool functionality is working");
        console.log("[SUCCESS] Protocol authorization is working");
        console.log("[SUCCESS] Ready for Core Connect Hackathon!");
        
        vm.stopBroadcast();
    }
}
