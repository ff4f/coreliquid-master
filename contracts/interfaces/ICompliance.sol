// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title ICompliance
 * @dev Interface for the Compliance contract
 * @author CoreLiquid Protocol
 */
interface ICompliance {
    // Events
    event ComplianceCheckPerformed(
        bytes32 indexed checkId,
        address indexed subject,
        ComplianceType checkType,
        bool passed,
        uint256 timestamp
    );
    
    event ComplianceViolationDetected(
        bytes32 indexed violationId,
        address indexed subject,
        ViolationType violationType,
        ViolationSeverity severity,
        string description
    );
    
    event ComplianceRuleUpdated(
        bytes32 indexed ruleId,
        string ruleName,
        RuleType ruleType,
        bool isActive,
        uint256 timestamp
    );
    
    event KYCStatusUpdated(
        address indexed user,
        KYCStatus oldStatus,
        KYCStatus newStatus,
        uint256 timestamp
    );
    
    event AMLCheckCompleted(
        bytes32 indexed checkId,
        address indexed user,
        AMLRiskLevel riskLevel,
        bool flagged,
        uint256 timestamp
    );
    
    event SanctionsScreeningPerformed(
        bytes32 indexed screeningId,
        address indexed user,
        bool isOnSanctionsList,
        string[] matchedLists,
        uint256 timestamp
    );
    
    event TransactionMonitored(
        bytes32 indexed monitoringId,
        address indexed user,
        bytes32 indexed transactionHash,
        MonitoringResult result,
        uint256 timestamp
    );
    
    event ComplianceReportGenerated(
        bytes32 indexed reportId,
        ReportType reportType,
        uint256 startTime,
        uint256 endTime,
        string ipfsHash
    );
    
    event RegulatoryFilingSubmitted(
        bytes32 indexed filingId,
        FilingType filingType,
        address regulator,
        uint256 timestamp
    );
    
    event ComplianceOfficerAssigned(
        address indexed officer,
        ComplianceRole role,
        uint256 timestamp
    );
    
    event ComplianceTrainingCompleted(
        address indexed user,
        string trainingModule,
        uint256 completionDate,
        uint256 expiryDate
    );
    
    event DataPrivacyRequestProcessed(
        bytes32 indexed requestId,
        address indexed user,
        PrivacyRequestType requestType,
        RequestStatus status
    );
    
    event AuditTrailCreated(
        bytes32 indexed trailId,
        address indexed user,
        string action,
        bytes32 dataHash,
        uint256 timestamp
    );
    
    event ComplianceAlertTriggered(
        bytes32 indexed alertId,
        AlertSeverity severity,
        string message,
        address[] recipients,
        uint256 timestamp
    );
    
    event JurisdictionRestrictionUpdated(
        string indexed jurisdiction,
        bool isRestricted,
        string[] restrictedServices,
        uint256 timestamp
    );
    
    event ComplianceMetricsUpdated(
        uint256 totalChecks,
        uint256 passedChecks,
        uint256 violations,
        uint256 complianceScore,
        uint256 timestamp
    );

    // Structs
    struct ComplianceCheck {
        bytes32 checkId;
        address subject;
        ComplianceType checkType;
        bool passed;
        uint256 score;
        uint256 timestamp;
        uint256 expiresAt;
        CheckDetails details;
        CheckMetrics metrics;
        string[] findings;
        string[] recommendations;
    }
    
    struct CheckDetails {
        string checkName;
        string description;
        uint256 version;
        address checker;
        bytes32[] evidenceHashes;
        string[] dataSourcesUsed;
        uint256 processingTime;
        bool requiresManualReview;
    }
    
    struct CheckMetrics {
        uint256 accuracy;
        uint256 confidence;
        uint256 riskScore;
        uint256 falsePositiveRate;
        uint256 falseNegativeRate;
        uint256 lastCalibration;
    }
    
    struct ComplianceRule {
        bytes32 ruleId;
        string name;
        string description;
        RuleType ruleType;
        uint256 priority;
        bool isActive;
        RuleConfig config;
        RuleMetrics metrics;
        RuleParameters parameters;
        string[] applicableJurisdictions;
    }
    
