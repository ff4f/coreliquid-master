// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IProtocolInsuranceEngine
 * @dev Interface for the Protocol Insurance Engine contract
 * @author CoreLiquid Protocol
 */
interface IProtocolInsuranceEngine {
    // Events
    event InsurancePolicyCreated(
        bytes32 indexed policyId,
        address indexed policyholder,
        PolicyType policyType,
        uint256 coverageAmount,
        uint256 premium,
        uint256 duration,
        uint256 timestamp
    );
    
    event PremiumPaid(
        bytes32 indexed policyId,
        address indexed policyholder,
        uint256 amount,
        uint256 period,
        uint256 timestamp
    );
    
    event ClaimSubmitted(
        bytes32 indexed claimId,
        bytes32 indexed policyId,
        address indexed claimant,
        ClaimType claimType,
        uint256 claimAmount,
        string evidence,
        uint256 timestamp
    );
    
    event ClaimProcessed(
        bytes32 indexed claimId,
        ClaimStatus status,
        uint256 payoutAmount,
        string reason,
        uint256 timestamp
    );
    
    event ClaimPaid(
        bytes32 indexed claimId,
        address indexed beneficiary,
        uint256 amount,
        uint256 timestamp
    );
    
    event InsurancePoolCreated(
        bytes32 indexed poolId,
        string name,
        address[] supportedTokens,
        uint256 maxCapacity,
        uint256 timestamp
    );
    
    event LiquidityProvided(
        bytes32 indexed poolId,
        address indexed provider,
        address token,
        uint256 amount,
        uint256 shares,
        uint256 timestamp
    );
    
    event LiquidityWithdrawn(
        bytes32 indexed poolId,
        address indexed provider,
        address token,
        uint256 amount,
        uint256 shares,
        uint256 timestamp
    );
    
    event RiskAssessmentUpdated(
        bytes32 indexed policyId,
        RiskLevel oldRisk,
        RiskLevel newRisk,
        uint256 newPremium,
        uint256 timestamp
    );
    
    event ReinsuranceActivated(
        bytes32 indexed policyId,
        address reinsurer,
        uint256 coverage,
        uint256 timestamp
    );
    
    event EmergencyWithdrawal(
        bytes32 indexed poolId,
        address indexed admin,
        uint256 amount,
        string reason,
        uint256 timestamp
    );
    
    event PremiumAdjusted(
        bytes32 indexed policyId,
        uint256 oldPremium,
        uint256 newPremium,
        string reason,
        uint256 timestamp
    );

    // Structs
    struct InsurancePolicy {
        bytes32 policyId;
        address policyholder;
        PolicyType policyType;
        uint256 coverageAmount;
        uint256 premium;
        uint256 duration;
        uint256 startTime;
        uint256 endTime;
        uint256 lastPremiumPayment;
        uint256 totalPremiumPaid;
        PolicyStatus status;
        RiskLevel riskLevel;
        bool isActive;
        bool autoRenewal;
        bytes32 poolId;
        address[] coveredAssets;
        string[] coveredRisks;
        uint256 deductible;
        uint256 maxClaim;
        uint256 claimsCount;
        uint256 totalClaimsPaid;
    }
    
    struct InsuranceClaim {
        bytes32 claimId;
        bytes32 policyId;
        address claimant;
        ClaimType claimType;
        uint256 claimAmount;
        uint256 approvedAmount;
        uint256 paidAmount;
        string description;
        string evidence;
        ClaimStatus status;
        uint256 submittedAt;
        uint256 processedAt;
        uint256 paidAt;
        address assessor;
        string assessmentNotes;
        bool requiresInvestigation;
        uint256 investigationDeadline;
    }
    
    struct InsurancePool {
        bytes32 poolId;
        string name;
        address[] supportedTokens;
        mapping(address => uint256) tokenBalances;
        mapping(address => uint256) totalShares;
        mapping(address => mapping(address => uint256)) userShares;
        uint256 totalValueLocked;
        uint256 maxCapacity;
        uint256 utilizationRate;
        uint256 totalPremiumCollected;
        uint256 totalClaimsPaid;
        uint256 reserveRatio;
        bool isActive;
        bool acceptingDeposits;
        uint256 createdAt;
        uint256 lastUpdate;
    }
    
