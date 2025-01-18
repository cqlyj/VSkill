// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";
import {StructDefinition} from "src/library/StructDefinition.sol";
import {Staking} from "src/Staking.sol";
import {VSkillUser} from "src/VSkillUser.sol";

contract Verifier is AutomationCompatibleInterface, Staking {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error Verifier__NotEnoughVerifiers(uint256 verifiersLength);
    error Verifier__NotSelectedVerifier();
    error Verifier__NotAllVerifiersProvidedFeedback();
    error Verifier__EvidenceStillInReview();
    error Verifier__NotValidSkillDomain();
    error Verifier__SkillDomainAlreadyAdded(address verifierAddress);

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    // why declare the constant again here, in the Staking contract, we have already declared the constant
    // because constant is not inherited, so we need to declare it again
    uint256 private constant INITIAL_REPUTATION = 2;
    uint256 private constant LOWEST_REPUTATION = 0;
    uint256 private constant HIGHEST_REPUTATION = 10;
    uint256 private constant BONUS_DISTRIBUTION_NUMBER = 20;

    mapping(string => StructDefinition.VerifierEvidenceIpfsHashInfo)
        private s_evidenceIpfsHashToItsInfo;
    AggregatorV3Interface private i_priceFeed;

    mapping(string skillDomain => address[] verifiersWithinSameDomain)
        private s_skillDomainToVerifiersWithinSameDomain;
    string[] private s_skillDomains;
    VSkillUser private immutable i_vSkillUser;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event VerifierSkillDomainUpdated();

    event FeedbackProvided(
        StructDefinition.VerifierFeedbackProvidedEventParams indexed feedbackInfo
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

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier isVeifier() {
        _isVerifier(msg.sender);
        _;
    }

    // modifier enoughNumberOfVerifiers(string memory skillDomain) {
    //     _enoughNumberOfVerifiers(skillDomain);
    //     _;
    // }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address priceFeed,
        string[] memory skillDomains,
        address vSkillUser
    ) {
        i_priceFeed = AggregatorV3Interface(priceFeed);
        s_skillDomains = skillDomains;
        i_vSkillUser = VSkillUser(payable(vSkillUser));
    }

    /*//////////////////////////////////////////////////////////////
                     CHAINLINK AUTOMATION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    // https://docs.chain.link/chainlink-automation/reference/automation-interfaces
    // https://docs.chain.link/chainlink-automation/guides/flexible-upkeeps

    function checkUpkeep(
        bytes calldata /* checkData */
    )
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        // // if the evidence status is `submitted` or `differentOpinion`, this function will return true
        // uint256 length = s_evidences.length;
        // // @written audit-medium no bound check for the length and DoS attack is possible
        // for (uint256 i = 0; i < length; i++) {
        //     if (
        //         s_evidences[i].status ==
        //         StructDefinition.VSkillUserSubmissionStatus.SUBMITTED ||
        //         s_evidences[i].status ==
        //         StructDefinition.VSkillUserSubmissionStatus.DIFFERENTOPINION
        //     ) {
        //         upkeepNeeded = true;
        //         performData = abi.encode(s_evidences[i]);
        //         return (upkeepNeeded, performData);
        //     }
        // }
        // upkeepNeeded = false;
        // return (upkeepNeeded, "");
    }

    function performUpkeep(bytes calldata performData) external override {
        // StructDefinition.VSkillUserEvidence memory ev = abi.decode(
        //     performData,
        //     (StructDefinition.VSkillUserEvidence)
        // );
        // _requestVerifiersSelection(ev);
    }

    /*//////////////////////////////////////////////////////////////
                     EXTERNAL AND PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function provideFeedback(
        uint256 requestId,
        string memory feedbackCid,
        bool approve
    ) public onlyVerifier {
        if (!_isSelectedVerifier(requestId)) {
            revert Verifier__NotSelectedVerifier();
        }
        // if not approve, no need to call the following function since the default value is false
        if (!approve) {
            return;
        } else {
            // call the function to update the status of the evidence and set the feedback cid
            i_vSkillUser.approveEvidenceStatus(requestId, feedbackCid);
        }
    }

    function addSkillDomain(string memory skillDomain) public onlyVerifier {
        if (!_isSkillDomainValid(skillDomain)) {
            revert Verifier__NotValidSkillDomain();
        }

        string[] memory currentSkillDomains = s_verifierToInfo[msg.sender]
            .skillDomains;
        uint256 length = currentSkillDomains.length;

        for (uint256 i = 0; i < length; i++) {
            if (
                keccak256(abi.encodePacked(currentSkillDomains[i])) ==
                keccak256(abi.encodePacked(skillDomain))
            ) {
                revert Verifier__SkillDomainAlreadyAdded(msg.sender);
            }
        }

        s_verifierToInfo[msg.sender].skillDomains.push(skillDomain);
        s_skillDomainToVerifiersWithinSameDomain[skillDomain].push(msg.sender);

        emit VerifierSkillDomainUpdated();
    }

    // This function will handle the skill domains and the stake
    function stakeToBecomeVerifier() public payable {
        super.stake();
    }

    function withdrawStakeAndLoseVerifier() public {
        super.withdrawStake();
    }

    /*//////////////////////////////////////////////////////////////
                                 SETTER
    //////////////////////////////////////////////////////////////*/

    // only the Relayer contract will be able to call this function
    // @audit update!
    function setVerifierAssignedRequestIds(
        uint256 requestId,
        address verifier
    ) public {
        s_verifierToInfo[verifier].assignedRequestIds.push(requestId);
    }

    /*//////////////////////////////////////////////////////////////
                     INTERNAL AND PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _isSkillDomainValid(
        string memory skillDomain
    ) internal view returns (bool) {
        uint256 length = s_skillDomains.length;
        for (uint256 i = 0; i < length; i++) {
            if (
                keccak256(abi.encodePacked(s_skillDomains[i])) ==
                keccak256(abi.encodePacked(skillDomain))
            ) {
                return true;
            }
        }
        return false;
    }

    function _isVerifier(address verifierOrUser) internal view {}

    function _isSelectedVerifier(
        uint256 requestId
    ) internal view returns (bool) {
        uint256[] memory assignedRequestIds = s_verifierToInfo[msg.sender]
            .assignedRequestIds;
        // will the id length be too large?
        // No there is the maximum number they can be assigned
        // After reach this number, the verifier needs to withdraw the stake and re-stake to be assigned again
        // about 3000 evidences
        uint256 length = assignedRequestIds.length;
        for (uint256 i = 0; i < length; i++) {
            if (assignedRequestIds[i] == requestId) {
                return true;
            }
        }
        return false;
    }

    /*//////////////////////////////////////////////////////////////
                                GETTERS
    //////////////////////////////////////////////////////////////*/

    function getEvidenceToStatusApproveOrNot(
        string memory evidenceIpfsHash
    ) external view returns (bool[] memory) {
        return s_evidenceIpfsHashToItsInfo[evidenceIpfsHash].statusApproveOrNot;
    }

    function getEvidenceIpfsHashToSelectedVerifiers(
        string memory evidenceIpfsHash
    ) external view returns (address[] memory) {
        return s_evidenceIpfsHashToItsInfo[evidenceIpfsHash].selectedVerifiers;
    }

    function getEvidenceToAllSelectedVerifiersToFeedbackStatus(
        string memory evidenceIpfsHash,
        address verifierAddress
    ) external view returns (bool) {
        return
            s_evidenceIpfsHashToItsInfo[evidenceIpfsHash]
                .allSelectedVerifiersToFeedbackStatus[verifierAddress];
    }

    function getSkillDomainToVerifiersWithinSameDomain(
        string memory skillDomain
    ) external view returns (address[] memory) {
        return s_skillDomainToVerifiersWithinSameDomain[skillDomain];
    }

    function getSkillDomainToVerifiersWithinSameDomainLength(
        string memory skillDomain
    ) external view returns (uint256) {
        return s_skillDomainToVerifiersWithinSameDomain[skillDomain].length;
    }
}