    struct RuleConfig {
        uint256 threshold;
        uint256 timeWindow;
        bool autoEnforce;
        bool requiresApproval;
        address[] approvers;
        uint256 escalationLevel;
        string[] exemptions;
        bool allowOverride;
    }
    
    struct RuleMetrics {
        uint256 totalTriggers;
        uint256 truePositives;
        uint256 falsePositives;
        uint256 effectiveness;
        uint256 lastUpdate;
        uint256 averageProcessingTime;
    }
    
    struct RuleParameters {
        uint256[] numericalParams;
        bool[] booleanParams;
        string[] stringParams;
        address[] addressParams;
        uint256 lastUpdate;
    }
    
    struct KYCProfile {
        address user;
        KYCStatus status;
        uint256 verificationLevel;
        uint256 completionDate;
        uint256 expiryDate;
        KYCDocuments documents;
        KYCVerification verification;
        KYCRiskAssessment riskAssessment;
        bool requiresUpdate;
    }
    
    struct KYCDocuments {
        bytes32[] documentHashes;
        string[] documentTypes;
        uint256[] uploadDates;
        bool[] isVerified;
        address[] verifiers;
        uint256 lastUpdate;
    }
    
    struct KYCVerification {
        bool identityVerified;
        bool addressVerified;
        bool phoneVerified;
        bool emailVerified;
        bool biometricVerified;
        uint256 verificationScore;
        address verifier;
        uint256 verificationDate;
    }
    
    struct KYCRiskAssessment {
        uint256 riskScore;
        KYCRiskLevel riskLevel;
        string[] riskFactors;
        bool isPEP; // Politically Exposed Person
        bool isHighRiskJurisdiction;
        uint256 assessmentDate;
        address assessor;
    }
    
    struct AMLProfile {
        address user;
        AMLRiskLevel riskLevel;
        uint256 riskScore;
        uint256 lastScreening;
        AMLFlags flags;
        TransactionPattern pattern;
        SuspiciousActivity[] activities;
        bool isMonitored;
    }
    
    struct AMLFlags {
        bool isSuspicious;
        bool isHighRisk;
        bool requiresEnhancedDueDiligence;
        bool isOnWatchlist;
        bool hasUnusualActivity;
        bool isStructuring;
        bool isPotentialTerroristFinancing;
        uint256 lastFlagUpdate;
    }
    
    struct TransactionPattern {
        uint256 averageTransactionSize;
        uint256 transactionFrequency;
        uint256 totalVolume;
        uint256 peakTransactionSize;
        address[] frequentCounterparties;
        string[] commonTransactionTypes;
        uint256 lastPatternUpdate;
    }
    
    struct SuspiciousActivity {
        bytes32 activityId;
        string activityType;
        string description;
        uint256 amount;
        address counterparty;
        uint256 timestamp;
        SuspicionLevel suspicionLevel;
        bool isReported;
        bytes32 reportId;
    }
    
    struct SanctionsScreening {
        bytes32 screeningId;
        address user;
        uint256 screeningDate;
        bool isOnSanctionsList;
        string[] matchedLists;
        MatchDetails[] matches;
        ScreeningConfig config;
        bool requiresManualReview;
    }
    
    struct MatchDetails {
        string listName;
        string matchedName;
        uint256 matchScore;
        string matchType;
        string additionalInfo;
        bool isFalsePositive;
    }
    
    struct ScreeningConfig {
        string[] sanctionsLists;
        uint256 matchThreshold;
        bool enableFuzzyMatching;
        bool checkAliases;
        bool checkAssociates;
        uint256 updateFrequency;
    }
    
    struct TransactionMonitoring {
        bytes32 monitoringId;
        address user;
        bytes32 transactionHash;
        uint256 amount;
        address counterparty;
        MonitoringResult result;
        MonitoringFlags flags;
        uint256 riskScore;
        uint256 timestamp;
    }
    
    struct MonitoringFlags {
        bool isHighValue;
        bool isUnusualPattern;
        bool isRapidSuccession;
        bool isCrossBorder;
        bool isHighRiskCounterparty;
        bool isStructuredTransaction;
        bool requiresReporting;
        bool isBlocked;
    }
    
    struct ComplianceReport {
        bytes32 reportId;
        ReportType reportType;
        uint256 startTime;
        uint256 endTime;
        ReportData data;
        ReportMetrics metrics;
        string ipfsHash;
        bool isSubmitted;
        uint256 submissionDate;
    }
    
