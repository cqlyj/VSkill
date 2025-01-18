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

    error Verifier__NotSelectedVerifier();
    error Verifier__NotValidSkillDomain();
    error Verifier__SkillDomainAlreadyAdded(address verifierAddress);
    error Verifier__EvidenceDeadlinePassed();
    error Verifier__AlreadyProvidedFeedback();

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    // why declare the constant again here, in the Staking contract, we have already declared the constant
    // because constant is not inherited, so we need to declare it again
    uint256 private constant INITIAL_REPUTATION = 2;
    uint256 private constant LOWEST_REPUTATION = 0;
    uint256 private constant HIGHEST_REPUTATION = 10;
    uint256 private constant MAXIMUM_REWARD = 0.05 ether; // half of the staking amount

    AggregatorV3Interface private i_priceFeed;

    mapping(string skillDomain => address[] verifiersWithinSameDomain)
        private s_skillDomainToVerifiersWithinSameDomain;
    string[] private s_skillDomains;
    VSkillUser private immutable i_vSkillUser;
    mapping(uint256 requestId => address[] verifiersProvidedFeedback)
        private s_requestIdToVerifiersProvidedFeedback;
    uint256 private s_reward;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event VerifierSkillDomainUpdated();
    event FeedbackProvided(uint256 indexed requestId);
    event VerifierRewarded(
        address indexed verifier,
        uint256 reward,
        uint256 reputation
    );

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

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

        if (block.timestamp > i_vSkillUser.getRequestIdToDeadline(requestId)) {
            revert Verifier__EvidenceDeadlinePassed();
        }

        if (!_onlyProvideFeedbackOnce(requestId)) {
            revert Verifier__AlreadyProvidedFeedback();
        }
        // if not approve, no need to call the following function since the default value is false
        // how to differentiate from those provide false and those who do not provide feedback?
        // those who do not provide feedback will not in the array
        if (!approve) {
            s_requestIdToVerifiersProvidedFeedback[requestId].push(msg.sender);
            return;
        } else {
            // call the function to update the status of the evidence and set the feedback cid
            s_requestIdToVerifiersProvidedFeedback[requestId].push(msg.sender);
            i_vSkillUser.approveEvidenceStatus(requestId, feedbackCid);
        }

        emit FeedbackProvided(requestId);
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

    function withdrawReward() public {}

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

    // only the Relayer contract will be able to call this function
    function punishVerifier(address verifier) public {
        // take all the stake out and remove the verifier
        s_addressToIsVerifier[verifier] = false;
        s_verifierCount -= 1;
        // what about the stake money? The money will be collected by the staking contract and will be used to reward the verifiers who provide feedback
        // also those rewards will be used to reward the verifiers who provide feedback
        s_reward += super.getStakeEthAmount();
        s_reward += s_verifierToInfo[verifier].reward;
        delete s_verifierToInfo[verifier];

        emit LoseVerifier(verifier);
    }

    // only the Relayer contract will be able to call this function
    function rewardVerifier(address verifier) public {
        // 1. add reputation
        // 2. add reward
        // How to calculate the reward? => It depends on the reputation and the current contract reward balance
        // reward = (reputation / HIGHEST_REPUTATION)^2 * min(s_reward, MAXIMUM_REWARD)

        uint256 currentReputation = s_verifierToInfo[verifier].reputation;
        if (currentReputation < HIGHEST_REPUTATION) {
            s_verifierToInfo[verifier].reputation++;
        }
        uint256 rewardAmount = 0;
        if (s_reward > MAXIMUM_REWARD) {
            rewardAmount =
                (currentReputation * currentReputation * MAXIMUM_REWARD) /
                (HIGHEST_REPUTATION * HIGHEST_REPUTATION);
        } else {
            rewardAmount =
                (currentReputation * currentReputation * s_reward) /
                (HIGHEST_REPUTATION * HIGHEST_REPUTATION);
        }

        s_verifierToInfo[verifier].reward += rewardAmount;

        emit VerifierRewarded(verifier, rewardAmount, currentReputation);
    }

    /*//////////////////////////////////////////////////////////////
                     INTERNAL AND PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _onlyProvideFeedbackOnce(
        uint256 requestId
    ) internal view returns (bool) {
        for (
            uint256 i = 0;
            i < s_requestIdToVerifiersProvidedFeedback[requestId].length;
            i++
        ) {
            if (
                s_requestIdToVerifiersProvidedFeedback[requestId][i] ==
                msg.sender
            ) {
                return false;
            }
        }
        return true;
    }

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

    function _isSelectedVerifier(
        uint256 requestId
    ) internal view returns (bool) {
        uint256[] memory assignedRequestIds = s_verifierToInfo[msg.sender]
            .assignedRequestIds;
        // will the id length be too large?
        // No there is the maximum number they can be assigned
        // After reach this number, the verifier needs to withdraw the stake and re-stake to be assigned again
        // about 3000 evidences? But TBH this can usually cannot be a huge number since there are so many verifiers
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

    function getVerifiersProvidedFeedback(
        uint256 requestId
    ) external view returns (address[] memory) {
        return s_requestIdToVerifiersProvidedFeedback[requestId];
    }

    function getVerifiersProvidedFeedbackLength(
        uint256 requestId
    ) external view returns (uint256) {
        return s_requestIdToVerifiersProvidedFeedback[requestId].length;
    }
}

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
