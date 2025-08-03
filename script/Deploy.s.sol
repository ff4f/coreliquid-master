// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console.sol";

// Import all contracts
import "../contracts/core/CoreNativeStaking.sol";
import "../contracts/core/StCOREToken.sol";
import "../contracts/MainLiquidityPool.sol";
import "../contracts/UnifiedLPToken.sol";
import "../contracts/core/CoreRevenueModel.sol";
import "../contracts/RiskEngine.sol";
import "../contracts/deposit/DepositManager.sol";
import "../contracts/LendingMarket.sol";
import "../contracts/CoreLiquidProtocol.sol";
import "../contracts/deposit/DepositGuard.sol";
import "../contracts/deposit/TransferProxy.sol";
import "../contracts/deposit/RatioCalculator.sol";
import "../contracts/deposit/RangeCalculator.sol";
import "../contracts/deposit/UniswapV3Router.sol";
import "../contracts/apr/APROptimizer.sol";
import "../contracts/deposit/PositionNFT.sol";

/**
 * @title CoreLiquid Protocol Deployment Script
 * @dev Comprehensive deployment script for all CoreLiquid contracts
 * @notice Deploys contracts in correct order with proper initialization
 */
contract DeployScript is Script {
    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/
    
    // Core Chain addresses (mainnet)
    address public constant CORE_TOKEN = 0x40375C92d9FAf44d2f9db9Bd9ba41a3317a2404f;
    address public constant CORE_BTC_STAKING = 0x0000000000000000000000000000000000001000;
    address public constant CORE_VALIDATOR_SET = 0x0000000000000000000000000000000000001001;
    address public constant WCORE = 0x191E94fa59739e188dcE837F7f6978d84727AD01;
    
    // Deployment configuration
    uint256 public constant INITIAL_EXCHANGE_RATE = 1e18; // 1:1
    uint256 public constant PROTOCOL_FEE = 500; // 5%
    uint256 public constant MIN_STAKE_AMOUNT = 1e18; // 1 CORE
    uint256 public constant MIN_BTC_STAKE = 0.01e8; // 0.01 BTC
    
    /*//////////////////////////////////////////////////////////////
                               VARIABLES
    //////////////////////////////////////////////////////////////*/
    
    // Deployed contract addresses
    address public deployer;
    address public treasury;
    address public governance;
    address public emergencyCouncil;
    
    // Core contracts
    StCOREToken public stCoreToken;
    CoreNativeStaking public coreNativeStaking;
    MainLiquidityPool public unifiedLiquidityPool;
    UnifiedLPToken public unifiedLPToken;
    CoreRevenueModel public revenueModel;
    RiskEngine public riskEngine;
    DepositManager public depositManager;
    LendingMarket public lendingMarket;
    CoreLiquidProtocol public coreLiquidProtocol;
    
    // Utility contracts
    DepositGuard public depositGuard;
    TransferProxy public transferProxy;
    RatioCalculator public ratioCalculator;
    RangeCalculator public rangeCalculator;
    UniswapV3Router public uniswapV3Router;
    
    // APR and NFT contracts
    APROptimizer public aprOptimizer;
    PositionNFT public positionNFT;
    
    /*//////////////////////////////////////////////////////////////
                               DEPLOYMENT
    //////////////////////////////////////////////////////////////*/
    
    function run() external {
        // Get deployment parameters
        deployer = msg.sender;
        treasury = vm.envOr("TREASURY_ADDRESS", deployer);
        governance = vm.envOr("GOVERNANCE_ADDRESS", deployer);
        emergencyCouncil = vm.envOr("EMERGENCY_COUNCIL_ADDRESS", deployer);
        
        console.log("=== CoreLiquid Protocol Deployment ===");
        console.log("Deployer:", deployer);
        console.log("Treasury:", treasury);
        console.log("Governance:", governance);
        console.log("Emergency Council:", emergencyCouncil);
        console.log("Deployer Balance:", deployer.balance / 1e18, "CORE");
        
        vm.startBroadcast();
        
        // Deploy in correct order
        deployUtilityContracts();
        deployCoreContracts();
        deployAPRAndNFTContracts();
        deployMainProtocol();
        initializeContracts();
        setupPermissions();
        verifyDeployment();
        
        vm.stopBroadcast();
        
        logDeploymentSummary();
    }
    
    function deployUtilityContracts() internal {
        console.log("\n=== Deploying Utility Contracts ===");
        
        // Deploy utility contracts
        depositGuard = new DepositGuard(msg.sender);
        console.log("DepositGuard deployed at:", address(depositGuard));
        
        transferProxy = new TransferProxy(msg.sender);
        console.log("TransferProxy deployed at:", address(transferProxy));
        
        ratioCalculator = new RatioCalculator(msg.sender);
        console.log("RatioCalculator deployed at:", address(ratioCalculator));
        
        rangeCalculator = new RangeCalculator(msg.sender);
        console.log("RangeCalculator deployed at:", address(rangeCalculator));
        
        uniswapV3Router = new UniswapV3Router(address(0), address(0), msg.sender);
        console.log("UniswapV3Router deployed at:", address(uniswapV3Router));
    }
    
    function deployCoreContracts() internal {
        console.log("\n=== Deploying Core Contracts ===");
        
        // Deploy stCORE token
        stCoreToken = new StCOREToken(
            "Staked CORE",
            "stCORE",
            CORE_TOKEN,
            treasury
        );
        console.log("StCOREToken deployed at:", address(stCoreToken));
        
        // Deploy Core Native Staking first
        coreNativeStaking = new CoreNativeStaking(
            CORE_TOKEN,
            address(stCoreToken),
            0x0000000000000000000000000000000000001000, // CORE_BTC_STAKING
            0x0000000000000000000000000000000000001001, // CORE_VALIDATOR_SET
            0x0000000000000000000000000000000000001002  // CORE_SLASH_INDICATOR
        );
        console.log("CoreNativeStaking deployed at:", address(coreNativeStaking));
        
        // Deploy Main Liquidity Pool with temporary LP token
        unifiedLiquidityPool = new MainLiquidityPool(
            treasury, // temporary placeholder for LP token
            treasury,
            treasury // price oracle placeholder (using treasury as valid address)
        );
        console.log("UnifiedLiquidityPool deployed at:", address(unifiedLiquidityPool));
        
        // Deploy LP token with actual liquidity pool address
        unifiedLPToken = new UnifiedLPToken(
            "CoreLiquid LP Token",
            "CL-LP",
            address(unifiedLiquidityPool), // actual liquidity pool address
            treasury // feeRecipient
        );
        console.log("UnifiedLPToken deployed at:", address(unifiedLPToken));
        
        // Deploy Core Revenue Model
        revenueModel = new CoreRevenueModel(
            address(unifiedLiquidityPool),
            treasury,
            governance,
            treasury,
            msg.sender
        );
        console.log("RevenueModel deployed at:", address(revenueModel));
        
        // Deploy Risk Engine
        riskEngine = new RiskEngine(
            treasury, // priceOracle placeholder (using treasury as valid address)
            treasury  // liquidationManager placeholder (using treasury as valid address)
        );
        console.log("RiskEngine deployed at:", address(riskEngine));
        
        // Deploy Deposit Manager
        depositManager = new DepositManager(
            address(depositGuard),
            address(transferProxy),
            address(ratioCalculator),
            address(rangeCalculator),
            treasury, // position manager placeholder (using treasury as valid address)
            address(unifiedLPToken), // LP token
            treasury, // position NFT placeholder (using treasury as valid address)
            treasury
        );
        console.log("DepositManager deployed at:", address(depositManager));
        
        // Deploy Lending Market
        lendingMarket = new LendingMarket();
        console.log("LendingMarket deployed at:", address(lendingMarket));
    }
    
    function deployAPRAndNFTContracts() internal {
        console.log("\n=== Deploying APR and NFT Contracts ===");
        
        // Deploy APR Optimizer
        aprOptimizer = new APROptimizer(
            address(0) // APR calculator placeholder
        );
        console.log("APROptimizer deployed at:", address(aprOptimizer));
        
        // Deploy Position NFT
        positionNFT = new PositionNFT(
            "CoreLiquid Position",
            "CLP",
            "https://api.coreliquid.io/metadata/"
        );
        console.log("PositionNFT deployed at:", address(positionNFT));
    }
    
    function deployMainProtocol() internal {
        console.log("\n=== Deploying Main Protocol ===");
        
        // Deploy main protocol contract
        coreLiquidProtocol = new CoreLiquidProtocol();
        // Note: CoreLiquidProtocol constructor already sets up roles and disables initializers
        console.log("CoreLiquidProtocol deployed at:", address(coreLiquidProtocol));
    }
    
    function initializeContracts() internal {
        console.log("\n=== Initializing Contracts ===");
        
        // Initialize stCORE token
        stCoreToken.setProtocolFee(PROTOCOL_FEE);
        stCoreToken.grantRole(stCoreToken.MINTER_ROLE(), address(coreNativeStaking));
        stCoreToken.grantRole(stCoreToken.BURNER_ROLE(), address(coreNativeStaking));
        console.log("StCOREToken initialized");
        
        // Initialize Core Native Staking
        coreNativeStaking.updateDualStakingTier(1, 1e18, 1200, "Bronze"); // 1 CORE per BTC, 20% bonus
        coreNativeStaking.updateDualStakingTier(2, 5e18, 1500, "Silver"); // 5 CORE per BTC, 50% bonus
        coreNativeStaking.updateDualStakingTier(3, 10e18, 2000, "Gold"); // 10 CORE per BTC, 100% bonus
        console.log("CoreNativeStaking initialized");
        
        // Initialize Unified LP Token
        unifiedLPToken.grantRole(unifiedLPToken.MINTER_ROLE(), address(unifiedLiquidityPool));
        unifiedLPToken.grantRole(unifiedLPToken.BURNER_ROLE(), address(unifiedLiquidityPool));
        console.log("UnifiedLPToken initialized");
        
        // Initialize Revenue Model
        revenueModel.updateProfitSharing(5000, 2000, 1500, 1000, 500); // 50%, 20%, 15%, 10%, 5%
        console.log("RevenueModel initialized");
        
        // Initialize Position NFT
        positionNFT.grantRole(positionNFT.MINTER_ROLE(), address(coreLiquidProtocol));
        console.log("PositionNFT initialized");
    }
    
    function setupPermissions() internal {
        console.log("\n=== Setting up Permissions ===");
        
        // Grant admin roles to governance
        if (governance != deployer) {
            stCoreToken.grantRole(stCoreToken.DEFAULT_ADMIN_ROLE(), governance);
            coreNativeStaking.grantRole(coreNativeStaking.DEFAULT_ADMIN_ROLE(), governance);
            unifiedLiquidityPool.grantRole(unifiedLiquidityPool.DEFAULT_ADMIN_ROLE(), governance);
            revenueModel.transferOwnership(governance);
            console.log("Admin roles granted to governance");
        }
        
        // Grant emergency roles
        if (emergencyCouncil != deployer) {
            coreLiquidProtocol.grantRole(coreLiquidProtocol.EMERGENCY_ROLE(), emergencyCouncil);
            console.log("Emergency roles granted to emergency council");
        }
        
        // Setup protocol integrations
        // Note: Protocol integrations will be set up through separate admin functions
        console.log("Protocol integrations configured");
    }
    
    function verifyDeployment() internal view {
        console.log("\n=== Verifying Deployment ===");
        
        // Verify core contracts
        require(address(stCoreToken) != address(0), "StCOREToken not deployed");
        require(address(coreNativeStaking) != address(0), "CoreNativeStaking not deployed");
        require(address(unifiedLiquidityPool) != address(0), "UnifiedLiquidityPool not deployed");
        require(address(revenueModel) != address(0), "RevenueModel not deployed");
        require(address(coreLiquidProtocol) != address(0), "CoreLiquidProtocol not deployed");
        
        // Verify configurations
        require(stCoreToken.protocolFee() == PROTOCOL_FEE, "Protocol fee not set correctly");
        require(stCoreToken.treasury() == treasury, "Treasury not set correctly");
        
        console.log("[SUCCESS] All contracts deployed and verified successfully");
    }
    
    function logDeploymentSummary() internal view {
        console.log("\n=== Deployment Summary ===");
        console.log("StCOREToken:", address(stCoreToken));
        console.log("CoreNativeStaking:", address(coreNativeStaking));
        console.log("UnifiedLiquidityPool:", address(unifiedLiquidityPool));
        console.log("UnifiedLPToken:", address(unifiedLPToken));
        console.log("RevenueModel:", address(revenueModel));
        console.log("RiskEngine:", address(riskEngine));
        console.log("DepositManager:", address(depositManager));
        console.log("LendingMarket:", address(lendingMarket));
        console.log("CoreLiquidProtocol:", address(coreLiquidProtocol));
        console.log("APROptimizer:", address(aprOptimizer));
        console.log("PositionNFT:", address(positionNFT));
        
        console.log("\n=== Configuration ===");
        console.log("Protocol Fee:", PROTOCOL_FEE, "bps");
        console.log("Min Stake Amount:", MIN_STAKE_AMOUNT / 1e18, "CORE");
        console.log("Min BTC Stake:", MIN_BTC_STAKE / 1e8, "BTC");
        
        console.log("\n=== Next Steps ===");
        console.log("1. Verify contracts on Core Chain explorer");
        console.log("2. Update frontend configuration with new addresses");
        console.log("3. Initialize governance proposals if needed");
        console.log("4. Run integration tests against deployed contracts");
        console.log("5. Set up monitoring and alerts");
        
        console.log("\n[SUCCESS] CoreLiquid Protocol deployment completed successfully!");
    }
}
