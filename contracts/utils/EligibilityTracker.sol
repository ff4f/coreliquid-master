// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract EligibilityTracker {
    struct EligibilityStatus {
        bool hasCoreUsed;
        bool hasTweeted;
        uint256 chainId;
        uint256 timestamp;
        uint256 score;
    }
    
    mapping(address => EligibilityStatus) public eligibility;
    mapping(address => bool) public verifiers;
    
    address public owner;
    uint256 public constant CORE_CHAIN_ID = 1116;
    
    event EligibilityUpdated(address indexed user, uint256 score);
    event VerifierAdded(address indexed verifier);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }
    
    modifier onlyVerifier() {
        require(verifiers[msg.sender] || msg.sender == owner, "Not verifier");
        _;
    }
    
    constructor() {
        owner = msg.sender;
        verifiers[msg.sender] = true;
    }
    
    function addVerifier(address verifier) external onlyOwner {
        verifiers[verifier] = true;
        emit VerifierAdded(verifier);
    }
    
    function updateEligibility(
        address user,
        bool hasCoreUsed,
        bool hasTweeted
    ) external onlyVerifier {
        EligibilityStatus storage status = eligibility[user];
        status.hasCoreUsed = hasCoreUsed;
        status.hasTweeted = hasTweeted;
        status.chainId = block.chainid;
        status.timestamp = block.timestamp;
        
        // Calculate score
        uint256 score = 0;
        if (hasCoreUsed) score += 50;
        if (hasTweeted) score += 30;
        if (block.chainid == CORE_CHAIN_ID) score += 20;
        
        status.score = score;
        
        emit EligibilityUpdated(user, score);
    }
    
    function getEligibilityScore(address user) external view returns (uint256) {
        return eligibility[user].score;
    }
    
    function isEligible(address user) external view returns (bool) {
        return eligibility[user].score >= 50; // Minimum 50 points
    }
}
