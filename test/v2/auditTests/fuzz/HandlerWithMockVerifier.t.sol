// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {Relayer} from "src/Relayer.sol";
import {MockVerifier} from "test/mock/MockVerifier.sol";
import {VSkillUser} from "src/VSkillUser.sol";
import {Distribution} from "src/Distribution.sol";
import {IRelayer} from "src/interfaces/IRelayer.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract HandlerWithMockVerifier is Test {
    IRelayer relayer;
    MockVerifier verifier;
    VSkillUser vSkillUser;
    Distribution distribution;

    address public USER;
    string public constant SKILL_DOMAIN = "Blockchain";
    string public constant CID = "cid";
    string public constant FEEDBACK_CID = "feedback_cid";
    uint256 public constant SUBMISSION_FEE = 0.0025e18;
    address public forwarder;

    constructor(
        IRelayer _relayer,
        MockVerifier _verifier,
        VSkillUser _vSkillUser,
        Distribution _distribution,
        address _user,
        address _forwarder
    ) {
        relayer = _relayer;
        verifier = _verifier;
        vSkillUser = _vSkillUser;
        distribution = _distribution;
        USER = _user;
        forwarder = _forwarder;

        deal(USER, 100000e18);
    }

    function withdraw() external {
        // Let's say the address(1) is our target verifier who want to withdraw
        vm.startPrank(address(1));

        // only withdraw when the user is a verifier
        if (!verifier.getAddressToIsVerifier(address(1))) {
            return;
        }

        // only if unhandledRequestCount is 0 can the user withdraw
        if (verifier.getVerifierUnhandledRequestCount(address(1)) > 0) {
            return;
        }

        // withdraw stake and lose verifier status

        verifier.withdrawStakeAndLoseVerifier();

        vm.stopPrank();
    }

    function userSubmittedEvidenceUnhandled() external {
        _setUpForRelayer();

        vm.startPrank(relayer.owner());
        relayer.assignEvidenceToVerifiers();
        vm.stopPrank();
    }

    function userSubmittedEvidenceHandled() external {
        (
            address[] memory selectedVerifiers,
            uint256 requestId
        ) = _setUpForRelayer();

        vm.startPrank(relayer.owner());
        relayer.assignEvidenceToVerifiers();
        vm.stopPrank();
        uint256 batchNumber = relayer.getBatchProcessed();
        uint256 deadline = relayer.getDeadline();
        // For now all of them approved the evidence so we can mint the NFT
        for (uint8 i = 0; i < selectedVerifiers.length; i++) {
            vm.startPrank(selectedVerifiers[i]);
            verifier.provideFeedback(requestId, FEEDBACK_CID, true);
            vm.stopPrank();
        }
        vm.warp(block.timestamp + deadline + 1);
        vm.startPrank(relayer.owner());
        // This time before handle the evidence, we will transfer the bonus
        relayer.transferBonusFromVSkillUserToVerifierContract();

        console.log(relayer.getBatchToDeadline(batchNumber - 1));
        console.log(block.timestamp);

        relayer.processEvidenceStatus(batchNumber - 1);
        relayer.handleEvidenceAfterDeadline(batchNumber - 1);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _addVerifiers(
        string memory skillDomain,
        uint256 amount
    ) internal returns (address[] memory) {
        address[] memory verifiers = new address[](amount);
        for (uint160 i = 0; i < amount; i++) {
            address verifierAddress = address(i + 1); // i + 1 to avoid address(0)
            // only add verifiers that are not already added
            if (!verifier.getAddressToIsVerifier(verifierAddress)) {
                vm.deal(verifierAddress, verifier.getStakeEthAmount());
                vm.startPrank(verifierAddress);
                verifier.stake{value: verifier.getStakeEthAmount()}();
                verifier.addSkillDomain(skillDomain);
                vm.stopPrank();
            }
            verifiers[i] = verifierAddress;
        }
        return verifiers;
    }

    function _setUpForRelayer() internal returns (address[] memory, uint256) {
        // 0. before starting the test, we need to add verifiers
        address[] memory selectedVerifiers = _addVerifiers(SKILL_DOMAIN, 3);
        // 1. submit evidence
        vm.startPrank(USER);
        vm.recordLogs();
        vSkillUser.submitEvidence{value: SUBMISSION_FEE}(CID, SKILL_DOMAIN);
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        vm.stopPrank();
        string memory skillDomain = vSkillUser
            .getRequestIdToEvidenceSkillDomain(uint256(requestId));
        assertEq(skillDomain, SKILL_DOMAIN);
        // 2. Distribution contract will give the random words
        VRFCoordinatorV2_5Mock vrfCoordinator = VRFCoordinatorV2_5Mock(
            distribution.getVrfCoordinator()
        );
        vrfCoordinator.fundSubscription(
            // This subscription ID is retrieved from the console, you can find this with -vvvv flag
            71559651348530707092126447838144209774845187901096159534269265783461099618592,
            100e18
        );
        vrfCoordinator.fulfillRandomWords(
            uint256(requestId),
            address(distribution)
        );
        uint256[] memory randomWords = distribution.getRandomWords(
            uint256(requestId)
        );
        assertEq(randomWords.length, distribution.getNumWords());
        // 3. Relayer catch the event and perform the upkeep
        vm.startPrank(forwarder);
        bytes memory performData = abi.encode(uint256(requestId));
        relayer.performUpkeep(performData);
        vm.stopPrank();
        return (selectedVerifiers, uint256(requestId));
    }
}
