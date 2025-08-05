// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title CreditManager
 * @dev Fixed-markup credit sale module replacing variable-interest LendingMarket.
 *      Users can supply liquidity, withdraw, open credit with one-time markup, and repay in instalments.
 *      Utilises DynamicFeeModel for utilisation-based fee quotes but never accrues over time.
 */

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "../core/DynamicFeeModel.sol";
import "../interfaces/IOracle.sol";

contract CreditManager is AccessControl, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;
    using Math for uint256;

    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/
    uint256 public constant PRECISION = 1e18;
    uint256 public constant BASIS_POINTS = 10_000; // 1e4

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/
    struct Market {
        IERC20 asset;
        uint256 totalSupply;
        uint256 totalBorrowPrincipal; // Outstanding principal only
        uint256 utilisationRate; // Cached for UI helpers
        uint256 reserveFactor; // Portion of markup sent to treasury
        uint256 markupIndex; // Cumulative fixed markup per asset (scaled 1e18)
        bool isActive;
        bool canBorrow;
        bool canSupply;
    }

    struct UserAccount {
        uint256 supplied;
        uint256 borrowedPrincipal;
        uint256 totalMarkup; // Fixed markup quoted at open
        uint256 repaidPrincipal;
        uint256 repaidMarkup;
        bool isCollateralEnabled; // Future use for cross-asset risk engine
    }

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    mapping(address => Market) public markets; // asset => market data
    mapping(address => mapping(address => UserAccount)) public userAccounts; // user => asset => account
    mapping(address => bool) public isMarketListed;
    address[] public allMarkets;

    DynamicFeeModel public feeModel;
    IOracle public priceOracle;
    address public treasury;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/
    event Supplied(address indexed user, address indexed asset, uint256 amount);
    event Withdrawn(address indexed user, address indexed asset, uint256 amount);
    event CreditOpened(address indexed user, address indexed asset, uint256 principal, uint256 markup);
    event InstalmentPaid(address indexed user, address indexed asset, uint256 principalPaid, uint256 markupPaid);
    event MarketAdded(address indexed asset);
    event MarketUpdated(address indexed asset);

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(address _feeModel, address _priceOracle, address _treasury) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);

        feeModel = DynamicFeeModel(_feeModel);
        priceOracle = IOracle(_priceOracle);
        treasury = _treasury;
    }

    /*//////////////////////////////////////////////////////////////
                          EXTERNAL USER ACTIONS
    //////////////////////////////////////////////////////////////*/

    function supply(address asset, uint256 amount) external nonReentrant whenNotPaused {
        require(amount > 0, "0");
        require(isMarketListed[asset], "unlisted");
        Market storage m = markets[asset];
        require(m.isActive && m.canSupply, "supply disabled");

        m.asset.safeTransferFrom(msg.sender, address(this), amount);

        UserAccount storage ua = userAccounts[msg.sender][asset];
        ua.supplied += amount;
        m.totalSupply += amount;

        _updateUtilisation(asset);
        emit Supplied(msg.sender, asset, amount);
    }

    function withdraw(address asset, uint256 amount) external nonReentrant whenNotPaused {
        require(amount > 0, "0");
        require(isMarketListed[asset], "unlisted");
        Market storage m = markets[asset];
        UserAccount storage ua = userAccounts[msg.sender][asset];
        require(ua.supplied >= amount, "insufficient");

        ua.supplied -= amount;
        m.totalSupply -= amount;
        m.asset.safeTransfer(msg.sender, amount);

        _updateUtilisation(asset);
        emit Withdrawn(msg.sender, asset, amount);
    }

    /**
     * @notice Opens an asset-backed credit with fixed markup.
     * @param asset Underlying token to borrow.
     * @param principal Amount of asset to borrow.
     * @param recipient Address receiving borrowed funds (optional, defaults to msg.sender).
     */
    function openCreditSale(address asset, uint256 principal, address recipient) external nonReentrant whenNotPaused {
        require(principal > 0, "0");
        require(isMarketListed[asset], "unlisted");
        Market storage m = markets[asset];
        require(m.isActive && m.canBorrow, "borrow disabled");

        // Calculate markup via DynamicFeeModel
        uint256 feeBps = feeModel.getMarkupBps(asset, m.totalSupply, m.totalBorrowPrincipal, 0);
        uint256 markup = (principal * feeBps) / BASIS_POINTS;

        // Accounting updates
        UserAccount storage ua = userAccounts[msg.sender][asset];
        ua.borrowedPrincipal += principal;
        ua.totalMarkup += markup;
        m.totalBorrowPrincipal += principal;

        _updateUtilisation(asset);

        // Transfer principal to recipient
        address to = recipient == address(0) ? msg.sender : recipient;
        m.asset.safeTransfer(to, principal);

        // Allocate fee share to treasury immediately
        uint256 reserveShare = (markup * m.reserveFactor) / PRECISION;
        if (reserveShare > 0) {
            m.asset.safeTransfer(treasury, reserveShare);
        }

        emit CreditOpened(msg.sender, asset, principal, markup);
    }

    /**
     * @notice Pay instalment towards borrowed principal and/or markup.
     * @param asset underlying token.
     * @param principalToRepay amount of principal to repay.
     * @param markupToRepay amount of markup to repay.
     */
    function payInstalment(address asset, uint256 principalToRepay, uint256 markupToRepay) external nonReentrant whenNotPaused {
        require(principalToRepay + markupToRepay > 0, "0");
        require(isMarketListed[asset], "unlisted");
        Market storage m = markets[asset];
        UserAccount storage ua = userAccounts[msg.sender][asset];

        require(ua.borrowedPrincipal >= principalToRepay, "excess principal");
        require(ua.totalMarkup - ua.repaidMarkup >= markupToRepay, "excess markup");

        // Pull tokens
        uint256 repayTotal = principalToRepay + markupToRepay;
        m.asset.safeTransferFrom(msg.sender, address(this), repayTotal);

        // Update accounting
        if (principalToRepay > 0) {
            ua.borrowedPrincipal -= principalToRepay;
            ua.repaidPrincipal += principalToRepay;
            m.totalBorrowPrincipal -= principalToRepay;
        }
        if (markupToRepay > 0) {
            ua.repaidMarkup += markupToRepay;
            // Markup repayment flows entirely to suppliers via future distribution logic
        }

        _updateUtilisation(asset);
        emit InstalmentPaid(msg.sender, asset, principalToRepay, markupToRepay);
    }

    /*//////////////////////////////////////////////////////////////
                         MARKET ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function addMarket(
        address asset,
        uint256 reserveFactor,
        bool canBorrow,
        bool canSupply
    ) external onlyRole(ADMIN_ROLE) {
        require(!isMarketListed[asset], "exists");
        markets[asset] = Market({
            asset: IERC20(asset),
            totalSupply: 0,
            totalBorrowPrincipal: 0,
            utilisationRate: 0,
            reserveFactor: reserveFactor,
            markupIndex: PRECISION,
            isActive: true,
            canBorrow: canBorrow,
            canSupply: canSupply
        });
        isMarketListed[asset] = true;
        allMarkets.push(asset);
        emit MarketAdded(asset);
    }

    function setFeeModel(address _feeModel) external onlyRole(ADMIN_ROLE) {
        feeModel = DynamicFeeModel(_feeModel);
    }

    function setReserveFactor(address asset, uint256 rf) external onlyRole(ADMIN_ROLE) {
        markets[asset].reserveFactor = rf;
        emit MarketUpdated(asset);
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/

    function _updateUtilisation(address asset) internal {
        Market storage m = markets[asset];
        if (m.totalSupply == 0) {
            m.utilisationRate = 0;
        } else {
            m.utilisationRate = (m.totalBorrowPrincipal * PRECISION) / m.totalSupply;
        }
    }
}