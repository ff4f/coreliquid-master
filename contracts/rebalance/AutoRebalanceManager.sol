// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title AutoRebalanceManager
 * @dev Manages automatic rebalancing of Uniswap v3 positions
 */
contract AutoRebalanceManager is AccessControl, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;
    using Math for uint256;
    
    bytes32 public constant REBALANCER_ROLE = keccak256("REBALANCER_ROLE");
    bytes32 public constant KEEPER_ROLE = keccak256("KEEPER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    
    struct RebalanceConfig {
        uint256 priceDeviationThreshold; // in basis points
        uint256 timeThreshold; // minimum time between rebalances
        uint256 gasThreshold; // minimum gas price for rebalancing
        uint256 minLiquidityThreshold; // minimum liquidity to trigger rebalance
        bool autoRebalanceEnabled;
        bool emergencyMode;
    }
    
    struct PositionInfo {
        uint256 tokenId;
        address owner;
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidity;
        uint256 lastRebalanceTime;
        uint256 rebalanceCount;
        bool isActive;
    }
    
    struct RebalanceParams {
        uint256 tokenId;
        int24 newTickLower;
        int24 newTickUpper;
        uint256 amount0Min;
        uint256 amount1Min;
        uint256 deadline;
        bool collectFees;
    }
    
    struct RebalanceResult {
        uint256 newTokenId;
        uint128 newLiquidity;
        uint256 amount0;
        uint256 amount1;
        uint256 feesCollected0;
        uint256 feesCollected1;
        uint256 gasUsed;
    }
    
    RebalanceConfig public config;
    
    mapping(uint256 => PositionInfo) public positions;
    mapping(address => uint256[]) public userPositions;
    mapping(uint256 => uint256) public rebalanceHistory; // tokenId -> last rebalance timestamp
    
    address public immutable uniswapV3Factory;
    address public immutable nonfungiblePositionManager;
    address public immutable swapRouter;
    
    uint256 public totalRebalances;
    uint256 public totalGasSaved;
    uint256 public rebalanceFee = 50; // 0.5% in basis points
    address public feeRecipient;
    
    event PositionRegistered(
        uint256 indexed tokenId,
        address indexed owner,
        address token0,
        address token1,
        uint24 fee
    );
    
    event RebalanceExecuted(
        uint256 indexed oldTokenId,
        uint256 indexed newTokenId,
        address indexed owner,
        int24 newTickLower,
        int24 newTickUpper,
        uint128 newLiquidity
    );
    
    event RebalanceConfigUpdated(
        uint256 priceDeviationThreshold,
        uint256 timeThreshold,
        uint256 gasThreshold
    );
    
    event EmergencyModeToggled(bool enabled);
    
    constructor(
        address _uniswapV3Factory,
        address _nonfungiblePositionManager,
        address _swapRouter,
        address _feeRecipient
    ) {
        require(_uniswapV3Factory != address(0), "Invalid factory");
        require(_nonfungiblePositionManager != address(0), "Invalid position manager");
        require(_swapRouter != address(0), "Invalid swap router");
        require(_feeRecipient != address(0), "Invalid fee recipient");
        
        uniswapV3Factory = _uniswapV3Factory;
        nonfungiblePositionManager = _nonfungiblePositionManager;
        swapRouter = _swapRouter;
        feeRecipient = _feeRecipient;
        
        // Initialize default config
        config = RebalanceConfig({
            priceDeviationThreshold: 500, // 5%
            timeThreshold: 1 hours,
            gasThreshold: 20 gwei,
            minLiquidityThreshold: 1e15, // 0.001 ETH equivalent
            autoRebalanceEnabled: true,
            emergencyMode: false
        });
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(REBALANCER_ROLE, msg.sender);
        _grantRole(KEEPER_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
    }
    
    function registerPosition(
        uint256 tokenId,
        address owner,
        address token0,
        address token1,
        uint24 fee,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity
    ) external onlyRole(REBALANCER_ROLE) {
        require(owner != address(0), "Invalid owner");
        require(token0 != address(0) && token1 != address(0), "Invalid tokens");
        require(liquidity > 0, "Invalid liquidity");
        require(!positions[tokenId].isActive, "Position already registered");
        
        positions[tokenId] = PositionInfo({
            tokenId: tokenId,
            owner: owner,
            token0: token0,
            token1: token1,
            fee: fee,
            tickLower: tickLower,
            tickUpper: tickUpper,
            liquidity: liquidity,
            lastRebalanceTime: block.timestamp,
            rebalanceCount: 0,
            isActive: true
        });
        
        userPositions[owner].push(tokenId);
        
        emit PositionRegistered(tokenId, owner, token0, token1, fee);
    }
    
    function executeRebalance(RebalanceParams calldata params)
        external
        onlyRole(KEEPER_ROLE)
        nonReentrant
        whenNotPaused
        returns (RebalanceResult memory result)
    {
        require(params.deadline >= block.timestamp, "Deadline expired");
        
        PositionInfo storage position = positions[params.tokenId];
        require(position.isActive, "Position not active");
        require(_shouldRebalance(params.tokenId), "Rebalance not needed");
        
        uint256 gasStart = gasleft();
        
        // Collect fees if requested
        if (params.collectFees) {
            (result.feesCollected0, result.feesCollected1) = _collectFees(params.tokenId);
        }
        
        // Close current position
        (uint256 amount0, uint256 amount1) = _closePosition(params.tokenId);
        
        // Deduct rebalance fee
        (uint256 netAmount0, uint256 netAmount1) = _deductRebalanceFee(
            position.token0,
            position.token1,
            amount0,
            amount1
        );
        
        // Open new position
        (result.newTokenId, result.newLiquidity, result.amount0, result.amount1) = _openNewPosition(
            position.token0,
            position.token1,
            position.fee,
            params.newTickLower,
            params.newTickUpper,
            netAmount0,
            netAmount1,
            params.amount0Min,
            params.amount1Min,
            params.deadline
        );
        
        // Update position info
        _updatePositionInfo(
            params.tokenId,
            result.newTokenId,
            params.newTickLower,
            params.newTickUpper,
            result.newLiquidity
        );
        
        result.gasUsed = gasStart - gasleft();
        totalRebalances++;
        totalGasSaved += result.gasUsed;
        
        emit RebalanceExecuted(
            params.tokenId,
            result.newTokenId,
            position.owner,
            params.newTickLower,
            params.newTickUpper,
            result.newLiquidity
        );
    }
    
    function shouldRebalance(uint256 tokenId) external view returns (bool) {
        return _shouldRebalance(tokenId);
    }
    
    function getRebalanceParams(uint256 tokenId)
        external
        view
        returns (int24 suggestedTickLower, int24 suggestedTickUpper, uint256 confidence)
    {
        PositionInfo memory position = positions[tokenId];
        require(position.isActive, "Position not active");
        
        // Get current price and calculate optimal range
        (suggestedTickLower, suggestedTickUpper, confidence) = _calculateOptimalRange(
            position.token0,
            position.token1,
            position.fee
        );
    }
    
    function batchRebalance(uint256[] calldata tokenIds, RebalanceParams[] calldata params)
        external
        onlyRole(KEEPER_ROLE)
        nonReentrant
        whenNotPaused
    {
        require(tokenIds.length == params.length, "Array length mismatch");
        require(tokenIds.length <= 10, "Too many positions");
        
        for (uint256 i = 0; i < tokenIds.length; i++) {
            if (_shouldRebalance(tokenIds[i])) {
                this.executeRebalance(params[i]);
            }
        }
    }
    
    function getUserPositions(address user) external view returns (uint256[] memory) {
        return userPositions[user];
    }
    
    function getPositionInfo(uint256 tokenId) external view returns (PositionInfo memory) {
        return positions[tokenId];
    }
    
    function _shouldRebalance(uint256 tokenId) internal view returns (bool) {
        if (!config.autoRebalanceEnabled || config.emergencyMode) {
            return false;
        }
        
        PositionInfo memory position = positions[tokenId];
        if (!position.isActive) return false;
        
        // Check time threshold
        if (block.timestamp - position.lastRebalanceTime < config.timeThreshold) {
            return false;
        }
        
        // Check gas price threshold
        if (tx.gasprice > config.gasThreshold) {
            return false;
        }
        
        // Check liquidity threshold
        if (position.liquidity < config.minLiquidityThreshold) {
            return false;
        }
        
        // Check price deviation
        return _isPriceOutOfRange(tokenId);
    }
    
    function _isPriceOutOfRange(uint256 tokenId) internal view returns (bool) {
        PositionInfo memory position = positions[tokenId];
        
        // Get current tick from pool
        int24 currentTick = _getCurrentTick(position.token0, position.token1, position.fee);
        
        // Check if current tick is outside the position range
        if (currentTick <= position.tickLower || currentTick >= position.tickUpper) {
            return true;
        }
        
        // Check if price has deviated significantly
        int24 rangeMidpoint = (position.tickLower + position.tickUpper) / 2;
        int24 deviation = currentTick > rangeMidpoint ? 
            currentTick - rangeMidpoint : rangeMidpoint - currentTick;
        
        int24 maxDeviation = int24(uint24(
            (uint256(uint24(position.tickUpper - position.tickLower)) * config.priceDeviationThreshold) / 10000
        ));
        
        return deviation > maxDeviation;
    }
    
    function _collectFees(uint256 /* _tokenId */) internal pure returns (uint256 amount0, uint256 amount1) {
        // Implementation would call Uniswap's collect function
        // This is a placeholder for the actual implementation
        return (0, 0);
    }
    
    function _closePosition(uint256 /* _tokenId */) internal pure returns (uint256 amount0, uint256 amount1) {
        // Implementation would call Uniswap's decreaseLiquidity and collect
        // This is a placeholder for the actual implementation
        return (0, 0);
    }
    
    function _openNewPosition(
        address /* _token0 */,
        address /* _token1 */,
        uint24 /* _fee */,
        int24 /* _tickLower */,
        int24 /* _tickUpper */,
        uint256 /* _amount0 */,
        uint256 /* _amount1 */,
        uint256 /* _amount0Min */,
        uint256 /* _amount1Min */,
        uint256 /* _deadline */
    ) internal pure returns (uint256 tokenId, uint128 liquidity, uint256 actualAmount0, uint256 actualAmount1) {
        // Implementation would call Uniswap's mint function
        // This is a placeholder for the actual implementation
        return (0, 0, 0, 0);
    }
    
    function _deductRebalanceFee(
        address token0,
        address token1,
        uint256 amount0,
        uint256 amount1
    ) internal returns (uint256 netAmount0, uint256 netAmount1) {
        uint256 fee0 = (amount0 * rebalanceFee) / 10000;
        uint256 fee1 = (amount1 * rebalanceFee) / 10000;
        
        netAmount0 = amount0 - fee0;
        netAmount1 = amount1 - fee1;
        
        if (fee0 > 0) {
            IERC20(token0).safeTransfer(feeRecipient, fee0);
        }
        if (fee1 > 0) {
            IERC20(token1).safeTransfer(feeRecipient, fee1);
        }
    }
    
    function _updatePositionInfo(
        uint256 oldTokenId,
        uint256 newTokenId,
        int24 newTickLower,
        int24 newTickUpper,
        uint128 newLiquidity
    ) internal {
        PositionInfo storage position = positions[oldTokenId];
        
        // Create new position entry
        positions[newTokenId] = PositionInfo({
            tokenId: newTokenId,
            owner: position.owner,
            token0: position.token0,
            token1: position.token1,
            fee: position.fee,
            tickLower: newTickLower,
            tickUpper: newTickUpper,
            liquidity: newLiquidity,
            lastRebalanceTime: block.timestamp,
            rebalanceCount: position.rebalanceCount + 1,
            isActive: true
        });
        
        // Update user positions array
        uint256[] storage userPos = userPositions[position.owner];
        for (uint256 i = 0; i < userPos.length; i++) {
            if (userPos[i] == oldTokenId) {
                userPos[i] = newTokenId;
                break;
            }
        }
        
        // Deactivate old position
        position.isActive = false;
        rebalanceHistory[oldTokenId] = block.timestamp;
    }
    
    function _getCurrentTick(address /* _token0 */, address /* _token1 */, uint24 /* _fee */) internal pure returns (int24) {
        // Implementation would get current tick from Uniswap pool
        // This is a placeholder
        return 0;
    }
    
    function _calculateOptimalRange(address /* _token0 */, address /* _token1 */, uint24 /* _fee */)
        internal
        pure
        returns (int24 tickLower, int24 tickUpper, uint256 confidence)
    {
        // Implementation would calculate optimal range based on volatility and other factors
        // This is a placeholder
        return (0, 0, 80);
    }
    
    function updateRebalanceConfig(
        uint256 _priceDeviationThreshold,
        uint256 _timeThreshold,
        uint256 _gasThreshold,
        uint256 _minLiquidityThreshold
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_priceDeviationThreshold <= 5000, "Threshold too high"); // Max 50%
        require(_timeThreshold >= 10 minutes, "Time threshold too low");
        
        config.priceDeviationThreshold = _priceDeviationThreshold;
        config.timeThreshold = _timeThreshold;
        config.gasThreshold = _gasThreshold;
        config.minLiquidityThreshold = _minLiquidityThreshold;
        
        emit RebalanceConfigUpdated(_priceDeviationThreshold, _timeThreshold, _gasThreshold);
    }
    
    function toggleAutoRebalance(bool enabled) external onlyRole(DEFAULT_ADMIN_ROLE) {
        config.autoRebalanceEnabled = enabled;
    }
    
    function toggleEmergencyMode(bool enabled) external onlyRole(DEFAULT_ADMIN_ROLE) {
        config.emergencyMode = enabled;
        emit EmergencyModeToggled(enabled);
    }
    
    function setRebalanceFee(uint256 _fee) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_fee <= 1000, "Fee too high"); // Max 10%
        rebalanceFee = _fee;
    }
    
    function setFeeRecipient(address _feeRecipient) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_feeRecipient != address(0), "Invalid fee recipient");
        feeRecipient = _feeRecipient;
    }
    
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }
    
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }
    
    function deregisterPosition(uint256 tokenId) external onlyRole(REBALANCER_ROLE) {
        require(positions[tokenId].isActive, "Position not active");
        positions[tokenId].isActive = false;
    }
}
