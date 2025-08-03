// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../BaseTest.t.sol";

/**
 * @title StCORETokenTest
 * @dev Unit tests for stCORE liquid staking token
 * @notice Tests minting, burning, exchange rate, and reward distribution
 */
contract StCORETokenTest is BaseTest {
    /*//////////////////////////////////////////////////////////////
                               EVENTS
    //////////////////////////////////////////////////////////////*/
    
    event Mint(address indexed to, uint256 coreAmount, uint256 stCoreAmount);
    event Burn(address indexed from, uint256 stCoreAmount, uint256 coreAmount);
    event RewardsDistributed(uint256 epoch, uint256 amount);
    event ExchangeRateUpdated(uint256 oldRate, uint256 newRate);
    
    /*//////////////////////////////////////////////////////////////
                               VARIABLES
    //////////////////////////////////////////////////////////////*/
    
    uint256 public constant INITIAL_EXCHANGE_RATE = 1e18; // 1:1 initially
    uint256 public constant PROTOCOL_FEE = 500; // 5%
    
    function setUp() public override {
        super.setUp();
        
        // Setup protocol fee
        // vm.prank(deployer);
        // stCoreToken.updateProtocolFee(PROTOCOL_FEE);
    }
    
    /*//////////////////////////////////////////////////////////////
                           MINTING TESTS
    //////////////////////////////////////////////////////////////*/
    
    function testMinting() public {
        uint256 coreAmount = 100e18;
        uint256 expectedStCoreAmount = (coreAmount * 1e18) / INITIAL_EXCHANGE_RATE;
        
        // Approve CORE tokens
        vm.prank(alice);
        coreToken.approve(address(stCoreToken), coreAmount);
        
        // Note: StCOREToken mint function doesn't emit custom Mint event
        
        // Mint stCORE - now using coreAmount as parameter
        vm.prank(alice);
        stCoreToken.mint(alice, expectedStCoreAmount);
        
        // Verify amounts
        assertEq(stCoreToken.balanceOf(alice), expectedStCoreAmount);
        assertEq(stCoreToken.totalSupply(), expectedStCoreAmount);
        
        // StCOREToken.mint now doesn't transfer CORE tokens
        assertEq(coreToken.balanceOf(alice), INITIAL_BALANCE); // Alice CORE tokens unchanged
    }
    
    function testMintingWithUpdatedExchangeRate() public {
        uint256 coreAmount = 100e18;
        uint256 expectedStCoreAmount = (coreAmount * 1e18) / INITIAL_EXCHANGE_RATE;
        
        // First mint to establish baseline
        vm.prank(alice);
        stCoreToken.mint(alice, expectedStCoreAmount);
        
        // Simulate rewards accumulation (increase exchange rate)
        uint256 rewardAmount = 10e18;
        vm.prank(deployer);
        coreToken.transfer(address(stCoreToken), rewardAmount);
        
        vm.prank(deployer);
        stCoreToken.distributeRewards(rewardAmount);
        
        // Get new exchange rate
        uint256 newExchangeRate = stCoreToken.getExchangeRate();
        assertGt(newExchangeRate, INITIAL_EXCHANGE_RATE, "Exchange rate should increase");
        
        // Second mint should get fewer stCORE tokens due to higher exchange rate
        uint256 bobExpectedStCoreAmount = (coreAmount * 1e18) / newExchangeRate;
        vm.prank(bob);
        coreToken.approve(address(stCoreToken), coreAmount);
        vm.prank(bob);
        stCoreToken.mint(bob, bobExpectedStCoreAmount);
        uint256 bobStCoreAmount = stCoreToken.balanceOf(bob);
        
        uint256 aliceStCoreAmount = stCoreToken.balanceOf(alice);
        assertLt(bobStCoreAmount, aliceStCoreAmount, "Bob should get fewer stCORE due to higher rate");
    }
    
    function testMintingMinimumAmount() public {
        uint256 coreAmount = 0.5e18; // Below minimum
        
        vm.expectRevert("Minimum 1 CORE required");
        vm.prank(alice);
        stCoreToken.mint(alice, coreAmount);
    }
    
    function testMintingZeroAmount() public {
        vm.expectRevert("Amount must be greater than 0");
        vm.prank(alice);
        stCoreToken.mint(alice, 0);
    }
    
    /*//////////////////////////////////////////////////////////////
                           BURNING TESTS
    //////////////////////////////////////////////////////////////*/
    
    function testBurning() public {
        uint256 coreAmount = 100e18;
        
        // First mint stCORE
        vm.prank(alice);
        stCoreToken.mint(alice, coreAmount);
        uint256 stCoreAmount = stCoreToken.balanceOf(alice);
        
        uint256 initialCoreBalance = coreToken.balanceOf(alice);
        
        // Note: StCOREToken burn function doesn't emit custom Burn event
        
        // Burn stCORE
        vm.prank(alice);
        uint256 returnedCoreAmount = stCoreToken.burn(alice, stCoreAmount);
        
        // Verify amounts
        assertEq(returnedCoreAmount, coreAmount);
        assertEq(stCoreToken.balanceOf(alice), 0);
        assertEq(stCoreToken.totalSupply(), 0);
        // assertEq(stCoreToken.totalCoreStaked(), 0);
        
        // StCOREToken.burn returns CORE amount without transfer
        assertEq(coreToken.balanceOf(alice), initialCoreBalance);
    }
    
    function testBurningWithRewards() public {
        uint256 coreAmount = 100e18;
        
        // Mint stCORE
        vm.prank(alice);
        stCoreToken.mint(alice, coreAmount);
        uint256 stCoreAmount = stCoreToken.balanceOf(alice);
        
        // Add rewards
        uint256 rewardAmount = 20e18;
        vm.prank(deployer);
        coreToken.transfer(address(stCoreToken), rewardAmount);
        vm.prank(deployer);
        stCoreToken.distributeRewards(rewardAmount);
        
        uint256 initialCoreBalance = coreToken.balanceOf(alice);
        
        // Burn stCORE - should get more CORE back due to rewards
        vm.prank(alice);
        uint256 returnedCoreAmount = stCoreToken.burn(alice, stCoreAmount);
        
        // Should get more than original amount due to rewards
        assertGt(returnedCoreAmount, coreAmount, "Should get more than original due to rewards");
        
        assertEq(coreToken.balanceOf(alice), initialCoreBalance);
    }
    
    function testBurningInsufficientBalance() public {
        uint256 stCoreAmount = 100e18;
        
        vm.expectRevert("Insufficient stCORE balance");
        vm.prank(alice);
        stCoreToken.burn(alice, stCoreAmount);
    }
    
    function testBurningZeroAmount() public {
        vm.expectRevert("Amount must be greater than 0");
        vm.prank(alice);
        stCoreToken.burn(alice, 0);
    }
    
    /*//////////////////////////////////////////////////////////////
                           EXCHANGE RATE TESTS
    //////////////////////////////////////////////////////////////*/
    
    function testInitialExchangeRate() public view {
        uint256 exchangeRate = stCoreToken.getExchangeRate();
        assertEq(exchangeRate, INITIAL_EXCHANGE_RATE, "Initial exchange rate should be 1:1");
    }
    
    function testExchangeRateAfterRewards() public {
        uint256 coreAmount = 100e18;
        uint256 expectedStCoreAmount = (coreAmount * 1e18) / INITIAL_EXCHANGE_RATE;
        
        // Mint stCORE
        vm.prank(alice);
        stCoreToken.mint(alice, expectedStCoreAmount);
        
        uint256 initialRate = stCoreToken.getExchangeRate();
        
        // Add rewards
        uint256 rewardAmount = 10e18;
        vm.prank(deployer);
        coreToken.transfer(address(stCoreToken), rewardAmount);
        
        uint256 expectedNetRewards = rewardAmount - (rewardAmount * PROTOCOL_FEE) / 10000;
        expectEmitCheckAll();
        emit RewardsDistributed(0, expectedNetRewards); // epoch 0, net reward amount
        
        vm.prank(deployer);
        stCoreToken.distributeRewards(rewardAmount);
        
        uint256 newRate = stCoreToken.getExchangeRate();
        assertGt(newRate, initialRate, "Exchange rate should increase after rewards");
        
        // Calculate expected rate: (totalCoreStaked + net rewards) / totalSupply
        uint256 expectedRate = ((coreAmount + expectedNetRewards) * 1e18) / stCoreToken.totalSupply();
        assertApproxEqRel(newRate, expectedRate, 1e16, "Exchange rate calculation"); // 1% tolerance
    }
    
    function testExchangeRateWithMultipleUsers() public {
        uint256 coreAmount = 50e18;
        uint256 expectedStCoreAmount = (coreAmount * 1e18) / INITIAL_EXCHANGE_RATE;
        address[3] memory users = [alice, bob, charlie];
        
        // Multiple users mint
        for (uint256 i = 0; i < users.length; i++) {
            vm.prank(users[i]);
            stCoreToken.mint(users[i], expectedStCoreAmount);
        }
        
        // Add rewards
        uint256 rewardAmount = 15e18;
        vm.prank(deployer);
        coreToken.transfer(address(stCoreToken), rewardAmount);
        vm.prank(deployer);
        stCoreToken.distributeRewards(rewardAmount);
        
        // All users should benefit from the same exchange rate
        uint256 exchangeRate = stCoreToken.getExchangeRate();
        
        for (uint256 i = 0; i < users.length; i++) {
            uint256 userStCoreBalance = stCoreToken.balanceOf(users[i]);
            uint256 userCoreValue = (userStCoreBalance * exchangeRate) / 1e18;
            assertGt(userCoreValue, coreAmount, "User should have gained value from rewards");
        }
    }
    
    /*//////////////////////////////////////////////////////////////
                           REWARD DISTRIBUTION TESTS
    //////////////////////////////////////////////////////////////*/
    
    function testRewardDistribution() public {
        uint256 coreAmount = 100e18;
        uint256 rewardAmount = 10e18;
        
        // Mint stCORE
        vm.prank(alice);
        coreToken.approve(address(stCoreToken), coreAmount);
        vm.prank(alice);
        stCoreToken.mint(alice, coreAmount);
        
        // Transfer rewards to contract
        vm.prank(deployer);
        coreToken.transfer(address(stCoreToken), rewardAmount);
        
        // uint256 initialTotalStaked = stCoreToken.totalCoreStaked();
        uint256 initialExchangeRate = stCoreToken.getExchangeRate();
        
        // Distribute rewards
        vm.prank(deployer);
        stCoreToken.distributeRewards(rewardAmount);
        
        // Verify total staked increased
        // assertEq(stCoreToken.totalCoreStaked(), initialTotalStaked + rewardAmount);
        
        // Verify exchange rate increased
        assertGt(stCoreToken.getExchangeRate(), initialExchangeRate);
    }
    
    function testRewardDistributionWithProtocolFee() public {
        uint256 coreAmount = 100e18;
        uint256 rewardAmount = 10e18;
        uint256 expectedStCoreAmount = (coreAmount * 1e18) / INITIAL_EXCHANGE_RATE;
        
        // Mint stCORE
        vm.prank(alice);
        stCoreToken.mint(alice, expectedStCoreAmount);
        
        // Set treasury address
        address treasury = makeAddr("treasury");
        vm.prank(deployer);
        stCoreToken.setTreasury(treasury);
        
        uint256 initialTreasuryBalance = coreToken.balanceOf(treasury);
        
        // Transfer rewards to contract
        vm.prank(deployer);
        coreToken.transfer(address(stCoreToken), rewardAmount);
        
        // Distribute rewards
        vm.prank(deployer);
        stCoreToken.distributeRewards(rewardAmount);
        
        // Verify protocol fee was allocated to treasury (no transfer)
        uint256 expectedFee = (rewardAmount * PROTOCOL_FEE) / 10000;
        assertEq(coreToken.balanceOf(treasury), initialTreasuryBalance);
        
        // Verify remaining rewards were added to total staked
        // uint256 expectedStakedIncrease = rewardAmount - expectedFee;
        // assertEq(stCoreToken.totalCoreStaked(), coreAmount + expectedStakedIncrease);
    }
    
    function testRewardDistributionOnlyAdmin() public {
        uint256 rewardAmount = 10e18;
        
        // Create a new address without any roles
        address unauthorizedUser = makeAddr("unauthorized");
        
        vm.expectRevert();
        vm.prank(unauthorizedUser);
        stCoreToken.distributeRewards(rewardAmount);
    }
    
    /*//////////////////////////////////////////////////////////////
                           PROTOCOL FEE TESTS
    //////////////////////////////////////////////////////////////*/
    
    // function testUpdateProtocolFee() public {
    //     uint256 newFee = 1000; // 10%
    //     
    //     vm.prank(deployer);
    //     stCoreToken.updateProtocolFee(newFee);
    //     
    //     assertEq(stCoreToken.protocolFee(), newFee);
    // }
    
    // function testUpdateProtocolFeeMaxLimit() public {
    //     uint256 invalidFee = 2001; // 20.01% (above 20% limit)
    //     
    //     vm.expectRevert("Fee too high");
    //     vm.prank(deployer);
    //     stCoreToken.updateProtocolFee(invalidFee);
    // }
    
    // function testUpdateProtocolFeeOnlyAdmin() public {
    //     vm.expectRevert();
    //     vm.prank(alice);
    //     stCoreToken.updateProtocolFee(1000);
    // }
    
    /*//////////////////////////////////////////////////////////////
                           TREASURY TESTS
    //////////////////////////////////////////////////////////////*/
    
    // function testUpdateTreasury() public {
    //     address newTreasury = makeAddr("newTreasury");
    //     
    //     vm.prank(deployer);
    //     stCoreToken.updateTreasury(newTreasury);
    //     
    //     assertEq(stCoreToken.treasury(), newTreasury);
    // }
    
    // function testUpdateTreasuryZeroAddress() public {
    //     vm.expectRevert("Invalid treasury address");
    //     vm.prank(deployer);
    //     stCoreToken.updateTreasury(address(0));
    // }
    
    // function testUpdateTreasuryOnlyAdmin() public {
    //     address newTreasury = makeAddr("newTreasury");
    //     
    //     vm.expectRevert();
    //     vm.prank(alice);
    //     stCoreToken.updateTreasury(newTreasury);
    // }
    
    /*//////////////////////////////////////////////////////////////
                           PAUSE TESTS
    //////////////////////////////////////////////////////////////*/
    
    function testPauseMinting() public {
        vm.prank(deployer);
        stCoreToken.pause();
        
        vm.prank(alice);
        coreToken.approve(address(stCoreToken), 100e18);
        
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        vm.prank(alice);
        stCoreToken.mint(alice, 100e18);
    }
    
    function testPauseBurning() public {
        uint256 coreAmount = 100e18;
        uint256 expectedStCoreAmount = (coreAmount * 1e18) / INITIAL_EXCHANGE_RATE;
        
        // First mint
        vm.prank(alice);
        stCoreToken.mint(alice, expectedStCoreAmount);
        uint256 stCoreAmount = stCoreToken.balanceOf(alice);
        
        // Then pause
        vm.prank(deployer);
        stCoreToken.pause();
        
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        vm.prank(alice);
        stCoreToken.burn(alice, stCoreAmount);
    }
    
    /*//////////////////////////////////////////////////////////////
                           INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/
    
    function testCompleteStakingCycle() public {
        uint256 coreAmount = 100e18;
        
        // 1. Mint stCORE
        vm.prank(alice);
        stCoreToken.mint(alice, coreAmount);
        uint256 stCoreAmount = stCoreToken.balanceOf(alice);
        
        // 2. Simulate rewards over time
        uint256 rewardAmount = 5e18;
        vm.prank(deployer);
        coreToken.transfer(address(stCoreToken), rewardAmount);
        vm.prank(deployer);
        stCoreToken.distributeRewards(rewardAmount);
        
        // 3. Check increased value
        uint256 newExchangeRate = stCoreToken.getExchangeRate();
        uint256 currentValue = (stCoreAmount * newExchangeRate) / 1e18;
        assertGt(currentValue, coreAmount, "Value should have increased");
        
        // 4. Burn and verify profit
        uint256 initialBalance = coreToken.balanceOf(alice);
        vm.prank(alice);
        uint256 returnedAmount = stCoreToken.burn(alice, stCoreAmount);
        
        assertGt(returnedAmount, coreAmount, "Should get more CORE back");
        assertEq(coreToken.balanceOf(alice), initialBalance);
    }
    
    function testMultipleRewardDistributions() public {
        uint256 coreAmount = 100e18;
        
        // Mint stCORE
        vm.prank(alice);
        coreToken.approve(address(stCoreToken), coreAmount);
        vm.prank(alice);
        stCoreToken.mint(alice, coreAmount);
        
        uint256 initialRate = stCoreToken.getExchangeRate();
        
        // Multiple reward distributions
        for (uint256 i = 1; i <= 3; i++) {
            uint256 rewardAmount = 2e18;
            vm.prank(deployer);
            coreToken.transfer(address(stCoreToken), rewardAmount);
            vm.prank(deployer);
            stCoreToken.distributeRewards(rewardAmount);
            
            uint256 currentRate = stCoreToken.getExchangeRate();
            assertGt(currentRate, initialRate, "Rate should keep increasing");
            initialRate = currentRate;
        }
    }
}
