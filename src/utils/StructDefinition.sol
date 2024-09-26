// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

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
}