// function provideFeedback(
//     string memory feedbackIpfsHash,
//     string memory evidenceIpfsHash,
//     address user,
//     bool approved
// ) external {
//     // can the same verifier call multiple time of this function? Yes, the verifier can call multiple times
//     // Any impact? The verifier will be rewarded or penalized multiple times
//     // @written audit-high the verifier can call multiple times of this function and pass the check for the if statement, the judgement will be centralized!!!
//     _onlySelectedVerifier(evidenceIpfsHash, msg.sender);
//     StructDefinition.VSkillUserEvidence[]
//         memory userEvidences = s_addressToEvidences[user];
//     uint256 length = userEvidences.length;
//     uint256 currentEvidenceIndex;
//     for (uint256 i = 0; i < length; i++) {
//         if (
//             keccak256(
//                 abi.encodePacked(userEvidences[i].evidenceIpfsHash)
//             ) == keccak256(abi.encodePacked(evidenceIpfsHash))
//         ) {
//             currentEvidenceIndex = i;
//             break;
//         }
//     }

//     s_addressToEvidences[user][currentEvidenceIndex].feedbackIpfsHash.push(
//         feedbackIpfsHash
//     );

//     s_verifiers[s_addressToId[msg.sender] - 1].feedbackIpfsHash.push(
//         feedbackIpfsHash
//     );

