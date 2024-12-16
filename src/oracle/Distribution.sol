// SPDX-License-Identifier: MIT

// @written audit-info floating pragma
pragma solidity 0.8.26;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import {StructDefinition} from "../utils/library/StructDefinition.sol";
import {IVerifier} from "../utils/interface/IVerifier.sol";

/**
 * @title Distribution contract for generating random numbers for verifiers
 * @author Luo Yingjie
 * @notice This contract is for generating random numbers for verifiers
 * @dev The random number is generated by Chainlink VRF, scripts alreadly developed, don't forget to update the subscriptionId in HelperConfig.s.sol
 */

// not really, we should use the latest version of VRF
// @written audit-info we should use the VRF v2.5
contract Distribution is VRFConsumerBaseV2 {
    /**
     * @dev StrcutDefinition is used for defining the struct of DistributionVerifierRequestContext and VSkillUserEvidence
     */
    using StructDefinition for StructDefinition.DistributionVerifierRequestContext;
    using StructDefinition for StructDefinition.VSkillUserEvidence;

    /**
     * @dev Those variables are used for Chainlink VRF
     */
    uint64 immutable i_subscriptionId;
    VRFCoordinatorV2Interface immutable i_vrfCoordinator;
    bytes32 immutable i_keyHash;
    uint32 immutable i_callbackGasLimit;
    uint16 constant REQUEST_CONFIRMATIONS = 3;
    uint32 constant NUM_WORDS = 3;

    uint256 s_requestId;

    uint256[] private s_randomWords;
    mapping(uint256 => StructDefinition.DistributionVerifierRequestContext)
        private s_requestIdToContext;

    event RequestIdToContextUpdated(
        uint256 indexed requestId,
        StructDefinition.DistributionVerifierRequestContext context
    );

    constructor(
        uint64 _subscriptionId,
        address _vrfCoordinator,
        bytes32 _keyHash,
        uint32 _callbackGasLimit
    ) VRFConsumerBaseV2(_vrfCoordinator) {
        i_subscriptionId = _subscriptionId;
        i_vrfCoordinator = VRFCoordinatorV2Interface(_vrfCoordinator);
        i_keyHash = _keyHash;
        i_callbackGasLimit = _callbackGasLimit;
    }

    /**
     *
     * @param requester The address of the requester, here is the `Verifier` conrtact
     * @param ev The evidence of the user, which is to be distributed to the verifiers
     */

    // can anyone call this function to distribute random numbers? yes
    // yes indeed an issue, anyone can call this function to distribute evidence to verifiers without paying any fees
    // @written audit-high anyone can call this function and distribute random numbers to verifiers without paying any fees, and this will drain the Links from our subscription
    function distributionRandomNumberForVerifiers(
        address requester,
        StructDefinition.VSkillUserEvidence memory ev
    ) public {
        s_requestId = i_vrfCoordinator.requestRandomWords(
            i_keyHash,
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS
        );

        s_requestIdToContext[s_requestId] = StructDefinition
            .DistributionVerifierRequestContext(requester, ev);

        emit RequestIdToContextUpdated(
            s_requestId,
            s_requestIdToContext[s_requestId]
        );
    }

    ///////////////////////////////
    /////   Internal Functions ////
    ///////////////////////////////

    /**
     *
     * @param _randomWords The random words generated by Chainlink VRF for further processing
     * @dev This function is called by Chainlink VRF to fulfill the request of random numbers
     */
    function fulfillRandomWords(
        uint256 /*_requestId*/,
        uint256[] memory _randomWords
    ) internal override {
        // why store random words in a state variable? Anyone can access this state variable? If they can see this random words, any impact?
        // not really, the random words are only used for the verifier contract
        // even if you know who the verifiers are, you can't do anything with the random words
        // that is you cannot assign the random words to yourself, so no impact
        s_randomWords = _randomWords;
        _processVerifiers(s_requestId);
    }

    /**
     *
     * @param _requestId The requestId of the Chainlink VRF
     * @dev This function will use the `VerifierInterface` to process the random words.
     */
    function _processVerifiers(uint256 _requestId) internal {
        StructDefinition.DistributionVerifierRequestContext
            memory context = s_requestIdToContext[_requestId];
        IVerifier(context.requester)._selectedVerifiersAddressCallback(
            context.ev,
            s_randomWords
        );
    }

    ///////////////////////////////
    /////   Getter Functions   ////
    ///////////////////////////////

    function getRandomWords() public view returns (uint256[] memory) {
        return s_randomWords;
    }

    function getRequestIdToContext(
        uint256 _requestId
    )
        public
        view
        returns (StructDefinition.DistributionVerifierRequestContext memory)
    {
        return s_requestIdToContext[_requestId];
    }

    function getSubscriptionId() public view returns (uint64) {
        return i_subscriptionId;
    }

    function getVrfCoordinator()
        public
        view
        returns (VRFCoordinatorV2Interface)
    {
        return i_vrfCoordinator;
    }

    function getKeyHash() public view returns (bytes32) {
        return i_keyHash;
    }

    function getCallbackGasLimit() public view returns (uint32) {
        return i_callbackGasLimit;
    }

    function getRequestConfirmations() public pure returns (uint16) {
        return REQUEST_CONFIRMATIONS;
    }
}
