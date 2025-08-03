// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./AutoRebalanceManager.sol";
import "./TickOptimizer.sol";
import "../utils/APROptimizer.sol";

/**
 * @title RebalanceFlow
 * @dev Orchestrates the complete rebalancing flow
 */
contract RebalanceFlow is AccessControl, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;
    
    bytes32 public constant FLOW_MANAGER_ROLE = keccak256("FLOW_MANAGER_ROLE");
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");
    
    struct FlowConfig {
        uint256 maxSlippage;
        uint256 minProfitThreshold;
        uint256 maxGasPrice;
        uint256 rebalanceInterval;
        bool enableAutoExecution;
        bool enableEmergencyStop;
    }
    
    struct RebalanceStep {
        uint8 stepType; // 0: analyze, 1: optimize, 2: execute, 3: verify
        bytes data;
        uint256 gasEstimate;
        bool completed;
        uint256 timestamp;
    }
    
    struct FlowExecution {
        uint256 flowId;
        uint256 tokenId;
        address initiator;
        RebalanceStep[] steps;
        uint256 totalGasUsed;
        uint256 startTime;
        uint256 endTime;
        bool success;
        string errorMessage;
    }
    
    AutoRebalanceManager public immutable rebalanceManager;
    TickOptimizer public immutable tickOptimizer;
    APROptimizer public immutable aprOptimizer;
    
    FlowConfig public config;
    
    mapping(uint256 => FlowExecution) public executions;
    mapping(uint256 => uint256) public positionToFlow; // tokenId -> flowId
    mapping(address => uint256[]) public userFlows;
    
    uint256 public nextFlowId = 1;
    uint256 public totalFlowsExecuted;
    uint256 public totalGasSaved;
    
    event FlowStarted(
        uint256 indexed flowId,
        uint256 indexed tokenId,
        address indexed initiator
    );
    
    event StepCompleted(
        uint256 indexed flowId,
        uint8 stepType,
        uint256 gasUsed
    );
    
    event FlowCompleted(
        uint256 indexed flowId,
        bool success,
        uint256 totalGasUsed
    );
    
    event FlowConfigUpdated(
        uint256 maxSlippage,
        uint256 minProfitThreshold,
        uint256 maxGasPrice
    );
    
    event EmergencyStop(uint256 indexed flowId, string reason);
    
    constructor(
        address _rebalanceManager,
        address _tickOptimizer,
        address _aprOptimizer
    ) {
        require(_rebalanceManager != address(0), "Invalid rebalance manager");
        require(_tickOptimizer != address(0), "Invalid tick optimizer");
        require(_aprOptimizer != address(0), "Invalid APR optimizer");
        
        rebalanceManager = AutoRebalanceManager(_rebalanceManager);
        tickOptimizer = TickOptimizer(_tickOptimizer);
        aprOptimizer = APROptimizer(_aprOptimizer);
        
        // Initialize default config
        config = FlowConfig({
            maxSlippage: 500, // 5%
            minProfitThreshold: 100, // 1%
            maxGasPrice: 50 gwei,
            rebalanceInterval: 1 hours,
            enableAutoExecution: true,
            enableEmergencyStop: true
        });
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(FLOW_MANAGER_ROLE, msg.sender);
        _grantRole(EXECUTOR_ROLE, msg.sender);
    }
    
    function initiateRebalanceFlow(uint256 tokenId)
        external
        onlyRole(EXECUTOR_ROLE)
        nonReentrant
        whenNotPaused
        returns (uint256 flowId)
    {
        require(tokenId > 0, "Invalid token ID");
        require(positionToFlow[tokenId] == 0, "Flow already active for position");
        
        // Validate position exists and needs rebalancing
        require(rebalanceManager.shouldRebalance(tokenId), "Rebalance not needed");
        
        flowId = nextFlowId++;
        
        // Initialize flow execution
        FlowExecution storage execution = executions[flowId];
        execution.flowId = flowId;
        execution.tokenId = tokenId;
        execution.initiator = msg.sender;
        execution.startTime = block.timestamp;
        
        // Create rebalance steps
        _createRebalanceSteps(flowId, tokenId);
        
        positionToFlow[tokenId] = flowId;
        userFlows[msg.sender].push(flowId);
        
        emit FlowStarted(flowId, tokenId, msg.sender);
        
        // Auto-execute if enabled
        if (config.enableAutoExecution) {
            _executeFlow(flowId);
        }
    }
    
    function executeFlow(uint256 flowId)
        external
        onlyRole(EXECUTOR_ROLE)
        nonReentrant
        whenNotPaused
    {
        require(executions[flowId].flowId != 0, "Flow does not exist");
        require(!executions[flowId].success, "Flow already completed");
        require(executions[flowId].endTime == 0, "Flow already finished");
        
        _executeFlow(flowId);
    }
    
    function _executeFlow(uint256 flowId) internal {
        FlowExecution storage execution = executions[flowId];
        uint256 gasStart = gasleft();
        
        try this._executeFlowSteps(flowId) {
            execution.success = true;
            execution.endTime = block.timestamp;
            
            // Clean up
            positionToFlow[execution.tokenId] = 0;
            totalFlowsExecuted++;
            
        } catch Error(string memory reason) {
            execution.success = false;
            execution.errorMessage = reason;
            execution.endTime = block.timestamp;
            
            if (config.enableEmergencyStop) {
                emit EmergencyStop(flowId, reason);
            }
        }
        
        execution.totalGasUsed = gasStart - gasleft();
        totalGasSaved += execution.totalGasUsed;
        
        emit FlowCompleted(flowId, execution.success, execution.totalGasUsed);
    }
    
    function _executeFlowSteps(uint256 flowId) external {
        require(msg.sender == address(this), "Internal function");
        
        FlowExecution storage execution = executions[flowId];
        
        for (uint256 i = 0; i < execution.steps.length; i++) {
            if (execution.steps[i].completed) continue;
            
            uint256 stepGasStart = gasleft();
            
            _executeStep(flowId, i);
            
            execution.steps[i].completed = true;
            execution.steps[i].timestamp = block.timestamp;
            
            uint256 stepGasUsed = stepGasStart - gasleft();
            
            emit StepCompleted(flowId, execution.steps[i].stepType, stepGasUsed);
        }
    }
    
    function _executeStep(uint256 flowId, uint256 stepIndex) internal {
        FlowExecution storage execution = executions[flowId];
        RebalanceStep storage step = execution.steps[stepIndex];
        
        if (step.stepType == 0) {
            // Analyze step
            _executeAnalyzeStep(execution.tokenId, step.data);
        } else if (step.stepType == 1) {
            // Optimize step
            _executeOptimizeStep(execution.tokenId, step.data);
        } else if (step.stepType == 2) {
            // Execute step
            _executeRebalanceStep(execution.tokenId, step.data);
        } else if (step.stepType == 3) {
            // Verify step
            _executeVerifyStep(execution.tokenId, step.data);
        }
    }
    
    function _executeAnalyzeStep(uint256 tokenId, bytes memory data) internal view {
        // Get position info
        AutoRebalanceManager.PositionInfo memory position = rebalanceManager.getPositionInfo(tokenId);
        
        // Check if pool data is fresh
        require(
            tickOptimizer.isPoolDataFresh(position.token0, position.token1, position.fee),
            "Pool data not fresh"
        );
        
        // Validate gas price
        require(tx.gasprice <= config.maxGasPrice, "Gas price too high");
    }
    
    function _executeOptimizeStep(uint256 tokenId, bytes memory data) internal view {
        AutoRebalanceManager.PositionInfo memory position = rebalanceManager.getPositionInfo(tokenId);
        
        // Get optimal tick range
        (int24 suggestedTickLower, int24 suggestedTickUpper,) = 
            rebalanceManager.getRebalanceParams(tokenId);
        
        // Validate the suggested range
        require(suggestedTickLower < suggestedTickUpper, "Invalid tick range");
        
        // Store optimized parameters in step data
        // In a real implementation, this would encode the parameters
    }
    
    function _executeRebalanceStep(uint256 tokenId, bytes memory data) internal {
        // Decode rebalance parameters from data
        (int24 newTickLower, int24 newTickUpper, uint256 amount0Min, uint256 amount1Min, uint256 deadline) = 
            abi.decode(data, (int24, int24, uint256, uint256, uint256));
        
        // Execute the rebalance
        AutoRebalanceManager.RebalanceParams memory params = AutoRebalanceManager.RebalanceParams({
            tokenId: tokenId,
            newTickLower: newTickLower,
            newTickUpper: newTickUpper,
            amount0Min: amount0Min,
            amount1Min: amount1Min,
            deadline: deadline,
            collectFees: true
        });
        
        rebalanceManager.executeRebalance(params);
    }
    
    function _executeVerifyStep(uint256 tokenId, bytes memory data) internal view {
        // Verify the rebalance was successful
        AutoRebalanceManager.PositionInfo memory position = rebalanceManager.getPositionInfo(tokenId);
        
        require(position.isActive, "Position not active after rebalance");
        require(position.liquidity > 0, "No liquidity after rebalance");
        
        // Check if the new position is profitable
        // This would involve calculating expected returns vs costs
    }
    
    function _createRebalanceSteps(uint256 flowId, uint256 tokenId) internal {
        FlowExecution storage execution = executions[flowId];
        
        // Step 1: Analyze
        execution.steps.push(RebalanceStep({
            stepType: 0,
            data: abi.encode(tokenId),
            gasEstimate: 50000,
            completed: false,
            timestamp: 0
        }));
        
        // Step 2: Optimize
        execution.steps.push(RebalanceStep({
            stepType: 1,
            data: abi.encode(tokenId),
            gasEstimate: 100000,
            completed: false,
            timestamp: 0
        }));
        
        // Step 3: Execute
        execution.steps.push(RebalanceStep({
            stepType: 2,
            data: abi.encode(tokenId, int24(0), int24(0), uint256(0), uint256(0), block.timestamp + 1 hours),
            gasEstimate: 300000,
            completed: false,
            timestamp: 0
        }));
        
        // Step 4: Verify
        execution.steps.push(RebalanceStep({
            stepType: 3,
            data: abi.encode(tokenId),
            gasEstimate: 50000,
            completed: false,
            timestamp: 0
        }));
    }
    
    function getFlowExecution(uint256 flowId) external view returns (FlowExecution memory) {
        return executions[flowId];
    }
    
    function getUserFlows(address user) external view returns (uint256[] memory) {
        return userFlows[user];
    }
    
    function getActiveFlow(uint256 tokenId) external view returns (uint256) {
        return positionToFlow[tokenId];
    }
    
    function cancelFlow(uint256 flowId) external onlyRole(FLOW_MANAGER_ROLE) {
        FlowExecution storage execution = executions[flowId];
        require(execution.flowId != 0, "Flow does not exist");
        require(execution.endTime == 0, "Flow already finished");
        
        execution.success = false;
        execution.errorMessage = "Cancelled by manager";
        execution.endTime = block.timestamp;
        
        positionToFlow[execution.tokenId] = 0;
        
        emit FlowCompleted(flowId, false, execution.totalGasUsed);
    }
    
    function updateFlowConfig(
        uint256 _maxSlippage,
        uint256 _minProfitThreshold,
        uint256 _maxGasPrice,
        uint256 _rebalanceInterval
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_maxSlippage <= 2000, "Slippage too high"); // Max 20%
        require(_minProfitThreshold <= 1000, "Profit threshold too high"); // Max 10%
        
        config.maxSlippage = _maxSlippage;
        config.minProfitThreshold = _minProfitThreshold;
        config.maxGasPrice = _maxGasPrice;
        config.rebalanceInterval = _rebalanceInterval;
        
        emit FlowConfigUpdated(_maxSlippage, _minProfitThreshold, _maxGasPrice);
    }
    
    function toggleAutoExecution(bool enabled) external onlyRole(DEFAULT_ADMIN_ROLE) {
        config.enableAutoExecution = enabled;
    }
    
    function toggleEmergencyStop(bool enabled) external onlyRole(DEFAULT_ADMIN_ROLE) {
        config.enableEmergencyStop = enabled;
    }
    
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }
    
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
    
    function getFlowStats() external view returns (
        uint256 totalFlows,
        uint256 successfulFlows,
        uint256 avgGasUsed,
        uint256 totalSaved
    ) {
        totalFlows = nextFlowId - 1;
        successfulFlows = totalFlowsExecuted;
        avgGasUsed = totalFlows > 0 ? totalGasSaved / totalFlows : 0;
        totalSaved = totalGasSaved;
    }
    
    function emergencyWithdraw(address token, uint256 amount) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        IERC20(token).safeTransfer(msg.sender, amount);
    }
}
