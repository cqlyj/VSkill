// SPDX-License-Identifier: MIT

// @audit-info floating pragma
pragma solidity ^0.8.24;

import {VSkillUser} from "../user/VSkillUser.sol";
import {Distribution} from "../oracle/Distribution.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";
import {StructDefinition} from "../utils/library/StructDefinition.sol";

/**
 * @title Verifier contract for verifiers to provide feedback on user's evidence.
 * @author Luo Yingjie
 * @notice This contract is the final contact which inherits from VSkillUser and Distribution contracts
 * @dev The verifier contract utilizes Chainlink Automation to assign evidence to verifiers and intergrates other contracts
 */
contract Verifier is VSkillUser, Distribution, AutomationCompatibleInterface {
    //////////////////////
    ///     errors     ///
    //////////////////////

    error Verifier__NotEnoughVerifiers(uint256 verifiersLength);
    error Verifier__NotSelectedVerifier();
    error Verifier__NotAllVerifiersProvidedFeedback();
    error Verifier__EvidenceStillInReview();

    /////////////////////////
    ///     libraries     ///
    /////////////////////////

    /**
     * @dev Using the StructDefinition library for the struct types
     */

    using StructDefinition for StructDefinition.VerifierConstructorParams;
    using StructDefinition for StructDefinition.VerifierEvidenceIpfsHashInfo;
    using StructDefinition for StructDefinition.VerifierFeedbackProvidedEventParams;
    using StructDefinition for StructDefinition.VSkillUserEvidence;
    using StructDefinition for StructDefinition.VSkillUserSubmissionStatus;
    using StructDefinition for StructDefinition.StakingVerifier;

    //////////////////////////////
    ///        Structs         ///
    //////////////////////////////

    // why declare the constant again here, in the Staking contract, we have already declared the constant
    // because constant is not inherited, so we need to declare it again
    uint256 private constant INITIAL_REPUTATION = 2;
    uint256 private constant LOWEST_REPUTATION = 0;
    uint256 private constant HIGHEST_REPUTATION = 10;
    uint256 private constant BONUS_DISTRIBUTION_NUMBER = 20;

    mapping(string => StructDefinition.VerifierEvidenceIpfsHashInfo)
        private s_evidenceIpfsHashToItsInfo;

    //////////////////////////////
    ///         Events         ///
    //////////////////////////////

    event VerifierSkillDomainUpdated(
        address indexed verifierAddress,
        string[] newSkillDomains
    );

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

    /////////////////////////
    ///     Modifiers     ///
    /////////////////////////

    /**
     * @dev Modifier to check if the address is a verifier
     */
    modifier isVeifier() {
        _isVerifier(msg.sender);
        _;
    }

    /**
     * @dev Modifier to check if the number of verifiers in the same domain is enough or not
     */
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
        s_priceFeed = AggregatorV3Interface(params.priceFeed);
    }

    ////////////////////////////////////////////
    /////  Chainlink Automation Functions  /////
    ////////////////////////////////////////////

    // https://docs.chain.link/chainlink-automation/reference/automation-interfaces
    // https://docs.chain.link/chainlink-automation/guides/flexible-upkeeps

    /**
     *
     * @return upkeepNeeded If the evidence status is `submitted` or `differentOpinion`, this function will return true, otherwise false
     * @return performData The evidence that needs to be assigned to the verifiers
     * @notice Once someone submits an evidence, the contract will automatically assign the evidence to the selected verifiers
     * @notice Those evidence status remains in `submitted` are the evidence that haven't been assigned to the verifiers
     * @notice Once the evidence is assigned to the verifiers, the status will be changed to `InReview`
     * @dev This is the Chainlink Automation function to check if the evidence needs to be assigned to the verifiers
     */
    function checkUpkeep(
        bytes calldata /* checkData */
    )
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        // if the evidence status is `submitted` or `differentOpinion`, this function will return true
        uint256 length = s_evidences.length;

        // @written audit-medium no bound check for the length and DoS attack is possible
        for (uint256 i = 0; i < length; i++) {
            if (
                s_evidences[i].status ==
                StructDefinition.VSkillUserSubmissionStatus.SUBMITTED ||
                s_evidences[i].status ==
                StructDefinition.VSkillUserSubmissionStatus.DIFFERENTOPINION
            ) {
                upkeepNeeded = true;
                performData = abi.encode(s_evidences[i]);
                return (upkeepNeeded, performData);
            }
        }
        upkeepNeeded = false;
        return (upkeepNeeded, "");
    }

    /**
     *
     * @param performData The evidence that needs to be assigned to the verifiers
     * @notice This function will assign the evidence to the selected verifiers
     * @dev This is the Chainlink Automation function to do further actions after the checkUpkeep function
     * @dev This function call the _requestVerifiersSelection function to assign the evidence to the verifiers
     */
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

    /**
     *
     * @param newSkillDomains The new skill domains that the verifier wants to update
     * @dev This function allows the verifier to update their skill domains
     * @dev Only the verifier can update their skill domains
     * @dev This function emits an event to notify the verifier that their skill domains have been updated
     */
    function updateSkillDomains(
        string[] memory newSkillDomains
    ) external isVeifier {
        // @written audit-low the verifier can update the skill domains to any value, no validation is done
        s_verifiers[s_addressToId[msg.sender] - 1]
            .skillDomains = newSkillDomains;
        emit VerifierSkillDomainUpdated(msg.sender, newSkillDomains);
    }

    /**
     *
     * @param feedbackIpfsHash The feedback IPFS hash that the verifier wants to provide
     * @param evidenceIpfsHash The evidence IPFS hash that the verifier wants to provide feedback
     * @param user The user who submits the evidence
     * @param approved Whether the verifier approves the evidence or not
     * @dev This function allows the verifier to provide feedback on the user's evidence
     * @dev Only the selected verifier can provide feedback
     * @dev This function emits an event to notify the verifier that the feedback has been provided
     * @dev This function emits an event to notify the user that the evidence status has been updated
     * @dev This function will also do a check to see if all the selected verifiers have provided feedback
     * @dev If the length of the statusApproveOrNot is less than the number of selected verifiers, the function will return, else it will call the _earnRewardsOrGetPenalized function
     * @dev If all the selected verifiers have provided feedback, the function will call the _earnRewardsOrGetPenalized function to reward or penalize the verifiers
     * @dev If the evidence status is `differentOpinion`, the function will wait until the evidence finally gets approved or rejected
     */
    function provideFeedback(
        string memory feedbackIpfsHash,
        string memory evidenceIpfsHash,
        address user,
        bool approved
    ) external {
        // can the same verifier call multiple time of this function? Yes, the verifier can call multiple times
        // Any impact? The verifier will be rewarded or penalized multiple times
        // @written audit-high the verifier can call multiple times of this function and pass the check for the if statement, the judgement will be centralized!!!
        _onlySelectedVerifier(evidenceIpfsHash, msg.sender);
        StructDefinition.VSkillUserEvidence[]
            memory userEvidences = s_addressToEvidences[user];
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

        s_addressToEvidences[user][currentEvidenceIndex].feedbackIpfsHash.push(
            feedbackIpfsHash
        );

        s_verifiers[s_addressToId[msg.sender] - 1].feedbackIpfsHash.push(
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

        // @audit-info separate the rest of the function into another function, this one is too long
        if (approved) {
            s_evidenceIpfsHashToItsInfo[evidenceIpfsHash]
                .statusApproveOrNot
                .push(true);
            emit EvidenceToStatusApproveOrNotUpdated(evidenceIpfsHash, true);

            s_evidenceIpfsHashToItsInfo[evidenceIpfsHash]
                .allSelectedVerifiersToFeedbackStatus[msg.sender] = true;
            emit EvidenceToAllSelectedVerifiersToFeedbackStatusUpdated(
                msg.sender,
                evidenceIpfsHash,
                true
            );
        } else {
            s_evidenceIpfsHashToItsInfo[evidenceIpfsHash]
                .statusApproveOrNot
                .push(false);
            emit EvidenceToStatusApproveOrNotUpdated(evidenceIpfsHash, false);

            s_evidenceIpfsHashToItsInfo[evidenceIpfsHash]
                .allSelectedVerifiersToFeedbackStatus[msg.sender] = false;
            emit EvidenceToAllSelectedVerifiersToFeedbackStatusUpdated(
                msg.sender,
                evidenceIpfsHash,
                false
            );
        }

        // get all the verifiers who provide feedback and call the function to earn rewards or get penalized

        // what if the evidenceIpfsHash is reassigned to other verifiers? The statusApproveOrNot length is reseted or not???
        // hold on, the check for the if statement will be passed if the same verifier just call multiple times of this function
        // And it will trigger the _earnRewardsOrGetPenalized function, any impact??
        // Yeah, the verifier can call multiple times of this function, and the verifier will be rewarded or penalized multiple times
        if (
            s_evidenceIpfsHashToItsInfo[evidenceIpfsHash]
                .statusApproveOrNot
                .length < s_numWords
        ) {
            return;
        } else {
            address[] memory allSelectedVerifiers = s_evidenceIpfsHashToItsInfo[
                evidenceIpfsHash
            ].selectedVerifiers;
            uint256 allSelectedVerifiersLength = allSelectedVerifiers.length;
            StructDefinition.VSkillUserSubmissionStatus evidenceStatus = _updateEvidenceStatus(
                    evidenceIpfsHash,
                    user
                );
            for (uint256 i = 0; i < allSelectedVerifiersLength; i++) {
                _earnRewardsOrGetPenalized(
                    evidenceIpfsHash,
                    allSelectedVerifiers[i],
                    evidenceStatus
                );
            }
        }
    }

    ////////////////////////////////
    ///     Public Functions     ///
    ////////////////////////////////

    /**
     * @dev The following functions are the public functions that are inherited from the Staking contract
     */
    function stake() public payable override {
        super.stake();
    }

    function withdrawStake(uint256 amountToWithdrawInEth) public override {
        super.withdrawStake(amountToWithdrawInEth);
    }

    /**
     *
     * @dev The follwoing functions are the public functions that are inherited from the VSkillUser contract
     */
    function submitEvidence(
        string memory evidenceIpfsHash,
        string memory skillDomain
    ) public payable override {
        super.submitEvidence(evidenceIpfsHash, skillDomain);
    }

    function checkFeedbackOfEvidence(
        uint256 indexOfUserEvidence
    ) public view override returns (string[] memory) {
        return super.checkFeedbackOfEvidence(indexOfUserEvidence);
    }

    function earnUserNft(
        StructDefinition.VSkillUserEvidence memory _evidence
    ) public override {
        super.earnUserNft(_evidence);
    }

    function changeSubmissionFee(
        uint256 newFeeInUsd
    ) public override onlyOwner {
        super.changeSubmissionFee(newFeeInUsd);
    }

    function addMoreSkills(
        string memory skillDomain,
        string memory newNftImageUri
    ) public override onlyOwner {
        super.addMoreSkills(skillDomain, newNftImageUri);
    }

    //////////////////////////////////
    /////   Internal Functions   /////
    //////////////////////////////////

    /**
     *
     * @param evidenceIpfsHash The evidence IPFS hash that the verifier provides feedback
     * @param verifierAddress The verifier address that provides feedback
     * @param evidenceStatus The current status of the evidence
     * @dev This function will reward or penalize the verifiers based on the feedback they provide
     * @dev If the evidence status is `inReview`, the function will revert
     * @dev If the evidence status is `approved` or `rejected`, the function will reward those verifiers who provide the same feedback as the evidence status
     * @dev If the evidence status is `differentOpinion`, the function will wait until the evidence finally gets approved or rejected
     */
    function _earnRewardsOrGetPenalized(
        string memory evidenceIpfsHash,
        address verifierAddress,
        StructDefinition.VSkillUserSubmissionStatus evidenceStatus
    ) internal {
        // @audit-gas since this function is only called by the provideFeedback function, the evidenceIpfsHash is already checked
        _onlySelectedVerifier(evidenceIpfsHash, verifierAddress);

        if (
            evidenceStatus ==
            StructDefinition.VSkillUserSubmissionStatus.INREVIEW
        ) {
            revert Verifier__EvidenceStillInReview();
        } else if (
            evidenceStatus ==
            StructDefinition.VSkillUserSubmissionStatus.APPROVED
        ) {
            bool status = s_evidenceIpfsHashToItsInfo[evidenceIpfsHash]
                .allSelectedVerifiersToFeedbackStatus[verifierAddress];
            if (status) {
                _rewardVerifiers(verifierAddress);
            } else {
                _penalizeVerifiers(verifierAddress);
            }
        } else if (
            evidenceStatus ==
            StructDefinition.VSkillUserSubmissionStatus.REJECTED
        ) {
            bool status = s_evidenceIpfsHashToItsInfo[evidenceIpfsHash]
                .allSelectedVerifiersToFeedbackStatus[verifierAddress];
            if (status) {
                _penalizeVerifiers(verifierAddress);
            } else {
                _rewardVerifiers(verifierAddress);
            }
        }
        // DIFFERENTOPINION
        else {
            // first wait until this evidence finally gets approved or rejected
            // then penalize or reward the verifiers
            // If different opinion, the verifier need to delete the status of the feedback first, but we still have a copy of the allSelectedVerifiersToFeedbackStatus

            // why only pop once? The verifier can provide feedback multiple times...

            // @audit-high the statusApproveOrNot array is not deleted, it only pops once
            s_evidenceIpfsHashToItsInfo[evidenceIpfsHash]
                .statusApproveOrNot
                .pop();

            return;
        }
    }

    /**
     *
     * @param verifiersAddress The address of the verifier that needs to be rewarded
     * @dev This function will reward the verifiers.
     * @dev The reward will be distributed in the form of stake
     * @dev The reward consists of two parts:
     * @dev (1) The reputation of the verifier
     * @dev (2) The bonus money in the staking contract
     * @dev The reward will be calculated based on the following algorithm:
     * @dev reward = reputation / HIGHEST_REPUTATION / BONUS_DISTRIBUTION_NUMBER * bonusMoneyInUsd
     * @dev The reputation will be increased by 1 if the current reputation is less than the highest reputation
     * @dev Then those bonus money will be stored in the verifier struct so that verifiers can withdraw the bonus money => Pull over push
     */
    function _rewardVerifiers(address verifiersAddress) internal {
        uint256 currentReputation = s_verifiers[
            s_addressToId[verifiersAddress] - 1
        ].reputation;

        if (currentReputation < HIGHEST_REPUTATION) {
            s_verifiers[s_addressToId[verifiersAddress] - 1].reputation++;

            emit VerifierReputationUpdated(
                verifiersAddress,
                s_verifiers[s_addressToId[verifiersAddress] - 1].reputation - 1,
                s_verifiers[s_addressToId[verifiersAddress] - 1].reputation
            );
        }
        // get the reward from the contract => what's the ratio of the reward?
        // first, higher reputation leads to higher rewards
        // second, the reward will depends on the bonus money in the staking contract
        // Here is the algorithm to calculate the reward: reward = reputation / HIGHEST_REPUTATION / 20 * bonusMoneyInUsd
        // 20 is that the verifier needs to stake about 20 USD to be a verifier => This is just a round number

        // is that possible the protocol will be out of money?
        // let's say one evidence is submitted, the evidence is differentOpinion for multiple times which exceeds 20 times
        // the BonusMoney is made up of the user submission fee + verifier penalty + vulnerable reward
        // if for now no verifier is punished, and no vunerable reward, the bonus money is only made up of the user submission fee
        // so the super.getBonusMoneyInEth() will be the user submission fee
        // now I have a lot verifiers with the initial reputation 2, the reward will be x * 2 / 10 / 20, where x is the amount of the user submission fee
        // that is to say, if there are y verifiers who will get reward, the total reward will be y * x * 2 / 10 / 20 = y * x / 100
        // when will y * x / 100 > x? when y > 100, that is to say, if there are more than 100 verifiers who will get reward, the protocol will be out of money

        // @audit there is possibility that the protocol will be out of money if there are too many verifiers who will get reward
        uint256 rewardAmountInEth = (super.getBonusMoneyInEth() *
            currentReputation) /
            HIGHEST_REPUTATION /
            BONUS_DISTRIBUTION_NUMBER;

        super._rewardVerifierInFormOfStake(verifiersAddress, rewardAmountInEth);
    }

    /**
     *
     * @param verifiersAddress The address of the verifier that needs to be penalized
     * @dev This function will penalize the verifiers.
     * @dev The penalty will be decrease the reputation of the verifiers if the current reputation is greater than the lowest reputation
     * @dev If the reputation is less than the lowest reputation, the verifier will be removed from the verifiers array and those stakes will be collected by the bonus money in the staking contract
     * @dev In this way, it incentivizes the verifiers to provide feedback correctly since the more malicious feedback they provide, the more money they will lose while other verifiers will get more rewards
     */
    function _penalizeVerifiers(address verifiersAddress) internal {
        if (
            s_verifiers[s_addressToId[verifiersAddress] - 1].reputation >
            LOWEST_REPUTATION
        ) {
            s_verifiers[s_addressToId[verifiersAddress] - 1].reputation--;

            emit VerifierReputationUpdated(
                verifiersAddress,
                s_verifiers[s_addressToId[verifiersAddress] - 1].reputation + 1,
                s_verifiers[s_addressToId[verifiersAddress] - 1].reputation
            );
        } else {
            StructDefinition.StakingVerifier
                memory verifierToBeRemoved = s_verifiers[
                    s_addressToId[verifiersAddress] - 1
                ];

            // what if the user forget to withdraw the additional part over the stake?
            // all the money will be collected by the staking contract... Is this a issue?
            // @audit user will lost all the money if they forget to withdraw the additional part over the stake
            uint256 verifierStakedMoneyInEth = verifierToBeRemoved
                .moneyStakedInEth;

            // after remove the verifier, what about the money they stake?
            // the money will be collected by the staking contract and will be used to reward the verifiers who provide feedback
            // in staking contract we need to implement a function to distribute the money to the verifiers who provide feedback...

            // This money will be locked in the staking contract and will be used to reward the verifiers who provide feedback
            super._penalizeVerifierStakeToBonusMoney(
                verifiersAddress,
                verifierStakedMoneyInEth
            );

            super._removeVerifier(verifiersAddress);

            emit LoseVerifier(verifierToBeRemoved.verifierAddress);
        }
    }

    /**
     *
     * @param verifierOrUser The address of the verifier or the user
     * @dev This function will check if the address is a verifier or not
     * @dev If the address is not a verifier, the function will revert
     */
    function _isVerifier(address verifierOrUser) internal view {
        if (s_addressToId[verifierOrUser] == 0) {
            revert Staking__NotVerifier();
        }
    }

    /**
     *
     * @param skillDomain The skill domain to be checked
     * @return verifiersWithinSameDomain The verifiers within the same domain
     * @return count The number of verifiers within the same domain
     * @dev This function will return the verifiers within the same domain
     */
    function _verifiersWithinSameDomain(
        string memory skillDomain
    ) public view returns (address[] memory, uint256 count) {
        uint256 length = s_verifiers.length;

        uint256 verifiersWithinSameDomainCount = 0;

        // @audit DoS
        for (uint256 i = 0; i < length; i++) {
            if (s_verifiers[i].skillDomains.length > 0) {
                uint256 skillDomainLength = s_verifiers[i].skillDomains.length;
                for (uint256 j = 0; j < skillDomainLength; j++) {
                    if (
                        keccak256(
                            abi.encodePacked(s_verifiers[i].skillDomains[j])
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

        // @audit DoS
        for (uint256 i = 0; i < length; i++) {
            if (s_verifiers[i].skillDomains.length > 0) {
                uint256 skillDomainLength = s_verifiers[i].skillDomains.length;
                for (uint256 j = 0; j < skillDomainLength; j++) {
                    if (
                        keccak256(
                            abi.encodePacked(s_verifiers[i].skillDomains[j])
                        ) == keccak256(abi.encodePacked(skillDomain))
                    ) {
                        verifiersWithinSameDomain[
                            verifiersWithinSameDomainIndex
                        ] = s_verifiers[i].verifierAddress;
                        verifiersWithinSameDomainIndex++;
                        break; // No need to check other domains for this verifier
                    }
                }
            }
        }

        return (verifiersWithinSameDomain, verifiersWithinSameDomainCount);
    }

    /**
     *
     * @param skillDomain The skill domain to be checked
     * @dev This function will check if the number of verifiers within the same domain is enough or not
     * @dev If the number of verifiers within the same domain is less than the number of words, the function will revert
     * @dev The number of words is the number of verifiers that required to provide feedback on the user's evidence
     */
    function _enoughNumberOfVerifiers(string memory skillDomain) public view {
        (, uint256 verifiersWithinSameDomainCount) = _verifiersWithinSameDomain(
            skillDomain
        );
        if (verifiersWithinSameDomainCount < s_numWords) {
            revert Verifier__NotEnoughVerifiers(verifiersWithinSameDomainCount);
        }
    }

    /**
     *
     * @param ev The evidence that needs to be assigned to the verifiers
     * @dev This function will assign the evidence to the selected verifiers
     * @dev This function will call the distributionRandomNumberForVerifiers function which then call the _selectedVerifiersAddressCallback function
     */

    // this is public, so anyone can call this function...
    // let's say someone not paying any money and directly call this function, then it will call the distributionRandomNumberForVerifiers function
    // This is indeed a problem! The user can call this function instead of calling that submitEvidence function
    // calling this function will just distribute the evidence to verifiers but the evidence will not be in the evidence array.

    // any impact if the user call this function directly? How the verifier verify the evidence?
    // this should be handled in the web interface, the verifier will get notified when new evidence is distributed to them
    // @audit the user can call this function directly and the evidence will be assigned to the verifiers without being in the evidence array
    function _requestVerifiersSelection(
        StructDefinition.VSkillUserEvidence memory ev
    ) public {
        // Initiate the random number request
        super.distributionRandomNumberForVerifiers(address(this), ev);
    }

    /**
     *
     * @param ev The evidence that needs to be assigned to the verifiers
     * @param randomWords The random words that are generated by the Chainlink VRF
     * @return selectedVerifiers The selected verifiers
     * @dev This function will select the verifiers based on the random words
     * @dev This is the callback function in the Distribution to be called after the random words are generated
     * @dev The selected verifiers will be stored in the evidenceIpfsHashToItsInfo mapping
     * @dev The evidence status will be updated to `InReview`
     * @dev The selected verifiers will be assigned to the evidence
     * @dev This function will call the _updateSelectedVerifiersInfo function to update the selected verifiers info
     * @dev This function will call the _assignEvidenceToSelectedVerifier function to assign the evidence to the selected verifiers
     * @dev This function will emit an event to notify the selected verifiers
     */
    function _selectedVerifiersAddressCallback(
        StructDefinition.VSkillUserEvidence memory ev,
        uint256[] memory randomWords
    )
        public
        enoughNumberOfVerifiers(ev.skillDomain)
        returns (address[] memory)
    {
        address[] memory selectedVerifiers = new address[](s_numWords);

        (
            address[] memory verifiersWithinSameDomain,
            uint256 verifiersWithinSameDomainCount
        ) = _verifiersWithinSameDomain(ev.skillDomain);

        // One reputation score is equal to one chance of being selected, and the total number of chances is equal to the sum of all reputation scores
        // One verifier can take multiple selected indices the same as the reputation score
        // How to fulfill this?
        // (1) Create an array of selected indices with the length of the sum of all reputation scores
        // (2) Fill the array with the verifier's address based on the reputation score

        // is this too gas expensive? The gas cost is high, is that possible to optimize?
        // @audit-gas as the number of verifiers increases, the gas cost will increase, the gas cost is high
        // @audit DoS
        uint256 totalReputationScore = 0;
        for (uint256 i = 0; i < verifiersWithinSameDomainCount; i++) {
            totalReputationScore += s_verifiers[
                s_addressToId[verifiersWithinSameDomain[i]] - 1
            ].reputation;
        }

        uint256[] memory selectedIndices = new uint256[](totalReputationScore);

        uint256 selectedIndicesCount = 0;

        for (uint256 i = 0; i < verifiersWithinSameDomainCount; i++) {
            uint256 reputation = s_verifiers[
                s_addressToId[verifiersWithinSameDomain[i]] - 1
            ].reputation;
            for (uint256 j = 0; j < reputation; j++) {
                selectedIndices[selectedIndicesCount] = i;
                selectedIndicesCount++;
            }
        }

        for (uint256 i = 0; i < s_numWords; i++) {
            uint256 randomIndex = randomWords[i] % totalReputationScore;
            selectedVerifiers[i] = verifiersWithinSameDomain[
                selectedIndices[randomIndex]
            ];
        }

        _updateSelectedVerifiersInfo(ev.evidenceIpfsHash, selectedVerifiers);

        _assignEvidenceToSelectedVerifier(ev, selectedVerifiers);

        return selectedVerifiers;
    }

    /**
     *
     * @param evidenceIpfsHash The evidence IPFS hash that needs to be updated
     * @param selectedVerifiers The array of selected verifiers
     * @dev This function will update the selected verifiers info
     * @dev The selected verifiers will be stored in the evidenceIpfsHashToItsInfo mapping
     * @dev This function will emit an event to notify the selected verifiers
     * @dev If the previous selected verifiers length is greater than 0, that is to say the evidence has been assigned to the verifiers before
     * @dev The current selected verifiers will be appended to the previous selected verifiers
     * @dev If the previous selected verifiers length is 0, that is to say the evidence hasn't been assigned to the verifiers before
     * @dev The current selected verifiers will be stored in the evidenceIpfsHashToItsInfo mapping
     */
    function _updateSelectedVerifiersInfo(
        string memory evidenceIpfsHash,
        address[] memory selectedVerifiers
    ) internal {
        address[] memory prevSelectedVerifiers = s_evidenceIpfsHashToItsInfo[
            evidenceIpfsHash
        ].selectedVerifiers;

        uint256 prevSelectedVerifiersLength = prevSelectedVerifiers.length;

        if (prevSelectedVerifiersLength > 0) {
            address[] memory prevAndCurrentSelectedVerifiers = new address[](
                prevSelectedVerifiersLength + s_numWords
            );

            for (uint256 i = 0; i < prevSelectedVerifiersLength; i++) {
                prevAndCurrentSelectedVerifiers[i] = prevSelectedVerifiers[i];
            }

            for (uint256 i = 0; i < s_numWords; i++) {
                prevAndCurrentSelectedVerifiers[
                    prevSelectedVerifiersLength + i
                ] = selectedVerifiers[i];
            }

            s_evidenceIpfsHashToItsInfo[evidenceIpfsHash]
                .selectedVerifiers = prevAndCurrentSelectedVerifiers;

            emit EvidenceIpfsHashToSelectedVerifiersUpdated(
                evidenceIpfsHash,
                prevAndCurrentSelectedVerifiers
            );
        } else {
            s_evidenceIpfsHashToItsInfo[evidenceIpfsHash]
                .selectedVerifiers = selectedVerifiers;

            emit EvidenceIpfsHashToSelectedVerifiersUpdated(
                evidenceIpfsHash,
                selectedVerifiers
            );
        }
    }

    /**
     *
     * @param ev The evidence that needs to be assigned to the verifiers
     * @param selectedVerifiers The array of selected verifiers
     * @dev This function will update the verifier.evidenceIpfsHash and verifier.evidenceSubmitters
     * @dev The evidence status will be updated to `InReview`
     * @dev This function will emit an event to notify the selected verifiers
     */
    function _assignEvidenceToSelectedVerifier(
        StructDefinition.VSkillUserEvidence memory ev,
        address[] memory selectedVerifiers
    ) internal {
        for (uint256 i = 0; i < s_numWords; i++) {
            s_verifiers[s_addressToId[selectedVerifiers[i]] - 1]
                .evidenceIpfsHash
                .push(ev.evidenceIpfsHash);

            s_verifiers[s_addressToId[selectedVerifiers[i]] - 1]
                .evidenceSubmitters
                .push(ev.submitter);

            emit VerifierAssignedToEvidence(
                selectedVerifiers[i],
                ev.submitter,
                ev.evidenceIpfsHash
            );
        }

        // @audit the status of the evidence will not be updated
        ev.status = StructDefinition.VSkillUserSubmissionStatus.INREVIEW;
        emit EvidenceStatusUpdated(
            ev.submitter,
            ev.evidenceIpfsHash,
            ev.status
        );
    }

    /**
     *
     * @param evidenceIpfsHash The evidence IPFS hash that the verifier provides feedback
     * @param verifierAddress The address of the verifier that provides feedback
     * @dev This function will check if the verifier is the selected verifier
     * @dev If the verifier is not the selected verifier, the function will revert
     */
    function _onlySelectedVerifier(
        string memory evidenceIpfsHash,
        address verifierAddress
    ) internal view isVeifier {
        // what if the verifier's evidenceIpfsHash array is empty?  It will revert
        // what if the verifier's evidenceIpfsHash array is too large? It will consume more gas
        // DoS? maybe this line is OK since the verifier's assigned evidence is usually not too large
        uint256 length = s_verifiers[s_addressToId[verifierAddress] - 1]
            .evidenceIpfsHash
            .length;
        for (uint256 i = 0; i < length; i++) {
            // @audit-gas each time compute the keccak256 of the evidenceIpfsHash, it will consume more gas
            // it's better to use a memory variable to store the keccak256 of the evidenceIpfsHash
            if (
                keccak256(
                    abi.encodePacked(
                        s_verifiers[s_addressToId[verifierAddress] - 1]
                            .evidenceIpfsHash[i]
                    )
                ) == keccak256(abi.encodePacked(evidenceIpfsHash))
            ) {
                // e if the verifier is the selected verifier, then can stop the loop
                // no need to check the rest of the evidenceIpfsHash
                return;
            }
        }
        revert Verifier__NotSelectedVerifier();
    }

    /**
     *
     * @param evidenceIpfsHash The evidence Ipfs hash that the corresponding evidence to be checked
     * @dev This function will check if all the verifiers have provided feedback
     * @dev If the length of the statusApproveOrNot is less than the number of selected verifiers, the function will revert, that is to say not all the verifiers have provided feedback
     */
    function _waitForConfirmation(
        string memory evidenceIpfsHash
    ) internal view {
        bool[] memory status = s_evidenceIpfsHashToItsInfo[evidenceIpfsHash]
            .statusApproveOrNot;
        if (status.length < s_numWords) {
            revert Verifier__NotAllVerifiersProvidedFeedback();
        }
    }

    /**
     *
     * @param evidenceIpfsHash The evidence IPFS hash that needs to be updated
     * @param user The user who submits the evidence
     * @return StructDefinition.VSkillUserSubmissionStatus The status after modification of the evidence
     * @dev This function will update the status of the evidence
     * @dev If all three verifiers approve or reject the evidence, the status of the evidence will be updated
     * @dev Anyone of them gives a different feedback, the status be differentOpinion
     * @dev And the evidence will be assigned again randomly to three verifiers(may be the same verifiers => it's possible)
     * @dev The process will be repeated until all three verifiers give the same feedback
     * @dev This function will emit an event to notify the user that the evidence status has been updated
     * @dev This function will return the status of the evidence
     * @dev If the status is `approved`, the function will return `APPROVED`
     * @dev If the status is `rejected`, the function will return `REJECTED`
     * @dev If the status is `differentOpinion`, the function will return `DIFFERENTOPINION`
     * @dev The status of the evidence will be updated in the evidenceIpfsHashToItsInfo mapping
     * @dev The status of the evidence will be updated in the addressToEvidences mapping
     */
    function _updateEvidenceStatus(
        string memory evidenceIpfsHash,
        address user
    ) internal returns (StructDefinition.VSkillUserSubmissionStatus) {
        _waitForConfirmation(evidenceIpfsHash);
        bool[] memory status = s_evidenceIpfsHashToItsInfo[evidenceIpfsHash]
            .statusApproveOrNot;
        uint256 length = s_addressToEvidences[user].length;
        uint256 currentEvidenceIndex;
        for (uint256 i = 0; i < length; i++) {
            // @audit-gas store the keccak256 of the evidenceIpfsHash in a memory variable
            if (
                keccak256(
                    abi.encodePacked(
                        s_addressToEvidences[user][i].evidenceIpfsHash
                    )
                ) == keccak256(abi.encodePacked(evidenceIpfsHash))
            ) {
                currentEvidenceIndex = i;
                break;
            }
        }

        uint256 statusLength = status.length;

        for (uint256 i = 1; i < statusLength; i++) {
            if (status[i] != status[i - 1]) {
                StructDefinition.VSkillUserEvidence
                    storage ev = s_addressToEvidences[user][
                        currentEvidenceIndex
                    ];
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
            StructDefinition.VSkillUserEvidence
                storage ev = s_addressToEvidences[user][currentEvidenceIndex];
            ev.status = StructDefinition.VSkillUserSubmissionStatus.APPROVED;
            emit EvidenceStatusUpdated(
                user,
                ev.evidenceIpfsHash,
                StructDefinition.VSkillUserSubmissionStatus.APPROVED
            );
            return StructDefinition.VSkillUserSubmissionStatus.APPROVED;
        } else {
            StructDefinition.VSkillUserEvidence
                storage ev = s_addressToEvidences[user][currentEvidenceIndex];
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
}
