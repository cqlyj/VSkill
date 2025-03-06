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
    address private s_forwarder;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error Relayer__InvalidBatchNumber();
    error Relayer__OnlyForwarder();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Relayer__UnhandledRequestIdAdded(
        uint256 indexed unhandledRequestIdsLength
    );
    event Relayer__NotEnoughVerifierForThisSkillDomainYet();
    event Relayer__EvidenceAssignedToVerifiers();
    event Relayer__EvidenceProcessed(uint256 indexed batchNumber);
    event Relayer__UserNftsMinted(uint256 indexed batchNumber);
    event Relayer__ForwarderSet(address forwarder);

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyForwarder() {
        if (msg.sender != s_forwarder) {
            revert Relayer__OnlyForwarder();
        }
        _;
    }

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

    //slither-disable-next-line missing-zero-check
    function setForwarder(address forwarder) external onlyOwner {
        s_forwarder = forwarder;

        emit Relayer__ForwarderSet(forwarder);
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
    function performUpkeep(
        bytes calldata performData
    ) external override onlyForwarder {
        uint256 requestId = abi.decode(performData, (uint256));
        string memory skillDomain = i_vSkillUser
            .getRequestIdToEvidenceSkillDomain(requestId);
        uint256[] memory randomWords = i_distribution.getRandomWords(requestId);

        // As for the number of verifiers enough or not, since we only require 3 verifiers
        // At the very beginning of the project, we will make sure that the number of verifiers is enough for each skill domain(above 3)
        // we always has three verifiers in the community to make sure it's always enough
        // After that we will allow users to submit the evidence
        uint256 verifierWithinSameDomainLength = i_verifier
            .getSkillDomainToVerifiersWithinSameDomainLength(skillDomain);
        if (verifierWithinSameDomainLength < NUM_WORDS) {
            emit Relayer__NotEnoughVerifierForThisSkillDomainYet();
            return;
        }
        // get the randomWords within the range of the verifierWithinSameDomainLength
        // here the length is just 3, no worries about DoS attack
        for (uint8 i = 0; i < NUM_WORDS; i++) {
            randomWords[i] = randomWords[i] % verifierWithinSameDomainLength;
        }
        // check the current randomWords is unique or not
        // if not, we will need to modify the randomWords a bit
        // since the length is only 3, we can afford to do this
        randomWords = _makeRandomWordsUnique(
            randomWords,
            verifierWithinSameDomainLength
        );
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
        uint256 length = s_unhandledRequestIds.length;
        // if there is no unhandled request, we will return so that we don't waste gas
        if (length == 0) {
            return;
        }
        // update the batch number
        s_batchToProcessedRequestIds[s_batchProcessed] = s_unhandledRequestIds;
        s_batchToDeadline[s_batchProcessed] = block.timestamp + DEADLINE;
        s_batchProcessed++;

        // the length can be very large, but we will monitor the event to track the length and avoid DoS attack
        for (uint256 i = 0; i < length; i++) {
            uint256 requestId = s_unhandledRequestIds[i];
            // What if at the time when calling this function, the verifiers have been removed from the community?
            // Then the random words will exceed the range and this function will revert
            // @audit-high If verifier is removed, here we will have out of range random words!
            uint256[]
                memory randomWordsWithinRange = s_requestIdToRandomWordsWithinRange[
                    requestId
                ];

            // @audit-written DoS can happen if the verifier is assigned to a lot of requests and thus they are not able to provide feedback to assigned evidence in timely manner
            // Which result in making them lose their stake
            // But since the evidence is assigned randomly, as long as there are enough verifiers, this should not be a problem
            // But there are cases where the verifier is assigned to a lot of requests and they are not able to provide feedback to all of them
            // And this specific domain does not hold a lot of verifiers, this can be a problem

            // maybe after the whole process is done, delete this requestId from the assignedRequestIds? => This might be a bit complicated
            // or perhaps limit the length of the assignedRequestIds?
            address[] memory verifiersWithinSameDomain = i_verifier
                .getSkillDomainToVerifiersWithinSameDomain(
                    i_vSkillUser.getRequestIdToEvidence(requestId).skillDomain
                );
            for (uint8 j = 0; j < randomWordsWithinRange.length; j++) {
                s_requestIdToVerifiersAssigned[requestId].push(
                    verifiersWithinSameDomain[randomWordsWithinRange[j]]
                );
                i_verifier.setVerifierAssignedRequestIds(
                    requestId,
                    verifiersWithinSameDomain[randomWordsWithinRange[j]]
                );
                i_verifier.addVerifierUnhandledRequestCount(
                    verifiersWithinSameDomain[randomWordsWithinRange[j]]
                );
                // only 7 days allowed for the verifiers to provide feedback
                i_vSkillUser.setDeadline(requestId, block.timestamp + DEADLINE);
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
            StructDefinition.VSkillUserEvidence memory evidence = i_vSkillUser
                .getRequestIdToEvidence(requestId);
            // mint those who have the status approved or DIFFERENTOPINION_A
            if (
                evidence.status ==
                StructDefinition.VSkillUserSubmissionStatus.APPROVED ||
                evidence.status ==
                StructDefinition.VSkillUserSubmissionStatus.DIFFERENTOPINION_A
            ) {
                i_vSkillUserNft.mintUserNft(
                    i_vSkillUser.getRequestIdToEvidence(requestId).skillDomain,
                    evidence.submitter
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

    // this transfer will be manually handled by the owner
    // What about use delegatecall...? (do the operation in the context of the caller)
    // @update come back to this design later
    function transferBonusFromVSkillUserToVerifierContract()
        external
        onlyOwner
    {
        uint256 transferredRewardAmount = i_vSkillUser
            .transferBonusToVerifierContract(address(i_verifier));
        i_verifier.addReward(transferredRewardAmount);
    }

    /*//////////////////////////////////////////////////////////////
                     INTERNAL AND PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _makeRandomWordsUnique(
        uint256[] memory randomWords,
        uint256 verifierWithinSameDomainLength
    ) internal pure returns (uint256[] memory) {
        // Check and fix (0,1) pair
        if (randomWords[0] == randomWords[1]) {
            randomWords[1] =
                (randomWords[1] + 1) %
                verifierWithinSameDomainLength;
        }

        // Check and fix (0,2) pair
        if (randomWords[0] == randomWords[2]) {
            randomWords[2] =
                (randomWords[2] + 1) %
                verifierWithinSameDomainLength;
        }

        // Check and fix (1,2) pair
        if (randomWords[1] == randomWords[2]) {
            randomWords[2] =
                (randomWords[2] + 1) %
                verifierWithinSameDomainLength;
            // After modification, need to check against first element again
            if (randomWords[0] == randomWords[2]) {
                randomWords[2] =
                    (randomWords[2] + 1) %
                    verifierWithinSameDomainLength;
            }
        }

        return randomWords;
    }

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

        // @audit-info Unsafe Casting => see in aderyn report
        // This one can be solved by just using the uint160 xorResult
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

    /*//////////////////////////////////////////////////////////////
                                GETTERS
    //////////////////////////////////////////////////////////////*/

    function getVerifierContractAddress() external view returns (address) {
        return address(i_verifier);
    }

    function getForwarder() external view returns (address) {
        return s_forwarder;
    }

    function getUnhandledRequestIds() external view returns (uint256[] memory) {
        return s_unhandledRequestIds;
    }

    function getUnhandledRequestIdsLength() external view returns (uint256) {
        return s_unhandledRequestIds.length;
    }

    function getBatchProcessed() external view returns (uint256) {
        return s_batchProcessed;
    }

    function getBatchToProcessedRequestIds(
        uint256 batchNumber
    ) external view returns (uint256[] memory) {
        return s_batchToProcessedRequestIds[batchNumber];
    }

    function getBatchToDeadline(
        uint256 batchNumber
    ) external view returns (uint256) {
        return s_batchToDeadline[batchNumber];
    }

    function getBatchProcessedOrNot(
        uint256 batchNumber
    ) external view returns (StructDefinition.RelayerBatchStatus) {
        return s_batchProcessedOrNot[batchNumber];
    }

    function getDeadline() external pure returns (uint256) {
        return DEADLINE;
    }
}
