// SPDX-License-Identifier: MIT

// @written audit-info floating pragma
pragma solidity 0.8.26;

/**
 * @title StructDefinition library that will be used to define the struct in the contract
 * @author Luo Yingjie
 * @notice Those structs are used to define the struct in the contract to prevent the stack too deep error
 */
library StructDefinition {
    struct VerifierConstructorParams {
        address priceFeed;
        uint64 subscriptionId;
        address vrfCoordinator;
        bytes32 keyHash;
        uint32 callbackGasLimit;
        uint256 submissionFeeInUsd;
        string[] userNftImageUris;
    }

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

    struct DistributionVerifierRequestContext {
        address requester;
        VSkillUserEvidence ev;
    }

    enum VSkillUserSubmissionStatus {
        SUBMITTED,
        INREVIEW,
        APPROVED,
        REJECTED,
        DIFFERENTOPINION
    }

    struct VSkillUserEvidence {
        address submitter;
        string evidenceIpfsHash;
        string skillDomain;
        VSkillUserSubmissionStatus status;
        string[] feedbackIpfsHash;
    }

    struct VerifierInfo {
        uint256 reputation;
        string[] skillDomains;
        uint256 moneyStakedInEth;
    }
}
