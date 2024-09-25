// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Verifier} from "src/verifier/Verifier.sol";
import {DeployVerifier} from "script/verifier/DeployVerifier.s.sol";
import {HelperConfig} from "script/verifier/HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2Mock.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {PriceConverter} from "src/utils/PriceCoverter.sol";
import {Staking} from "src/staking/Staking.sol";

contract VerifierTest is Test {
    using PriceConverter for uint256;

    DeployVerifier deployer;
    Verifier verifier;
    HelperConfig helperConfig;

    address priceFeed;
    uint64 subscriptionId;
    address vrfCoordinator;
    bytes32 keyHash;
    uint32 callbackGasLimit;
    uint256 submissionFeeInUsd;
    string[] userNftImageUris;
    address linkTokenAddress;
    uint256 deployerKey;

    address public USER = makeAddr("user");
    uint256 private constant MIN_USD_AMOUNT_TO_STAKE = 20e18; // 20 USD
    string[] private NEW_SKILL_DOMAINS = ["newSkillDomain1", "newSkillDomain2"];
    uint256 private constant INITIAL_BALANCE = 100 ether;

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
        (
            priceFeed,
            subscriptionId,
            vrfCoordinator,
            keyHash,
            callbackGasLimit,
            submissionFeeInUsd,
            linkTokenAddress,
            deployerKey
        ) = helperConfig.activeNetworkConfig();

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
        address indexed verifierAddress,
        address indexed user,
        bool indexed approved,
        string feedbackIpfsHash,
        string evidenceIpfsHash
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

    modifier stakeToBeVerifier() {
        uint256 minEthAmount = MIN_USD_AMOUNT_TO_STAKE.convertUsdToEth(
            AggregatorV3Interface(priceFeed)
        );
        vm.prank(USER);
        verifier.stake{value: minEthAmount}();
        _;
    }

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
        stakeToBeVerifier
    {
        vm.prank(USER);
        verifier.updateSkillDomains(NEW_SKILL_DOMAINS);

        assert(
            NEW_SKILL_DOMAINS.length ==
                verifier.getVerifierSkillDomains(USER).length
        );
    }

    function testUpdateSkillDomainsEmitsVerifierSkillDomainUpdatedEvent()
        external
        stakeToBeVerifier
    {
        vm.prank(USER);

        vm.expectEmit(true, false, false, true, address(verifier));
        emit VerifierSkillDomainUpdated(USER, NEW_SKILL_DOMAINS);
        verifier.updateSkillDomains(NEW_SKILL_DOMAINS);
    }

    //////////////////////////////////////
    //    _verifiersWithinSameDomain    //
    //////////////////////////////////////
}
