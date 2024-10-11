// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {Verifier} from "src/verifier/Verifier.sol";
import {DeployVerifier} from "script/verifier/DeployVerifier.s.sol";
import {HelperConfig} from "script/verifier/HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2Mock.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {PriceConverter} from "src/utils/library/PriceCoverter.sol";
import {Staking} from "src/staking/Staking.sol";
import {StructDefinition} from "src/utils/library/StructDefinition.sol";
import {Vm} from "forge-std/Vm.sol";

contract VerifierTest is Test {
    using PriceConverter for uint256;
    using StructDefinition for StructDefinition.VerifierConstructorParams;
    using StructDefinition for StructDefinition.VerifierFeedbackProvidedEventParams;

    DeployVerifier deployer;
    Verifier verifier;
    HelperConfig helperConfig;

    StructDefinition.VerifierConstructorParams verifierConstructorParams;
    address linkTokenAddress;
    uint256 deployerKey;

    address public USER = makeAddr("user");
    uint256 private constant MIN_USD_AMOUNT_TO_STAKE = 20e18; // 20 USD
    string[] private NEW_SKILL_DOMAINS = ["newSkillDomain1", "newSkillDomain2"];
    string[] private SKILL_DOMAINS = ["Frontend", "Backend"];
    uint256 private constant INITIAL_BALANCE = 100 ether;
    uint256 private constant NUM_WORDS = 3;
    string public constant IPFS_HASH =
        "https://ipfs.io/ipfs/QmbJLndDmDiwdotu3MtfcjC2hC5tXeAR9EXbNSdUDUDYWa";
    string public constant FEEDBACK_IPFS_HASH =
        "https://ipfs.io/ipfs/QmSsYRx3LpDAb1GZQm7zZ1AuHZjfbPkD6J7s9r41xu1mf8";

    enum SubmissionStatus {
        SUBMITTED,
        INREVIEW,
        APPROVED,
        REJECTED,
        DIFFERENTOPINION
    }

    function setUp() external {
        deployer = new DeployVerifier();
        (verifier, helperConfig) = deployer.run();
        // (
        //     verifierConstructorParams.priceFeed,
        //     verifierConstructorParams.subscriptionId,
        //     verifierConstructorParams.vrfCoordinator,
        //     verifierConstructorParams.keyHash,
        //     verifierConstructorParams.callbackGasLimit,
        //     verifierConstructorParams.submissionFeeInUsd,
        //     linkTokenAddress,
        //     deployerKey
        // ) = helperConfig.activeNetworkConfig();

        // Refactor the above code to the following to avoid stack too deep error
        verifierConstructorParams.priceFeed = helperConfig
            .getActiveNetworkConfig()
            .priceFeed;
        verifierConstructorParams.subscriptionId = helperConfig
            .getActiveNetworkConfig()
            .subscriptionId;
        verifierConstructorParams.vrfCoordinator = helperConfig
            .getActiveNetworkConfig()
            .vrfCoordinator;
        verifierConstructorParams.keyHash = helperConfig
            .getActiveNetworkConfig()
            .keyHash;
        verifierConstructorParams.callbackGasLimit = helperConfig
            .getActiveNetworkConfig()
            .callbackGasLimit;
        verifierConstructorParams.submissionFeeInUsd = helperConfig
            .getActiveNetworkConfig()
            .submissionFeeInUsd;
        linkTokenAddress = helperConfig
            .getActiveNetworkConfig()
            .linkTokenAddress;
        deployerKey = helperConfig.getActiveNetworkConfig().deployerKey;
        verifierConstructorParams.userNftImageUris = helperConfig
            .getActiveNetworkConfig()
            .userNftImageUris;

        vm.deal(USER, INITIAL_BALANCE);
    }

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
        SubmissionStatus status
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

    /////////////////////////////
    ////       modifier      ////
    /////////////////////////////

    modifier becomeVerifierWithSkillDomain(
        address user,
        string[] memory skillDomains
    ) {
        _becomeVerifierWithSkillDomain(user, skillDomains);
        _;
    }

    ///////////////////////////
    ///     constructor     ///
    ///////////////////////////

    function testVerifierConstructorSetCorrectly() external view {
        assertEq(
            address(verifier.getPriceFeed()),
            address(verifierConstructorParams.priceFeed)
        );
        // this subscriptionId will be updated later in the helperconfig, hence commented out
        // assertEq(
        //     verifier.getSubscriptionId(),
        //     verifierConstructorParams.subscriptionId
        // );
        assertEq(
            address(verifier.getVrfCoordinator()),
            address(verifierConstructorParams.vrfCoordinator)
        );
        assertEq(verifier.getKeyHash(), verifierConstructorParams.keyHash);
        assertEq(
            verifier.getCallbackGasLimit(),
            verifierConstructorParams.callbackGasLimit
        );
        assertEq(
            verifier.getSubmissionFeeInUsd(),
            verifierConstructorParams.submissionFeeInUsd
        );
        assertEq(
            verifier.getUserNftImageUris().length,
            verifierConstructorParams.userNftImageUris.length
        );

        assert(
            keccak256(abi.encode(verifier.getUserNftImageUris())) ==
                keccak256(
                    abi.encode(verifierConstructorParams.userNftImageUris)
                )
        );
    }

    ///////////////////////////
    ///     checkUpkeep     ///
    ///////////////////////////

    function testCheckUpKeepReturnsTrueIfEvidenceStatusIsSubmittedOrDifferentOpinion()
        external
    {
        StructDefinition.VSkillUserEvidence memory ev1 = StructDefinition
            .VSkillUserEvidence(
                USER,
                IPFS_HASH,
                SKILL_DOMAINS[0],
                StructDefinition.VSkillUserSubmissionStatus.SUBMITTED,
                new string[](0)
            );

        StructDefinition.VSkillUserEvidence memory ev2 = StructDefinition
            .VSkillUserEvidence(
                USER,
                IPFS_HASH,
                SKILL_DOMAINS[0],
                StructDefinition.VSkillUserSubmissionStatus.DIFFERENTOPINION,
                new string[](0)
            );
        vm.prank(USER);
        verifier.submitEvidence{
            value: verifier.getSubmissionFeeInUsd().convertUsdToEth(
                AggregatorV3Interface(verifierConstructorParams.priceFeed)
            )
        }(ev1.evidenceIpfsHash, ev1.skillDomain);
        (bool upkeepNeeded1, ) = verifier.checkUpkeep("");
        assert(upkeepNeeded1);

        vm.prank(USER);
        verifier.submitEvidence{
            value: verifier.getSubmissionFeeInUsd().convertUsdToEth(
                AggregatorV3Interface(verifierConstructorParams.priceFeed)
            )
        }(ev2.evidenceIpfsHash, ev2.skillDomain);
        (bool upkeepNeeded2, ) = verifier.checkUpkeep("");
        assert(upkeepNeeded2);
    }

    function testCheckUpKeepReturnsCorrectEvidenceIfEvidenceStatusIsSubmittedOrDifferentOpinion()
        external
    {
        StructDefinition.VSkillUserEvidence memory ev1 = StructDefinition
            .VSkillUserEvidence(
                USER,
                IPFS_HASH,
                SKILL_DOMAINS[0],
                StructDefinition.VSkillUserSubmissionStatus.SUBMITTED,
                new string[](0)
            );

        StructDefinition.VSkillUserEvidence memory ev2 = StructDefinition
            .VSkillUserEvidence(
                USER,
                IPFS_HASH,
                SKILL_DOMAINS[0],
                StructDefinition.VSkillUserSubmissionStatus.DIFFERENTOPINION,
                new string[](0)
            );
        vm.prank(USER);
        verifier.submitEvidence{
            value: verifier.getSubmissionFeeInUsd().convertUsdToEth(
                AggregatorV3Interface(verifierConstructorParams.priceFeed)
            )
        }(ev1.evidenceIpfsHash, ev1.skillDomain);
        (, bytes memory evidence1) = verifier.checkUpkeep("");
        assertEq(
            abi
                .decode(evidence1, (StructDefinition.VSkillUserEvidence))
                .evidenceIpfsHash,
            ev1.evidenceIpfsHash
        );

        vm.prank(USER);
        verifier.submitEvidence{
            value: verifier.getSubmissionFeeInUsd().convertUsdToEth(
                AggregatorV3Interface(verifierConstructorParams.priceFeed)
            )
        }(ev2.evidenceIpfsHash, ev2.skillDomain);
        (, bytes memory evidence2) = verifier.checkUpkeep("");
        assertEq(
            abi
                .decode(evidence2, (StructDefinition.VSkillUserEvidence))
                .evidenceIpfsHash,
            ev2.evidenceIpfsHash
        );
    }

    // since we cannot change the status of the evidence unless we have those verifiers to provide feedback
    // this test case will be skipped
    // function testCheckUpKeepReturnsFalseIfEvidenceStatusIsNotSubmittedOrDifferentOpinion()
    //     external
    // {}

    //////////////////////////////
    //    updateSkillDomains    //
    //////////////////////////////

    function testUpdateSkillDomainsRevertIfNotVerifier() external {
        vm.prank(USER);
        vm.expectRevert(Staking.Staking__NotVerifier.selector);
        verifier.updateSkillDomains(NEW_SKILL_DOMAINS);
    }

    function testUpdateSkillDomainsUpdateSuccessfully()
        external
        becomeVerifierWithSkillDomain(USER, SKILL_DOMAINS)
    {
        assert(
            NEW_SKILL_DOMAINS.length ==
                verifier.getVerifierSkillDomains(USER).length
        );
    }

    function testUpdateSkillDomainsEmitsVerifierSkillDomainUpdatedEvent()
        external
    {
        _stakeToBeVerifier(USER);
        vm.prank(USER);

        vm.expectEmit(true, false, false, true, address(verifier));
        emit VerifierSkillDomainUpdated(USER, NEW_SKILL_DOMAINS);
        verifier.updateSkillDomains(NEW_SKILL_DOMAINS);
    }

    ///////////////////////////////
    ///     provideFeedback     ///
    ///////////////////////////////

    function testProvideFeedbackRevertIfNotSelectedVerifiers() external {
        _stakeToBeVerifier(USER);
        vm.prank(USER);
        vm.expectRevert(
            abi.encodeWithSelector(
                Verifier.Verifier__NotSelectedVerifier.selector
            )
        );
        verifier.provideFeedback(FEEDBACK_IPFS_HASH, IPFS_HASH, USER, true);
    }

    function testProvideFeedbackUpdateAddressToEvidences() external {
        _createNumWordsNumberOfSameDomainVerifier(SKILL_DOMAINS);

        StructDefinition.VSkillUserEvidence memory ev = StructDefinition
            .VSkillUserEvidence(
                USER,
                IPFS_HASH,
                SKILL_DOMAINS[0],
                StructDefinition.VSkillUserSubmissionStatus.SUBMITTED,
                new string[](0)
            );
        vm.startPrank(USER);
        verifier.submitEvidence{
            value: verifier.getSubmissionFeeInUsd().convertUsdToEth(
                AggregatorV3Interface(verifierConstructorParams.priceFeed)
            )
        }(ev.evidenceIpfsHash, ev.skillDomain);
        vm.stopPrank();

        vm.recordLogs();
        verifier._requestVerifiersSelection(ev);
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[0].topics[2];
        VRFCoordinatorV2Mock vrfCoordinatorMock = VRFCoordinatorV2Mock(
            verifierConstructorParams.vrfCoordinator
        );
        vm.pauseGasMetering();
        vm.recordLogs();
        vrfCoordinatorMock.fulfillRandomWords(
            uint256(requestId),
            address(verifier)
        );
        Vm.Log[] memory entriesOfFulfillRandomWords = vm.getRecordedLogs();
        bytes32 selectedVerifier = entriesOfFulfillRandomWords[1].topics[1];
        address selectedVerifierAddress = address(
            uint160(uint256(selectedVerifier))
        );

        vm.prank(selectedVerifierAddress);
        verifier.provideFeedback(FEEDBACK_IPFS_HASH, IPFS_HASH, USER, true);
        StructDefinition.VSkillUserEvidence[] memory evidences = verifier
            .getAddressToEvidences(USER);
        assertEq(evidences.length, 1);
    }

    function testProvideFeedbackUpdateVerifiersInfo() external {
        _createNumWordsNumberOfSameDomainVerifier(SKILL_DOMAINS);

        StructDefinition.VSkillUserEvidence memory ev = StructDefinition
            .VSkillUserEvidence(
                USER,
                IPFS_HASH,
                SKILL_DOMAINS[0],
                StructDefinition.VSkillUserSubmissionStatus.SUBMITTED,
                new string[](0)
            );
        vm.startPrank(USER);
        verifier.submitEvidence{
            value: verifier.getSubmissionFeeInUsd().convertUsdToEth(
                AggregatorV3Interface(verifierConstructorParams.priceFeed)
            )
        }(ev.evidenceIpfsHash, ev.skillDomain);
        vm.stopPrank();

        vm.recordLogs();
        verifier._requestVerifiersSelection(ev);
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[0].topics[2];
        VRFCoordinatorV2Mock vrfCoordinatorMock = VRFCoordinatorV2Mock(
            verifierConstructorParams.vrfCoordinator
        );
        vm.pauseGasMetering();
        vm.recordLogs();
        vrfCoordinatorMock.fulfillRandomWords(
            uint256(requestId),
            address(verifier)
        );
        Vm.Log[] memory entriesOfFulfillRandomWords = vm.getRecordedLogs();
        bytes32 selectedVerifier = entriesOfFulfillRandomWords[1].topics[1];
        address selectedVerifierAddress = address(
            uint160(uint256(selectedVerifier))
        );

        vm.prank(selectedVerifierAddress);
        verifier.provideFeedback(FEEDBACK_IPFS_HASH, IPFS_HASH, USER, true);
        string[] memory feedbackIpfsHashes = verifier
            .getVerifierFeedbackIpfsHash(selectedVerifierAddress);

        assertEq(feedbackIpfsHashes.length, 1);
        assertEq(feedbackIpfsHashes[0], FEEDBACK_IPFS_HASH);
    }

    function testProvideFeedbackEmitFeedbackProvidedEvent() external {
        _createNumWordsNumberOfSameDomainVerifier(SKILL_DOMAINS);

        StructDefinition.VSkillUserEvidence memory ev = StructDefinition
            .VSkillUserEvidence(
                USER,
                IPFS_HASH,
                SKILL_DOMAINS[0],
                StructDefinition.VSkillUserSubmissionStatus.SUBMITTED,
                new string[](0)
            );
        vm.startPrank(USER);
        verifier.submitEvidence{
            value: verifier.getSubmissionFeeInUsd().convertUsdToEth(
                AggregatorV3Interface(verifierConstructorParams.priceFeed)
            )
        }(ev.evidenceIpfsHash, ev.skillDomain);
        vm.stopPrank();

        vm.recordLogs();
        verifier._requestVerifiersSelection(ev);
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[0].topics[2];
        VRFCoordinatorV2Mock vrfCoordinatorMock = VRFCoordinatorV2Mock(
            verifierConstructorParams.vrfCoordinator
        );
        vm.pauseGasMetering();
        vm.recordLogs();
        vrfCoordinatorMock.fulfillRandomWords(
            uint256(requestId),
            address(verifier)
        );
        Vm.Log[] memory entriesOfFulfillRandomWords = vm.getRecordedLogs();
        bytes32 selectedVerifier = entriesOfFulfillRandomWords[1].topics[1];
        address selectedVerifierAddress = address(
            uint160(uint256(selectedVerifier))
        );

        vm.startPrank(selectedVerifierAddress);
        vm.expectEmit(true, false, false, false, address(verifier));
        emit FeedbackProvided(
            StructDefinition.VerifierFeedbackProvidedEventParams({
                verifierAddress: selectedVerifierAddress,
                user: USER,
                approved: true,
                feedbackIpfsHash: FEEDBACK_IPFS_HASH,
                evidenceIpfsHash: IPFS_HASH
            })
        );
        verifier.provideFeedback(FEEDBACK_IPFS_HASH, IPFS_HASH, USER, true);

        vm.stopPrank();
    }

    function testProvideFeedbackUpdateEvidenceIpfsHashToItsInfo() external {
        _createNumWordsNumberOfSameDomainVerifier(SKILL_DOMAINS);

        StructDefinition.VSkillUserEvidence memory ev = StructDefinition
            .VSkillUserEvidence(
                USER,
                IPFS_HASH,
                SKILL_DOMAINS[0],
                StructDefinition.VSkillUserSubmissionStatus.SUBMITTED,
                new string[](0)
            );
        vm.startPrank(USER);
        verifier.submitEvidence{
            value: verifier.getSubmissionFeeInUsd().convertUsdToEth(
                AggregatorV3Interface(verifierConstructorParams.priceFeed)
            )
        }(ev.evidenceIpfsHash, ev.skillDomain);
        vm.stopPrank();

        vm.recordLogs();
        verifier._requestVerifiersSelection(ev);
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[0].topics[2];
        VRFCoordinatorV2Mock vrfCoordinatorMock = VRFCoordinatorV2Mock(
            verifierConstructorParams.vrfCoordinator
        );
        vm.pauseGasMetering();
        vm.recordLogs();
        vrfCoordinatorMock.fulfillRandomWords(
            uint256(requestId),
            address(verifier)
        );
        Vm.Log[] memory entriesOfFulfillRandomWords = vm.getRecordedLogs();
        bytes32 selectedVerifier = entriesOfFulfillRandomWords[1].topics[1];
        address selectedVerifierAddress = address(
            uint160(uint256(selectedVerifier))
        );

        vm.startPrank(selectedVerifierAddress);
        verifier.provideFeedback(FEEDBACK_IPFS_HASH, IPFS_HASH, USER, true);
        vm.stopPrank();

        bool[] memory statusApproveOrNot = verifier
            .getEvidenceToStatusApproveOrNot(IPFS_HASH);

        assertEq(statusApproveOrNot.length, 1);
        assertEq(statusApproveOrNot[0], true);

        bool selectedVerifierFeedbackStatus = verifier
            .getEvidenceToAllSelectedVerifiersToFeedbackStatus(
                IPFS_HASH,
                selectedVerifierAddress
            );

        assert(selectedVerifierFeedbackStatus);
    }

    function testProvideFeedbackEmitsEvidenceToStatusApproveOrNotUpdatedEvent()
        external
    {
        _createNumWordsNumberOfSameDomainVerifier(SKILL_DOMAINS);

        StructDefinition.VSkillUserEvidence memory ev = StructDefinition
            .VSkillUserEvidence(
                USER,
                IPFS_HASH,
                SKILL_DOMAINS[0],
                StructDefinition.VSkillUserSubmissionStatus.SUBMITTED,
                new string[](0)
            );
        vm.startPrank(USER);
        verifier.submitEvidence{
            value: verifier.getSubmissionFeeInUsd().convertUsdToEth(
                AggregatorV3Interface(verifierConstructorParams.priceFeed)
            )
        }(ev.evidenceIpfsHash, ev.skillDomain);
        vm.stopPrank();

        vm.recordLogs();
        verifier._requestVerifiersSelection(ev);
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[0].topics[2];
        VRFCoordinatorV2Mock vrfCoordinatorMock = VRFCoordinatorV2Mock(
            verifierConstructorParams.vrfCoordinator
        );
        vm.pauseGasMetering();
        vm.recordLogs();
        vrfCoordinatorMock.fulfillRandomWords(
            uint256(requestId),
            address(verifier)
        );
        Vm.Log[] memory entriesOfFulfillRandomWords = vm.getRecordedLogs();
        bytes32 selectedVerifier = entriesOfFulfillRandomWords[1].topics[1];
        address selectedVerifierAddress = address(
            uint160(uint256(selectedVerifier))
        );

        vm.startPrank(selectedVerifierAddress);
        vm.expectEmit(true, true, false, false, address(verifier));
        emit EvidenceToStatusApproveOrNotUpdated(IPFS_HASH, true);
        verifier.provideFeedback(FEEDBACK_IPFS_HASH, IPFS_HASH, USER, true);
        vm.stopPrank();
    }

    function testProvideFeedbackEmitsEvidenceToAllSelectedVerifiersToFeedbackStatusUpdatedEvent()
        external
    {
        _createNumWordsNumberOfSameDomainVerifier(SKILL_DOMAINS);

        StructDefinition.VSkillUserEvidence memory ev = StructDefinition
            .VSkillUserEvidence(
                USER,
                IPFS_HASH,
                SKILL_DOMAINS[0],
                StructDefinition.VSkillUserSubmissionStatus.SUBMITTED,
                new string[](0)
            );
        vm.startPrank(USER);
        verifier.submitEvidence{
            value: verifier.getSubmissionFeeInUsd().convertUsdToEth(
                AggregatorV3Interface(verifierConstructorParams.priceFeed)
            )
        }(ev.evidenceIpfsHash, ev.skillDomain);
        vm.stopPrank();

        vm.recordLogs();
        verifier._requestVerifiersSelection(ev);
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[0].topics[2];
        VRFCoordinatorV2Mock vrfCoordinatorMock = VRFCoordinatorV2Mock(
            verifierConstructorParams.vrfCoordinator
        );
        vm.pauseGasMetering();
        vm.recordLogs();
        vrfCoordinatorMock.fulfillRandomWords(
            uint256(requestId),
            address(verifier)
        );
        Vm.Log[] memory entriesOfFulfillRandomWords = vm.getRecordedLogs();
        bytes32 selectedVerifier = entriesOfFulfillRandomWords[1].topics[1];
        address selectedVerifierAddress = address(
            uint160(uint256(selectedVerifier))
        );

        vm.startPrank(selectedVerifierAddress);
        vm.expectEmit(true, true, true, false, address(verifier));
        emit EvidenceToAllSelectedVerifiersToFeedbackStatusUpdated(
            selectedVerifierAddress,
            IPFS_HASH,
            true
        );
        verifier.provideFeedback(FEEDBACK_IPFS_HASH, IPFS_HASH, USER, true);
        vm.stopPrank();
    }

    function testProvideFeedbackCallUpdateEvidenceStatusIfMoreThanNumWordsVerifiersSubmitFeedback()
        external
    {
        _createNumWordsNumberOfSameDomainVerifier(SKILL_DOMAINS);

        StructDefinition.VSkillUserEvidence memory ev = StructDefinition
            .VSkillUserEvidence(
                USER,
                IPFS_HASH,
                SKILL_DOMAINS[0],
                StructDefinition.VSkillUserSubmissionStatus.SUBMITTED,
                new string[](0)
            );
        vm.startPrank(USER);
        verifier.submitEvidence{
            value: verifier.getSubmissionFeeInUsd().convertUsdToEth(
                AggregatorV3Interface(verifierConstructorParams.priceFeed)
            )
        }(ev.evidenceIpfsHash, ev.skillDomain);
        vm.stopPrank();

        vm.recordLogs();
        verifier._requestVerifiersSelection(ev);
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[0].topics[2];
        VRFCoordinatorV2Mock vrfCoordinatorMock = VRFCoordinatorV2Mock(
            verifierConstructorParams.vrfCoordinator
        );
        vm.pauseGasMetering();
        vm.recordLogs();
        vrfCoordinatorMock.fulfillRandomWords(
            uint256(requestId),
            address(verifier)
        );
        Vm.Log[] memory entriesOfFulfillRandomWords = vm.getRecordedLogs();
        bytes32 selectedVerifierOne = entriesOfFulfillRandomWords[1].topics[1];
        bytes32 selectedVerifierTwo = entriesOfFulfillRandomWords[2].topics[1];
        bytes32 selectedVerifierThree = entriesOfFulfillRandomWords[3].topics[
            1
        ];
        address selectedVerifierAddressOne = address(
            uint160(uint256(selectedVerifierOne))
        );
        address selectedVerifierAddressTwo = address(
            uint160(uint256(selectedVerifierTwo))
        );
        address selectedVerifierAddressThree = address(
            uint160(uint256(selectedVerifierThree))
        );

        // all of them approve, this should set the status to approved

        vm.prank(selectedVerifierAddressOne);
        verifier.provideFeedback(FEEDBACK_IPFS_HASH, IPFS_HASH, USER, true);

        vm.prank(selectedVerifierAddressTwo);
        verifier.provideFeedback(FEEDBACK_IPFS_HASH, IPFS_HASH, USER, true);

        vm.prank(selectedVerifierAddressThree);
        verifier.provideFeedback(FEEDBACK_IPFS_HASH, IPFS_HASH, USER, true);

        StructDefinition.VSkillUserSubmissionStatus status = verifier
            .getEvidenceStatus(USER, 0);
        assertEq(uint256(status), uint256(SubmissionStatus.APPROVED));
    }

    function testProvideFeedbackUpdateEvidenceStatusToCorrectOne() external {
        _createNumWordsNumberOfSameDomainVerifier(SKILL_DOMAINS);

        StructDefinition.VSkillUserEvidence memory ev = StructDefinition
            .VSkillUserEvidence(
                USER,
                IPFS_HASH,
                SKILL_DOMAINS[0],
                StructDefinition.VSkillUserSubmissionStatus.SUBMITTED,
                new string[](0)
            );
        vm.startPrank(USER);
        verifier.submitEvidence{
            value: verifier.getSubmissionFeeInUsd().convertUsdToEth(
                AggregatorV3Interface(verifierConstructorParams.priceFeed)
            )
        }(ev.evidenceIpfsHash, ev.skillDomain);
        vm.stopPrank();

        vm.recordLogs();
        verifier._requestVerifiersSelection(ev);
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[0].topics[2];
        VRFCoordinatorV2Mock vrfCoordinatorMock = VRFCoordinatorV2Mock(
            verifierConstructorParams.vrfCoordinator
        );
        vm.pauseGasMetering();
        vm.recordLogs();
        vrfCoordinatorMock.fulfillRandomWords(
            uint256(requestId),
            address(verifier)
        );
        Vm.Log[] memory entriesOfFulfillRandomWords = vm.getRecordedLogs();
        bytes32 selectedVerifierOne = entriesOfFulfillRandomWords[1].topics[1];
        bytes32 selectedVerifierTwo = entriesOfFulfillRandomWords[2].topics[1];
        bytes32 selectedVerifierThree = entriesOfFulfillRandomWords[3].topics[
            1
        ];
        address selectedVerifierAddressOne = address(
            uint160(uint256(selectedVerifierOne))
        );
        address selectedVerifierAddressTwo = address(
            uint160(uint256(selectedVerifierTwo))
        );
        address selectedVerifierAddressThree = address(
            uint160(uint256(selectedVerifierThree))
        );

        // all of them not approve, this should set the status to rejected

        // vm.prank(selectedVerifierAddressOne);
        // verifier.provideFeedback(FEEDBACK_IPFS_HASH, IPFS_HASH, USER, false);

        // vm.prank(selectedVerifierAddressTwo);
        // verifier.provideFeedback(FEEDBACK_IPFS_HASH, IPFS_HASH, USER, false);

        // vm.prank(selectedVerifierAddressThree);
        // verifier.provideFeedback(FEEDBACK_IPFS_HASH, IPFS_HASH, USER, false);

        // StructDefinition.VSkillUserSubmissionStatus status = verifier
        //     .getEvidenceStatus(USER, 0);
        // assertEq(uint256(status), uint256(SubmissionStatus.REJECTED));

        // one of them approve, this should set the status to different opinion

        vm.prank(selectedVerifierAddressOne);
        verifier.provideFeedback(FEEDBACK_IPFS_HASH, IPFS_HASH, USER, true);

        vm.prank(selectedVerifierAddressTwo);
        verifier.provideFeedback(FEEDBACK_IPFS_HASH, IPFS_HASH, USER, false);

        vm.prank(selectedVerifierAddressThree);
        verifier.provideFeedback(FEEDBACK_IPFS_HASH, IPFS_HASH, USER, false);

        StructDefinition.VSkillUserSubmissionStatus status = verifier
            .getEvidenceStatus(USER, 0);
        assertEq(uint256(status), uint256(SubmissionStatus.DIFFERENTOPINION));
    }

    function testProvideFeedbackWithDifferentOpinionWillPunishWrongDecision()
        external
    {
        _createNumWordsNumberOfSameDomainVerifier(SKILL_DOMAINS);

        StructDefinition.VSkillUserEvidence memory ev = StructDefinition
            .VSkillUserEvidence(
                USER,
                IPFS_HASH,
                SKILL_DOMAINS[0],
                StructDefinition.VSkillUserSubmissionStatus.SUBMITTED,
                new string[](0)
            );
        vm.startPrank(USER);
        verifier.submitEvidence{
            value: verifier.getSubmissionFeeInUsd().convertUsdToEth(
                AggregatorV3Interface(verifierConstructorParams.priceFeed)
            )
        }(ev.evidenceIpfsHash, ev.skillDomain);
        vm.stopPrank();

        vm.recordLogs();
        verifier._requestVerifiersSelection(ev);
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[0].topics[2];
        VRFCoordinatorV2Mock vrfCoordinatorMock = VRFCoordinatorV2Mock(
            verifierConstructorParams.vrfCoordinator
        );
        vm.pauseGasMetering();
        vm.recordLogs();
        vrfCoordinatorMock.fulfillRandomWords(
            uint256(requestId),
            address(verifier)
        );
        Vm.Log[] memory entriesOfFulfillRandomWords = vm.getRecordedLogs();
        bytes32 selectedVerifierOne = entriesOfFulfillRandomWords[1].topics[1];
        bytes32 selectedVerifierTwo = entriesOfFulfillRandomWords[2].topics[1];
        bytes32 selectedVerifierThree = entriesOfFulfillRandomWords[3].topics[
            1
        ];
        address selectedVerifierAddressOne = address(
            uint160(uint256(selectedVerifierOne))
        );
        address selectedVerifierAddressTwo = address(
            uint160(uint256(selectedVerifierTwo))
        );
        address selectedVerifierAddressThree = address(
            uint160(uint256(selectedVerifierThree))
        );

        vm.prank(selectedVerifierAddressOne);
        verifier.provideFeedback(FEEDBACK_IPFS_HASH, IPFS_HASH, USER, true);

        vm.prank(selectedVerifierAddressTwo);
        verifier.provideFeedback(FEEDBACK_IPFS_HASH, IPFS_HASH, USER, false);

        vm.prank(selectedVerifierAddressThree);
        verifier.provideFeedback(FEEDBACK_IPFS_HASH, IPFS_HASH, USER, false);

        StructDefinition.VSkillUserSubmissionStatus status = verifier
            .getEvidenceStatus(USER, 0);
        assertEq(uint256(status), uint256(SubmissionStatus.DIFFERENTOPINION));

        // since it's different opinion, the chainlink node will notice this and call the checkUpkeep again

        vm.recordLogs();
        verifier._requestVerifiersSelection(ev);
        Vm.Log[] memory entriesNew = vm.getRecordedLogs();
        bytes32 requestIdNew = entriesNew[1].topics[1];
        VRFCoordinatorV2Mock vrfCoordinatorMockNew = VRFCoordinatorV2Mock(
            verifierConstructorParams.vrfCoordinator
        );
        vm.pauseGasMetering();
        vm.recordLogs();
        vrfCoordinatorMockNew.fulfillRandomWords(
            uint256(requestIdNew),
            address(verifier)
        );
        Vm.Log[] memory entriesOfFulfillRandomWordsNew = vm.getRecordedLogs();
        bytes32 selectedVerifierFour = entriesOfFulfillRandomWordsNew[1].topics[
            1
        ];
        bytes32 selectedVerifierFive = entriesOfFulfillRandomWordsNew[2].topics[
            1
        ];
        bytes32 selectedVerifierSix = entriesOfFulfillRandomWordsNew[3].topics[
            1
        ];
        address selectedVerifierFourAddress = address(
            uint160(uint256(selectedVerifierFour))
        );
        address selectedVerifierFiveAddress = address(
            uint160(uint256(selectedVerifierFive))
        );
        address selectedVerifierSixAddress = address(
            uint160(uint256(selectedVerifierSix))
        );

        // This time, we think this evidence is approved, so we will punish the wrong decision => selectedVerifierOne

        vm.prank(selectedVerifierFourAddress);
        verifier.provideFeedback(FEEDBACK_IPFS_HASH, IPFS_HASH, USER, true);

        vm.prank(selectedVerifierFiveAddress);
        verifier.provideFeedback(FEEDBACK_IPFS_HASH, IPFS_HASH, USER, true);

        vm.prank(selectedVerifierSixAddress);
        verifier.provideFeedback(FEEDBACK_IPFS_HASH, IPFS_HASH, USER, true);

        StructDefinition.VSkillUserSubmissionStatus statusNew = verifier
            .getEvidenceStatus(USER, 0);
        assertEq(uint256(statusNew), uint256(SubmissionStatus.APPROVED));
    }

    //////////////////////////////////////
    //    _verifiersWithinSameDomain    //
    //////////////////////////////////////
    function testVerifierWithinSameDomainOnlyRetureVerifierWithinSameDomainAndCorrectCount()
        external
        becomeVerifierWithSkillDomain(USER, SKILL_DOMAINS)
    {
        address verifierNotSameDomain = makeAddr("verifierNotSameDomain");
        vm.deal(verifierNotSameDomain, INITIAL_BALANCE);
        _becomeVerifierWithSkillDomain(
            verifierNotSameDomain,
            NEW_SKILL_DOMAINS
        );

        string memory expectedSkillDomain = SKILL_DOMAINS[0];
        (address[] memory verifiers, uint256 count) = verifier
            ._verifiersWithinSameDomain(expectedSkillDomain);

        assert(verifiers.length == 1);
        assert(count == 1);
        assert(verifiers[0] == USER);
    }

    //////////////////////////////////////
    //     _enoughNumberOfVerifiers     //
    //////////////////////////////////////

    function testEnoughNumberOfVerifiersWillRevertWithNotEnoughVerifiersIfNotEnoughVerifiers()
        external
        becomeVerifierWithSkillDomain(USER, SKILL_DOMAINS)
    {
        string memory skillDomain = SKILL_DOMAINS[0];
        vm.expectRevert(
            abi.encodeWithSelector(
                Verifier.Verifier__NotEnoughVerifiers.selector,
                1
            )
        );
        verifier._enoughNumberOfVerifiers(skillDomain);
    }

    function testEnoughNumberOfVerifiersWillRevertIfNotEnoughVerifierWithinSameDomain()
        external
        becomeVerifierWithSkillDomain(USER, SKILL_DOMAINS)
    {
        for (uint160 i = 1; i < uint160(NUM_WORDS); i++) {
            address verifierWithinSameDomain = address(i);
            vm.deal(verifierWithinSameDomain, INITIAL_BALANCE);
            _becomeVerifierWithSkillDomain(
                verifierWithinSameDomain,
                NEW_SKILL_DOMAINS
            );
        }

        string memory skillDomainNeeded = NEW_SKILL_DOMAINS[0];
        vm.expectRevert(
            abi.encodeWithSelector(
                Verifier.Verifier__NotEnoughVerifiers.selector,
                2
            )
        );
        verifier._enoughNumberOfVerifiers(skillDomainNeeded);
    }

    function testEnoughNumberOFVerifiersWillPassIfEnoughVerifiers()
        external
        becomeVerifierWithSkillDomain(USER, SKILL_DOMAINS)
    {
        for (uint160 i = 1; i < uint160(NUM_WORDS); i++) {
            address verifierWithinSameDomain = address(i);
            vm.deal(verifierWithinSameDomain, INITIAL_BALANCE);
            _becomeVerifierWithSkillDomain(
                verifierWithinSameDomain,
                SKILL_DOMAINS
            );
        }
        verifier._enoughNumberOfVerifiers(SKILL_DOMAINS[0]);
    }

    ////////////////////////
    //    A HUGE TEST     //
    ////////////////////////

    // The test below works, that is to say the VRF works, but it is not a good test

    function testRequestVerifiersSelection() external {
        _createNumWordsNumberOfSameDomainVerifier(SKILL_DOMAINS);

        address submitter = makeAddr("submitter");

        StructDefinition.VSkillUserEvidence memory ev = StructDefinition
            .VSkillUserEvidence(
                submitter,
                IPFS_HASH,
                SKILL_DOMAINS[0],
                StructDefinition.VSkillUserSubmissionStatus.SUBMITTED,
                new string[](0)
            );

        vm.recordLogs();
        verifier._requestVerifiersSelection(ev);
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[0].topics[2];
        VRFCoordinatorV2Mock vrfCoordinatorMock = VRFCoordinatorV2Mock(
            verifierConstructorParams.vrfCoordinator
        );
        vm.pauseGasMetering();
        vrfCoordinatorMock.fulfillRandomWords(
            uint256(requestId),
            address(verifier)
        );

        uint256[] memory randomWords = verifier.getRandomWords();
        assertEq(randomWords.length, uint256(3));
    }

    ///////////////////////////////////
    ///       Helper Functions      ///
    ///////////////////////////////////
    function _stakeToBeVerifier(address user) internal {
        uint256 minEthAmount = MIN_USD_AMOUNT_TO_STAKE.convertUsdToEth(
            AggregatorV3Interface(verifierConstructorParams.priceFeed)
        );
        vm.prank(user);
        verifier.stake{value: minEthAmount}();
    }

    function _becomeVerifierWithSkillDomain(
        address user,
        string[] memory skillDomains
    ) internal {
        _stakeToBeVerifier(user);
        vm.prank(user);
        verifier.updateSkillDomains(skillDomains);
    }

    function _createNumWordsNumberOfSameDomainVerifier(
        string[] memory skillDomain
    ) internal returns (address[] memory) {
        address[] memory verifierWithinSameDomain = new address[](NUM_WORDS);
        for (uint160 i = 1; i < uint160(NUM_WORDS + 1); i++) {
            address verifierAddress = address(i);
            vm.deal(verifierAddress, INITIAL_BALANCE);
            _becomeVerifierWithSkillDomain(verifierAddress, skillDomain);
            verifierWithinSameDomain[i - 1] = verifierAddress;
        }
        return verifierWithinSameDomain;
    }
}