    struct LiquidityProvider {
        address provider;
        bytes32[] poolIds;
        mapping(bytes32 => uint256) poolShares;
        mapping(bytes32 => uint256) poolDeposits;
        uint256 totalDeposited;
        uint256 totalEarned;
        uint256 totalWithdrawn;
        uint256 reputationScore;
        bool isActive;
        uint256 joinedAt;
        uint256 lastActivity;
    }
    
    struct RiskAssessment {
        bytes32 policyId;
        RiskLevel riskLevel;
        uint256 riskScore;
        string[] riskFactors;
        uint256[] riskWeights;
        uint256 assessedAt;
        address assessor;
        bool isValid;
        uint256 validUntil;
        string methodology;
        uint256 confidenceLevel;
    }
    
    struct PremiumCalculation {
        bytes32 policyId;
        uint256 basePremium;
        uint256 riskMultiplier;
        uint256 poolMultiplier;
        uint256 discountRate;
        uint256 finalPremium;
        uint256 calculatedAt;
        bool isValid;
        string[] factors;
        uint256[] adjustments;
    }
    
    struct InsuranceMetrics {
        uint256 totalPolicies;
        uint256 activePolicies;
        uint256 totalCoverage;
        uint256 totalPremiumCollected;
        uint256 totalClaims;
        uint256 totalClaimsPaid;
        uint256 claimRatio;
        uint256 profitabilityRatio;
        uint256 solvencyRatio;
        uint256 averagePremium;
        uint256 averageClaimAmount;
        uint256 lastUpdate;
    }
    
    struct ReinsuranceContract {
        bytes32 contractId;
        address reinsurer;
        bytes32[] coveredPolicies;
        uint256 maxCoverage;
        uint256 retentionLimit;
        uint256 premiumShare;
        uint256 claimShare;
        bool isActive;
        uint256 startTime;
        uint256 endTime;
        uint256 totalPremiumPaid;
        uint256 totalClaimsReceived;
    }

    // Enums
    enum PolicyType {
        SMART_CONTRACT_RISK,
        LIQUIDITY_RISK,
        ORACLE_FAILURE,
        GOVERNANCE_ATTACK,
        BRIDGE_FAILURE,
        SLASHING_RISK,
        GENERAL_PROTOCOL_RISK
    }
    
    enum PolicyStatus {
        PENDING,
        ACTIVE,
        EXPIRED,
        CANCELLED,
        SUSPENDED,
        CLAIMED
    }
    
    enum ClaimType {
        SMART_CONTRACT_EXPLOIT,
        ORACLE_MANIPULATION,
        GOVERNANCE_ATTACK,
        BRIDGE_HACK,
        SLASHING_EVENT,
        LIQUIDITY_CRISIS,
        OTHER
    }
    
    enum ClaimStatus {
        SUBMITTED,
        UNDER_REVIEW,
        INVESTIGATING,
        APPROVED,
        REJECTED,
        PAID,
        DISPUTED
    }
    
    enum RiskLevel {
        LOW,
        MEDIUM,
        HIGH,
        CRITICAL
    }

    // Core insurance functions
    function createPolicy(
        PolicyType policyType,
        uint256 coverageAmount,
        uint256 duration,
        address[] calldata coveredAssets,
        string[] calldata coveredRisks
    ) external returns (bytes32 policyId);
    
    function payPremium(
        bytes32 policyId
    ) external payable;
    
    function renewPolicy(
        bytes32 policyId,
        uint256 newDuration
    ) external returns (bool success);
    
    function cancelPolicy(
        bytes32 policyId
    ) external returns (uint256 refundAmount);
    
    function updateCoverage(
        bytes32 policyId,
        uint256 newCoverageAmount
    ) external returns (uint256 premiumAdjustment);
    
    // Claim functions
    function submitClaim(
        bytes32 policyId,
        ClaimType claimType,
        uint256 claimAmount,
        string calldata description,
        string calldata evidence
    ) external returns (bytes32 claimId);
    
    function processClaim(
        bytes32 claimId,
        ClaimStatus status,
        uint256 approvedAmount,
        string calldata reason
    ) external;
    
    function payClaim(
        bytes32 claimId
    ) external returns (bool success);
    
    function disputeClaim(
        bytes32 claimId,
        string calldata reason
    ) external;
    
