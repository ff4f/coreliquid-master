// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IInsurance
 * @dev Interface for the Insurance contract
 * @author CoreLiquid Protocol
 */
interface IInsurance {
    // Events
    event PolicyCreated(
        bytes32 indexed policyId,
        address indexed policyholder,
        PolicyType policyType,
        uint256 coverageAmount,
        uint256 premium,
        uint256 duration,
        uint256 timestamp
    );
    
    event PolicyActivated(
        bytes32 indexed policyId,
        address indexed policyholder,
        uint256 activatedAt,
        uint256 expiresAt
    );
    
    event PolicyCancelled(
        bytes32 indexed policyId,
        address indexed policyholder,
        CancellationReason reason,
        uint256 refundAmount,
        uint256 timestamp
    );
    
    event ClaimSubmitted(
        bytes32 indexed claimId,
        bytes32 indexed policyId,
        address indexed claimant,
        ClaimType claimType,
        uint256 claimAmount,
        uint256 timestamp
    );
    
    event ClaimProcessed(
        bytes32 indexed claimId,
        ClaimStatus status,
        uint256 payoutAmount,
        address processedBy,
        uint256 timestamp
    );
    
    event ClaimPaid(
        bytes32 indexed claimId,
        address indexed claimant,
        uint256 payoutAmount,
        uint256 timestamp
    );
    
    event PremiumPaid(
        bytes32 indexed policyId,
        address indexed policyholder,
        uint256 amount,
        uint256 period,
        uint256 timestamp
    );
    
    event RiskAssessed(
        bytes32 indexed assessmentId,
        address indexed subject,
        RiskLevel riskLevel,
        uint256 riskScore,
        uint256 timestamp
    );
    
    event PoolCreated(
        bytes32 indexed poolId,
        string poolName,
        PoolType poolType,
        uint256 initialCapital,
        address creator,
        uint256 timestamp
    );
    
    event CapitalDeposited(
        bytes32 indexed poolId,
        address indexed provider,
        uint256 amount,
        uint256 shares,
        uint256 timestamp
    );
    
    event CapitalWithdrawn(
        bytes32 indexed poolId,
        address indexed provider,
        uint256 amount,
        uint256 shares,
        uint256 timestamp
    );
    
    event ReinsuranceContractCreated(
        bytes32 indexed contractId,
        address indexed reinsurer,
        ReinsuranceType reinsuranceType,
        uint256 coverage,
        uint256 premium,
        uint256 timestamp
    );
    
    event UnderwritingCompleted(
        bytes32 indexed applicationId,
        address indexed applicant,
        bool approved,
        uint256 premiumRate,
        string[] conditions,
        uint256 timestamp
    );
    
    event ActuarialModelUpdated(
        bytes32 indexed modelId,
        string modelName,
        uint256 version,
        address updatedBy,
        uint256 timestamp
    );
    
    event ClaimAssessed(
        bytes32 indexed claimId,
        address indexed assessor,
        uint256 assessedAmount,
        bool isValid,
        uint256 timestamp
    );
    
    event CoverageUpdated(
        address indexed holder,
        uint256 totalCoverage,
        uint256 activePolicies,
        uint256 timestamp
    );
    
    event UnderwriterAdded(
        address indexed underwriter,
        uint256 stakeAmount,
        uint256 capacity,
        uint256 timestamp
    );
    
    event UnderwriterRemoved(
        address indexed underwriter,
        uint256 timestamp
    );
    
    event LiquidityAdded(
        address indexed provider,
        address indexed asset,
        uint256 amount,
        uint256 timestamp
    );
    
    event LiquidityRemoved(
        address indexed provider,
        address indexed asset,
        uint256 amount,
        uint256 timestamp
    );
    
    event EmergencyPause(
        address indexed caller,
        uint256 timestamp
    );
    
    event EmergencyUnpause(
        address indexed caller,
        uint256 timestamp
    );
    