    struct ReportData {
        uint256 totalTransactions;
        uint256 flaggedTransactions;
        uint256 blockedTransactions;
        uint256 reportedTransactions;
        uint256 totalUsers;
        uint256 verifiedUsers;
        uint256 suspiciousUsers;
        ComplianceBreakdown breakdown;
    }
    
    struct ComplianceBreakdown {
        uint256 kycViolations;
        uint256 amlViolations;
        uint256 sanctionsViolations;
        uint256 jurisdictionViolations;
        uint256 dataPrivacyViolations;
        uint256 otherViolations;
    }
    
    struct ReportMetrics {
        uint256 complianceScore;
        uint256 violationRate;
        uint256 falsePositiveRate;
        uint256 processingTime;
        uint256 costOfCompliance;
        uint256 riskMitigated;
    }
    
    struct RegulatoryFiling {
        bytes32 filingId;
        FilingType filingType;
        address regulator;
        uint256 filingDate;
        uint256 reportingPeriod;
        bytes32 reportHash;
        FilingStatus status;
        string[] attachments;
        bool isConfidential;
    }
    
    struct JurisdictionRule {
        string jurisdiction;
        bool isRestricted;
        string[] restrictedServices;
        string[] requiredLicenses;
        uint256 maxTransactionAmount;
        bool requiresLocalEntity;
        ComplianceRequirement[] requirements;
        uint256 lastUpdate;
    }
    
    struct ComplianceRequirement {
        string requirementType;
        string description;
        bool isMandatory;
        uint256 deadline;
        bool isCompliant;
        string[] evidenceRequired;
    }
    
    struct DataPrivacyRequest {
        bytes32 requestId;
        address user;
        PrivacyRequestType requestType;
        string description;
        uint256 requestDate;
        uint256 deadline;
        RequestStatus status;
        string[] dataCategories;
        bytes32 responseHash;
    }
    
    struct AuditTrail {
        bytes32 trailId;
        address user;
        string action;
        bytes32 dataHash;
        uint256 timestamp;
        string ipAddress;
        string userAgent;
        bytes32 sessionId;
        bool isVerified;
    }
    
    struct ComplianceMetrics {
        uint256 totalChecks;
        uint256 passedChecks;
        uint256 failedChecks;
        uint256 violations;
        uint256 complianceScore;
        uint256 averageProcessingTime;
        uint256 costOfCompliance;
        uint256 lastUpdate;
    }

    // Enums
    enum ComplianceType {
        KYC,
        AML,
        SANCTIONS,
        JURISDICTION,
        DATA_PRIVACY,
        TRANSACTION_MONITORING,
        REGULATORY_REPORTING,
        RISK_ASSESSMENT
    }
    
    enum ViolationType {
        KYC_INCOMPLETE,
        AML_SUSPICIOUS,
        SANCTIONS_MATCH,
        JURISDICTION_RESTRICTED,
        DATA_BREACH,
        TRANSACTION_LIMIT_EXCEEDED,
        REPORTING_FAILURE,
        UNAUTHORIZED_ACCESS
    }
    
    enum ViolationSeverity {
        LOW,
        MEDIUM,
        HIGH,
        CRITICAL,
        REGULATORY
    }
    
    enum KYCStatus {
        NOT_STARTED,
        IN_PROGRESS,
        PENDING_REVIEW,
        VERIFIED,
        REJECTED,
        EXPIRED,
        SUSPENDED
    }
    
    enum AMLRiskLevel {
        LOW,
        MEDIUM,
        HIGH,
        VERY_HIGH,
        PROHIBITED
    }
    
    enum KYCRiskLevel {
        LOW,
        MEDIUM,
        HIGH,
        VERY_HIGH
    }
    
    enum SuspicionLevel {
        LOW,
        MEDIUM,
        HIGH,
        VERY_HIGH
    }
    
    enum MonitoringResult {
        CLEAR,
        FLAGGED,
        BLOCKED,
        REPORTED,
        UNDER_REVIEW
    }
    
    enum RuleType {
        THRESHOLD,
        PATTERN,
        BLACKLIST,
        WHITELIST,
        GEOGRAPHIC,
        TEMPORAL,
        BEHAVIORAL,
        REGULATORY
    }
    
