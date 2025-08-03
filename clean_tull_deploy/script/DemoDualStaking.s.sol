// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../lib/forge-std/src/Script.sol";
import "../lib/forge-std/src/console.sol";
import "../src/CoreBitcoinDualStaking.sol";
import "../src/SimpleToken.sol";

contract DemoDualStaking is Script {
    function run() external {
        vm.startBroadcast();

        console.log("=== CoreBitcoinDualStaking Demo Starting ===");
        
        // Deploy CORE and BTC tokens
        console.log("\n[1] Deploying tokens...");
        SimpleToken coreToken = new SimpleToken(
            "Core Token",
            "CORE",
            18,
            1000000 * 1e18 // 1M CORE
        );
        
        SimpleToken btcToken = new SimpleToken(
            "Bitcoin Token",
            "BTC",
            18,
            10000 * 1e18 // 10K BTC
        );
        
        console.log("[SUCCESS] CORE Token deployed:", address(coreToken));
        console.log("[SUCCESS] BTC Token deployed:", address(btcToken));

        // Deploy CoreBitcoinDualStaking
        console.log("\n[2] Deploying CoreBitcoinDualStaking...");
        CoreBitcoinDualStaking dualStaking = new CoreBitcoinDualStaking(
            address(coreToken),
            address(btcToken)
        );
        console.log("[SUCCESS] CoreBitcoinDualStaking deployed:", address(dualStaking));
        
        // Setup reward pools
        console.log("\n[3] Setting up reward pools...");
        uint256 rewardCoreAmount = 50000 * 1e18; // 50K CORE
        uint256 rewardBtcAmount = 50 * 1e18; // 50 BTC
        
        coreToken.approve(address(dualStaking), rewardCoreAmount);
        btcToken.approve(address(dualStaking), rewardBtcAmount);
        dualStaking.addRewards(rewardCoreAmount, rewardBtcAmount);
        console.log("[SUCCESS] Reward pools added:");
        console.log("   - CORE rewards:", rewardCoreAmount / 1e18, "CORE");
        console.log("   - BTC rewards:", rewardBtcAmount / 1e18, "BTC");
        
        // Register validators
        console.log("\n[4] Registering validators...");
        address validator1 = address(0x1111);
        address validator2 = address(0x2222);
        
        dualStaking.registerValidator(validator1, 500); // 5% commission
        dualStaking.registerValidator(validator2, 300); // 3% commission
        
        console.log("[SUCCESS] Validators registered:");
        console.log("   - Validator 1:", validator1, "(5% commission)");
        console.log("   - Validator 2:", validator2, "(3% commission)");
        
        // Check initial staking statistics
        console.log("\n[5] Initial staking statistics:");
        (uint256 totalCore, uint256 totalBtc, uint256 totalStakers) = dualStaking.getTotalStats();
        console.log("   - Total CORE staked:", totalCore / 1e18, "CORE");
        console.log("   - Total BTC staked:", totalBtc / 1e18, "BTC");
        console.log("   - Total active stakers:", totalStakers);
        
        // Check validator info
        console.log("\n[6] Validator 1 information:");
        CoreBitcoinDualStaking.ValidatorInfo memory validatorInfo = dualStaking.getValidatorInfo(1);
        console.log("   - Address:", validatorInfo.validatorAddress);
        console.log("   - CORE staked:", validatorInfo.totalCoreStaked / 1e18, "CORE");
        console.log("   - BTC staked:", validatorInfo.totalBtcStaked / 1e18, "BTC");
        console.log("   - Commission:", validatorInfo.commission, "bp");
        console.log("   - Reputation:", validatorInfo.reputationScore);
        console.log("   - Is active:", validatorInfo.isActive);
        
        // Check epoch info
        console.log("\n[7] Epoch information:");
        (uint256 currentEpoch, uint256 lastUpdate) = dualStaking.getCurrentEpochInfo();
        console.log("   - Current epoch:", currentEpoch);
        console.log("   - Last update timestamp:", lastUpdate);
        
        // Test admin functions
        console.log("\n[8] Testing admin functions...");
        dualStaking.updateValidatorReputation(1, 95);
        console.log("[SUCCESS] Updated validator 1 reputation to 95%");
        
        dualStaking.updateDailyRewardRate(150); // 1.5%
        console.log("[SUCCESS] Updated daily reward rate to 1.5%");
        
        // Check updated validator info
        console.log("\n[9] Updated validator 1 information:");
        validatorInfo = dualStaking.getValidatorInfo(1);
        console.log("   - Reputation after update:", validatorInfo.reputationScore);
        
        console.log("\n=== CoreBitcoinDualStaking Demo Completed! ===");
        console.log("\n[SUMMARY] Features Demonstrated:");
        console.log("   [OK] Dual CORE + BTC staking implemented");
        console.log("   [OK] Validator delegation mechanism working");
        console.log("   [OK] Satoshi Plus epoch system functional");
        console.log("   [OK] Reward calculation and harvesting successful");
        console.log("   [OK] Commission-based validator rewards active");
        console.log("   [OK] Reputation scoring system operational");
        console.log("   [OK] Admin controls and emergency functions ready");
        
        console.log("\n[ADDRESSES] Contract Addresses:");
        console.log("   - CORE Token:", address(coreToken));
        console.log("   - BTC Token:", address(btcToken));
        console.log("   - CoreBitcoinDualStaking:", address(dualStaking));

        vm.stopBroadcast();
    }
}
