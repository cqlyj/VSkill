// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {ILogAutomation, Log} from "@chainlink/contracts/src/v0.8/automation/interfaces/ILogAutomation.sol";
import {VSkillUser} from "src/VSkillUser.sol";
import {StructDefinition} from "src/library/StructDefinition.sol";
import {Distribution} from "src/Distribution.sol";
import {Verifier} from "src/Verifier.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {VSkillUserNft} from "src/VSkillUserNft.sol";

// This contract will be the yul version of the Relayer contract
// In order to reduce the gas cost of the contract operations
contract RelayerYul is ILogAutomation, Ownable {
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
    function assignEvidenceToVerifiers() external onlyOwner {
        assembly {
            // .slot gets storage slot number of a state variable
            let unhandledRequestIdsSlot := s_unhandledRequestIds.slot

            // Stack input
            // key: 32-byte key in storage.
            // Stack output
            // value: 32-byte value corresponding to that key. 0 if that key was never written before.
            // The first 32 bytes of the storage slot contain the length of the array.q
            let unhandledRequestIdsLength := sload(unhandledRequestIdsSlot)

            // if there is no unhandled request, we will return so that we don't waste gas
            if iszero(unhandledRequestIdsLength) {
                // Stack input
                // offset: byte offset in the memory in bytes, to copy what will be the return data of this context.
                // size: byte size to copy (size of the return data).
                return(0, 0)
            }

            // Update batch related storage

            // s_batchToProcessedRequestIds[s_batchProcessed] = s_unhandledRequestIds;
            // s_batchToDeadline[s_batchProcessed] = block.timestamp + DEADLINE;
            // s_batchProcessed++;

            let batchSlot := s_batchProcessed.slot
            let currentBatch := sload(batchSlot)

            // Store batch deadline

            // Stack input
            // offset: offset in the memory in bytes.
            // value: 32-byte value to write in the memory.

            // This calculates storage slot for a mapping entry:
            // For mapping s_batchToDeadline[currentBatch], we need to:
            // Store the key (currentBatch) at memory position 0
            // Store the mapping's slot at memory position 32 (0x20)
            // Take keccak256 hash of these 64 bytes (0x40) to get final storage slot
            mstore(0x00, currentBatch)
            mstore(0x20, s_batchToDeadline.slot)
            let deadlineSlot := keccak256(0x00, 0x40)
            // timestamp() gets current block timestamp
            sstore(deadlineSlot, add(timestamp(), DEADLINE))

            // Calculate storage slot for s_batchToProcessedRequestIds mapping
            let batchToRequestsSlot := s_batchToProcessedRequestIds.slot

            // Store the array in the mapping
            // First, calculate the slot for s_batchToProcessedRequestIds[s_batchProcessed]
            // Calculate mapping slot for current batch
            mstore(0x00, currentBatch)
            mstore(0x20, batchToRequestsSlot)
            let mappingIndex := keccak256(0x00, 0x40)

            // Store length in the mapping array
            sstore(mappingIndex, unhandledRequestIdsLength)

            // Copy the array
            for {
                let i := 0
            } lt(i, unhandledRequestIdsLength) {
                i := add(i, 1)
            } {
                // Calculate source slot (s_unhandledRequestIds array element)
                mstore(0x00, unhandledRequestIdsSlot)
                let sourceSlot := keccak256(0x00, 0x20)
                sourceSlot := add(sourceSlot, i)

                // Calculate destination slot in the mapping array
                mstore(0x00, mappingIndex)
                let destSlot := keccak256(0x00, 0x20)
                destSlot := add(destSlot, i)

                // Copy the value
                sstore(destSlot, sload(sourceSlot))
            }

            // Increment batch number
            sstore(batchSlot, add(currentBatch, 1))
        }

        uint256 length = s_unhandledRequestIds.length;
        // Handle verifier assignments
        for (uint256 i = 0; i < length; i++) {
            uint256 requestId = s_unhandledRequestIds[i];
            _assignVerifiersToRequest(requestId);
        }

        // Clear unhandled requests
        assembly {
            // Clear array length
            sstore(s_unhandledRequestIds.slot, 0)

            // Get array data slot
            let arrayDataSlot := keccak256(s_unhandledRequestIds.slot, 0x00)

            // Clear array elements
            for {
                let i := 0
            } lt(i, length) {
                i := add(i, 1)
            } {
                sstore(add(arrayDataSlot, i), 0)
            }
        }

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

    // Helper function to handle verifier assignment for a single request
    function _assignVerifiersToRequest(uint256 requestId) internal {
        uint256[]
            memory randomWordsWithinRange = s_requestIdToRandomWordsWithinRange[
                requestId
            ];

        // Get skill domain and verifiers
        StructDefinition.VSkillUserEvidence memory evidence = i_vSkillUser
            .getRequestIdToEvidence(requestId);
        address[] memory verifiersWithinSameDomain = i_verifier
            .getSkillDomainToVerifiersWithinSameDomain(evidence.skillDomain);

        assembly {
            // Load array lengths from memory
            let randomWordsLength := mload(randomWordsWithinRange)
            // Get pointers to the start of the array data (skip length word)
            let randomWordsPtr := add(randomWordsWithinRange, 0x20)
            let verifiersPtr := add(verifiersWithinSameDomain, 0x20)

            // Calculate storage slot for s_requestIdToVerifiersAssigned[requestId]
            mstore(0x00, requestId)
            mstore(0x20, s_requestIdToVerifiersAssigned.slot)
            let mappingSlot := keccak256(0x00, 0x40)

            // Initialize array length in storage if it's not already set
            let currentLength := sload(mappingSlot)
            if iszero(currentLength) {
                sstore(mappingSlot, 0)
            }

            for {
                let j := 0
            } lt(j, randomWordsLength) {
                j := add(j, 1)
            } {
                // Get verifier address using randomWordsWithinRange[j] as index
                let randomIndex := mload(add(randomWordsPtr, mul(j, 0x20)))
                let verifierAddr := mload(
                    add(verifiersPtr, mul(randomIndex, 0x20))
                )

                // Update array length
                currentLength := sload(mappingSlot)
                sstore(mappingSlot, add(currentLength, 1))

                // Calculate storage slot for array element
                // Hash the array base slot to get the starting slot for elements
                mstore(0x00, mappingSlot)
                let arrayBaseSlot := keccak256(0x00, 0x20)
                // Add the current index to get the exact slot
                let elementSlot := add(arrayBaseSlot, currentLength)

                // Store verifier address
                sstore(elementSlot, verifierAddr)
            }
        }

        // External contract calls can't be optimized in assembly
        for (uint8 j = 0; j < randomWordsWithinRange.length; j++) {
            address verifier = verifiersWithinSameDomain[
                randomWordsWithinRange[j]
            ];
            i_verifier.setVerifierAssignedRequestIds(requestId, verifier);
            i_verifier.addVerifierUnhandledRequestCount(verifier);
            i_vSkillUser.setDeadline(requestId, block.timestamp + DEADLINE);
        }
    }

    function _makeRandomWordsUnique(
        uint256[] memory randomWords,
        uint256 verifierWithinSameDomainLength
    ) internal pure returns (uint256[] memory) {
        assembly {
            // mem[p…(p+32))
            // When you pass an array to a function, its memory layout is:
            // First 32 bytes (0x20): Array length
            // Next 32 bytes: First element
            // Next 32 bytes: Second element
            let first := mload(add(randomWords, 0x20))
            let second := mload(add(randomWords, 0x40))
            let third := mload(add(randomWords, 0x60))

            // Check and fix (0,1) pair
            if eq(first, second) {
                // second = (second + 1) % length
                second := mod(add(second, 1), verifierWithinSameDomainLength)
                mstore(add(randomWords, 0x40), second)
            }

            // Check and fix (0,2) pair
            if eq(first, third) {
                // third = (third + 1) % length
                third := mod(add(third, 1), verifierWithinSameDomainLength)
                mstore(add(randomWords, 0x60), third)
            }

            // Check and fix (1,2) pair
            if eq(second, third) {
                // third = (third + 1) % length
                third := mod(add(third, 1), verifierWithinSameDomainLength)

                // Check against first element again
                if eq(first, third) {
                    third := mod(add(third, 1), verifierWithinSameDomainLength)
                }
                mstore(add(randomWords, 0x60), third)
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
    ) private pure returns (address resultAddr) {
        // A⊕A=0
        // A⊕0=A
        // XOR all assigned verifiers

        assembly {
            let xorResult := 0

            // XOR all assigned verifiers
            let assignedLength := mload(verifiersAssigned)
            let assignedPtr := add(verifiersAssigned, 0x20)

            // lt => less than
            for {
                let i := 0
            } lt(i, assignedLength) {
                i := add(i, 1)
            } {
                xorResult := xor(
                    xorResult,
                    mload(add(assignedPtr, mul(i, 0x20)))
                )
            }

            // XOR all verifiers with same operation
            let sameOpLength := mload(verifiersWithSameOperation)
            let sameOpPtr := add(verifiersWithSameOperation, 0x20)

            for {
                let i := 0
            } lt(i, sameOpLength) {
                i := add(i, 1)
            } {
                xorResult := xor(xorResult, mload(add(sameOpPtr, mul(i, 0x20))))
            }

            // Convert result to address
            resultAddr := xorResult
        }
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
