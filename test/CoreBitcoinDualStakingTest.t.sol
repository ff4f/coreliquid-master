// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../contracts/CoreBitcoinDualStaking.sol";
import "../contracts/SimpleToken.sol";

contract CoreBitcoinDualStakingTest is Test {
    CoreBitcoinDualStaking public dualStaking;
    SimpleToken public coreToken;
    SimpleToken public btcToken;
    
    address public deployer = address(this);
    address public validator1 = address(0x1);
    address public validator2 = address(0x2);
    address public user1 = address(0x3);
    address public user2 = address(0x4);
    address public operator = address(0x5);
    
    uint256 public constant INITIAL_SUPPLY = 1000000 * 1e18;
    uint256 public constant MIN_CORE_STAKE = 1000 * 1e18;
    uint256 public constant MIN_BTC_STAKE = 1e16;
    uint256 public constant STAKE_AMOUNT_CORE = 5000 * 1e18;
    uint256 public constant STAKE_AMOUNT_BTC = 2 * 1e18;
    
    event DualStakeActivated(
        address indexed user,
        uint256 coreAmount,
        uint256 btcAmount,
        uint256 validatorId
    );
    
    event RewardsHarvested(
        address indexed user,
        uint256 coreRewards,
        uint256 btcRewards
    );
    
    event ValidatorRegistered(
        uint256 indexed validatorId,
        address indexed validator,
        uint256 commission
    );

    function setUp() public {
        // Deploy tokens
        coreToken = new SimpleToken("Core Token", "CORE", INITIAL_SUPPLY);
        btcToken = new SimpleToken("Bitcoin Token", "BTC", INITIAL_SUPPLY);
        
        // Deploy dual staking contract
        dualStaking = new CoreBitcoinDualStaking(
            address(coreToken),
            address(btcToken)
        );
        
        // Setup roles
        dualStaking.grantRole(dualStaking.OPERATOR_ROLE(), operator);
        
        // Distribute tokens to users
        coreToken.transfer(user1, 10000 * 1e18);
        btcToken.transfer(user1, 10 * 1e18);
        coreToken.transfer(user2, 10000 * 1e18);
        btcToken.transfer(user2, 10 * 1e18);
        
        // Add reward pools
        coreToken.approve(address(dualStaking), 50000 * 1e18);
        btcToken.approve(address(dualStaking), 50 * 1e18);
        vm.prank(operator);
        dualStaking.addRewards(50000 * 1e18, 50 * 1e18);
        
        // Register validators
        vm.startPrank(operator);
        dualStaking.registerValidator(validator1, 500); // 5% commission
        dualStaking.registerValidator(validator2, 300); // 3% commission
        vm.stopPrank();
    }

    function testDeployment() public {
        assertEq(address(dualStaking.coreToken()), address(coreToken));
        assertEq(address(dualStaking.btcToken()), address(btcToken));
        assertEq(dualStaking.nextValidatorId(), 3); // Should be 3 after registering 2 validators
        assertEq(dualStaking.currentEpoch(), 1);
    }

    function testValidatorRegistration() public {
        // Test validator info
        CoreBitcoinDualStaking.ValidatorInfo memory validator1Info = dualStaking.getValidatorInfo(1);
        assertEq(validator1Info.validatorAddress, validator1);
        assertEq(validator1Info.commission, 500);
        assertTrue(validator1Info.isActive);
        assertEq(validator1Info.reputationScore, 100);
        
        CoreBitcoinDualStaking.ValidatorInfo memory validator2Info = dualStaking.getValidatorInfo(2);
        assertEq(validator2Info.validatorAddress, validator2);
        assertEq(validator2Info.commission, 300);
        assertTrue(validator2Info.isActive);
    }

    function testDualStakeActivation() public {
        // Setup user1 approvals
        vm.startPrank(user1);
        coreToken.approve(address(dualStaking), STAKE_AMOUNT_CORE);
        btcToken.approve(address(dualStaking), STAKE_AMOUNT_BTC);
        
        // Expect event emission
        vm.expectEmit(true, true, true, true);
        emit DualStakeActivated(user1, STAKE_AMOUNT_CORE, STAKE_AMOUNT_BTC, 1);
        
        // Activate dual stake
        dualStaking.activateDualStake(STAKE_AMOUNT_CORE, STAKE_AMOUNT_BTC, 1);
        vm.stopPrank();
        
        // Verify stake info
        CoreBitcoinDualStaking.DualStakeInfo memory stakeInfo = dualStaking.getUserStakeInfo(user1);
        assertEq(stakeInfo.coreAmount, STAKE_AMOUNT_CORE);
        assertEq(stakeInfo.btcAmount, STAKE_AMOUNT_BTC);
        assertEq(stakeInfo.validatorId, 1);
        assertTrue(stakeInfo.isActive);
        
        // Verify validator stats updated
        CoreBitcoinDualStaking.ValidatorInfo memory validatorInfo = dualStaking.getValidatorInfo(1);
        assertEq(validatorInfo.totalCoreStaked, STAKE_AMOUNT_CORE);
        assertEq(validatorInfo.totalBtcStaked, STAKE_AMOUNT_BTC);
        
        // Verify global stats
        (uint256 totalCore, uint256 totalBtc, uint256 totalStakers) = dualStaking.getTotalStats();
        assertEq(totalCore, STAKE_AMOUNT_CORE);
        assertEq(totalBtc, STAKE_AMOUNT_BTC);
        assertEq(totalStakers, 1);
    }

    function testRevertWhen_InsufficientCoreAmount() public {
        vm.startPrank(user1);
        coreToken.approve(address(dualStaking), MIN_CORE_STAKE - 1);
        btcToken.approve(address(dualStaking), MIN_BTC_STAKE);
        
        vm.expectRevert("Insufficient CORE amount");
        dualStaking.activateDualStake(MIN_CORE_STAKE - 1, MIN_BTC_STAKE, 1);
        vm.stopPrank();
    }

    function testRevertWhen_InsufficientBtcAmount() public {
        vm.startPrank(user1);
        coreToken.approve(address(dualStaking), MIN_CORE_STAKE);
        btcToken.approve(address(dualStaking), MIN_BTC_STAKE - 1);
        
        vm.expectRevert("Insufficient BTC amount");
        dualStaking.activateDualStake(MIN_CORE_STAKE, MIN_BTC_STAKE - 1, 1);
        vm.stopPrank();
    }

    function testRevertWhen_ValidatorNotActive() public {
        vm.startPrank(user1);
        coreToken.approve(address(dualStaking), STAKE_AMOUNT_CORE);
        btcToken.approve(address(dualStaking), STAKE_AMOUNT_BTC);
        
        vm.expectRevert("Validator not active");
        dualStaking.activateDualStake(STAKE_AMOUNT_CORE, STAKE_AMOUNT_BTC, 999); // Non-existent validator
        vm.stopPrank();
    }

    function testRevertWhen_AlreadyStaking() public {
        // First stake
        vm.startPrank(user1);
        coreToken.approve(address(dualStaking), STAKE_AMOUNT_CORE * 2);
        btcToken.approve(address(dualStaking), STAKE_AMOUNT_BTC * 2);
        dualStaking.activateDualStake(STAKE_AMOUNT_CORE, STAKE_AMOUNT_BTC, 1);
        
        // Try to stake again
        vm.expectRevert("Already staking");
        dualStaking.activateDualStake(STAKE_AMOUNT_CORE, STAKE_AMOUNT_BTC, 2);
        vm.stopPrank();
    }

    function testRewardCalculation() public {
        // Setup stake
        vm.startPrank(user1);
        coreToken.approve(address(dualStaking), STAKE_AMOUNT_CORE);
        btcToken.approve(address(dualStaking), STAKE_AMOUNT_BTC);
        dualStaking.activateDualStake(STAKE_AMOUNT_CORE, STAKE_AMOUNT_BTC, 1);
        vm.stopPrank();
        
        // Fast forward 1 day
        vm.warp(block.timestamp + 1 days);
        
        // Check pending rewards
        (uint256 coreRewards, uint256 btcRewards) = dualStaking.getPendingRewards(user1);
        
        // Should have rewards (exact calculation depends on implementation)
        assertGt(coreRewards, 0);
        assertGt(btcRewards, 0);
    }

    function testHarvestRewards() public {
        // Setup stake
        vm.startPrank(user1);
        coreToken.approve(address(dualStaking), STAKE_AMOUNT_CORE);
        btcToken.approve(address(dualStaking), STAKE_AMOUNT_BTC);
        dualStaking.activateDualStake(STAKE_AMOUNT_CORE, STAKE_AMOUNT_BTC, 1);
        vm.stopPrank();
        
        // Fast forward 1 day
        vm.warp(block.timestamp + 1 days);
        
        // Get balances before harvest
        uint256 coreBalanceBefore = coreToken.balanceOf(user1);
        uint256 btcBalanceBefore = btcToken.balanceOf(user1);
        
        // Get pending rewards
        (uint256 expectedCoreRewards, uint256 expectedBtcRewards) = dualStaking.getPendingRewards(user1);
        
        // Harvest rewards
        vm.prank(user1);
        dualStaking.harvestRewards();
        
        // Check balances after harvest
        uint256 coreBalanceAfter = coreToken.balanceOf(user1);
        uint256 btcBalanceAfter = btcToken.balanceOf(user1);
        
        // Verify rewards received
        assertEq(coreBalanceAfter - coreBalanceBefore, expectedCoreRewards);
        assertEq(btcBalanceAfter - btcBalanceBefore, expectedBtcRewards);
    }

    function testRevertWhen_NoActiveStakeForHarvest() public {
        vm.prank(user1);
        vm.expectRevert("No active stake");
        dualStaking.harvestRewards();
    }

    function testUnstake() public {
        // Setup stake
        vm.startPrank(user1);
        coreToken.approve(address(dualStaking), STAKE_AMOUNT_CORE);
        btcToken.approve(address(dualStaking), STAKE_AMOUNT_BTC);
        dualStaking.activateDualStake(STAKE_AMOUNT_CORE, STAKE_AMOUNT_BTC, 1);
        
        // Get balances before unstake
        uint256 coreBalanceBefore = coreToken.balanceOf(user1);
        uint256 btcBalanceBefore = btcToken.balanceOf(user1);
        
        // Unstake
        dualStaking.unstake();
        vm.stopPrank();
        
        // Check balances after unstake
        uint256 coreBalanceAfter = coreToken.balanceOf(user1);
        uint256 btcBalanceAfter = btcToken.balanceOf(user1);
        
        // Verify tokens returned
        assertEq(coreBalanceAfter - coreBalanceBefore, STAKE_AMOUNT_CORE);
        assertEq(btcBalanceAfter - btcBalanceBefore, STAKE_AMOUNT_BTC);
        
        // Verify stake info cleared
        CoreBitcoinDualStaking.DualStakeInfo memory stakeInfo = dualStaking.getUserStakeInfo(user1);
        assertFalse(stakeInfo.isActive);
        
        // Verify global stats updated
        (uint256 totalCore, uint256 totalBtc, uint256 totalStakers) = dualStaking.getTotalStats();
        assertEq(totalCore, 0);
        assertEq(totalBtc, 0);
        assertEq(totalStakers, 0);
    }

    function testMultipleUsersStaking() public {
        // User1 stakes with validator1
        vm.startPrank(user1);
        coreToken.approve(address(dualStaking), STAKE_AMOUNT_CORE);
        btcToken.approve(address(dualStaking), STAKE_AMOUNT_BTC);
        dualStaking.activateDualStake(STAKE_AMOUNT_CORE, STAKE_AMOUNT_BTC, 1);
        vm.stopPrank();
        
        // User2 stakes with validator2
        vm.startPrank(user2);
        coreToken.approve(address(dualStaking), STAKE_AMOUNT_CORE);
        btcToken.approve(address(dualStaking), STAKE_AMOUNT_BTC);
        dualStaking.activateDualStake(STAKE_AMOUNT_CORE, STAKE_AMOUNT_BTC, 2);
        vm.stopPrank();
        
        // Verify global stats
        (uint256 totalCore, uint256 totalBtc, uint256 totalStakers) = dualStaking.getTotalStats();
        assertEq(totalCore, STAKE_AMOUNT_CORE * 2);
        assertEq(totalBtc, STAKE_AMOUNT_BTC * 2);
        assertEq(totalStakers, 2);
        
        // Verify validator stats
        CoreBitcoinDualStaking.ValidatorInfo memory validator1Info = dualStaking.getValidatorInfo(1);
        CoreBitcoinDualStaking.ValidatorInfo memory validator2Info = dualStaking.getValidatorInfo(2);
        
        assertEq(validator1Info.totalCoreStaked, STAKE_AMOUNT_CORE);
        assertEq(validator1Info.totalBtcStaked, STAKE_AMOUNT_BTC);
        assertEq(validator2Info.totalCoreStaked, STAKE_AMOUNT_CORE);
        assertEq(validator2Info.totalBtcStaked, STAKE_AMOUNT_BTC);
    }

    function testEpochAdvancement() public {
        uint256 initialEpoch = dualStaking.currentEpoch();
        
        // Fast forward more than epoch duration (1 day)
        vm.warp(block.timestamp + 1 days + 1);
        
        // Trigger epoch update by calling any function that updates epoch
        vm.startPrank(user1);
        coreToken.approve(address(dualStaking), STAKE_AMOUNT_CORE);
        btcToken.approve(address(dualStaking), STAKE_AMOUNT_BTC);
        dualStaking.activateDualStake(STAKE_AMOUNT_CORE, STAKE_AMOUNT_BTC, 1);
        vm.stopPrank();
        
        uint256 newEpoch = dualStaking.currentEpoch();
        assertEq(newEpoch, initialEpoch + 1);
    }

    function testValidatorHistory() public {
        // User1 stakes with validator1
        vm.startPrank(user1);
        coreToken.approve(address(dualStaking), STAKE_AMOUNT_CORE);
        btcToken.approve(address(dualStaking), STAKE_AMOUNT_BTC);
        dualStaking.activateDualStake(STAKE_AMOUNT_CORE, STAKE_AMOUNT_BTC, 1);
        vm.stopPrank();
        
        // Check validator history
        uint256[] memory history = dualStaking.getUserValidatorHistory(user1);
        assertEq(history.length, 1);
        assertEq(history[0], 1);
    }

    function testAdminFunctions() public {
        // Test updating validator reputation
        vm.prank(operator);
        dualStaking.updateValidatorReputation(1, 95);
        
        CoreBitcoinDualStaking.ValidatorInfo memory validatorInfo = dualStaking.getValidatorInfo(1);
        assertEq(validatorInfo.reputationScore, 95);
        
        // Test updating daily reward rate
        vm.prank(operator);
        dualStaking.updateDailyRewardRate(150);
        
        // Test deactivating validator
        vm.prank(operator);
        dualStaking.deactivateValidator(1);
        
        validatorInfo = dualStaking.getValidatorInfo(1);
        assertFalse(validatorInfo.isActive);
    }

    function testEmergencyFunctions() public {
        // Test emergency pause
        dualStaking.emergencyPause();
        
        // Should revert when paused
        vm.startPrank(user1);
        coreToken.approve(address(dualStaking), STAKE_AMOUNT_CORE);
        btcToken.approve(address(dualStaking), STAKE_AMOUNT_BTC);
        
        vm.expectRevert("Pausable: paused");
        dualStaking.activateDualStake(STAKE_AMOUNT_CORE, STAKE_AMOUNT_BTC, 1);
        vm.stopPrank();
        
        // Test emergency unpause
        dualStaking.emergencyUnpause();
        
        // Should work after unpause
        vm.startPrank(user1);
        dualStaking.activateDualStake(STAKE_AMOUNT_CORE, STAKE_AMOUNT_BTC, 2); // Use validator 2 since 1 is deactivated
        vm.stopPrank();
    }

    function testEpochSnapshots() public {
        uint256 currentEpoch = dualStaking.currentEpoch();
        
        // User1 stakes
        vm.startPrank(user1);
        coreToken.approve(address(dualStaking), STAKE_AMOUNT_CORE);
        btcToken.approve(address(dualStaking), STAKE_AMOUNT_BTC);
        dualStaking.activateDualStake(STAKE_AMOUNT_CORE, STAKE_AMOUNT_BTC, 1);
        vm.stopPrank();
        
        // Check epoch snapshot
        uint256 userStakeSnapshot = dualStaking.getEpochStakeSnapshot(currentEpoch, user1);
        uint256 totalStakeSnapshot = dualStaking.getEpochTotalStake(currentEpoch);
        
        assertEq(userStakeSnapshot, STAKE_AMOUNT_CORE + STAKE_AMOUNT_BTC);
        assertEq(totalStakeSnapshot, STAKE_AMOUNT_CORE + STAKE_AMOUNT_BTC);
    }

    function testRevertWhen_InvalidValidatorRegistration() public {
        vm.startPrank(operator);
        
        // Test invalid address
        vm.expectRevert("Invalid validator address");
        dualStaking.registerValidator(address(0), 500);
        
        // Test commission too high
        vm.expectRevert("Commission too high");
        dualStaking.registerValidator(address(0x999), 2001); // > 20%
        
        vm.stopPrank();
    }

    function testRevertWhen_UnauthorizedAccess() public {
        // Test unauthorized validator registration
        vm.prank(user1);
        vm.expectRevert();
        dualStaking.registerValidator(address(0x999), 500);
        
        // Test unauthorized admin functions
        vm.prank(user1);
        vm.expectRevert();
        dualStaking.updateValidatorReputation(1, 95);
        
        vm.prank(user1);
        vm.expectRevert();
        dualStaking.updateDailyRewardRate(150);
    }
}
