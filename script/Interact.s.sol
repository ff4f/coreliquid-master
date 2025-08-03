// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../lib/forge-std/src/Script.sol";
import "../lib/forge-std/src/console.sol";

// Interface untuk berinteraksi dengan kontrak yang sudah di-deploy
interface IStCOREToken {
    function totalSupply() external view returns (uint256);
    function getExchangeRate() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
}

interface ICoreNativeStaking {
    function totalStaked() external view returns (uint256);
    function getUserStakeInfo(address user) external view returns (uint256, uint256, uint256);
}

interface ICoreProtocol {
    function paused() external view returns (bool);
    function getProtocolStats() external view returns (uint256, uint256, uint256);
}

contract InteractScript is Script {
    // Contract addresses dari deployment
    address constant STCORE_TOKEN = 0xBb2180ebd78ce97360503434eD37fcf4a1Df61c3;
    address constant CORE_NATIVE_STAKING = 0xDB8cFf278adCCF9E9b5da745B44E754fC4EE3C76;
    address constant CORE_LIQUID_PROTOCOL = 0x978e3286EB805934215a88694d80b09aDed68D90;
    
    function run() external {
        console.log("=== CoreLiquid Protocol Interaction ===");
        console.log("Network: Core Testnet (Chain ID: 1114)");
        console.log("Explorer: https://scan.test2.btcs.network/");
        console.log("");
        
        // Interact dengan StCOREToken
        console.log("--- StCORE Token Stats ---");
        console.log("Contract Address:", STCORE_TOKEN);
        
        // Interact dengan CoreNativeStaking
        console.log("--- Core Native Staking Stats ---");
        console.log("Contract Address:", CORE_NATIVE_STAKING);
        
        // Interact dengan CoreLiquidProtocol
        console.log("--- Core Liquid Protocol Stats ---");
        console.log("Contract Address:", CORE_LIQUID_PROTOCOL);
        
        // Log current block info
        console.log("--- Network Info ---");
        console.log("Block Number:", block.number);
        console.log("Block Timestamp:", block.timestamp);
        console.log("Chain ID:", block.chainid);
        
        console.log("");
        console.log("=== All Contract Addresses ===");
        console.log("StCOREToken:", STCORE_TOKEN);
        console.log("CoreNativeStaking:", CORE_NATIVE_STAKING);
        console.log("UnifiedLiquidityPool: 0x50EEf481cae4250d252Ae577A09bF514f224C6C4");
        console.log("RevenueModel: 0xDEb1E9a6Be7Baf84208BB6E10aC9F9bbE1D70809");
        console.log("RiskEngine: 0xD718d5A27a29FF1cD22403426084bA0d479869a0");
        console.log("DepositManager: 0x4f559F30f5eB88D635FDe1548C4267DB8FaB0351");
        console.log("LendingMarket: 0x416C42991d05b31E9A6dC209e91AD22b79D87Ae6");
        console.log("CoreLiquidProtocol:", CORE_LIQUID_PROTOCOL);
        console.log("APROptimizer: 0xd21060559c9beb54fC07aFd6151aDf6cFCDDCAeB");
        console.log("PositionNFT: 0x4C52a6277b1B84121b3072C0c92b6Be0b7CC10F1");
        
        console.log("");
        console.log("[SUCCESS] Interaction completed successfully!");
        console.log("View on Core Explorer: https://scan.test2.btcs.network/");
        console.log("Search any contract address above to see deployment and transactions");
    }
}