    function investigateClaim(
        bytes32 claimId,
        uint256 deadline
    ) external;
    
    // Pool management functions
    function createInsurancePool(
        string calldata name,
        address[] calldata supportedTokens,
        uint256 maxCapacity
    ) external returns (bytes32 poolId);
    
    function provideLiquidity(
        bytes32 poolId,
        address token,
        uint256 amount
    ) external returns (uint256 shares);
    
    function withdrawLiquidity(
        bytes32 poolId,
        address token,
        uint256 shares
    ) external returns (uint256 amount);
    
    function rebalancePool(
        bytes32 poolId
    ) external;
    
    function updatePoolParameters(
        bytes32 poolId,
        uint256 maxCapacity,
        uint256 reserveRatio
    ) external;
    
    // Risk assessment functions
    function assessRisk(
        bytes32 policyId
    ) external returns (RiskLevel riskLevel, uint256 riskScore);
    
    function updateRiskAssessment(
        bytes32 policyId,
        RiskLevel newRiskLevel,
        string[] calldata riskFactors
    ) external;
    
    function calculatePremium(
        PolicyType policyType,
        uint256 coverageAmount,
        uint256 duration,
        address[] calldata coveredAssets
    ) external view returns (uint256 premium);
    
    function adjustPremium(
        bytes32 policyId,
        uint256 newPremium,
        string calldata reason
    ) external;
    
    // Reinsurance functions
    function createReinsuranceContract(
        address reinsurer,
        bytes32[] calldata coveredPolicies,
        uint256 maxCoverage,
        uint256 retentionLimit
    ) external returns (bytes32 contractId);
    
    function activateReinsurance(
        bytes32 policyId,
        bytes32 contractId
    ) external;
    
    function claimReinsurance(
        bytes32 claimId,
        bytes32 contractId
    ) external returns (uint256 reinsuranceAmount);
    
    function updateReinsuranceTerms(
        bytes32 contractId,
        uint256 newMaxCoverage,
        uint256 newRetentionLimit
    ) external;
    
    // Emergency functions
    function pausePolicy(
        bytes32 policyId
    ) external;
    
    function unpausePolicy(
        bytes32 policyId
    ) external;
    
    function emergencyWithdraw(
        bytes32 poolId,
        uint256 amount,
        string calldata reason
    ) external;
    
    function freezePool(
        bytes32 poolId
    ) external;
    
    function unfreezePool(
        bytes32 poolId
    ) external;
    
    // Configuration functions
    function setMinimumCoverage(
        uint256 minimumAmount
    ) external;
    
    function setMaximumCoverage(
        uint256 maximumAmount
    ) external;
    
    function setClaimAssessor(
        address assessor,
        bool enabled
    ) external;
    
    function setRiskAssessor(
        address assessor,
        bool enabled
    ) external;
    
    function updatePremiumRates(
        PolicyType policyType,
        uint256 baseRate
    ) external;
    
    // View functions - Policy information
    function getPolicy(
        bytes32 policyId
    ) external view returns (InsurancePolicy memory);
    
    function getPolicyStatus(
        bytes32 policyId
    ) external view returns (PolicyStatus);
    
    function getUserPolicies(
        address user
    ) external view returns (bytes32[] memory);
    
    function getActivePolicies() external view returns (bytes32[] memory);
    
    function getPoliciesByType(
        PolicyType policyType
    ) external view returns (bytes32[] memory);
    
    function isPolicyActive(
        bytes32 policyId
    ) external view returns (bool);
    
    function getPolicyExpiry(
        bytes32 policyId
    ) external view returns (uint256 expiryTime);
    
    function getCoverageAmount(
        bytes32 policyId
    ) external view returns (uint256 coverage);
    
    // View functions - Claim information
    function getClaim(
        bytes32 claimId
    ) external view returns (InsuranceClaim memory);
    
    function getClaimStatus(
        bytes32 claimId
    ) external view returns (ClaimStatus);
    
    function getPolicyClaims(
        bytes32 policyId
    ) external view returns (bytes32[] memory);
    
    function getUserClaims(
        address user
    ) external view returns (bytes32[] memory);
    
    function getClaimsByStatus(
        ClaimStatus status
    ) external view returns (bytes32[] memory);
    