//     emit FeedbackProvided(
//         StructDefinition.VerifierFeedbackProvidedEventParams({
//             verifierAddress: msg.sender,
//             user: user,
//             approved: approved,
//             feedbackIpfsHash: feedbackIpfsHash,
//             evidenceIpfsHash: evidenceIpfsHash
//         })
//     );

//     // @written audit-info separate the rest of the function into another function, this one is too long
//     if (approved) {
//         s_evidenceIpfsHashToItsInfo[evidenceIpfsHash]
//             .statusApproveOrNot
//             .push(true);
//         emit EvidenceToStatusApproveOrNotUpdated(evidenceIpfsHash, true);

//         s_evidenceIpfsHashToItsInfo[evidenceIpfsHash]
//             .allSelectedVerifiersToFeedbackStatus[msg.sender] = true;
//         emit EvidenceToAllSelectedVerifiersToFeedbackStatusUpdated(
//             msg.sender,
//             evidenceIpfsHash,
//             true
//         );
//     } else {
//         s_evidenceIpfsHashToItsInfo[evidenceIpfsHash]
//             .statusApproveOrNot
//             .push(false);
//         emit EvidenceToStatusApproveOrNotUpdated(evidenceIpfsHash, false);

//         s_evidenceIpfsHashToItsInfo[evidenceIpfsHash]
//             .allSelectedVerifiersToFeedbackStatus[msg.sender] = false;
//         emit EvidenceToAllSelectedVerifiersToFeedbackStatusUpdated(
//             msg.sender,
//             evidenceIpfsHash,
//             false
//         );
//     }

//     // get all the verifiers who provide feedback and call the function to earn rewards or get penalized

//     // what if the evidenceIpfsHash is reassigned to other verifiers? The statusApproveOrNot length is reseted or not???
//     // hold on, the check for the if statement will be passed if the same verifier just call multiple times of this function
//     // And it will trigger the _earnRewardsOrGetPenalized function, any impact??
//     // Yeah, the verifier can call multiple times of this function, and the verifier will be rewarded or penalized multiple times
//     if (
//         s_evidenceIpfsHashToItsInfo[evidenceIpfsHash]
//             .statusApproveOrNot
//             .length < NUM_WORDS
//     ) {
//         return;
//     } else {
//         address[] memory allSelectedVerifiers = s_evidenceIpfsHashToItsInfo[
//             evidenceIpfsHash
//         ].selectedVerifiers;
//         uint256 allSelectedVerifiersLength = allSelectedVerifiers.length;
//         StructDefinition.VSkillUserSubmissionStatus evidenceStatus = _updateEvidenceStatus(
//                 evidenceIpfsHash,
//                 user
//             );