    event EmergencyClaimPayout(
        bytes32 indexed claimId,
        address indexed claimant,
        uint256 amount,
        address indexed caller,
        uint256 timestamp
    );
    
    event InsuranceConfigUpdated(
        uint256 timestamp
    );
    
    event ClaimFiled(
        bytes32 indexed claimId,
        bytes32 indexed policyId,
        address indexed claimant,
        uint256 amount,
        uint256 timestamp
    );

    // Structs
    struct Policy {
        bytes32 policyId;
        address policyholder;
        PolicyType policyType;
        uint256 coverageAmount;
        uint256 premium;
        uint256 deductible;
        uint256 duration;
        uint256 createdAt;
        uint256 activatedAt;
        uint256 expiresAt;
        PolicyStatus status;
        PolicyTerms terms;
        PolicyMetrics metrics;
        bytes32[] claims;
        address underwriter;
    }
    
    struct PolicyTerms {
        string[] coveredRisks;
        string[] exclusions;
        uint256 maxClaimAmount;
        uint256 maxClaimsPerPeriod;
        uint256 waitingPeriod;
        bool autoRenewal;
        uint256 renewalDiscount;
        string[] conditions;
    }
    
    struct PolicyMetrics {
        uint256 totalPremiumPaid;
        uint256 totalClaimsSubmitted;
        uint256 totalClaimsPaid;
        uint256 lossRatio;
        uint256 profitability;
        uint256 riskScore;
        uint256 lastUpdate;
    }
    
    struct Claim {
        bytes32 claimId;
        bytes32 policyId;
        address claimant;
        ClaimType claimType;
        uint256 claimAmount;
        uint256 submittedAt;
        uint256 processedAt;
        uint256 paidAt;
        ClaimStatus status;
        ClaimDetails details;
        ClaimAssessment assessment;
        uint256 payoutAmount;
        address processor;
    }
    
    struct ClaimDetails {
        string description;
        uint256 incidentDate;
        string incidentLocation;
        string[] evidenceHashes;
        string[] witnessStatements;
        uint256 estimatedLoss;
        string category;
        bool isEmergency;
        string[] supportingDocuments;
    }
    
    struct ClaimAssessment {
        address assessor;
        uint256 assessedAmount;
        uint256 assessmentDate;
        string assessmentNotes;
        bool isValid;
        string[] verificationChecks;
        uint256 confidence;
        string[] recommendations;
        bool requiresInvestigation;
    }
    
    struct RiskAssessment {
        bytes32 assessmentId;
        address subject;
        RiskLevel riskLevel;
        uint256 riskScore;
        uint256 assessmentDate;
        uint256 validUntil;
        RiskFactors factors;
        RiskMetrics metrics;
        address assessor;
        string methodology;
    }
    
    struct RiskFactors {
        uint256 creditRisk;
        uint256 marketRisk;
        uint256 operationalRisk;
        uint256 liquidityRisk;
        uint256 technicalRisk;
        uint256 regulatoryRisk;
        uint256 reputationalRisk;
        uint256 concentrationRisk;
    }
    
    struct RiskMetrics {
        uint256 probabilityOfDefault;
        uint256 lossGivenDefault;
        uint256 exposureAtDefault;
        uint256 expectedLoss;
        uint256 unexpectedLoss;
        uint256 valueAtRisk;
        uint256 volatility;
        uint256 correlation;
    }
    
    struct InsurancePool {
        bytes32 poolId;
        string name;
        PoolType poolType;
        uint256 totalCapital;
        uint256 availableCapital;
        uint256 utilizedCapital;
        uint256 totalShares;
        bool isActive;
        PoolConfig config;
        PoolMetrics metrics;
        bytes32[] activePolicies;
    }
    
    struct PoolConfig {
        uint256 minCapital;
        uint256 maxCapital;
        uint256 targetUtilization;
        uint256 maxUtilization;
        uint256 entryFee;
        uint256 exitFee;
        uint256 managementFee;
        uint256 performanceFee;
        bool allowPublicParticipation;
        address[] authorizedUnderwriters;
    }
    
