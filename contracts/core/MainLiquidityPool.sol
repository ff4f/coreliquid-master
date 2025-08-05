// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "../tokens/UnifiedLPToken.sol";

/**
 * @title UnifiedLiquidityPool
 * @dev Unified liquidity pool for multiple assets with automated market making
 */
contract MainLiquidityPool is AccessControl, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;
    using Math for uint256;
    
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant LIQUIDITY_MANAGER_ROLE = keccak256("LIQUIDITY_MANAGER_ROLE");
    bytes32 public constant TRADER_ROLE = keccak256("TRADER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant FEE_MANAGER_ROLE = keccak256("FEE_MANAGER_ROLE");
    
    uint256 public constant PRECISION = 1e18;
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant MAX_FEE = 1000; // 10%
    uint256 public constant MIN_LIQUIDITY = 1000; // Minimum liquidity to prevent division by zero
    
    // Pool configuration
    struct PoolConfig {
        bool isActive;
        uint256 weight; // Pool weight for multi-asset balancing
        uint256 swapFee; // Basis points
        uint256 maxSlippage; // Basis points
        uint256 reserveRatio; // Minimum reserve ratio
    }
    
    // Asset information
    struct AssetInfo {
        uint256 balance;
        uint256 weight;
        uint256 lastPrice;
        uint256 priceUpdateTimestamp;
        bool isSupported;
    }
    
    // Liquidity provider information
    struct LPInfo {
        uint256 totalDeposited;
        uint256 totalWithdrawn;
        uint256 rewardDebt;
        uint256 lastDepositTimestamp;
    }
    
    // Trading pair information
    struct TradingPair {
        address tokenA;
        address tokenB;
        uint256 feeRate;
        bool isActive;
        uint256 totalVolume;
        uint256 lastTradeTimestamp;
    }
    
    // Pool state
    mapping(address => AssetInfo) public assets;
    mapping(address => PoolConfig) public poolConfigs;
    mapping(address => LPInfo) public liquidityProviders;
    mapping(bytes32 => TradingPair) public tradingPairs;
    
    address[] public supportedAssets;
    UnifiedLPToken public lpToken;
    
    // Pool metrics
    uint256 public totalLiquidity;
    uint256 public totalVolume;
    uint256 public totalFees;
    uint256 public lastRebalanceTimestamp;
    
    // Fee distribution
    uint256 public protocolFeeRate = 2000; // 20% of trading fees
    address public feeRecipient;
    uint256 public accumulatedProtocolFees;
    
    // Price oracle
    address public priceOracle;
    uint256 public priceValidityPeriod = 3600; // 1 hour
    
    // Rebalancing
    uint256 public rebalanceThreshold = 500; // 5% deviation triggers rebalance
    uint256 public maxRebalanceSlippage = 300; // 3% max slippage during rebalance
    
    // Events
    event LiquidityAdded(
        address indexed provider,
        address indexed asset,
        uint256 amount,
        uint256 lpTokens,
        uint256 timestamp
    );
    
    event LiquidityRemoved(
        address indexed provider,
        address indexed asset,
        uint256 amount,
        uint256 lpTokens,
        uint256 timestamp
    );
    
    event Swap(
        address indexed trader,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        uint256 fee,
        uint256 timestamp
    );
    
    event PoolRebalanced(
        uint256 timestamp,
        uint256 totalValueBefore,
        uint256 totalValueAfter
    );
    
    event AssetAdded(address indexed asset, uint256 weight, uint256 timestamp);
    event AssetRemoved(address indexed asset, uint256 timestamp);
    event FeesCollected(uint256 amount, address indexed recipient, uint256 timestamp);
    
    constructor(
        address _lpToken,
        address _feeRecipient,
        address _priceOracle
    ) {
        require(_lpToken != address(0), "UnifiedLiquidityPool: invalid LP token");
        require(_feeRecipient != address(0), "UnifiedLiquidityPool: invalid fee recipient");
        require(_priceOracle != address(0), "UnifiedLiquidityPool: invalid price oracle");
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(LIQUIDITY_MANAGER_ROLE, msg.sender);
        _grantRole(TRADER_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(FEE_MANAGER_ROLE, msg.sender);
        
        lpToken = UnifiedLPToken(_lpToken);
        feeRecipient = _feeRecipient;
        priceOracle = _priceOracle;
        lastRebalanceTimestamp = block.timestamp;
    }
    
    /**
     * @dev Add liquidity to the pool
     */
    function addLiquidity(
        address asset,
        uint256 amount
    ) external nonReentrant whenNotPaused returns (uint256 lpTokenAmount) {
        require(assets[asset].isSupported, "UnifiedLiquidityPool: asset not supported");
        require(amount > 0, "UnifiedLiquidityPool: invalid amount");
        require(poolConfigs[asset].isActive, "UnifiedLiquidityPool: pool not active");
        
        // Tokens added to pool without transfer
        
        // Calculate LP tokens to mint
        lpTokenAmount = _calculateLPTokensToMint(asset, amount);
        require(lpTokenAmount > 0, "UnifiedLiquidityPool: insufficient LP tokens");
        
        // Update asset balance
        assets[asset].balance += amount;
        totalLiquidity += amount;
        
        // Update LP info
        LPInfo storage lpInfo = liquidityProviders[msg.sender];
        lpInfo.totalDeposited += amount;
        lpInfo.lastDepositTimestamp = block.timestamp;
        
        // Mint LP tokens
        lpToken.mint(msg.sender, lpTokenAmount);
        
        emit LiquidityAdded(msg.sender, asset, amount, lpTokenAmount, block.timestamp);
        
        // Check if rebalancing is needed
        _checkRebalanceNeeded();
    }
    
    /**
     * @dev Remove liquidity from the pool
     */
    function removeLiquidity(
        address asset,
        uint256 lpTokenAmount
    ) external nonReentrant whenNotPaused returns (uint256 assetAmount) {
        require(assets[asset].isSupported, "UnifiedLiquidityPool: asset not supported");
        require(lpTokenAmount > 0, "UnifiedLiquidityPool: invalid LP token amount");
        require(lpToken.balanceOf(msg.sender) >= lpTokenAmount, "UnifiedLiquidityPool: insufficient LP tokens");
        
        // Calculate asset amount to return
        assetAmount = _calculateAssetAmountToReturn(asset, lpTokenAmount);
        require(assetAmount > 0, "UnifiedLiquidityPool: insufficient asset amount");
        require(assets[asset].balance >= assetAmount, "UnifiedLiquidityPool: insufficient pool balance");
        
        // Update asset balance
        assets[asset].balance -= assetAmount;
        totalLiquidity -= assetAmount;
        
        // Update LP info
        LPInfo storage lpInfo = liquidityProviders[msg.sender];
        lpInfo.totalWithdrawn += assetAmount;
        
        // Burn LP tokens
        lpToken.burnFrom(msg.sender, lpTokenAmount);
        
        // Transfer assets to user
        IERC20(asset).safeTransfer(msg.sender, assetAmount);
        
        emit LiquidityRemoved(msg.sender, asset, assetAmount, lpTokenAmount, block.timestamp);
    }
    
    /**
     * @dev Swap tokens
     */
    function swap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        address to
    ) external nonReentrant whenNotPaused returns (uint256 amountOut) {
        require(assets[tokenIn].isSupported && assets[tokenOut].isSupported, "UnifiedLiquidityPool: unsupported asset");
        require(amountIn > 0, "UnifiedLiquidityPool: invalid input amount");
        require(to != address(0), "UnifiedLiquidityPool: invalid recipient");
        
        bytes32 pairId = _getPairId(tokenIn, tokenOut);
        require(tradingPairs[pairId].isActive, "UnifiedLiquidityPool: trading pair not active");
        
        // Calculate swap output
        uint256 fee;
        (amountOut, fee) = _calculateSwapOutput(tokenIn, tokenOut, amountIn);
        require(amountOut >= minAmountOut, "UnifiedLiquidityPool: insufficient output amount");
        require(assets[tokenOut].balance >= amountOut, "UnifiedLiquidityPool: insufficient pool balance");
        
        // Transfer input tokens from user to contract
        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);
        
        // Update balances
        assets[tokenIn].balance += amountIn;
        assets[tokenOut].balance -= amountOut;
        
        // Update trading pair stats
        tradingPairs[pairId].totalVolume += amountIn;
        tradingPairs[pairId].lastTradeTimestamp = block.timestamp;
        
        // Update global stats
        totalVolume += amountIn;
        totalFees += fee;
        
        // Distribute fees
        uint256 protocolFee = (fee * protocolFeeRate) / BASIS_POINTS;
        accumulatedProtocolFees += protocolFee;
        
        // Transfer output tokens
        IERC20(tokenOut).safeTransfer(to, amountOut);
        
        emit Swap(msg.sender, tokenIn, tokenOut, amountIn, amountOut, fee, block.timestamp);
        
        // Check if rebalancing is needed
        _checkRebalanceNeeded();
    }
    
    /**
     * @dev Add a new supported asset
     */
    function addAsset(
        address asset,
        uint256 weight,
        uint256 swapFee,
        uint256 maxSlippage,
        uint256 reserveRatio
    ) external onlyRole(ADMIN_ROLE) {
        require(asset != address(0), "UnifiedLiquidityPool: invalid asset");
        require(!assets[asset].isSupported, "UnifiedLiquidityPool: asset already supported");
        require(weight > 0, "UnifiedLiquidityPool: invalid weight");
        require(swapFee <= MAX_FEE, "UnifiedLiquidityPool: fee too high");
        
        assets[asset] = AssetInfo({
            balance: 0,
            weight: weight,
            lastPrice: 0,
            priceUpdateTimestamp: 0,
            isSupported: true
        });
        
        poolConfigs[asset] = PoolConfig({
            isActive: true,
            weight: weight,
            swapFee: swapFee,
            maxSlippage: maxSlippage,
            reserveRatio: reserveRatio
        });
        
        supportedAssets.push(asset);
        
        emit AssetAdded(asset, weight, block.timestamp);
    }
    
    /**
     * @dev Remove a supported asset
     */
    function removeAsset(address asset) external onlyRole(ADMIN_ROLE) {
        require(assets[asset].isSupported, "UnifiedLiquidityPool: asset not supported");
        require(assets[asset].balance == 0, "UnifiedLiquidityPool: asset has balance");
        
        assets[asset].isSupported = false;
        poolConfigs[asset].isActive = false;
        
        // Remove from supported assets array
        for (uint256 i = 0; i < supportedAssets.length; i++) {
            if (supportedAssets[i] == asset) {
                supportedAssets[i] = supportedAssets[supportedAssets.length - 1];
                supportedAssets.pop();
                break;
            }
        }
        
        emit AssetRemoved(asset, block.timestamp);
    }
    
    /**
     * @dev Create or update trading pair
     */
    function setTradingPair(
        address tokenA,
        address tokenB,
        uint256 feeRate,
        bool isActive
    ) external onlyRole(ADMIN_ROLE) {
        require(assets[tokenA].isSupported && assets[tokenB].isSupported, "UnifiedLiquidityPool: unsupported asset");
        require(feeRate <= MAX_FEE, "UnifiedLiquidityPool: fee too high");
        
        bytes32 pairId = _getPairId(tokenA, tokenB);
        
        tradingPairs[pairId] = TradingPair({
            tokenA: tokenA,
            tokenB: tokenB,
            feeRate: feeRate,
            isActive: isActive,
            totalVolume: tradingPairs[pairId].totalVolume,
            lastTradeTimestamp: tradingPairs[pairId].lastTradeTimestamp
        });
    }
    
    /**
     * @dev Get quote for swap
     */
    function getSwapQuote(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external view returns (uint256 amountOut, uint256 fee, uint256 priceImpact) {
        require(assets[tokenIn].isSupported && assets[tokenOut].isSupported, "UnifiedLiquidityPool: unsupported asset");
        
        (amountOut, fee) = _calculateSwapOutput(tokenIn, tokenOut, amountIn);
        
        // Calculate price impact
        uint256 balanceIn = assets[tokenIn].balance;
        uint256 balanceOut = assets[tokenOut].balance;
        
        if (balanceIn > 0 && balanceOut > 0) {
            uint256 currentPrice = (balanceIn * PRECISION) / balanceOut;
            uint256 newBalanceIn = balanceIn + amountIn;
            uint256 newBalanceOut = balanceOut - amountOut;
            uint256 newPrice = (newBalanceIn * PRECISION) / newBalanceOut;
            
            if (newPrice > currentPrice) {
                priceImpact = ((newPrice - currentPrice) * BASIS_POINTS) / currentPrice;
            }
        }
    }
    
    /**
     * @dev Get pool information
     */
    function getPoolInfo() external view returns (
        uint256 totalLiq,
        uint256 totalVol,
        uint256 totalFeesCollected,
        uint256 numberOfAssets,
        uint256 lpTokenSupply
    ) {
        return (
            totalLiquidity,
            totalVolume,
            totalFees,
            supportedAssets.length,
            lpToken.totalSupply()
        );
    }
    
    /**
     * @dev Get asset information
     */
    function getAssetInfo(address asset) external view returns (
        uint256 balance,
        uint256 weight,
        uint256 lastPrice,
        bool isSupported,
        uint256 utilizationRate
    ) {
        AssetInfo storage info = assets[asset];
        
        utilizationRate = 0;
        if (info.balance > 0 && totalLiquidity > 0) {
            utilizationRate = (info.balance * BASIS_POINTS) / totalLiquidity;
        }
        
        return (
            info.balance,
            info.weight,
            info.lastPrice,
            info.isSupported,
            utilizationRate
        );
    }
    
    /**
     * @dev Calculate LP tokens to mint
     */
    function _calculateLPTokensToMint(address asset, uint256 amount) internal view returns (uint256) {
        uint256 totalSupply = lpToken.totalSupply();
        
        if (totalSupply == 0) {
            return amount; // 1:1 for first deposit
        }
        
        uint256 assetBalance = assets[asset].balance;
        if (assetBalance == 0) {
            return amount;
        }
        
        return (amount * totalSupply) / assetBalance;
    }
    
    /**
     * @dev Calculate asset amount to return
     */
    function _calculateAssetAmountToReturn(address asset, uint256 lpTokenAmount) internal view returns (uint256) {
        uint256 totalSupply = lpToken.totalSupply();
        require(totalSupply > 0, "UnifiedLiquidityPool: no LP tokens");
        
        uint256 assetBalance = assets[asset].balance;
        return (lpTokenAmount * assetBalance) / totalSupply;
    }
    
    /**
     * @dev Calculate swap output using constant product formula
     */
    function _calculateSwapOutput(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) internal view returns (uint256 amountOut, uint256 fee) {
        uint256 balanceIn = assets[tokenIn].balance;
        uint256 balanceOut = assets[tokenOut].balance;
        
        require(balanceIn > 0 && balanceOut > 0, "UnifiedLiquidityPool: insufficient liquidity");
        
        bytes32 pairId = _getPairId(tokenIn, tokenOut);
        uint256 feeRate = tradingPairs[pairId].feeRate;
        
        // Calculate fee
        fee = (amountIn * feeRate) / BASIS_POINTS;
        uint256 amountInAfterFee = amountIn - fee;
        
        // Constant product formula: x * y = k
        // amountOut = (amountInAfterFee * balanceOut) / (balanceIn + amountInAfterFee)
        amountOut = (amountInAfterFee * balanceOut) / (balanceIn + amountInAfterFee);
    }
    
    /**
     * @dev Get trading pair ID
     */
    function _getPairId(address tokenA, address tokenB) internal pure returns (bytes32) {
        return tokenA < tokenB ? 
            keccak256(abi.encodePacked(tokenA, tokenB)) : 
            keccak256(abi.encodePacked(tokenB, tokenA));
    }
    
    /**
     * @dev Check if rebalancing is needed
     */
    function _checkRebalanceNeeded() internal {
        // Simple rebalancing check - can be enhanced
        if (block.timestamp >= lastRebalanceTimestamp + 1 hours) {
            // Trigger rebalance if needed
            lastRebalanceTimestamp = block.timestamp;
        }
    }
    
    /**
     * @dev Collect protocol fees
     */
    function collectProtocolFees() external onlyRole(FEE_MANAGER_ROLE) {
        require(accumulatedProtocolFees > 0, "UnifiedLiquidityPool: no fees to collect");
        
        uint256 amount = accumulatedProtocolFees;
        accumulatedProtocolFees = 0;
        
        emit FeesCollected(amount, feeRecipient, block.timestamp);
    }
    
    /**
     * @dev Set protocol fee rate
     */
    function setProtocolFeeRate(uint256 _protocolFeeRate) external onlyRole(ADMIN_ROLE) {
        require(_protocolFeeRate <= BASIS_POINTS, "UnifiedLiquidityPool: invalid fee rate");
        protocolFeeRate = _protocolFeeRate;
    }
    
    /**
     * @dev Set fee recipient
     */
    function setFeeRecipient(address _feeRecipient) external onlyRole(ADMIN_ROLE) {
        require(_feeRecipient != address(0), "UnifiedLiquidityPool: invalid recipient");
        feeRecipient = _feeRecipient;
    }
    
    /**
     * @dev Pause the contract
     */
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }
    
    /**
     * @dev Unpause the contract
     */
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }
    
    /**
     * @dev Emergency function to recover stuck tokens
     */
    function emergencyWithdraw(
        address token,
        uint256 amount,
        address to
    ) external onlyRole(ADMIN_ROLE) {
        IERC20(token).safeTransfer(to, amount);
    }
}