    enum ReportType {
        DAILY,
        WEEKLY,
        MONTHLY,
        QUARTERLY,
        ANNUAL,
        SUSPICIOUS_ACTIVITY,
        REGULATORY_FILING,
        AUDIT_REPORT
    }
    
    enum FilingType {
        SAR, // Suspicious Activity Report
        CTR, // Currency Transaction Report
        FBAR, // Foreign Bank Account Report
        FATCA, // Foreign Account Tax Compliance Act
        CRS, // Common Reporting Standard
        CUSTOM
    }
    
    enum FilingStatus {
        DRAFT,
        SUBMITTED,
        ACKNOWLEDGED,
        UNDER_REVIEW,
        APPROVED,
        REJECTED
    }
    
    enum PrivacyRequestType {
        ACCESS,
        RECTIFICATION,
        ERASURE,
        PORTABILITY,
        RESTRICTION,
        OBJECTION
    }
    
    enum RequestStatus {
        RECEIVED,
        IN_PROGRESS,
        COMPLETED,
        REJECTED,
        EXPIRED
    }
    
    enum ComplianceRole {
        COMPLIANCE_OFFICER,
        AML_ANALYST,
        KYC_SPECIALIST,
        SANCTIONS_OFFICER,
        DATA_PROTECTION_OFFICER,
        AUDIT_MANAGER
    }
    
    enum AlertSeverity {
        INFO,
        LOW,
        MEDIUM,
        HIGH,
        CRITICAL
    }

    // Core compliance functions
    function performComplianceCheck(
        address subject,
        ComplianceType checkType
    ) external returns (bytes32 checkId);
    
    function batchComplianceCheck(
        address[] calldata subjects,
        ComplianceType checkType
    ) external returns (bytes32[] memory checkIds);
    
    function isCompliant(
        address subject,
        ComplianceType checkType
    ) external view returns (bool compliant);
    
    function getComplianceScore(
        address subject
    ) external view returns (uint256 score);
    
    function reportViolation(
        address subject,
        ViolationType violationType,
        string calldata description
    ) external returns (bytes32 violationId);
    
    // KYC functions
    function initiateKYC(
        address user
    ) external returns (bytes32 kycId);
    
    function submitKYCDocuments(
        address user,
        bytes32[] calldata documentHashes,
        string[] calldata documentTypes
    ) external;
    
    function verifyKYC(
        address user,
        bool approved,
        string calldata reason
    ) external;
    
    function updateKYCStatus(
        address user,
        KYCStatus newStatus
    ) external;
    
    function renewKYC(
        address user
    ) external;
    
    function getKYCStatus(
        address user
    ) external view returns (KYCStatus status, uint256 expiryDate);
    
    // AML functions
    function performAMLScreening(
        address user
    ) external returns (bytes32 screeningId);
    
    function updateAMLRiskLevel(
        address user,
        AMLRiskLevel newLevel,
        string calldata reason
    ) external;
    
    function reportSuspiciousActivity(
        address user,
        string calldata activityType,
        string calldata description,
        uint256 amount
    ) external returns (bytes32 reportId);
    
    function addToWatchlist(
        address user,
        string calldata reason
    ) external;
    
    function removeFromWatchlist(
        address user,
        string calldata reason
    ) external;
    
    function isOnWatchlist(
        address user
    ) external view returns (bool onWatchlist);
    
    // Sanctions screening functions
    function performSanctionsScreening(
        address user
    ) external returns (bytes32 screeningId);
    
    function updateSanctionsLists(
        string[] calldata listNames,
        bytes32[] calldata listHashes
    ) external;
    
    function addToSanctionsList(
        address user,
        string calldata listName,
        string calldata reason
    ) external;
    
    function removeFromSanctionsList(
        address user,
        string calldata listName,
        string calldata reason
    ) external;
    
    function isOnSanctionsList(
        address user
    ) external view returns (bool onList, string[] memory lists);
    
    // Transaction monitoring functions
    function monitorTransaction(
        address user,
        bytes32 transactionHash,
        uint256 amount,
        address counterparty
    ) external returns (bytes32 monitoringId);
    
    function flagTransaction(
        bytes32 transactionHash,
        string calldata reason
    ) external;
    
    function blockTransaction(
        bytes32 transactionHash,
        string calldata reason
    ) external;
    
