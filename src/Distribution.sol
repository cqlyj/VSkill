// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

contract Distribution is VRFConsumerBaseV2Plus {
    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    uint256 immutable i_subscriptionId;
    bytes32 immutable i_keyHash;
    uint32 immutable i_callbackGasLimit;
    address immutable i_vrfCoordinator;
    uint16 constant REQUEST_CONFIRMATIONS = 3;
    uint32 constant NUM_WORDS = 3;
    address private i_vSkillUser;
    mapping(uint256 requestId => uint256[] randomWords)
        private s_requestIdToRandomWords;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error Distribution__OnlyVSkillUser();
    error Distribution__VrfCoordinatorZeroAddress();
    error Distribution__VSkillUserZeroAddress();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event VerifierDistributionRequested(uint256 indexed requestId);
    event RequestIdToRandomWordsUpdated(uint256 indexed requestId);
    event Distribution__VSkillUserSet(address indexed vSkillUser);

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyVSkillUser() {
        if (msg.sender != i_vSkillUser) {
            revert Distribution__OnlyVSkillUser();
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        uint256 _subscriptionId,
        bytes32 _keyHash,
        uint32 _callbackGasLimit,
        address vrfCoordinator
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        if (vrfCoordinator == address(0)) {
            revert Distribution__VrfCoordinatorZeroAddress();
        }
        i_subscriptionId = _subscriptionId;
        i_keyHash = _keyHash;
        i_callbackGasLimit = _callbackGasLimit;
        i_vrfCoordinator = vrfCoordinator;
    }

    function setVSkillUser(address _vSkillUser) public onlyOwner {
        if (_vSkillUser == address(0)) {
            revert Distribution__VSkillUserZeroAddress();
        }
        i_vSkillUser = _vSkillUser;

        emit Distribution__VSkillUserSet(_vSkillUser);
    }

    /*//////////////////////////////////////////////////////////////
                     EXTERNAL AND PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    // the VSkillUser contract will call this function to request random numbers for verifiers
    function distributionRandomNumberForVerifiers()
        public
        onlyVSkillUser
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
                // For now just set it to false
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
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
        emit RequestIdToRandomWordsUpdated(_requestId);
    }

    /*//////////////////////////////////////////////////////////////
                                GETTERS
    //////////////////////////////////////////////////////////////*/

    function getSubscriptionId() public view returns (uint256) {
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

    function getVSkillUser() public view returns (address) {
        return i_vSkillUser;
    }

    function getVrfCoordinator() public view returns (address) {
        return i_vrfCoordinator;
    }
}
