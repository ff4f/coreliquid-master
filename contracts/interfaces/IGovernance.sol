// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IGovernance
 * @dev Interface for the Governance contract
 * @author CoreLiquid Protocol
 */
interface IGovernance {
    // Events
    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        string title,
        string description,
        ProposalType proposalType,
        uint256 startTime,
        uint256 endTime,
        uint256 timestamp
    );
    
    event VoteCast(
        uint256 indexed proposalId,
        address indexed voter,
        VoteChoice choice,
        uint256 votingPower,
        string reason,
        uint256 timestamp
    );
    
    event ProposalExecuted(
        uint256 indexed proposalId,
        bool success,
        bytes returnData,
        uint256 timestamp
    );
    
    event ProposalCanceled(
        uint256 indexed proposalId,
        address indexed canceler,
        string reason,
        uint256 timestamp
    );
    
    event ProposalQueued(
        uint256 indexed proposalId,
        uint256 executionTime,
        uint256 timestamp
    );
    
    event VotingPowerDelegated(
        address indexed delegator,
        address indexed delegatee,
        uint256 amount,
        uint256 timestamp
    );
    
    event VotingPowerUndelegated(
        address indexed delegator,
        address indexed delegatee,
        uint256 amount,
        uint256 timestamp
    );
    
    event CommitteeMemberAdded(
        bytes32 indexed committeeId,
        address indexed member,
        uint256 timestamp
    );
    
    event CommitteeMemberRemoved(
        bytes32 indexed committeeId,
        address indexed member,
        uint256 timestamp
    );
    
    event CommitteeConfigUpdated(
        bytes32 indexed committeeId,
        uint256 timestamp
    );
    
    event SpendingLimitSet(
        address indexed asset,
        uint256 dailyLimit,
        uint256 monthlyLimit,
        uint256 timestamp
    );
    
    event EmergencyWithdraw(
        address indexed asset,
        uint256 amount,
        address indexed recipient,
        uint256 timestamp
    );
    
    event SnapshotCreated(
        bytes32 indexed snapshotId,
        uint256 blockNumber,
        uint256 timestamp
    );
    
    event SnapshotFinalized(
        bytes32 indexed snapshotId,
        uint256 timestamp
    );
    
    event EmergencyModeEnabled(
        uint256 timestamp
    );
    
    event EmergencyModeDisabled(
        uint256 timestamp
    );
    
    event ProposalVetoed(
        bytes32 indexed proposalId,
        address indexed vetoer,
        uint256 timestamp
    );
    
    event GovernanceConfigUpdated(
        uint256 timestamp
    );
    
    event CommitteeCreated(
        bytes32 indexed committeeId,
        string name,
        address[] members,
        uint256 timestamp
    );
    
    event QuorumUpdated(
        uint256 oldQuorum,
        uint256 newQuorum,
        uint256 timestamp
    );
    
    event VotingDelayUpdated(
        uint256 oldDelay,
        uint256 newDelay,
        uint256 timestamp
    );
    
    event VotingPeriodUpdated(
        uint256 oldPeriod,
        uint256 newPeriod,
        uint256 timestamp
    );
    
    event ProposalThresholdUpdated(
        uint256 oldThreshold,
        uint256 newThreshold,
        uint256 timestamp
    );
    
    event TimelockUpdated(
        address oldTimelock,
        address newTimelock,
        uint256 timestamp
    );
    
    event GuardianSet(
        address indexed oldGuardian,
        address indexed newGuardian,
        uint256 timestamp
    );
    
    event EmergencyActionExecuted(
        uint256 indexed actionId,
        address indexed executor,
        EmergencyActionType actionType,
        bytes data,
        uint256 timestamp
    );

    // Structs
    struct Proposal {
        uint256 proposalId;
        address proposer;
        string title;
        string description;
        ProposalType proposalType;
        ProposalStatus status;
        uint256 startTime;
        uint256 endTime;
        uint256 executionTime;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
        uint256 totalVotingPower;
        bool executed;
        bool canceled;
        ProposalConfig config;
        ProposalMetrics metrics;
        bytes[] calldatas;
        address[] targets;
        uint256[] values;
        string[] signatures;
        uint256 createdAt;
    }
    
    struct ProposalConfig {
        uint256 quorumRequired;
        uint256 votingDelay;
        uint256 votingPeriod;
        uint256 executionDelay;
        bool requiresTimelock;
        uint256 proposalThreshold;
        VotingType votingType;
        bool allowDelegation;
        uint256 maxActions;
    }
    
    struct ProposalMetrics {
        uint256 totalVoters;
        uint256 participationRate;
        uint256 averageVotingPower;
        uint256 delegatedVotes;
        uint256 directVotes;
        uint256 lastVoteTime;
        uint256 discussionCount;
        uint256 supportScore;
    }
    
    struct Vote {
        uint256 proposalId;
        address voter;
        VoteChoice choice;
        uint256 votingPower;
        uint256 timestamp;
        string reason;
        bool isDelegated;
        address delegator;
    }
    
    struct VotingPowerSnapshot {
        address account;
        uint256 blockNumber;
        uint256 votingPower;
        uint256 delegatedPower;
        uint256 ownPower;
        uint256 timestamp;
    }
    
    struct Delegation {
        address delegator;
        address delegatee;
        uint256 amount;
        uint256 startTime;
        uint256 endTime;
        bool isActive;
        DelegationType delegationType;
    }
    
    struct Delegate {
        address delegator;
        address delegatee;
        uint256 amount;
        uint256 timestamp;
        DelegationConfig config;
        bool isActive;
        uint256 undelegatedAt;
    }
    
    struct DelegationConfig {
        uint256 duration;
        bool isRevocable;
        uint256 minAmount;
        uint256 maxAmount;
        bool autoRenew;
    }
    
    struct Treasury {
        bytes32 treasuryId;
        string name;
        address treasuryAddress;
        uint256 totalValue;
        uint256 availableBalance;
        uint256 allocatedBalance;
        address[] supportedAssets;
        address manager;
        uint256 createdAt;
        uint256 lastUpdate;
        bool isActive;
    }
    
    struct Committee {
        bytes32 committeeId;
        string name;
        string description;
        CommitteeType committeeType;
        address[] members;
        uint256[] votingWeights;
        uint256 quorum;
        uint256 votingPeriod;
        bool isActive;
        CommitteeConfig config;
        uint256 createdAt;
        address creator;
    }
    
    struct Snapshot {
        bytes32 snapshotId;
        uint256 blockNumber;
        uint256 timestamp;
        uint256 totalSupply;
        uint256 totalVotingPower;
        bool isActive;
    }
    
    struct VotingPower {
        uint256 totalPower;
        uint256 delegatedPower;
        uint256 ownPower;
        uint256 lastUpdate;
        bool isActive;
    }
    
    struct GovernanceConfig {
        uint256 votingDelay;
        uint256 votingPeriod;
        uint256 proposalThreshold;
        uint256 quorumNumerator;
        uint256 quorumDenominator;
        uint256 executionDelay;
        address timelock;
        address guardian;
        bool emergencyMode;
        uint256 maxProposalsPerUser;
        uint256 cooldownPeriod;
    }
    
    struct CommitteeConfig {
        uint256 maxMembers;
        uint256 minMembers;
        uint256 termLength;
        bool allowSelfNomination;
        uint256 nominationPeriod;
        uint256 electionPeriod;
        VotingType votingType;
        bool requiresStaking;
        uint256 stakingAmount;
    }
    
    struct EmergencyAction {
        uint256 actionId;
        EmergencyActionType actionType;
        address executor;
        bytes data;
        uint256 executionTime;
        bool executed;
        string reason;
        uint256 approvals;
        uint256 requiredApprovals;
    }
    
    struct VotingStrategy {
        bytes32 strategyId;
        string name;
        StrategyType strategyType;
        uint256[] parameters;
        bool isActive;
        address creator;
        uint256 createdAt;
    }
    
    struct ProposalTemplate {
        bytes32 templateId;
        string name;
        string description;
        ProposalType proposalType;
        string[] requiredFields;
        bytes templateData;
        bool isActive;
        address creator;
        uint256 usageCount;
    }
    
    struct GovernanceMetrics {
        uint256 totalProposals;
        uint256 executedProposals;
        uint256 canceledProposals;
        uint256 averageParticipation;
        uint256 totalVotingPower;
        uint256 activeDelegations;
        uint256 uniqueVoters;
        uint256 averageVotingTime;
        uint256 lastUpdate;
    }
    
    struct VoterProfile {
        address voter;
        uint256 totalVotes;
        uint256 proposalsCreated;
        uint256 votingPowerUsed;
        uint256 delegatedPower;
        uint256 participationRate;
        uint256 averageVotingTime;
        VoteChoice[] voteHistory;
        uint256 reputation;
        bool isActive;
    }

    // Enums
    enum ProposalType {
        PARAMETER_CHANGE,
        PROTOCOL_UPGRADE,
        TREASURY_ALLOCATION,
        EMERGENCY_ACTION,
        COMMITTEE_ELECTION,
        CONSTITUTION_AMENDMENT,
        INTEGRATION_APPROVAL,
        FEE_ADJUSTMENT,
        RISK_PARAMETER,
        CUSTOM
    }
    
    enum ProposalStatus {
        PENDING,
        ACTIVE,
        CANCELED,
        DEFEATED,
        SUCCEEDED,
        QUEUED,
        EXPIRED,
        EXECUTED
    }
    
    enum VoteType {
        FOR,
        AGAINST,
        ABSTAIN
    }
    
    enum ProposalState {
        PENDING,
        ACTIVE,
        CANCELED,
        DEFEATED,
        SUCCEEDED,
        QUEUED,
        EXPIRED,
        EXECUTED,
        VETOED
    }
    
    enum VoteChoice {
        AGAINST,
        FOR,
        ABSTAIN
    }
    
    enum VotingType {
        SIMPLE_MAJORITY,
        SUPERMAJORITY,
        QUADRATIC,
        WEIGHTED,
        RANKED_CHOICE,
        APPROVAL
    }
    
    enum DelegationType {
        FULL,
        PARTIAL,
        TOPIC_SPECIFIC,
        TIME_LIMITED,
        CONDITIONAL
    }
    
    enum CommitteeType {
        TECHNICAL,
        TREASURY,
        RISK,
        GOVERNANCE,
        EMERGENCY,
        ADVISORY
    }
    
    enum EmergencyActionType {
        PAUSE_PROTOCOL,
        UNPAUSE_PROTOCOL,
        EMERGENCY_WITHDRAWAL,
        PARAMETER_OVERRIDE,
        CONTRACT_UPGRADE,
        FUND_RECOVERY
    }
    
    enum StrategyType {
        TOKEN_WEIGHTED,
        STAKE_WEIGHTED,
        REPUTATION_WEIGHTED,
        HYBRID,
        CUSTOM
    }

    // Core governance functions
    function propose(
        address[] calldata targets,
        uint256[] calldata values,
        string[] calldata signatures,
        bytes[] calldata calldatas,
        string calldata title,
        string calldata description,
        ProposalType proposalType
    ) external returns (uint256 proposalId);
    
    function castVote(
        uint256 proposalId,
        VoteChoice choice
    ) external returns (uint256 votingPower);
    
    function castVoteWithReason(
        uint256 proposalId,
        VoteChoice choice,
        string calldata reason
    ) external returns (uint256 votingPower);
    
    function castVoteBySig(
        uint256 proposalId,
        VoteChoice choice,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 votingPower);
    
    function execute(
        uint256 proposalId
    ) external returns (bool success);
    
    function cancel(
        uint256 proposalId
    ) external;
    
    function queue(
        uint256 proposalId
    ) external;
    
    // Delegation functions
    function delegate(
        address delegatee,
        uint256 amount,
        DelegationType delegationType
    ) external;
    
    function undelegate(
        address delegatee,
        uint256 amount
    ) external;
    
    function delegateBySig(
        address delegatee,
        uint256 amount,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;
    
    function batchDelegate(
        address[] calldata delegatees,
        uint256[] calldata amounts,
        DelegationType[] calldata delegationTypes
    ) external;
    
    // Committee functions
    function createCommittee(
        string calldata name,
        string calldata description,
        CommitteeType committeeType,
        address[] calldata initialMembers,
        CommitteeConfig calldata config
    ) external returns (bytes32 committeeId);
    
    function nominateForCommittee(
        bytes32 committeeId,
        address nominee
    ) external;
    
    function voteForCommittee(
        bytes32 committeeId,
        address[] calldata candidates,
        uint256[] calldata votes
    ) external;
    
    function executeCommitteeDecision(
        bytes32 committeeId,
        uint256 proposalId
    ) external;
    
    // Emergency functions
    function createEmergencyAction(
        EmergencyActionType actionType,
        bytes calldata data,
        string calldata reason
    ) external returns (uint256 actionId);
    
    function approveEmergencyAction(
        uint256 actionId
    ) external;
    
    function executeEmergencyAction(
        uint256 actionId
    ) external;
    
    function setEmergencyMode(
        bool enabled
    ) external;
    
    // Configuration functions
    function setVotingDelay(
        uint256 newVotingDelay
    ) external;
    
    function setVotingPeriod(
        uint256 newVotingPeriod
    ) external;
    
    function setProposalThreshold(
        uint256 newProposalThreshold
    ) external;
    
    function setQuorum(
        uint256 numerator,
        uint256 denominator
    ) external;
    
    function setTimelock(
        address newTimelock
    ) external;
    
    function setGuardian(
        address newGuardian
    ) external;
    
    function updateGovernanceConfig(
        GovernanceConfig calldata newConfig
    ) external;
    
    // Strategy functions
    function createVotingStrategy(
        string calldata name,
        StrategyType strategyType,
        uint256[] calldata parameters
    ) external returns (bytes32 strategyId);
    
    function updateVotingStrategy(
        bytes32 strategyId,
        uint256[] calldata parameters
    ) external;
    
    function setDefaultVotingStrategy(
        bytes32 strategyId
    ) external;
    
    // Template functions
    function createProposalTemplate(
        string calldata name,
        string calldata description,
        ProposalType proposalType,
        string[] calldata requiredFields,
        bytes calldata templateData
    ) external returns (bytes32 templateId);
    
    function useProposalTemplate(
        bytes32 templateId,
        bytes calldata proposalData
    ) external returns (uint256 proposalId);
    
    // View functions - Proposals
    function getProposal(
        uint256 proposalId
    ) external view returns (Proposal memory);
    
    function getProposalState(
        uint256 proposalId
    ) external view returns (ProposalStatus);
    
    function getProposalVotes(
        uint256 proposalId
    ) external view returns (uint256 forVotes, uint256 againstVotes, uint256 abstainVotes);
    
    function getProposalActions(
        uint256 proposalId
    ) external view returns (
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas
    );
    
    function getAllProposals() external view returns (uint256[] memory);
    
    function getActiveProposals() external view returns (uint256[] memory);
    
    function getUserProposals(
        address user
    ) external view returns (uint256[] memory);
    
    function getProposalsByType(
        ProposalType proposalType
    ) external view returns (uint256[] memory);
    
    // View functions - Voting
    function getVote(
        uint256 proposalId,
        address voter
    ) external view returns (Vote memory);
    
    function getVotingPower(
        address account,
        uint256 blockNumber
    ) external view returns (uint256);
    
    function getCurrentVotingPower(
        address account
    ) external view returns (uint256);
    
    function getDelegatedVotingPower(
        address account
    ) external view returns (uint256);
    
    function getVotingPowerSnapshot(
        address account,
        uint256 blockNumber
    ) external view returns (VotingPowerSnapshot memory);
    
    function hasVoted(
        uint256 proposalId,
        address voter
    ) external view returns (bool);
    
    // View functions - Delegation
    function getDelegation(
        address delegator,
        address delegatee
    ) external view returns (Delegation memory);
    
    function getDelegations(
        address delegator
    ) external view returns (Delegation[] memory);
    
    function getDelegatees(
        address delegator
    ) external view returns (address[] memory);
    
    function getDelegators(
        address delegatee
    ) external view returns (address[] memory);
    
    function getTotalDelegatedPower(
        address delegatee
    ) external view returns (uint256);
    
    // View functions - Committees
    function getCommittee(
        bytes32 committeeId
    ) external view returns (Committee memory);
    
    function getAllCommittees() external view returns (bytes32[] memory);
    
    function getCommitteesByType(
        CommitteeType committeeType
    ) external view returns (bytes32[] memory);
    
    function getCommitteeMembers(
        bytes32 committeeId
    ) external view returns (address[] memory);
    
    function isCommitteeMember(
        bytes32 committeeId,
        address member
    ) external view returns (bool);
    
    function getCommitteeVotingWeight(
        bytes32 committeeId,
        address member
    ) external view returns (uint256);
    
    // View functions - Emergency
    function getEmergencyAction(
        uint256 actionId
    ) external view returns (EmergencyAction memory);
    
    function getAllEmergencyActions() external view returns (uint256[] memory);
    
    function getPendingEmergencyActions() external view returns (uint256[] memory);
    
    function hasApprovedEmergencyAction(
        uint256 actionId,
        address approver
    ) external view returns (bool);
    
    function isEmergencyMode() external view returns (bool);
    
    // View functions - Configuration
    function getGovernanceConfig() external view returns (GovernanceConfig memory);
    
    function getVotingDelay() external view returns (uint256);
    
    function getVotingPeriod() external view returns (uint256);
    
    function getProposalThreshold() external view returns (uint256);
    
    function getQuorum() external view returns (uint256 numerator, uint256 denominator);
    
    function getTimelock() external view returns (address);
    
    function getGuardian() external view returns (address);
    
    // View functions - Strategies
    function getVotingStrategy(
        bytes32 strategyId
    ) external view returns (VotingStrategy memory);
    
    function getAllVotingStrategies() external view returns (bytes32[] memory);
    
    function getDefaultVotingStrategy() external view returns (bytes32);
    
    function calculateVotingPower(
        address account,
        bytes32 strategyId,
        uint256 blockNumber
    ) external view returns (uint256);
    
    // View functions - Templates
    function getProposalTemplate(
        bytes32 templateId
    ) external view returns (ProposalTemplate memory);
    
    function getAllProposalTemplates() external view returns (bytes32[] memory);
    
    function getTemplatesByType(
        ProposalType proposalType
    ) external view returns (bytes32[] memory);
    
    // View functions - Analytics
    function getGovernanceMetrics() external view returns (GovernanceMetrics memory);
    
    function getVoterProfile(
        address voter
    ) external view returns (VoterProfile memory);
    
    function getParticipationRate(
        uint256 timeframe
    ) external view returns (uint256);
    
    function getAverageVotingTime() external view returns (uint256);
    
    function getTopVoters(
        uint256 count
    ) external view returns (address[] memory voters, uint256[] memory votingPowers);
    
    function getProposalSuccessRate(
        address proposer
    ) external view returns (uint256);
    
    function getSystemHealth() external view returns (
        bool isHealthy,
        uint256 activeProposals,
        uint256 participationRate,
        uint256 averageVotingPower
    );
}
