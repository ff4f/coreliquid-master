// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title PositionNFT
 * @dev NFT contract for representing liquidity positions
 */
contract PositionNFT is ERC721, ERC721Enumerable, Ownable, ReentrancyGuard {
    using Strings for uint256;

    struct Position {
        address owner;
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidity;
        uint256 feeGrowthInside0LastX128;
        uint256 feeGrowthInside1LastX128;
        uint128 tokensOwed0;
        uint128 tokensOwed1;
        uint256 createdAt;
        uint256 lastUpdate;
        bool isActive;
    }

    mapping(uint256 => Position) public positions;
    uint256 private _nextTokenId = 1;
    string private _baseTokenURI;

    event PositionMinted(
        uint256 indexed tokenId,
        address indexed owner,
        address token0,
        address token1,
        uint24 fee,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity
    );

    event PositionUpdated(
        uint256 indexed tokenId,
        uint128 liquidity,
        uint128 tokensOwed0,
        uint128 tokensOwed1
    );

    event PositionBurned(uint256 indexed tokenId);

    constructor(
        string memory name,
        string memory symbol,
        string memory baseTokenURI
    ) ERC721(name, symbol) Ownable(msg.sender) {
        _baseTokenURI = baseTokenURI;
    }

    /**
     * @dev Mint a new position NFT
     * @param to Address to mint the NFT to
     * @param token0 First token of the pair
     * @param token1 Second token of the pair
     * @param fee Fee tier
     * @param tickLower Lower tick boundary
     * @param tickUpper Upper tick boundary
     * @param liquidity Initial liquidity amount
     * @return tokenId The ID of the minted NFT
     */
    function mint(
        address to,
        address token0,
        address token1,
        uint24 fee,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity
    ) external onlyOwner nonReentrant returns (uint256 tokenId) {
        require(to != address(0), "Invalid recipient");
        require(token0 != address(0) && token1 != address(0), "Invalid tokens");
        require(token0 != token1, "Identical tokens");
        require(tickLower < tickUpper, "Invalid tick range");
        require(liquidity > 0, "Invalid liquidity");

        tokenId = _nextTokenId++;
        
        positions[tokenId] = Position({
            owner: to,
            token0: token0,
            token1: token1,
            fee: fee,
            tickLower: tickLower,
            tickUpper: tickUpper,
            liquidity: liquidity,
            feeGrowthInside0LastX128: 0,
            feeGrowthInside1LastX128: 0,
            tokensOwed0: 0,
            tokensOwed1: 0,
            createdAt: block.timestamp,
            lastUpdate: block.timestamp,
            isActive: true
        });

        _safeMint(to, tokenId);

        emit PositionMinted(
            tokenId,
            to,
            token0,
            token1,
            fee,
            tickLower,
            tickUpper,
            liquidity
        );
    }

    /**
     * @dev Update position data
     * @param tokenId Token ID to update
     * @param liquidity New liquidity amount
     * @param tokensOwed0 Tokens owed for token0
     * @param tokensOwed1 Tokens owed for token1
     */
    function updatePosition(
        uint256 tokenId,
        uint128 liquidity,
        uint128 tokensOwed0,
        uint128 tokensOwed1
    ) external onlyOwner {
        require(_ownerOf(tokenId) != address(0), "Position does not exist");
        
        Position storage position = positions[tokenId];
        position.liquidity = liquidity;
        position.tokensOwed0 = tokensOwed0;
        position.tokensOwed1 = tokensOwed1;
        position.lastUpdate = block.timestamp;

        emit PositionUpdated(tokenId, liquidity, tokensOwed0, tokensOwed1);
    }

    /**
     * @dev Burn a position NFT
     * @param tokenId Token ID to burn
     */
    function burn(uint256 tokenId) external {
        require(_isAuthorized(ownerOf(tokenId), msg.sender, tokenId), "Not authorized");
        require(positions[tokenId].liquidity == 0, "Position still has liquidity");
        
        positions[tokenId].isActive = false;
        _burn(tokenId);
        
        emit PositionBurned(tokenId);
    }

    /**
     * @dev Get position data
     * @param tokenId Token ID
     * @return position Position data
     */
    function getPosition(uint256 tokenId) external view returns (Position memory position) {
        require(_ownerOf(tokenId) != address(0), "Position does not exist");
        return positions[tokenId];
    }

    /**
     * @dev Get positions owned by an address
     * @param owner Owner address
     * @return tokenIds Array of token IDs owned by the address
     */
    function getPositionsByOwner(address owner) external view returns (uint256[] memory tokenIds) {
        uint256 balance = balanceOf(owner);
        tokenIds = new uint256[](balance);
        
        for (uint256 i = 0; i < balance; i++) {
            tokenIds[i] = tokenOfOwnerByIndex(owner, i);
        }
    }

    /**
     * @dev Set base URI for token metadata
     * @param baseTokenURI New base URI
     */
    function setBaseURI(string memory baseTokenURI) external onlyOwner {
        _baseTokenURI = baseTokenURI;
    }

    /**
     * @dev Get token URI
     * @param tokenId Token ID
     * @return Token URI string
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_ownerOf(tokenId) != address(0), "Position does not exist");
        
        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 
            ? string(abi.encodePacked(baseURI, tokenId.toString()))
            : "";
    }

    /**
     * @dev Get base URI
     * @return Base URI string
     */
    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    /**
     * @dev Check if position is active
     * @param tokenId Token ID
     * @return isActive True if position is active
     */
    function isPositionActive(uint256 tokenId) external view returns (bool isActive) {
        require(_ownerOf(tokenId) != address(0), "Position does not exist");
        return positions[tokenId].isActive;
    }

    /**
     * @dev Get total number of positions
     * @return total Total number of minted positions
     */
    function totalPositions() external view returns (uint256 total) {
        return _nextTokenId - 1;
    }

    // Override required functions
    function _update(address to, uint256 tokenId, address auth)
        internal
        override(ERC721, ERC721Enumerable)
        returns (address)
    {
        return super._update(to, tokenId, auth);
    }

    function _increaseBalance(address account, uint128 value)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._increaseBalance(account, value);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}