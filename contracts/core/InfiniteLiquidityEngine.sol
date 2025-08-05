// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "../interfaces/ipriceoracle.sol";

/**
 * @title InfiniteLiquidityEngine
 * @dev Advanced liquidity engine providing infinite liquidity through algorithmic market making
 */
contract InfiniteLiquidityEngine is Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;
    using Math for uint256;

    struct LiquidityPool {
        address tokenA;
        address tokenB;
        uint256 reserveA;
        uint256 reserveB;
        uint256 totalSupply;
        uint256 fee; // Fee in basis points
        uint256 amplificationFactor; // For stable swaps
        bool isStable; // Stable or volatile pool
        bool isActive;
        uint256 lastUpdate;
    }

    struct VirtualLiquidity {
        uint256 virtualReserveA;
        uint256 virtualReserveB;
        uint256 amplificationFactor;
        uint256 concentrationFactor;
        bool isEnabled;
    }

    struct SwapParams {
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 minAmountOut;
        address to;
        uint256 deadline;
        bool useVirtualLiquidity;
    }

    struct LiquidityPosition {
        uint256 liquidity;
        uint256 token0Owed;
        uint256 token1Owed;
        uint256 feeGrowthInside0LastX128;
        uint256 feeGrowthInside1LastX128;
        uint256 tokensOwed0;
        uint256 tokensOwed1;
        uint256 lastUpdate;
    }

    struct ConcentratedLiquidity {
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidity;
        uint256 feeGrowthInside0LastX128;
        uint256 feeGrowthInside1LastX128;
        uint128 tokensOwed0;
        uint128 tokensOwed1;
    }

    struct TickInfo {
        uint128 liquidityGross;
        int128 liquidityNet;
        uint256 feeGrowthOutside0X128;
        uint256 feeGrowthOutside1X128;
        int56 tickCumulativeOutside;
        uint160 secondsPerLiquidityOutsideX128;
        uint32 secondsOutside;
        bool initialized;
    }

    mapping(bytes32 => LiquidityPool) public liquidityPools;
    mapping(bytes32 => VirtualLiquidity) public virtualLiquidity;
    mapping(address => mapping(bytes32 => LiquidityPosition)) public positions;
    mapping(bytes32 => mapping(int24 => TickInfo)) public ticks;
    mapping(address => bool) public authorizedRouters;
    mapping(bytes32 => uint256) public poolFees;
    mapping(bytes32 => bool) public poolExists;
    
    address public priceOracle;
    address public feeCollector;
    
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant MAX_FEE = 1000; // 10% max fee
    uint256 public constant MIN_LIQUIDITY = 1000;
    uint256 public constant VIRTUAL_LIQUIDITY_MULTIPLIER = 1000;
    
    uint256 public defaultFee = 30; // 0.3%
    uint256 public protocolFeeShare = 1000; // 10%
    uint256 public maxSlippage = 500; // 5%
    
    bool public virtualLiquidityEnabled = true;
    bool public concentratedLiquidityEnabled = true;
    
    event PoolCreated(
        bytes32 indexed poolId,
        address indexed tokenA,
        address indexed tokenB,
        uint256 fee,
        bool isStable
    );
    
    event LiquidityAdded(
        bytes32 indexed poolId,
        address indexed provider,
        uint256 amountA,
        uint256 amountB,
        uint256 liquidity
    );
    
    event LiquidityRemoved(
        bytes32 indexed poolId,
        address indexed provider,
        uint256 amountA,
        uint256 amountB,
        uint256 liquidity
    );
    
    event Swap(
        bytes32 indexed poolId,
        address indexed user,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut
    );
    
    event VirtualLiquidityUpdated(
        bytes32 indexed poolId,
        uint256 virtualReserveA,
        uint256 virtualReserveB
    );
    
    event FeesCollected(
        bytes32 indexed poolId,
        address indexed collector,
        uint256 amount0,
        uint256 amount1
    );

    modifier onlyAuthorizedRouter() {
        require(authorizedRouters[msg.sender] || msg.sender == owner(), "Not authorized router");
        _;
    }

    modifier poolActive(bytes32 poolId) {
        require(liquidityPools[poolId].isActive, "Pool not active");
        _;
    }

    modifier validDeadline(uint256 deadline) {
        require(block.timestamp <= deadline, "Transaction expired");
        _;
    }

    constructor(
        address _priceOracle,
        address _feeCollector
    ) Ownable(msg.sender) {
        require(_priceOracle != address(0), "Invalid price oracle");
        require(_feeCollector != address(0), "Invalid fee collector");
        
        priceOracle = _priceOracle;
        feeCollector = _feeCollector;
    }

    /**
     * @dev Create a new liquidity pool
     * @param tokenA First token address
     * @param tokenB Second token address
     * @param fee Pool fee in basis points
     * @param isStable Whether this is a stable pool
     * @param amplificationFactor Amplification factor for stable pools
     * @return poolId Pool identifier
     */
    function createPool(
        address tokenA,
        address tokenB,
        uint256 fee,
        bool isStable,
        uint256 amplificationFactor
    ) external onlyOwner returns (bytes32 poolId) {
        require(tokenA != tokenB, "Identical tokens");
        require(tokenA != address(0) && tokenB != address(0), "Zero address");
        require(fee <= MAX_FEE, "Fee too high");
        
        // Sort tokens
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        
        poolId = keccak256(abi.encodePacked(token0, token1, fee, isStable));
        require(!poolExists[poolId], "Pool already exists");
        
        liquidityPools[poolId] = LiquidityPool({
            tokenA: token0,
            tokenB: token1,
            reserveA: 0,
            reserveB: 0,
            totalSupply: 0,
            fee: fee,
            amplificationFactor: amplificationFactor,
            isStable: isStable,
            isActive: true,
            lastUpdate: block.timestamp
        });
        
        poolExists[poolId] = true;
        
        // Initialize virtual liquidity if enabled
        if (virtualLiquidityEnabled) {
            _initializeVirtualLiquidity(poolId, token0, token1);
        }
        
        emit PoolCreated(poolId, token0, token1, fee, isStable);
    }

    /**
     * @dev Add liquidity to a pool
     * @param poolId Pool identifier
     * @param amountADesired Desired amount of tokenA
     * @param amountBDesired Desired amount of tokenB
     * @param amountAMin Minimum amount of tokenA
     * @param amountBMin Minimum amount of tokenB
     * @param to Recipient of liquidity tokens
     * @param deadline Transaction deadline
     * @return amountA Actual amount of tokenA added
     * @return amountB Actual amount of tokenB added
     * @return liquidity Liquidity tokens minted
     */
    function addLiquidity(
        bytes32 poolId,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external 
        nonReentrant 
        whenNotPaused 
        poolActive(poolId)
        validDeadline(deadline)
        returns (uint256 amountA, uint256 amountB, uint256 liquidity) 
    {
        require(to != address(0), "Invalid recipient");
        
        LiquidityPool storage pool = liquidityPools[poolId];
        
        // Calculate optimal amounts
        (amountA, amountB) = _calculateOptimalAmounts(
            pool,
            amountADesired,
            amountBDesired,
            amountAMin,
            amountBMin
        );
        
        // Transfer tokens from user
        IERC20(pool.tokenA).safeTransferFrom(msg.sender, address(this), amountA);
        IERC20(pool.tokenB).safeTransferFrom(msg.sender, address(this), amountB);
        
        // Calculate liquidity to mint
        if (pool.totalSupply == 0) {
            liquidity = Math.sqrt(amountA * amountB) - MIN_LIQUIDITY;
            // Lock minimum liquidity
            pool.totalSupply = MIN_LIQUIDITY;
        } else {
            liquidity = Math.min(
                amountA * pool.totalSupply / pool.reserveA,
                amountB * pool.totalSupply / pool.reserveB
            );
        }
        
        require(liquidity > 0, "Insufficient liquidity minted");
        
        // Update pool reserves
        pool.reserveA += amountA;
        pool.reserveB += amountB;
        pool.totalSupply += liquidity;
        pool.lastUpdate = block.timestamp;
        
        // Update user position
        positions[to][poolId].liquidity += liquidity;
        positions[to][poolId].lastUpdate = block.timestamp;
        
        // Update virtual liquidity
        if (virtualLiquidityEnabled) {
            _updateVirtualLiquidity(poolId);
        }
        
        emit LiquidityAdded(poolId, to, amountA, amountB, liquidity);
    }

    /**
     * @dev Remove liquidity from a pool
     * @param poolId Pool identifier
     * @param liquidity Amount of liquidity to remove
     * @param amountAMin Minimum amount of tokenA to receive
     * @param amountBMin Minimum amount of tokenB to receive
     * @param to Recipient of tokens
     * @param deadline Transaction deadline
     * @return amountA Amount of tokenA received
     * @return amountB Amount of tokenB received
     */
    function removeLiquidity(
        bytes32 poolId,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external 
        nonReentrant 
        whenNotPaused 
        poolActive(poolId)
        validDeadline(deadline)
        returns (uint256 amountA, uint256 amountB) 
    {
        require(to != address(0), "Invalid recipient");
        require(liquidity > 0, "Invalid liquidity amount");
        
        LiquidityPool storage pool = liquidityPools[poolId];
        LiquidityPosition storage position = positions[msg.sender][poolId];
        
        require(position.liquidity >= liquidity, "Insufficient liquidity");
        
        // Calculate amounts to return
        amountA = liquidity * pool.reserveA / pool.totalSupply;
        amountB = liquidity * pool.reserveB / pool.totalSupply;
        
        require(amountA >= amountAMin, "Insufficient tokenA amount");
        require(amountB >= amountBMin, "Insufficient tokenB amount");
        
        // Update pool state
        pool.reserveA -= amountA;
        pool.reserveB -= amountB;
        pool.totalSupply -= liquidity;
        pool.lastUpdate = block.timestamp;
        
        // Update user position
        position.liquidity -= liquidity;
        position.lastUpdate = block.timestamp;
        
        // Transfer tokens to user
        IERC20(pool.tokenA).safeTransfer(to, amountA);
        IERC20(pool.tokenB).safeTransfer(to, amountB);
        
        // Update virtual liquidity
        if (virtualLiquidityEnabled) {
            _updateVirtualLiquidity(poolId);
        }
        
        emit LiquidityRemoved(poolId, msg.sender, amountA, amountB, liquidity);
    }

    /**
     * @dev Swap tokens with infinite liquidity support
     * @param params Swap parameters
     * @return amountOut Amount of tokens received
     */
    function swapWithInfiniteLiquidity(
        SwapParams calldata params
    ) external 
        nonReentrant 
        whenNotPaused 
        validDeadline(params.deadline)
        returns (uint256 amountOut) 
    {
        require(params.amountIn > 0, "Invalid input amount");
        require(params.to != address(0), "Invalid recipient");
        
        bytes32 poolId = _getPoolId(params.tokenIn, params.tokenOut);
        require(poolExists[poolId], "Pool does not exist");
        
        LiquidityPool storage pool = liquidityPools[poolId];
        require(pool.isActive, "Pool not active");
        
        // Calculate output amount
        if (params.useVirtualLiquidity && virtualLiquidityEnabled) {
            amountOut = _swapWithVirtualLiquidity(poolId, params);
        } else {
            amountOut = _swapWithRegularLiquidity(poolId, params);
        }
        
        require(amountOut >= params.minAmountOut, "Insufficient output amount");
        
        // Execute swap
        IERC20(params.tokenIn).safeTransferFrom(msg.sender, address(this), params.amountIn);
        IERC20(params.tokenOut).safeTransfer(params.to, amountOut);
        
        // Update pool state
        _updatePoolAfterSwap(poolId, params.tokenIn, params.tokenOut, params.amountIn, amountOut);
        
        emit Swap(poolId, msg.sender, params.tokenIn, params.tokenOut, params.amountIn, amountOut);
    }

    /**
     * @dev Get quote for swap
     * @param tokenIn Input token
     * @param tokenOut Output token
     * @param amountIn Input amount
     * @param useVirtualLiquidity Whether to use virtual liquidity
     * @return amountOut Expected output amount
     */
    function getQuote(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        bool useVirtualLiquidity
    ) external view returns (uint256 amountOut) {
        bytes32 poolId = _getPoolId(tokenIn, tokenOut);
        require(poolExists[poolId], "Pool does not exist");
        
        if (useVirtualLiquidity && virtualLiquidityEnabled) {
            amountOut = _getVirtualLiquidityQuote(poolId, tokenIn, tokenOut, amountIn);
        } else {
            amountOut = _getRegularQuote(poolId, tokenIn, tokenOut, amountIn);
        }
    }

    /**
     * @dev Initialize virtual liquidity for a pool
     * @param poolId Pool identifier
     * @param tokenA First token
     * @param tokenB Second token
     */
    function _initializeVirtualLiquidity(
        bytes32 poolId,
        address tokenA,
        address tokenB
    ) internal {
        // Get token prices from oracle
        (uint256 priceA,) = IPriceOracle(priceOracle).getPrice(tokenA);
        (uint256 priceB,) = IPriceOracle(priceOracle).getPrice(tokenB);
        
        // Calculate virtual reserves based on prices
        uint256 virtualReserveA = 1000000 * 1e18; // 1M tokens
        uint256 virtualReserveB = virtualReserveA * priceA / priceB;
        
        virtualLiquidity[poolId] = VirtualLiquidity({
            virtualReserveA: virtualReserveA,
            virtualReserveB: virtualReserveB,
            amplificationFactor: 100,
            concentrationFactor: 1000,
            isEnabled: true
        });
        
        emit VirtualLiquidityUpdated(poolId, virtualReserveA, virtualReserveB);
    }

    /**
     * @dev Update virtual liquidity based on real reserves
     * @param poolId Pool identifier
     */
    function _updateVirtualLiquidity(bytes32 poolId) internal {
        LiquidityPool storage pool = liquidityPools[poolId];
        VirtualLiquidity storage vLiquidity = virtualLiquidity[poolId];
        
        if (!vLiquidity.isEnabled) return;
        
        // Adjust virtual reserves based on real reserves
        uint256 multiplier = VIRTUAL_LIQUIDITY_MULTIPLIER;
        vLiquidity.virtualReserveA = pool.reserveA * multiplier;
        vLiquidity.virtualReserveB = pool.reserveB * multiplier;
        
        emit VirtualLiquidityUpdated(poolId, vLiquidity.virtualReserveA, vLiquidity.virtualReserveB);
    }

    /**
     * @dev Calculate optimal amounts for liquidity provision
     * @param pool Pool data
     * @param amountADesired Desired amount A
     * @param amountBDesired Desired amount B
     * @param amountAMin Minimum amount A
     * @param amountBMin Minimum amount B
     * @return amountA Optimal amount A
     * @return amountB Optimal amount B
     */
    function _calculateOptimalAmounts(
        LiquidityPool storage pool,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    ) internal view returns (uint256 amountA, uint256 amountB) {
        if (pool.reserveA == 0 && pool.reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint256 amountBOptimal = amountADesired * pool.reserveB / pool.reserveA;
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, "Insufficient B amount");
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint256 amountAOptimal = amountBDesired * pool.reserveA / pool.reserveB;
                require(amountAOptimal <= amountADesired && amountAOptimal >= amountAMin, "Insufficient A amount");
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }

    /**
     * @dev Swap with virtual liquidity
     * @param poolId Pool identifier
     * @param params Swap parameters
     * @return amountOut Output amount
     */
    function _swapWithVirtualLiquidity(
        bytes32 poolId,
        SwapParams memory params
    ) internal view returns (uint256 amountOut) {
        VirtualLiquidity storage vLiquidity = virtualLiquidity[poolId];
        LiquidityPool storage pool = liquidityPools[poolId];
        
        // Use virtual reserves for calculation
        uint256 reserveIn = params.tokenIn == pool.tokenA ? 
            vLiquidity.virtualReserveA : vLiquidity.virtualReserveB;
        uint256 reserveOut = params.tokenIn == pool.tokenA ? 
            vLiquidity.virtualReserveB : vLiquidity.virtualReserveA;
        
        // Apply fee
        uint256 amountInWithFee = params.amountIn * (BASIS_POINTS - pool.fee) / BASIS_POINTS;
        
        // Calculate output using constant product formula with amplification
        if (pool.isStable) {
            amountOut = _getStableSwapOutput(reserveIn, reserveOut, amountInWithFee, pool.amplificationFactor);
        } else {
            amountOut = amountInWithFee * reserveOut / (reserveIn + amountInWithFee);
        }
    }

    /**
     * @dev Swap with regular liquidity
     * @param poolId Pool identifier
     * @param params Swap parameters
     * @return amountOut Output amount
     */
    function _swapWithRegularLiquidity(
        bytes32 poolId,
        SwapParams memory params
    ) internal view returns (uint256 amountOut) {
        LiquidityPool storage pool = liquidityPools[poolId];
        
        uint256 reserveIn = params.tokenIn == pool.tokenA ? pool.reserveA : pool.reserveB;
        uint256 reserveOut = params.tokenIn == pool.tokenA ? pool.reserveB : pool.reserveA;
        
        require(reserveIn > 0 && reserveOut > 0, "Insufficient liquidity");
        
        // Apply fee
        uint256 amountInWithFee = params.amountIn * (BASIS_POINTS - pool.fee) / BASIS_POINTS;
        
        // Calculate output
        if (pool.isStable) {
            amountOut = _getStableSwapOutput(reserveIn, reserveOut, amountInWithFee, pool.amplificationFactor);
        } else {
            amountOut = amountInWithFee * reserveOut / (reserveIn + amountInWithFee);
        }
    }

    /**
     * @dev Get virtual liquidity quote
     * @param poolId Pool identifier
     * @param tokenIn Input token
     * @param tokenOut Output token
     * @param amountIn Input amount
     * @return amountOut Expected output
     */
    function _getVirtualLiquidityQuote(
        bytes32 poolId,
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) internal view returns (uint256 amountOut) {
        SwapParams memory params = SwapParams({
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            amountIn: amountIn,
            minAmountOut: 0,
            to: address(0),
            deadline: block.timestamp,
            useVirtualLiquidity: true
        });
        
        return _swapWithVirtualLiquidity(poolId, params);
    }

    /**
     * @dev Get regular quote
     * @param poolId Pool identifier
     * @param tokenIn Input token
     * @param tokenOut Output token
     * @param amountIn Input amount
     * @return amountOut Expected output
     */
    function _getRegularQuote(
        bytes32 poolId,
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) internal view returns (uint256 amountOut) {
        SwapParams memory params = SwapParams({
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            amountIn: amountIn,
            minAmountOut: 0,
            to: address(0),
            deadline: block.timestamp,
            useVirtualLiquidity: false
        });
        
        return _swapWithRegularLiquidity(poolId, params);
    }

    /**
     * @dev Calculate stable swap output
     * @param reserveIn Input reserve
     * @param reserveOut Output reserve
     * @param amountIn Input amount
     * @param amplificationFactor Amplification factor
     * @return amountOut Output amount
     */
    function _getStableSwapOutput(
        uint256 reserveIn,
        uint256 reserveOut,
        uint256 amountIn,
        uint256 amplificationFactor
    ) internal pure returns (uint256 amountOut) {
        // Simplified stable swap calculation
        // In practice, would use more sophisticated curve math
        uint256 totalReserves = reserveIn + reserveOut;
        uint256 product = reserveIn * reserveOut;
        
        // Apply amplification
        uint256 amplifiedProduct = product * amplificationFactor / 100;
        uint256 newReserveIn = reserveIn + amountIn;
        
        // Calculate new output reserve
        uint256 newReserveOut = amplifiedProduct / newReserveIn;
        amountOut = reserveOut - newReserveOut;
        
        // Ensure output doesn't exceed available reserves
        if (amountOut > reserveOut) {
            amountOut = reserveOut * 99 / 100; // Leave 1% buffer
        }
    }

    /**
     * @dev Update pool state after swap
     * @param poolId Pool identifier
     * @param tokenIn Input token
     * @param tokenOut Output token
     * @param amountIn Input amount
     * @param amountOut Output amount
     */
    function _updatePoolAfterSwap(
        bytes32 poolId,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut
    ) internal {
        LiquidityPool storage pool = liquidityPools[poolId];
        
        if (tokenIn == pool.tokenA) {
            pool.reserveA += amountIn;
            pool.reserveB -= amountOut;
        } else {
            pool.reserveB += amountIn;
            pool.reserveA -= amountOut;
        }
        
        pool.lastUpdate = block.timestamp;
        
        // Update virtual liquidity
        if (virtualLiquidityEnabled) {
            _updateVirtualLiquidity(poolId);
        }
    }

    /**
     * @dev Get pool ID for token pair
     * @param tokenA First token
     * @param tokenB Second token
     * @return poolId Pool identifier
     */
    function _getPoolId(address tokenA, address tokenB) internal view returns (bytes32 poolId) {
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        poolId = keccak256(abi.encodePacked(token0, token1, defaultFee, false));
    }

    /**
     * @dev Set authorized router status
     * @param router Router address
     * @param authorized Authorization status
     */
    function setAuthorizedRouter(address router, bool authorized) external onlyOwner {
        authorizedRouters[router] = authorized;
    }

    /**
     * @dev Set price oracle
     * @param newPriceOracle New price oracle address
     */
    function setPriceOracle(address newPriceOracle) external onlyOwner {
        require(newPriceOracle != address(0), "Invalid price oracle");
        priceOracle = newPriceOracle;
    }

    /**
     * @dev Set fee collector
     * @param newFeeCollector New fee collector address
     */
    function setFeeCollector(address newFeeCollector) external onlyOwner {
        require(newFeeCollector != address(0), "Invalid fee collector");
        feeCollector = newFeeCollector;
    }

    /**
     * @dev Set default fee
     * @param newDefaultFee New default fee
     */
    function setDefaultFee(uint256 newDefaultFee) external onlyOwner {
        require(newDefaultFee <= MAX_FEE, "Fee too high");
        defaultFee = newDefaultFee;
    }

    /**
     * @dev Toggle virtual liquidity
     * @param enabled Virtual liquidity enabled status
     */
    function setVirtualLiquidityEnabled(bool enabled) external onlyOwner {
        virtualLiquidityEnabled = enabled;
    }

    /**
     * @dev Toggle concentrated liquidity
     * @param enabled Concentrated liquidity enabled status
     */
    function setConcentratedLiquidityEnabled(bool enabled) external onlyOwner {
        concentratedLiquidityEnabled = enabled;
    }

    /**
     * @dev Get pool information
     * @param poolId Pool identifier
     * @return pool Pool data
     */
    function getPool(bytes32 poolId) external view returns (LiquidityPool memory pool) {
        return liquidityPools[poolId];
    }

    /**
     * @dev Get virtual liquidity information
     * @param poolId Pool identifier
     * @return vLiquidity Virtual liquidity data
     */
    function getVirtualLiquidity(bytes32 poolId) external view returns (VirtualLiquidity memory vLiquidity) {
        return virtualLiquidity[poolId];
    }

    /**
     * @dev Get user position
     * @param user User address
     * @param poolId Pool identifier
     * @return position User position data
     */
    function getPosition(address user, bytes32 poolId) external view returns (LiquidityPosition memory position) {
        return positions[user][poolId];
    }

    /**
     * @dev Pause contract
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev Unpause contract
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @dev Emergency token recovery
     * @param token Token to recover
     * @param amount Amount to recover
     */
    function emergencyRecovery(address token, uint256 amount) external onlyOwner {
        IERC20(token).safeTransfer(owner(), amount);
    }
}