//         // @written audit-high the statusApproveOrNot array will call the .pop() function while empty with this setup of allSelectedVerifiersLength
//         // when the evidence is different opinion for more than once.
//         for (uint256 i = 0; i < allSelectedVerifiersLength; i++) {
//             _earnRewardsOrGetPenalized(
//                 evidenceIpfsHash,
//                 allSelectedVerifiers[i],
//                 evidenceStatus
//             );
//         }
//     }
// }

// Will be handled in Relayer contract
// function _earnRewardsOrGetPenalized(
//     string memory evidenceIpfsHash,
//     address verifierAddress,
//     StructDefinition.VSkillUserSubmissionStatus evidenceStatus
// ) internal {
//     if (
//         evidenceStatus ==
//         StructDefinition.VSkillUserSubmissionStatus.INREVIEW
//     ) {
//         revert Verifier__EvidenceStillInReview();
//     } else if (
//         evidenceStatus ==
//         StructDefinition.VSkillUserSubmissionStatus.APPROVED
//     ) {
//         bool status = s_evidenceIpfsHashToItsInfo[evidenceIpfsHash]
//             .allSelectedVerifiersToFeedbackStatus[verifierAddress];
//         if (status) {
//             _rewardVerifiers(verifierAddress);
//         } else {
//             _penalizeVerifiers(verifierAddress);
//         }
//     } else if (
//         evidenceStatus ==
//         StructDefinition.VSkillUserSubmissionStatus.REJECTED
//     ) {
//         bool status = s_evidenceIpfsHashToItsInfo[evidenceIpfsHash]
//             .allSelectedVerifiersToFeedbackStatus[verifierAddress];
//         if (status) {
//             _penalizeVerifiers(verifierAddress);
//         } else {
//             _rewardVerifiers(verifierAddress);
//         }
//     }
//     // DIFFERENTOPINION
//     else {
//         // first wait until this evidence finally gets approved or rejected
//         // then penalize or reward the verifiers
//         // If different opinion, the verifier need to delete the status of the feedback first, but we still have a copy of the allSelectedVerifiersToFeedbackStatus

//         // why only pop once? The verifier can provide feedback multiple times...
//         // because in the provideFeedback function, there is the for loop to pop this array

//         // @written audit-high if one verifier provides feedback for three times, the statusApproveOrNot array will have three elements, like all trues
//         // Then once the second verifier provide a false feedback, it will trigger the different opinion
//         // And the statusApproveOrNot array will be popped. But there are two more elements in the array and may violate the logic
//         s_evidenceIpfsHashToItsInfo[evidenceIpfsHash]
//             .statusApproveOrNot
//             .pop();

//         return;
//     }
// }

// function _rewardVerifiers(address verifiersAddress) internal {
//     uint256 currentReputation = s_verifiers[
//         s_addressToId[verifiersAddress] - 1
//     ].reputation;

//     if (currentReputation < HIGHEST_REPUTATION) {
//         s_verifiers[s_addressToId[verifiersAddress] - 1].reputation++;

//         emit VerifierReputationUpdated(
//             verifiersAddress,
//             s_verifiers[s_addressToId[verifiersAddress] - 1].reputation - 1,
//             s_verifiers[s_addressToId[verifiersAddress] - 1].reputation
//         );
//     }
//     // get the reward from the contract => what's the ratio of the reward?
//     // first, higher reputation leads to higher rewards
//     // second, the reward will depends on the bonus money in the staking contract
//     // Here is the algorithm to calculate the reward: reward = reputation / HIGHEST_REPUTATION / 20 * bonusMoneyInUsd
//     // 20 is that the verifier needs to stake about 20 USD to be a verifier => This is just a round number

//     // @written audit-info the first verifier may get more rewards than the last verifier, is this a issue?

