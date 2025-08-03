// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IComplianceManager
 * @dev Interface for compliance manager functionality
 */
interface IComplianceManager {
    function validateTransaction(address from, address to, uint256 amount) external view returns (bool);
    function setComplianceRule(bytes32 ruleId, bool enabled) external;
    function getComplianceStatus(address user) external view returns (uint8);
    function updateKYCStatus(address user, bool verified) external;
    function isTransactionAllowed(address user, uint256 amount) external view returns (bool);
}