    struct PoolMetrics {
        uint256 totalPremiumsCollected;
        uint256 totalClaimsPaid;
        uint256 lossRatio;
        uint256 expenseRatio;
        uint256 combinedRatio;
        uint256 returnOnCapital;
        uint256 solvencyRatio;
        uint256 lastUpdate;
    }
    
    struct CapitalPosition {
        address provider;
        uint256 amount;
        uint256 shares;
        uint256 entryTime;
        uint256 lastReward;
        uint256 accruedRewards;
        bool isActive;
        PositionMetrics metrics;
    }
    
    struct PositionMetrics {
        uint256 totalRewards;
        uint256 totalLosses;
        uint256 netReturn;
        uint256 riskAdjustedReturn;
        uint256 sharpeRatio;
        uint256 maxDrawdown;
    }
    
    struct ReinsuranceContract {
        bytes32 contractId;
        address reinsurer;
        ReinsuranceType reinsuranceType;
        uint256 coverage;
        uint256 premium;
        uint256 retention;
        uint256 limit;
        uint256 duration;
        bool isActive;
        ReinsuranceTerms terms;
        ReinsuranceMetrics metrics;
    }
    
    struct ReinsuranceTerms {
        string[] coveredLines;
        string[] exclusions;
        uint256 attachmentPoint;
        uint256 exhaustionPoint;
        bool isProportional;
        uint256 cessionRate;
        string[] conditions;
    }
    
    struct ReinsuranceMetrics {
        uint256 totalPremiumCeded;
        uint256 totalClaimsRecovered;
        uint256 lossRatio;
        uint256 profitCommission;
        uint256 lastSettlement;
    }
    
    struct UnderwritingApplication {
        bytes32 applicationId;
        address applicant;
        PolicyType requestedPolicyType;
        uint256 requestedCoverage;
        uint256 submittedAt;
        uint256 processedAt;
        ApplicationStatus status;
        ApplicationData data;
        UnderwritingDecision decision;
        address underwriter;
    }
    
    struct ApplicationData {
        string[] riskFactors;
        uint256[] riskValues;
        string[] documents;
        string[] declarations;
        bool hasHistory;
        string[] previousClaims;
    }
    
    struct UnderwritingDecision {
        bool approved;
        uint256 premiumRate;
        uint256 deductible;
        string[] conditions;
        string[] exclusions;
        uint256 validUntil;
        string reasoning;
        uint256 confidence;
    }
    
    struct ActuarialModel {
        bytes32 modelId;
        string name;
        string description;
        ModelType modelType;
        uint256 version;
        bool isActive;
        ModelParameters parameters;
        ModelPerformance performance;
        uint256 lastCalibration;
        address[] authorizedUsers;
    }
    
    struct ModelParameters {
        uint256[] coefficients;
        uint256[] weights;
        string[] variables;
        uint256 confidenceLevel;
        uint256 timeHorizon;
        bool useHistoricalData;
        bool useMacroFactors;
    }
    
    struct ModelPerformance {
        uint256 accuracy;
        uint256 precision;
        uint256 recall;
        uint256 auc;
        uint256 mse;
        uint256 mae;
        uint256 backtestResults;
        uint256 lastValidation;
    }
    
    struct PremiumCalculation {
        bytes32 calculationId;
        address applicant;
        PolicyType policyType;
        uint256 basePremium;
        uint256 riskAdjustment;
        uint256 loadingFactor;
        uint256 finalPremium;
        uint256 calculatedAt;
        CalculationFactors factors;
        string methodology;
    }
    
    struct CalculationFactors {
        uint256 ageFactor;
        uint256 experienceFactor;
        uint256 exposureFactor;
        uint256 territoryFactor;
        uint256 industryFactor;
        uint256 sizeFactor;
    }
    
