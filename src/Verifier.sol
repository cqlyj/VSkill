// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {Staking} from "src/Staking.sol";
import {VSkillUser} from "src/VSkillUser.sol";
import {Ownable} from "@openzeppelin-contracts/contracts/access/Ownable.sol";

contract Verifier is Staking, Ownable {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error Verifier__NotSelectedVerifier();
    error Verifier__NotValidSkillDomain();
    error Verifier__SkillDomainAlreadyAdded(address verifierAddress);
    error Verifier__EvidenceDeadlinePassed();
    error Verifier__AlreadyProvidedFeedback();
    error Verifier__NotInitialized();
    error Verifier__AlreadyInitialized();
    error Verifier__NotRelayer();
    error Verifier__ExistUnhandledEvidence();

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    // why declare the constant again here, in the Staking contract, we have already declared the constant
    // because constant is not inherited, so we need to declare it again
    uint256 private constant LOWEST_REPUTATION = 0;
    uint256 private constant HIGHEST_REPUTATION = 10;
    uint256 private constant MAXIMUM_REWARD = 0.05 ether; // half of the staking amount

    // @audit-written unused variable
    AggregatorV3Interface private immutable i_priceFeed;

    mapping(string skillDomain => address[] verifiersWithinSameDomain)
        private s_skillDomainToVerifiersWithinSameDomain;
    string[] private s_skillDomains;
    VSkillUser private immutable i_vSkillUser;
    mapping(uint256 requestId => address[] verifiersProvidedFeedback)
        private s_requestIdToVerifiersProvidedFeedback;
    uint256 private s_reward;
    address private i_relayer;
    bool private s_initialized;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Verifier__VerifierSkillDomainUpdated();
    event Verifier__FeedbackProvided(uint256 indexed requestId);
    event Verifier__VerifierRewarded(
        address indexed verifier,
        uint256 reward,
        uint256 reputation
    );
    event Verifier__VerifierPenalized(
        address indexed verifier,
        uint256 reputation
    );
    // @audit-written unused event
    event Verifier__LoseVerifier(address indexed verifier);
    event Verifier__Initialized(address indexed relayer);
    event Verifier__RewardAdded(uint256 reward);

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyInitialized() {
        if (!s_initialized) {
            revert Verifier__NotInitialized();
        }
        _;
    }

    modifier onlyNotInitialized() {
        if (s_initialized) {
            revert Verifier__AlreadyInitialized();
        }
        _;
    }

    modifier onlyRelayer() {
        // The Relayer is the one who can add more skills
        if (msg.sender != i_relayer) {
            revert Verifier__NotRelayer();
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address priceFeed,
        string[] memory skillDomains,
        address vSkillUser
    ) Ownable(msg.sender) {
        i_priceFeed = AggregatorV3Interface(priceFeed);
        s_skillDomains = skillDomains;
        i_vSkillUser = VSkillUser(payable(vSkillUser));
        s_initialized = false;
    }

    function initializeRelayer(
        address _relayer
    ) external onlyOwner onlyNotInitialized {
        //slither-disable-next-line missing-zero-check
        i_relayer = _relayer;
        s_initialized = true;

        emit Verifier__Initialized(i_relayer);
    }

    /*//////////////////////////////////////////////////////////////
                     EXTERNAL AND PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function provideFeedback(
        uint256 requestId,
        string memory feedbackCid,
        bool approve
    ) public onlyVerifier onlyInitialized {
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
        s_verifierToInfo[msg.sender].unhandledRequestCount--;
        if (!approve) {
            s_requestIdToVerifiersProvidedFeedback[requestId].push(msg.sender);
            return;
        } else {
            // call the function to update the status of the evidence and set the feedback cid
            s_requestIdToVerifiersProvidedFeedback[requestId].push(msg.sender);
            i_vSkillUser.approveEvidenceStatus(requestId, feedbackCid);
        }

        emit Verifier__FeedbackProvided(requestId);
    }

    function addSkillDomain(
        string memory skillDomain
    ) public onlyVerifier onlyInitialized {
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

        emit Verifier__VerifierSkillDomainUpdated();
    }

    // This function will handle the skill domains and the stake
    function stake() public payable override onlyInitialized {
        super.stake();
    }

    function withdrawStakeAndLoseVerifier() public onlyInitialized {
        if (s_verifierToInfo[msg.sender].unhandledRequestCount > 0) {
            revert Verifier__ExistUnhandledEvidence();
        }
        super.withdrawStake();

        // @audit-written the verifier deletion is not complete!
        // we need also delete the verifier from the s_skillDomainToVerifiersWithinSameDomain and also decrease the length
        // Otherwise, even if the verifier is not a verifier anymore, they still can be selected as a verifier
    }

    function withdrawReward() public onlyInitialized {
        s_verifierToInfo[msg.sender].reward = 0;
        (bool success, ) = msg.sender.call{
            value: s_verifierToInfo[msg.sender].reward
        }("");
        if (!success) {
            revert Staking__WithdrawFailed();
        }

        emit Withdrawn(msg.sender, s_verifierToInfo[msg.sender].reward);
    }

    /*//////////////////////////////////////////////////////////////
                                 SETTER
    //////////////////////////////////////////////////////////////*/

    function setVerifierAssignedRequestIds(
        uint256 requestId,
        address verifier
    ) public onlyInitialized onlyRelayer {
        s_verifierToInfo[verifier].assignedRequestIds.push(requestId);
    }

    // punish is lose the verifier, not the same as penalize
    function punishVerifier(
        address verifier
    ) public onlyInitialized onlyRelayer {
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

    function rewardVerifier(
        address verifier
    ) public onlyInitialized onlyRelayer {
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

        emit Verifier__VerifierRewarded(
            verifier,
            rewardAmount,
            currentReputation + 1 <= HIGHEST_REPUTATION
                ? currentReputation + 1
                : HIGHEST_REPUTATION
        );
    }

    function penalizeVerifier(
        address verifier
    ) public onlyInitialized onlyRelayer {
        // 1. minus reputation
        // 2. check if the reputation is lower than the lowest reputation, if yes, remove the verifier

        if (s_verifierToInfo[verifier].reputation > LOWEST_REPUTATION) {
            s_verifierToInfo[verifier].reputation--;
            emit Verifier__VerifierPenalized(
                verifier,
                s_verifierToInfo[verifier].reputation
            );
        } else {
            punishVerifier(verifier);
        }
    }

    function addVerifierUnhandledRequestCount(
        address verifier
    ) public onlyInitialized onlyRelayer {
        s_verifierToInfo[verifier].unhandledRequestCount++;
    }

    function addReward(uint256 reward) public onlyInitialized onlyRelayer {
        s_reward += reward;

        emit Verifier__RewardAdded(reward);
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

    function getReward() external view returns (uint256) {
        return s_reward;
    }

    function getVerifierReward(
        address verifier
    ) external view returns (uint256) {
        return s_verifierToInfo[verifier].reward;
    }

    function getVerifierUnhandledRequestCount(
        address verifier
    ) external view returns (uint256) {
        return s_verifierToInfo[verifier].unhandledRequestCount;
    }

    function getHighestReputation() external pure returns (uint256) {
        return HIGHEST_REPUTATION;
    }

    // @audit-written lack getter function for verifiers to get their assigned request ids
}