    function getClaimAmount(
        bytes32 claimId
    ) external view returns (uint256 claimAmount, uint256 approvedAmount);
    
    // View functions - Pool information
    function getPool(
        bytes32 poolId
    ) external view returns (
        string memory name,
        address[] memory supportedTokens,
        uint256 totalValueLocked,
        uint256 maxCapacity,
        uint256 utilizationRate
    );
    
    function getPoolBalance(
        bytes32 poolId,
        address token
    ) external view returns (uint256 balance);
    
    function getUserPoolShares(
        bytes32 poolId,
        address user
    ) external view returns (uint256 shares);
    
    function getPoolUtilization(
        bytes32 poolId
    ) external view returns (uint256 utilizationRate);
    
    function getAllPools() external view returns (bytes32[] memory);
    
    function getActivePools() external view returns (bytes32[] memory);
    
    // View functions - Premium calculations
    function getPremiumCalculation(
        bytes32 policyId
    ) external view returns (PremiumCalculation memory);
    
    function estimatePremium(
        PolicyType policyType,
        uint256 coverageAmount,
        uint256 duration,
        address user
    ) external view returns (uint256 estimatedPremium);
    
    function getBasePremiumRate(
        PolicyType policyType
    ) external view returns (uint256 baseRate);
    
    function getRiskMultiplier(
        RiskLevel riskLevel
    ) external view returns (uint256 multiplier);
    
    // View functions - Risk assessment
    function getRiskAssessment(
        bytes32 policyId
    ) external view returns (RiskAssessment memory);
    
    function getRiskLevel(
        bytes32 policyId
    ) external view returns (RiskLevel);
    
    function getRiskScore(
        bytes32 policyId
    ) external view returns (uint256 riskScore);
    
    function isRiskAssessmentValid(
        bytes32 policyId
    ) external view returns (bool isValid, uint256 validUntil);
    
    // View functions - Metrics and analytics
    function getInsuranceMetrics() external view returns (InsuranceMetrics memory);
    
    function getClaimRatio(
        bytes32 poolId
    ) external view returns (uint256 claimRatio);
    
    function getProfitabilityRatio(
        bytes32 poolId
    ) external view returns (uint256 profitabilityRatio);
    
    function getSolvencyRatio(
        bytes32 poolId
    ) external view returns (uint256 solvencyRatio);
    
    function getTotalCoverage() external view returns (uint256 totalCoverage);
    
    function getTotalPremiumCollected() external view returns (uint256 totalPremium);
    
    function getTotalClaimsPaid() external view returns (uint256 totalClaims);
    
    // View functions - Reinsurance
    function getReinsuranceContract(
        bytes32 contractId
    ) external view returns (ReinsuranceContract memory);
    
    function getPolicyReinsurance(
        bytes32 policyId
    ) external view returns (bytes32[] memory contractIds);
    
    function getReinsuranceCoverage(
        bytes32 policyId
    ) external view returns (uint256 totalCoverage);
    
    function isReinsured(
        bytes32 policyId
    ) external view returns (bool);
    
    // View functions - Liquidity provider information
    function getLiquidityProvider(
        address provider
    ) external view returns (
        bytes32[] memory poolIds,
        uint256 totalDeposited,
        uint256 totalEarned,
        uint256 reputationScore
    );
    
    function getProviderShares(
        address provider,
        bytes32 poolId
    ) external view returns (uint256 shares, uint256 value);
    
    function getProviderEarnings(
        address provider,
        bytes32 poolId
    ) external view returns (uint256 earnings);
    
    function getTopProviders(
        uint256 count
    ) external view returns (address[] memory providers, uint256[] memory deposits);
    
    // View functions - System health
    function isSystemHealthy() external view returns (bool);
    
    function getSystemHealth() external view returns (
        bool isHealthy,
        uint256 solvencyHealth,
        uint256 liquidityHealth,
        uint256 claimHealth
    );
    
    function getPoolHealth(
        bytes32 poolId
    ) external view returns (
        bool isHealthy,
        uint256 utilizationHealth,
        uint256 reserveHealth,
        uint256 claimHealth
    );
    
    function getMinimumReserves(
        bytes32 poolId
    ) external view returns (uint256 minimumReserves);
    
    function canAcceptNewPolicies(
        bytes32 poolId
    ) external view returns (bool);
}
