// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title UniswapV3Router
 * @dev Handles Uniswap v3 position management
 */
contract UniswapV3Router is IERC721Receiver, ReentrancyGuard, Ownable {
    
    struct MintParams {
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        address recipient;
        uint256 deadline;
    }
    
    struct PositionInfo {
        uint256 tokenId;
        uint128 liquidity;
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint256 feeGrowthInside0LastX128;
        uint256 feeGrowthInside1LastX128;
        uint128 tokensOwed0;
        uint128 tokensOwed1;
    }
    
    // Mock Uniswap v3 interfaces
    address public immutable positionManager;
    address public immutable swapRouter;
    
    mapping(uint256 => PositionInfo) public positions;
    mapping(address => uint256[]) public userPositions;
    
    uint256 private nextTokenId = 1;
    
    event PositionMinted(
        uint256 indexed tokenId,
        address indexed owner,
        uint128 liquidity,
        uint256 amount0,
        uint256 amount1
    );
    
    event LiquidityDecreased(
        uint256 indexed tokenId,
        uint128 liquidity,
        uint256 amount0,
        uint256 amount1
    );
    
    event FeesCollected(
        uint256 indexed tokenId,
        uint256 amount0,
        uint256 amount1
    );
    
    constructor(address _positionManager, address _swapRouter, address initialOwner) Ownable(initialOwner) {
        positionManager = _positionManager;
        swapRouter = _swapRouter;
    }
    
    function mintPosition(MintParams calldata params) 
        external 
        nonReentrant 
        returns (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1) 
    {
        require(params.deadline >= block.timestamp, "Deadline expired");
        require(params.token0 < params.token1, "Invalid token order");
        require(params.tickLower < params.tickUpper, "Invalid tick range");
        
        tokenId = nextTokenId++;
        
        // Simulate liquidity calculation
        liquidity = uint128((params.amount0Desired + params.amount1Desired) / 2);
        amount0 = params.amount0Desired;
        amount1 = params.amount1Desired;
        
        // Store position info
        positions[tokenId] = PositionInfo({
            tokenId: tokenId,
            liquidity: liquidity,
            token0: params.token0,
            token1: params.token1,
            fee: params.fee,
            tickLower: params.tickLower,
            tickUpper: params.tickUpper,
            feeGrowthInside0LastX128: 0,
            feeGrowthInside1LastX128: 0,
            tokensOwed0: 0,
            tokensOwed1: 0
        });
        
        userPositions[params.recipient].push(tokenId);
        
        emit PositionMinted(tokenId, params.recipient, liquidity, amount0, amount1);
    }
    
    function decreaseLiquidity(
        uint256 tokenId,
        uint128 liquidityToRemove,
        uint256 amount0Min,
        uint256 amount1Min,
        uint256 deadline
    ) external nonReentrant returns (uint256 amount0, uint256 amount1) {
        require(deadline >= block.timestamp, "Deadline expired");
        require(positions[tokenId].tokenId != 0, "Position not found");
        
        PositionInfo storage position = positions[tokenId];
        require(liquidityToRemove <= position.liquidity, "Insufficient liquidity");
        
        // Calculate proportional amounts
        amount0 = (uint256(liquidityToRemove) * 1000) / uint256(position.liquidity);
        amount1 = (uint256(liquidityToRemove) * 1000) / uint256(position.liquidity);
        
        require(amount0 >= amount0Min && amount1 >= amount1Min, "Slippage exceeded");
        
        position.liquidity -= liquidityToRemove;
        
        emit LiquidityDecreased(tokenId, liquidityToRemove, amount0, amount1);
    }
    
    function collectFees(
        uint256 tokenId,
        uint128 amount0Max,
        uint128 amount1Max
    ) external nonReentrant returns (uint256 amount0, uint256 amount1) {
        require(positions[tokenId].tokenId != 0, "Position not found");
        
        PositionInfo storage position = positions[tokenId];
        
        // Simulate fee collection
        amount0 = uint256(position.tokensOwed0);
        amount1 = uint256(position.tokensOwed1);
        
        if (amount0 > amount0Max) amount0 = amount0Max;
        if (amount1 > amount1Max) amount1 = amount1Max;
        
        position.tokensOwed0 -= uint128(amount0);
        position.tokensOwed1 -= uint128(amount1);
        
        emit FeesCollected(tokenId, amount0, amount1);
    }
    
    function collectAll(uint256 tokenId) 
        external 
        nonReentrant 
        returns (uint256 amount0, uint256 amount1, uint256 fees0, uint256 fees1) 
    {
        require(positions[tokenId].tokenId != 0, "Position not found");
        
        PositionInfo storage position = positions[tokenId];
        
        // Collect all liquidity
        if (position.liquidity > 0) {
            (amount0, amount1) = this.decreaseLiquidity(
                tokenId,
                position.liquidity,
                0,
                0,
                block.timestamp + 300
            );
        }
        
        // Collect all fees
        (fees0, fees1) = this.collectFees(
            tokenId,
            type(uint128).max,
            type(uint128).max
        );
    }
    
    function burnPosition(uint256 tokenId) external nonReentrant {
        require(positions[tokenId].tokenId != 0, "Position not found");
        require(positions[tokenId].liquidity == 0, "Position has liquidity");
        require(positions[tokenId].tokensOwed0 == 0 && positions[tokenId].tokensOwed1 == 0, "Uncollected fees");
        
        delete positions[tokenId];
        
        // Remove from user positions
        uint256[] storage userPos = userPositions[msg.sender];
        for (uint256 i = 0; i < userPos.length; i++) {
            if (userPos[i] == tokenId) {
                userPos[i] = userPos[userPos.length - 1];
                userPos.pop();
                break;
            }
        }
    }
    
    function getPosition(uint256 tokenId) external view returns (PositionInfo memory) {
        return positions[tokenId];
    }
    
    function getUserPositions(address user) external view returns (uint256[] memory) {
        return userPositions[user];
    }
    
    function simulateFeesAccrual(uint256 tokenId, uint128 fees0, uint128 fees1) external onlyOwner {
        require(positions[tokenId].tokenId != 0, "Position not found");
        
        positions[tokenId].tokensOwed0 += fees0;
        positions[tokenId].tokensOwed1 += fees1;
    }
    
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}
