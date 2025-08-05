// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "../interfaces/IGovernance.sol";

/**
 * @title Governance
 * @dev Comprehensive governance system for CoreLiquid Protocol
 * @author CoreLiquid Protocol
 */
contract Governance is IGovernance, AccessControl, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;
    using Math for uint256;

    // Roles
    bytes32 public constant GOVERNANCE_MANAGER_ROLE = keccak256("GOVERNANCE_MANAGER_ROLE");
    bytes32 public constant PROPOSER_ROLE = keccak256("PROPOSER_ROLE");
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
    bytes32 public constant TIMELOCK_ROLE = keccak256("TIMELOCK_ROLE");

    // Constants
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant MIN_VOTING_PERIOD = 1 days;
    uint256 public constant MAX_VOTING_PERIOD = 30 days;
    uint256 public constant MIN_VOTING_DELAY = 1 hours;
    uint256 public constant MAX_VOTING_DELAY = 7 days;
    uint256 public constant MIN_PROPOSAL_THRESHOLD = 1e18; // 1 token
    uint256 public constant MAX_PROPOSAL_THRESHOLD = 1000000e18; // 1M tokens

    // Governance token
    IERC20 public immutable governanceToken;

    // Storage mappings
    mapping(bytes32 => IGovernance.Proposal) public proposals;
    mapping(bytes32 => mapping(address => IGovernance.Vote)) public votes;
    mapping(address => IGovernance.Delegate) public delegates;
    mapping(bytes32 => IGovernance.Committee) public committees;
    mapping(bytes32 => IGovernance.Treasury) public treasuries;
    mapping(bytes32 => IGovernance.Snapshot) public snapshots;
    mapping(address => IGovernance.VotingPower) public votingPowers;
    mapping(address => bytes32[]) public userProposals;
    mapping(address => bytes32[]) public userVotes;
    mapping(address => bytes32[]) public userDelegations;
    
    // Global arrays
    bytes32[] public allProposals;
    bytes32[] public activeProposals;
    bytes32[] public executedProposals;
    bytes32[] public allCommittees;
    bytes32[] public allSnapshots;
    
    // Governance configuration
    GovernanceConfig public config;
    
    // Counters
    uint256 public totalProposals;
    uint256 public totalVotes;
    uint256 public totalDelegations;
    uint256 public totalExecutions;

    // State variables
    bool public emergencyMode;
    uint256 public lastSnapshotBlock;
    mapping(bytes32 => bool) public proposalQueued;
    mapping(bytes32 => uint256) public proposalEta;

    constructor(
        address _governanceToken,
        uint256 _votingDelay,
        uint256 _votingPeriod,
        uint256 _proposalThreshold,
        uint256 _quorum
    ) {
        require(_governanceToken != address(0), "Invalid governance token");
        require(_votingDelay >= MIN_VOTING_DELAY && _votingDelay <= MAX_VOTING_DELAY, "Invalid voting delay");
        require(_votingPeriod >= MIN_VOTING_PERIOD && _votingPeriod <= MAX_VOTING_PERIOD, "Invalid voting period");
        require(_proposalThreshold >= MIN_PROPOSAL_THRESHOLD && _proposalThreshold <= MAX_PROPOSAL_THRESHOLD, "Invalid proposal threshold");
        require(_quorum > 0 && _quorum <= BASIS_POINTS, "Invalid quorum");
        
        governanceToken = IERC20(_governanceToken);
        
        config = GovernanceConfig({
            votingDelay: _votingDelay,
            votingPeriod: _votingPeriod,
            proposalThreshold: _proposalThreshold,
            quorumNumerator: _quorum,
            quorumDenominator: 10000,
            executionDelay: 2 days,
            timelock: address(0),
            guardian: msg.sender,
            emergencyMode: false,
            maxProposalsPerUser: 10,
            cooldownPeriod: 1 days
        });
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(GOVERNANCE_MANAGER_ROLE, msg.sender);
        _grantRole(PROPOSER_ROLE, msg.sender);
        _grantRole(EXECUTOR_ROLE, msg.sender);
        _grantRole(EMERGENCY_ROLE, msg.sender);
        _grantRole(TIMELOCK_ROLE, msg.sender);
    }

    // Core governance functions
    function propose(
        string calldata title,
        string calldata description,
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata calldatas,
        ProposalConfig calldata proposalConfig
    ) external returns (bytes32 proposalId) {
        require(targets.length == values.length && values.length == calldatas.length, "Array length mismatch");
        require(targets.length > 0 && targets.length <= 10, "Invalid actions count");
        require(getVotingPower(msg.sender) >= config.proposalThreshold, "Insufficient voting power");
        
        proposalId = keccak256(abi.encodePacked(title, block.timestamp, msg.sender));
        
        Proposal storage proposal = proposals[proposalId];
        proposal.proposalId = uint256(proposalId);
        proposal.title = title;
        proposal.description = description;
        proposal.proposer = msg.sender;
        proposal.targets = targets;
        proposal.values = values;
        proposal.calldatas = calldatas;
        proposal.startTime = block.timestamp + config.votingDelay;
        proposal.endTime = proposal.startTime + config.votingPeriod;
        proposal.createdAt = block.timestamp;
        proposal.config = proposalConfig;
        proposal.status = ProposalStatus.PENDING;
        
        userProposals[msg.sender].push(proposalId);
        allProposals.push(proposalId);
        activeProposals.push(proposalId);
        totalProposals++;
        
        // Emit simplified event
        // emit ProposalCreated(proposalId, msg.sender, block.timestamp);
    }

    function castVote(
        bytes32 proposalId,
        IGovernance.VoteType voteType,
        string calldata reason
    ) external {
        require(proposals[proposalId].proposalId != 0, "Proposal not found");
        require(block.timestamp >= proposals[proposalId].startTime, "Voting not started");
        require(block.timestamp <= proposals[proposalId].endTime, "Voting ended");
        require(votes[proposalId][msg.sender].voter == address(0), "Already voted");
        
        uint256 votingPower = getVotingPower(msg.sender);
        require(votingPower > 0, "No voting power");
        
        Vote storage vote = votes[proposalId][msg.sender];
        vote.voter = msg.sender;
        vote.choice = VoteChoice(uint8(voteType));
        vote.votingPower = votingPower;
        vote.timestamp = block.timestamp;
        vote.reason = reason;
        
        Proposal storage proposal = proposals[proposalId];
        if (voteType == IGovernance.VoteType.FOR) {
            proposal.forVotes += votingPower;
        } else if (voteType == IGovernance.VoteType.AGAINST) {
            proposal.againstVotes += votingPower;
        } else {
            proposal.abstainVotes += votingPower;
        }
        proposal.totalVotingPower += votingPower;
        
        userVotes[msg.sender].push(proposalId);
        totalVotes++;
        
        emit VoteCast(uint256(proposalId), msg.sender, VoteChoice(uint8(voteType)), votingPower, reason, block.timestamp);
    }

    function execute(
        bytes32 proposalId
    ) external onlyRole(EXECUTOR_ROLE) {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.proposalId != 0, "Proposal not found");
        require(block.timestamp > proposal.endTime, "Voting not ended");
        require(proposal.status == ProposalStatus.SUCCEEDED || proposal.status == ProposalStatus.QUEUED, "Cannot execute");
        
        if (proposal.status == ProposalStatus.SUCCEEDED) {
            require(proposalQueued[proposalId], "Proposal not queued");
            require(block.timestamp >= proposalEta[proposalId], "Timelock not expired");
        }
        
        proposal.status = ProposalStatus.EXECUTED;
        proposal.executionTime = block.timestamp;
        
        // Execute proposal actions
        for (uint256 i = 0; i < proposal.targets.length; i++) {
            (bool success, bytes memory returnData) = proposal.targets[i].call{
                value: proposal.values[i]
            }(proposal.calldatas[i]);
            
            if (!success) {
                if (returnData.length > 0) {
                    assembly {
                        let returnDataSize := mload(returnData)
                        revert(add(32, returnData), returnDataSize)
                    }
                } else {
                    revert("Execution failed");
                }
            }
        }
        
        _removeFromActiveProposals(proposalId);
        executedProposals.push(proposalId);
        totalExecutions++;
        
        emit ProposalExecuted(uint256(proposalId), true, "", block.timestamp);
    }

    function cancel(
        bytes32 proposalId
    ) external {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.proposalId != 0, "Proposal not found");
        require(
            msg.sender == proposal.proposer || 
            hasRole(GOVERNANCE_MANAGER_ROLE, msg.sender) ||
            getVotingPower(proposal.proposer) < config.proposalThreshold,
            "Cannot cancel"
        );
        require(
            proposal.status == ProposalStatus.PENDING || 
            proposal.status == ProposalStatus.ACTIVE,
            "Cannot cancel"
        );
        
        proposal.status = ProposalStatus.CANCELED;
        // proposal.canceledAt = block.timestamp; // Field not available
        
        _removeFromActiveProposals(proposalId);
        
        emit ProposalCanceled(uint256(proposalId), msg.sender, "Canceled", block.timestamp);
    }

    function queue(
        bytes32 proposalId
    ) external {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.proposalId != 0, "Proposal not found");
        require(proposal.status == ProposalStatus.SUCCEEDED, "Proposal not succeeded");
        
        proposal.status = ProposalStatus.QUEUED;
        proposalQueued[proposalId] = true;
        proposalEta[proposalId] = block.timestamp + config.executionDelay;
        
        emit ProposalQueued(uint256(proposalId), proposalEta[proposalId], block.timestamp);
    }

    // Delegation functions
    function delegate(
        address delegatee,
        uint256 amount,
        DelegationConfig calldata delegationConfig
    ) external {
        require(delegatee != address(0), "Invalid delegatee");
        require(amount > 0, "Invalid amount");
        require(governanceToken.balanceOf(msg.sender) >= amount, "Insufficient balance");
        
        bytes32 delegationId = keccak256(abi.encodePacked(msg.sender, delegatee, block.timestamp));
        
        IGovernance.Delegate storage delegation = delegates[msg.sender];
        delegation.delegator = msg.sender;
        delegation.delegatee = delegatee;
        delegation.amount = amount;
        delegation.timestamp = block.timestamp;
        delegation.config = delegationConfig;
        delegation.isActive = true;
        
        // Update voting power
        // votingPowers[msg.sender].delegatedOut += amount; // Field not available
        // votingPowers[delegatee].delegatedIn += amount; // Field not available
        
        userDelegations[msg.sender].push(delegationId);
        totalDelegations++;
        
        emit VotingPowerDelegated(msg.sender, delegatee, amount, block.timestamp);
    }

    function undelegate(
        address delegatee
    ) external {
        IGovernance.Delegate storage delegation = delegates[msg.sender];
        require(delegation.isActive, "No active delegation");
        require(delegation.delegatee == delegatee, "Invalid delegatee");
        
        uint256 amount = delegation.amount;
        delegation.isActive = false;
        delegation.undelegatedAt = block.timestamp;
        
        // Update voting power
        // votingPowers[msg.sender].delegatedOut -= amount; // Field not available
        // votingPowers[delegatee].delegatedIn -= amount; // Field not available
        
        emit VotingPowerUndelegated(msg.sender, delegatee, amount, block.timestamp);
    }

    function subdelegateVotes(
        address subDelegatee,
        uint256 amount
    ) external {
        require(subDelegatee != address(0), "Invalid sub-delegatee");
        require(amount > 0, "Invalid amount");
        // require(votingPowers[msg.sender].delegatedIn >= amount, "Insufficient delegated power"); // Field not available
        
        // Update voting power
        // votingPowers[msg.sender].delegatedIn -= amount; // Field not available
        // votingPowers[subDelegatee].delegatedIn += amount; // Field not available
        
        emit VotingPowerDelegated(msg.sender, subDelegatee, amount, block.timestamp);
    }

    // Committee functions
    function createCommittee(
        string calldata name,
        string calldata description,
        address[] calldata members,
        CommitteeConfig calldata committeeConfig
    ) external onlyRole(GOVERNANCE_MANAGER_ROLE) returns (bytes32 committeeId) {
        require(members.length > 0, "No members");
        
        committeeId = keccak256(abi.encodePacked(name, block.timestamp));
        
        Committee storage committee = committees[committeeId];
        committee.committeeId = committeeId;
        committee.name = name;
        committee.description = description;
        committee.members = members;
        committee.createdAt = block.timestamp;
        committee.config = committeeConfig;
        committee.isActive = true;
        
        allCommittees.push(committeeId);
        
        emit CommitteeCreated(committeeId, name, members, block.timestamp);
    }

    function addCommitteeMember(
        bytes32 committeeId,
        address member
    ) external onlyRole(GOVERNANCE_MANAGER_ROLE) {
        require(committees[committeeId].isActive, "Committee not found");
        require(member != address(0), "Invalid member");
        
        committees[committeeId].members.push(member);
        
        emit CommitteeMemberAdded(committeeId, member, block.timestamp);
    }

    function removeCommitteeMember(
        bytes32 committeeId,
        address member
    ) external onlyRole(GOVERNANCE_MANAGER_ROLE) {
        require(committees[committeeId].isActive, "Committee not found");
        
        address[] storage members = committees[committeeId].members;
        for (uint256 i = 0; i < members.length; i++) {
            if (members[i] == member) {
                members[i] = members[members.length - 1];
                members.pop();
                break;
            }
        }
        
        emit CommitteeMemberRemoved(committeeId, member, block.timestamp);
    }

    function updateCommitteeConfig(
        bytes32 committeeId,
        CommitteeConfig calldata newConfig
    ) external onlyRole(GOVERNANCE_MANAGER_ROLE) {
        require(committees[committeeId].isActive, "Committee not found");
        
        committees[committeeId].config = newConfig;
        
        emit CommitteeConfigUpdated(committeeId, block.timestamp);
    }

    function createCommitteeProposal(
        bytes32 committeeId,
        string calldata title,
        string calldata description,
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata calldatas
    ) external returns (bytes32 proposalId) {
        require(committees[committeeId].isActive, "Committee not found");
        require(_isCommitteeMember(committeeId, msg.sender), "Not a committee member");
        
        ProposalConfig memory proposalConfig = ProposalConfig({
            quorumRequired: 0,
            votingDelay: 0,
            votingPeriod: 0,
            executionDelay: 0,
            requiresTimelock: false,
            proposalThreshold: 0,
            votingType: VotingType.SIMPLE_MAJORITY,
            allowDelegation: true,
            maxActions: 10
        });
        
        proposalId = this.propose(title, description, targets, values, calldatas, proposalConfig);
    }

    // Treasury functions
    function proposeTreasurySpend(
        address recipient,
        uint256 amount,
        address asset,
        string calldata purpose
    ) external returns (bytes32 proposalId) {
        require(recipient != address(0), "Invalid recipient");
        require(amount > 0, "Invalid amount");
        
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        
        targets[0] = asset;
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature("transfer(address,uint256)", recipient, amount);
        
        ProposalConfig memory proposalConfig = ProposalConfig({
            quorumRequired: 0,
            votingDelay: 0,
            votingPeriod: 0,
            executionDelay: 0,
            requiresTimelock: true,
            proposalThreshold: 0,
            votingType: VotingType.SIMPLE_MAJORITY,
            allowDelegation: true,
            maxActions: 10
        });
        
        proposalId = this.propose(
            string(abi.encodePacked("Treasury Spend: ", purpose)),
            purpose,
            targets,
            values,
            calldatas,
            proposalConfig
        );
    }

    function executeTreasurySpend(
        bytes32 proposalId
    ) external {
        this.execute(proposalId);
    }

    function setSpendingLimit(
        address asset,
        uint256 dailyLimit,
        uint256 monthlyLimit
    ) external onlyRole(GOVERNANCE_MANAGER_ROLE) {
        // Implementation for spending limits
        emit SpendingLimitSet(asset, dailyLimit, monthlyLimit, block.timestamp);
    }

    function emergencyWithdraw(
        address asset,
        uint256 amount,
        address recipient
    ) external onlyRole(EMERGENCY_ROLE) {
        require(emergencyMode, "Not in emergency mode");
        require(recipient != address(0), "Invalid recipient");
        
        if (asset == address(0)) {
            payable(recipient).transfer(amount);
        } else {
            IERC20(asset).safeTransfer(recipient, amount);
        }
        
        emit EmergencyWithdraw(asset, amount, recipient, block.timestamp);
    }

    // Snapshot functions
    function createSnapshot() external onlyRole(GOVERNANCE_MANAGER_ROLE) returns (bytes32 snapshotId) {
        snapshotId = keccak256(abi.encodePacked("snapshot", block.number, block.timestamp));
        
        Snapshot storage snapshot = snapshots[snapshotId];
        snapshot.snapshotId = snapshotId;
        snapshot.blockNumber = block.number;
        snapshot.timestamp = block.timestamp;
        snapshot.totalSupply = governanceToken.totalSupply();
        // snapshot.isFinalized = false; // Field not available
        
        lastSnapshotBlock = block.number;
        allSnapshots.push(snapshotId);
        
        emit SnapshotCreated(snapshotId, block.number, block.timestamp);
    }

    function finalizeSnapshot(
        bytes32 snapshotId
    ) external onlyRole(GOVERNANCE_MANAGER_ROLE) {
        require(snapshots[snapshotId].snapshotId != bytes32(0), "Snapshot not found");
        // require(!snapshots[snapshotId].isFinalized, "Already finalized"); // Field not available
        
        // snapshots[snapshotId].isFinalized = true; // Field not available
        
        emit SnapshotFinalized(snapshotId, block.timestamp);
    }

    // Emergency functions
    function executeEmergencyAction(
        address target,
        bytes calldata data
    ) external onlyRole(EMERGENCY_ROLE) {
        require(emergencyMode, "Not in emergency mode");
        
        (bool success, bytes memory returnData) = target.call(data);
        if (!success) {
            if (returnData.length > 0) {
                assembly {
                    let returnDataSize := mload(returnData)
                    revert(add(32, returnData), returnDataSize)
                }
            } else {
                revert("Emergency action failed");
            }
        }
        
        emit EmergencyActionExecuted(
            0, // actionId
            msg.sender, // executor
            EmergencyActionType.PAUSE_PROTOCOL,
            data,
            block.timestamp
        );
    }

    function enableEmergencyMode() external onlyRole(EMERGENCY_ROLE) {
        emergencyMode = true;
        _pause();
        
        emit EmergencyModeEnabled(block.timestamp);
    }

    function disableEmergencyMode() external onlyRole(EMERGENCY_ROLE) {
        emergencyMode = false;
        _unpause();
        
        emit EmergencyModeDisabled(block.timestamp);
    }

    function veto(
        bytes32 proposalId
    ) external onlyRole(EMERGENCY_ROLE) {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.proposalId != 0, "Proposal not found");
        require(
            proposal.status == ProposalStatus.PENDING || 
            proposal.status == ProposalStatus.ACTIVE || 
            proposal.status == ProposalStatus.SUCCEEDED,
            "Cannot veto"
        );
        
        proposal.status = ProposalStatus.CANCELED;
        // proposal.vetoedAt = block.timestamp; // Field not available
        
        _removeFromActiveProposals(proposalId);
        
        emit ProposalVetoed(proposalId, msg.sender, block.timestamp);
    }

    function emergencyPause() external onlyRole(EMERGENCY_ROLE) {
        _pause();
    }

    // Configuration functions
    function updateGovernanceConfig(
        GovernanceConfig calldata newConfig
    ) external onlyRole(GOVERNANCE_MANAGER_ROLE) {
        require(newConfig.votingDelay >= MIN_VOTING_DELAY && newConfig.votingDelay <= MAX_VOTING_DELAY, "Invalid voting delay");
        require(newConfig.votingPeriod >= MIN_VOTING_PERIOD && newConfig.votingPeriod <= MAX_VOTING_PERIOD, "Invalid voting period");
        require(newConfig.proposalThreshold >= MIN_PROPOSAL_THRESHOLD && newConfig.proposalThreshold <= MAX_PROPOSAL_THRESHOLD, "Invalid proposal threshold");
        require(newConfig.quorumNumerator > 0 && newConfig.quorumNumerator <= BASIS_POINTS, "Invalid quorum");
        
        config = newConfig;
        
        emit GovernanceConfigUpdated(block.timestamp);
    }

    function setVotingDelay(
        uint256 newVotingDelay
    ) external onlyRole(GOVERNANCE_MANAGER_ROLE) {
        require(newVotingDelay >= MIN_VOTING_DELAY && newVotingDelay <= MAX_VOTING_DELAY, "Invalid voting delay");
        
        config.votingDelay = newVotingDelay;
        
        emit VotingDelayUpdated(0, newVotingDelay, block.timestamp);
    }

    function setVotingPeriod(
        uint256 newVotingPeriod
    ) external onlyRole(GOVERNANCE_MANAGER_ROLE) {
        require(newVotingPeriod >= MIN_VOTING_PERIOD && newVotingPeriod <= MAX_VOTING_PERIOD, "Invalid voting period");
        
        config.votingPeriod = newVotingPeriod;
        
        emit VotingPeriodUpdated(0, newVotingPeriod, block.timestamp);
    }

    function setProposalThreshold(
        uint256 newProposalThreshold
    ) external onlyRole(GOVERNANCE_MANAGER_ROLE) {
        require(newProposalThreshold >= MIN_PROPOSAL_THRESHOLD && newProposalThreshold <= MAX_PROPOSAL_THRESHOLD, "Invalid proposal threshold");
        
        config.proposalThreshold = newProposalThreshold;
        
        emit ProposalThresholdUpdated(0, newProposalThreshold, block.timestamp);
    }

    function setQuorum(
        uint256 newQuorum
    ) external onlyRole(GOVERNANCE_MANAGER_ROLE) {
        require(newQuorum > 0 && newQuorum <= BASIS_POINTS, "Invalid quorum");
        
        config.quorumNumerator = newQuorum;
        
        emit QuorumUpdated(0, newQuorum, block.timestamp);
    }

    function setTimelock(
        uint256 newTimelockDelay
    ) external onlyRole(GOVERNANCE_MANAGER_ROLE) {
        require(newTimelockDelay >= 1 days && newTimelockDelay <= 30 days, "Invalid timelock delay");
        
        config.executionDelay = newTimelockDelay;
        
        emit TimelockUpdated(address(0), address(this), block.timestamp);
    }

    // View functions
    function getProposal(bytes32 proposalId) external view returns (Proposal memory) {
        return proposals[proposalId];
    }

    function getProposalState(bytes32 proposalId) external view returns (IGovernance.ProposalState) {
        Proposal storage proposal = proposals[proposalId];
        
        if (proposal.status == IGovernance.ProposalStatus.CANCELED || proposal.status == IGovernance.ProposalStatus.CANCELED) {
            return IGovernance.ProposalState(uint8(proposal.status));
        }
        
        if (block.timestamp <= proposal.startTime) {
            return IGovernance.ProposalState.PENDING;
        }
        
        if (block.timestamp <= proposal.endTime) {
            return IGovernance.ProposalState.ACTIVE;
        }
        
        if (proposal.forVotes <= proposal.againstVotes || 
            proposal.forVotes < _getQuorumVotes()) {
            return IGovernance.ProposalState.DEFEATED;
        }
        
        if (proposal.status == IGovernance.ProposalStatus.EXECUTED) {
            return IGovernance.ProposalState.EXECUTED;
        }
        
        if (proposalQueued[proposalId]) {
            return IGovernance.ProposalState.QUEUED;
        }
        
        return IGovernance.ProposalState.SUCCEEDED;
    }

    function getVote(bytes32 proposalId, address voter) external view returns (Vote memory) {
        return votes[proposalId][voter];
    }

    function getVotingPower(address account) public view returns (uint256) {
        VotingPower storage power = votingPowers[account];
        uint256 tokenBalance = governanceToken.balanceOf(account);
        
        return tokenBalance; // Simplified since delegatedIn and delegatedOut fields not available
    }

    function getDelegation(address delegator) external view returns (Delegate memory) {
        return delegates[delegator];
    }

    function getCommittee(bytes32 committeeId) external view returns (Committee memory) {
        return committees[committeeId];
    }

    function getTreasury(bytes32 treasuryId) external view returns (Treasury memory) {
        return treasuries[treasuryId];
    }

    function getSnapshot(bytes32 snapshotId) external view returns (Snapshot memory) {
        return snapshots[snapshotId];
    }

    function getGovernanceConfig() external view returns (GovernanceConfig memory) {
        return config;
    }

    function getAllProposals() external view returns (bytes32[] memory) {
        return allProposals;
    }

    function getActiveProposals() external view returns (bytes32[] memory) {
        return activeProposals;
    }

    function getUserProposals(address user) external view returns (bytes32[] memory) {
        return userProposals[user];
    }

    function getUserVotes(address user) external view returns (bytes32[] memory) {
        return userVotes[user];
    }

    function getGovernanceMetrics() external view returns (GovernanceMetrics memory) {
        return GovernanceMetrics({
            totalProposals: totalProposals,
            executedProposals: totalExecutions,
            canceledProposals: 0,
            averageParticipation: totalVotes > 0 ? (totalVotes * BASIS_POINTS) / totalProposals : 0,
            totalVotingPower: governanceToken.totalSupply(),
            activeDelegations: totalDelegations,
            uniqueVoters: totalVotes,
            averageVotingTime: 0,
            lastUpdate: block.timestamp
        });
    }

    // Internal functions
    function _getQuorumVotes() internal view returns (uint256) {
        return (governanceToken.totalSupply() * config.quorumNumerator) / BASIS_POINTS;
    }

    function _isCommitteeMember(bytes32 committeeId, address account) internal view returns (bool) {
        address[] storage members = committees[committeeId].members;
        for (uint256 i = 0; i < members.length; i++) {
            if (members[i] == account) {
                return true;
            }
        }
        return false;
    }

    function _removeFromActiveProposals(bytes32 proposalId) internal {
        for (uint256 i = 0; i < activeProposals.length; i++) {
            if (activeProposals[i] == proposalId) {
                activeProposals[i] = activeProposals[activeProposals.length - 1];
                activeProposals.pop();
                break;
            }
        }
    }

    // Emergency functions
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    // Receive function for treasury
    receive() external payable {
        // Allow contract to receive ETH for treasury
    }
}