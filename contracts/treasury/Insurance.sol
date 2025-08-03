// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "../interfaces/IInsurance.sol";
import "../interfaces/IOracle.sol";
import "../interfaces/IRiskManagement.sol";

/**
 * @title Insurance
 * @dev Comprehensive insurance system for CoreLiquid Protocol
 * @author CoreLiquid Protocol
 */
abstract contract Insurance is AccessControl, ReentrancyGuard, Pausable, EIP712, IInsurance {
    using SafeERC20 for IERC20;
    using ECDSA for bytes32;

    // Roles
    bytes32 public constant INSURANCE_MANAGER_ROLE = keccak256("INSURANCE_MANAGER_ROLE");
    bytes32 public constant UNDERWRITER_ROLE = keccak256("UNDERWRITER_ROLE");
    bytes32 public constant CLAIMS_ASSESSOR_ROLE = keccak256("CLAIMS_ASSESSOR_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");

    // Constants
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant PRECISION = 1e18;
    uint256 public constant MAX_POLICIES = 10000;
    uint256 public constant MAX_COVERAGE_RATIO = 9000; // 90%
    uint256 public constant MIN_COVERAGE_RATIO = 1000; // 10%
    uint256 public constant MAX_PREMIUM_RATE = 2000; // 20%
    uint256 public constant MIN_PREMIUM_RATE = 10; // 0.1%
    uint256 public constant CLAIM_PERIOD = 30 days;
    uint256 public constant ASSESSMENT_PERIOD = 7 days;

    // External contracts
    IOracle public immutable oracle;
    IRiskManagement public immutable riskManagement;

    // Storage mappings
    mapping(bytes32 => IInsurance.InsurancePolicy) public policies;
    mapping(bytes32 => IInsurance.Claim) public claims;
    mapping(address => IInsurance.Coverage) public coverages;
    mapping(bytes32 => IInsurance.Premium) public premiums;
    mapping(address => IInsurance.Underwriter) public underwriters;
    mapping(bytes32 => IInsurance.RiskAssessment) public riskAssessments;
    mapping(address => IInsurance.InsurancePool) public pools;
    mapping(bytes32 => IInsurance.ClaimAssessment) public claimAssessments;
    mapping(address => IInsurance.InsuranceMetrics) public insuranceMetrics;
    mapping(bytes32 => IInsurance.PolicyMetrics) public policyMetrics;
    mapping(address => bytes32[]) public userPolicies;
    mapping(address => bytes32[]) public userClaims;
    mapping(bytes32 => bytes32[]) public policyClaimsHistory;
    mapping(address => mapping(address => uint256)) public poolBalances;
    
    // Global arrays
    bytes32[] public allPolicies;
    bytes32[] public allClaims;
    address[] public allCoverageHolders;
    address[] public allUnderwriters;
    bytes32[] public allAssessments;
    address[] public allPools;
    bytes32[] public activePolicies;
    bytes32[] public pendingClaims;
    
    // Insurance configuration
    IInsurance.InsuranceConfig public config;
    
    // Counters
    uint256 public totalPolicies;
    uint256 public totalClaims;
    uint256 public totalCoverageHolders;
    uint256 public totalUnderwriters;
    uint256 public totalPools;
    uint256 public totalPremiumsCollected;
    uint256 public totalClaimsPaid;
    uint256 public policyCounter;
    uint256 public claimCounter;

    // State variables
    bool public emergencyMode;
    uint256 public lastGlobalUpdate;
    mapping(bytes32 => bool) public isPolicyActive;
    mapping(bytes32 => bool) public isClaimActive;
    mapping(address => bool) public isCoverageActive;
    mapping(address => bool) public isUnderwriterActive;
    mapping(address => bool) public isPoolActive;

    constructor(
        string memory name,
        string memory version,
        address _oracle,
        address _riskManagement,
        uint256 _basePremiumRate,
        uint256 _maxCoverageRatio
    ) EIP712(name, version) {
        require(_oracle != address(0), "Invalid oracle");
        require(_riskManagement != address(0), "Invalid risk management");
        require(_basePremiumRate >= MIN_PREMIUM_RATE && _basePremiumRate <= MAX_PREMIUM_RATE, "Invalid premium rate");
        require(_maxCoverageRatio >= MIN_COVERAGE_RATIO && _maxCoverageRatio <= MAX_COVERAGE_RATIO, "Invalid coverage ratio");
        
        oracle = IOracle(_oracle);
        riskManagement = IRiskManagement(_riskManagement);
        
        config = IInsurance.InsuranceConfig({
            basePremiumRate: _basePremiumRate,
            maxCoverageRatio: _maxCoverageRatio,
            minCoverageAmount: 1000e18, // $1000
            maxCoverageAmount: 10000000e18, // $10M
            claimAssessmentPeriod: ASSESSMENT_PERIOD,
            maxClaimAmount: 5000000e18, // $5M
            underwriterStakeRequired: 10000e18, // $10K
            poolMinimumBalance: 100000e18, // $100K
            isActive: true
        });
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(INSURANCE_MANAGER_ROLE, msg.sender);
        _grantRole(UNDERWRITER_ROLE, msg.sender);
        _grantRole(CLAIMS_ASSESSOR_ROLE, msg.sender);
        _grantRole(EMERGENCY_ROLE, msg.sender);
        _grantRole(ORACLE_ROLE, msg.sender);
    }

    // Core insurance functions
    function createPolicy(
        address coverageAsset,
        uint256 coverageAmount,
        uint256 duration,
        IInsurance.PolicyType policyType,
        bytes calldata riskData
    ) external payable nonReentrant whenNotPaused returns (bytes32) {
        require(coverageAsset != address(0), "Invalid coverage asset");
        require(coverageAmount >= config.minCoverageAmount, "Coverage amount too small");
        require(coverageAmount <= config.maxCoverageAmount, "Coverage amount too large");
        require(duration > 0 && duration <= 365 days, "Invalid duration");
        require(totalPolicies < MAX_POLICIES, "Too many policies");
        
        // Perform risk assessment
        bytes32 assessmentId = _performRiskAssessment(msg.sender, coverageAsset, coverageAmount, riskData);
        IInsurance.RiskAssessment storage assessment = riskAssessments[assessmentId];
        
        // Calculate premium
        uint256 premiumAmount = _calculatePremium(coverageAmount, duration, assessment.riskScore, policyType);
        require(msg.value >= premiumAmount, "Insufficient premium payment");
        
        // Generate policy ID
        bytes32 policyId = keccak256(abi.encodePacked(
            msg.sender,
            coverageAsset,
            coverageAmount,
            block.timestamp,
            ++policyCounter
        ));
        
        // Create insurance policy
        IInsurance.InsurancePolicy storage policy = policies[policyId];
        policy.policyId = policyId;
        policy.policyholder = msg.sender;
        policy.coverageAsset = coverageAsset;
        policy.coverageAmount = coverageAmount;
        policy.premiumAmount = premiumAmount;
        policy.startTime = block.timestamp;
        policy.endTime = block.timestamp + duration;
        policy.policyType = policyType;
        policy.status = IInsurance.PolicyStatus.ACTIVE;
        policy.riskAssessmentId = assessmentId;
        policy.createdAt = block.timestamp;
        
        // Create premium record
        IInsurance.Premium storage premium = premiums[policyId];
        premium.policyId = policyId;
        premium.amount = premiumAmount;
        premium.paidAt = block.timestamp;
        premium.isPaid = true;
        
        // Update coverage
        IInsurance.Coverage storage coverage = coverages[msg.sender];
        coverage.holder = msg.sender;
        coverage.totalCoverage += coverageAmount;
        coverage.activePolicies++;
        coverage.lastUpdate = block.timestamp;
        
        if (!isCoverageActive[msg.sender]) {
            allCoverageHolders.push(msg.sender);
            isCoverageActive[msg.sender] = true;
            totalCoverageHolders++;
        }
        
        // Add to tracking arrays
        allPolicies.push(policyId);
        activePolicies.push(policyId);
        userPolicies[msg.sender].push(policyId);
        isPolicyActive[policyId] = true;
        
        // Update metrics
        IInsurance.InsuranceMetrics storage metrics = insuranceMetrics[msg.sender];
        metrics.user = msg.sender;
        metrics.totalPolicies++;
        metrics.totalPremiumsPaid += premiumAmount;
        metrics.lastPolicy = block.timestamp;
        
        IInsurance.PolicyMetrics storage policyMetrics_ = policyMetrics[policyId];
        policyMetrics_.lastUpdate = block.timestamp;
        policyMetrics_.totalPremiumPaid = premiumAmount;
        
        totalPolicies++;
        totalPremiumsCollected += premiumAmount;
        
        // Distribute premium to pools
        _distributePremiumToPools(premiumAmount);
        
        emit PolicyCreated(
            policyId,
            msg.sender,
            coverageAsset,
            coverageAmount,
            premiumAmount,
            block.timestamp,
            block.timestamp + duration
        );
        
        return policyId;
    }

    function fileClaim(
        bytes32 policyId,
        uint256 claimAmount,
        string calldata description,
        bytes calldata evidence
    ) external nonReentrant returns (bytes32) {
        require(isPolicyActive[policyId], "Policy not active");
        
        InsurancePolicy storage policy = policies[policyId];
        require(policy.policyId != bytes32(0), "Policy not found");
        require(policy.policyholder == msg.sender, "Not policy holder");
        require(policy.status == IInsurance.PolicyStatus.ACTIVE, "Policy not active");
        require(block.timestamp >= policy.startTime, "Policy not started");
        require(block.timestamp <= policy.endTime, "Policy expired");
        require(claimAmount > 0, "Invalid claim amount");
        require(claimAmount <= policy.coverageAmount, "Claim exceeds coverage");
        require(claimAmount <= config.maxClaimAmount, "Claim amount too large");
        require(bytes(description).length > 0, "Invalid description");
        
        // Generate claim ID
        bytes32 claimId = keccak256(abi.encodePacked(
            policyId,
            msg.sender,
            claimAmount,
            block.timestamp,
            ++claimCounter
        ));
        
        // Create claim
        IInsurance.Claim storage claim = claims[claimId];
        claim.claimId = claimId;
        claim.policyId = policyId;
        claim.claimant = msg.sender;
        claim.claimAmount = claimAmount;
        claim.description = description;
        claim.evidence = evidence;
        claim.filedAt = block.timestamp;
        claim.status = IInsurance.ClaimStatus.PENDING;
        
        // Add to tracking arrays
        allClaims.push(claimId);
        pendingClaims.push(claimId);
        userClaims[msg.sender].push(claimId);
        policyClaimsHistory[policyId].push(claimId);
        isClaimActive[claimId] = true;
        
        // Update metrics
        InsuranceMetrics storage metrics = insuranceMetrics[msg.sender];
        metrics.totalClaims++;
        metrics.lastClaim = block.timestamp;
        
        totalClaims++;
        
        emit ClaimFiled(
            claimId,
            policyId,
            msg.sender,
            claimAmount,
            description,
            block.timestamp
        );
        
        return claimId;
    }

    function assessClaim(
        bytes32 claimId,
        bool approved,
        uint256 approvedAmount,
        string calldata assessmentNotes
    ) external onlyRole(CLAIMS_ASSESSOR_ROLE) {
        require(isClaimActive[claimId], "Claim not active");
        
        Claim storage claim = claims[claimId];
        require(claim.claimId != bytes32(0), "Claim not found");
        require(claim.status == IInsurance.ClaimStatus.PENDING, "Claim not pending");
        require(block.timestamp <= claim.filedAt + config.claimAssessmentPeriod, "Assessment period expired");
        
        if (approved) {
            require(approvedAmount > 0, "Invalid approved amount");
            require(approvedAmount <= claim.claimAmount, "Approved amount exceeds claim");
            
            IInsurance.InsurancePolicy storage policy = policies[claim.policyId];
            require(approvedAmount <= policy.coverageAmount, "Approved amount exceeds coverage");
            
            claim.status = IInsurance.ClaimStatus.APPROVED;
            claim.approvedAmount = approvedAmount;
        } else {
            claim.status = IInsurance.ClaimStatus.REJECTED;
            claim.approvedAmount = 0;
        }
        
        claim.assessedAt = block.timestamp;
        claim.assessor = msg.sender;
        
        // Create assessment record
        bytes32 assessmentId = keccak256(abi.encodePacked(claimId, msg.sender, block.timestamp));
        ClaimAssessment storage assessment = claimAssessments[assessmentId];
        assessment.assessmentId = assessmentId;
        assessment.claimId = claimId;
        assessment.assessor = msg.sender;
        assessment.approved = approved;
        assessment.approvedAmount = approvedAmount;
        assessment.notes = assessmentNotes;
        assessment.assessedAt = block.timestamp;
        
        allAssessments.push(assessmentId);
        
        // Remove from pending claims
        _removePendingClaim(claimId);
        
        emit ClaimAssessed(
            claimId,
            msg.sender,
            approved,
            approvedAmount,
            assessmentNotes,
            block.timestamp
        );
        
        // Auto-process approved claims
        if (approved) {
            _processClaim(claimId);
        }
    }

    function processClaim(
        bytes32 claimId
    ) external onlyRole(CLAIMS_ASSESSOR_ROLE) nonReentrant {
        _processClaim(claimId);
    }

    function updateCoverage(
        address coverageAsset,
        uint256 newCoverageAmount
    ) external {
        require(isCoverageActive[msg.sender], "No active coverage");
        require(coverageAsset != address(0), "Invalid coverage asset");
        require(newCoverageAmount >= config.minCoverageAmount, "Coverage amount too small");
        require(newCoverageAmount <= config.maxCoverageAmount, "Coverage amount too large");
        
        Coverage storage coverage = coverages[msg.sender];
        uint256 oldCoverage = coverage.totalCoverage;
        
        coverage.totalCoverage = newCoverageAmount;
        coverage.lastUpdate = block.timestamp;
        
        emit CoverageUpdated(
            msg.sender,
            coverageAsset,
            oldCoverage,
            newCoverageAmount,
            block.timestamp
        );
    }

    function addUnderwriter(
        address underwriter,
        uint256 stakeAmount,
        uint256 capacity
    ) external onlyRole(INSURANCE_MANAGER_ROLE) {
        require(underwriter != address(0), "Invalid underwriter");
        require(stakeAmount >= config.underwriterStakeRequired, "Insufficient stake");
        require(capacity > 0, "Invalid capacity");
        require(!isUnderwriterActive[underwriter], "Underwriter already active");
        
        IInsurance.Underwriter storage underwriterInfo = underwriters[underwriter];
        underwriterInfo.underwriter = underwriter;
        underwriterInfo.stakeAmount = stakeAmount;
        underwriterInfo.capacity = capacity;
        underwriterInfo.availableCapacity = capacity;
        underwriterInfo.joinedAt = block.timestamp;
        underwriterInfo.isActive = true;
        
        allUnderwriters.push(underwriter);
        isUnderwriterActive[underwriter] = true;
        totalUnderwriters++;
        
        emit UnderwriterAdded(underwriter, stakeAmount, capacity, block.timestamp);
    }

    function removeUnderwriter(
        address underwriter
    ) external onlyRole(INSURANCE_MANAGER_ROLE) {
        require(isUnderwriterActive[underwriter], "Underwriter not active");
        
        underwriters[underwriter].isActive = false;
        underwriters[underwriter].removedAt = block.timestamp;
        isUnderwriterActive[underwriter] = false;
        totalUnderwriters--;
        
        emit UnderwriterRemoved(underwriter, block.timestamp);
    }

    function createPool(
        address poolAsset,
        uint256 initialBalance,
        uint256 maxCapacity
    ) external onlyRole(INSURANCE_MANAGER_ROLE) {
        require(poolAsset != address(0), "Invalid pool asset");
        require(initialBalance >= config.poolMinimumBalance, "Initial balance too small");
        require(maxCapacity > initialBalance, "Invalid max capacity");
        require(!isPoolActive[poolAsset], "Pool already exists");
        
        IInsurance.InsurancePool storage pool = pools[poolAsset];
        pool.asset = poolAsset;
        pool.balance = initialBalance;
        pool.maxCapacity = maxCapacity;
        pool.utilizationRate = 0;
        pool.createdAt = block.timestamp;
        pool.isActive = true;
        
        allPools.push(poolAsset);
        isPoolActive[poolAsset] = true;
        totalPools++;
        
        emit PoolCreated(poolAsset, initialBalance, maxCapacity, block.timestamp);
    }

    function addLiquidityToPool(
        address poolAsset,
        uint256 amount
    ) external nonReentrant {
        require(isPoolActive[poolAsset], "Pool not active");
        require(amount > 0, "Invalid amount");
        
        InsurancePool storage pool = pools[poolAsset];
        require(pool.balance + amount <= pool.maxCapacity, "Exceeds pool capacity");
        
        // Transfer tokens to contract
        IERC20(poolAsset).safeTransferFrom(msg.sender, address(this), amount);
        
        // Update pool balance
        pool.balance += amount;
        pool.lastUpdate = block.timestamp;
        
        // Track user contribution
        poolBalances[msg.sender][poolAsset] += amount;
        
        emit LiquidityAdded(msg.sender, poolAsset, amount, block.timestamp);
    }

    function removeLiquidityFromPool(
        address poolAsset,
        uint256 amount
    ) external nonReentrant {
        require(isPoolActive[poolAsset], "Pool not active");
        require(amount > 0, "Invalid amount");
        require(poolBalances[msg.sender][poolAsset] >= amount, "Insufficient balance");
        
        InsurancePool storage pool = pools[poolAsset];
        require(pool.balance >= amount, "Insufficient pool liquidity");
        require(pool.balance - amount >= config.poolMinimumBalance, "Below minimum balance");
        
        // Update balances
        pool.balance -= amount;
        pool.lastUpdate = block.timestamp;
        poolBalances[msg.sender][poolAsset] -= amount;
        
        // Transfer tokens back
        IERC20(poolAsset).safeTransfer(msg.sender, amount);
        
        emit LiquidityRemoved(msg.sender, poolAsset, amount, block.timestamp);
    }

    // Emergency functions
    function emergencyPause() external onlyRole(EMERGENCY_ROLE) {
        emergencyMode = true;
        _pause();
        
        emit EmergencyPause(msg.sender, block.timestamp);
    }

    function emergencyUnpause() external onlyRole(EMERGENCY_ROLE) {
        emergencyMode = false;
        _unpause();
        
        emit EmergencyUnpause(msg.sender, block.timestamp);
    }

    function emergencyClaimPayout(
        bytes32 claimId,
        uint256 amount
    ) external onlyRole(EMERGENCY_ROLE) {
        require(emergencyMode, "Not in emergency mode");
        require(isClaimActive[claimId], "Claim not active");
        
        Claim storage claim = claims[claimId];
        require(claim.claimId != bytes32(0), "Claim not found");
        require(amount > 0, "Invalid amount");
        require(amount <= claim.claimAmount, "Amount exceeds claim");
        
        // Process emergency payout
        claim.status = IInsurance.ClaimStatus.PAID;
        claim.paidAmount = amount;
        claim.paidAt = block.timestamp;
        
        // Transfer payout
        payable(claim.claimant).transfer(amount);
        
        totalClaimsPaid += amount;
        
        emit EmergencyClaimPayout(claimId, claim.claimant, amount, msg.sender, block.timestamp);
    }

    // View functions
    function getInsurancePolicy(bytes32 policyId) external view returns (IInsurance.InsurancePolicy memory) {
        return policies[policyId];
    }

    // New wrapper to comply with IInsurance interface
    function getPolicy(bytes32 policyId) external view override returns (IInsurance.Policy memory) {
        IInsurance.InsurancePolicy storage ip = policies[policyId];

        string[] memory emptyStrArr = new string[](0);
        bytes32[] memory emptyBytesArr = new bytes32[](0);

        IInsurance.PolicyTerms memory terms = IInsurance.PolicyTerms({
            coveredRisks: emptyStrArr,
            exclusions: emptyStrArr,
            maxClaimAmount: 0,
            maxClaimsPerPeriod: 0,
            waitingPeriod: 0,
            autoRenewal: false,
            renewalDiscount: 0,
            conditions: emptyStrArr
        });

        IInsurance.PolicyMetrics memory metrics = IInsurance.PolicyMetrics({
            totalPremiumPaid: 0,
            totalClaimsSubmitted: 0,
            totalClaimsPaid: 0,
            lossRatio: 0,
            profitability: 0,
            riskScore: 0,
            lastUpdate: 0
        });

        IInsurance.Policy memory p = IInsurance.Policy({
            policyId: ip.policyId,
            policyholder: ip.policyholder,
            policyType: ip.policyType,
            coverageAmount: ip.coverageAmount,
            premium: ip.premiumAmount,
            deductible: 0,
            duration: ip.endTime > ip.startTime ? ip.endTime - ip.startTime : 0,
            createdAt: ip.createdAt,
            activatedAt: ip.startTime,
            expiresAt: ip.endTime,
            status: ip.status,
            terms: terms,
            metrics: metrics,
            claims: emptyBytesArr,
            underwriter: address(0)
        });

        return p;
    }

    function getClaim(bytes32 claimId) external view returns (IInsurance.Claim memory) {
        return claims[claimId];
    }

    function getCoverage(address holder) external view returns (IInsurance.Coverage memory) {
        return coverages[holder];
    }

    function getPremium(bytes32 policyId) external view returns (IInsurance.Premium memory) {
        return premiums[policyId];
    }

    function getUnderwriter(address underwriter) external view returns (IInsurance.Underwriter memory) {
        return underwriters[underwriter];
    }

    function getRiskAssessment(bytes32 assessmentId) external view returns (IInsurance.RiskAssessment memory) {
        return riskAssessments[assessmentId];
    }

    function getPool(address poolAsset) external view returns (IInsurance.InsurancePool memory) {
        return pools[poolAsset];
    }

    function getClaimAssessment(bytes32 assessmentId) external view returns (IInsurance.ClaimAssessment memory) {
        return claimAssessments[assessmentId];
    }

    function getInsuranceMetrics(address user) external view returns (IInsurance.InsuranceMetrics memory) {
        return insuranceMetrics[user];
    }

    function getPolicyMetrics(bytes32 policyId) external view returns (IInsurance.PolicyMetrics memory) {
        return policyMetrics[policyId];
    }

    function getInsuranceConfig() external view returns (IInsurance.InsuranceConfig memory) {
        return config;
    }

    function getAllPolicies() external view returns (bytes32[] memory) {
        return allPolicies;
    }

    function getActivePolicies() external view returns (bytes32[] memory) {
        return activePolicies;
    }

    function getAllClaims() external view returns (bytes32[] memory) {
        return allClaims;
    }

    function getPendingClaims() external view returns (bytes32[] memory) {
        return pendingClaims;
    }

    function getUserPolicies(address user) external view returns (bytes32[] memory) {
        return userPolicies[user];
    }

    function getUserClaims(address user) external view returns (bytes32[] memory) {
        return userClaims[user];
    }

    function getPolicyClaimsHistory(bytes32 policyId) external view returns (bytes32[] memory) {
        return policyClaimsHistory[policyId];
    }

    function getSystemMetrics() external view returns (IInsurance.SystemMetrics memory) {
        return IInsurance.SystemMetrics({
            totalPolicies: totalPolicies,
            totalClaims: totalClaims,
            totalCoverageHolders: totalCoverageHolders,
            totalUnderwriters: totalUnderwriters,
            totalPools: totalPools,
            totalPremiumsCollected: totalPremiumsCollected,
            totalClaimsPaid: totalClaimsPaid,
            systemHealth: _calculateSystemHealth(),
            lastUpdate: block.timestamp
        });
    }

    // Internal functions
    function _performRiskAssessment(
        address user,
        address asset,
        uint256 amount,
        bytes calldata riskData
    ) internal returns (bytes32) {
        bytes32 assessmentId = keccak256(abi.encodePacked(user, asset, amount, block.timestamp));
        
        // Get risk score from risk management contract
        uint256 riskScore = riskManagement.calculateRiskScore(user, asset, amount);
        
        RiskAssessment storage assessment = riskAssessments[assessmentId];
        assessment.assessmentId = assessmentId;
        assessment.user = user;
        assessment.asset = asset;
        assessment.amount = amount;
        assessment.riskScore = riskScore;
        assessment.riskData = riskData;
        assessment.assessedAt = block.timestamp;
        
        allAssessments.push(assessmentId);
        
        return assessmentId;
    }

    function _calculatePremium(
        uint256 coverageAmount,
        uint256 duration,
        uint256 riskScore,
        IInsurance.PolicyType policyType
    ) internal view returns (uint256) {
        // Base premium calculation
        uint256 basePremium = (coverageAmount * config.basePremiumRate * duration) / (365 days * BASIS_POINTS);
        
        // Risk adjustment
        uint256 riskMultiplier = BASIS_POINTS + (riskScore * 100); // 1% per risk point
        uint256 riskAdjustedPremium = (basePremium * riskMultiplier) / BASIS_POINTS;
        
        // Policy type adjustment
        uint256 typeMultiplier = BASIS_POINTS;
        if (policyType == IInsurance.PolicyType.COMPREHENSIVE) {
            typeMultiplier = 15000; // 150%
        } else if (policyType == IInsurance.PolicyType.PREMIUM) {
            typeMultiplier = 12000; // 120%
        }
        
        return (riskAdjustedPremium * typeMultiplier) / BASIS_POINTS;
    }

    function _processClaim(bytes32 claimId) internal {
        Claim storage claim = claims[claimId];
        require(claim.status == IInsurance.ClaimStatus.APPROVED, "Claim not approved");
        
        uint256 payoutAmount = claim.approvedAmount;
        
        // Check pool liquidity
        InsurancePolicy storage policy = policies[claim.policyId];
        IInsurance.InsurancePool storage pool = pools[policy.coverageAsset];
        require(pool.balance >= payoutAmount, "Insufficient pool liquidity");
        
        // Update claim status
        claim.status = IInsurance.ClaimStatus.PAID;
        claim.paidAmount = payoutAmount;
        claim.paidAt = block.timestamp;
        
        // Update pool balance
        pool.balance -= payoutAmount;
        pool.lastUpdate = block.timestamp;
        
        // Transfer payout
        if (policy.coverageAsset == address(0)) {
            payable(claim.claimant).transfer(payoutAmount);
        } else {
            IERC20(policy.coverageAsset).safeTransfer(claim.claimant, payoutAmount);
        }
        
        // Update metrics
        IInsurance.InsuranceMetrics storage metrics = insuranceMetrics[claim.claimant];
        metrics.totalClaimsPaid += payoutAmount;
        
        totalClaimsPaid += payoutAmount;
        
        emit ClaimPaid(claimId, claim.claimant, payoutAmount, block.timestamp);
    }

    function _distributePremiumToPools(uint256 premiumAmount) internal {
        if (allPools.length == 0) return;
        
        uint256 amountPerPool = premiumAmount / allPools.length;
        
        for (uint256 i = 0; i < allPools.length; i++) {
            address poolAsset = allPools[i];
            InsurancePool storage pool = pools[poolAsset];
            
            if (pool.isActive) {
                pool.balance += amountPerPool;
                pool.lastUpdate = block.timestamp;
            }
        }
    }

    function _removePendingClaim(bytes32 claimId) internal {
        for (uint256 i = 0; i < pendingClaims.length; i++) {
            if (pendingClaims[i] == claimId) {
                pendingClaims[i] = pendingClaims[pendingClaims.length - 1];
                pendingClaims.pop();
                break;
            }
        }
    }

    function _calculateSystemHealth() internal view returns (uint256) {
        if (totalPolicies == 0) return BASIS_POINTS;
        
        // Calculate claim ratio
        uint256 claimRatio = totalClaims > 0 ? 
            (totalClaimsPaid * BASIS_POINTS) / totalPremiumsCollected : 0;
        
        // Calculate pool utilization
        uint256 totalPoolBalance = 0;
        uint256 totalPoolCapacity = 0;
        
        for (uint256 i = 0; i < allPools.length; i++) {
            InsurancePool storage pool = pools[allPools[i]];
            if (pool.isActive) {
                totalPoolBalance += pool.balance;
                totalPoolCapacity += pool.maxCapacity;
            }
        }
        
        uint256 poolUtilization = totalPoolCapacity > 0 ? 
            (totalPoolBalance * BASIS_POINTS) / totalPoolCapacity : 0;
        
        // Calculate active policy ratio
        uint256 activePolicyRatio = totalPolicies > 0 ? 
            (activePolicies.length * BASIS_POINTS) / totalPolicies : 0;
        
        // Health score (lower claim ratio and higher pool utilization = better health)
        uint256 healthScore = BASIS_POINTS - (claimRatio / 2) + (poolUtilization / 4) + (activePolicyRatio / 4);
        
        return healthScore > BASIS_POINTS ? BASIS_POINTS : healthScore;
    }

    // Configuration update functions
    function updateInsuranceConfig(
        IInsurance.InsuranceConfig calldata newConfig
    ) external onlyRole(INSURANCE_MANAGER_ROLE) {
        require(newConfig.basePremiumRate >= MIN_PREMIUM_RATE && newConfig.basePremiumRate <= MAX_PREMIUM_RATE, "Invalid premium rate");
        require(newConfig.maxCoverageRatio >= MIN_COVERAGE_RATIO && newConfig.maxCoverageRatio <= MAX_COVERAGE_RATIO, "Invalid coverage ratio");
        require(newConfig.minCoverageAmount > 0, "Invalid min coverage");
        require(newConfig.maxCoverageAmount > newConfig.minCoverageAmount, "Invalid max coverage");
        
        config = newConfig;
        
        emit InsuranceConfigUpdated(block.timestamp);
    }

    // Admin functions
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    // Receive function for ETH payments
    receive() external payable {
        // Allow contract to receive ETH for premium payments and claim payouts
    }
}
