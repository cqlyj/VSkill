// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {ILogAutomation, Log} from "@chainlink/contracts/src/v0.8/automation/interfaces/ILogAutomation.sol";
import {VSkillUser} from "src/VSkillUser.sol";
import {StructDefinition} from "src/library/StructDefinition.sol";
import {Distribution} from "src/Distribution.sol";
import {Verifier} from "src/Verifier.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract Relayer is ILogAutomation, Ownable {
    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    VSkillUser private immutable i_vSkillUser;
    Distribution private immutable i_distribution;
    Verifier private immutable i_verifier;
    mapping(uint256 requestId => uint256[] randomWordsWithinRange)
        private s_requestIdToRandomWordsWithinRange;
    uint256[] private s_unhandledRequestIds;
    mapping(uint256 requestId => address[] verifiersAssigned)
        private s_requestIdToVerifiersAssigned;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Relayer__UnhandledRequestIdAdded(
        uint256 indexed unhandledRequestIdsLength
    );
    event Relayer__NoVerifierForThisSkillDomainYet();
    event Relayer__EvidenceAssignedToVerifiers();

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address vSkillUser,
        address distribution,
        address verifier
    ) Ownable(msg.sender) {
        i_vSkillUser = VSkillUser(payable(vSkillUser));
        i_distribution = Distribution(distribution);
        i_verifier = Verifier(payable(verifier));
    }

    /*//////////////////////////////////////////////////////////////
                          CHAINLINK AUTOMATION
    //////////////////////////////////////////////////////////////*/

    // Listen for the distribution RequestIdToRandomWordsUpdated event
    function checkLog(
        Log calldata log,
        bytes memory
    ) external pure returns (bool upkeepNeeded, bytes memory performData) {
        upkeepNeeded = true;
        uint256 requestId = uint256(log.topics[1]);
        performData = abi.encode(requestId);
    }

    // Here we just store select randomWords in the range of the verifierWithinSameDomainLength
    // And store the requestId in the s_unhandledRequestIds array
    // As for the assignment, we will handle this in batches to reduce gas costs
    // @audit only the Forwarder will be able to call this function!!!
    // update this soon!
    function performUpkeep(bytes calldata performData) external override {
        uint256 requestId = abi.decode(performData, (uint256));
        StructDefinition.VSkillUserEvidence memory evidence = i_vSkillUser
            .getRequestIdToEvidence(requestId);
        uint256[] memory randomWords = i_distribution.getRandomWords(requestId);

        // As for the number of verifiers enough or not, since we only require 3 verifiers
        // At the very beginning of the project, we will make sure that the number of verifiers is enough for each skill domain(above 3)
        // After that we will allow users to submit the evidence
        // Even if there are only 2 or 1 verifiers, we will still allow the user to submit the evidence and one of them will need to provide the same feedback twice
        // If the length is zero: we will emit an event and the owner will need to handle this manually...(but this usually won't happen)
        uint256 verifierWithinSameDomainLength = i_verifier
            .getSkillDomainToVerifiersWithinSameDomainLength(
                evidence.skillDomain
            );
        if (verifierWithinSameDomainLength == 0) {
            emit Relayer__NoVerifierForThisSkillDomainYet();
            return;
        }
        // get the randomWords within the range of the verifierWithinSameDomainLength
        // here the length is just 3, no worries about DoS attack
        for (uint8 i = 0; i < randomWords.length; i++) {
            randomWords[i] = randomWords[i] % verifierWithinSameDomainLength;
        }
        s_requestIdToRandomWordsWithinRange[requestId] = randomWords;
        s_unhandledRequestIds.push(requestId);
        emit Relayer__UnhandledRequestIdAdded(s_unhandledRequestIds.length);
    }

    /*//////////////////////////////////////////////////////////////
                     EXTERNAL AND PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    // These functions will be called daily by the owner, the automation process will be set on the browser

    // This will be a very gas cost function as it will assign all the evidence to the verifiers
    // Try to reduce the gas cost as much as possible
    // We are the only one (owner or the profit beneficiary) who can call this function

    // once the verifiers are assigned, the verifier will get the notification on the frontend(listening to the event)
    // and they can start to provide feedback to the specific evidence

    // set the assigned verifiers as the one who can change the evidence status
    // @audit refactor this function to be more gas efficient!
    function assignEvidenceToVerifiers() external onlyOwner {
        uint256 length = s_unhandledRequestIds.length;
        // the length can be very large, but we will monitor the event to track the length and avoid DoS attack
        for (uint256 i = 0; i < length; i++) {
            uint256 requestId = s_unhandledRequestIds[i];
            uint256[]
                memory randomWordsWithinRange = s_requestIdToRandomWordsWithinRange[
                    requestId
                ];
            address[] memory verifiersWithinSameDomain = i_verifier
                .getSkillDomainToVerifiersWithinSameDomain(
                    i_vSkillUser.getRequestIdToEvidence(requestId).skillDomain
                );
            for (uint8 j = 0; j < randomWordsWithinRange.length; j++) {
                i_verifier.setVerifierAssignedRequestIds(
                    requestId,
                    verifiersWithinSameDomain[randomWordsWithinRange[j]]
                );
                s_requestIdToVerifiersAssigned[requestId].push(
                    verifiersWithinSameDomain[randomWordsWithinRange[j]]
                );
            }
        }
        delete s_unhandledRequestIds;

        emit Relayer__EvidenceAssignedToVerifiers();
    }

    // This will be a very gas cost function as it will check all the feedbacks and decide the final status
    // Try to reduce the gas cost as much as possible

    // if the status is approved, the user will get the NFT
    // if the status is rejected, the user will not get the NFT
    // if the status is different opinion, the situation will be as follows:
    // If the status is `DIFFERENTOPINION_A`, the user will be able to mint the NFT. The verifiers will be penalized.
    // If the status is `DIFFERENTOPINION_R`, the user will not be able to mint the NFT. The verifiers will be penalized.
    //   - If more than 2/3 of the verifiers have approved the evidence, then it's `DIFFERENTOPINION_A`. The rest one will be penalized.
    //   - If only 1/3 of the verifiers have approved the evidence, the status will be `DIFFERENTOPINION_R`. The rest two will be penalized.

    function mintUserNfts() external onlyOwner {}
}
