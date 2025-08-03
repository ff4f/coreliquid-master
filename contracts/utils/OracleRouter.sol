// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface AggregatorV3Interface {
    function latestRoundData() external view returns (
        uint80 roundId,
        int256 price,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    );
    function decimals() external view returns (uint8);
}

contract OracleRouter {
    mapping(address => address) public priceFeeds;
    mapping(address => uint256) public twapPrices;
    
    uint256 public constant PRICE_PRECISION = 1e18;
    uint256 public constant STALE_PRICE_THRESHOLD = 3600; // 1 hour
    
    event PriceFeedUpdated(address indexed token, address indexed feed);
    event TWAPUpdated(address indexed token, uint256 price);
    
    error StalePriceData();
    error InvalidPriceFeed();
    
    function setPriceFeed(address token, address feed) external {
        priceFeeds[token] = feed;
        emit PriceFeedUpdated(token, feed);
    }
    
    function getPrice(address token) external view returns (uint256) {
        address feed = priceFeeds[token];
        require(feed != address(0), "Price feed not set");
        
        try AggregatorV3Interface(feed).latestRoundData() returns (
            uint80,
            int256 price,
            uint256,
            uint256 updatedAt,
            uint80
        ) {
            require(price > 0, "Invalid price");
            require(block.timestamp - updatedAt <= STALE_PRICE_THRESHOLD, "Stale price");
            
            uint8 decimals = AggregatorV3Interface(feed).decimals();
            return _scalePrice(uint256(price), decimals);
        } catch {
            // Fallback to TWAP if Chainlink fails
            return getTWAPPrice(token);
        }
    }
    
    function getTWAPPrice(address token) public view returns (uint256) {
        uint256 twapPrice = twapPrices[token];
        require(twapPrice > 0, "TWAP not available");
        return twapPrice;
    }
    
    function updateTWAP(address token, uint256 price) external {
        twapPrices[token] = price;
        emit TWAPUpdated(token, price);
    }
    
    function getHistoricalPrices(address token, uint256 period) external view returns (uint256[] memory) {
        // Return array with current TWAP price for now
        uint256[] memory prices = new uint256[](1);
        prices[0] = getTWAPPrice(token);
        return prices;
    }
    
    function _scalePrice(uint256 price, uint8 decimals) internal pure returns (uint256) {
        if (decimals == 18) {
            return price;
        } else if (decimals < 18) {
            return price * (10 ** (18 - decimals));
        } else {
            return price / (10 ** (decimals - 18));
        }
    }
}
