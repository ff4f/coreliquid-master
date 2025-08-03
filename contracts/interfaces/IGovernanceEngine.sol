// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IGovernanceEngine
 * @dev Interface for the Governance Engine contract
 * @author CoreLiquid Protocol
 */
interface IGovernanceEngine {
    // Events
    event ProposalCreated(
        bytes32 indexed proposalId,
        address indexed proposer,
        string title,
        ProposalType proposalType,
        uint256 votingStartTime,
        uint256 votingEndTime,
        uint256 timestamp
    );
    
    event VoteCast(
        bytes32 indexed proposalId,
        address indexed voter,
        VoteChoice choice,
        uint256 votingPower,
        string reason,
        uint256 timestamp
    );
    
    event ProposalExecuted(
        bytes32 indexed proposalId,
        bool success,
        bytes returnData,
        uint256 timestamp
    );
    
    event ProposalCancelled(
        bytes32 indexed proposalId,
        address indexed canceller,
        string reason,
        uint256 timestamp
    );
    
    event QuorumUpdated(
        uint256 oldQuorum,
        uint256 newQuorum,
        uint256 timestamp
    );
    
    event VotingPowerDelegated(
        address indexed delegator,
        address indexed delegatee,
        uint256 amount,
        uint256 timestamp
    );
    
    event VotingPowerRevoked(
        address indexed delegator,
        address indexed delegatee,
        uint256 amount,
        uint256 timestamp
    );
    
    event GovernanceParametersUpdated(
        string parameterName,
        uint256 oldValue,
        uint256 newValue,
        uint256 timestamp
    );
    
    event EmergencyActionExecuted(
        bytes32 indexed actionId,
        address indexed executor,
        string actionType,
        uint256 timestamp
    );
    
    event VetoExecuted(
        bytes32 indexed proposalId,
        address indexed vetoer,
        string reason,
        uint256 timestamp
    );
    
    event TimelockUpdated(
        bytes32 indexed proposalId,
        uint256 oldDelay,
        uint256 newDelay,
        uint256 timestamp
    );

    // Structs
    struct Proposal {
        bytes32 proposalId;
        address proposer;
        string title;
        string description;
        ProposalType proposalType;
        address[] targets;
        uint256[] values;
        bytes[] calldatas;
        string[] signatures;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
        uint256 totalVotingPower;
        uint256 votingStartTime;
        uint256 votingEndTime;
        uint256 executionDelay;
        uint256 createdAt;
        uint256 executedAt;
        ProposalStatus status;
        bool isEmergency;
        bool isVetoed;
        address vetoer;
        string vetoReason;
    }
    
    struct Vote {
        bytes32 proposalId;
        address voter;
        VoteChoice choice;
        uint256 votingPower;
        string reason;
        uint256 timestamp;
        bool isDelegated;
        address delegator;
    }
    
    struct VotingPowerSnapshot {
        address account;
        uint256 votingPower;
        uint256 blockNumber;
        uint256 timestamp;
        bool isDelegated;
        address delegatee;
    }
    
    struct Delegation {
        address delegator;
        address delegatee;
        uint256 amount;
        uint256 delegatedAt;
        uint256 expiresAt;
        bool isActive;
        bool isRevocable;
    }
    
    struct GovernanceConfig {
        uint256 votingDelay;
        uint256 votingPeriod;
        uint256 proposalThreshold;
        uint256 quorumNumerator;
        uint256 quorumDenominator;
        uint256 executionDelay;
        uint256 gracePeriod;
        bool requiresQuorum;
        bool allowDelegation;
        bool allowVeto;
        uint256 lastUpdate;
    }
    
    struct GovernanceMetrics {
        uint256 totalProposals;
        uint256 activeProposals;
        uint256 executedProposals;
        uint256 cancelledProposals;
        uint256 totalVotes;
        uint256 totalVoters;
        uint256 averageParticipation;
        uint256 averageVotingPower;
        uint256 lastUpdate;
    }
    
    struct VoterProfile {
        address voter;
        uint256 totalVotes;
        uint256 totalVotingPower;
        uint256 proposalsCreated;
        uint256 participationRate;
        uint256 delegatedPower;
        uint256 receivedDelegations;
        bool isDelegate;
        bool isActive;
        uint256 lastVoteTime;
    }
    
    struct ProposalResult {
        bytes32 proposalId;
        bool passed;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
        uint256 totalVotes;
        uint256 participationRate;
        uint256 quorumReached;
        bool quorumMet;
        uint256 executionTime;
    }

    // Enums
    enum ProposalType {
        PARAMETER_CHANGE,
        PROTOCOL_UPGRADE,
        TREASURY_ALLOCATION,
        EMERGENCY_ACTION,
        GENERAL,
        CONSTITUTIONAL
    }
    
    enum ProposalStatus {
        PENDING,
        ACTIVE,
        SUCCEEDED,
        DEFEATED,
        QUEUED,
        EXECUTED,
        CANCELLED,
        VETOED,
        EXPIRED
    }
    
