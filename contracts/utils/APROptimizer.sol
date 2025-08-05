// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title APROptimizer
 * @dev Contract for optimizing Annual Percentage Rate (APR) across different strategies
 */
contract APROptimizer is Ownable, ReentrancyGuard {
    using Math for uint256;

    uint256 public constant PRECISION = 1e18;
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant SECONDS_PER_YEAR = 365 days;

    struct StrategyAPR {
        address strategy;
        uint256 currentAPR;
        uint256 historicalAPR;
        uint256 riskScore;
        uint256 liquidity;
        bool isActive;
        uint256 lastUpdate;
    }

    struct OptimizationParams {
        uint256 targetAPR;
        uint256 riskTolerance;
        uint256 liquidityRequirement;
        uint256 rebalanceThreshold;
    }

    mapping(address => StrategyAPR) public strategies;
    address[] public strategyList;
    OptimizationParams public optimizationParams;

    event StrategyAdded(address indexed strategy, uint256 apr, uint256 riskScore);
    event StrategyUpdated(address indexed strategy, uint256 newAPR, uint256 newRiskScore);
    event OptimizationExecuted(address[] strategies, uint256[] allocations, uint256 expectedAPR);
    event ParametersUpdated(uint256 targetAPR, uint256 riskTolerance);

    constructor() Ownable(msg.sender) {
        optimizationParams = OptimizationParams({
            targetAPR: 1000, // 10% target APR
            riskTolerance: 500, // 5% risk tolerance
            liquidityRequirement: 1000000 * 1e18, // 1M minimum liquidity
            rebalanceThreshold: 100 // 1% rebalance threshold
        });
    }

    /**
     * @dev Add a new strategy to optimization pool
     * @param strategy Strategy contract address
     * @param currentAPR Current APR of the strategy
     * @param riskScore Risk score (0-10000 basis points)
     * @param liquidity Available liquidity
     */
    function addStrategy(
        address strategy,
        uint256 currentAPR,
        uint256 riskScore,
        uint256 liquidity
    ) external onlyOwner {
        require(strategy != address(0), "Invalid strategy");
        require(riskScore <= BASIS_POINTS, "Invalid risk score");
        require(!strategies[strategy].isActive, "Strategy already exists");

        strategies[strategy] = StrategyAPR({
            strategy: strategy,
            currentAPR: currentAPR,
            historicalAPR: currentAPR,
            riskScore: riskScore,
            liquidity: liquidity,
            isActive: true,
            lastUpdate: block.timestamp
        });

        strategyList.push(strategy);
        emit StrategyAdded(strategy, currentAPR, riskScore);
    }

    /**
     * @dev Update strategy APR and metrics
     * @param strategy Strategy address
     * @param newAPR New APR value
     * @param newRiskScore New risk score
     * @param newLiquidity New liquidity amount
     */
    function updateStrategy(
        address strategy,
        uint256 newAPR,
        uint256 newRiskScore,
        uint256 newLiquidity
    ) external onlyOwner {
        require(strategies[strategy].isActive, "Strategy not found");
        require(newRiskScore <= BASIS_POINTS, "Invalid risk score");

        StrategyAPR storage strategyData = strategies[strategy];
        strategyData.historicalAPR = (strategyData.historicalAPR + strategyData.currentAPR) / 2;
        strategyData.currentAPR = newAPR;
        strategyData.riskScore = newRiskScore;
        strategyData.liquidity = newLiquidity;
        strategyData.lastUpdate = block.timestamp;

        emit StrategyUpdated(strategy, newAPR, newRiskScore);
    }

    /**
     * @dev Calculate optimal allocation across strategies
     * @param totalAmount Total amount to allocate
     * @return strategies_ Array of strategy addresses
     * @return allocations Array of allocation amounts
     * @return expectedAPR Expected weighted APR
     */
    function calculateOptimalAllocation(uint256 totalAmount)
        external
        view
        returns (
            address[] memory strategies_,
            uint256[] memory allocations,
            uint256 expectedAPR
        )
    {
        require(totalAmount > 0, "Invalid amount");

        uint256 activeStrategies = 0;
        for (uint256 i = 0; i < strategyList.length; i++) {
            if (strategies[strategyList[i]].isActive && 
                strategies[strategyList[i]].liquidity >= optimizationParams.liquidityRequirement) {
                activeStrategies++;
            }
        }

        require(activeStrategies > 0, "No active strategies");

        strategies_ = new address[](activeStrategies);
        allocations = new uint256[](activeStrategies);

        uint256 index = 0;
        uint256 totalWeight = 0;
        uint256 weightedAPR = 0;

        // Calculate weights based on APR and inverse risk
        for (uint256 i = 0; i < strategyList.length; i++) {
            address strategyAddr = strategyList[i];
            StrategyAPR memory strategy = strategies[strategyAddr];
            
            if (strategy.isActive && strategy.liquidity >= optimizationParams.liquidityRequirement) {
                strategies_[index] = strategyAddr;
                
                // Weight = APR / (1 + riskScore)
                uint256 weight = strategy.currentAPR * PRECISION / (PRECISION + strategy.riskScore * PRECISION / BASIS_POINTS);
                totalWeight += weight;
                
                // Store weight temporarily in allocations array
                allocations[index] = weight;
                index++;
            }
        }

        // Convert weights to actual allocations
        for (uint256 i = 0; i < activeStrategies; i++) {
            allocations[i] = totalAmount * allocations[i] / totalWeight;
            
            // Calculate weighted APR
            uint256 strategyAPR = strategies[strategies_[i]].currentAPR;
            weightedAPR += strategyAPR * allocations[i] / totalAmount;
        }

        expectedAPR = weightedAPR;
    }

    /**
     * @dev Get strategy information
     * @param strategy Strategy address
     * @return strategyData Strategy information
     */
    function getStrategy(address strategy) external view returns (StrategyAPR memory strategyData) {
        return strategies[strategy];
    }

    /**
     * @dev Get all active strategies
     * @return activeStrategies Array of active strategy addresses
     */
    function getActiveStrategies() external view returns (address[] memory activeStrategies) {
        uint256 count = 0;
        for (uint256 i = 0; i < strategyList.length; i++) {
            if (strategies[strategyList[i]].isActive) {
                count++;
            }
        }

        activeStrategies = new address[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < strategyList.length; i++) {
            if (strategies[strategyList[i]].isActive) {
                activeStrategies[index] = strategyList[i];
                index++;
            }
        }
    }

    /**
     * @dev Update optimization parameters
     * @param targetAPR Target APR (basis points)
     * @param riskTolerance Risk tolerance (basis points)
     * @param liquidityRequirement Minimum liquidity requirement
     * @param rebalanceThreshold Rebalance threshold (basis points)
     */
    function updateOptimizationParams(
        uint256 targetAPR,
        uint256 riskTolerance,
        uint256 liquidityRequirement,
        uint256 rebalanceThreshold
    ) external onlyOwner {
        optimizationParams = OptimizationParams({
            targetAPR: targetAPR,
            riskTolerance: riskTolerance,
            liquidityRequirement: liquidityRequirement,
            rebalanceThreshold: rebalanceThreshold
        });

        emit ParametersUpdated(targetAPR, riskTolerance);
    }

    /**
     * @dev Deactivate a strategy
     * @param strategy Strategy address to deactivate
     */
    function deactivateStrategy(address strategy) external onlyOwner {
        require(strategies[strategy].isActive, "Strategy not active");
        strategies[strategy].isActive = false;
    }

    /**
     * @dev Reactivate a strategy
     * @param strategy Strategy address to reactivate
     */
    function reactivateStrategy(address strategy) external onlyOwner {
        require(!strategies[strategy].isActive, "Strategy already active");
        require(strategies[strategy].strategy != address(0), "Strategy not found");
        strategies[strategy].isActive = true;
    }
}