    function approveTransaction(
        bytes32 transactionHash,
        string calldata reason
    ) external;
    
    function isTransactionBlocked(
        bytes32 transactionHash
    ) external view returns (bool blocked);
    
    // Rule management functions
    function createComplianceRule(
        string calldata name,
        RuleType ruleType,
        RuleConfig calldata config
    ) external returns (bytes32 ruleId);
    
    function updateComplianceRule(
        bytes32 ruleId,
        RuleConfig calldata newConfig
    ) external;
    
    function activateRule(
        bytes32 ruleId
    ) external;
    
    function deactivateRule(
        bytes32 ruleId
    ) external;
    
    function deleteRule(
        bytes32 ruleId
    ) external;
    
    // Jurisdiction management functions
    function setJurisdictionRule(
        string calldata jurisdiction,
        JurisdictionRule calldata rule
    ) external;
    
    function updateJurisdictionRestriction(
        string calldata jurisdiction,
        bool isRestricted,
        string[] calldata restrictedServices
    ) external;
    
    function isJurisdictionRestricted(
        string calldata jurisdiction
    ) external view returns (bool restricted);
    
    function isServiceAllowed(
        string calldata jurisdiction,
        string calldata service
    ) external view returns (bool allowed);
    
    // Reporting functions
    function generateComplianceReport(
        ReportType reportType,
        uint256 startTime,
        uint256 endTime
    ) external returns (bytes32 reportId);
    
    function submitRegulatoryFiling(
        FilingType filingType,
        address regulator,
        bytes32 reportHash
    ) external returns (bytes32 filingId);
    
    function updateFilingStatus(
        bytes32 filingId,
        FilingStatus newStatus
    ) external;
    
    function schedulePeriodicReporting(
        ReportType reportType,
        uint256 frequency
    ) external;
    
    // Data privacy functions
    function submitPrivacyRequest(
        PrivacyRequestType requestType,
        string calldata description
    ) external returns (bytes32 requestId);
    
    function processPrivacyRequest(
        bytes32 requestId,
        RequestStatus status,
        bytes32 responseHash
    ) external;
    
    function deleteUserData(
        address user,
        string[] calldata dataCategories
    ) external;
    
    function exportUserData(
        address user
    ) external returns (bytes32 dataHash);
    
    // Audit functions
    function createAuditTrail(
        address user,
        string calldata action,
        bytes32 dataHash
    ) external returns (bytes32 trailId);
    
    function verifyAuditTrail(
        bytes32 trailId
    ) external view returns (bool verified);
    
    function getAuditHistory(
        address user,
        uint256 startTime,
        uint256 endTime
    ) external view returns (AuditTrail[] memory);
    
    // Configuration functions
    function setComplianceOfficer(
        address officer,
        ComplianceRole role
    ) external;
    
    function updateComplianceConfig(
        string calldata parameter,
        uint256 value
    ) external;
    
    function setGlobalComplianceThreshold(
        uint256 threshold
    ) external;
    
    function pauseCompliance(
        ComplianceType complianceType,
        string calldata reason
    ) external;
    
    function unpauseCompliance(
        ComplianceType complianceType
    ) external;
    
    // Emergency functions
    function emergencyFreeze(
        address user,
        string calldata reason
    ) external;
    
    function emergencyUnfreeze(
        address user,
        string calldata reason
    ) external;
    
    function emergencyBlockAllTransactions(
        string calldata reason
    ) external;
    
    function emergencyUnblockAllTransactions() external;
    
    function forceComplianceCheck(
        address user,
        ComplianceType checkType
    ) external;
    
    // View functions - Compliance checks
    function getComplianceCheck(
        bytes32 checkId
    ) external view returns (ComplianceCheck memory);
    
    function getUserComplianceChecks(
        address user
    ) external view returns (bytes32[] memory);
    
    function getComplianceChecksByType(
        ComplianceType checkType
    ) external view returns (bytes32[] memory);
    
    function getFailedComplianceChecks(
        uint256 timeframe
    ) external view returns (bytes32[] memory);
    
    function isComplianceCheckValid(
        bytes32 checkId
    ) external view returns (bool valid);
    
    // View functions - KYC
    function getKYCProfile(
        address user
    ) external view returns (KYCProfile memory);
    
