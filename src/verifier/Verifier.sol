// SPDX-License-Identifier: MIT

// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions

pragma solidity ^0.8.24;

import {VSkillUser} from "../user/VSkillUser.sol";
import {Distribution} from "../oracle/Distribution.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract Verifier is VSkillUser, Distribution {
    error Verifier__NotEnoughVerifiers(uint256 verifiersLength);
    error Verifier__NotSelectedVerifier();
    error Verifier__NotAllVerifiersProvidedFeedback();
    error Verifier__EvidenceStillInReview();

    uint256 private constant INITIAL_REPUTATION = 2;
    uint256 private immutable LOWEST_REPUTATION = 0;
    uint256 private immutable HIGHEST_REPUTATION = 10;
    uint256 private constant BONUS_DISTRIBUTION_NUMBER = 20;

    mapping(string => bool[]) private evidenceToStatusApproveOrNot;

    modifier isVeifier() {
        _isVerifier(msg.sender);
        _;
    }

    modifier enoughNumberOfVerifiers(string memory skillDomain) {
        _enoughNumberOfVerifiers(skillDomain);
        _;
    }

    modifier onlySelectedVerifier(string memory evidenceIpfsHash) {
        _onlySelectedVerifier(evidenceIpfsHash);
        _;
    }

    constructor(
        address _priceFeed,
        uint64 _subscriptionId,
        address _vrfCoordinator,
        bytes32 _keyHash,
        uint32 _callbackGasLimit,
        uint256 _submissionFeeInUsd,
        string[] memory _userNftImageUris
    )
        VSkillUser(_submissionFeeInUsd, _priceFeed, _userNftImageUris)
        Distribution(
            _subscriptionId,
            _vrfCoordinator,
            _keyHash,
            _callbackGasLimit
        )
    {
        priceFeed = AggregatorV3Interface(_priceFeed);
    }

    function earnRewardsOrGetPenalized(
        string memory evidenceIpfsHash,
        address userThatSubmittedEvidence
    ) external onlySelectedVerifier(evidenceIpfsHash) {
        if (
            _updateEvidenceStatus(
                evidenceIpfsHash,
                userThatSubmittedEvidence
            ) == SubmissionStatus.InReview
        ) {
            _penalizeVerifiers(msg.sender);
            revert Verifier__EvidenceStillInReview();
        }

        _rewardVerifiers(msg.sender);
    }

    function updateSkillDomains(
        string[] memory newSkillDomains
    ) external isVeifier {
        verifiers[addressToId[msg.sender] - 1].skillDomains = newSkillDomains;
    }

    function provideFeedback(
        string memory feedbackIpfsHash,
        string memory evidenceIpfsHash,
        address user,
        bool approved
    ) external onlySelectedVerifier(evidenceIpfsHash) {
        evidence[] memory userEvidences = addressToEvidences[user];
        uint256 length = userEvidences.length;
        uint256 currentEvidenceIndex;
        for (uint256 i = 0; i < length; i++) {
            if (
                keccak256(
                    abi.encodePacked(userEvidences[i].evidenceIpfsHash)
                ) == keccak256(abi.encodePacked(evidenceIpfsHash))
            ) {
                currentEvidenceIndex = i;
                break;
            }
        }

        userEvidences[currentEvidenceIndex].status = SubmissionStatus.InReview;
        userEvidences[currentEvidenceIndex].feedbackIpfsHash = feedbackIpfsHash;
        verifiers[addressToId[msg.sender] - 1].feedbackIpfsHash.push(
            feedbackIpfsHash
        );

        if (approved) {
            evidenceToStatusApproveOrNot[evidenceIpfsHash].push(true);
        } else {
            evidenceToStatusApproveOrNot[evidenceIpfsHash].push(false);
        }
    }

    //////////////////////////////////
    /////   Internal Functions   /////
    //////////////////////////////////

    function _rewardVerifiers(address verifiersAddress) internal {
        uint256 currentReputation = verifiers[addressToId[verifiersAddress] - 1]
            .reputation;

        if (currentReputation < HIGHEST_REPUTATION) {
            verifiers[addressToId[verifiersAddress] - 1].reputation++;
        }
        // get the reward from the contract => what's the ratio of the reward?
        // first, higher reputation leads to higher rewards
        // second, the reward will depends on the bonus money in the staking contract
        // Here is the algorithm to calculate the reward: reward = reputation / HIGHEST_REPUTATION / 20 * bonusMoneyInUsd
        // 20 is that the verifier needs to stake about 20 USD to be a verifier => This is just a round number

        uint256 rewardAmountInUsd = (currentReputation /
            HIGHEST_REPUTATION /
            BONUS_DISTRIBUTION_NUMBER) * super.getBonusMoneyInUsd();

        super._rewardVerifierInFormOfStake(verifiersAddress, rewardAmountInUsd);
    }

    function _penalizeVerifiers(address verifiersAddress) internal {
        if (
            verifiers[addressToId[verifiersAddress] - 1].reputation >
            LOWEST_REPUTATION
        ) {
            verifiers[addressToId[verifiersAddress] - 1].reputation--;
        } else {
            verifier memory verifierToBeRemoved = verifiers[
                addressToId[verifiersAddress] - 1
            ];

            uint256 verifierStakedMoneyInUsd = verifierToBeRemoved
                .moneyStakedInUsd;

            // after remove the verifier, what about the money they stake?
            // the money will be collected by the staking contract and will be used to reward the verifiers who provide feedback
            // in staking contract we need to implement a function to distribute the money to the verifiers who provide feedback...

            // This money will be locked in the staking contract and will be used to reward the verifiers who provide feedback
            super._penalizeVerifierStakeToBonusMoney(verifierStakedMoneyInUsd);

            super._removeVerifier(verifiersAddress);

            emit LoseVerifier(verifierToBeRemoved.verifierAddress);
        }
    }

    function _isVerifier(address verifierOrUser) internal view {
        if (addressToId[verifierOrUser] == 0) {
            revert Staking__NotVerifier();
        }
    }

    function _verifiersWithinSameDomain(
        string memory skillDomain
    ) internal view returns (address[] memory, uint256 count) {
        uint256 length = verifiers.length;
        address[] memory verifiersWithinSameDomain = new address[](length);
        uint256 verifiersWithinSameDomainCount = 0;
        for (uint256 i = 0; i < length; i++) {
            if (verifiers[i].skillDomains.length > 0) {
                uint256 skillDomainLength = verifiers[i].skillDomains.length;
                for (uint256 j = 0; j < skillDomainLength; j++) {
                    if (
                        keccak256(
                            abi.encodePacked(verifiers[i].skillDomains[j])
                        ) == keccak256(abi.encodePacked(skillDomain))
                    ) {
                        verifiersWithinSameDomain[
                            verifiersWithinSameDomainCount
                        ] = verifiers[i].verifierAddress;
                        verifiersWithinSameDomainCount++;
                    }
                }
            }
        }
        return (verifiersWithinSameDomain, verifiersWithinSameDomainCount);
    }

    function _enoughNumberOfVerifiers(string memory skillDomain) internal view {
        (, uint256 verifiersWithinSameDomainCount) = _verifiersWithinSameDomain(
            skillDomain
        );
        if (verifiersWithinSameDomainCount < numWords) {
            revert Verifier__NotEnoughVerifiers(verifiersWithinSameDomainCount);
        }
    }

    function _selectedVerifiersAddress(
        string memory skillDomain
    )
        internal
        view
        enoughNumberOfVerifiers(skillDomain)
        returns (address[] memory)
    {
        address[] memory selectedVerifiers = new address[](numWords);

        uint256[] memory randomWords = getRandomWords();

        (
            address[] memory verifiersWithinSameDomain,
            uint256 verifiersWithinSameDomainCount
        ) = _verifiersWithinSameDomain(skillDomain);

        // One reputation score is equal to one chance of being selected, and the total number of chances is equal to the sum of all reputation scores
        // One verifier can take multiple selected indices the same as the reputation score
        // How to fulfill this?
        // (1) Create an array of selected indices with the length of the sum of all reputation scores
        // (2) Fill the array with the verifier's address based on the reputation score

        uint256 totalReputationScore = 0;
        for (uint256 i = 0; i < verifiersWithinSameDomainCount; i++) {
            totalReputationScore += verifiers[
                addressToId[verifiersWithinSameDomain[i]] - 1
            ].reputation;
        }

        uint256[] memory selectedIndices = new uint256[](totalReputationScore);

        uint256 selectedIndicesCount = 0;

        for (uint256 i = 0; i < verifiersWithinSameDomainCount; i++) {
            uint256 reputation = verifiers[
                addressToId[verifiersWithinSameDomain[i]] - 1
            ].reputation;
            for (uint256 j = 0; j < reputation; j++) {
                selectedIndices[selectedIndicesCount] = i;
                selectedIndicesCount++;
            }
        }

        for (uint256 i = 0; i < numWords; i++) {
            uint256 randomIndex = randomWords[i] % totalReputationScore;
            selectedVerifiers[i] = verifiersWithinSameDomain[
                selectedIndices[randomIndex]
            ];
        }

        return selectedVerifiers;
    }

    function _assignEvidenceToSelectedVerifier(
        string memory skillDomain,
        string memory evidenceIpfsHash
    ) internal {
        address[] memory selectedVerifiers = _selectedVerifiersAddress(
            skillDomain
        );

        for (uint256 i = 0; i < numWords; i++) {
            verifiers[addressToId[selectedVerifiers[i]] - 1]
                .evidenceIpfsHash
                .push(evidenceIpfsHash);
        }
    }

    function _onlySelectedVerifier(
        string memory evidenceIpfsHash
    ) internal view isVeifier {
        uint256 length = verifiers[addressToId[msg.sender] - 1]
            .evidenceIpfsHash
            .length;
        for (uint256 i = 0; i < length; i++) {
            if (
                keccak256(
                    abi.encodePacked(
                        verifiers[addressToId[msg.sender] - 1].evidenceIpfsHash[
                            i
                        ]
                    )
                ) == keccak256(abi.encodePacked(evidenceIpfsHash))
            ) {
                return;
            }
        }
        revert Verifier__NotSelectedVerifier();
    }

    function _waitForConfirmation(
        string memory evidenceIpfsHash
    ) internal view {
        bool[] memory status = evidenceToStatusApproveOrNot[evidenceIpfsHash];
        if (status.length < numWords) {
            revert Verifier__NotAllVerifiersProvidedFeedback();
        }
    }

    function _updateEvidenceStatus(
        string memory evidenceIpfsHash,
        address user
    ) internal view returns (SubmissionStatus) {
        _waitForConfirmation(evidenceIpfsHash);
        bool[] memory status = evidenceToStatusApproveOrNot[evidenceIpfsHash];

        uint256 length = addressToEvidences[user].length;
        uint256 currentEvidenceIndex;
        for (uint256 i = 0; i < length; i++) {
            if (
                keccak256(
                    abi.encodePacked(
                        addressToEvidences[user][i].evidenceIpfsHash
                    )
                ) == keccak256(abi.encodePacked(evidenceIpfsHash))
            ) {
                currentEvidenceIndex = i;
                break;
            }
        }

        // If all three verifiers approve or reject the evidence, the status of the evidence will be updated
        // Anyone of them gives a different feedback, the status will remain in review
        // And the evidence will be assigned again randomly to three verifiers(may be the same verifiers => it's possible)
        // The process will be repeated until all three verifiers give the same feedback

        for (uint256 i = 0; i < numWords; i++) {
            if (status[i] != status[i + 1]) {
                return SubmissionStatus.InReview;
            }
        }

        if (status[0]) {
            return SubmissionStatus.Approved;
        } else {
            return SubmissionStatus.Rejected;
        }
    }

    ///////////////////////////////
    /////   Getter Functions   ////
    ///////////////////////////////
}
