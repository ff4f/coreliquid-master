// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./interfaces/IGovernance.sol";

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
    mapping(bytes32 => Proposal) public proposals;
    mapping(bytes32 => mapping(address => Vote)) public votes;
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
            quorum: _quorum,
            timelockDelay: 2 days,
            maxActions: 10,
            gracePeriod: 14 days,
            isActive: true
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
    ) external override returns (bytes32 proposalId) {
        require(targets.length == values.length && values.length == calldatas.length, "Array length mismatch");
        require(targets.length > 0 && targets.length <= config.maxActions, "Invalid actions count");
        require(getVotingPower(msg.sender) >= config.proposalThreshold, "Insufficient voting power");
        
        proposalId = keccak256(abi.encodePacked(title, block.timestamp, msg.sender));
        
        Proposal storage proposal = proposals[proposalId];
        proposal.proposalId = proposalId;
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
        proposal.state = ProposalState.PENDING;
        
        userProposals[msg.sender].push(proposalId);
        allProposals.push(proposalId);
        activeProposals.push(proposalId);
        totalProposals++;
        
        emit ProposalCreated(
            proposalId,
            title,
            msg.sender,
            targets,
            values,
            calldatas,
            proposal.startTime,
            proposal.endTime,
            block.timestamp
        );
    }

    function castVote(
        bytes32 proposalId,
        IGovernance.VoteType voteType,
        string calldata reason
    ) external override {
        require(proposals[proposalId].proposalId != bytes32(0), "Proposal not found");
        require(block.timestamp >= proposals[proposalId].startTime, "Voting not started");
        require(block.timestamp <= proposals[proposalId].endTime, "Voting ended");
        require(votes[proposalId][msg.sender].voter == address(0), "Already voted");
        
        uint256 votingPower = getVotingPower(msg.sender);
        require(votingPower > 0, "No voting power");
        
        Vote storage vote = votes[proposalId][msg.sender];
        vote.voter = msg.sender;
        vote.voteType = voteType;
        vote.votingPower = votingPower;
        vote.timestamp = block.timestamp;
        vote.reason = reason;
        
        Proposal storage proposal = proposals[proposalId];
        if (voteType == IGovernance.VoteType.FOR) {
            proposal.results.forVotes += votingPower;
        } else if (voteType == IGovernance.VoteType.AGAINST) {
            proposal.results.againstVotes += votingPower;
        } else {
            proposal.results.abstainVotes += votingPower;
        }
        proposal.results.totalVotes += votingPower;
        
        userVotes[msg.sender].push(proposalId);
        totalVotes++;
        
        emit VoteCast(proposalId, msg.sender, voteType, votingPower, reason, block.timestamp);
    }

    function execute(
        bytes32 proposalId
    ) external override onlyRole(EXECUTOR_ROLE) {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.proposalId != bytes32(0), "Proposal not found");
        require(block.timestamp > proposal.endTime, "Voting not ended");
        require(proposal.state == ProposalState.SUCCEEDED || proposal.state == ProposalState.QUEUED, "Cannot execute");
        
        if (proposal.state == ProposalState.SUCCEEDED) {
            require(proposalQueued[proposalId], "Proposal not queued");
            require(block.timestamp >= proposalEta[proposalId], "Timelock not expired");
        }
        
        proposal.state = ProposalState.EXECUTED;
        proposal.executedAt = block.timestamp;
        
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
        
        emit ProposalExecuted(proposalId, msg.sender, block.timestamp);
    }

    function cancel(
        bytes32 proposalId
    ) external override {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.proposalId != bytes32(0), "Proposal not found");
        require(
            msg.sender == proposal.proposer || 
            hasRole(GOVERNANCE_MANAGER_ROLE, msg.sender) ||
            getVotingPower(proposal.proposer) < config.proposalThreshold,
            "Cannot cancel"
        );
        require(
            proposal.state == ProposalState.PENDING || 
            proposal.state == ProposalState.ACTIVE,
            "Cannot cancel"
        );
        
        proposal.state = ProposalState.CANCELED;
        proposal.canceledAt = block.timestamp;
        
        _removeFromActiveProposals(proposalId);
        
        emit ProposalCanceled(proposalId, msg.sender, block.timestamp);
    }

    function queue(
        bytes32 proposalId
    ) external override {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.proposalId != bytes32(0), "Proposal not found");
        require(proposal.state == ProposalState.SUCCEEDED, "Proposal not succeeded");
        
        proposal.state = ProposalState.QUEUED;
        proposalQueued[proposalId] = true;
        proposalEta[proposalId] = block.timestamp + config.timelockDelay;
        
        emit ProposalQueued(proposalId, proposalEta[proposalId], block.timestamp);
    }

    // Delegation functions
    function delegate(
        address delegatee,
        uint256 amount,
        DelegationConfig calldata delegationConfig
    ) external override {
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
        votingPowers[msg.sender].delegatedOut += amount;
        votingPowers[delegatee].delegatedIn += amount;
        
        userDelegations[msg.sender].push(delegationId);
        totalDelegations++;
        
        emit VotingPowerDelegated(msg.sender, delegatee, amount, block.timestamp);
    }

    function undelegate(
        address delegatee
    ) external override {
        IGovernance.Delegate storage delegation = delegates[msg.sender];
        require(delegation.isActive, "No active delegation");
        require(delegation.delegatee == delegatee, "Invalid delegatee");
        
        uint256 amount = delegation.amount;
        delegation.isActive = false;
        delegation.undelegatedAt = block.timestamp;
        
        // Update voting power
        votingPowers[msg.sender].delegatedOut -= amount;
        votingPowers[delegatee].delegatedIn -= amount;
        
        emit VotingPowerUndelegated(msg.sender, delegatee, amount, block.timestamp);
    }

    function subdelegateVotes(
        address subDelegatee,
        uint256 amount
    ) external override {
        require(subDelegatee != address(0), "Invalid sub-delegatee");
        require(amount > 0, "Invalid amount");
        require(votingPowers[msg.sender].delegatedIn >= amount, "Insufficient delegated power");
        
        // Update voting power
        votingPowers[msg.sender].delegatedIn -= amount;
        votingPowers[subDelegatee].delegatedIn += amount;
        
        emit VotingPowerDelegated(msg.sender, subDelegatee, amount, block.timestamp);
    }

    // Committee functions
    function createCommittee(
        string calldata name,
        string calldata description,
        address[] calldata members,
        CommitteeConfig calldata committeeConfig
    ) external override onlyRole(GOVERNANCE_MANAGER_ROLE) returns (bytes32 committeeId) {
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
    ) external override onlyRole(GOVERNANCE_MANAGER_ROLE) {
        require(committees[committeeId].isActive, "Committee not found");
        require(member != address(0), "Invalid member");
        
        committees[committeeId].members.push(member);
        
        emit CommitteeMemberAdded(committeeId, member, block.timestamp);
    }

    function removeCommitteeMember(
        bytes32 committeeId,
        address member
    ) external override onlyRole(GOVERNANCE_MANAGER_ROLE) {
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
    ) external override onlyRole(GOVERNANCE_MANAGER_ROLE) {
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
    ) external override returns (bytes32 proposalId) {
        require(committees[committeeId].isActive, "Committee not found");
        require(_isCommitteeMember(committeeId, msg.sender), "Not a committee member");
        
        ProposalConfig memory proposalConfig = ProposalConfig({
            isCommitteeProposal: true,
            committeeId: committeeId,
            requiresSnapshot: false,
            customVotingPeriod: 0,
            customQuorum: 0,
            allowDelegation: true,
            isEmergency: false
        });
        
        proposalId = this.propose(title, description, targets, values, calldatas, proposalConfig);
    }

    // Treasury functions
    function proposeTreasurySpend(
        address recipient,
        uint256 amount,
        address asset,
        string calldata purpose
    ) external override returns (bytes32 proposalId) {
        require(recipient != address(0), "Invalid recipient");
        require(amount > 0, "Invalid amount");
        
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        
        targets[0] = asset;
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature("transfer(address,uint256)", recipient, amount);
        
        ProposalConfig memory proposalConfig = ProposalConfig({
            isCommitteeProposal: false,
            committeeId: bytes32(0),
            requiresSnapshot: true,
            customVotingPeriod: 0,
            customQuorum: 0,
            allowDelegation: true,
            isEmergency: false
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
    ) external override {
        this.execute(proposalId);
    }

    function setSpendingLimit(
        address asset,
        uint256 dailyLimit,
        uint256 monthlyLimit
    ) external override onlyRole(GOVERNANCE_MANAGER_ROLE) {
        // Implementation for spending limits
        emit SpendingLimitSet(asset, dailyLimit, monthlyLimit, block.timestamp);
    }

    function emergencyWithdraw(
        address asset,
        uint256 amount,
        address recipient
    ) external override onlyRole(EMERGENCY_ROLE) {
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
    function createSnapshot() external override onlyRole(GOVERNANCE_MANAGER_ROLE) returns (bytes32 snapshotId) {
        snapshotId = keccak256(abi.encodePacked("snapshot", block.number, block.timestamp));
        
        Snapshot storage snapshot = snapshots[snapshotId];
        snapshot.snapshotId = snapshotId;
        snapshot.blockNumber = block.number;
        snapshot.timestamp = block.timestamp;
        snapshot.totalSupply = governanceToken.totalSupply();
        snapshot.isFinalized = false;
        
        lastSnapshotBlock = block.number;
        allSnapshots.push(snapshotId);
        
        emit SnapshotCreated(snapshotId, block.number, block.timestamp);
    }

    function finalizeSnapshot(
        bytes32 snapshotId
    ) external override onlyRole(GOVERNANCE_MANAGER_ROLE) {
        require(snapshots[snapshotId].snapshotId != bytes32(0), "Snapshot not found");
        require(!snapshots[snapshotId].isFinalized, "Already finalized");
        
        snapshots[snapshotId].isFinalized = true;
        
        emit SnapshotFinalized(snapshotId, block.timestamp);
    }

    // Emergency functions
    function executeEmergencyAction(
        address target,
        bytes calldata data
    ) external override onlyRole(EMERGENCY_ROLE) {
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
        
        emit EmergencyActionExecuted(target, data, block.timestamp);
    }

    function enableEmergencyMode() external override onlyRole(EMERGENCY_ROLE) {
        emergencyMode = true;
        _pause();
        
        emit EmergencyModeEnabled(block.timestamp);
    }

    function disableEmergencyMode() external override onlyRole(EMERGENCY_ROLE) {
        emergencyMode = false;
        _unpause();
        
        emit EmergencyModeDisabled(block.timestamp);
    }

    function veto(
        bytes32 proposalId
    ) external override onlyRole(EMERGENCY_ROLE) {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.proposalId != bytes32(0), "Proposal not found");
        require(
            proposal.state == ProposalState.PENDING || 
            proposal.state == ProposalState.ACTIVE || 
            proposal.state == ProposalState.SUCCEEDED,
            "Cannot veto"
        );
        
        proposal.state = ProposalState.VETOED;
        proposal.vetoedAt = block.timestamp;
        
        _removeFromActiveProposals(proposalId);
        
        emit ProposalVetoed(proposalId, msg.sender, block.timestamp);
    }

    function emergencyPause() external override onlyRole(EMERGENCY_ROLE) {
        _pause();
    }

    // Configuration functions
    function updateGovernanceConfig(
        GovernanceConfig calldata newConfig
    ) external override onlyRole(GOVERNANCE_MANAGER_ROLE) {
        require(newConfig.votingDelay >= MIN_VOTING_DELAY && newConfig.votingDelay <= MAX_VOTING_DELAY, "Invalid voting delay");
        require(newConfig.votingPeriod >= MIN_VOTING_PERIOD && newConfig.votingPeriod <= MAX_VOTING_PERIOD, "Invalid voting period");
        require(newConfig.proposalThreshold >= MIN_PROPOSAL_THRESHOLD && newConfig.proposalThreshold <= MAX_PROPOSAL_THRESHOLD, "Invalid proposal threshold");
        require(newConfig.quorum > 0 && newConfig.quorum <= BASIS_POINTS, "Invalid quorum");
        
        config = newConfig;
        
        emit GovernanceConfigUpdated(block.timestamp);
    }

    function setVotingDelay(
        uint256 newVotingDelay
    ) external override onlyRole(GOVERNANCE_MANAGER_ROLE) {
        require(newVotingDelay >= MIN_VOTING_DELAY && newVotingDelay <= MAX_VOTING_DELAY, "Invalid voting delay");
        
        config.votingDelay = newVotingDelay;
        
        emit VotingDelayUpdated(newVotingDelay, block.timestamp);
    }

    function setVotingPeriod(
        uint256 newVotingPeriod
    ) external override onlyRole(GOVERNANCE_MANAGER_ROLE) {
        require(newVotingPeriod >= MIN_VOTING_PERIOD && newVotingPeriod <= MAX_VOTING_PERIOD, "Invalid voting period");
        
        config.votingPeriod = newVotingPeriod;
        
        emit VotingPeriodUpdated(newVotingPeriod, block.timestamp);
    }

    function setProposalThreshold(
        uint256 newProposalThreshold
    ) external override onlyRole(GOVERNANCE_MANAGER_ROLE) {
        require(newProposalThreshold >= MIN_PROPOSAL_THRESHOLD && newProposalThreshold <= MAX_PROPOSAL_THRESHOLD, "Invalid proposal threshold");
        
        config.proposalThreshold = newProposalThreshold;
        
        emit ProposalThresholdUpdated(newProposalThreshold, block.timestamp);
    }

    function setQuorum(
        uint256 newQuorum
    ) external override onlyRole(GOVERNANCE_MANAGER_ROLE) {
        require(newQuorum > 0 && newQuorum <= BASIS_POINTS, "Invalid quorum");
        
        config.quorum = newQuorum;
        
        emit QuorumUpdated(newQuorum, block.timestamp);
    }

    function setTimelock(
        uint256 newTimelockDelay
    ) external override onlyRole(GOVERNANCE_MANAGER_ROLE) {
        require(newTimelockDelay >= 1 days && newTimelockDelay <= 30 days, "Invalid timelock delay");
        
        config.timelockDelay = newTimelockDelay;
        
        emit TimelockUpdated(newTimelockDelay, block.timestamp);
    }

    // View functions
    function getProposal(bytes32 proposalId) external view override returns (Proposal memory) {
        return proposals[proposalId];
    }

    function getProposalState(bytes32 proposalId) external view override returns (IGovernance.ProposalState) {
        Proposal storage proposal = proposals[proposalId];
        
        if (proposal.state == IGovernance.ProposalState.CANCELED || proposal.state == IGovernance.ProposalState.VETOED) {
            return proposal.state;
        }
        
        if (block.timestamp <= proposal.startTime) {
            return IGovernance.ProposalState.PENDING;
        }
        
        if (block.timestamp <= proposal.endTime) {
            return IGovernance.ProposalState.ACTIVE;
        }
        
        if (proposal.results.forVotes <= proposal.results.againstVotes || 
            proposal.results.forVotes < _getQuorumVotes()) {
            return IGovernance.ProposalState.DEFEATED;
        }
        
        if (proposal.state == IGovernance.ProposalState.EXECUTED) {
            return IGovernance.ProposalState.EXECUTED;
        }
        
        if (proposalQueued[proposalId]) {
            return IGovernance.ProposalState.QUEUED;
        }
        
        return IGovernance.ProposalState.SUCCEEDED;
    }

    function getVote(bytes32 proposalId, address voter) external view override returns (Vote memory) {
        return votes[proposalId][voter];
    }

    function getVotingPower(address account) public view override returns (uint256) {
        VotingPower storage power = votingPowers[account];
        uint256 tokenBalance = governanceToken.balanceOf(account);
        
        return tokenBalance + power.delegatedIn - power.delegatedOut;
    }

    function getDelegation(address delegator) external view override returns (Delegate memory) {
        return delegates[delegator];
    }

    function getCommittee(bytes32 committeeId) external view override returns (Committee memory) {
        return committees[committeeId];
    }

    function getTreasury(bytes32 treasuryId) external view override returns (Treasury memory) {
        return treasuries[treasuryId];
    }

    function getSnapshot(bytes32 snapshotId) external view override returns (Snapshot memory) {
        return snapshots[snapshotId];
    }

    function getGovernanceConfig() external view override returns (GovernanceConfig memory) {
        return config;
    }

    function getAllProposals() external view override returns (bytes32[] memory) {
        return allProposals;
    }

    function getActiveProposals() external view override returns (bytes32[] memory) {
        return activeProposals;
    }

    function getUserProposals(address user) external view override returns (bytes32[] memory) {
        return userProposals[user];
    }

    function getUserVotes(address user) external view override returns (bytes32[] memory) {
        return userVotes[user];
    }

    function getGovernanceMetrics() external view override returns (GovernanceMetrics memory) {
        return GovernanceMetrics({
            totalProposals: totalProposals,
            totalVotes: totalVotes,
            totalDelegations: totalDelegations,
            totalExecutions: totalExecutions,
            activeProposalsCount: activeProposals.length,
            totalVotingPower: governanceToken.totalSupply(),
            participationRate: totalVotes > 0 ? (totalVotes * BASIS_POINTS) / totalProposals : 0,
            averageVotingPower: totalVotes > 0 ? governanceToken.totalSupply() / totalVotes : 0
        });
    }

    // Internal functions
    function _getQuorumVotes() internal view returns (uint256) {
        return (governanceToken.totalSupply() * config.quorum) / BASIS_POINTS;
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