//     // The reward is distributed one by one, so the BonusMoney will be decreased one by one
//     // That is to say, the protocol cannot be drained but only distribute less and less rewards

//     uint256 rewardAmountInEth = (super.getBonusMoneyInEth() *
//         currentReputation) /
//         HIGHEST_REPUTATION /
//         BONUS_DISTRIBUTION_NUMBER;

//     super._rewardVerifierInFormOfStake(verifiersAddress, rewardAmountInEth);
// }

// function _penalizeVerifiers(address verifiersAddress) internal {
//     if (
//         s_verifiers[s_addressToId[verifiersAddress] - 1].reputation >
//         LOWEST_REPUTATION
//     ) {
//         s_verifiers[s_addressToId[verifiersAddress] - 1].reputation--;

//         emit VerifierReputationUpdated(
//             verifiersAddress,
//             s_verifiers[s_addressToId[verifiersAddress] - 1].reputation + 1,
//             s_verifiers[s_addressToId[verifiersAddress] - 1].reputation
//         );
//     } else {
//         StructDefinition.StakingVerifier
//             memory verifierToBeRemoved = s_verifiers[
//                 s_addressToId[verifiersAddress] - 1
//             ];

//         // what if the user forget to withdraw the additional part over the stake?
//         // all the money will be collected by the staking contract... Is this a issue?
//         // @written audit-high user will lost all the money if they forget to withdraw the additional part over the stake
//         uint256 verifierStakedMoneyInEth = verifierToBeRemoved
//             .moneyStakedInEth;

//         // after remove the verifier, what about the money they stake?
//         // the money will be collected by the staking contract and will be used to reward the verifiers who provide feedback
//         // in staking contract we need to implement a function to distribute the money to the verifiers who provide feedback...

//         // This money will be locked in the staking contract and will be used to reward the verifiers who provide feedback
//         super._penalizeVerifierStakeToBonusMoney(
//             verifiersAddress,
//             verifierStakedMoneyInEth
//         );

//         super._removeVerifier(verifiersAddress);

//         emit LoseVerifier(verifierToBeRemoved.verifierAddress);
//     }
// }

// function _requestVerifiersSelection(
//     StructDefinition.VSkillUserEvidence memory ev
// ) public {
//     // Initiate the random number request
//     super.distributionRandomNumberForVerifiers(address(this), ev);
// }

// function _selectedVerifiersAddressCallback(
//     StructDefinition.VSkillUserEvidence memory ev,
//     uint256[] memory randomWords
// )
//     public
//     enoughNumberOfVerifiers(ev.skillDomain)
//     returns (address[] memory)
// {
//     address[] memory selectedVerifiers = new address[](NUM_WORDS);

//     (
//         address[] memory verifiersWithinSameDomain,
//         uint256 verifiersWithinSameDomainCount
//     ) = _verifiersWithinSameDomain(ev.skillDomain);

//     // One reputation score is equal to one chance of being selected, and the total number of chances is equal to the sum of all reputation scores
//     // One verifier can take multiple selected indices the same as the reputation score
//     // How to fulfill this?
//     // (1) Create an array of selected indices with the length of the sum of all reputation scores
//     // (2) Fill the array with the verifier's address based on the reputation score

//     // is this too gas expensive? The gas cost is high, is that possible to optimize?
//     // @written audit-gas as the number of verifiers increases, the gas cost will increase, the gas cost is high
//     // written @audit-medium DoS
//     uint256 totalReputationScore = 0;
//     for (uint256 i = 0; i < verifiersWithinSameDomainCount; i++) {
//         totalReputationScore += s_verifiers[
//             s_addressToId[verifiersWithinSameDomain[i]] - 1
//         ].reputation;
//     }

//     uint256[] memory selectedIndices = new uint256[](totalReputationScore);

//     uint256 selectedIndicesCount = 0;

