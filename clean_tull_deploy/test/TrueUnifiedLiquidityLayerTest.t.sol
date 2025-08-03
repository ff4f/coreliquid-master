// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/TrueUnifiedLiquidityLayer.sol";
import "../src/SimpleToken.sol";

/**
 * @title TrueUnifiedLiquidityLayerTest
 * @dev Basic test suite for TrueUnifiedLiquidityLayer
 */
contract TrueUnifiedLiquidityLayerTest is Test {
    TrueUnifiedLiquidityLayer public liquidityLayer;
    SimpleToken public testToken;
    
    address public treasury = address(0x1234);
    address public user1 = address(0x5678);
    address public protocol1 = address(0x9ABC);
    
    uint256 public constant INITIAL_SUPPLY = 1000000 * 1e18;
    uint256 public constant DEPOSIT_AMOUNT = 1000 * 1e18;
    
    function setUp() public {
        // Deploy contracts
        liquidityLayer = new TrueUnifiedLiquidityLayer(treasury);
        testToken = new SimpleToken("Test Token", "TEST", 18, INITIAL_SUPPLY);
        
        // Setup roles
        liquidityLayer.grantRole(liquidityLayer.PROTOCOL_ROLE(), protocol1);
        liquidityLayer.grantRole(liquidityLayer.KEEPER_ROLE(), address(this));
        
        // Add supported assets
        liquidityLayer.addSupportedAsset(address(testToken));
        
        // Distribute tokens
        testToken.transfer(protocol1, DEPOSIT_AMOUNT * 10);
        
        // Register protocol
        liquidityLayer.registerProtocol(
            protocol1,
            "Test Protocol",
            500, // 5% APY
            DEPOSIT_AMOUNT * 100,
            20 // Low risk
        );
    }
    
    function testDeposit() public {
        // Approve and deposit
        vm.startPrank(protocol1);
        testToken.approve(address(liquidityLayer), DEPOSIT_AMOUNT);
        liquidityLayer.deposit(address(testToken), DEPOSIT_AMOUNT, user1);
        vm.stopPrank();
        
        // Check balance
        assertEq(liquidityLayer.userBalances(user1, address(testToken)), DEPOSIT_AMOUNT);
        
        // Check asset analytics
        (uint256 totalDeposited, uint256 totalUtilized, uint256 idleCapital, uint256 weightedAPY, uint256 protocolCount, uint256 lastRebalanceTime) = liquidityLayer.getAssetAnalytics(address(testToken));
        assertEq(totalDeposited, DEPOSIT_AMOUNT);
        assertGt(totalDeposited, 0);
    }
    
    function testCrossProtocolAccess() public {
        // First deposit
        vm.startPrank(protocol1);
        testToken.approve(address(liquidityLayer), DEPOSIT_AMOUNT);
        liquidityLayer.deposit(address(testToken), DEPOSIT_AMOUNT, user1);
        
        // Access assets without transfer
        uint256 accessAmount = DEPOSIT_AMOUNT / 2;
        liquidityLayer.accessAssets(protocol1, address(testToken), accessAmount, user1);
        vm.stopPrank();
        
        // Check allocation
        assertEq(liquidityLayer.protocolAllocations(protocol1, address(testToken)), accessAmount);
        
        // Check utilization
        (uint256 totalDeposited2, uint256 totalUtilized2, uint256 idleCapital2, uint256 weightedAPY2, uint256 protocolCount2, uint256 lastRebalanceTime2) = liquidityLayer.getAssetAnalytics(address(testToken));
        assertEq(totalUtilized2, accessAmount);
    }
    
    function testReturnAssetsWithYield() public {
        // Setup: deposit and access
        vm.startPrank(protocol1);
        testToken.approve(address(liquidityLayer), DEPOSIT_AMOUNT);
        liquidityLayer.deposit(address(testToken), DEPOSIT_AMOUNT, user1);
        
        uint256 accessAmount = DEPOSIT_AMOUNT / 2;
        liquidityLayer.accessAssets(protocol1, address(testToken), accessAmount, user1);
        
        // Return with yield
        uint256 yieldAmount = accessAmount / 10; // 10% yield
        liquidityLayer.returnAssets(protocol1, address(testToken), accessAmount, yieldAmount);
        vm.stopPrank();
        
        // Check allocation cleared
        assertEq(liquidityLayer.protocolAllocations(protocol1, address(testToken)), 0);
        
        // Check yield generated
        (uint256 totalDeposited3, uint256 totalUtilized3, uint256 idleCapital3, uint256 weightedAPY3, uint256 protocolCount3, uint256 lastRebalanceTime3) = liquidityLayer.getAssetAnalytics(address(testToken));
        // Note: totalYieldGenerated is not available in getAssetAnalytics, so we check that total deposited increased
        assertGt(totalDeposited3, DEPOSIT_AMOUNT);
    }
    
    function testWithdraw() public {
        // Setup: deposit first
        vm.startPrank(protocol1);
        testToken.approve(address(liquidityLayer), DEPOSIT_AMOUNT);
        liquidityLayer.deposit(address(testToken), DEPOSIT_AMOUNT, user1);
        
        // Withdraw
        uint256 withdrawAmount = DEPOSIT_AMOUNT / 2;
        liquidityLayer.withdraw(address(testToken), withdrawAmount, user1);
        vm.stopPrank();
        
        // Check balance
        assertEq(liquidityLayer.userBalances(user1, address(testToken)), DEPOSIT_AMOUNT - withdrawAmount);
    }
    
    function testIdleCapitalDetection() public {
        // Large deposit
        uint256 largeDeposit = DEPOSIT_AMOUNT * 5;
        
        vm.startPrank(protocol1);
        testToken.approve(address(liquidityLayer), largeDeposit);
        liquidityLayer.deposit(address(testToken), largeDeposit, user1);
        vm.stopPrank();
        
        // Check idle capital
        (uint256 totalDeposited5, uint256 totalUtilized5, uint256 idleCapital5, uint256 weightedAPY5, uint256 protocolCount5, uint256 lastRebalanceTime5) = liquidityLayer.getAssetAnalytics(address(testToken));
        assertEq(idleCapital5, largeDeposit);
        
        // Trigger daily rebalance
        address[] memory assets = new address[](1);
        assets[0] = address(testToken);
        liquidityLayer.executeDailyRebalance(assets);
        
        // Check rebalance timestamp updated
        (uint256 totalDeposited4, uint256 totalUtilized4, uint256 idleCapital4, uint256 weightedAPY4, uint256 protocolCount4, uint256 lastRebalanceTime4) = liquidityLayer.getAssetAnalytics(address(testToken));
        assertGt(lastRebalanceTime4, 0);
    }
    
    function testTotalValueLocked() public {
        vm.startPrank(protocol1);
        testToken.approve(address(liquidityLayer), DEPOSIT_AMOUNT);
        liquidityLayer.deposit(address(testToken), DEPOSIT_AMOUNT, user1);
        vm.stopPrank();
        
        uint256 totalTVL = liquidityLayer.getTotalValueLocked();
        assertEq(totalTVL, DEPOSIT_AMOUNT);
    }
    
    function testProtocolManagement() public {
        address newProtocol = address(0x3333);
        
        liquidityLayer.registerProtocol(
            newProtocol,
            "New Protocol",
            1000, // 10% APY
            DEPOSIT_AMOUNT * 200,
            60 // Higher risk
        );
        
        (string memory name, uint256 currentAPY, uint256 maxCapacity, uint256 totalAllocated, uint256 totalYieldGenerated, uint256 riskScore, uint256 lastUpdateTimestamp, bool isActive) = liquidityLayer.registeredProtocols(newProtocol);
        assertEq(currentAPY, 1000);
        assertTrue(isActive);
    }
    
    function testEmergencyPause() public {
        // Emergency withdrawal (using DEFAULT_ADMIN_ROLE)
        liquidityLayer.emergencyWithdrawFromProtocol(protocol1, address(testToken), 1000 ether);
        
        // Emergency pause
        liquidityLayer.emergencyPause();
        assertTrue(liquidityLayer.paused());
        
        // Emergency unpause
        liquidityLayer.emergencyUnpause();
        assertFalse(liquidityLayer.paused());
    }
    
    function test_RevertWhen_UnauthorizedDeposit() public {
        vm.startPrank(user1); // user1 doesn't have PROTOCOL_ROLE
        vm.expectRevert();
        liquidityLayer.deposit(address(testToken), 100, user1);
        vm.stopPrank();
    }
    
    function test_RevertWhen_InsufficientBalance() public {
        vm.startPrank(protocol1);
        vm.expectRevert("Insufficient balance");
        liquidityLayer.withdraw(address(testToken), DEPOSIT_AMOUNT, user1);
        vm.stopPrank();
    }
}