    enum VoteChoice {
        AGAINST,
        FOR,
        ABSTAIN
    }

    // Core governance functions
    function createProposal(
        string calldata title,
        string calldata description,
        ProposalType proposalType,
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata calldatas,
        string[] calldata signatures
    ) external returns (bytes32 proposalId);
    
    function castVote(
        bytes32 proposalId,
        VoteChoice choice
    ) external returns (uint256 votingPower);
    
    function castVoteWithReason(
        bytes32 proposalId,
        VoteChoice choice,
        string calldata reason
    ) external returns (uint256 votingPower);
    
    function executeProposal(
        bytes32 proposalId
    ) external returns (bool success);
    
    function cancelProposal(
        bytes32 proposalId,
        string calldata reason
    ) external;
    
    function queueProposal(
        bytes32 proposalId
    ) external;
    
    // Advanced voting functions
    function castVoteBySig(
        bytes32 proposalId,
        VoteChoice choice,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 votingPower);
    
    function batchVote(
        bytes32[] calldata proposalIds,
        VoteChoice[] calldata choices
    ) external returns (uint256[] memory votingPowers);
    
    function delegateVote(
        bytes32 proposalId,
        address delegatee,
        VoteChoice choice
    ) external returns (uint256 votingPower);
    
    function voteWithSnapshot(
        bytes32 proposalId,
        VoteChoice choice,
        uint256 blockNumber
    ) external returns (uint256 votingPower);
    
    // Delegation functions
    function delegateVotingPower(
        address delegatee,
        uint256 amount
    ) external;
    
    function revokeDelegation(
        address delegatee,
        uint256 amount
    ) external;
    
    function delegateWithExpiry(
        address delegatee,
        uint256 amount,
        uint256 expiry
    ) external;
    
    function batchDelegate(
        address[] calldata delegatees,
        uint256[] calldata amounts
    ) external;
    
    function transferDelegation(
        address oldDelegatee,
        address newDelegatee,
        uint256 amount
    ) external;
    
    // Emergency functions
    function createEmergencyProposal(
        string calldata title,
        string calldata description,
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata calldatas,
        string calldata justification
    ) external returns (bytes32 proposalId);
    
    function executeEmergencyAction(
        bytes32 proposalId
    ) external returns (bool success);
    
    function vetoProposal(
        bytes32 proposalId,
        string calldata reason
    ) external;
    
    function emergencyPause() external;
    
    function emergencyUnpause() external;
    
    // Configuration functions
    function updateGovernanceParameters(
        uint256 votingDelay,
        uint256 votingPeriod,
        uint256 proposalThreshold,
        uint256 quorumNumerator,
        uint256 executionDelay
    ) external;
    
    function updateQuorum(
        uint256 newQuorumNumerator
    ) external;
    
    function updateVotingPeriod(
        uint256 newVotingPeriod
    ) external;
    
    function updateProposalThreshold(
        uint256 newThreshold
    ) external;
    
    function updateExecutionDelay(
        uint256 newDelay
    ) external;
    
    function setVetoAuthority(
        address vetoAuthority,
        bool enabled
    ) external;
    
    // Timelock functions
    function updateTimelockDelay(
        bytes32 proposalId,
        uint256 newDelay
    ) external;
    
    function cancelTimelockExecution(
        bytes32 proposalId
    ) external;
    
    function executeTimelockProposal(
        bytes32 proposalId
    ) external returns (bool success);
    
    function getTimelockStatus(
        bytes32 proposalId
    ) external view returns (
        bool isQueued,
        uint256 executionTime,
        bool canExecute
    );
    
    // Snapshot functions
    function createVotingPowerSnapshot() external returns (uint256 snapshotId);
    
    function getVotingPowerAtSnapshot(
        address account,
        uint256 snapshotId
    ) external view returns (uint256 votingPower);
    
    function getTotalVotingPowerAtSnapshot(
        uint256 snapshotId
    ) external view returns (uint256 totalVotingPower);
    
    function updateVotingPowerSnapshot(
        address account
    ) external;
    
    // View functions - Proposal information
    function getProposal(
        bytes32 proposalId
    ) external view returns (Proposal memory);
    
    function getProposalStatus(
        bytes32 proposalId
    ) external view returns (ProposalStatus);
    
    function getProposalResult(
        bytes32 proposalId
    ) external view returns (ProposalResult memory);
    
    function getAllProposals() external view returns (bytes32[] memory);
    
    function getActiveProposals() external view returns (bytes32[] memory);
    
    function getUserProposals(
        address user
    ) external view returns (bytes32[] memory);
    
    function getProposalsByType(
        ProposalType proposalType
    ) external view returns (bytes32[] memory);
    
    // View functions - Voting information
    function getVote(
        bytes32 proposalId,
        address voter
    ) external view returns (Vote memory);
    
    function getProposalVotes(
        bytes32 proposalId
    ) external view returns (
        uint256 forVotes,
        uint256 againstVotes,
        uint256 abstainVotes
    );
    
