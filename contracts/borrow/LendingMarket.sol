// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title LendingMarket
 * @dev Core lending market contract
 */
contract LendingMarket is Ownable, ReentrancyGuard {
    struct Market {
        address asset;
        uint256 totalSupply;
        uint256 totalBorrows;
        uint256 supplyRate;
        uint256 borrowRate;
        bool isActive;
    }
    
    mapping(address => Market) public markets;
    mapping(address => bool) public supportedAssets;
    
    event MarketCreated(address indexed asset);
    event Supply(address indexed user, address indexed asset, uint256 amount);
    event Borrow(address indexed user, address indexed asset, uint256 amount);
    
    constructor() Ownable(msg.sender) {}
    
    function createMarket(address asset) external onlyOwner {
        require(!supportedAssets[asset], "Market already exists");
        
        markets[asset] = Market({
            asset: asset,
            totalSupply: 0,
            totalBorrows: 0,
            supplyRate: 0,
            borrowRate: 0,
            isActive: true
        });
        
        supportedAssets[asset] = true;
        emit MarketCreated(asset);
    }
    
    function supply(address asset, uint256 amount) external nonReentrant {
        require(supportedAssets[asset], "Asset not supported");
        require(markets[asset].isActive, "Market not active");
        
        IERC20(asset).transferFrom(msg.sender, address(this), amount);
        markets[asset].totalSupply += amount;
        
        emit Supply(msg.sender, asset, amount);
    }
    
    function borrow(address asset, uint256 amount) external nonReentrant {
        require(supportedAssets[asset], "Asset not supported");
        require(markets[asset].isActive, "Market not active");
        require(markets[asset].totalSupply >= amount, "Insufficient liquidity");
        
        markets[asset].totalBorrows += amount;
        IERC20(asset).transfer(msg.sender, amount);
        
        emit Borrow(msg.sender, asset, amount);
    }
    
    function getMarketData(address asset) external view returns (Market memory) {
        return markets[asset];
    }
}