// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title PositionNFT
 * @dev ERC-721 token representing protocol positions
 */
contract PositionNFT is ERC721, ERC721Enumerable, ERC721URIStorage, AccessControl, Pausable {
    using Strings for uint256;
    
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant METADATA_ROLE = keccak256("METADATA_ROLE");
    
    struct PositionData {
        uint256 uniswapTokenId;
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidity;
        uint256 amount0;
        uint256 amount1;
        uint256 createdAt;
        uint256 lastRebalanceAt;
        bool isActive;
    }
    
    uint256 private _tokenIdCounter;
    mapping(uint256 => PositionData) public positions;
    mapping(uint256 => uint256) public uniswapToProtocol; // uniswap tokenId -> protocol tokenId
    
    string private _baseTokenURI;
    
    event PositionMinted(
        uint256 indexed tokenId,
        address indexed owner,
        uint256 uniswapTokenId,
        address token0,
        address token1,
        uint128 liquidity
    );
    
    event PositionUpdated(
        uint256 indexed tokenId,
        uint256 newUniswapTokenId,
        uint128 newLiquidity
    );
    
    event PositionDeactivated(uint256 indexed tokenId);
    
    constructor(
        string memory name,
        string memory symbol,
        string memory baseURI
    ) ERC721(name, symbol) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(METADATA_ROLE, msg.sender);
        _baseTokenURI = baseURI;
    }
    
    function mintPosition(
        address to,
        uint256 uniswapTokenId,
        address token0,
        address token1,
        uint24 fee,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity,
        uint256 amount0,
        uint256 amount1
    ) external onlyRole(MINTER_ROLE) whenNotPaused returns (uint256) {
        require(to != address(0), "Invalid recipient");
        require(uniswapTokenId > 0, "Invalid Uniswap token ID");
        require(token0 != address(0) && token1 != address(0), "Invalid tokens");
        require(liquidity > 0, "Invalid liquidity");
        
        _tokenIdCounter++;
        uint256 tokenId = _tokenIdCounter;
        
        positions[tokenId] = PositionData({
            uniswapTokenId: uniswapTokenId,
            token0: token0,
            token1: token1,
            fee: fee,
            tickLower: tickLower,
            tickUpper: tickUpper,
            liquidity: liquidity,
            amount0: amount0,
            amount1: amount1,
            createdAt: block.timestamp,
            lastRebalanceAt: block.timestamp,
            isActive: true
        });
        
        uniswapToProtocol[uniswapTokenId] = tokenId;
        
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, _generateTokenURI(tokenId));
        
        emit PositionMinted(tokenId, to, uniswapTokenId, token0, token1, liquidity);
        
        return tokenId;
    }
    
    function updatePosition(
        uint256 tokenId,
        uint256 newUniswapTokenId,
        int24 newTickLower,
        int24 newTickUpper,
        uint128 newLiquidity,
        uint256 newAmount0,
        uint256 newAmount1
    ) external onlyRole(MINTER_ROLE) {
        require(_ownerOf(tokenId) != address(0), "Position does not exist");
        require(positions[tokenId].isActive, "Position is not active");
        
        PositionData storage position = positions[tokenId];
        
        // Remove old mapping
        delete uniswapToProtocol[position.uniswapTokenId];
        
        // Update position data
        position.uniswapTokenId = newUniswapTokenId;
        position.tickLower = newTickLower;
        position.tickUpper = newTickUpper;
        position.liquidity = newLiquidity;
        position.amount0 = newAmount0;
        position.amount1 = newAmount1;
        position.lastRebalanceAt = block.timestamp;
        
        // Add new mapping
        uniswapToProtocol[newUniswapTokenId] = tokenId;
        
        // Update metadata
        _setTokenURI(tokenId, _generateTokenURI(tokenId));
        
        emit PositionUpdated(tokenId, newUniswapTokenId, newLiquidity);
    }
    
    function deactivatePosition(uint256 tokenId) external onlyRole(MINTER_ROLE) {
        require(_ownerOf(tokenId) != address(0), "Position does not exist");
        require(positions[tokenId].isActive, "Position already inactive");
        
        positions[tokenId].isActive = false;
        delete uniswapToProtocol[positions[tokenId].uniswapTokenId];
        
        emit PositionDeactivated(tokenId);
    }
    
    function getPosition(uint256 tokenId) external view returns (PositionData memory) {
        require(_ownerOf(tokenId) != address(0), "Position does not exist");
        return positions[tokenId];
    }
    
    function getPositionByUniswapId(uint256 uniswapTokenId) external view returns (uint256, PositionData memory) {
        uint256 tokenId = uniswapToProtocol[uniswapTokenId];
        require(tokenId > 0, "Position not found");
        return (tokenId, positions[tokenId]);
    }
    
    function getUserPositions(address user) external view returns (uint256[] memory) {
        uint256 balance = balanceOf(user);
        uint256[] memory tokenIds = new uint256[](balance);
        
        for (uint256 i = 0; i < balance; i++) {
            tokenIds[i] = tokenOfOwnerByIndex(user, i);
        }
        
        return tokenIds;
    }
    
    function _generateTokenURI(uint256 tokenId) internal view returns (string memory) {
        PositionData memory position = positions[tokenId];
        
        string memory json = Base64.encode(
            bytes(
                string(
                    abi.encodePacked(
                        '{"name": "CoreFluidX Position #',
                        tokenId.toString(),
                        '",',
                        '"description": "CoreFluidX Liquidity Position",',
                        '"attributes": [',
                        '{"trait_type": "Token0", "value": "',
                        _addressToString(position.token0),
                        '"},',
                        '{"trait_type": "Token1", "value": "',
                        _addressToString(position.token1),
                        '"},',
                        '{"trait_type": "Fee Tier", "value": "',
                        uint256(position.fee).toString(),
                        '"},',
                        '{"trait_type": "Liquidity", "value": "',
                        uint256(position.liquidity).toString(),
                        '"},',
                        '{"trait_type": "Active", "value": "',
                        position.isActive ? 'true' : 'false',
                        '"}',
                        ']',
                        '}'
                    )
                )
            )
        );
        
        return string(abi.encodePacked("data:application/json;base64,", json));
    }
    
    function _addressToString(address addr) internal pure returns (string memory) {
        return Strings.toHexString(uint256(uint160(addr)), 20);
    }
    
    function setBaseURI(string memory baseURI) external onlyRole(METADATA_ROLE) {
        _baseTokenURI = baseURI;
    }
    
    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }
    
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }
    
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }
    
    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal override(ERC721, ERC721Enumerable) whenNotPaused returns (address) {
        return super._update(to, tokenId, auth);
    }
    
    function _increaseBalance(address account, uint128 value) internal override(ERC721, ERC721Enumerable) {
        super._increaseBalance(account, value);
    }
    
    // Custom burn function to clean up mappings
    function burnPosition(uint256 tokenId) external {
        address owner = _requireOwned(tokenId);
        require(
            _msgSender() == owner || 
            getApproved(tokenId) == _msgSender() || 
            isApprovedForAll(owner, _msgSender()),
            "Not approved or owner"
        );
        
        // Clean up mappings
        delete uniswapToProtocol[positions[tokenId].uniswapTokenId];
        delete positions[tokenId];
        
        _burn(tokenId);
    }
    
    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }
    
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable, ERC721URIStorage, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
