// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./GovernanceToken.sol";

/**
 * @title Voting
 * @dev Advanced governance voting system with proposal management and execution
 */
contract Voting is AccessControl, ReentrancyGuard, Pausable {
    using Math for uint256;

    bytes32 public constant PROPOSER_ROLE = keccak256("PROPOSER_ROLE");
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");

    // Constants
    uint256 public constant PRECISION = 1e18;
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant MIN_VOTING_PERIOD = 1 days;
    uint256 public constant MAX_VOTING_PERIOD = 14 days;
    uint256 public constant MIN_VOTING_DELAY = 1 hours;
    uint256 public constant MAX_VOTING_DELAY = 7 days;
    uint256 public constant MAX_ACTIONS = 10;

    // Enums
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

    enum VoteType {
        Against,
        For,
        Abstain
    }

    // Structs
    struct Proposal {
        uint256 id;
        address proposer;
        address[] targets;
        uint256[] values;
        bytes[] calldatas;
        string description;
        uint256 startBlock;
        uint256 endBlock;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
        bool canceled;
        bool executed;
        uint256 eta; // Execution time
        mapping(address => Receipt) receipts;
    }

    struct Receipt {
        bool hasVoted;
        VoteType support;
        uint256 votes;
        string reason;
    }

    struct ProposalCore {
        uint256 id;
        address proposer;
        uint256 startBlock;
        uint256 endBlock;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
        bool canceled;
        bool executed;
        uint256 eta;
        string description;
    }

    struct VotingConfig {
        uint256 votingDelay;
        uint256 votingPeriod;
        uint256 proposalThreshold;
        uint256 quorumNumerator;
        uint256 quorumDenominator;
        uint256 timelock;
        bool requireSupermajority;
        uint256 supermajorityThreshold;
    }

    struct ProposalStats {
        uint256 totalVoters;
        uint256 participationRate;
        uint256 averageVotingPower;
        uint256 largestVote;
        address largestVoter;
        uint256 proposalWeight;
    }

    struct VoterProfile {
        uint256 totalVotes;
        uint256 proposalsVoted;
        uint256 proposalsCreated;
        uint256 votingPower;
        uint256 delegatedPower;
        uint256 lastVoteBlock;
        bool isActive;
    }

    // Storage
    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => ProposalStats) public proposalStats;
    mapping(address => VoterProfile) public voterProfiles;
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    mapping(address => uint256) public latestProposalIds;
    mapping(bytes32 => bool) public queuedTransactions;
    
    GovernanceToken public governanceToken;
    VotingConfig public votingConfig;
    
    uint256 public proposalCount;
    uint256 public totalProposalsExecuted;
    uint256 public totalVotesCast;
    address public timelock;
    address public guardian;
    bool public emergencyMode;
    
    // Events
    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
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
        uint256 indexed proposalId,
        VoteType support,
        uint256 votes,
        string reason
    );
    
    event ProposalCanceled(uint256 indexed proposalId);
    event ProposalQueued(uint256 indexed proposalId, uint256 eta);
    event ProposalExecuted(uint256 indexed proposalId);
    event VotingConfigUpdated(VotingConfig newConfig);
    event EmergencyModeToggled(bool enabled);
    event GuardianChanged(address indexed oldGuardian, address indexed newGuardian);
    event TimelockChanged(address indexed oldTimelock, address indexed newTimelock);

    constructor(
        address _governanceToken,
        address _timelock,
        address _guardian
    ) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(PROPOSER_ROLE, msg.sender);
        _grantRole(EXECUTOR_ROLE, msg.sender);
        _grantRole(GUARDIAN_ROLE, _guardian);
        
        governanceToken = GovernanceToken(_governanceToken);
        timelock = _timelock;
        guardian = _guardian;
        
        // Default voting configuration
        votingConfig = VotingConfig({
            votingDelay: 1 days,
            votingPeriod: 3 days,
            proposalThreshold: 100000 * 1e18, // 100k tokens
            quorumNumerator: 4, // 4%
            quorumDenominator: 100,
            timelock: 2 days,
            requireSupermajority: false,
            supermajorityThreshold: 6700 // 67%
        });
    }

    /**
     * @dev Create a new proposal
     */
    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) external returns (uint256) {
        require(targets.length == values.length && targets.length == calldatas.length, "Proposal function information arity mismatch");
        require(targets.length > 0, "Must provide actions");
        require(targets.length <= MAX_ACTIONS, "Too many actions");
        
        // Check proposer has enough voting power
        uint256 proposerVotes = governanceToken.getVotes(msg.sender);
        require(proposerVotes >= votingConfig.proposalThreshold, "Proposer votes below proposal threshold");
        
        // Check if proposer has pending proposal
        uint256 latestProposalId = latestProposalIds[msg.sender];
        if (latestProposalId != 0) {
            ProposalState proposerLatestProposalState = state(latestProposalId);
            require(proposerLatestProposalState != ProposalState.Active, "One live proposal per proposer, found an already active proposal");
            require(proposerLatestProposalState != ProposalState.Pending, "One live proposal per proposer, found an already pending proposal");
        }
        
        proposalCount++;
        uint256 proposalId = proposalCount;
        
        Proposal storage newProposal = proposals[proposalId];
        newProposal.id = proposalId;
        newProposal.proposer = msg.sender;
        newProposal.targets = targets;
        newProposal.values = values;
        newProposal.calldatas = calldatas;
        newProposal.description = description;
        newProposal.startBlock = block.number + votingConfig.votingDelay;
        newProposal.endBlock = newProposal.startBlock + votingConfig.votingPeriod;
        
        latestProposalIds[msg.sender] = proposalId;
        
        // Update voter profile
        voterProfiles[msg.sender].proposalsCreated++;
        
        emit ProposalCreated(
            proposalId,
            msg.sender,
            targets,
            values,
            new string[](targets.length),
            calldatas,
            newProposal.startBlock,
            newProposal.endBlock,
            description
        );
        
        return proposalId;
    }

    /**
     * @dev Cast a vote on a proposal
     */
    function castVote(uint256 proposalId, VoteType support) external returns (uint256) {
        return _castVote(msg.sender, proposalId, support, "");
    }

    /**
     * @dev Cast a vote with reason
     */
    function castVoteWithReason(
        uint256 proposalId,
        VoteType support,
        string calldata reason
    ) external returns (uint256) {
        return _castVote(msg.sender, proposalId, support, reason);
    }

    /**
     * @dev Cast vote by signature
     */
    function castVoteBySig(
        uint256 proposalId,
        VoteType support,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256) {
        bytes32 domainSeparator = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)"),
                keccak256(bytes("CoreLiquid Governance")),
                block.chainid,
                address(this)
            )
        );
        
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Ballot(uint256 proposalId,uint8 support)"),
                proposalId,
                uint8(support)
            )
        );
        
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        address signatory = ecrecover(digest, v, r, s);
        require(signatory != address(0), "Invalid signature");
        
        return _castVote(signatory, proposalId, support, "");
    }

    /**
     * @dev Queue a successful proposal for execution
     */
    function queue(uint256 proposalId) external {
        require(state(proposalId) == ProposalState.Succeeded, "Proposal can only be queued if it is succeeded");
        
        Proposal storage proposal = proposals[proposalId];
        uint256 eta = block.timestamp + votingConfig.timelock;
        proposal.eta = eta;
        
        for (uint256 i = 0; i < proposal.targets.length; i++) {
            _queueOrRevert(proposal.targets[i], proposal.values[i], proposal.calldatas[i], eta);
        }
        
        emit ProposalQueued(proposalId, eta);
    }

    /**
     * @dev Execute a queued proposal
     */
    function execute(uint256 proposalId) external payable nonReentrant {
        require(state(proposalId) == ProposalState.Queued, "Proposal can only be executed if it is queued");
        
        Proposal storage proposal = proposals[proposalId];
        require(block.timestamp >= proposal.eta, "Proposal hasn't finished timelock");
        require(block.timestamp <= proposal.eta + 14 days, "Transaction is stale");
        
        proposal.executed = true;
        
        for (uint256 i = 0; i < proposal.targets.length; i++) {
            _executeTransaction(proposal.targets[i], proposal.values[i], proposal.calldatas[i]);
        }
        
        totalProposalsExecuted++;
        
        emit ProposalExecuted(proposalId);
    }

    /**
     * @dev Cancel a proposal
     */
    function cancel(uint256 proposalId) external {
        ProposalState currentState = state(proposalId);
        require(currentState != ProposalState.Executed, "Cannot cancel executed proposal");
        
        Proposal storage proposal = proposals[proposalId];
        
        // Only proposer or guardian can cancel
        require(
            msg.sender == proposal.proposer ||
            hasRole(GUARDIAN_ROLE, msg.sender) ||
            governanceToken.getVotes(proposal.proposer) < votingConfig.proposalThreshold,
            "Proposer above threshold"
        );
        
        proposal.canceled = true;
        
        // Cancel queued transactions
        for (uint256 i = 0; i < proposal.targets.length; i++) {
            bytes32 txHash = keccak256(abi.encode(proposal.targets[i], proposal.values[i], proposal.calldatas[i], proposal.eta));
            queuedTransactions[txHash] = false;
        }
        
        emit ProposalCanceled(proposalId);
    }

    /**
     * @dev Get proposal state
     */
    function state(uint256 proposalId) public view returns (ProposalState) {
        require(proposalId > 0 && proposalId <= proposalCount, "Invalid proposal id");
        
        Proposal storage proposal = proposals[proposalId];
        
        if (proposal.canceled) {
            return ProposalState.Canceled;
        } else if (block.number <= proposal.startBlock) {
            return ProposalState.Pending;
        } else if (block.number <= proposal.endBlock) {
            return ProposalState.Active;
        } else if (proposal.forVotes <= proposal.againstVotes || proposal.forVotes < quorum(proposalId)) {
            return ProposalState.Defeated;
        } else if (proposal.eta == 0) {
            return ProposalState.Succeeded;
        } else if (proposal.executed) {
            return ProposalState.Executed;
        } else if (block.timestamp >= proposal.eta + 14 days) {
            return ProposalState.Expired;
        } else {
            return ProposalState.Queued;
        }
    }

    /**
     * @dev Get required quorum for a proposal
     */
    function quorum(uint256 proposalId) public view returns (uint256) {
        Proposal storage proposal = proposals[proposalId];
        uint256 totalSupply = governanceToken.totalSupply();
        return (totalSupply * votingConfig.quorumNumerator) / votingConfig.quorumDenominator;
    }

    /**
     * @dev Get proposal details
     */
    function getProposal(uint256 proposalId) external view returns (ProposalCore memory) {
        require(proposalId > 0 && proposalId <= proposalCount, "Invalid proposal id");
        
        Proposal storage proposal = proposals[proposalId];
        
        return ProposalCore({
            id: proposal.id,
            proposer: proposal.proposer,
            startBlock: proposal.startBlock,
            endBlock: proposal.endBlock,
            forVotes: proposal.forVotes,
            againstVotes: proposal.againstVotes,
            abstainVotes: proposal.abstainVotes,
            canceled: proposal.canceled,
            executed: proposal.executed,
            eta: proposal.eta,
            description: proposal.description
        });
    }

    /**
     * @dev Get proposal actions
     */
    function getActions(uint256 proposalId) external view returns (
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas
    ) {
        Proposal storage proposal = proposals[proposalId];
        return (proposal.targets, proposal.values, proposal.calldatas);
    }

    /**
     * @dev Get receipt for a voter on a proposal
     */
    function getReceipt(uint256 proposalId, address voter) external view returns (Receipt memory) {
        return proposals[proposalId].receipts[voter];
    }

    /**
     * @dev Get voter profile
     */
    function getVoterProfile(address voter) external view returns (VoterProfile memory) {
        return voterProfiles[voter];
    }

    /**
     * @dev Get proposal statistics
     */
    function getProposalStats(uint256 proposalId) external view returns (ProposalStats memory) {
        return proposalStats[proposalId];
    }

    // Admin functions
    function updateVotingConfig(VotingConfig memory newConfig) external onlyRole(ADMIN_ROLE) {
        require(newConfig.votingDelay >= MIN_VOTING_DELAY && newConfig.votingDelay <= MAX_VOTING_DELAY, "Invalid voting delay");
        require(newConfig.votingPeriod >= MIN_VOTING_PERIOD && newConfig.votingPeriod <= MAX_VOTING_PERIOD, "Invalid voting period");
        require(newConfig.quorumNumerator <= newConfig.quorumDenominator, "Invalid quorum");
        
        votingConfig = newConfig;
        emit VotingConfigUpdated(newConfig);
    }

    function setTimelock(address newTimelock) external onlyRole(ADMIN_ROLE) {
        address oldTimelock = timelock;
        timelock = newTimelock;
        emit TimelockChanged(oldTimelock, newTimelock);
    }

    function setGuardian(address newGuardian) external onlyRole(ADMIN_ROLE) {
        address oldGuardian = guardian;
        guardian = newGuardian;
        _revokeRole(GUARDIAN_ROLE, oldGuardian);
        _grantRole(GUARDIAN_ROLE, newGuardian);
        emit GuardianChanged(oldGuardian, newGuardian);
    }

    function toggleEmergencyMode() external onlyRole(GUARDIAN_ROLE) {
        emergencyMode = !emergencyMode;
        emit EmergencyModeToggled(emergencyMode);
    }

    function pause() external onlyRole(GUARDIAN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    // Internal functions
    function _castVote(
        address voter,
        uint256 proposalId,
        VoteType support,
        string memory reason
    ) internal returns (uint256) {
        require(state(proposalId) == ProposalState.Active, "Voting is closed");
        require(!hasVoted[proposalId][voter], "Voter already voted");
        
        uint256 votes = governanceToken.getVotes(voter);
        require(votes > 0, "No voting power");
        
        Proposal storage proposal = proposals[proposalId];
        Receipt storage receipt = proposal.receipts[voter];
        
        receipt.hasVoted = true;
        receipt.support = support;
        receipt.votes = votes;
        receipt.reason = reason;
        
        hasVoted[proposalId][voter] = true;
        
        if (support == VoteType.Against) {
            proposal.againstVotes += votes;
        } else if (support == VoteType.For) {
            proposal.forVotes += votes;
        } else {
            proposal.abstainVotes += votes;
        }
        
        // Update statistics
        ProposalStats storage stats = proposalStats[proposalId];
        stats.totalVoters++;
        stats.averageVotingPower = (stats.averageVotingPower * (stats.totalVoters - 1) + votes) / stats.totalVoters;
        
        if (votes > stats.largestVote) {
            stats.largestVote = votes;
            stats.largestVoter = voter;
        }
        
        // Update voter profile
        VoterProfile storage profile = voterProfiles[voter];
        profile.totalVotes += votes;
        profile.proposalsVoted++;
        profile.lastVoteBlock = block.number;
        profile.isActive = true;
        
        totalVotesCast++;
        
        emit VoteCast(voter, proposalId, support, votes, reason);
        
        return votes;
    }

    function _queueOrRevert(
        address target,
        uint256 value,
        bytes memory data,
        uint256 eta
    ) internal {
        bytes32 txHash = keccak256(abi.encode(target, value, data, eta));
        require(!queuedTransactions[txHash], "Proposal action already queued at eta");
        queuedTransactions[txHash] = true;
    }

    function _executeTransaction(
        address target,
        uint256 value,
        bytes memory data
    ) internal {
        (bool success, ) = target.call{value: value}(data);
        require(success, "Transaction execution reverted");
    }

    // View functions
    function getVotingConfig() external view returns (VotingConfig memory) {
        return votingConfig;
    }

    function proposalDeadline(uint256 proposalId) external view returns (uint256) {
        return proposals[proposalId].endBlock;
    }

    function proposalSnapshot(uint256 proposalId) external view returns (uint256) {
        return proposals[proposalId].startBlock;
    }

    function proposalEta(uint256 proposalId) external view returns (uint256) {
        return proposals[proposalId].eta;
    }

    function proposalThreshold() external view returns (uint256) {
        return votingConfig.proposalThreshold;
    }

    function votingDelay() external view returns (uint256) {
        return votingConfig.votingDelay;
    }

    function votingPeriod() external view returns (uint256) {
        return votingConfig.votingPeriod;
    }

    receive() external payable {}
}