//     for (uint256 i = 0; i < verifiersWithinSameDomainCount; i++) {
//         uint256 reputation = s_verifiers[
//             s_addressToId[verifiersWithinSameDomain[i]] - 1
//         ].reputation;
//         for (uint256 j = 0; j < reputation; j++) {
//             selectedIndices[selectedIndicesCount] = i;
//             selectedIndicesCount++;
//         }
//     }

//     for (uint256 i = 0; i < NUM_WORDS; i++) {
//         uint256 randomIndex = randomWords[i] % totalReputationScore;
//         selectedVerifiers[i] = verifiersWithinSameDomain[
//             selectedIndices[randomIndex]
//         ];
//     }

//     _updateSelectedVerifiersInfo(ev.evidenceIpfsHash, selectedVerifiers);

//     _assignEvidenceToSelectedVerifier(ev, selectedVerifiers);

//     return selectedVerifiers;
// }

// function _updateSelectedVerifiersInfo(
//     string memory evidenceIpfsHash,
//     address[] memory selectedVerifiers
// ) internal {
//     address[] memory prevSelectedVerifiers = s_evidenceIpfsHashToItsInfo[
//         evidenceIpfsHash
//     ].selectedVerifiers;

//     uint256 prevSelectedVerifiersLength = prevSelectedVerifiers.length;

//     if (prevSelectedVerifiersLength > 0) {
//         address[] memory prevAndCurrentSelectedVerifiers = new address[](
//             prevSelectedVerifiersLength + NUM_WORDS
//         );

//         for (uint256 i = 0; i < prevSelectedVerifiersLength; i++) {
//             prevAndCurrentSelectedVerifiers[i] = prevSelectedVerifiers[i];
//         }

//         for (uint256 i = 0; i < NUM_WORDS; i++) {
//             prevAndCurrentSelectedVerifiers[
//                 prevSelectedVerifiersLength + i
//             ] = selectedVerifiers[i];
//         }

//         s_evidenceIpfsHashToItsInfo[evidenceIpfsHash]
//             .selectedVerifiers = prevAndCurrentSelectedVerifiers;

//         emit EvidenceIpfsHashToSelectedVerifiersUpdated(
//             evidenceIpfsHash,
//             prevAndCurrentSelectedVerifiers
//         );
//     } else {
//         s_evidenceIpfsHashToItsInfo[evidenceIpfsHash]
//             .selectedVerifiers = selectedVerifiers;

//         emit EvidenceIpfsHashToSelectedVerifiersUpdated(
//             evidenceIpfsHash,
//             selectedVerifiers
//         );
//     }
// }

// function _assignEvidenceToSelectedVerifier(
//     StructDefinition.VSkillUserEvidence memory ev,
//     address[] memory selectedVerifiers
// ) internal {
//     for (uint256 i = 0; i < NUM_WORDS; i++) {
//         s_verifiers[s_addressToId[selectedVerifiers[i]] - 1]
//             .evidenceIpfsHash
//             .push(ev.evidenceIpfsHash);

//         s_verifiers[s_addressToId[selectedVerifiers[i]] - 1]
//             .evidenceSubmitters
//             .push(ev.submitter);

//         emit VerifierAssignedToEvidence(
//             selectedVerifiers[i],
//             ev.submitter,
//             ev.evidenceIpfsHash
//         );
//     }

//     // written @audit-medium the status of the evidence will not be updated
//     // which then will keep triggering the checkUpkeep function, causing the gas cost to increase
//     ev.status = StructDefinition.VSkillUserSubmissionStatus.INREVIEW;
//     emit EvidenceStatusUpdated(
//         ev.submitter,
//         ev.evidenceIpfsHash,
//         ev.status
//     );
// }

