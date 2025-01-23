// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {DeployRelayer} from "script/deploy/DeployRelayer.s.sol";
import {DeployVerifier} from "script/deploy/DeployVerifier.s.sol";
import {DeployVSkillUser} from "script/deploy/DeployVSkillUser.s.sol";
import {DeployVSkillUserNft} from "script/deploy/DeployVSkillUserNft.s.sol";
import {Relayer} from "src/Relayer.sol";
import {Verifier} from "src/Verifier.sol";
import {VSkillUser} from "src/VSkillUser.sol";
import {VSkillUserNft} from "src/VSkillUserNft.sol";
import {Distribution} from "src/Distribution.sol";
import {Initialize} from "script/interactions/Initialize.s.sol";
import {RelayerHelperConfig} from "script/helperConfig/RelayerHelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {VerifierHelperConfig} from "script/helperConfig/VerifierHelperConfig.s.sol";

// We have already tested most of the functions in v1, here we will focus on testing the possible situations that can occur in the v2 version of the contract.
contract VSkillTest is Test {
    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    DeployRelayer deployRelayer;
    DeployVerifier deployVerifier;
    DeployVSkillUser deployVSkillUser;
    DeployVSkillUserNft deployVSkillUserNft;

    Relayer relayer;
    Verifier verifier;
    VSkillUser vSkillUser;
    VSkillUserNft vSkillUserNft;
    Distribution distribution;

    RelayerHelperConfig relayerHelperConfig;
    VerifierHelperConfig verifierHelperConfig;

    address public USER = makeAddr("user");
    string public constant SKILL_DOMAIN = "Blockchain";
    string public constant CID = "cid";
    uint256 public constant SUBMISSION_FEE = 0.0025e18;
    address public forwarder;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event RequestIdToRandomWordsUpdated(uint256 indexed requestId);
    event Relayer__NotEnoughVerifierForThisSkillDomainYet();

    /*//////////////////////////////////////////////////////////////
                                 SET UP
    //////////////////////////////////////////////////////////////*/

    function setUp() external {
        deployRelayer = new DeployRelayer();
        deployVerifier = new DeployVerifier();
        deployVSkillUser = new DeployVSkillUser();
        deployVSkillUserNft = new DeployVSkillUserNft();

        (vSkillUser, ) = deployVSkillUser.run();
        (vSkillUserNft, ) = deployVSkillUserNft.run();

        verifierHelperConfig = new VerifierHelperConfig();
        address priceFeed = verifierHelperConfig
            .getActiveNetworkConfig()
            .priceFeed;
        string[] memory skillDomains = verifierHelperConfig
            .getActiveNetworkConfig()
            .skillDomains;
        verifier = deployVerifier.deployVerifier(
            priceFeed,
            skillDomains,
            address(vSkillUser)
        );

        relayerHelperConfig = new RelayerHelperConfig();
        address registry = relayerHelperConfig
            .getActiveNetworkConfig()
            .registryAddress;
        uint256 upkeepId = relayerHelperConfig
            .getActiveNetworkConfig()
            .upkeepId;
        distribution = Distribution(
            vSkillUser.getDistributionContractAddress()
        );
        address relayerAddress = deployRelayer.deployRelayer(
            address(vSkillUser),
            address(distribution),
            address(verifier),
            address(vSkillUserNft)
        );
        relayer = Relayer(relayerAddress);

        // Initialize those contracts
        Initialize initialize = new Initialize();
        initialize._initializeToVSkillUser(
            address(distribution),
            address(vSkillUser)
        );
        initialize._initializeToRelayer(
            vSkillUser,
            vSkillUserNft,
            verifier,
            address(relayer)
        );
        forwarder = initialize._initializeToForwarder(
            registry,
            upkeepId,
            relayer
        );

        vm.deal(USER, 1000 ether);
    }

    /*//////////////////////////////////////////////////////////////
                               VSKILLUSER
    //////////////////////////////////////////////////////////////*/

    function testContractsHaveBeenInitializedProperly() external {
        vm.startPrank(vSkillUser.owner());
        vm.expectRevert(VSkillUser.VSkillUser__AlreadyInitialized.selector);
        vSkillUser.initializeRelayer(address(relayer));

        vm.expectRevert(
            VSkillUserNft.VSkillUserNft__AlreadyInitialized.selector
        );
        vSkillUserNft.initializeRelayer(address(relayer));

        vm.expectRevert(Verifier.Verifier__AlreadyInitialized.selector);
        verifier.initializeRelayer(address(relayer));

        vm.stopPrank();

        assert(relayer.getForwarder() != address(0));
        assert(distribution.getVSkillUser() == address(vSkillUser));
    }

    function testUserCanSubmitEvidence() external {
        vm.prank(USER);
        vSkillUser.submitEvidence{value: SUBMISSION_FEE}(CID, SKILL_DOMAIN);

        assertEq(
            vSkillUser.getBonus(),
            ((SUBMISSION_FEE * vSkillUser.getBonusWeight()) /
                vSkillUser.getTotalWeight())
        );
    }

    function testUserCanOnlySubmitEvidenceWithValidSkillDomain() external {
        vm.prank(USER);
        vm.expectRevert(VSkillUser.VSkillUser__InvalidSkillDomain.selector);
        vSkillUser.submitEvidence{value: SUBMISSION_FEE}(
            CID,
            "Invalid Skill Domain"
        );
    }

    /*//////////////////////////////////////////////////////////////
                                VERIFIER
    //////////////////////////////////////////////////////////////*/

    function testOnlyValidSkillDomainCanBeAddedToVerifier() external {
        // 1. stake to be verifier
        uint256 stakeAmount = verifier.getStakeEthAmount();
        vm.startPrank(USER);
        verifier.stake{value: stakeAmount}();

        // 2. add invalid skill domain
        vm.expectRevert(Verifier.Verifier__NotValidSkillDomain.selector);
        verifier.addSkillDomain("Invalid Skill Domain");

        // 3. add valid skill domain
        verifier.addSkillDomain(SKILL_DOMAIN);
        vm.stopPrank();

        assert(verifier.getVerifierInfo(USER).skillDomains.length == 1);
        assertEq(verifier.getVerifierInfo(USER).skillDomains[0], SKILL_DOMAIN);
    }

    function testVerifierCanWithdrawStakeWhenAllEvidenceHandled() external {
        uint256 stakeAmount = verifier.getStakeEthAmount();
        vm.startPrank(USER);
        verifier.stake{value: stakeAmount}();

        assertEq(verifier.getVerifierCount(), 1);

        verifier.withdrawStakeAndLoseVerifier();
        vm.stopPrank();

        assertEq(verifier.getVerifierCount(), 0);
        assertEq(verifier.getVerifierInfo(USER).reputation, 0);
    }

    /*//////////////////////////////////////////////////////////////
                                RELAYER
    //////////////////////////////////////////////////////////////*/

    function testPerformUpkeepOnlyCalledByForwarder() external {
        uint256 dummyRequestId = 1;
        bytes memory performData = abi.encode(dummyRequestId);

        vm.prank(USER);
        vm.expectRevert(Relayer.Relayer__OnlyForwarder.selector);
        relayer.performUpkeep(performData);
    }

    function testPerformUpkeepStopIfNotEnoughVerifier() external {
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

        vm.expectEmit(true, false, false, false, address(distribution));
        emit RequestIdToRandomWordsUpdated(uint256(requestId));
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
        vm.expectEmit(false, false, false, false, address(relayer));
        emit Relayer__NotEnoughVerifierForThisSkillDomainYet();
        relayer.performUpkeep(performData);

        vm.stopPrank();
    }

    function testPerformUpkeepWorkingGood() external {
        _setUpForRelayer();

        assertEq(relayer.getUnhandledRequestIdsLength(), 1);
    }

    function testAssignEvidenceToVerifiersWorkingGood() external {
        _setUpForRelayer();

        vm.prank(relayer.owner());
        relayer.assignEvidenceToVerifiers();

        assertEq(relayer.getUnhandledRequestIdsLength(), 0);
    }

    function testProcessEvidenceStatusWorkingGood() external {
        _setUpForRelayer();

        vm.startPrank(relayer.owner());
        relayer.assignEvidenceToVerifiers();
        uint256 batchNumber = relayer.getBatchProcessed();
        uint256 deadline = relayer.getDeadline();
        vm.warp(deadline + 1);
        relayer.processEvidenceStatus(batchNumber - 1);
        vm.stopPrank();

        // all verifiers should be punished(Lose verifier)
        assert(verifier.getVerifierCount() == 0);
        // 3 because in the _setUpForRelayer function we added 3 verifiers
        assertEq(verifier.getReward(), verifier.getStakeEthAmount() * 3);
    }

    function testHandleEvidenceAfterDeadline(
        string memory feedbackCid
    ) external {
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
            vm.prank(selectedVerifiers[i]);
            verifier.provideFeedback(requestId, feedbackCid, true);
        }
        vm.warp(deadline + 1);
        vm.startPrank(relayer.owner());
        relayer.processEvidenceStatus(batchNumber - 1);
        relayer.handleEvidenceAfterDeadline(batchNumber - 1);
        vm.stopPrank();

        assert(vSkillUserNft.balanceOf(USER) == 1);
    }

    // TBH, this function is not really meet the expectation because it will cost some gas to just add the bonus
    // But this mechanism may prevent some kind of single point of failure?
    // We will figure out this
    function testTransferBonusFromVSkillUserToVerifierContractWorkingGood(
        string memory feedbackCid
    ) external {
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
            vm.prank(selectedVerifiers[i]);
            verifier.provideFeedback(requestId, feedbackCid, true);
        }
        vm.warp(deadline + 1);
        vm.startPrank(relayer.owner());
        // This time before handle the evidence, we will transfer the bonus
        relayer.transferBonusFromVSkillUserToVerifierContract();
        relayer.processEvidenceStatus(batchNumber - 1);
        relayer.handleEvidenceAfterDeadline(batchNumber - 1);
        vm.stopPrank();

        uint256 bonusAmount = (vSkillUser.getSubmissionFeeInEth() *
            vSkillUser.getBonusWeight()) / vSkillUser.getTotalWeight();
        uint256 rewardAmount = (bonusAmount *
            verifier.getInitialReputation() *
            verifier.getInitialReputation()) /
            (verifier.getHighestReputation() * verifier.getHighestReputation());
        vm.assertEq(
            rewardAmount,
            verifier.getVerifierReward(selectedVerifiers[0])
        );
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
            vm.deal(verifierAddress, verifier.getStakeEthAmount());
            vm.startPrank(verifierAddress);
            verifier.stake{value: verifier.getStakeEthAmount()}();
            verifier.addSkillDomain(skillDomain);
            vm.stopPrank();
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

        vm.expectEmit(true, false, false, false, address(distribution));
        emit RequestIdToRandomWordsUpdated(uint256(requestId));
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
