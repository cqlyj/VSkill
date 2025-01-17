// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

contract Distribution is VRFConsumerBaseV2Plus {
    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    uint64 immutable i_subscriptionId;
    bytes32 immutable i_keyHash;
    uint32 immutable i_callbackGasLimit;
    uint16 constant REQUEST_CONFIRMATIONS = 3;
    uint32 constant NUM_WORDS = 3;

    mapping(uint256 requestId => uint256[] randomWords)
        private s_requestIdToRandomWords;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event VerifierDistributionRequested(uint256 indexed requestId);
    event RequestIdToRandomWordsUpdated(uint256 indexed requestId);

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        uint64 _subscriptionId,
        bytes32 _keyHash,
        uint32 _callbackGasLimit,
        address vrfCoordinator
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_subscriptionId = _subscriptionId;
        i_keyHash = _keyHash;
        i_callbackGasLimit = _callbackGasLimit;
    }

    /*//////////////////////////////////////////////////////////////
                     EXTERNAL AND PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    // the VSkillUser contract will call this function to request random numbers for verifierss
    function distributionRandomNumberForVerifiers()
        public
        onlyOwner
        returns (uint256)
    {
        uint256 requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_keyHash,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: true})
                )
            })
        );

        emit VerifierDistributionRequested(requestId);
        return requestId;
    }

    /*//////////////////////////////////////////////////////////////
                     INTERNAL AND PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function fulfillRandomWords(
        uint256 _requestId,
        uint256[] calldata _randomWords
    ) internal override {
        s_requestIdToRandomWords[_requestId] = _randomWords;
        // _processVerifiers(_requestId);
        // Since this contract will be inherited by Relayer, the operation of the distribution will be updated later
        emit RequestIdToRandomWordsUpdated(_requestId);
    }

    /*//////////////////////////////////////////////////////////////
                                GETTERS
    //////////////////////////////////////////////////////////////*/

    function getSubscriptionId() public view returns (uint64) {
        return i_subscriptionId;
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

    function getNumWords() public pure returns (uint32) {
        return NUM_WORDS;
    }

    function getRandomWords(
        uint256 _requestId
    ) public view returns (uint256[] memory) {
        return s_requestIdToRandomWords[_requestId];
    }
}

// import {IVerifier} from "../utils/interface/IVerifier.sol";
// import {StructDefinition} from "../utils/library/StructDefinition.sol";

// mapping(uint256 => StructDefinition.DistributionVerifierRequestContext) private s_requestIdToContext;

// function _processVerifiers(uint256 _requestId) internal {
//     StructDefinition.DistributionVerifierRequestContext
//         memory context = s_requestIdToContext[_requestId];
//     IVerifier(context.requester)._selectedVerifiersAddressCallback(
//         context.ev,
//         s_randomWords
//     );
// }
