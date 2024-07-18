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

contract Distribution is VRFConsumerBaseV2 {
    uint64 subscriptionId;
    VRFCoordinatorV2Interface vrfCoordinator;
    bytes32 keyHash;
    uint32 callbackGasLimit;
    uint16 requestConfirmations = 3;
    uint32 numWords = 3;

    uint256 requestId;

    uint256[] private randomWords;

    // mapping(string => address[]) verifiersWithinSameDomain;
    // First get the address of those verifiers who are within the same domain
    // Then based on the random number generated, select the verifier
    // Those verifiers have the reputation score, higher reputation scores means higher probability of being selected
    // Come back when write the contract for verifiers

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

    function distributionRandomNumberForVerifiers() external {
        requestId = vrfCoordinator.requestRandomWords(
            keyHash,
            subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            numWords
        );
    }

    function fulfillRandomWords(
        uint256 /*_requestId*/,
        uint256[] memory _randomWords
    ) internal override {
        randomWords = _randomWords;
    }

    ///////////////////////////////
    /////   Getter Functions   ////
    ///////////////////////////////

    function getRandomWords() external view returns (uint256[] memory) {
        return randomWords;
    }
}
