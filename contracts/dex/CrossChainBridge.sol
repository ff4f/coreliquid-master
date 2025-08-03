// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "../interfaces/ICrossChainBridge.sol";
import "../interfaces/IOracle.sol";

/**
 * @title CrossChainBridge
 * @dev Comprehensive cross-chain bridge system for CoreLiquid Protocol
 * @author CoreLiquid Protocol
 */
contract CrossChainBridge is ICrossChainBridge, AccessControl, ReentrancyGuard, Pausable, EIP712 {
    using SafeERC20 for IERC20;
    using ECDSA for bytes32;

    // Roles
    bytes32 public constant BRIDGE_MANAGER_ROLE = keccak256("BRIDGE_MANAGER_ROLE");
    bytes32 public constant VALIDATOR_ROLE = keccak256("VALIDATOR_ROLE");
    bytes32 public constant RELAYER_ROLE = keccak256("RELAYER_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");

    // Constants
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant PRECISION = 1e18;
    uint256 public constant MAX_CHAINS = 50;
    uint256 public constant MAX_VALIDATORS = 100;
    uint256 public constant MIN_VALIDATORS = 3;
    uint256 public constant VALIDATION_THRESHOLD = 6700; // 67%
    uint256 public constant MAX_BRIDGE_FEE = 1000; // 10%
    uint256 public constant CHALLENGE_PERIOD = 1 hours;

    // External contracts
    IOracle public immutable oracle;

    // Storage mappings
    mapping(uint256 => ChainConfig) public chainConfigs;
    mapping(address => TokenConfig) public tokenConfigs;
    mapping(bytes32 => BridgeTransaction) public bridgeTransactions;
    mapping(address => ValidatorInfo) public validators;
    mapping(bytes32 => ICrossChainBridge.BridgeValidationResult) public validationResults;
    mapping(uint256 => RelayerInfo) public relayers;
    mapping(bytes32 => SecurityConfig) public securityConfigs;
    mapping(address => LiquidityPool) public liquidityPools;
    mapping(bytes32 => FeeStructure) public feeStructures;
    mapping(address => ICrossChainBridge.BridgeMetrics) public bridgeMetrics;
    mapping(uint256 => uint256[]) public chainRoutes;
    mapping(bytes32 => bytes32[]) public transactionValidations;
    mapping(address => mapping(uint256 => uint256)) public userChainBalances;
    mapping(bytes32 => uint256) public transactionFees;
    
    // Global arrays
    uint256[] public supportedChains;
    address[] public supportedTokens;
    address[] public allValidators;
    uint256[] public allRelayers;
    bytes32[] public allTransactions;
    bytes32[] public pendingTransactions;
    
    // Bridge configuration
    BridgeConfig public config;
    
    // Counters
    uint256 public totalChains;
    uint256 public totalTokens;
    uint256 public totalValidators;
    uint256 public totalRelayers;
    uint256 public totalTransactions;
    uint256 public totalVolume;

    // State variables
    bool public emergencyMode;
    uint256 public lastGlobalUpdate;
    mapping(uint256 => bool) public isChainActive;
    mapping(address => bool) public isTokenActive;
    mapping(address => bool) public isValidatorActive;
    mapping(bytes32 => bool) public isTransactionProcessed;

    constructor(
        string memory name,
        string memory version,
        address _oracle,
        uint256 _baseFee,
        uint256 _validationThreshold
    ) EIP712(name, version) {
        require(_oracle != address(0), "Invalid oracle");
        require(_baseFee <= MAX_BRIDGE_FEE, "Fee too high");
        require(_validationThreshold >= 5000 && _validationThreshold <= 10000, "Invalid threshold");
        
        oracle = IOracle(_oracle);
        
        config = BridgeConfig({
            baseFee: _baseFee,
            validationThreshold: _validationThreshold,
            challengePeriod: CHALLENGE_PERIOD,
            maxTransactionAmount: 1000000e18, // $1M
            minTransactionAmount: 1e18, // $1
            emergencyWithdrawDelay: 24 hours,
            relayerReward: 100, // 1%
            validatorReward: 50, // 0.5%
            isActive: true
        });
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(BRIDGE_MANAGER_ROLE, msg.sender);
        _grantRole(VALIDATOR_ROLE, msg.sender);
        _grantRole(RELAYER_ROLE, msg.sender);
        _grantRole(EMERGENCY_ROLE, msg.sender);
        _grantRole(ORACLE_ROLE, msg.sender);
    }

    // Core bridge functions
    function initiateBridge(
        address token,
        uint256 amount,
        uint256 targetChain,
        address recipient,
        bytes calldata data
    ) external override payable nonReentrant whenNotPaused returns (bytes32) {
        require(isTokenActive[token], "Token not supported");
        require(isChainActive[targetChain], "Target chain not supported");
        require(amount >= config.minTransactionAmount, "Amount too small");
        require(amount <= config.maxTransactionAmount, "Amount too large");
        require(recipient != address(0), "Invalid recipient");
        
        TokenConfig storage tokenConfig = tokenConfigs[token];
        require(tokenConfig.isActive, "Token inactive");
        
        ChainConfig storage targetChainConfig = chainConfigs[targetChain];
        require(targetChainConfig.isActive, "Target chain inactive");
        
        // Calculate fees
        uint256 bridgeFee = _calculateBridgeFee(token, amount, targetChain);
        require(msg.value >= bridgeFee, "Insufficient fee");
        
        // Transfer tokens to bridge
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        
        // Generate transaction ID
        bytes32 transactionId = keccak256(abi.encodePacked(
            msg.sender,
            token,
            amount,
            targetChain,
            recipient,
            block.timestamp,
            totalTransactions
        ));
        
        // Create bridge transaction
        BridgeTransaction storage transaction = bridgeTransactions[transactionId];
        transaction.transactionId = transactionId;
        transaction.sourceChain = block.chainid;
        transaction.targetChain = targetChain;
        transaction.token = token;
        transaction.amount = amount;
        transaction.sender = msg.sender;
        transaction.recipient = recipient;
        transaction.fee = bridgeFee;
        transaction.timestamp = block.timestamp;
        transaction.status = TransactionStatus.PENDING;
        transaction.data = data;
        
        // Add to tracking arrays
        allTransactions.push(transactionId);
        pendingTransactions.push(transactionId);
        transactionFees[transactionId] = bridgeFee;
        
        // Update metrics
        BridgeMetrics storage metrics = bridgeMetrics[msg.sender];
        metrics.user = msg.sender;
        metrics.totalTransactions++;
        metrics.totalVolume += amount;
        metrics.lastTransaction = block.timestamp;
        
        totalTransactions++;
        totalVolume += amount;
        
        emit BridgeInitiated(
            transactionId,
            msg.sender,
            token,
            amount,
            block.chainid,
            targetChain,
            recipient,
            block.timestamp
        );
        
        return transactionId;
    }

    function validateTransaction(
        bytes32 transactionId,
        bool isValid,
        bytes calldata signature
    ) external override onlyRole(VALIDATOR_ROLE) {
        require(!isTransactionProcessed[transactionId], "Transaction already processed");
        
        BridgeTransaction storage transaction = bridgeTransactions[transactionId];
        require(transaction.transactionId != bytes32(0), "Transaction not found");
        require(transaction.status == TransactionStatus.PENDING, "Transaction not pending");
        
        ValidatorInfo storage validator = validators[msg.sender];
        require(validator.isActive, "Validator not active");
        
        // Verify signature
        bytes32 messageHash = _hashTypedDataV4(keccak256(abi.encode(
            keccak256("ValidateTransaction(bytes32 transactionId,bool isValid,uint256 nonce)"),
            transactionId,
            isValid,
            validator.nonce
        )));
        
        require(messageHash.recover(signature) == msg.sender, "Invalid signature");
        
        // Create validation result
        bytes32 validationId = keccak256(abi.encodePacked(transactionId, msg.sender, block.timestamp));
        ICrossChainBridge.BridgeValidationResult storage result = validationResults[validationId];
        result.validationId = validationId;
        result.transactionId = transactionId;
        result.validator = msg.sender;
        result.isValid = isValid;
        result.timestamp = block.timestamp;
        result.signature = signature;
        
        // Add to transaction validations
        transactionValidations[transactionId].push(validationId);
        
        // Update validator info
        validator.totalValidations++;
        validator.nonce++;
        validator.lastValidation = block.timestamp;
        
        // Check if enough validations
        _checkValidationThreshold(transactionId);
        
        emit TransactionValidated(transactionId, msg.sender, isValid, block.timestamp);
    }

    function executeTransaction(
        bytes32 transactionId
    ) external override onlyRole(RELAYER_ROLE) nonReentrant {
        require(!isTransactionProcessed[transactionId], "Transaction already processed");
        
        BridgeTransaction storage transaction = bridgeTransactions[transactionId];
        require(transaction.transactionId != bytes32(0), "Transaction not found");
        require(transaction.status == TransactionStatus.VALIDATED, "Transaction not validated");
        require(transaction.targetChain == block.chainid, "Wrong target chain");
        
        // Check if enough time has passed for challenge period
        require(block.timestamp >= transaction.validatedAt + config.challengePeriod, "Challenge period not over");
        
        TokenConfig storage tokenConfig = tokenConfigs[transaction.token];
        require(tokenConfig.isActive, "Token inactive");
        
        // Execute the transaction
        if (tokenConfig.bridgeType == BridgeType.LOCK_MINT) {
            // Mint tokens on target chain (simplified)
            _mintTokens(transaction.token, transaction.recipient, transaction.amount);
        } else if (tokenConfig.bridgeType == BridgeType.BURN_MINT) {
            // Mint tokens on target chain (simplified)
            _mintTokens(transaction.token, transaction.recipient, transaction.amount);
        } else {
            // Transfer from liquidity pool
            LiquidityPool storage pool = liquidityPools[transaction.token];
            require(pool.balance >= transaction.amount, "Insufficient liquidity");
            
            pool.balance -= transaction.amount;
            IERC20(transaction.token).safeTransfer(transaction.recipient, transaction.amount);
        }
        
        // Update transaction status
        transaction.status = TransactionStatus.EXECUTED;
        transaction.executedAt = block.timestamp;
        transaction.executor = msg.sender;
        isTransactionProcessed[transactionId] = true;
        
        // Remove from pending transactions
        _removePendingTransaction(transactionId);
        
        // Update relayer info
        RelayerInfo storage relayer = relayers[0]; // Simplified
        relayer.totalExecutions++;
        relayer.lastExecution = block.timestamp;
        
        // Distribute rewards
        _distributeRewards(transactionId);
        
        emit TransactionExecuted(transactionId, msg.sender, block.timestamp);
    }

    function challengeTransaction(
        bytes32 transactionId,
        string calldata reason,
        bytes calldata evidence
    ) external override {
        BridgeTransaction storage transaction = bridgeTransactions[transactionId];
        require(transaction.transactionId != bytes32(0), "Transaction not found");
        require(transaction.status == TransactionStatus.VALIDATED, "Transaction not validated");
        require(block.timestamp < transaction.validatedAt + config.challengePeriod, "Challenge period over");
        require(bytes(reason).length > 0, "Invalid reason");
        
        // Update transaction status
        transaction.status = TransactionStatus.CHALLENGED;
        transaction.challenger = msg.sender;
        transaction.challengeReason = reason;
        transaction.challengeEvidence = evidence;
        transaction.challengedAt = block.timestamp;
        
        emit TransactionChallenged(transactionId, msg.sender, reason, block.timestamp);
    }

    function resolveChallenge(
        bytes32 transactionId,
        bool upholdChallenge,
        string calldata resolution
    ) external override onlyRole(BRIDGE_MANAGER_ROLE) {
        BridgeTransaction storage transaction = bridgeTransactions[transactionId];
        require(transaction.transactionId != bytes32(0), "Transaction not found");
        require(transaction.status == TransactionStatus.CHALLENGED, "Transaction not challenged");
        
        if (upholdChallenge) {
            transaction.status = TransactionStatus.FAILED;
            // Refund tokens to sender
            _refundTransaction(transactionId);
        } else {
            transaction.status = TransactionStatus.VALIDATED;
        }
        
        transaction.resolution = resolution;
        transaction.resolvedAt = block.timestamp;
        transaction.resolver = msg.sender;
        
        emit ChallengeResolved(transactionId, upholdChallenge, resolution, msg.sender, block.timestamp);
    }

    function addLiquidity(
        address token,
        uint256 amount
    ) external override nonReentrant {
        require(isTokenActive[token], "Token not supported");
        require(amount > 0, "Invalid amount");
        
        TokenConfig storage tokenConfig = tokenConfigs[token];
        require(tokenConfig.bridgeType == BridgeType.LIQUIDITY_POOL, "Token doesn't use liquidity pool");
        
        // Transfer tokens to bridge
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        
        // Update liquidity pool
        LiquidityPool storage pool = liquidityPools[token];
        pool.token = token;
        pool.balance += amount;
        pool.totalDeposits += amount;
        pool.lastUpdate = block.timestamp;
        
        // Track user contribution (simplified)
        userChainBalances[msg.sender][block.chainid] += amount;
        
        emit LiquidityAdded(msg.sender, token, amount, block.timestamp);
    }

    function removeLiquidity(
        address token,
        uint256 amount
    ) external override nonReentrant {
        require(isTokenActive[token], "Token not supported");
        require(amount > 0, "Invalid amount");
        require(userChainBalances[msg.sender][block.chainid] >= amount, "Insufficient balance");
        
        LiquidityPool storage pool = liquidityPools[token];
        require(pool.balance >= amount, "Insufficient pool liquidity");
        
        // Update pool and user balance
        pool.balance -= amount;
        pool.totalWithdrawals += amount;
        pool.lastUpdate = block.timestamp;
        userChainBalances[msg.sender][block.chainid] -= amount;
        
        // Transfer tokens back
        IERC20(token).safeTransfer(msg.sender, amount);
        
        emit LiquidityRemoved(msg.sender, token, amount, block.timestamp);
    }

    // Configuration functions
    function addSupportedChain(
        uint256 chainId,
        string calldata name,
        string calldata rpcUrl,
        uint256 blockTime,
        uint256 confirmations
    ) external override onlyRole(BRIDGE_MANAGER_ROLE) {
        require(chainId != 0, "Invalid chain ID");
        require(bytes(name).length > 0, "Invalid name");
        require(totalChains < MAX_CHAINS, "Too many chains");
        require(!isChainActive[chainId], "Chain already supported");
        
        ChainConfig storage chainConfig = chainConfigs[chainId];
        chainConfig.chainId = chainId;
        chainConfig.name = name;
        chainConfig.rpcUrl = rpcUrl;
        chainConfig.blockTime = blockTime;
        chainConfig.confirmations = confirmations;
        chainConfig.isActive = true;
        
        supportedChains.push(chainId);
        isChainActive[chainId] = true;
        totalChains++;
        
        emit ChainAdded(chainId, name, block.timestamp);
    }

    function addSupportedToken(
        address token,
        string calldata name,
        string calldata symbol,
        uint8 decimals,
        BridgeType bridgeType
    ) external override onlyRole(BRIDGE_MANAGER_ROLE) {
        require(token != address(0), "Invalid token");
        require(bytes(name).length > 0, "Invalid name");
        require(!isTokenActive[token], "Token already supported");
        
        TokenConfig storage tokenConfig = tokenConfigs[token];
        tokenConfig.token = token;
        tokenConfig.name = name;
        tokenConfig.symbol = symbol;
        tokenConfig.decimals = decimals;
        tokenConfig.bridgeType = bridgeType;
        tokenConfig.isActive = true;
        
        supportedTokens.push(token);
        isTokenActive[token] = true;
        totalTokens++;
        
        emit TokenAdded(token, name, symbol, bridgeType, block.timestamp);
    }

    function addValidator(
        address validator,
        uint256 stake
    ) external override onlyRole(BRIDGE_MANAGER_ROLE) {
        require(validator != address(0), "Invalid validator");
        require(stake > 0, "Invalid stake");
        require(totalValidators < MAX_VALIDATORS, "Too many validators");
        require(!isValidatorActive[validator], "Validator already active");
        
        ValidatorInfo storage validatorInfo = validators[validator];
        validatorInfo.validator = validator;
        validatorInfo.stake = stake;
        validatorInfo.joinedAt = block.timestamp;
        validatorInfo.isActive = true;
        
        allValidators.push(validator);
        isValidatorActive[validator] = true;
        totalValidators++;
        
        emit ValidatorAdded(validator, stake, block.timestamp);
    }

    function removeValidator(
        address validator
    ) external override onlyRole(BRIDGE_MANAGER_ROLE) {
        require(isValidatorActive[validator], "Validator not active");
        require(totalValidators > MIN_VALIDATORS, "Cannot remove validator");
        
        validators[validator].isActive = false;
        validators[validator].removedAt = block.timestamp;
        isValidatorActive[validator] = false;
        totalValidators--;
        
        emit ValidatorRemoved(validator, block.timestamp);
    }

    function setSecurityConfig(
        bytes32 configId,
        uint256 maxAmount,
        uint256 dailyLimit,
        uint256 validationThreshold
    ) external override onlyRole(BRIDGE_MANAGER_ROLE) {
        require(configId != bytes32(0), "Invalid config ID");
        require(maxAmount > 0, "Invalid max amount");
        require(dailyLimit > 0, "Invalid daily limit");
        require(validationThreshold >= 5000 && validationThreshold <= 10000, "Invalid threshold");
        
        SecurityConfig storage securityConfig = securityConfigs[configId];
        securityConfig.configId = configId;
        securityConfig.maxTransactionAmount = maxAmount;
        securityConfig.dailyLimit = dailyLimit;
        securityConfig.validationThreshold = validationThreshold;
        securityConfig.isActive = true;
        
        emit SecurityConfigSet(configId, maxAmount, dailyLimit, validationThreshold, block.timestamp);
    }

    // Emergency functions
    function emergencyPause() external override onlyRole(EMERGENCY_ROLE) {
        emergencyMode = true;
        _pause();
        
        emit EmergencyPause(msg.sender, block.timestamp);
    }

    function emergencyUnpause() external override onlyRole(EMERGENCY_ROLE) {
        emergencyMode = false;
        _unpause();
        
        emit EmergencyUnpause(msg.sender, block.timestamp);
    }

    function emergencyWithdraw(
        address token,
        uint256 amount,
        address recipient
    ) external override onlyRole(EMERGENCY_ROLE) {
        require(emergencyMode, "Not in emergency mode");
        require(token != address(0), "Invalid token");
        require(amount > 0, "Invalid amount");
        require(recipient != address(0), "Invalid recipient");
        
        IERC20(token).safeTransfer(recipient, amount);
        
        emit EmergencyWithdraw(token, amount, recipient, msg.sender, block.timestamp);
    }

    // View functions
    function getChainConfig(uint256 chainId) external view override returns (ChainConfig memory) {
        return chainConfigs[chainId];
    }

    function getTokenConfig(address token) external view override returns (TokenConfig memory) {
        return tokenConfigs[token];
    }

    function getBridgeTransaction(bytes32 transactionId) external view override returns (BridgeTransaction memory) {
        return bridgeTransactions[transactionId];
    }

    function getValidatorInfo(address validator) external view override returns (ValidatorInfo memory) {
        return validators[validator];
    }

    function getValidationResult(bytes32 validationId) external view override returns (ICrossChainBridge.BridgeValidationResult memory) {
        return validationResults[validationId];
    }

    function getRelayerInfo(uint256 relayerId) external view override returns (RelayerInfo memory) {
        return relayers[relayerId];
    }

    function getSecurityConfig(bytes32 configId) external view override returns (SecurityConfig memory) {
        return securityConfigs[configId];
    }

    function getLiquidityPool(address token) external view override returns (LiquidityPool memory) {
        return liquidityPools[token];
    }

    function getFeeStructure(bytes32 feeId) external view override returns (FeeStructure memory) {
        return feeStructures[feeId];
    }

    function getBridgeMetrics(address user) external view override returns (ICrossChainBridge.BridgeMetrics memory) {
        return bridgeMetrics[user];
    }

    function getBridgeConfig() external view override returns (BridgeConfig memory) {
        return config;
    }

    function getSupportedChains() external view override returns (uint256[] memory) {
        return supportedChains;
    }

    function getSupportedTokens() external view override returns (address[] memory) {
        return supportedTokens;
    }

    function getAllValidators() external view override returns (address[] memory) {
        return allValidators;
    }

    function getPendingTransactions() external view override returns (bytes32[] memory) {
        return pendingTransactions;
    }

    function getTransactionValidations(bytes32 transactionId) external view override returns (bytes32[] memory) {
        return transactionValidations[transactionId];
    }

    function getSystemMetrics() external view override returns (ICrossChainBridge.SystemMetrics memory) {
        return ICrossChainBridge.SystemMetrics({
            totalChains: totalChains,
            totalTokens: totalTokens,
            totalValidators: totalValidators,
            totalTransactions: totalTransactions,
            totalVolume: totalVolume,
            pendingTransactions: pendingTransactions.length,
            systemHealth: _calculateSystemHealth(),
            lastUpdate: block.timestamp
        });
    }

    // Internal functions
    function _calculateBridgeFee(
        address token,
        uint256 amount,
        uint256 targetChain
    ) internal view returns (uint256) {
        // Base fee calculation
        uint256 baseFee = (amount * config.baseFee) / BASIS_POINTS;
        
        // Add chain-specific fees
        ChainConfig storage chainConfig = chainConfigs[targetChain];
        uint256 chainFee = (amount * chainConfig.fee) / BASIS_POINTS;
        
        // Add token-specific fees
        TokenConfig storage tokenConfig = tokenConfigs[token];
        uint256 tokenFee = (amount * tokenConfig.fee) / BASIS_POINTS;
        
        return baseFee + chainFee + tokenFee;
    }

    function _checkValidationThreshold(bytes32 transactionId) internal {
        bytes32[] storage validations = transactionValidations[transactionId];
        
        if (validations.length < MIN_VALIDATORS) {
            return;
        }
        
        uint256 validCount = 0;
        for (uint256 i = 0; i < validations.length; i++) {
            ICrossChainBridge.BridgeValidationResult storage result = validationResults[validations[i]];
            if (result.isValid) {
                validCount++;
            }
        }
        
        uint256 validationPercentage = (validCount * BASIS_POINTS) / validations.length;
        
        if (validationPercentage >= config.validationThreshold) {
            BridgeTransaction storage transaction = bridgeTransactions[transactionId];
            transaction.status = TransactionStatus.VALIDATED;
            transaction.validatedAt = block.timestamp;
            
            emit TransactionValidationComplete(transactionId, validCount, validations.length, block.timestamp);
        }
    }

    function _removePendingTransaction(bytes32 transactionId) internal {
        for (uint256 i = 0; i < pendingTransactions.length; i++) {
            if (pendingTransactions[i] == transactionId) {
                pendingTransactions[i] = pendingTransactions[pendingTransactions.length - 1];
                pendingTransactions.pop();
                break;
            }
        }
    }

    function _mintTokens(address token, address recipient, uint256 amount) internal {
        // Simplified minting - in real implementation, this would interact with token contract
        // For now, we'll transfer from liquidity pool
        LiquidityPool storage pool = liquidityPools[token];
        require(pool.balance >= amount, "Insufficient liquidity for minting");
        
        pool.balance -= amount;
        IERC20(token).safeTransfer(recipient, amount);
    }

    function _refundTransaction(bytes32 transactionId) internal {
        BridgeTransaction storage transaction = bridgeTransactions[transactionId];
        
        // Refund tokens to sender
        IERC20(transaction.token).safeTransfer(transaction.sender, transaction.amount);
        
        // Refund bridge fee
        if (transaction.fee > 0) {
            payable(transaction.sender).transfer(transaction.fee);
        }
    }

    function _distributeRewards(bytes32 transactionId) internal {
        uint256 fee = transactionFees[transactionId];
        
        if (fee > 0) {
            // Distribute to validators
            uint256 validatorReward = (fee * config.validatorReward) / BASIS_POINTS;
            uint256 validatorCount = transactionValidations[transactionId].length;
            
            if (validatorCount > 0) {
                uint256 rewardPerValidator = validatorReward / validatorCount;
                
                for (uint256 i = 0; i < transactionValidations[transactionId].length; i++) {
                    ICrossChainBridge.BridgeValidationResult storage result = validationResults[transactionValidations[transactionId][i]];
                    if (result.isValid) {
                        payable(result.validator).transfer(rewardPerValidator);
                    }
                }
            }
            
            // Distribute to relayer
            uint256 relayerReward = (fee * config.relayerReward) / BASIS_POINTS;
            payable(msg.sender).transfer(relayerReward);
        }
    }

    function _calculateSystemHealth() internal view returns (uint256) {
        if (totalChains == 0 || totalValidators == 0) return 0;
        
        uint256 activeChains = 0;
        uint256 activeValidators = 0;
        
        for (uint256 i = 0; i < supportedChains.length; i++) {
            if (isChainActive[supportedChains[i]]) {
                activeChains++;
            }
        }
        
        for (uint256 i = 0; i < allValidators.length; i++) {
            if (isValidatorActive[allValidators[i]]) {
                activeValidators++;
            }
        }
        
        uint256 chainHealth = (activeChains * BASIS_POINTS) / totalChains;
        uint256 validatorHealth = (activeValidators * BASIS_POINTS) / totalValidators;
        
        return (chainHealth + validatorHealth) / 2;
    }

    // Configuration update functions
    function updateBridgeConfig(
        BridgeConfig calldata newConfig
    ) external onlyRole(BRIDGE_MANAGER_ROLE) {
        require(newConfig.baseFee <= MAX_BRIDGE_FEE, "Fee too high");
        require(newConfig.validationThreshold >= 5000 && newConfig.validationThreshold <= 10000, "Invalid threshold");
        require(newConfig.challengePeriod >= 1 hours && newConfig.challengePeriod <= 7 days, "Invalid challenge period");
        
        config = newConfig;
        
        emit BridgeConfigUpdated(block.timestamp);
    }

    // Emergency functions
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
}
