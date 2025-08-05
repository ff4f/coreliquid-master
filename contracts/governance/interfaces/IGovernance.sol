// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IGovernance
 * @dev Interface for Core protocol governance system
 */
interface IGovernance {
    /**
     * @dev Proposal states
     */
    enum ProposalState {
        Pending,
        Active,
        Canceled,
        Defeated,
        Succeeded,
        Queued,
        Expired,
        Executed
    }

    /**
     * @dev Proposal structure
     */
    struct Proposal {
        uint256 id;
        address proposer;
        address[] targets;
        uint256[] values;
        string[] signatures;
        bytes[] calldatas;
        uint256 startBlock;
        uint256 endBlock;
        string description;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
        bool canceled;
        bool executed;
        mapping(address => Receipt) receipts;
    }

    /**
     * @dev Vote receipt structure
     */
    struct Receipt {
        bool hasVoted;
        uint8 support; // 0=against, 1=for, 2=abstain
        uint256 votes;
    }

    /**
     * @dev Voting configuration
     */
    struct VotingConfig {
        uint256 votingDelay; // Delay before voting starts
        uint256 votingPeriod; // Duration of voting period
        uint256 proposalThreshold; // Minimum tokens to create proposal
        uint256 quorumNumerator; // Quorum percentage numerator
        uint256 quorumDenominator; // Quorum percentage denominator
    }

    /**
     * @dev Events
     */
    event ProposalCreated(
        uint256 proposalId,
        address proposer,
        address[] targets,
        uint256[] values,
        string[] signatures,
        bytes[] calldatas,
        uint256 startBlock,
        uint256 endBlock,
        string description
    );

    event VoteCast(
        address indexed voter,
        uint256 proposalId,
        uint8 support,
        uint256 weight,
        string reason
    );

    event ProposalCanceled(uint256 proposalId);
    event ProposalExecuted(uint256 proposalId);
    event ProposalQueued(uint256 proposalId, uint256 eta);
    event VotingDelaySet(uint256 oldVotingDelay, uint256 newVotingDelay);
    event VotingPeriodSet(uint256 oldVotingPeriod, uint256 newVotingPeriod);
    event ProposalThresholdSet(uint256 oldProposalThreshold, uint256 newProposalThreshold);
    event QuorumNumeratorUpdated(uint256 oldQuorumNumerator, uint256 newQuorumNumerator);

    /**
     * @dev Core governance functions
     */
    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) external returns (uint256);

    function execute(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) external payable returns (uint256);

    function cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) external returns (uint256);

    function castVote(uint256 proposalId, uint8 support) external returns (uint256);

    function castVoteWithReason(
        uint256 proposalId,
        uint8 support,
        string calldata reason
    ) external returns (uint256);

    function castVoteBySig(
        uint256 proposalId,
        uint8 support,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256);

    /**
     * @dev Proposal state functions
     */
    function state(uint256 proposalId) external view returns (ProposalState);

    function proposalSnapshot(uint256 proposalId) external view returns (uint256);

    function proposalDeadline(uint256 proposalId) external view returns (uint256);

    function proposalThreshold() external view returns (uint256);

    function getVotes(address account, uint256 blockNumber) external view returns (uint256);

    function getPastVotes(address account, uint256 blockNumber) external view returns (uint256);

    function getPastTotalSupply(uint256 blockNumber) external view returns (uint256);

    /**
     * @dev Voting configuration functions
     */
    function votingDelay() external view returns (uint256);

    function votingPeriod() external view returns (uint256);

    function quorum(uint256 blockNumber) external view returns (uint256);

    function quorumNumerator() external view returns (uint256);

    function quorumDenominator() external view returns (uint256);

    /**
     * @dev Proposal management functions
     */
    function getProposal(uint256 proposalId) external view returns (
        uint256 id,
        address proposer,
        uint256 eta,
        uint256 startBlock,
        uint256 endBlock,
        uint256 forVotes,
        uint256 againstVotes,
        uint256 abstainVotes,
        bool canceled,
        bool executed
    );

    function getActions(uint256 proposalId) external view returns (
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas
    );

    function getReceipt(uint256 proposalId, address voter) external view returns (
        bool hasVoted,
        uint8 support,
        uint256 votes
    );

    function proposalCount() external view returns (uint256);

    function latestProposalIds(address proposer) external view returns (uint256);

    /**
     * @dev Administrative functions
     */
    function setVotingDelay(uint256 newVotingDelay) external;

    function setVotingPeriod(uint256 newVotingPeriod) external;

    function setProposalThreshold(uint256 newProposalThreshold) external;

    function updateQuorumNumerator(uint256 newQuorumNumerator) external;

    /**
     * @dev Timelock functions
     */
    function timelock() external view returns (address);

    function updateTimelock(address newTimelock) external;

    /**
     * @dev Token functions
     */
    function token() external view returns (address);

    /**
     * @dev Delegation functions
     */
    function delegate(address delegatee) external;

    function delegateBySig(
        address delegatee,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    function delegates(address account) external view returns (address);

    function getCurrentVotes(address account) external view returns (uint256);

    function getPriorVotes(address account, uint256 blockNumber) external view returns (uint256);

    /**
     * @dev Emergency functions
     */
    function emergencyExecute(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas
    ) external;

    function setEmergencyAdmin(address newEmergencyAdmin) external;

    function emergencyAdmin() external view returns (address);

    /**
     * @dev Guardian functions
     */
    function setGuardian(address newGuardian) external;

    function guardian() external view returns (address);

    function guardianCancel(uint256 proposalId) external;

    /**
     * @dev Proposal validation
     */
    function validateProposal(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas
    ) external view returns (bool);

    /**
     * @dev Voting power functions
     */
    function getVotingPower(address account) external view returns (uint256);

    function getTotalVotingPower() external view returns (uint256);

    /**
     * @dev Proposal execution helpers
     */
    function hashProposal(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) external pure returns (uint256);

    /**
     * @dev Version and compatibility
     */
    function version() external view returns (string memory);

    function COUNTING_MODE() external pure returns (string memory);

    /**
     * @dev Clock functions for voting snapshots
     */
    function clock() external view returns (uint48);

    function CLOCK_MODE() external pure returns (string memory);
}