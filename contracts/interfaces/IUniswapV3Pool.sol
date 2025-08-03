// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title IUniswapV3Pool
 * @dev Interface for Uniswap V3 Pool contract
 */
interface IUniswapV3Pool {
    /**
     * @notice The first of the two tokens of the pool, sorted by address
     * @return The token contract address
     */
    function token0() external view returns (address);

    /**
     * @notice The second of the two tokens of the pool, sorted by address
     * @return The token contract address
     */
    function token1() external view returns (address);

    /**
     * @notice The pool's fee in hundredths of a bip, i.e. 1e-6
     * @return The fee
     */
    function fee() external view returns (uint24);

    /**
     * @notice The pool tick spacing
     * @dev Ticks can only be used at multiples of this value, minimum of 1 and always positive
     * e.g.: a tickSpacing of 3 means ticks can be initialized every 3rd tick, i.e., ..., -6, -3, 0, 3, 6, ...
     * This value is an int24 to avoid casting even though it is always positive.
     * @return The tick spacing
     */
    function tickSpacing() external view returns (int24);

    /**
     * @notice The currently in range liquidity available to the pool
     * @dev This value has no relationship to the total liquidity across all ticks
     * @return The liquidity at the current price of the pool
     */
    function liquidity() external view returns (uint128);

    /**
     * @notice The current price of the pool as a sqrt(token1/token0) Q64.96 value
     * @dev The price is represented as a sqrt(price) because the price itself can overflow a uint256
     * @return sqrtPriceX96 The current price of the pool as a sqrt(price) Q64.96
     */
    function slot0()
        external
        view
        returns (
            uint160 sqrtPriceX96,
            int24 tick,
            uint16 observationIndex,
            uint16 observationCardinality,
            uint16 observationCardinalityNext,
            uint8 feeProtocol,
            bool unlocked
        );

    /**
     * @notice Look up information about a specific tick in the pool
     * @param tick The tick to look up
     * @return liquidityGross the total amount of position liquidity that uses the pool either as tick lower or
     * tick upper,
     * liquidityNet how much liquidity changes when the pool price crosses the tick,
     * feeGrowthOutside0X128 the fee growth on the other side of the tick from the current tick in token0,
     * feeGrowthOutside1X128 the fee growth on the other side of the tick from the current tick in token1,
     * tickCumulativeOutside the cumulative tick value on the other side of the tick from the current tick
     * secondsPerLiquidityOutsideX128 the seconds spent per liquidity on the other side of the tick from the current tick,
     * secondsOutside the seconds spent on the other side of the tick from the current tick,
     * initialized Set to true if the tick is initialized, i.e. liquidityGross is greater than 0, otherwise equal to false.
     * Outside values can only be used if the tick is initialized, i.e. if liquidityGross is greater than 0.
     * In addition, these values are only relative and must be used only in comparison to previous snapshots for
     * a specific position.
     */
    function ticks(int24 tick)
        external
        view
        returns (
            uint128 liquidityGross,
            int128 liquidityNet,
            uint256 feeGrowthOutside0X128,
            uint256 feeGrowthOutside1X128,
            int56 tickCumulativeOutside,
            uint160 secondsPerLiquidityOutsideX128,
            uint32 secondsOutside,
            bool initialized
        );

    /**
     * @notice Adds liquidity for the given recipient/tickLower/tickUpper position
     * @dev The caller of this method receives a callback in the form of IUniswapV3MintCallback#uniswapV3MintCallback
     * in which they must pay any token0 or token1 owed for the liquidity. The amount of token0/token1 due depends
     * on tickLower, tickUpper, the amount of liquidity, and the current price.
     * @param recipient The address for which the liquidity will be created
     * @param tickLower The lower tick of the position in which to add liquidity
     * @param tickUpper The upper tick of the position in which to add liquidity
     * @param amount The amount of liquidity to mint
     * @param data Any data that should be passed through to the callback
     * @return amount0 The amount of token0 that was paid to mint the given amount of liquidity. Matches the value in the callback
     * @return amount1 The amount of token1 that was paid to mint the given amount of liquidity. Matches the value in the callback
     */
    function mint(
        address recipient,
        int24 tickLower,
        int24 tickUpper,
        uint128 amount,
        bytes calldata data
    ) external returns (uint256 amount0, uint256 amount1);

    /**
     * @notice Burn liquidity from the sender and account tokens owed for the liquidity to the position
     * @dev Can be used to trigger a recalculation of fees owed to a position by calling with an amount of 0
     * @dev Fees must be collected separately via a call to #collect
     * @param tickLower The lower tick of the position for which to burn liquidity
     * @param tickUpper The upper tick of the position for which to burn liquidity
     * @param amount How much liquidity to burn
     * @return amount0 The amount of token0 sent to the recipient
     * @return amount1 The amount of token1 sent to the recipient
     */
    function burn(
        int24 tickLower,
        int24 tickUpper,
        uint128 amount
    ) external returns (uint256 amount0, uint256 amount1);

    /**
     * @notice Collect tokens owed to a position
     * @dev Does not recompute fees earned, which must be done either via mint or burn of any amount of liquidity.
     * Collect must be called by the position owner. To withdraw only token0 or only token1, amount0Requested or
     * amount1Requested may be set to zero. To withdraw all tokens owed, caller may pass any value greater than the
     * actual tokens owed, e.g. type(uint128).max. Tokens owed may be from accumulated swap fees or burned liquidity.
     * @param recipient The address which should receive the fees collected
     * @param tickLower The lower tick of the position for which to collect fees
     * @param tickUpper The upper tick of the position for which to collect fees
     * @param amount0Requested How much token0 should be withdrawn from the fees owed
     * @param amount1Requested How much token1 should be withdrawn from the fees owed
     * @return amount0 The amount of fees collected in token0
     * @return amount1 The amount of fees collected in token1
     */
    function collect(
        address recipient,
        int24 tickLower,
        int24 tickUpper,
        uint128 amount0Requested,
        uint128 amount1Requested
    ) external returns (uint128 amount0, uint128 amount1);
}