    function getKYCDocuments(
        address user
    ) external view returns (KYCDocuments memory);
    
    function getKYCVerification(
        address user
    ) external view returns (KYCVerification memory);
    
    function getKYCRiskAssessment(
        address user
    ) external view returns (KYCRiskAssessment memory);
    
    function getAllKYCUsers() external view returns (address[] memory);
    
    function getKYCUsersByStatus(
        KYCStatus status
    ) external view returns (address[] memory);
    
    // View functions - AML
    function getAMLProfile(
        address user
    ) external view returns (AMLProfile memory);
    
    function getAMLFlags(
        address user
    ) external view returns (AMLFlags memory);
    
    function getTransactionPattern(
        address user
    ) external view returns (TransactionPattern memory);
    
    function getSuspiciousActivities(
        address user
    ) external view returns (SuspiciousActivity[] memory);
    
    function getWatchlistUsers() external view returns (address[] memory);
    
    // View functions - Sanctions
    function getSanctionsScreening(
        bytes32 screeningId
    ) external view returns (SanctionsScreening memory);
    
    function getUserSanctionsHistory(
        address user
    ) external view returns (bytes32[] memory);
    
    function getSanctionsLists() external view returns (string[] memory);
    
    function getSanctionedUsers() external view returns (address[] memory);
    
    // View functions - Transaction monitoring
    function getTransactionMonitoring(
        bytes32 monitoringId
    ) external view returns (TransactionMonitoring memory);
    
    function getFlaggedTransactions(
        uint256 timeframe
    ) external view returns (bytes32[] memory);
    
    function getBlockedTransactions(
        uint256 timeframe
    ) external view returns (bytes32[] memory);
    
    function getUserTransactionHistory(
        address user,
        uint256 timeframe
    ) external view returns (bytes32[] memory);
    
    // View functions - Rules
    function getComplianceRule(
        bytes32 ruleId
    ) external view returns (ComplianceRule memory);
    
    function getAllComplianceRules() external view returns (bytes32[] memory);
    
    function getActiveComplianceRules() external view returns (bytes32[] memory);
    
    function getRulesByType(
        RuleType ruleType
    ) external view returns (bytes32[] memory);
    
    // View functions - Jurisdiction
    function getJurisdictionRule(
        string calldata jurisdiction
    ) external view returns (JurisdictionRule memory);
    
    function getAllJurisdictions() external view returns (string[] memory);
    
    function getRestrictedJurisdictions() external view returns (string[] memory);
    
    function getJurisdictionRequirements(
        string calldata jurisdiction
    ) external view returns (ComplianceRequirement[] memory);
    
    // View functions - Reports
    function getComplianceReport(
        bytes32 reportId
    ) external view returns (ComplianceReport memory);
    
    function getAllComplianceReports() external view returns (bytes32[] memory);
    
    function getReportsByType(
        ReportType reportType
    ) external view returns (bytes32[] memory);
    
    function getRegulatoryFiling(
        bytes32 filingId
    ) external view returns (RegulatoryFiling memory);
    
    function getFilingsByRegulator(
        address regulator
    ) external view returns (bytes32[] memory);
    
    // View functions - Privacy
    function getDataPrivacyRequest(
        bytes32 requestId
    ) external view returns (DataPrivacyRequest memory);
    
    function getUserPrivacyRequests(
        address user
    ) external view returns (bytes32[] memory);
    
    function getPendingPrivacyRequests() external view returns (bytes32[] memory);
    
    // View functions - Analytics
    function getComplianceMetrics() external view returns (ComplianceMetrics memory);
    
    function getComplianceAnalytics(
        uint256 timeframe
    ) external view returns (
        uint256 totalChecks,
        uint256 passRate,
        uint256 violationRate,
        uint256 averageScore
    );
    
    function getViolationsByType(
        uint256 timeframe
    ) external view returns (
        ViolationType[] memory types,
        uint256[] memory counts
    );
    
    function getComplianceTrends(
        uint256 timeframe
    ) external view returns (
        uint256[] memory scores,
        uint256[] memory timestamps
    );
    
    function getSystemComplianceHealth() external view returns (
        uint256 overallScore,
        uint256 riskLevel,
        uint256 totalUsers,
        uint256 compliantUsers
    );
}