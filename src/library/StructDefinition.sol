// SPDX-License-Identifier: MIT

// @written audit-info floating pragma
pragma solidity 0.8.26;

/**
 * @title StructDefinition library that will be used to define the struct in the contract
 * @author Luo Yingjie
 * @notice Those structs are used to define the struct in the contract to prevent the stack too deep error
 */
library StructDefinition {
    struct VerifierEvidenceIpfsHashInfo {
        bool[] statusApproveOrNot;
        address[] selectedVerifiers;
        mapping(address => bool) allSelectedVerifiersToFeedbackStatus;
    }

    struct VerifierFeedbackProvidedEventParams {
        address verifierAddress;
        address user;
        bool approved;
        string feedbackIpfsHash;
        string evidenceIpfsHash;
    }

    enum VSkillUserSubmissionStatus {
        SUBMITTED,
        INREVIEW,
        APPROVED,
        REJECTED,
        DIFFERENTOPINION_A,
        DIFFERENTOPINION_B
    }

    struct VSkillUserEvidence {
        address submitter;
        string cid;
        string skillDomain;
        VSkillUserSubmissionStatus status;
        // Only three verifiers are needed to approve the evidence
        bool[3] statusApproveOrNot;
        string[] feedbackCids;
    }

    struct VerifierInfo {
        uint256 reputation;
        string[] skillDomains;
        uint256[] assignedRequestIds;
    }
}
