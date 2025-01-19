// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {ILogAutomation, Log} from "@chainlink/contracts/src/v0.8/automation/interfaces/ILogAutomation.sol";
import {VSkillUser} from "src/VSkillUser.sol";
import {StructDefinition} from "src/library/StructDefinition.sol";
import {Distribution} from "src/Distribution.sol";
import {Verifier} from "src/Verifier.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {VSkillUserNft} from "src/VSkillUserNft.sol";

contract Relayer is ILogAutomation, Ownable {
    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    uint256 private constant DEADLINE = 7 days;
    uint256 private constant NUM_WORDS = 3;

    VSkillUser private immutable i_vSkillUser;
    Distribution private immutable i_distribution;
    Verifier private immutable i_verifier;
    VSkillUserNft private immutable i_vSkillUserNft;
    mapping(uint256 requestId => uint256[] randomWordsWithinRange)
        private s_requestIdToRandomWordsWithinRange;
    uint256[] private s_unhandledRequestIds;
    mapping(uint256 requestId => address[] verifiersAssigned)
        private s_requestIdToVerifiersAssigned;
    uint256 private s_batchProcessed;
    mapping(uint256 batch => uint256[] processedRequestIds)
        private s_batchToProcessedRequestIds;
    mapping(uint256 batch => uint256 deadline) private s_batchToDeadline;
    mapping(uint256 batch => StructDefinition.RelayerBatchStatus batchStatus)
        private s_batchProcessedOrNot;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error Relayer__InvalidBatchNumber();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Relayer__UnhandledRequestIdAdded(
        uint256 indexed unhandledRequestIdsLength
    );
    event Relayer__NoVerifierForThisSkillDomainYet();
    event Relayer__EvidenceAssignedToVerifiers();
    event Relayer__EvidenceProcessed(uint256 indexed batchNumber);
    event Relayer__UserNftsMinted(uint256 indexed batchNumber);

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address vSkillUser,
        address distribution,
        address verifier,
        address vSkillUserNft
    ) Ownable(msg.sender) {
        i_vSkillUser = VSkillUser(payable(vSkillUser));
        i_distribution = Distribution(distribution);
        i_verifier = Verifier(payable(verifier));
        i_vSkillUserNft = VSkillUserNft(vSkillUserNft);
        s_batchProcessed = 0;
    }

    /*//////////////////////////////////////////////////////////////
                          CHAINLINK AUTOMATION
    //////////////////////////////////////////////////////////////*/

    // Listen for the distribution RequestIdToRandomWordsUpdated event
    function checkLog(
        Log calldata log,
        bytes memory
    ) external pure returns (bool upkeepNeeded, bytes memory performData) {
        upkeepNeeded = true;
        uint256 requestId = uint256(log.topics[1]);
        performData = abi.encode(requestId);
    }

    // Here we just store select randomWords in the range of the verifierWithinSameDomainLength
    // And store the requestId in the s_unhandledRequestIds array
    // As for the assignment, we will handle this in batches to reduce gas costs
    // @audit only the Forwarder will be able to call this function!!!
    // update this soon!
    function performUpkeep(bytes calldata performData) external override {
        uint256 requestId = abi.decode(performData, (uint256));
        StructDefinition.VSkillUserEvidence memory evidence = i_vSkillUser
            .getRequestIdToEvidence(requestId);
        uint256[] memory randomWords = i_distribution.getRandomWords(requestId);

        // As for the number of verifiers enough or not, since we only require 3 verifiers
        // At the very beginning of the project, we will make sure that the number of verifiers is enough for each skill domain(above 3)
        // After that we will allow users to submit the evidence
        // Even if there are only 2 or 1 verifiers, we will still allow the user to submit the evidence and one of them will need to provide the same feedback twice
        // If the length is zero: we will emit an event and the owner will need to handle this manually...(but this usually won't happen)
        // @audit make sure the randomWordsWithinRange every element is unique!
        uint256 verifierWithinSameDomainLength = i_verifier
            .getSkillDomainToVerifiersWithinSameDomainLength(
                evidence.skillDomain
            );
        if (verifierWithinSameDomainLength == 0) {
            emit Relayer__NoVerifierForThisSkillDomainYet();
            return;
        }
        // get the randomWords within the range of the verifierWithinSameDomainLength
        // here the length is just 3, no worries about DoS attack
        for (uint8 i = 0; i < NUM_WORDS; i++) {
            randomWords[i] = randomWords[i] % verifierWithinSameDomainLength;
        }
        s_requestIdToRandomWordsWithinRange[requestId] = randomWords;
        s_unhandledRequestIds.push(requestId);
        emit Relayer__UnhandledRequestIdAdded(s_unhandledRequestIds.length);
    }

    /*//////////////////////////////////////////////////////////////
                     EXTERNAL AND PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    // These functions will be called daily by the owner, the automation process will be set on the browser

    // This will be a very gas cost function as it will assign all the evidence to the verifiers
    // Try to reduce the gas cost as much as possible
    // We are the only one (owner or the profit beneficiary) who can call this function

    // once the verifiers are assigned, the verifier will get the notification on the frontend(listening to the event)
    // and they can start to provide feedback to the specific evidence

    // set the assigned verifiers as the one who can change the evidence status
    // @audit refactor this function to be more gas efficient!
    function assignEvidenceToVerifiers() external onlyOwner {
        // update the batch number
        s_batchToProcessedRequestIds[s_batchProcessed] = s_unhandledRequestIds;
        s_batchToDeadline[s_batchProcessed] = block.timestamp + DEADLINE;
        s_batchProcessed++;

        uint256 length = s_unhandledRequestIds.length;
        // the length can be very large, but we will monitor the event to track the length and avoid DoS attack
        for (uint256 i = 0; i < length; i++) {
            uint256 requestId = s_unhandledRequestIds[i];
            uint256[]
                memory randomWordsWithinRange = s_requestIdToRandomWordsWithinRange[
                    requestId
                ];
            address[] memory verifiersWithinSameDomain = i_verifier
                .getSkillDomainToVerifiersWithinSameDomain(
                    i_vSkillUser.getRequestIdToEvidence(requestId).skillDomain
                );
            for (uint8 j = 0; j < randomWordsWithinRange.length; j++) {
                i_verifier.setVerifierAssignedRequestIds(
                    requestId,
                    verifiersWithinSameDomain[randomWordsWithinRange[j]]
                );
                // only 7 days allowed for the verifiers to provide feedback
                i_vSkillUser.setDeadline(requestId, block.timestamp + DEADLINE);
                s_requestIdToVerifiersAssigned[requestId].push(
                    verifiersWithinSameDomain[randomWordsWithinRange[j]]
                );
            }
        }
        delete s_unhandledRequestIds;

        emit Relayer__EvidenceAssignedToVerifiers();
    }

    // This function will process those evidences which have passed the ddl and decide the final status
    // the same batch of unhandledRequestIds will be processed since they are the same deadline

    // we allow the batch number input in case there are emergency situations for process that batch earlier or in case where we have two or more batches left unprocessed
    function processEvidenceStatus(uint256 batchNumber) external onlyOwner {
        _onlyValidNotProcessedBatchNumber(batchNumber);
        uint256[] memory requestIds = s_batchToProcessedRequestIds[batchNumber];
        uint256 length = requestIds.length;
        for (uint256 i = 0; i < length; i++) {
            uint256 requestId = requestIds[i];
            StructDefinition.VSkillUserEvidence memory evidence = i_vSkillUser
                .getRequestIdToEvidence(requestId);

            // since the array is updated one by one, we only need to check the second element
            // if the second element is true, then the status is approved or DIFFERENTOPINION_A
            // if the second element is false, then the status is rejected or DIFFERENTOPINION_R
            bool secondElement = evidence.statusApproveOrNot[1];
            if (secondElement) {
                _handleApprovedStatus(requestId, evidence);
            } else {
                _handleRejectedStatus(requestId, evidence);
            }
        }

        s_batchProcessedOrNot[batchNumber] = StructDefinition
            .RelayerBatchStatus
            .PROCESSED;
        emit Relayer__EvidenceProcessed(batchNumber);
    }

    // If this batch has exceeded the gas limit, we can call the two functions one by one, otherwise this is the function we will call to handle the evidence after the deadline
    function handleEvidenceAfterDeadline(
        uint256 batchNumber
    ) external onlyOwner {
        mintUserNfts(batchNumber);
        rewardOrPenalizeVerifiers(batchNumber);
    }

    // This will be a very gas cost function as it will check all the feedbacks and decide the final status
    // Try to reduce the gas cost as much as possible

    // if the status is approved, the user will get the NFT
    // if the status is rejected, the user will not get the NFT
    // if the status is different opinion, the situation will be as follows:
    // If the status is `DIFFERENTOPINION_A`, the user will be able to mint the NFT. The verifiers will be penalized.
    // If the status is `DIFFERENTOPINION_R`, the user will not be able to mint the NFT. The verifiers will be penalized.
    //   - If more than 2/3 of the verifiers have approved the evidence, then it's `DIFFERENTOPINION_A`. The rest one will be penalized.
    //   - If only 1/3 of the verifiers have approved the evidence, the status will be `DIFFERENTOPINION_R`. The rest two will be penalized.

    function mintUserNfts(uint256 batchNumber) public onlyOwner {
        // only after the batch has been processed, we will mint the NFT
        _onlyProcessedBatchNumber(batchNumber);
        uint256[] memory requestIds = s_batchToProcessedRequestIds[batchNumber];
        uint256 length = requestIds.length;
        for (uint256 i = 0; i < length; i++) {
            uint256 requestId = requestIds[i];
            StructDefinition.VSkillUserSubmissionStatus status = i_vSkillUser
                .getRequestIdToEvidenceStatus(requestId);
            // mint those who have the status approved or DIFFERENTOPINION_A
            if (
                status ==
                StructDefinition.VSkillUserSubmissionStatus.APPROVED ||
                status ==
                StructDefinition.VSkillUserSubmissionStatus.DIFFERENTOPINION_A
            ) {
                i_vSkillUserNft.mintUserNft(
                    i_vSkillUser.getRequestIdToEvidence(requestId).skillDomain
                );
            }
        }

        emit Relayer__UserNftsMinted(batchNumber);
    }

    // Since all the verifiers who have not provided the feedback have been punished(they lose verifier status)
    // And as long as there are someone who did not provide the feedback for evidence, it will be marked directly as approved or rejected
    // We only need to handle the situation DIFFERENTOPINION_A and DIFFERENTOPINION_R to reward or penalize the verifiers
    // As for the approved or rejected status, we will reward them as long as they are still verifiers
    function rewardOrPenalizeVerifiers(uint256 batchNumber) public onlyOwner {
        // only after the batch has been processed, we will reward or penalize the verifiers
        _onlyProcessedBatchNumber(batchNumber);
        uint256[] memory requestIds = s_batchToProcessedRequestIds[batchNumber];
        uint256 length = requestIds.length;
        for (uint256 i = 0; i < length; i++) {
            uint256 requestId = requestIds[i];
            StructDefinition.VSkillUserSubmissionStatus status = i_vSkillUser
                .getRequestIdToEvidenceStatus(requestId);
            if (
                status ==
                StructDefinition.VSkillUserSubmissionStatus.APPROVED ||
                status == StructDefinition.VSkillUserSubmissionStatus.REJECTED
            ) {
                // reward the verifiers as long as they are still verifiers
                _rewardVerifiers(requestId);
            } else {
                // based on if the verifier approved or rejected the evidence, we will reward or penalize the verifiers
                _handleRewardsOrPenalties(requestId, status);
            }
        }
    }

    function addMoreSkill(
        string memory skillDomain,
        string memory nftImageUri
    ) external onlyOwner {
        i_vSkillUserNft.addMoreSkillsForNft(skillDomain, nftImageUri);
        i_vSkillUser.addMoreSkills(skillDomain);
    }

    /*//////////////////////////////////////////////////////////////
                     INTERNAL AND PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _onlyValidNotProcessedBatchNumber(
        uint256 batchNumber
    ) private view {
        // the batch number cannot be greater than or equal to the s_batchProcessed since we have increased the batch number after the assignment
        // the most recent batch number will have nothing mapped to it
        if (batchNumber >= s_batchProcessed) {
            revert Relayer__InvalidBatchNumber();
        }
        // if the current timestamp is less than the deadline, we will revert since this batch is not yet reach the deadline
        if (block.timestamp < s_batchToDeadline[batchNumber]) {
            revert Relayer__InvalidBatchNumber();
        }

        // if this batch has been processed, we will revert since we only allow the batch to be processed once
        if (
            s_batchProcessedOrNot[batchNumber] !=
            StructDefinition.RelayerBatchStatus.PENDING
        ) {
            revert Relayer__InvalidBatchNumber();
        }
    }

    function _onlyProcessedBatchNumber(uint256 batchNumber) private view {
        // the batch number cannot be greater than or equal to the s_batchProcessed since we have increased the batch number after the assignment
        // the most recent batch number will have nothing mapped to it
        if (batchNumber >= s_batchProcessed) {
            revert Relayer__InvalidBatchNumber();
        }
        // if this batch has not been processed, we will revert since we only allow the batch to be processed once
        if (
            s_batchProcessedOrNot[batchNumber] !=
            StructDefinition.RelayerBatchStatus.PROCESSED
        ) {
            revert Relayer__InvalidBatchNumber();
        }
    }

    function _handleApprovedStatus(
        uint256 requestId,
        StructDefinition.VSkillUserEvidence memory evidence
    ) internal {
        uint256 length = i_verifier.getVerifiersProvidedFeedbackLength(
            requestId
        );
        if (length < NUM_WORDS) {
            // there is one verifier who has not provided the feedback yet
            // we will punish this verifier!
            i_vSkillUser.setEvidenceStatus(
                requestId,
                StructDefinition.VSkillUserSubmissionStatus.APPROVED
            );
            _punishTheOnlyVerifierWhoHasNotProvidedFeedback(requestId);
            return;
        }

        // check the third element
        // if it's true, then the status is approved
        // if it's false, then the status is DIFFERENTOPINION_A
        bool thirdElement = evidence.statusApproveOrNot[2];
        if (thirdElement) {
            i_vSkillUser.setEvidenceStatus(
                requestId,
                StructDefinition.VSkillUserSubmissionStatus.APPROVED
            );
        } else {
            i_vSkillUser.setEvidenceStatus(
                requestId,
                StructDefinition.VSkillUserSubmissionStatus.DIFFERENTOPINION_A
            );
        }
    }

    function _punishTheOnlyVerifierWhoHasNotProvidedFeedback(
        uint256 requestId
    ) private {
        address[] memory verifiersAssigned = s_requestIdToVerifiersAssigned[
            requestId
        ];
        // this array is of length 2 since we know that only one verifier has not provided the feedback
        address[] memory verifiersProvidedFeedback = i_verifier
            .getVerifiersProvidedFeedback(requestId);

        // the one who has not provided the feedback
        address verifierWhoHasNotProvidedFeedback = _getTheOnlyOneVerifierDifferentFromOtherTwo(
                verifiersAssigned,
                verifiersProvidedFeedback
            );
        i_verifier.punishVerifier(verifierWhoHasNotProvidedFeedback);
    }

    function _getTheOnlyOneVerifierDifferentFromOtherTwo(
        address[] memory verifiersAssigned,
        address[] memory verifiersWithSameOperation
    ) private pure returns (address) {
        // A⊕A=0
        // A⊕0=A
        // XOR all assigned verifiers
        uint256 xorResult = 0;
        for (uint256 i = 0; i < verifiersAssigned.length; i++) {
            xorResult ^= uint256(uint160(verifiersAssigned[i]));
        }

        // XOR all verifiers who are of the same operation
        for (uint256 i = 0; i < verifiersWithSameOperation.length; i++) {
            xorResult ^= uint256(uint160(verifiersWithSameOperation[i]));
        }

        return address(uint160(xorResult));
    }

    function _punishTheRestTwoVerifierWhoHasNotProvidedFeedback(
        uint256 requestId
    ) private {
        address[] memory verifiersAssigned = s_requestIdToVerifiersAssigned[
            requestId
        ];
        // this array is only of length 1 since we know that only one verifier has provided the feedback
        address[] memory verifiersProvidedFeedback = i_verifier
            .getVerifiersProvidedFeedback(requestId);

        for (uint256 i = 0; i < NUM_WORDS; i++) {
            if (verifiersAssigned[i] != verifiersProvidedFeedback[0]) {
                i_verifier.punishVerifier(verifiersAssigned[i]);
            }
        }
    }

    function _punishAllVerifiersWhoHaveNotProvidedFeedback(
        uint256 requestId
    ) private {
        for (uint256 i = 0; i < NUM_WORDS; i++) {
            i_verifier.punishVerifier(
                s_requestIdToVerifiersAssigned[requestId][i]
            );
        }
    }

    function _handleRejectedStatus(
        uint256 requestId,
        StructDefinition.VSkillUserEvidence memory evidence
    ) internal {
        uint256 length = i_verifier.getVerifiersProvidedFeedbackLength(
            requestId
        );

        // As long as there is someone who has not provided the feedback, the status will be marked directly as rejected
        if (length == 0) {
            // all the verifiers have not provided the feedback yet
            // we will punish all the verifiers
            i_vSkillUser.setEvidenceStatus(
                requestId,
                StructDefinition.VSkillUserSubmissionStatus.REJECTED
            );
            _punishAllVerifiersWhoHaveNotProvidedFeedback(requestId);
        } else if (length == 1) {
            // only one verifier has provided the feedback
            // we will punish other two verifiers
            // check the first element to set the status
            i_vSkillUser.setEvidenceStatus(
                requestId,
                StructDefinition.VSkillUserSubmissionStatus.REJECTED
            );
            _punishTheRestTwoVerifierWhoHasNotProvidedFeedback(requestId);
        } else if (length == 2) {
            // two verifiers have provided the feedback
            // we will punish the rest one verifier
            // check the first element to set the status
            i_vSkillUser.setEvidenceStatus(
                requestId,
                StructDefinition.VSkillUserSubmissionStatus.REJECTED
            );
            _punishTheOnlyVerifierWhoHasNotProvidedFeedback(requestId);
        } else {
            bool firstElement = evidence.statusApproveOrNot[0];
            StructDefinition.VSkillUserSubmissionStatus status = firstElement
                ? StructDefinition.VSkillUserSubmissionStatus.DIFFERENTOPINION_R
                : StructDefinition.VSkillUserSubmissionStatus.REJECTED;
            i_vSkillUser.setEvidenceStatus(requestId, status);
        }
    }

    function _rewardVerifiers(uint256 requestId) private {
        address[] memory verifiersAssigned = s_requestIdToVerifiersAssigned[
            requestId
        ];
        for (uint256 i = 0; i < verifiersAssigned.length; i++) {
            // if the verifier is still a verifier, we will reward the verifier
            // else just skip
            if (i_verifier.getAddressToIsVerifier(verifiersAssigned[i])) {
                i_verifier.rewardVerifier(verifiersAssigned[i]);
            }
        }
    }

    function _handleRewardsOrPenalties(
        uint256 requestId,
        StructDefinition.VSkillUserSubmissionStatus status
    ) private {
        address[] memory verifiersAssigned = s_requestIdToVerifiersAssigned[
            requestId
        ];
        address[] memory verifiersApproved = i_vSkillUser
            .getRequestIdToVerifiersApprovedEvidence(requestId);

        // We know that every verifier has provided the feedback
        // if the status is DIFFERENTOPINION_A, we will reward the verifiers who approved the evidence and penalize the rest one
        // if the status is DIFFERENTOPINION_R, we will penalize all the verifiers who approved the evidence and reward the rest one
        if (
            status ==
            StructDefinition.VSkillUserSubmissionStatus.DIFFERENTOPINION_A
        ) {
            // reward the verifiers who approved the evidence
            for (uint256 i = 0; i < verifiersApproved.length; i++) {
                i_verifier.rewardVerifier(verifiersApproved[i]);
            }
            // penalize the rest one verifier
            address verifierWhoHasNotApproved = _getTheOnlyOneVerifierDifferentFromOtherTwo(
                    verifiersAssigned,
                    verifiersApproved
                );
            i_verifier.penalizeVerifier(verifierWhoHasNotApproved);
        } else {
            // penalize the verifiers who approved the evidence
            for (uint256 i = 0; i < verifiersApproved.length; i++) {
                i_verifier.penalizeVerifier(verifiersApproved[i]);
            }
            // reward the rest one verifier
            address verifierWhoHasNotApproved = _getTheOnlyOneVerifierDifferentFromOtherTwo(
                    verifiersAssigned,
                    verifiersApproved
                );
            i_verifier.rewardVerifier(verifierWhoHasNotApproved);
        }
    }
}
