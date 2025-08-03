// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title DynamicFeeModel
 * @notice Calculates a one-time fixed mark-up (in basis points) for asset-backed credit sales.
 *         Unlike traditional interest models, the mark-up is immutable once the order is opened—
 *         there is *no* per-block accrual loop.
 *
 * Basis-points math (1e4 = 100%). Utilisation math uses 1e18 precision (PRECISION).
 */
contract DynamicFeeModel is AccessControl {
    using Math for uint256;

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant FEE_MANAGER_ROLE = keccak256("FEE_MANAGER_ROLE");

    uint256 public constant PRECISION = 1e18;          // Utilisation precision
    uint256 public constant BASIS_POINTS = 10_000;      // 100 %

    // Hard safety‐limit for mark-up → 50 % (editable via admin fn)
    uint256 public maxMarkupBps = 5_000;

    /*//////////////////////////////////////////////////////////////
                               FEE-CURVE MODEL
    //////////////////////////////////////////////////////////////*/

    struct FeeCurve {
        uint256 baseSpreadBps;      // Minimum mark-up applied (e.g. 50 = 0.5 %)
        uint256 slopeBps;           // Additional BPS applied per 1 % util deviation
        uint256 targetUtil;         // Target utilisation ratio (1e18 scale)
        bool    isActive;
    }

    // asset => curve params
    mapping(address => FeeCurve) public feeCurves;
    mapping(address => bool) public supportedAssets;
    address[] public assetList;

    /*//////////////////////////////////////////////////////////////
                                    EVENTS
    //////////////////////////////////////////////////////////////*/

    event FeeCurveInitialised(address indexed asset, uint256 baseSpreadBps, uint256 slopeBps, uint256 targetUtil);
    event FeeCurveUpdated(address indexed asset, uint256 baseSpreadBps, uint256 slopeBps, uint256 targetUtil);
    event MaxMarkupUpdated(uint256 newMax);

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(FEE_MANAGER_ROLE, msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                          ADMIN / MANAGER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Set or update an asset fee curve.
     */
    function setFeeCurve(
        address asset,
        uint256 baseSpreadBps,
        uint256 slopeBps,
        uint256 targetUtil
    ) external onlyRole(FEE_MANAGER_ROLE) {
        require(asset != address(0), "Invalid asset");
        require(baseSpreadBps <= maxMarkupBps, "Base too high");
        require(targetUtil <= PRECISION, "Invalid target util");

        if (!supportedAssets[asset]) {
            supportedAssets[asset] = true;
            assetList.push(asset);
        }

        feeCurves[asset] = FeeCurve({
            baseSpreadBps: baseSpreadBps,
            slopeBps: slopeBps,
            targetUtil: targetUtil,
            isActive: true
        });

        emit FeeCurveInitialised(asset, baseSpreadBps, slopeBps, targetUtil);
    }

    /**
     * @notice Emergency pause a curve.
     */
    function pauseCurve(address asset) external onlyRole(ADMIN_ROLE) {
        feeCurves[asset].isActive = false;
    }

    function resumeCurve(address asset) external onlyRole(ADMIN_ROLE) {
        feeCurves[asset].isActive = true;
    }

    /**
     * @notice Update global hard cap for mark-up.
     */
    function updateMaxMarkup(uint256 newCapBps) external onlyRole(ADMIN_ROLE) {
        require(newCapBps <= BASIS_POINTS, ">100 %");
        maxMarkupBps = newCapBps;
        emit MaxMarkupUpdated(newCapBps);
    }

    /*//////////////////////////////////////////////////////////////
                         PUBLIC VIEW — FEE CALCULATION
    //////////////////////////////////////////////////////////////*/

    /**
     * @param asset            Asset address.
     * @param totalSupply      Total liquidity in pool.
     * @param totalBorrow      Total outstanding credit (principal).
     * @param totalReserves    Protocol reserves.
     * @return markupBps       Fixed mark-up quoted in basis points.
     */
    function getMarkupBps(
        address asset,
        uint256 totalSupply,
        uint256 totalBorrow,
        uint256 totalReserves
    ) external view returns (uint256 markupBps) {
        FeeCurve memory curve = feeCurves[asset];
        if (!curve.isActive) return 0;

        uint256 util = _calculateUtilisation(totalSupply, totalBorrow, totalReserves);

        if (util <= curve.targetUtil) {
            // Below target → minimal spread
            markupBps = curve.baseSpreadBps;
        } else {
            // Linear increase: base + (util - target) * slope per 1e18 util
            uint256 delta = util - curve.targetUtil; // 1e18 scale
            // Convert delta util (1e18) to percentage (bps denominator = 1e4)
            uint256 deltaPct = (delta * 100) / PRECISION; // Now in % (0-100)
            markupBps = curve.baseSpreadBps + ((deltaPct * curve.slopeBps) / 100);
        }

        if (markupBps > maxMarkupBps) markupBps = maxMarkupBps;
    }

    /**
     * @dev Convenience helper returning the absolute markup amount.
     */
    function quoteMarkupAmount(
        address asset,
        uint256 notional,
        uint256 totalSupply,
        uint256 totalBorrow,
        uint256 totalReserves
    ) external view returns (uint256) {
        uint256 bps = this.getMarkupBps(asset, totalSupply, totalBorrow, totalReserves);
        return (notional * bps) / BASIS_POINTS;
    }

    /*//////////////////////////////////////////////////////////////
                               INTERNAL MATH
    //////////////////////////////////////////////////////////////*/

    function _calculateUtilisation(
        uint256 totalSupply,
        uint256 totalBorrow,
        uint256 totalReserves
    ) internal pure returns (uint256) {
        if (totalSupply == 0) return 0;
        uint256 available = totalSupply - totalBorrow - totalReserves;
        if (available == 0) return PRECISION;
        return (totalBorrow * PRECISION) / (totalBorrow + available);
    }

    /*//////////////////////////////////////////////////////////////
                           VIEW HELPERS (FRONTEND / SDK)
    //////////////////////////////////////////////////////////////*/

    function getSupportedAssets() external view returns (address[] memory) {
        return assetList;
    }

    function getFeeCurve(address asset) external view returns (FeeCurve memory) {
        return feeCurves[asset];
    }
}