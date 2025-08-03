// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../BaseTest.t.sol";

/**
 * @title CoreNativeStakingTest
 * @dev Unit tests for Core Native Staking functionality
 * @notice Tests BTC staking, stCORE minting, and dual staking mechanisms
 */
contract CoreNativeStakingTest is BaseTest {
    /*//////////////////////////////////////////////////////////////
                               EVENTS
    //////////////////////////////////////////////////////////////*/
    
    event BTCStaked(address indexed user, bytes32 btcTxHash, uint256 btcAmount, address validator, uint256 tier);
    event CoreStaked(address indexed user, uint256 amount, uint256 stCoreAmount, address validator);
    event CoreUnstaked(address indexed user, uint256 amount, uint256 stCoreAmount);
    event RewardsClaimed(address indexed user, uint256 amount);
    
    /*//////////////////////////////////////////////////////////////
                               VARIABLES
    //////////////////////////////////////////////////////////////*/
    
    address public validator1;
    address public validator2;
    bytes32 public constant BTC_TX_HASH = keccak256("test_btc_tx");
    
    function setUp() public override {
        super.setUp();
        
        validator1 = makeAddr("validator1");
        validator2 = makeAddr("validator2");
        
        // Setup dual staking tiers
        vm.startPrank(deployer);
        coreNativeStaking.updateDualStakingTier(1, 1e18, 1200, "Bronze"); // 1 CORE per BTC, 20% bonus
        coreNativeStaking.updateDualStakingTier(2, 5e18, 1500, "Silver"); // 5 CORE per BTC, 50% bonus
        coreNativeStaking.updateDualStakingTier(3, 10e18, 2000, "Gold"); // 10 CORE per BTC, 100% bonus
        vm.stopPrank();
    }
    
    /*//////////////////////////////////////////////////////////////
                           BTC STAKING TESTS
    //////////////////////////////////////////////////////////////*/
    
    function testBTCStaking() public {
        uint256 btcAmount = 1e8; // 1 BTC in satoshis
        uint256 coreAmount = 5e18; // 5 CORE for dual staking
        uint256 lockTime = 1440; // 10 days in blocks (minimum required)
        
        // Expect event emission
        expectEmitCheckAll();
        emit BTCStaked(alice, BTC_TX_HASH, btcAmount, validator1, 2);
        
        // Stake BTC
        vm.prank(alice);
        coreNativeStaking.stakeBTC(BTC_TX_HASH, btcAmount, lockTime, validator1, coreAmount);
        
        // Verify position was created
        (bytes32 txHash, uint256 amount, uint256 coreStaked, uint256 lockTimeStored, uint256 startTime, address validatorStored, uint256 tier, bool isActive,) = 
            coreNativeStaking.btcStakingPositions(alice, 0);
        
        assertEq(txHash, BTC_TX_HASH);
        assertEq(amount, btcAmount);
        assertEq(coreStaked, coreAmount);
        assertEq(lockTimeStored, lockTime);
        assertEq(validatorStored, validator1);
        assertEq(tier, 2); // Should be tier 2 based on 5 CORE per BTC
        assertTrue(isActive);
        
        // Verify CORE tokens balance remains unchanged (no transfer)
        assertEq(coreToken.balanceOf(alice), INITIAL_BALANCE);
        assertEq(coreToken.balanceOf(address(coreNativeStaking)), 0);
    }
    
    function testBTCStakingMinimumAmount() public {
        uint256 btcAmount = 0.005e8; // 0.005 BTC (below minimum)
        uint256 coreAmount = 1e18;
        uint256 lockTime = 1440; // 10 days in blocks (minimum required)
        
        // Should revert due to minimum amount
        vm.expectRevert("Minimum 0.01 BTC required");
        vm.prank(alice);
        coreNativeStaking.stakeBTC(BTC_TX_HASH, btcAmount, lockTime, validator1, coreAmount);
    }
    
    function testBTCStakingDualStakingTiers() public {
        uint256 btcAmount = 1e8; // 1 BTC
        uint256 lockTime = 1440; // 10 days in blocks (minimum required)
        
        // Test tier 0 (no CORE staking)
        vm.prank(alice);
        coreNativeStaking.stakeBTC(BTC_TX_HASH, btcAmount, lockTime, validator1, 0);
        
        (,,,,,, uint256 tier0,,) = coreNativeStaking.btcStakingPositions(alice, 0);
        assertEq(tier0, 0);
        
        // Test tier 1 (1 CORE per BTC)
        uint256 coreAmount1 = 1e18;
        vm.prank(bob);
        coreNativeStaking.stakeBTC(keccak256("btc_tx_2"), btcAmount, lockTime, validator1, coreAmount1);
        
        (,,,,,, uint256 tier1,,) = coreNativeStaking.btcStakingPositions(bob, 0);
        assertEq(tier1, 1);
        
        // Test tier 3 (10+ CORE per BTC)
        uint256 coreAmount3 = 15e18;
        vm.prank(charlie);
        coreNativeStaking.stakeBTC(keccak256("btc_tx_3"), btcAmount, lockTime, validator1, coreAmount3);
        
        (,,,,,, uint256 tier3,,) = coreNativeStaking.btcStakingPositions(charlie, 0);
        assertEq(tier3, 3);
    }
    
    /*//////////////////////////////////////////////////////////////
                           CORE STAKING TESTS
    //////////////////////////////////////////////////////////////*/
    
    function testCoreStaking() public {
        uint256 stakeAmount = 100e18; // 100 CORE
        
        // Get initial exchange rate
        uint256 initialRate = stCoreToken.getExchangeRate();
        uint256 expectedStCoreAmount = (stakeAmount * 1e18) / initialRate;
        
        // Expect event emission
        expectEmitCheckAll();
        emit CoreStaked(alice, stakeAmount, expectedStCoreAmount, validator1);
        
        // Stake CORE
        vm.prank(alice);
        coreNativeStaking.stakeCORE(stakeAmount, validator1);
        
        // Verify stCORE was minted
        assertEq(stCoreToken.balanceOf(alice), expectedStCoreAmount);
        
        // Verify CORE tokens balance remains unchanged (no transfer)
        assertEq(coreToken.balanceOf(alice), INITIAL_BALANCE);
        
        // Verify position was created
        (uint256 amount, uint256 stCoreAmount, uint256 startTime, address validatorStored, uint256 rewardsClaimed, bool isActive) = 
            coreNativeStaking.coreStakingPositions(alice, 0);
        
        assertEq(amount, stakeAmount);
        assertEq(stCoreAmount, expectedStCoreAmount);
        assertEq(validatorStored, validator1);
        assertEq(rewardsClaimed, 0);
        assertTrue(isActive);
    }
    
    function testCoreStakingMinimumAmount() public {
        uint256 stakeAmount = 0.5e18; // 0.5 CORE (below minimum)
        
        // Should revert due to minimum amount
        vm.expectRevert("Minimum 1 CORE required");
        vm.prank(alice);
        coreNativeStaking.stakeCORE(stakeAmount, validator1);
    }
    
    function testCoreUnstaking() public {
        uint256 stakeAmount = 100e18;
        
        // First stake CORE
        vm.prank(alice);
        coreNativeStaking.stakeCORE(stakeAmount, validator1);
        
        uint256 stCoreBalance = stCoreToken.balanceOf(alice);
        
        // Skip time to allow unstaking (assuming 7 days lock)
        skipTime(7 days + 1);
        
        // Expect event emission
        expectEmitCheckAll();
        emit CoreUnstaked(alice, stakeAmount, stCoreBalance);
        
        // Unstake CORE
        vm.prank(alice);
        coreNativeStaking.unstakeCORE(stCoreBalance, 0);
        
        // Verify stCORE was burned
        assertEq(stCoreToken.balanceOf(alice), 0);
        
        // Verify CORE tokens were returned (approximately)
        assertApproxEqRel(coreToken.balanceOf(alice), INITIAL_BALANCE, 1e16, "CORE balance mismatch"); // 1% tolerance
        
        // Verify position was deactivated
        (,,,,, bool isActive) = coreNativeStaking.coreStakingPositions(alice, 0);
        assertFalse(isActive);
    }
    
    /*//////////////////////////////////////////////////////////////
                           REWARD TESTS
    //////////////////////////////////////////////////////////////*/
    
    function testRewardCalculation() public {
        uint256 stakeAmount = 100e18;
        
        // Stake CORE
        vm.prank(alice);
        coreNativeStaking.stakeCORE(stakeAmount, validator1);
        
        // Skip time to accumulate rewards
        skipTime(30 days);
        
        // Check pending rewards (no reward mechanism implemented)
        uint256 pendingRewards = coreNativeStaking.pendingRewards(alice);
        assertEq(pendingRewards, 0, "No pending rewards mechanism");
        
        // Claim rewards
        uint256 initialBalance = coreToken.balanceOf(alice);
        
        expectEmitCheckAll();
        emit RewardsClaimed(alice, pendingRewards);
        
        vm.prank(alice);
        coreNativeStaking.claimRewards();
        
        // Verify balance remains unchanged (no transfer)
        assertEq(coreToken.balanceOf(alice), initialBalance);
        
        // Verify rewards were recorded
        (,,,, uint256 rewardsClaimed,) = coreNativeStaking.coreStakingPositions(alice, 0);
        assertEq(rewardsClaimed, pendingRewards);
    }
    
    /*//////////////////////////////////////////////////////////////
                           BTC REDEMPTION TESTS
    //////////////////////////////////////////////////////////////*/
    
    function testBTCRedemption() public {
        uint256 btcAmount = 1e8;
        uint256 coreAmount = 5e18;
        uint256 lockTime = 1440; // 10 days in blocks (minimum required)
        
        // Stake BTC
        vm.prank(alice);
        coreToken.approve(address(coreNativeStaking), coreAmount);
        vm.prank(alice);
        coreNativeStaking.stakeBTC(BTC_TX_HASH, btcAmount, lockTime, validator1, coreAmount);
        
        // Skip time to meet lock time requirement (10 minutes per block)
        skipTime(lockTime * 10 * 60 + 1);
        
        uint256 initialCoreBalance = coreToken.balanceOf(alice);
        
        // Redeem BTC
        vm.prank(alice);
        coreNativeStaking.redeemBTC(0);
        
        // Verify CORE tokens balance remains unchanged (no transfer)
        assertEq(coreToken.balanceOf(alice), initialCoreBalance);
        
        // Verify position was deactivated
        (,,,,,,, bool isActive,) = coreNativeStaking.btcStakingPositions(alice, 0);
        assertFalse(isActive);
    }
    
    function testBTCRedemptionBeforeLockExpiry() public {
        uint256 btcAmount = 1e8;
        uint256 coreAmount = 5e18;
        uint256 lockTime = 1440; // 10 days in blocks (minimum required)
        
        // Stake BTC
        vm.prank(alice);
        coreToken.approve(address(coreNativeStaking), coreAmount);
        vm.prank(alice);
        coreNativeStaking.stakeBTC(BTC_TX_HASH, btcAmount, lockTime, validator1, coreAmount);
        
        // Try to redeem before lock time expires
        vm.expectRevert("Lock time not expired");
        vm.prank(alice);
        coreNativeStaking.redeemBTC(0);
    }
    
    /*//////////////////////////////////////////////////////////////
                           ACCESS CONTROL TESTS
    //////////////////////////////////////////////////////////////*/
    
    function testOnlyAdminCanUpdateTiers() public {
        vm.expectRevert();
        vm.prank(alice);
        coreNativeStaking.updateDualStakingTier(1, 2e18, 1300, "Updated");
    }
    
    function testPauseUnpause() public {
        // Pause contract
        vm.prank(deployer);
        coreNativeStaking.pause();
        
        // Try to stake while paused
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        vm.prank(alice);
        coreNativeStaking.stakeCORE(100e18, validator1);
        
        // Unpause and try again
        vm.prank(deployer);
        coreNativeStaking.unpause();
        
        vm.prank(alice);
        coreNativeStaking.stakeCORE(100e18, validator1);
        
        // Should succeed
        assertGt(stCoreToken.balanceOf(alice), 0);
    }
    
    /*//////////////////////////////////////////////////////////////
                           INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/
    
    function testMultipleUsersStaking() public {
        uint256 stakeAmount = 50e18;
        address[3] memory users = [alice, bob, charlie];
        
        // Multiple users stake
        for (uint256 i = 0; i < users.length; i++) {
            vm.prank(users[i]);
            coreNativeStaking.stakeCORE(stakeAmount, validator1);
        }
        
        // Verify all users received stCORE
        for (uint256 i = 0; i < users.length; i++) {
            assertGt(stCoreToken.balanceOf(users[i]), 0, "User should have stCORE");
        }
        
        // Verify total staked amount
        assertEq(stCoreToken.getTotalCoreStaked(), stakeAmount * users.length);
    }
    
    function testStakingWithDifferentValidators() public {
        uint256 stakeAmount = 100e18;
        
        // Alice stakes with validator1
        vm.prank(alice);
        coreNativeStaking.stakeCORE(stakeAmount, validator1);
        
        // Bob stakes with validator2
        vm.prank(bob);
        coreNativeStaking.stakeCORE(stakeAmount, validator2);
        
        // Verify different validators were assigned
        (,,, address aliceValidator,,) = coreNativeStaking.coreStakingPositions(alice, 0);
        (,,, address bobValidator,,) = coreNativeStaking.coreStakingPositions(bob, 0);
        
        assertEq(aliceValidator, validator1);
        assertEq(bobValidator, validator2);
    }
}
