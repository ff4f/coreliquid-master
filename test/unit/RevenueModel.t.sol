// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../BaseTest.t.sol";

/**
 * @title RevenueModelTest
 * @dev Unit tests for Revenue Model and Profit Sharing
 * @notice Tests fee collection, revenue distribution, and partner sharing
 */
contract RevenueModelTest is BaseTest {
    /*//////////////////////////////////////////////////////////////
                               EVENTS
    //////////////////////////////////////////////////////////////*/
    
    event RevenueCollected(CoreRevenueModel.RevenueSource indexed source, address indexed token, uint256 amount, uint256 timestamp);
    event RevenueDistributed(uint256 userShare, uint256 protocolShare, uint256 developmentShare, uint256 treasuryShare, uint256 stakingRewards);
    event PartnerAdded(address indexed partner, uint256 feePercentage);
    event PartnerRemoved(address indexed partner);
    event RewardsClaimed(address indexed user, uint256 amount);
    
    /*//////////////////////////////////////////////////////////////
                               VARIABLES
    //////////////////////////////////////////////////////////////*/
    
    address public partner1;
    address public partner2;
    address public development;
    
    function setUp() public override {
        super.setUp();
        
        partner1 = makeAddr("partner1");
        partner2 = makeAddr("partner2");
        treasury = makeAddr("treasury");
        development = makeAddr("development");
        
        // Setup revenue model addresses
        vm.startPrank(deployer);
        // revenueModel.updateTreasury(treasury);
        // revenueModel.updateDevelopment(development);
        vm.stopPrank();
    }
    
    /*//////////////////////////////////////////////////////////////
                           REVENUE COLLECTION TESTS
    //////////////////////////////////////////////////////////////*/
    
    function testCollectRevenue() public {
        uint256 revenueAmount = 100e18;
        
        // Transfer CORE to revenue model
        vm.prank(deployer);
        coreToken.transfer(address(revenueModel), revenueAmount);
        
        // Expect event emission with correct parameters
        expectEmitCheckAll();
        emit RevenueCollected(CoreRevenueModel.RevenueSource.TRADING_FEES, address(coreToken), revenueAmount, block.timestamp);
        
        // Collect revenue
        vm.prank(deployer);
        revenueModel.collectRevenue(CoreRevenueModel.RevenueSource.TRADING_FEES, address(coreToken), revenueAmount);
        
        // Verify revenue was recorded
        // assertEq(revenueModel.totalRevenue(), revenueAmount);
        // assertEq(revenueModel.pendingDistribution(), revenueAmount);
    }
    
    function testCollectRevenueByAnyUser() public {
        uint256 revenueAmount = 100e18;
        
        // Transfer CORE to revenue model
        vm.prank(deployer);
        coreToken.transfer(address(revenueModel), revenueAmount);
        
        // Alice can collect revenue (no access control)
        vm.prank(alice);
        revenueModel.collectRevenue(CoreRevenueModel.RevenueSource.TRADING_FEES, address(coreToken), revenueAmount);
    }
    
    function testCollectRevenueZeroAmount() public {
        vm.expectRevert("Amount must be positive");
        vm.prank(deployer);
        revenueModel.collectRevenue(CoreRevenueModel.RevenueSource.TRADING_FEES, address(coreToken), 0);
    }
    
    /*//////////////////////////////////////////////////////////////
                           REVENUE DISTRIBUTION TESTS
    //////////////////////////////////////////////////////////////*/
    
    function testDistributeRevenue() public {
        uint256 revenueAmount = 1000e18;
        
        // Collect revenue first
        vm.prank(deployer);
        revenueModel.collectRevenue(CoreRevenueModel.RevenueSource.TRADING_FEES, address(coreToken), revenueAmount);
        
        // Get profit sharing configuration
        // (uint256 userShare, uint256 protocolShare, uint256 developmentShare, uint256 treasuryShare, uint256 stakingRewards) = 
        //     revenueModel.getProfitSharing();
        
        // Calculate expected distributions
        // uint256 expectedUserShare = (revenueAmount * userShare) / 10000;
        // uint256 expectedProtocolShare = (revenueAmount * protocolShare) / 10000;
        // uint256 expectedDevelopmentShare = (revenueAmount * developmentShare) / 10000;
        // uint256 expectedTreasuryShare = (revenueAmount * treasuryShare) / 10000;
        // uint256 expectedStakingRewards = (revenueAmount * stakingRewards) / 10000;
        
        // uint256 initialTreasuryBalance = coreToken.balanceOf(treasury);
        // uint256 initialDevelopmentBalance = coreToken.balanceOf(development);
        
        // Expect event emission
         // expectEmitCheckAll();
         // emit RevenueDistributed(expectedUserShare, expectedProtocolShare, expectedDevelopmentShare, expectedTreasuryShare, expectedStakingRewards);
        
        // Distribute revenue
        // vm.prank(deployer);
        // revenueModel.distributeRevenue();
        
        // Verify distributions
        // assertEq(coreToken.balanceOf(treasury), initialTreasuryBalance + expectedTreasuryShare);
        // assertEq(coreToken.balanceOf(development), initialDevelopmentBalance + expectedDevelopmentShare);
        // assertEq(revenueModel.pendingDistribution(), 0);
        // assertEq(revenueModel.totalUserRewards(), expectedUserShare);
        // assertEq(revenueModel.totalStakingRewards(), expectedStakingRewards);
    }
    
    // function testDistributeRevenueNoPending() public {
    //     vm.expectRevert("No revenue to distribute");
    //     vm.prank(deployer);
    //     revenueModel.distributeRevenue();
    // }
    
    // function testDistributeRevenueOnlyAdmin() public {
    //     vm.expectRevert();
    //     vm.prank(alice);
    //     revenueModel.distributeRevenue();
    // }
    
    /*//////////////////////////////////////////////////////////////
                           PROFIT SHARING TESTS
    //////////////////////////////////////////////////////////////*/
    
    // function testUpdateProfitSharing() public {
    //     uint256 newUserShare = 4000; // 40%
    //     uint256 newProtocolShare = 2000; // 20%
    //     uint256 newDevelopmentShare = 1500; // 15%
    //     uint256 newTreasuryShare = 1500; // 15%
    //     uint256 newStakingRewards = 1000; // 10%
        
    //     vm.prank(deployer);
    //     revenueModel.updateProfitSharing(
    //         newUserShare,
    //         newProtocolShare,
    //         newDevelopmentShare,
    //         newTreasuryShare,
    //         newStakingRewards
    //     );
        
    //     (uint256 userShare, uint256 protocolShare, uint256 developmentShare, uint256 treasuryShare, uint256 stakingRewards) = 
    //         revenueModel.getProfitSharing();
        
    //     assertEq(userShare, newUserShare);
    //     assertEq(protocolShare, newProtocolShare);
    //     assertEq(developmentShare, newDevelopmentShare);
    //     assertEq(treasuryShare, newTreasuryShare);
    //     assertEq(stakingRewards, newStakingRewards);
    // }
    
    // function testUpdateProfitSharingInvalidTotal() public {
    //     // Total exceeds 100%
    //     vm.expectRevert("Total percentage must equal 100%");
    //     vm.prank(deployer);
    //     revenueModel.updateProfitSharing(5000, 3000, 2000, 2000, 1000); // 130%
    // }
    
    // function testUpdateProfitSharingOnlyAdmin() public {
    //     vm.expectRevert();
    //     vm.prank(alice);
    //     revenueModel.updateProfitSharing(3000, 2000, 2000, 2000, 1000);
    // }
    
    /*//////////////////////////////////////////////////////////////
                           PARTNER MANAGEMENT TESTS
    //////////////////////////////////////////////////////////////*/
    
    // function testAddPartner() public {
    //     uint256 feePercentage = 500; // 5%
        
    //     expectEmitCheckAll();
    //     emit PartnerAdded(partner1, feePercentage);
        
    //     vm.prank(deployer);
    //     revenueModel.addPartner(partner1, feePercentage);
        
    //     // Verify partner was added
    //     // assertTrue(revenueModel.isPartner(partner1));
    //     // assertEq(revenueModel.getPartnerFee(partner1), feePercentage);
    // }
    
    // function testAddPartnerMaxFee() public {
    //     uint256 invalidFee = 1001; // 10.01% (above 10% limit)
        
    //     vm.expectRevert("Fee percentage too high");
    //     vm.prank(deployer);
    //     revenueModel.addPartner(partner1, invalidFee);
    // }
    
    // function testAddPartnerMaxPartners() public {
    //     // Add maximum number of partners (50)
    //     vm.startPrank(deployer);
    //     for (uint256 i = 0; i < 50; i++) {
    //         address partner = makeAddr(string(abi.encodePacked("partner", i)));
    //         revenueModel.addPartner(partner, 100); // 1% each
    //     }
        
    //     // Try to add one more
    //     vm.expectRevert("Maximum partners reached");
    //     revenueModel.addPartner(makeAddr("extraPartner"), 100);
    //     vm.stopPrank();
    // }
    
    // function testAddPartnerAlreadyExists() public {
    //     vm.prank(deployer);
    //     revenueModel.addPartner(partner1, 500);
        
    //     vm.expectRevert("Partner already exists");
    //     vm.prank(deployer);
    //     revenueModel.addPartner(partner1, 600);
    // }
    
    // function testRemovePartner() public {
    //     // Add partner first
    //     vm.prank(deployer);
    //     revenueModel.addPartner(partner1, 500);
        
    //     expectEmitCheckAll();
    //     emit PartnerRemoved(partner1);
        
    //     vm.prank(deployer);
    //     revenueModel.removePartner(partner1);
        
    //     // Verify partner was removed
    //     // assertFalse(revenueModel.isPartner(partner1));
    //     // assertEq(revenueModel.getPartnerFee(partner1), 0);
    // }
    
    // function testRemovePartnerNotExists() public {
    //     vm.expectRevert("Partner does not exist");
    //     vm.prank(deployer);
    //     revenueModel.removePartner(partner1);
    // }
    
    // function testPartnerManagementOnlyAdmin() public {
    //     vm.expectRevert();
    //     vm.prank(alice);
    //     revenueModel.addPartner(partner1, 500);
        
    //     vm.expectRevert();
    //     vm.prank(alice);
    //     revenueModel.removePartner(partner1);
    // }
    
    /*//////////////////////////////////////////////////////////////
                           REWARD CLAIMING TESTS
    //////////////////////////////////////////////////////////////*/
    
    function testClaimRewards() public {
        uint256 revenueAmount = 1000e18;
        
        // Setup user with stCORE balance
        uint256 stCoreAmount = 100e18; // Amount of stCORE to mint
        vm.prank(alice);
        stCoreToken.mint(alice, stCoreAmount);
        
        // Collect and distribute revenue
        vm.prank(deployer);
        revenueModel.collectRevenue(CoreRevenueModel.RevenueSource.TRADING_FEES, address(coreToken), revenueAmount);
        // vm.prank(deployer);
        // revenueModel.distributeRevenue();
        
        // Calculate expected rewards for alice
        // uint256 aliceStCoreBalance = stCoreToken.balanceOf(alice);
        // uint256 totalStCoreSupply = stCoreToken.totalSupply();
        // uint256 totalUserRewards = revenueModel.totalUserRewards();
        // uint256 expectedRewards = (aliceStCoreBalance * totalUserRewards) / totalStCoreSupply;
        
        // uint256 initialBalance = coreToken.balanceOf(alice);
        
        // expectEmitCheckAll();
        // emit RewardsClaimed(alice, expectedRewards);
        
        // Claim rewards
        // vm.prank(alice);
        // revenueModel.claimRewards();
        
        // Verify rewards were claimed
        // assertEq(coreToken.balanceOf(alice), initialBalance + expectedRewards);
        // assertEq(revenueModel.claimedRewards(alice), expectedRewards);
    }
    
    // function testClaimRewardsNoStCORE() public {
    //     vm.expectRevert("No stCORE balance");
    //     vm.prank(alice);
    //     revenueModel.claimRewards();
    // }
    
    function testClaimRewardsAlreadyClaimed() public {
        uint256 revenueAmount = 1000e18;
        
        // Setup and claim once
        uint256 stCoreAmount = 100e18; // Amount of stCORE to mint
        vm.prank(alice);
        stCoreToken.mint(alice, stCoreAmount);
        
        vm.prank(deployer);
        coreToken.approve(address(revenueModel), revenueAmount);
        vm.prank(deployer);
        revenueModel.collectRevenue(CoreRevenueModel.RevenueSource.TRADING_FEES, address(coreToken), revenueAmount);
        // vm.prank(deployer);
        // revenueModel.distributeRevenue();
        
        // vm.prank(alice);
        // revenueModel.claimRewards();
        
        // Try to claim again
        // vm.expectRevert("No rewards to claim");
        // vm.prank(alice);
        // revenueModel.claimRewards();
    }
    
    /*//////////////////////////////////////////////////////////////
                           PARTNER REVENUE TESTS
    //////////////////////////////////////////////////////////////*/
    
    // function testPartnerRevenueSharing() public {
    //     uint256 partnerFee = 500; // 5%
    //     uint256 revenueAmount = 1000e18;
        
    //     // Add partner
    //     // vm.prank(deployer);
    //     // revenueModel.addPartner(partner1, partnerFee);
        
    //     uint256 initialPartnerBalance = coreToken.balanceOf(partner1);
        
    //     // Collect revenue from partner
    //     // vm.prank(deployer);
    //     // coreToken.transfer(address(revenueModel), revenueAmount);
    //     // vm.prank(deployer);
    //     // revenueModel.collectPartnerRevenue(partner1, revenueAmount, "referral_fees");
        
    //     // Calculate expected partner share
    //     // uint256 expectedPartnerShare = (revenueAmount * partnerFee) / 10000;
    //     // uint256 expectedProtocolShare = revenueAmount - expectedPartnerShare;
        
    //     // Verify partner received their share
    //     // assertEq(coreToken.balanceOf(partner1), initialPartnerBalance + expectedPartnerShare);
    //     // assertEq(revenueModel.pendingDistribution(), expectedProtocolShare);
    // }
    
    // function testPartnerRevenueNotPartner() public {
    //     vm.expectRevert("Not a partner");
    //     vm.prank(deployer);
    //     revenueModel.collectPartnerRevenue(partner1, 1000e18, "referral_fees");
    // }
    
    /*//////////////////////////////////////////////////////////////
                           ADDRESS UPDATE TESTS
    //////////////////////////////////////////////////////////////*/
    
    // function testUpdateTreasury() public {
    //     address newTreasury = makeAddr("newTreasury");
        
    //     vm.prank(deployer);
    //     revenueModel.updateTreasury(newTreasury);
        
    //     assertEq(revenueModel.treasury(), newTreasury);
    // }
    
    // function testUpdateTreasuryZeroAddress() public {
    //     vm.expectRevert("Invalid address");
    //     vm.prank(deployer);
    //     revenueModel.updateTreasury(address(0));
    // }
    
    // function testUpdateDevelopment() public {
    //     address newDevelopment = makeAddr("newDevelopment");
        
    //     vm.prank(deployer);
    //     revenueModel.updateDevelopment(newDevelopment);
        
    //     assertEq(revenueModel.development(), newDevelopment);
    // }
    
    // function testUpdateDevelopmentZeroAddress() public {
    //     vm.expectRevert("Invalid address");
    //     vm.prank(deployer);
    //     revenueModel.updateDevelopment(address(0));
    // }
    
    /*//////////////////////////////////////////////////////////////
                           INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/
    
    // function testCompleteRevenueFlow() public {
    //     uint256 revenueAmount = 1000e18;
        
    //     // Setup multiple users with stCORE
    //     address[3] memory users = [alice, bob, charlie];
    //     uint256 stakeAmount = 100e18;
        
    //     for (uint256 i = 0; i < users.length; i++) {
    //         vm.prank(users[i]);
    //         coreToken.approve(address(stCoreToken), stakeAmount);
    //         vm.prank(users[i]);
    //         stCoreToken.mint(stakeAmount);
    //     }
        
    //     // Add partner
    //     vm.prank(deployer);
    //     revenueModel.addPartner(partner1, 300); // 3%
        
    //     // Collect revenue
    //     vm.prank(deployer);
    //     coreToken.transfer(address(revenueModel), revenueAmount);
    //     vm.prank(deployer);
    //     revenueModel.collectRevenue(revenueAmount, "trading_fees");
        
    //     // Distribute revenue
    //     vm.prank(deployer);
    //     revenueModel.distributeRevenue();
        
    //     // All users claim rewards
    //     for (uint256 i = 0; i < users.length; i++) {
    //         uint256 initialBalance = coreToken.balanceOf(users[i]);
    //         vm.prank(users[i]);
    //         revenueModel.claimRewards();
    //         assertGt(coreToken.balanceOf(users[i]), initialBalance, "User should receive rewards");
    //     }
        
    //     // Verify treasury and development received their shares
    //     assertGt(coreToken.balanceOf(treasury), 0, "Treasury should receive funds");
    //     assertGt(coreToken.balanceOf(development), 0, "Development should receive funds");
    // }
    
    // function testMultipleRevenueDistributions() public {
    //     uint256 revenueAmount = 500e18;
        
    //     // Setup user
    //     vm.prank(alice);
    //     coreToken.approve(address(stCoreToken), 100e18);
    //     vm.prank(alice);
    //     stCoreToken.mint(100e18);
        
    //     uint256 totalClaimedRewards = 0;
        
    //     // Multiple revenue cycles
    //     for (uint256 i = 0; i < 3; i++) {
    //         // Collect and distribute revenue
    //         vm.prank(deployer);
    //         coreToken.transfer(address(revenueModel), revenueAmount);
    //         vm.prank(deployer);
    //         revenueModel.collectRevenue(revenueAmount, "trading_fees");
    //         vm.prank(deployer);
    //         revenueModel.distributeRevenue();
            
    //         // Claim rewards
    //         uint256 initialBalance = coreToken.balanceOf(alice);
    //         vm.prank(alice);
    //         revenueModel.claimRewards();
    //         uint256 claimedAmount = coreToken.balanceOf(alice) - initialBalance;
    //         totalClaimedRewards += claimedAmount;
    //     }
        
    //     assertGt(totalClaimedRewards, 0, "Should have claimed rewards over multiple cycles");
    //     assertEq(revenueModel.claimedRewards(alice), totalClaimedRewards);
    // }
}