    struct Coverage {
        address holder;
        uint256 totalCoverage;
        uint256 activePolicies;
        uint256 lastUpdate;
        bool isActive;
    }
    
    struct Premium {
        bytes32 policyId;
        uint256 amount;
        uint256 paidAt;
        bool isPaid;
        uint256 dueDate;
        uint256 period;
        bool isRecurring;
    }
    
    struct Underwriter {
        address underwriter;
        uint256 stakeAmount;
        uint256 capacity;
        uint256 availableCapacity;
        uint256 joinedAt;
        uint256 removedAt;
        bool isActive;
        uint256 totalPoliciesUnderwritten;
        uint256 totalPremiumsCollected;
        uint256 totalClaimsPaid;
    }
    
    struct InsurancePolicy {
        bytes32 policyId;
        address policyholder;
        address coverageAsset;
        uint256 coverageAmount;
        uint256 premiumAmount;
        uint256 startTime;
        uint256 endTime;
        PolicyType policyType;
        PolicyStatus status;
        bytes32 riskAssessmentId;
        uint256 createdAt;
        uint256 lastUpdate;
        bool isActive;
    }
    
    struct InsuranceConfig {
        uint256 basePremiumRate;
        uint256 maxCoverageRatio;
        uint256 minCoverageAmount;
        uint256 maxCoverageAmount;
        uint256 claimAssessmentPeriod;
        uint256 maxClaimAmount;
        uint256 underwriterStakeRequired;
        uint256 poolMinimumBalance;
        bool isActive;
    }
    
    struct InsuranceMetrics {
        address user;
        uint256 totalPolicies;
        uint256 totalClaims;
        uint256 totalPremiumsPaid;
        uint256 totalClaimsPaid;
        uint256 lastPolicy;
        uint256 lastClaim;
        uint256 riskScore;
        bool isActive;
    }

    struct SystemMetrics {
        uint256 totalPolicies;
        uint256 totalClaims;
        uint256 totalCoverageHolders;
        uint256 totalUnderwriters;
        uint256 totalPools;
        uint256 totalPremiumsCollected;
        uint256 totalClaimsPaid;
        uint256 systemHealth;
        uint256 lastUpdate;
    }

    // Enums
    enum PolicyType {
        SMART_CONTRACT_COVER,
        PROTOCOL_COVER,
        STABLECOIN_DEPEG,
        YIELD_TOKEN_COVER,
        BRIDGE_COVER,
        ORACLE_FAILURE,
        GOVERNANCE_ATTACK,
        LIQUIDITY_COVER,
        SLASHING_COVER,
        CUSTODY_COVER
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
        PROTOCOL_HACK,
        STABLECOIN_DEPEG_EVENT,
        YIELD_LOSS,
        BRIDGE_FAILURE,
        ORACLE_MANIPULATION,
        GOVERNANCE_ATTACK_EVENT,
        LIQUIDITY_CRISIS,
        SLASHING_EVENT,
        CUSTODY_LOSS
    }
    
    enum ClaimStatus {
        SUBMITTED,
        UNDER_REVIEW,
        INVESTIGATING,
        APPROVED,
        REJECTED,
        PAID,
        DISPUTED,
        SETTLED
    }
    
    enum CancellationReason {
        USER_REQUEST,
        NON_PAYMENT,
        FRAUD,
        RISK_CHANGE,
        REGULATORY,
        MUTUAL_AGREEMENT,
        BREACH_OF_TERMS
    }
    
    enum RiskLevel {
        VERY_LOW,
        LOW,
        MEDIUM,
        HIGH,
        VERY_HIGH,
        EXTREME
    }
    
    enum PoolType {
        GENERAL,
        SPECIALIZED,
        CATASTROPHE,
        REINSURANCE,
        MUTUAL,
        CAPTIVE,
        PARAMETRIC
    }
    
