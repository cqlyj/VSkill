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

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import {StructDefinition} from "../utils/library/StructDefinition.sol";
import {VerifierInterface} from "../utils/interface/VerifierInterface.sol";

contract Distribution is VRFConsumerBaseV2 {
    using StructDefinition for StructDefinition.DistributionVerifierRequestContext;
    using StructDefinition for StructDefinition.VSkillUserEvidence;

    uint64 subscriptionId;
    VRFCoordinatorV2Interface vrfCoordinator;
    bytes32 keyHash;
    uint32 callbackGasLimit;
    uint16 requestConfirmations = 3;
    uint32 numWords = 3;

    uint256 requestId;

    uint256[] private randomWords;
    mapping(uint256 => StructDefinition.DistributionVerifierRequestContext)
        private requestIdToContext;

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
        subscriptionId = _subscriptionId;
        vrfCoordinator = VRFCoordinatorV2Interface(_vrfCoordinator);
        keyHash = _keyHash;
        callbackGasLimit = _callbackGasLimit;
    }

    function distributionRandomNumberForVerifiers(
        address requester,
        StructDefinition.VSkillUserEvidence memory ev
    ) public {
        requestId = vrfCoordinator.requestRandomWords(
            keyHash,
            subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            numWords
        );

        requestIdToContext[requestId] = StructDefinition
            .DistributionVerifierRequestContext(requester, ev);

        emit RequestIdToContextUpdated(
            requestId,
            requestIdToContext[requestId]
        );
    }

    function fulfillRandomWords(
        uint256 /*_requestId*/,
        uint256[] memory _randomWords
    ) internal override {
        randomWords = _randomWords;
        _processVerifiers(requestId);
    }

    ///////////////////////////////
    /////   Internal Functions ////
    ///////////////////////////////
    function _processVerifiers(uint256 _requestId) internal {
        StructDefinition.DistributionVerifierRequestContext
            memory context = requestIdToContext[_requestId];
        VerifierInterface(context.requester)._selectedVerifiersAddressCallback(
            context.ev,
            randomWords
        );
    }

    ///////////////////////////////
    /////   Getter Functions   ////
    ///////////////////////////////

    function getRandomWords() public view returns (uint256[] memory) {
        return randomWords;
    }

    function getRequestIdToContext(
        uint256 _requestId
    )
        public
        view
        returns (StructDefinition.DistributionVerifierRequestContext memory)
    {
        return requestIdToContext[_requestId];
    }

    function getSubscriptionId() public view returns (uint64) {
        return subscriptionId;
    }

    function getVrfCoordinator()
        public
        view
        returns (VRFCoordinatorV2Interface)
    {
        return vrfCoordinator;
    }

    function getKeyHash() public view returns (bytes32) {
        return keyHash;
    }

    function getCallbackGasLimit() public view returns (uint32) {
        return callbackGasLimit;
    }

    function getRequestConfirmations() public view returns (uint16) {
        return requestConfirmations;
    }
}
