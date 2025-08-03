// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "../interfaces/IOracle.sol";

/**
 * @title UnifiedAMM
 * @dev Advanced Automated Market Maker with multiple pool types and sophisticated features
 * @author CoreLiquid Protocol
 */
contract UnifiedAMM is AccessControl, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;
    using Math for uint256;
    
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant LIQUIDITY_PROVIDER_ROLE = keccak256("LIQUIDITY_PROVIDER_ROLE");
    bytes32 public constant TRADER_ROLE = keccak256("TRADER_ROLE");
    bytes32 public constant FEE_MANAGER_ROLE = keccak256("FEE_MANAGER_ROLE");
    
    uint256 public constant PRECISION = 1e18;
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant MIN_LIQUIDITY = 1000;
    uint256 public constant MAX_FEE = 1000; // 10%
    uint256 public constant DEFAULT_FEE = 30; // 0.3%
    uint256 public constant PRICE_IMPACT_THRESHOLD = 500; // 5%
    
    enum PoolType {
        ConstantProduct, // x * y = k
        StableSwap,      // Curve-like for stable assets
        WeightedPool,    // Balancer-like with custom weights
        ConcentratedLiquidity // Uniswap V3-like
    }
    
    struct Pool {
        address tokenA;
        address tokenB;
        uint256 reserveA;
        uint256 reserveB;
        uint256 totalLiquidity;
        uint256 feeRate; // in basis points
        PoolType poolType;
        uint256 weightA; // for weighted pools (basis points)
        uint256 weightB; // for weighted pools (basis points)
        uint256 amplificationParameter; // for stable swap pools
        bool isActive;
        uint256 createdAt;
        uint256 lastUpdate;
        uint256 cumulativePriceA;
        uint256 cumulativePriceB;
        uint256 totalVolume;
        uint256 totalFees;
    }
    
    struct LiquidityPosition {
        uint256 poolId;
        address provider;
        uint256 liquidity;
        uint256 tokenAAmount;
        uint256 tokenBAmount;
        uint256 timestamp;
        uint256 lastRewardClaim;
        uint256 accruedFees;
        bool isActive;
    }
    
    struct SwapParams {
        uint256 poolId;
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 amountOutMin;
        address to;
        uint256 deadline;
        bytes extraData;
    }
    
    struct PriceInfo {
        uint256 price; // tokenB per tokenA
        uint256 priceImpact;
        uint256 slippage;
        uint256 timestamp;
        bool isValid;
    }
    
    struct PoolStats {
        uint256 totalValueLocked;
        uint256 volume24h;
        uint256 fees24h;
        uint256 apr;
        uint256 utilization;
        uint256 priceVolatility;
        uint256 liquidityDepth;
    }
    
    // State variables
    mapping(uint256 => Pool) public pools;
    mapping(address => mapping(address => uint256)) public getPoolId;
    mapping(uint256 => mapping(address => uint256)) public liquidityBalances;
    mapping(address => uint256[]) public userPools;
    mapping(uint256 => LiquidityPosition[]) public poolPositions;
    mapping(address => LiquidityPosition[]) public userPositions;
    mapping(uint256 => PriceInfo) public poolPrices;
    mapping(address => bool) public supportedTokens;
    
    uint256 public nextPoolId = 1;
    uint256 public totalPools;
    uint256 public totalValueLocked;
    uint256 public protocolFeeRate = 10; // 0.1%
    address public feeRecipient;
    address public treasury;
    
    // External contracts
    IOracle public priceOracle;
    
    // Pool creation parameters
    uint256 public poolCreationFee = 0.1 ether;
    uint256 public minInitialLiquidity = 1000e18;
    bool public permissionlessPoolCreation = true;
    
    // Events
    event PoolCreated(
        uint256 indexed poolId,
        address indexed tokenA,
        address indexed tokenB,
        PoolType poolType,
        address creator
    );
    event LiquidityAdded(
        uint256 indexed poolId,
        address indexed provider,
        uint256 amountA,
        uint256 amountB,
        uint256 liquidity
    );
    event LiquidityRemoved(
        uint256 indexed poolId,
        address indexed provider,
        uint256 amountA,
        uint256 amountB,
        uint256 liquidity
    );
    event Swap(
        uint256 indexed poolId,
        address indexed trader,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        uint256 fee
    );
    event PriceUpdate(
        uint256 indexed poolId,
        uint256 price,
        uint256 priceImpact
    );
    event FeesCollected(
        uint256 indexed poolId,
        address indexed provider,
        uint256 amount
    );
    
    constructor(
        address _priceOracle,
        address _feeRecipient,
        address _treasury
    ) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(FEE_MANAGER_ROLE, msg.sender);
        
        priceOracle = IOracle(_priceOracle);
        feeRecipient = _feeRecipient;
        treasury = _treasury;
    }
    
    /**
     * @dev Create a new liquidity pool
     * @param tokenA First token address
     * @param tokenB Second token address
     * @param poolType Type of the pool
     * @param feeRate Fee rate in basis points
     * @param weightA Weight of token A (for weighted pools)
     * @param weightB Weight of token B (for weighted pools)
     * @param amplificationParameter Amplification parameter (for stable pools)
     * @return poolId The ID of the created pool
     */
    function createPool(
        address tokenA,
        address tokenB,
        PoolType poolType,
        uint256 feeRate,
        uint256 weightA,
        uint256 weightB,
        uint256 amplificationParameter
    ) external payable nonReentrant returns (uint256 poolId) {
        require(tokenA != tokenB, "Identical tokens");
        require(tokenA != address(0) && tokenB != address(0), "Zero address");
        require(feeRate <= MAX_FEE, "Fee too high");
        require(getPoolId[tokenA][tokenB] == 0, "Pool already exists");
        
        if (!permissionlessPoolCreation) {
            require(hasRole(ADMIN_ROLE, msg.sender), "Not authorized");
        }
        
        if (poolCreationFee > 0) {
            require(msg.value >= poolCreationFee, "Insufficient fee");
            payable(treasury).transfer(msg.value);
        }
        
        // Validate pool-specific parameters
        if (poolType == PoolType.WeightedPool) {
            require(weightA + weightB == BASIS_POINTS, "Invalid weights");
            require(weightA >= 200 && weightB >= 200, "Weight too low"); // Min 2%
        }
        
        if (poolType == PoolType.StableSwap) {
            require(amplificationParameter >= 1 && amplificationParameter <= 5000, "Invalid amplification");
        }
        
        // Order tokens
        if (tokenA > tokenB) {
            (tokenA, tokenB) = (tokenB, tokenA);
            (weightA, weightB) = (weightB, weightA);
        }
        
        poolId = nextPoolId++;
        
        pools[poolId] = Pool({
            tokenA: tokenA,
            tokenB: tokenB,
            reserveA: 0,
            reserveB: 0,
            totalLiquidity: 0,
            feeRate: feeRate,
            poolType: poolType,
            weightA: weightA,
            weightB: weightB,
            amplificationParameter: amplificationParameter,
            isActive: true,
            createdAt: block.timestamp,
            lastUpdate: block.timestamp,
            cumulativePriceA: 0,
            cumulativePriceB: 0,
            totalVolume: 0,
            totalFees: 0
        });
        
        getPoolId[tokenA][tokenB] = poolId;
        getPoolId[tokenB][tokenA] = poolId;
        totalPools++;
        
        emit PoolCreated(poolId, tokenA, tokenB, poolType, msg.sender);
    }
    
    /**
     * @dev Add liquidity to a pool
     * @param tokenA First token address
     * @param tokenB Second token address
     * @param amountA Amount of token A to add
     * @param amountB Amount of token B to add
     * @return liquidity The amount of liquidity tokens minted
     */
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountA,
        uint256 amountB
    ) external nonReentrant whenNotPaused returns (uint256 liquidity) {
        require(amountA > 0 && amountB > 0, "Insufficient amounts");
        
        uint256 poolId = getPoolId[tokenA][tokenB];
        require(poolId != 0, "Pool does not exist");
        
        Pool storage pool = pools[poolId];
        require(pool.isActive, "Pool not active");
        
        // Order tokens to match pool
        if (tokenA != pool.tokenA) {
            (tokenA, tokenB) = (tokenB, tokenA);
            (amountA, amountB) = (amountB, amountA);
        }
        
        // Calculate optimal amounts and liquidity
        (uint256 optimalAmountA, uint256 optimalAmountB, uint256 liquidityMinted) = 
            _calculateLiquidityAmounts(poolId, amountA, amountB);
        
        require(liquidityMinted >= MIN_LIQUIDITY, "Insufficient liquidity");
        
        // Transfer tokens from user
        IERC20(tokenA).safeTransferFrom(msg.sender, address(this), optimalAmountA);
        IERC20(tokenB).safeTransferFrom(msg.sender, address(this), optimalAmountB);
        
        // Update pool reserves
        pool.reserveA += optimalAmountA;
        pool.reserveB += optimalAmountB;
        pool.totalLiquidity += liquidityMinted;
        pool.lastUpdate = block.timestamp;
        
        // Update user liquidity balance
        liquidityBalances[poolId][msg.sender] += liquidityMinted;
        
        // Add to user pools if first time
        if (liquidityBalances[poolId][msg.sender] == liquidityMinted) {
            userPools[msg.sender].push(poolId);
        }
        
        // Create liquidity position
        _createLiquidityPosition(poolId, msg.sender, liquidityMinted, optimalAmountA, optimalAmountB);
        
        // Update price
        _updatePrice(poolId);
        
        emit LiquidityAdded(poolId, msg.sender, optimalAmountA, optimalAmountB, liquidityMinted);
        
        return liquidityMinted;
    }
    
    /**
     * @dev Remove liquidity from a pool
     * @param tokenA First token address
     * @param tokenB Second token address
     * @param liquidity Amount of liquidity to remove
     * @return amountA Amount of token A returned
     * @return amountB Amount of token B returned
     */
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity
    ) external nonReentrant returns (uint256 amountA, uint256 amountB) {
        require(liquidity > 0, "Insufficient liquidity");
        
        uint256 poolId = getPoolId[tokenA][tokenB];
        require(poolId != 0, "Pool does not exist");
        
        Pool storage pool = pools[poolId];
        require(liquidityBalances[poolId][msg.sender] >= liquidity, "Insufficient balance");
        
        // Calculate amounts to return
        amountA = liquidity.mulDiv(pool.reserveA, pool.totalLiquidity);
        amountB = liquidity.mulDiv(pool.reserveB, pool.totalLiquidity);
        
        require(amountA > 0 && amountB > 0, "Insufficient liquidity burned");
        
        // Update pool reserves
        pool.reserveA -= amountA;
        pool.reserveB -= amountB;
        pool.totalLiquidity -= liquidity;
        pool.lastUpdate = block.timestamp;
        
        // Update user liquidity balance
        liquidityBalances[poolId][msg.sender] -= liquidity;
        
        // Order tokens to match user request
        if (tokenA != pool.tokenA) {
            (amountA, amountB) = (amountB, amountA);
        }
        
        // Transfer tokens to user
        IERC20(pool.tokenA).safeTransfer(msg.sender, tokenA == pool.tokenA ? amountA : amountB);
        IERC20(pool.tokenB).safeTransfer(msg.sender, tokenB == pool.tokenB ? amountB : amountA);
        
        // Update liquidity position
        _updateLiquidityPosition(poolId, msg.sender, liquidity, false);
        
        // Update price
        _updatePrice(poolId);
        
        emit LiquidityRemoved(poolId, msg.sender, amountA, amountB, liquidity);
    }
    
    /**
     * @dev Swap exact tokens for tokens
     * @param amountIn Amount of input tokens
     * @param amountOutMin Minimum amount of output tokens
     * @param path Array of token addresses representing the swap path
     * @return amounts Array of amounts for each step in the path
     */
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path
    ) external nonReentrant whenNotPaused returns (uint256[] memory amounts) {
        require(path.length >= 2, "Invalid path");
        require(amountIn > 0, "Insufficient input amount");
        
        amounts = new uint256[](path.length);
        amounts[0] = amountIn;
        
        // Transfer input tokens from user
        IERC20(path[0]).safeTransferFrom(msg.sender, address(this), amountIn);
        
        // Execute swaps along the path
        for (uint256 i = 0; i < path.length - 1; i++) {
            uint256 poolId = getPoolId[path[i]][path[i + 1]];
            require(poolId != 0, "Pool does not exist");
            
            Pool storage pool = pools[poolId];
            require(pool.isActive, "Pool not active");
            
            // Calculate output amount
            amounts[i + 1] = _getAmountOut(poolId, amounts[i], path[i], path[i + 1]);
            
            // Execute swap
            _executeSwap(poolId, path[i], path[i + 1], amounts[i], amounts[i + 1]);
        }
        
        require(amounts[amounts.length - 1] >= amountOutMin, "Insufficient output amount");
        
        // Transfer output tokens to user
        IERC20(path[path.length - 1]).safeTransfer(msg.sender, amounts[amounts.length - 1]);
        
        return amounts;
    }
    
    /**
     * @dev Get amount out for a given input
     * @param amountIn Input amount
     * @param reserveIn Input token reserve
     * @param reserveOut Output token reserve
     * @return amountOut Output amount
     */
    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) public pure returns (uint256 amountOut) {
        require(amountIn > 0, "Insufficient input amount");
        require(reserveIn > 0 && reserveOut > 0, "Insufficient liquidity");
        
        // Constant product formula: x * y = k
        // amountOut = (amountIn * reserveOut) / (reserveIn + amountIn)
        uint256 amountInWithFee = amountIn * 997; // 0.3% fee
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * 1000 + amountInWithFee;
        amountOut = numerator / denominator;
    }
    
    /**
     * @dev Get amount out for a specific pool
     * @param poolId Pool ID
     * @param amountIn Input amount
     * @param tokenIn Input token address
     * @param tokenOut Output token address
     * @return amountOut Output amount
     */
    function getAmountOutForPool(
        uint256 poolId,
        uint256 amountIn,
        address tokenIn,
        address tokenOut
    ) external view returns (uint256 amountOut) {
        return _getAmountOut(poolId, amountIn, tokenIn, tokenOut);
    }
    
    /**
     * @dev Get pool information
     * @param poolId Pool ID
     * @return pool Pool struct
     */
    function getPool(uint256 poolId) external view returns (Pool memory pool) {
        return pools[poolId];
    }
    
    /**
     * @dev Get pool statistics
     * @param poolId Pool ID
     * @return stats Pool statistics
     */
    function getPoolStats(uint256 poolId) external view returns (PoolStats memory stats) {
        Pool storage pool = pools[poolId];
        
        uint256 priceA = priceOracle.getPrice(pool.tokenA);
        uint256 priceB = priceOracle.getPrice(pool.tokenB);
        
        uint256 tvl = (pool.reserveA * priceA + pool.reserveB * priceB) / PRECISION;
        
        return PoolStats({
            totalValueLocked: tvl,
            volume24h: _getVolume24h(poolId),
            fees24h: _getFees24h(poolId),
            apr: _calculateAPR(poolId),
            utilization: _calculateUtilization(poolId),
            priceVolatility: _calculatePriceVolatility(poolId),
            liquidityDepth: _calculateLiquidityDepth(poolId)
        });
    }
    
    /**
     * @dev Get user's liquidity positions
     * @param user User address
     * @return positions Array of liquidity positions
     */
    function getUserPositions(address user) external view returns (LiquidityPosition[] memory positions) {
        return userPositions[user];
    }
    
    /**
     * @dev Get user's pools
     * @param user User address
     * @return poolIds Array of pool IDs
     */
    function getUserPools(address user) external view returns (uint256[] memory poolIds) {
        return userPools[user];
    }
    
    // Internal functions
    function _calculateLiquidityAmounts(
        uint256 poolId,
        uint256 amountA,
        uint256 amountB
    ) internal view returns (uint256 optimalAmountA, uint256 optimalAmountB, uint256 liquidity) {
        Pool storage pool = pools[poolId];
        
        if (pool.totalLiquidity == 0) {
            // First liquidity provision
            optimalAmountA = amountA;
            optimalAmountB = amountB;
            liquidity = Math.sqrt(amountA * amountB) - MIN_LIQUIDITY;
        } else {
            // Subsequent liquidity provision
            uint256 amountBOptimal = amountA.mulDiv(pool.reserveB, pool.reserveA);
            
            if (amountBOptimal <= amountB) {
                optimalAmountA = amountA;
                optimalAmountB = amountBOptimal;
            } else {
                uint256 amountAOptimal = amountB.mulDiv(pool.reserveA, pool.reserveB);
                optimalAmountA = amountAOptimal;
                optimalAmountB = amountB;
            }
            
            liquidity = Math.min(
                optimalAmountA.mulDiv(pool.totalLiquidity, pool.reserveA),
                optimalAmountB.mulDiv(pool.totalLiquidity, pool.reserveB)
            );
        }
    }
    
    function _getAmountOut(
        uint256 poolId,
        uint256 amountIn,
        address tokenIn,
        address tokenOut
    ) internal view returns (uint256 amountOut) {
        Pool storage pool = pools[poolId];
        
        uint256 reserveIn;
        uint256 reserveOut;
        
        if (tokenIn == pool.tokenA) {
            reserveIn = pool.reserveA;
            reserveOut = pool.reserveB;
        } else {
            reserveIn = pool.reserveB;
            reserveOut = pool.reserveA;
        }
        
        if (pool.poolType == PoolType.ConstantProduct) {
            return _getAmountOutConstantProduct(amountIn, reserveIn, reserveOut, pool.feeRate);
        } else if (pool.poolType == PoolType.StableSwap) {
            return _getAmountOutStableSwap(amountIn, reserveIn, reserveOut, pool.amplificationParameter, pool.feeRate);
        } else if (pool.poolType == PoolType.WeightedPool) {
            uint256 weightIn = tokenIn == pool.tokenA ? pool.weightA : pool.weightB;
            uint256 weightOut = tokenOut == pool.tokenA ? pool.weightA : pool.weightB;
            return _getAmountOutWeighted(amountIn, reserveIn, reserveOut, weightIn, weightOut, pool.feeRate);
        }
        
        return 0;
    }
    
    function _getAmountOutConstantProduct(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut,
        uint256 feeRate
    ) internal pure returns (uint256 amountOut) {
        uint256 amountInWithFee = amountIn * (BASIS_POINTS - feeRate);
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * BASIS_POINTS + amountInWithFee;
        amountOut = numerator / denominator;
    }
    
    function _getAmountOutStableSwap(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut,
        uint256 amplificationParameter,
        uint256 feeRate
    ) internal pure returns (uint256 amountOut) {
        // Simplified stable swap calculation
        // In a real implementation, this would use the Curve formula
        uint256 amountInWithFee = amountIn * (BASIS_POINTS - feeRate) / BASIS_POINTS;
        
        // For stable assets, use a modified constant product with amplification
        uint256 totalLiquidity = reserveIn + reserveOut;
        uint256 product = reserveIn * reserveOut;
        uint256 amplifiedProduct = product * amplificationParameter;
        
        // Simplified calculation - in practice, this would be more complex
        amountOut = (amountInWithFee * reserveOut) / (reserveIn + amountInWithFee);
        
        // Apply amplification effect (reduces slippage for stable pairs)
        if (amplificationParameter > 1) {
            uint256 reduction = amountOut / (amplificationParameter * 2);
            amountOut = amountOut - reduction;
        }
    }
    
    function _getAmountOutWeighted(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut,
        uint256 weightIn,
        uint256 weightOut,
        uint256 feeRate
    ) internal pure returns (uint256 amountOut) {
        // Balancer-style weighted pool calculation
        uint256 amountInWithFee = amountIn * (BASIS_POINTS - feeRate) / BASIS_POINTS;
        
        // amountOut = reserveOut * (1 - (reserveIn / (reserveIn + amountIn))^(weightIn/weightOut))
        uint256 base = reserveIn * PRECISION / (reserveIn + amountInWithFee);
        uint256 exponent = weightIn * PRECISION / weightOut;
        
        // Simplified power calculation (in practice, use a proper power function)
        uint256 power = _pow(base, exponent);
        amountOut = reserveOut * (PRECISION - power) / PRECISION;
    }
    
    function _executeSwap(
        uint256 poolId,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut
    ) internal {
        Pool storage pool = pools[poolId];
        
        // Update reserves
        if (tokenIn == pool.tokenA) {
            pool.reserveA += amountIn;
            pool.reserveB -= amountOut;
        } else {
            pool.reserveB += amountIn;
            pool.reserveA -= amountOut;
        }
        
        // Calculate and collect fees
        uint256 fee = amountIn * pool.feeRate / BASIS_POINTS;
        uint256 protocolFee = fee * protocolFeeRate / BASIS_POINTS;
        
        pool.totalFees += fee;
        pool.totalVolume += amountIn;
        pool.lastUpdate = block.timestamp;
        
        // Update price
        _updatePrice(poolId);
        
        emit Swap(poolId, msg.sender, tokenIn, tokenOut, amountIn, amountOut, fee);
    }
    
    function _updatePrice(uint256 poolId) internal {
        Pool storage pool = pools[poolId];
        
        if (pool.reserveA > 0 && pool.reserveB > 0) {
            uint256 price = pool.reserveB.mulDiv(PRECISION, pool.reserveA);
            uint256 priceImpact = _calculatePriceImpact(poolId, price);
            
            poolPrices[poolId] = PriceInfo({
                price: price,
                priceImpact: priceImpact,
                slippage: 0, // Would be calculated based on recent trades
                timestamp: block.timestamp,
                isValid: true
            });
            
            emit PriceUpdate(poolId, price, priceImpact);
        }
    }
    
    function _calculatePriceImpact(uint256 poolId, uint256 currentPrice) internal view returns (uint256) {
        // Calculate price impact based on historical price
        // This is a simplified implementation
        return 0;
    }
    
    function _createLiquidityPosition(
        uint256 poolId,
        address provider,
        uint256 liquidity,
        uint256 amountA,
        uint256 amountB
    ) internal {
        LiquidityPosition memory position = LiquidityPosition({
            poolId: poolId,
            provider: provider,
            liquidity: liquidity,
            tokenAAmount: amountA,
            tokenBAmount: amountB,
            timestamp: block.timestamp,
            lastRewardClaim: block.timestamp,
            accruedFees: 0,
            isActive: true
        });
        
        poolPositions[poolId].push(position);
        userPositions[provider].push(position);
    }
    
    function _updateLiquidityPosition(
        uint256 poolId,
        address provider,
        uint256 liquidity,
        bool isAdd
    ) internal {
        // Update existing position or create new one
        // This is a simplified implementation
    }
    
    function _getVolume24h(uint256 poolId) internal view returns (uint256) {
        // Calculate 24h volume - simplified
        return pools[poolId].totalVolume;
    }
    
    function _getFees24h(uint256 poolId) internal view returns (uint256) {
        // Calculate 24h fees - simplified
        return pools[poolId].totalFees;
    }
    
    function _calculateAPR(uint256 poolId) internal view returns (uint256) {
        // Calculate APR based on fees and TVL - simplified
        Pool storage pool = pools[poolId];
        if (pool.totalLiquidity == 0) return 0;
        
        uint256 dailyFees = _getFees24h(poolId);
        uint256 yearlyFees = dailyFees * 365;
        
        // Get TVL in USD
        uint256 priceA = priceOracle.getPrice(pool.tokenA);
        uint256 priceB = priceOracle.getPrice(pool.tokenB);
        uint256 tvl = (pool.reserveA * priceA + pool.reserveB * priceB) / PRECISION;
        
        if (tvl == 0) return 0;
        
        return yearlyFees.mulDiv(100 * PRECISION, tvl); // APR in percentage
    }
    
    function _calculateUtilization(uint256 poolId) internal view returns (uint256) {
        // Calculate pool utilization - simplified
        return 50e16; // 50%
    }
    
    function _calculatePriceVolatility(uint256 poolId) internal view returns (uint256) {
        // Calculate price volatility - simplified
        return 10e16; // 10%
    }
    
    function _calculateLiquidityDepth(uint256 poolId) internal view returns (uint256) {
        // Calculate liquidity depth - simplified
        Pool storage pool = pools[poolId];
        return Math.min(pool.reserveA, pool.reserveB);
    }
    
    function _pow(uint256 base, uint256 exponent) internal pure returns (uint256) {
        // Simplified power function - in practice, use a proper implementation
        if (exponent == 0) return PRECISION;
        if (exponent == PRECISION) return base;
        
        // Linear approximation for small exponents
        return base + (exponent - PRECISION) * base / PRECISION;
    }
    
    // Admin functions
    function setPoolCreationFee(uint256 _fee) external onlyRole(ADMIN_ROLE) {
        poolCreationFee = _fee;
    }
    
    function setProtocolFeeRate(uint256 _feeRate) external onlyRole(FEE_MANAGER_ROLE) {
        require(_feeRate <= 1000, "Fee too high"); // Max 10%
        protocolFeeRate = _feeRate;
    }
    
    function setPermissionlessPoolCreation(bool _enabled) external onlyRole(ADMIN_ROLE) {
        permissionlessPoolCreation = _enabled;
    }
    
    function togglePoolStatus(uint256 poolId, bool isActive) external onlyRole(ADMIN_ROLE) {
        pools[poolId].isActive = isActive;
    }
    
    function setPriceOracle(address _priceOracle) external onlyRole(ADMIN_ROLE) {
        priceOracle = IOracle(_priceOracle);
    }
    
    function setFeeRecipient(address _feeRecipient) external onlyRole(ADMIN_ROLE) {
        feeRecipient = _feeRecipient;
    }
    
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }
    
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }
    
    // Emergency functions
    function emergencyWithdraw(address token, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        IERC20(token).safeTransfer(msg.sender, amount);
    }
    
    receive() external payable {
        // Accept ETH for pool creation fees
    }
}
