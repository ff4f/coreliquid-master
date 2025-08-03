// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IComplianceEngine
 * @dev Interface for compliance engine functionality
 */
interface IComplianceEngine {
    function checkCompliance(address user, uint256 amount) external view returns (bool);
    function updateComplianceRules(bytes32 ruleId, bytes calldata ruleData) external;
    function isWhitelisted(address user) external view returns (bool);
    function addToWhitelist(address user) external;
    function removeFromWhitelist(address user) external;
}
