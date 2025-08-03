// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title PositionNFT
 * @dev NFT contract for representing liquidity positions
 */
contract PositionNFT is ERC721, AccessControl, Pausable {
    using Strings for uint256;
    
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    
    uint256 private _nextTokenId = 1;
    
    // Position metadata
    struct PositionData {
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidity;
        uint256 amount0;
        uint256 amount1;
        uint256 timestamp;
        string strategy;
    }
    
    mapping(uint256 => PositionData) public positions;
    
    event PositionMinted(
        uint256 indexed tokenId,
        address indexed owner,
        address token0,
        address token1,
        uint24 fee,
        uint128 liquidity
    );
    
    event PositionUpdated(
        uint256 indexed tokenId,
        uint128 newLiquidity,
        uint256 amount0,
        uint256 amount1
    );
    
    constructor(
        string memory name,
        string memory symbol
    ) ERC721(name, symbol) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
    }
    
    /**
     * @dev Mint a new position NFT
     */
    function mint(
        address to,
        address token0,
        address token1,
        uint24 fee,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity,
        uint256 amount0,
        uint256 amount1,
        string memory strategy
    ) external onlyRole(MINTER_ROLE) returns (uint256) {
        uint256 tokenId = _nextTokenId++;
        
        positions[tokenId] = PositionData({
            token0: token0,
            token1: token1,
            fee: fee,
            tickLower: tickLower,
            tickUpper: tickUpper,
            liquidity: liquidity,
            amount0: amount0,
            amount1: amount1,
            timestamp: block.timestamp,
            strategy: strategy
        });
        
        _safeMint(to, tokenId);
        
        emit PositionMinted(tokenId, to, token0, token1, fee, liquidity);
        
        return tokenId;
    }
    
    /**
     * @dev Update position data
     */
    function updatePosition(
        uint256 tokenId,
        uint128 newLiquidity,
        uint256 amount0,
        uint256 amount1
    ) external onlyRole(MINTER_ROLE) {
        require(_ownerOf(tokenId) != address(0), "PositionNFT: token does not exist");
        
        PositionData storage position = positions[tokenId];
        position.liquidity = newLiquidity;
        position.amount0 = amount0;
        position.amount1 = amount1;
        
        emit PositionUpdated(tokenId, newLiquidity, amount0, amount1);
    }
    
    /**
     * @dev Burn a position NFT
     */
    function burn(uint256 tokenId) external {
        require(
            _isAuthorized(_ownerOf(tokenId), msg.sender, tokenId),
            "PositionNFT: caller is not owner nor approved"
        );
        
        delete positions[tokenId];
        _burn(tokenId);
    }
    
    /**
     * @dev Get position data
     */
    function getPosition(uint256 tokenId) external view returns (PositionData memory) {
        require(_ownerOf(tokenId) != address(0), "PositionNFT: token does not exist");
        return positions[tokenId];
    }
    
    /**
     * @dev Generate token URI with metadata
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_ownerOf(tokenId) != address(0), "PositionNFT: URI query for nonexistent token");
        
        PositionData memory position = positions[tokenId];
        
        string memory json = Base64.encode(
            bytes(
                string(
                    abi.encodePacked(
                        '{"name": "CoreLiquid Position #',
                        tokenId.toString(),
                        '",',
                        '"description": "A CoreLiquid liquidity position",',
                        '"attributes": [',
                        '{"trait_type": "Token0", "value": "',
                        _addressToString(position.token0),
                        '"},',
                        '{"trait_type": "Token1", "value": "',
                        _addressToString(position.token1),
                        '"},',
                        '{"trait_type": "Fee", "value": "',
                        uint256(position.fee).toString(),
                        '"},',
                        '{"trait_type": "Liquidity", "value": "',
                        uint256(position.liquidity).toString(),
                        '"},',
                        '{"trait_type": "Strategy", "value": "',
                        position.strategy,
                        '"}',
                        ']',
                        '}'
                    )
                )
            )
        );
        
        return string(abi.encodePacked("data:application/json;base64,", json));
    }
    
    /**
     * @dev Convert address to string
     */
    function _addressToString(address addr) internal pure returns (string memory) {
        bytes32 value = bytes32(uint256(uint160(addr)));
        bytes memory alphabet = "0123456789abcdef";
        bytes memory str = new bytes(42);
        str[0] = "0";
        str[1] = "x";
        for (uint256 i = 0; i < 20; i++) {
            str[2 + i * 2] = alphabet[uint8(value[i + 12] >> 4)];
            str[3 + i * 2] = alphabet[uint8(value[i + 12] & 0x0f)];
        }
        return string(str);
    }
    
    /**
     * @dev Get total supply of tokens
     */
    function totalSupply() external view returns (uint256) {
        return _nextTokenId - 1;
    }
    
    /**
     * @dev Pause the contract
     */
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }
    
    /**
     * @dev Unpause the contract
     */
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }
    
    /**
     * @dev Override _update to include pause functionality
     */
    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal override whenNotPaused returns (address) {
        return super._update(to, tokenId, auth);
    }
    
    /**
     * @dev See {IERC165-supportsInterface}
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC721, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