// function _onlySelectedVerifier(
//     string memory evidenceIpfsHash,
//     address verifierAddress
// ) internal view isVeifier {
//     // what if the verifier's evidenceIpfsHash array is empty?  It will revert
//     // what if the verifier's evidenceIpfsHash array is too large? It will consume more gas
//     // DoS? maybe this line is OK since the verifier's assigned evidence is usually not too large
//     uint256 length = s_verifiers[s_addressToId[verifierAddress] - 1]
//         .evidenceIpfsHash
//         .length;
//     for (uint256 i = 0; i < length; i++) {
//         // @written audit-gas each time compute the keccak256 of the evidenceIpfsHash, it will consume more gas
//         // it's better to use a memory variable to store the keccak256 of the evidenceIpfsHash
//         if (
//             keccak256(
//                 abi.encodePacked(
//                     s_verifiers[s_addressToId[verifierAddress] - 1]
//                         .evidenceIpfsHash[i]
//                 )
//             ) == keccak256(abi.encodePacked(evidenceIpfsHash))
//         ) {
//             // e if the verifier is the selected verifier, then can stop the loop
//             // no need to check the rest of the evidenceIpfsHash
//             return;
//         }
//     }
//     revert Verifier__NotSelectedVerifier();
// }

// function _waitForConfirmation(
//     string memory evidenceIpfsHash
// ) internal view {
//     bool[] memory status = s_evidenceIpfsHashToItsInfo[evidenceIpfsHash]
//         .statusApproveOrNot;
//     if (status.length < NUM_WORDS) {
//         revert Verifier__NotAllVerifiersProvidedFeedback();
//     }
// }

// function _updateEvidenceStatus(
//     string memory evidenceIpfsHash,
//     address user
// ) internal returns (StructDefinition.VSkillUserSubmissionStatus) {
//     _waitForConfirmation(evidenceIpfsHash);
//     bool[] memory status = s_evidenceIpfsHashToItsInfo[evidenceIpfsHash]
//         .statusApproveOrNot;
//     uint256 length = s_addressToEvidences[user].length;
//     uint256 currentEvidenceIndex;
//     for (uint256 i = 0; i < length; i++) {
//         // @written audit-gas store the keccak256 of the evidenceIpfsHash in a memory variable
//         if (
//             keccak256(
//                 abi.encodePacked(
//                     s_addressToEvidences[user][i].evidenceIpfsHash
//                 )
//             ) == keccak256(abi.encodePacked(evidenceIpfsHash))
//         ) {
//             currentEvidenceIndex = i;
//             break;
//         }
//     }

//     uint256 statusLength = status.length;

//     for (uint256 i = 1; i < statusLength; i++) {
//         if (status[i] != status[i - 1]) {
//             StructDefinition.VSkillUserEvidence
//                 storage ev = s_addressToEvidences[user][
//                     currentEvidenceIndex
//                 ];
//             ev.status = StructDefinition
//                 .VSkillUserSubmissionStatus
//                 .DIFFERENTOPINION;
//             emit EvidenceStatusUpdated(
//                 user,
//                 ev.evidenceIpfsHash,
//                 StructDefinition.VSkillUserSubmissionStatus.DIFFERENTOPINION
//             );
//             return
//                 StructDefinition
//                     .VSkillUserSubmissionStatus
//                     .DIFFERENTOPINION;
//         }
//     }

//     if (status[0]) {
//         StructDefinition.VSkillUserEvidence
//             storage ev = s_addressToEvidences[user][currentEvidenceIndex];
//         ev.status = StructDefinition.VSkillUserSubmissionStatus.APPROVED;
//         emit EvidenceStatusUpdated(
//             user,
//             ev.evidenceIpfsHash,
//             StructDefinition.VSkillUserSubmissionStatus.APPROVED
//         );
//         return StructDefinition.VSkillUserSubmissionStatus.APPROVED;
//     } else {
//         StructDefinition.VSkillUserEvidence
//             storage ev = s_addressToEvidences[user][currentEvidenceIndex];
//         ev.status = StructDefinition.VSkillUserSubmissionStatus.REJECTED;
//         emit EvidenceStatusUpdated(
//             user,
//             ev.evidenceIpfsHash,
//             StructDefinition.VSkillUserSubmissionStatus.REJECTED
//         );
//         return StructDefinition.VSkillUserSubmissionStatus.REJECTED;
//     }
// }