    enum ReinsuranceType {
        QUOTA_SHARE,
        SURPLUS,
        EXCESS_OF_LOSS,
        STOP_LOSS,
        CATASTROPHE_XOL,
        AGGREGATE_XOL,
        FACULTATIVE
    }
    
    enum ApplicationStatus {
        SUBMITTED,
        UNDER_REVIEW,
        ADDITIONAL_INFO_REQUIRED,
        APPROVED,
        REJECTED,
        EXPIRED
    }
    
    enum ModelType {
        FREQUENCY_SEVERITY,
        GENERALIZED_LINEAR,
        MACHINE_LEARNING,
        CREDIBILITY,
        BAYESIAN,
        COPULA,
        EXTREME_VALUE
    }

    // Core insurance functions
    function createPolicy(
        PolicyType policyType,
        uint256 coverageAmount,
        uint256 duration,
        PolicyTerms calldata terms
    ) external payable returns (bytes32 policyId);
    
    function activatePolicy(
        bytes32 policyId
    ) external;
    
    function renewPolicy(
        bytes32 policyId,
        uint256 newDuration
    ) external payable;
    
    function cancelPolicy(
        bytes32 policyId,
        CancellationReason reason
    ) external;
    
    function payPremium(
        bytes32 policyId
    ) external payable;
    
    // Claim functions
    function submitClaim(
        bytes32 policyId,
        ClaimType claimType,
        uint256 claimAmount,
        ClaimDetails calldata details
    ) external returns (bytes32 claimId);
    
    function processClaim(
        bytes32 claimId,
        ClaimAssessment calldata assessment
    ) external;
    
    function approveClaim(
        bytes32 claimId,
        uint256 payoutAmount
    ) external;
    
    function rejectClaim(
        bytes32 claimId,
        string calldata reason
    ) external;
    
    function payClaim(
        bytes32 claimId
    ) external;
    
    function disputeClaim(
        bytes32 claimId,
        string calldata reason
    ) external;
    
    function settleClaim(
        bytes32 claimId,
        uint256 settlementAmount
    ) external;
    
    // Risk assessment functions
    function assessRisk(
        address subject,
        PolicyType policyType,
        uint256 coverageAmount
    ) external returns (bytes32 assessmentId);
    
    function updateRiskAssessment(
        bytes32 assessmentId,
        RiskFactors calldata factors
    ) external;
    
    function calculateRiskScore(
        address subject,
        PolicyType policyType
    ) external view returns (uint256 riskScore, RiskLevel riskLevel);
    
    function setRiskParameters(
        PolicyType policyType,
        string calldata parameter,
        uint256 value
    ) external;
    
    // Pool management functions
    function createInsurancePool(
        string calldata name,
        PoolType poolType,
        PoolConfig calldata config
    ) external payable returns (bytes32 poolId);
    
    function depositCapital(
        bytes32 poolId,
        uint256 amount
    ) external returns (uint256 shares);
    
    function withdrawCapital(
        bytes32 poolId,
        uint256 shares
    ) external returns (uint256 amount);
    
    function rebalancePool(
        bytes32 poolId
    ) external;
    
    function distributeRewards(
        bytes32 poolId
    ) external;
    
    function liquidatePool(
        bytes32 poolId,
        string calldata reason
    ) external;
    
    // Underwriting functions
    function submitUnderwritingApplication(
        PolicyType policyType,
        uint256 requestedCoverage,
        ApplicationData calldata data
    ) external returns (bytes32 applicationId);
    
    function processUnderwritingApplication(
        bytes32 applicationId,
        UnderwritingDecision calldata decision
    ) external;
    
    function calculatePremium(
        address applicant,
        PolicyType policyType,
        uint256 coverageAmount
    ) external returns (bytes32 calculationId);
    
    function updateUnderwritingGuidelines(
        PolicyType policyType,
        string[] calldata guidelines
    ) external;
    
