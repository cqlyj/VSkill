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
import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";
import {StructDefinition} from "../utils/library/StructDefinition.sol";

contract Verifier is VSkillUser, Distribution, AutomationCompatibleInterface {
    using StructDefinition for StructDefinition.VerifierConstructorParams;
    using StructDefinition for StructDefinition.VerifierEvidenceIpfsHashInfo;
    using StructDefinition for StructDefinition.VerifierFeedbackProvidedEventParams;
    using StructDefinition for StructDefinition.VSkillUserEvidence;
    using StructDefinition for StructDefinition.VSkillUserSubmissionStatus;
    using StructDefinition for StructDefinition.StakingVerifier;

    error Verifier__NotEnoughVerifiers(uint256 verifiersLength);
    error Verifier__NotSelectedVerifier();
    error Verifier__NotAllVerifiersProvidedFeedback();
    error Verifier__EvidenceStillInReview();

    //////////////////////////////
    ///        Structs         ///
    //////////////////////////////

    uint256 private constant INITIAL_REPUTATION = 2;
    uint256 private immutable LOWEST_REPUTATION = 0;
    uint256 private immutable HIGHEST_REPUTATION = 10;
    uint256 private constant BONUS_DISTRIBUTION_NUMBER = 20;

    mapping(string => StructDefinition.VerifierEvidenceIpfsHashInfo)
        private evidenceIpfsHashToItsInfo;

    //////////////////////////////
    ///         Events         ///
    //////////////////////////////

    event VerifierSkillDomainUpdated(
        address indexed verifierAddress,
        string[] newSkillDomains
    );

    event FeedbackProvided(
        StructDefinition.VerifierFeedbackProvidedEventParams feedbackInfo
    );

    event EvidenceToStatusApproveOrNotUpdated(
        string indexed evidenceIpfsHash,
        bool indexed status
    );

    event EvidenceToAllSelectedVerifiersToFeedbackStatusUpdated(
        address indexed verifierAddress,
        string indexed evidenceIpfsHash,
        bool indexed status
    );

    event EvidenceStatusUpdated(
        address indexed user,
        string indexed evidenceIpfsHash,
        StructDefinition.VSkillUserSubmissionStatus status
    );

    event VerifierAssignedToEvidence(
        address indexed verifierAddress,
        address indexed submitter,
        string indexed evidenceIpfsHash
    );

    event EvidenceIpfsHashToSelectedVerifiersUpdated(
        string indexed evidenceIpfsHash,
        address[] selectedVerifiers
    );

    event VerifierReputationUpdated(
        address indexed verifierAddress,
        uint256 indexed prevousReputation,
        uint256 indexed currentReputation
    );

    modifier isVeifier() {
        _isVerifier(msg.sender);
        _;
    }

    modifier enoughNumberOfVerifiers(string memory skillDomain) {
        _enoughNumberOfVerifiers(skillDomain);
        _;
    }

    constructor(
        StructDefinition.VerifierConstructorParams memory params
    )
        VSkillUser(
            params.submissionFeeInUsd,
            params.priceFeed,
            params.userNftImageUris
        )
        Distribution(
            params.subscriptionId,
            params.vrfCoordinator,
            params.keyHash,
            params.callbackGasLimit
        )
    {
        priceFeed = AggregatorV3Interface(params.priceFeed);
    }

    ////////////////////////////////////////////
    /////  Chainlink Automation Functions  /////
    ////////////////////////////////////////////

    // https://docs.chain.link/chainlink-automation/reference/automation-interfaces
    // https://docs.chain.link/chainlink-automation/guides/flexible-upkeeps

    // once someone submits an evidence, the contract will automatically assign the evidence to the selected verifiers
    // those evidence status remains in `submitted` are the evidence that haven't been assigned to the verifiers
    // once the evidence is assigned to the verifiers, the status will be changed to `InReview`

    function checkUpkeep(
        bytes calldata /* checkData */
    )
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        // if the evidence status is `submitted` or `differentOpinion`, this function will return true
        uint256 length = evidences.length;
        for (uint256 i = 0; i < length; i++) {
            if (
                evidences[i].status ==
                StructDefinition.VSkillUserSubmissionStatus.SUBMITTED ||
                evidences[i].status ==
                StructDefinition.VSkillUserSubmissionStatus.DIFFERENTOPINION
            ) {
                upkeepNeeded = true;
                performData = abi.encode(evidences[i]);
                return (upkeepNeeded, performData);
            }
        }
        upkeepNeeded = false;
        return (upkeepNeeded, "");
    }

    function performUpkeep(bytes calldata performData) external override {
        StructDefinition.VSkillUserEvidence memory ev = abi.decode(
            performData,
            (StructDefinition.VSkillUserEvidence)
        );
        _requestVerifiersSelection(ev);
    }

    //////////////////////////////////
    /////   External Functions   /////
    //////////////////////////////////

    function updateSkillDomains(
        string[] memory newSkillDomains
    ) external isVeifier {
        verifiers[addressToId[msg.sender] - 1].skillDomains = newSkillDomains;
        emit VerifierSkillDomainUpdated(msg.sender, newSkillDomains);
    }

    function provideFeedback(
        string memory feedbackIpfsHash,
        string memory evidenceIpfsHash,
        address user,
        bool approved
    ) external {
        _onlySelectedVerifier(evidenceIpfsHash, msg.sender);
        StructDefinition.VSkillUserEvidence[]
            memory userEvidences = addressToEvidences[user];
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

        // addressToEvidence[user].length == 0... ??

        addressToEvidences[user][currentEvidenceIndex].feedbackIpfsHash.push(
            feedbackIpfsHash
        );

        verifiers[addressToId[msg.sender] - 1].feedbackIpfsHash.push(
            feedbackIpfsHash
        );

        emit FeedbackProvided(
            StructDefinition.VerifierFeedbackProvidedEventParams({
                verifierAddress: msg.sender,
                user: user,
                approved: approved,
                feedbackIpfsHash: feedbackIpfsHash,
                evidenceIpfsHash: evidenceIpfsHash
            })
        );

        if (approved) {
            evidenceIpfsHashToItsInfo[evidenceIpfsHash].statusApproveOrNot.push(
                    true
                );
            emit EvidenceToStatusApproveOrNotUpdated(evidenceIpfsHash, true);

            evidenceIpfsHashToItsInfo[evidenceIpfsHash]
                .allSelectedVerifiersToFeedbackStatus[msg.sender] = true;
            emit EvidenceToAllSelectedVerifiersToFeedbackStatusUpdated(
                msg.sender,
                evidenceIpfsHash,
                true
            );
        } else {
            evidenceIpfsHashToItsInfo[evidenceIpfsHash].statusApproveOrNot.push(
                    false
                );
            emit EvidenceToStatusApproveOrNotUpdated(evidenceIpfsHash, false);

            evidenceIpfsHashToItsInfo[evidenceIpfsHash]
                .allSelectedVerifiersToFeedbackStatus[msg.sender] = false;
            emit EvidenceToAllSelectedVerifiersToFeedbackStatusUpdated(
                msg.sender,
                evidenceIpfsHash,
                false
            );
        }

        // get all the verifiers who provide feedback and call the function to earn rewards or get penalized

        // Consider pull over push...
        
        // if (
        //     _updateEvidenceStatus(evidenceIpfsHash, user) !=
        //     StructDefinition.VSkillUserSubmissionStatus.INREVIEW
        // ) {
        //     address[] memory allSelectedVerifiers = evidenceIpfsHashToItsInfo[
        //         evidenceIpfsHash
        //     ].selectedVerifiers;
        //     uint256 allSelectedVerifiersLength = allSelectedVerifiers.length;
        //     for (uint256 i = 0; i < allSelectedVerifiersLength; i++) {
        //         _earnRewardsOrGetPenalized(
        //             evidenceIpfsHash,
        //             user,
        //             allSelectedVerifiers[i]
        //         );
        //     }
        // }
    }

    function stake() public payable override {
        super.stake();
    }

    function withdrawStake(uint256 amountToWithdrawInEth) public override {
        super.withdrawStake(amountToWithdrawInEth);
    }

    //////////////////////////////////
    /////   Internal Functions   /////
    //////////////////////////////////

    function _earnRewardsOrGetPenalized(
        string memory evidenceIpfsHash,
        address userThatSubmittedEvidence,
        address verifierAddress
    ) internal {
        _onlySelectedVerifier(evidenceIpfsHash, verifierAddress);
        if (
            _updateEvidenceStatus(
                evidenceIpfsHash,
                userThatSubmittedEvidence
            ) == StructDefinition.VSkillUserSubmissionStatus.INREVIEW
        ) {
            revert Verifier__EvidenceStillInReview();
        } else if (
            _updateEvidenceStatus(
                evidenceIpfsHash,
                userThatSubmittedEvidence
            ) == StructDefinition.VSkillUserSubmissionStatus.DIFFERENTOPINION
        ) {
            // first wait until this evidence finally gets approved or rejected
            // then penalize or reward the verifiers
            return;
        } else if (
            _updateEvidenceStatus(
                evidenceIpfsHash,
                userThatSubmittedEvidence
            ) == StructDefinition.VSkillUserSubmissionStatus.APPROVED
        ) {
            bool status = evidenceIpfsHashToItsInfo[evidenceIpfsHash]
                .allSelectedVerifiersToFeedbackStatus[verifierAddress];
            if (status) {
                _rewardVerifiers(verifierAddress);
            } else {
                _penalizeVerifiers(verifierAddress);
            }
        } else {
            bool status = evidenceIpfsHashToItsInfo[evidenceIpfsHash]
                .allSelectedVerifiersToFeedbackStatus[verifierAddress];
            if (status) {
                _penalizeVerifiers(verifierAddress);
            } else {
                _rewardVerifiers(verifierAddress);
            }
        }
    }

    function _rewardVerifiers(address verifiersAddress) internal {
        uint256 currentReputation = verifiers[addressToId[verifiersAddress] - 1]
            .reputation;

        if (currentReputation < HIGHEST_REPUTATION) {
            verifiers[addressToId[verifiersAddress] - 1].reputation++;

            emit VerifierReputationUpdated(
                verifiersAddress,
                verifiers[addressToId[verifiersAddress] - 1].reputation - 1,
                verifiers[addressToId[verifiersAddress] - 1].reputation
            );
        }
        // get the reward from the contract => what's the ratio of the reward?
        // first, higher reputation leads to higher rewards
        // second, the reward will depends on the bonus money in the staking contract
        // Here is the algorithm to calculate the reward: reward = reputation / HIGHEST_REPUTATION / 20 * bonusMoneyInUsd
        // 20 is that the verifier needs to stake about 20 USD to be a verifier => This is just a round number

        uint256 rewardAmountInEth = (currentReputation /
            HIGHEST_REPUTATION /
            BONUS_DISTRIBUTION_NUMBER) * super.getBonusMoneyInEth();

        super._rewardVerifierInFormOfStake(verifiersAddress, rewardAmountInEth);
    }

    function _penalizeVerifiers(address verifiersAddress) internal {
        if (
            verifiers[addressToId[verifiersAddress] - 1].reputation >
            LOWEST_REPUTATION
        ) {
            verifiers[addressToId[verifiersAddress] - 1].reputation--;

            emit VerifierReputationUpdated(
                verifiersAddress,
                verifiers[addressToId[verifiersAddress] - 1].reputation + 1,
                verifiers[addressToId[verifiersAddress] - 1].reputation
            );
        } else {
            StructDefinition.StakingVerifier
                memory verifierToBeRemoved = verifiers[
                    addressToId[verifiersAddress] - 1
                ];

            uint256 verifierStakedMoneyInEth = verifierToBeRemoved
                .moneyStakedInEth;

            // after remove the verifier, what about the money they stake?
            // the money will be collected by the staking contract and will be used to reward the verifiers who provide feedback
            // in staking contract we need to implement a function to distribute the money to the verifiers who provide feedback...

            // This money will be locked in the staking contract and will be used to reward the verifiers who provide feedback
            super._penalizeVerifierStakeToBonusMoney(verifierStakedMoneyInEth);

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
    ) public view returns (address[] memory, uint256 count) {
        uint256 length = verifiers.length;

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
                        verifiersWithinSameDomainCount++;
                        break; // No need to check other domains for this verifier
                    }
                }
            }
        }

        address[] memory verifiersWithinSameDomain = new address[](
            verifiersWithinSameDomainCount
        );

        uint256 verifiersWithinSameDomainIndex = 0;

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
                            verifiersWithinSameDomainIndex
                        ] = verifiers[i].verifierAddress;
                        verifiersWithinSameDomainIndex++;
                        break; // No need to check other domains for this verifier
                    }
                }
            }
        }

        return (verifiersWithinSameDomain, verifiersWithinSameDomainCount);
    }

    function _enoughNumberOfVerifiers(string memory skillDomain) public view {
        (, uint256 verifiersWithinSameDomainCount) = _verifiersWithinSameDomain(
            skillDomain
        );
        if (verifiersWithinSameDomainCount < numWords) {
            revert Verifier__NotEnoughVerifiers(verifiersWithinSameDomainCount);
        }
    }

    function _requestVerifiersSelection(
        StructDefinition.VSkillUserEvidence memory ev
    ) public {
        // Initiate the random number request
        super.distributionRandomNumberForVerifiers(address(this), ev);
    }

    function _selectedVerifiersAddressCallback(
        StructDefinition.VSkillUserEvidence memory ev,
        uint256[] memory randomWords
    )
        public
        enoughNumberOfVerifiers(ev.skillDomain)
        returns (address[] memory)
    {
        address[] memory selectedVerifiers = new address[](numWords);

        (
            address[] memory verifiersWithinSameDomain,
            uint256 verifiersWithinSameDomainCount
        ) = _verifiersWithinSameDomain(ev.skillDomain);

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

        _updateSelectedVerifiersInfo(ev.evidenceIpfsHash, selectedVerifiers);

        _assignEvidenceToSelectedVerifier(ev, selectedVerifiers);

        return selectedVerifiers;
    }

    function _updateSelectedVerifiersInfo(
        string memory evidenceIpfsHash,
        address[] memory selectedVerifiers
    ) internal {
        address[] memory prevSelectedVerifiers = evidenceIpfsHashToItsInfo[
            evidenceIpfsHash
        ].selectedVerifiers;

        uint256 prevSelectedVerifiersLength = prevSelectedVerifiers.length;

        if (prevSelectedVerifiersLength > 0) {
            address[] memory prevAndCurrentSelectedVerifiers = new address[](
                prevSelectedVerifiersLength + numWords
            );

            for (uint256 i = 0; i < prevSelectedVerifiersLength; i++) {
                prevAndCurrentSelectedVerifiers[i] = prevSelectedVerifiers[i];
            }

            for (uint256 i = 0; i < numWords; i++) {
                prevAndCurrentSelectedVerifiers[
                    prevSelectedVerifiersLength + i
                ] = selectedVerifiers[i];
            }

            evidenceIpfsHashToItsInfo[evidenceIpfsHash]
                .selectedVerifiers = prevAndCurrentSelectedVerifiers;

            emit EvidenceIpfsHashToSelectedVerifiersUpdated(
                evidenceIpfsHash,
                prevAndCurrentSelectedVerifiers
            );
        } else {
            evidenceIpfsHashToItsInfo[evidenceIpfsHash]
                .selectedVerifiers = selectedVerifiers;

            emit EvidenceIpfsHashToSelectedVerifiersUpdated(
                evidenceIpfsHash,
                selectedVerifiers
            );
        }
    }

    function _assignEvidenceToSelectedVerifier(
        StructDefinition.VSkillUserEvidence memory ev,
        address[] memory selectedVerifiers
    ) internal {
        for (uint256 i = 0; i < numWords; i++) {
            verifiers[addressToId[selectedVerifiers[i]] - 1]
                .evidenceIpfsHash
                .push(ev.evidenceIpfsHash);

            verifiers[addressToId[selectedVerifiers[i]] - 1]
                .evidenceSubmitters
                .push(ev.submitter);

            emit VerifierAssignedToEvidence(
                selectedVerifiers[i],
                ev.submitter,
                ev.evidenceIpfsHash
            );
        }

        ev.status = StructDefinition.VSkillUserSubmissionStatus.INREVIEW;
        emit EvidenceStatusUpdated(
            ev.submitter,
            ev.evidenceIpfsHash,
            ev.status
        );
    }

    function _onlySelectedVerifier(
        string memory evidenceIpfsHash,
        address verifierAddress
    ) internal view isVeifier {
        uint256 length = verifiers[addressToId[verifierAddress] - 1]
            .evidenceIpfsHash
            .length;
        for (uint256 i = 0; i < length; i++) {
            if (
                keccak256(
                    abi.encodePacked(
                        verifiers[addressToId[verifierAddress] - 1]
                            .evidenceIpfsHash[i]
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
        bool[] memory status = evidenceIpfsHashToItsInfo[evidenceIpfsHash]
            .statusApproveOrNot;
        if (status.length < numWords) {
            revert Verifier__NotAllVerifiersProvidedFeedback();
        }
    }

    function _updateEvidenceStatus(
        string memory evidenceIpfsHash,
        address user
    ) internal returns (StructDefinition.VSkillUserSubmissionStatus) {
        _waitForConfirmation(evidenceIpfsHash);
        bool[] memory status = evidenceIpfsHashToItsInfo[evidenceIpfsHash]
            .statusApproveOrNot;
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
        // Anyone of them gives a different feedback, the status be differentOpinion
        // And the evidence will be assigned again randomly to three verifiers(may be the same verifiers => it's possible)
        // The process will be repeated until all three verifiers give the same feedback

        for (uint256 i = 0; i < numWords; i++) {
            if (status[i] != status[i + 1]) {
                StructDefinition.VSkillUserEvidence
                    storage ev = addressToEvidences[user][currentEvidenceIndex];
                ev.status = StructDefinition
                    .VSkillUserSubmissionStatus
                    .DIFFERENTOPINION;
                emit EvidenceStatusUpdated(
                    user,
                    ev.evidenceIpfsHash,
                    StructDefinition.VSkillUserSubmissionStatus.DIFFERENTOPINION
                );
                return
                    StructDefinition
                        .VSkillUserSubmissionStatus
                        .DIFFERENTOPINION;
            }
        }

        if (status[0]) {
            StructDefinition.VSkillUserEvidence memory ev = addressToEvidences[
                user
            ][currentEvidenceIndex];
            ev.status = StructDefinition.VSkillUserSubmissionStatus.APPROVED;
            emit EvidenceStatusUpdated(
                user,
                ev.evidenceIpfsHash,
                StructDefinition.VSkillUserSubmissionStatus.APPROVED
            );
            return StructDefinition.VSkillUserSubmissionStatus.APPROVED;
        } else {
            StructDefinition.VSkillUserEvidence memory ev = addressToEvidences[
                user
            ][currentEvidenceIndex];
            ev.status = StructDefinition.VSkillUserSubmissionStatus.REJECTED;
            emit EvidenceStatusUpdated(
                user,
                ev.evidenceIpfsHash,
                StructDefinition.VSkillUserSubmissionStatus.REJECTED
            );
            return StructDefinition.VSkillUserSubmissionStatus.REJECTED;
        }
    }

    ///////////////////////////////
    /////   Getter Functions   ////
    ///////////////////////////////

    function getEvidenceToStatusApproveOrNot(
        string memory evidenceIpfsHash
    ) external view returns (bool[] memory) {
        return evidenceIpfsHashToItsInfo[evidenceIpfsHash].statusApproveOrNot;
    }

    function getEvidenceIpfsHashToSelectedVerifiers(
        string memory evidenceIpfsHash
    ) external view returns (address[] memory) {
        return evidenceIpfsHashToItsInfo[evidenceIpfsHash].selectedVerifiers;
    }

    function getEvidenceToAllSelectedVerifiersToFeedbackStatus(
        string memory evidenceIpfsHash,
        address verifierAddress
    ) external view returns (bool) {
        return
            evidenceIpfsHashToItsInfo[evidenceIpfsHash]
                .allSelectedVerifiersToFeedbackStatus[verifierAddress];
    }
}
