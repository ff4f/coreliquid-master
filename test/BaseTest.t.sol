// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "lib/forge-std/src/Test.sol";
import "lib/forge-std/src/console.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

// Import Core contracts
import "../contracts/core/CoreLiquidProtocol.sol";
import "../contracts/core/CoreNativeStaking.sol";
import "../contracts/staking/StCOREToken.sol";
import "../contracts/core/CoreRevenueModel.sol";
import "../contracts/core/TrueUnifiedLiquidityLayer.sol";
import "../contracts/UnifiedLPToken.sol";
import "../contracts/utils/DepositManager.sol";
import "../contracts/borrow/LendingMarket.sol";
import "../contracts/common/RiskEngine.sol";
import "./mocks/MockCoreBTCStaking.sol";
import "./mocks/MockCoreValidator.sol";

/**
 * @title BaseTest
 * @dev Base test contract with common setup and utilities for CoreLiquid Protocol
 * @notice Follows Core DAO testing patterns and best practices
 */
contract BaseTest is Test {
    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/
    
    uint256 public constant INITIAL_BALANCE = 1000 ether;
    uint256 public constant CORE_CHAIN_ID = 1116;
    uint256 public constant CORE_TESTNET_CHAIN_ID = 1115;
    
    // Core Chain native contract addresses
    address public constant CORE_BTC_STAKING = 0x0000000000000000000000000000000000001000;
    address public constant CORE_VALIDATOR_SET = 0x0000000000000000000000000000000000001001;
    address public constant CORE_SLASH_INDICATOR = 0x0000000000000000000000000000000000001002;
    
    /*//////////////////////////////////////////////////////////////
                               VARIABLES
    //////////////////////////////////////////////////////////////*/
    
    // Test accounts
    address public deployer;
    address public alice;
    address public bob;
    address public charlie;
    address public treasury;
    address public governance;
    address public emergencyCouncil;
    
    // Core protocol contracts
    CoreLiquidProtocol public coreLiquidProtocol;
    CoreNativeStaking public coreNativeStaking;
    StCOREToken public stCoreToken;
    CoreRevenueModel public revenueModel;
    TrueUnifiedLiquidityLayer public unifiedLiquidityPool;
    UnifiedLPToken public unifiedLPToken;
    DepositManager public depositManager;
    LendingMarket public lendingMarket;
    RiskEngine public riskEngine;
    
    // Mock tokens for testing
    MockERC20 public coreToken;
    MockERC20 public wbtcToken;
    MockERC20 public usdcToken;
    MockERC20 public ethToken;
    
    // Mock Core chain contracts
    MockCoreBTCStaking public mockCoreBTCStaking;
    MockCoreValidator public mockCoreValidator;
    
    /*//////////////////////////////////////////////////////////////
                               EVENTS
    //////////////////////////////////////////////////////////////*/
    
    event TestSetupCompleted(address indexed deployer, uint256 timestamp);
    event ContractDeployed(string contractName, address contractAddress);
    
    /*//////////////////////////////////////////////////////////////
                               SETUP
    //////////////////////////////////////////////////////////////*/
    
    function setUp() public virtual {
        // Setup test accounts
        deployer = address(this);
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        charlie = makeAddr("charlie");
        treasury = makeAddr("treasury");
        governance = makeAddr("governance");
        emergencyCouncil = makeAddr("emergencyCouncil");
        
        // Deploy mock tokens
        _deployMockTokens();
        
        // Deploy mock Core chain contracts
        _deployMockCoreContracts();
        
        // Deploy core protocol contracts
        _deployProtocolContracts();
        
        // Setup initial balances
        _setupInitialBalances();
        
        // Configure protocol
        _configureProtocol();
        
        emit TestSetupCompleted(deployer, block.timestamp);
    }
    
    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    
    function _deployMockTokens() internal {
        coreToken = new MockERC20("Core Token", "CORE", 18);
        wbtcToken = new MockERC20("Wrapped Bitcoin", "WBTC", 8);
        usdcToken = new MockERC20("USD Coin", "USDC", 6);
        ethToken = new MockERC20("Ethereum", "ETH", 18);
        
        emit ContractDeployed("CORE Token", address(coreToken));
        emit ContractDeployed("WBTC Token", address(wbtcToken));
        emit ContractDeployed("USDC Token", address(usdcToken));
        emit ContractDeployed("ETH Token", address(ethToken));
    }
    
    function _deployMockCoreContracts() internal {
        mockCoreBTCStaking = new MockCoreBTCStaking();
        mockCoreValidator = new MockCoreValidator();
        
        emit ContractDeployed("Mock Core BTC Staking", address(mockCoreBTCStaking));
        emit ContractDeployed("Mock Core Validator", address(mockCoreValidator));
    }
    
    function _deployProtocolContracts() internal {
        // Deploy StCORE token first
        stCoreToken = new StCOREToken(
            "Staked CORE",
            "stCORE",
            address(coreToken),
            address(0) // Will be set after coreNativeStaking deployment
        );
        emit ContractDeployed("StCORE Token", address(stCoreToken));
        
        // Deploy Core Native Staking
        coreNativeStaking = new CoreNativeStaking(
            address(coreToken),
            address(stCoreToken),
            address(mockCoreBTCStaking),
            address(mockCoreValidator),
            address(0) // Mock slash indicator (not used in tests)
        );
        emit ContractDeployed("Core Native Staking", address(coreNativeStaking));
        
        // Deploy Unified Liquidity Pool
        unifiedLiquidityPool = new TrueUnifiedLiquidityLayer(
            address(0), // oracle placeholder
            address(0), // positionManager placeholder
            deployer
        );
        emit ContractDeployed("Unified Liquidity Pool", address(unifiedLiquidityPool));
        
        // Deploy Unified LP Token
        unifiedLPToken = new UnifiedLPToken(
            "CoreLiquid Unified LP Token",
            "CULP",
            address(unifiedLiquidityPool),
            treasury
        );
        emit ContractDeployed("Unified LP Token", address(unifiedLPToken));
        
        // Deploy Revenue Model
        revenueModel = new CoreRevenueModel(
            address(unifiedLiquidityPool),
            treasury, // treasury address
            treasury, // development fund
            address(coreNativeStaking), // staking rewards address
            deployer  // initial owner
        );
        emit ContractDeployed("Revenue Model", address(revenueModel));
        
        // Deploy Risk Engine
        riskEngine = new RiskEngine(
            address(0), // oracle
            address(0), // positionRegistry
            address(0), // lendingMarket
            address(0), // collateralManager
            deployer    // initialOwner
        );
        emit ContractDeployed("Risk Engine", address(riskEngine));
        
        // Deploy Lending Market
        lendingMarket = new LendingMarket(address(0)); // oracle
        emit ContractDeployed("Lending Market", address(lendingMarket));
        
        // Deploy main protocol contract without initialization for now
        coreLiquidProtocol = new CoreLiquidProtocol();
        emit ContractDeployed("Core Liquid Protocol", address(coreLiquidProtocol));
        
        // Initialize in individual tests if needed
        
        // Skip DepositManager for now due to missing dependencies
        // depositManager will be deployed separately when needed
    }
    
    function _setupInitialBalances() internal {
        // Mint tokens to test accounts
        address[4] memory testAccounts = [alice, bob, charlie, deployer];
        
        for (uint256 i = 0; i < testAccounts.length; i++) {
            coreToken.mint(testAccounts[i], INITIAL_BALANCE);
            wbtcToken.mint(testAccounts[i], INITIAL_BALANCE / 1e10); // WBTC has 8 decimals
            usdcToken.mint(testAccounts[i], INITIAL_BALANCE / 1e12); // USDC has 6 decimals
            ethToken.mint(testAccounts[i], INITIAL_BALANCE);
            
            // Give some ETH for gas
            vm.deal(testAccounts[i], 100 ether);
        }
    }
    
    function _configureProtocol() internal {
        // Grant necessary roles to deployer for CoreLiquidProtocol
        coreLiquidProtocol.grantRole(coreLiquidProtocol.UPGRADER_ROLE(), deployer);
        coreLiquidProtocol.grantRole(coreLiquidProtocol.DEFAULT_ADMIN_ROLE(), deployer);
        
        // Grant necessary roles to deployer for StCORE token
        stCoreToken.grantRole(stCoreToken.MINTER_ROLE(), deployer);
        stCoreToken.grantRole(stCoreToken.BURNER_ROLE(), deployer);
        stCoreToken.grantRole(stCoreToken.ORACLE_ROLE(), deployer);
        stCoreToken.grantRole(stCoreToken.EMERGENCY_ROLE(), deployer);
        stCoreToken.grantRole(stCoreToken.DEFAULT_ADMIN_ROLE(), deployer);
        
        // Grant roles to test users for testing purposes
        stCoreToken.grantRole(stCoreToken.MINTER_ROLE(), alice);
        stCoreToken.grantRole(stCoreToken.BURNER_ROLE(), alice);
        stCoreToken.grantRole(stCoreToken.ORACLE_ROLE(), alice);
        stCoreToken.grantRole(stCoreToken.MINTER_ROLE(), bob);
        stCoreToken.grantRole(stCoreToken.BURNER_ROLE(), bob);
        stCoreToken.grantRole(stCoreToken.ORACLE_ROLE(), bob);
        stCoreToken.grantRole(stCoreToken.MINTER_ROLE(), charlie);
        stCoreToken.grantRole(stCoreToken.BURNER_ROLE(), charlie);
        stCoreToken.grantRole(stCoreToken.ORACLE_ROLE(), charlie);
        
        // Grant necessary roles to deployer for CoreNativeStaking
        coreNativeStaking.grantRole(coreNativeStaking.OPERATOR_ROLE(), deployer);
        coreNativeStaking.grantRole(coreNativeStaking.EMERGENCY_ROLE(), deployer);
        
        // Update staking contract in StCORE token (this automatically grants necessary roles)
        stCoreToken.setStakingContract(address(coreNativeStaking));
        
        // Configure protocol components (only if they are deployed)
        if (address(lendingMarket) != address(0)) {
            coreLiquidProtocol.updateComponent("LENDING_MARKET", address(lendingMarket));
        }
        if (address(riskEngine) != address(0)) {
            coreLiquidProtocol.updateComponent("RISK_ENGINE", address(riskEngine));
        }
        if (address(revenueModel) != address(0)) {
            coreLiquidProtocol.updateComponent("REVENUE_MODEL", address(revenueModel));
        }
        if (address(unifiedLiquidityPool) != address(0)) {
            coreLiquidProtocol.updateComponent("ULP", address(unifiedLiquidityPool));
        }
        if (address(coreNativeStaking) != address(0)) {
            coreLiquidProtocol.updateComponent("CORE_STAKING", address(coreNativeStaking));
        }
    }
    
    /*//////////////////////////////////////////////////////////////
                           HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    
    function skipTime(uint256 timeToSkip) internal {
        vm.warp(block.timestamp + timeToSkip);
    }
    
    function skipBlocks(uint256 blocksToSkip) internal {
        vm.roll(block.number + blocksToSkip);
    }
    
    function expectEmitCheckAll() internal {
        vm.expectEmit(true, true, true, true);
    }
    

    function getTokenBalance(address token, address account) internal view returns (uint256) {
        return IERC20(token).balanceOf(account);
    }
    
    function approveToken(address token, address spender, uint256 amount, address from) internal {
        vm.prank(from);
        IERC20(token).approve(spender, amount);
    }
}

/**
 * @title MockERC20
 * @dev Mock ERC20 token for testing purposes
 */
contract MockERC20 is ERC20 {
    uint8 private _decimals;
    
    constructor(string memory name, string memory symbol, uint8 decimals_) ERC20(name, symbol) {
        _decimals = decimals_;
    }
    
    function decimals() public view override returns (uint8) {
        return _decimals;
    }
    
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
    
    function burn(address from, uint256 amount) external {
        _burn(from, amount);
    }
}