    // Reinsurance functions
    function createReinsuranceContract(
        address reinsurer,
        ReinsuranceType reinsuranceType,
        uint256 coverage,
        uint256 premium,
        ReinsuranceTerms calldata terms
    ) external returns (bytes32 contractId);
    
    function cededPremium(
        bytes32 contractId,
        uint256 amount
    ) external;
    
    function recoverClaim(
        bytes32 contractId,
        bytes32 claimId,
        uint256 amount
    ) external;
    
    function settleReinsurance(
        bytes32 contractId,
        uint256 period
    ) external;
    
    // Actuarial functions
    function deployActuarialModel(
        string calldata name,
        ModelType modelType,
        ModelParameters calldata parameters
    ) external returns (bytes32 modelId);
    
    function calibrateModel(
        bytes32 modelId,
        uint256[] calldata historicalData
    ) external;
    
    function validateModel(
        bytes32 modelId,
        uint256[] calldata testData
    ) external returns (ModelPerformance memory performance);
    
    function updateModelParameters(
        bytes32 modelId,
        ModelParameters calldata parameters
    ) external;
    
    function runStressTest(
        bytes32 poolId,
        string calldata scenario,
        uint256[] calldata shocks
    ) external returns (uint256 projectedLoss);
    
    // Configuration functions
    function setInsuranceParameters(
        string calldata parameter,
        uint256 value
    ) external;
    
    function updatePolicyTerms(
        PolicyType policyType,
        PolicyTerms calldata terms
    ) external;
    
    function setClaimProcessor(
        address processor,
        ClaimType[] calldata claimTypes
    ) external;
    
    function setUnderwriter(
        address underwriter,
        PolicyType[] calldata policyTypes
    ) external;
    
    function pauseInsuranceSystem(
        string calldata reason
    ) external;
    
    function unpauseInsuranceSystem() external;
    
    // Emergency functions
    function emergencyClaimPayout(
        bytes32 claimId,
        uint256 amount,
        string calldata reason
    ) external;
    
    function emergencyPoolLiquidation(
        bytes32 poolId,
        string calldata reason
    ) external;
    
    function emergencyPolicyTermination(
        bytes32 policyId,
        string calldata reason
    ) external;
    
    function freezeAssets(
        bytes32 poolId,
        string calldata reason
    ) external;
    
    function unfreezeAssets(
        bytes32 poolId
    ) external;
    
    // View functions - Policies
    function getPolicy(
        bytes32 policyId
    ) external view returns (Policy memory);
    
    function getUserPolicies(
        address user
    ) external view returns (bytes32[] memory);
    
    function getActivePolicies() external view returns (bytes32[] memory);
    
    function getPoliciesByType(
        PolicyType policyType
    ) external view returns (bytes32[] memory);
    
    function getPolicyTerms(
        bytes32 policyId
    ) external view returns (PolicyTerms memory);
    
    function getPolicyMetrics(
        bytes32 policyId
    ) external view returns (PolicyMetrics memory);
    
    function isPolicyActive(
        bytes32 policyId
    ) external view returns (bool active);
    
    function getPolicyPremium(
        bytes32 policyId
    ) external view returns (uint256 premium, uint256 nextDue);
    
    // View functions - Claims
    function getClaim(
        bytes32 claimId
    ) external view returns (Claim memory);
    
    function getPolicyClaims(
        bytes32 policyId
    ) external view returns (bytes32[] memory);
    
    function getUserClaims(
        address user
    ) external view returns (bytes32[] memory);
    
    function getClaimsByStatus(
        ClaimStatus status
    ) external view returns (bytes32[] memory);
    
    function getClaimDetails(
        bytes32 claimId
    ) external view returns (ClaimDetails memory);
    
    function getClaimAssessment(
        bytes32 claimId
    ) external view returns (ClaimAssessment memory);
    
    function isClaimValid(
        bytes32 claimId
    ) external view returns (bool valid);
    