    function hasVoted(
        bytes32 proposalId,
        address voter
    ) external view returns (bool);
    
    function getVotingPower(
        address account
    ) external view returns (uint256 votingPower);
    
    function getVotingPowerAt(
        address account,
        uint256 blockNumber
    ) external view returns (uint256 votingPower);
    
    // View functions - Delegation information
    function getDelegation(
        address delegator,
        address delegatee
    ) external view returns (Delegation memory);
    
    function getUserDelegations(
        address user
    ) external view returns (Delegation[] memory);
    
    function getDelegatedVotingPower(
        address delegatee
    ) external view returns (uint256 delegatedPower);
    
    function getDelegators(
        address delegatee
    ) external view returns (address[] memory);
    
    function getTotalDelegatedPower() external view returns (uint256);
    
    // View functions - Quorum and thresholds
    function getQuorum(
        bytes32 proposalId
    ) external view returns (uint256 quorum);
    
    function getCurrentQuorum() external view returns (uint256 quorum);
    
    function isQuorumReached(
        bytes32 proposalId
    ) external view returns (bool);
    
    function getProposalThreshold() external view returns (uint256 threshold);
    
    function canCreateProposal(
        address account
    ) external view returns (bool);
    
    // View functions - Timing information
    function getVotingPeriod(
        bytes32 proposalId
    ) external view returns (uint256 startTime, uint256 endTime);
    
    function isVotingActive(
        bytes32 proposalId
    ) external view returns (bool);
    
    function getTimeRemaining(
        bytes32 proposalId
    ) external view returns (uint256 timeRemaining);
    
    function canExecute(
        bytes32 proposalId
    ) external view returns (bool);
    
    function getExecutionTime(
        bytes32 proposalId
    ) external view returns (uint256 executionTime);
    
    // View functions - Governance metrics
    function getGovernanceMetrics() external view returns (GovernanceMetrics memory);
    
    function getVoterProfile(
        address voter
    ) external view returns (VoterProfile memory);
    
    function getParticipationRate(
        bytes32 proposalId
    ) external view returns (uint256 participationRate);
    
    function getAverageParticipation() external view returns (uint256 averageParticipation);
    
    function getTopVoters(
        uint256 count
    ) external view returns (address[] memory voters, uint256[] memory votingPowers);
    
    // View functions - Configuration
    function getGovernanceConfig() external view returns (GovernanceConfig memory);
    
    function getVotingDelay() external view returns (uint256);
    
    function getVotingPeriod() external view returns (uint256);
    
    function getExecutionDelay() external view returns (uint256);
    
    function getGracePeriod() external view returns (uint256);
    
    function isVetoEnabled() external view returns (bool);
    
    function isDelegationEnabled() external view returns (bool);
    
    // View functions - Proposal validation
    function validateProposal(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata calldatas,
        string[] calldata signatures
    ) external view returns (bool isValid, string memory reason);
    
    function estimateExecutionGas(
        bytes32 proposalId
    ) external view returns (uint256 gasEstimate);
    
    function canCancel(
        bytes32 proposalId,
        address canceller
    ) external view returns (bool);
    
    function canVeto(
        bytes32 proposalId,
        address vetoer
    ) external view returns (bool);
    
    // View functions - Historical data
    function getProposalHistory(
        address proposer,
        uint256 fromTimestamp,
        uint256 toTimestamp
    ) external view returns (bytes32[] memory);
    
    function getVotingHistory(
        address voter,
        uint256 fromTimestamp,
        uint256 toTimestamp
    ) external view returns (Vote[] memory);
    
    function getDelegationHistory(
        address account,
        uint256 fromTimestamp,
        uint256 toTimestamp
    ) external view returns (Delegation[] memory);
    
    function getExecutionHistory(
        uint256 fromTimestamp,
        uint256 toTimestamp
    ) external view returns (bytes32[] memory);
    
    // View functions - Analytics
    function getProposalSuccessRate() external view returns (uint256 successRate);
    
    function getAverageVotingPower() external view returns (uint256 averageVotingPower);
    
    function getVotingPowerDistribution() external view returns (
        uint256[] memory ranges,
        uint256[] memory counts
    );
    
    function getProposalTypeDistribution() external view returns (
        ProposalType[] memory types,
        uint256[] memory counts
    );
    
    function getMostActiveVoters(
        uint256 count
    ) external view returns (address[] memory voters, uint256[] memory voteCounts);
    
    // View functions - System health
    function isSystemHealthy() external view returns (bool);
    
    function getSystemHealth() external view returns (
        bool isHealthy,
        uint256 participationHealth,
        uint256 proposalHealth,
        uint256 executionHealth
    );
    
    function getGovernanceActivity() external view returns (
        uint256 recentProposals,
        uint256 recentVotes,
        uint256 activeParticipants
    );
    
    function isEmergencyMode() external view returns (bool);
    
    function getLastActivity() external view returns (uint256 lastActivityTime);
}
