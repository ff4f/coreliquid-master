// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IUserPositionRegistry
 * @dev Interface for managing user positions in the CoreLiquid protocol
 */
interface IUserPositionRegistry {
    struct Position {
        uint256 amount;
        uint256 timestamp;
        address validator;
        bool isActive;
    }
    
    struct UserPosition {
        uint256 totalStaked;
        uint256 totalRewards;
        Position[] positions;
        mapping(address => uint256) validatorStakes;
    }
    
    /**
     * @dev Emitted when a new position is created
     */
    event PositionCreated(
        address indexed user,
        uint256 indexed positionId,
        uint256 amount,
        address validator
    );
    
    /**
     * @dev Emitted when a position is updated
     */
    event PositionUpdated(
        address indexed user,
        uint256 indexed positionId,
        uint256 newAmount
    );
    
    /**
     * @dev Emitted when a position is closed
     */
    event PositionClosed(
        address indexed user,
        uint256 indexed positionId
    );
    
    /**
     * @dev Creates a new position for a user
     * @param user The user address
     * @param amount The staked amount
     * @param validator The validator address
     * @return positionId The ID of the created position
     */
    function createPosition(
        address user,
        uint256 amount,
        address validator
    ) external returns (uint256 positionId);
    
    /**
     * @dev Updates an existing position
     * @param user The user address
     * @param positionId The position ID
     * @param newAmount The new staked amount
     */
    function updatePosition(
        address user,
        uint256 positionId,
        uint256 newAmount
    ) external;
    
    /**
     * @dev Closes a position
     * @param user The user address
     * @param positionId The position ID
     */
    function closePosition(
        address user,
        uint256 positionId
    ) external;
    
    /**
     * @dev Gets user's total staked amount
     * @param user The user address
     * @return totalStaked The total staked amount
     */
    function getUserTotalStaked(address user) external view returns (uint256 totalStaked);
    
    /**
     * @dev Gets user's total rewards
     * @param user The user address
     * @return totalRewards The total rewards
     */
    function getUserTotalRewards(address user) external view returns (uint256 totalRewards);
    
    /**
     * @dev Gets user's stake with a specific validator
     * @param user The user address
     * @param validator The validator address
     * @return stake The staked amount with the validator
     */
    function getUserValidatorStake(
        address user,
        address validator
    ) external view returns (uint256 stake);
    
    /**
     * @dev Gets user's position by ID
     * @param user The user address
     * @param positionId The position ID
     * @return position The position data
     */
    function getUserPosition(
        address user,
        uint256 positionId
    ) external view returns (Position memory position);
    
    /**
     * @dev Gets the number of positions for a user
     * @param user The user address
     * @return count The number of positions
     */
    function getUserPositionCount(address user) external view returns (uint256 count);
    
    /**
     * @dev Gets all active positions for a user
     * @param user The user address
     * @return positions Array of active positions
     */
    function getUserActivePositions(address user) external view returns (Position[] memory positions);
    
    /**
     * @dev Checks if a user has any active positions
     * @param user The user address
     * @return hasPositions True if user has active positions
     */
    function hasActivePositions(address user) external view returns (bool hasPositions);
}