    // View functions - Risk
    function getRiskAssessment(
        bytes32 assessmentId
    ) external view returns (RiskAssessment memory);
    
    function getUserRiskProfile(
        address user
    ) external view returns (RiskLevel riskLevel, uint256 riskScore);
    
    function getRiskFactors(
        address subject,
        PolicyType policyType
    ) external view returns (RiskFactors memory);
    
    function getRiskMetrics(
        address subject
    ) external view returns (RiskMetrics memory);
    
    // View functions - Pools
    function getInsurancePool(
        bytes32 poolId
    ) external view returns (InsurancePool memory);
    
    function getAllPools() external view returns (bytes32[] memory);
    
    function getActivePools() external view returns (bytes32[] memory);
    
    function getPoolsByType(
        PoolType poolType
    ) external view returns (bytes32[] memory);
    
    function getPoolMetrics(
        bytes32 poolId
    ) external view returns (PoolMetrics memory);
    
    function getCapitalPosition(
        bytes32 poolId,
        address provider
    ) external view returns (CapitalPosition memory);
    
    function getPoolUtilization(
        bytes32 poolId
    ) external view returns (uint256 utilization);
    
    function getPoolSolvency(
        bytes32 poolId
    ) external view returns (uint256 solvencyRatio);
    
    // View functions - Underwriting
    function getUnderwritingApplication(
        bytes32 applicationId
    ) external view returns (UnderwritingApplication memory);
    
    function getUserApplications(
        address user
    ) external view returns (bytes32[] memory);
    
    function getPendingApplications() external view returns (bytes32[] memory);
    
    function getUnderwritingDecision(
        bytes32 applicationId
    ) external view returns (UnderwritingDecision memory);
    
    function getPremiumCalculation(
        bytes32 calculationId
    ) external view returns (PremiumCalculation memory);
    
    // View functions - Reinsurance
    function getReinsuranceContract(
        bytes32 contractId
    ) external view returns (ReinsuranceContract memory);
    
    function getAllReinsuranceContracts() external view returns (bytes32[] memory);
    
    function getActiveReinsuranceContracts() external view returns (bytes32[] memory);
    
    function getReinsuranceMetrics(
        bytes32 contractId
    ) external view returns (ReinsuranceMetrics memory);
    
    // View functions - Models
    function getActuarialModel(
        bytes32 modelId
    ) external view returns (ActuarialModel memory);
    
    function getAllModels() external view returns (bytes32[] memory);
    
    function getActiveModels() external view returns (bytes32[] memory);
    
    function getModelsByType(
        ModelType modelType
    ) external view returns (bytes32[] memory);
    
    function getModelPerformance(
        bytes32 modelId
    ) external view returns (ModelPerformance memory);
    
    function getModelParameters(
        bytes32 modelId
    ) external view returns (ModelParameters memory);
    
    // View functions - Analytics
    function getInsuranceMetrics() external view returns (InsuranceMetrics memory);
    
    function getPoolAnalytics(
        bytes32 poolId,
        uint256 timeframe
    ) external view returns (
        uint256 premiumsCollected,
        uint256 claimsPaid,
        uint256 profitability,
        uint256 riskExposure
    );
    
    function getClaimStatistics(
        uint256 timeframe
    ) external view returns (
        uint256 totalClaims,
        uint256 approvedClaims,
        uint256 rejectedClaims,
        uint256 averageClaimAmount,
        uint256 averageProcessingTime
    );
    
    function getLossRatio(
        PolicyType policyType,
        uint256 timeframe
    ) external view returns (uint256 lossRatio);
    
    function getSolvencyPosition() external view returns (
        uint256 totalCapital,
        uint256 requiredCapital,
        uint256 solvencyRatio,
        bool isSolvent
    );
    
    function getSystemHealth() external view returns (
        uint256 activePolicies,
        uint256 totalCoverage,
        uint256 availableCapital,
        uint256 systemRisk
    );
}
