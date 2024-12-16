// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {DeployDistribution} from "script/oracle/DeployDistribution.s.sol";
import {Distribution} from "src/oracle/Distribution.sol";
import {HelperConfig} from "script/oracle/HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2Mock.sol";
import {Vm} from "forge-std/Vm.sol";
import {StructDefinition} from "src/utils/library/StructDefinition.sol";

contract DistributionTest is Test {
    using StructDefinition for StructDefinition.VSkillUserEvidence;

    DeployDistribution deployer;
    Distribution distribution;
    HelperConfig helperConfig;
    uint64 subscriptionId;
    address vrfCoordinator;
    bytes32 keyHash;
    uint32 callbackGasLimit;
    uint32 numWords = 3;
    address linkTokenAddress;
    uint256 deployerKey;

    string public constant IPFS_HASH =
        "https://ipfs.io/ipfs/QmbJLndDmDiwdotu3MtfcjC2hC5tXeAR9EXbNSdUDUDYWa";
    string[] private SKILL_DOMAINS = ["skillDomain1", "skillDomain2"];
    address private verifierContractAddress;
    address private SUBMITTER = makeAddr("submitter");
    StructDefinition.VSkillUserEvidence private EV =
        StructDefinition.VSkillUserEvidence(
            SUBMITTER,
            IPFS_HASH,
            SKILL_DOMAINS[0],
            StructDefinition.VSkillUserSubmissionStatus.SUBMITTED,
            new string[](0)
        );

    // For now, just test on non-mainnet forks -> After figuered out why mainnet fork is not working, remove this modifier
    modifier skipMainnetForkingTest() {
        if (block.chainid == 1) {
            return;
        }
        _;
    }

    function setUp() external skipMainnetForkingTest {
        deployer = new DeployDistribution();
        (distribution, helperConfig) = deployer.run();
        (
            subscriptionId,
            vrfCoordinator,
            keyHash,
            callbackGasLimit,
            linkTokenAddress,
            deployerKey
        ) = helperConfig.activeNetworkConfig();
    }

    ////////////////////////////////////////////////
    //    distributionRandomNumberForVerifiers    //
    ////////////////////////////////////////////////

    function testDistributionRandomNumberForVerifiersEmitsRandomWordsRequested()
        external
    {
        vm.recordLogs();
        distribution.distributionRandomNumberForVerifiers(SUBMITTER, EV);
        Vm.Log[] memory entries = vm.getRecordedLogs();

        bytes32 requestId = entries[0].topics[2];
        assertEq(uint256(requestId), 1);
    }

    function testDistributionRandomNumberForVerifiersEmitsTwoEvents() external {
        vm.recordLogs();
        distribution.distributionRandomNumberForVerifiers(SUBMITTER, EV);
        Vm.Log[] memory entries = vm.getRecordedLogs();

        assertEq(entries.length, 2);
    }

    function testDistributionRandomNumberForVerifiersEmitsRequestIdToContextUpdatedEvent()
        external
    {
        vm.recordLogs();
        distribution.distributionRandomNumberForVerifiers(SUBMITTER, EV);
        Vm.Log[] memory entries = vm.getRecordedLogs();

        bytes32 requestId = entries[0].topics[2];
        bytes32 requestIdFromRequestIdToContext = entries[1].topics[1];
        assertEq(requestId, requestIdFromRequestIdToContext);
    }

    function testDistributionRandomNumberForVerifiersUpdatesRequestIdToContext()
        external
    {
        vm.recordLogs();
        distribution.distributionRandomNumberForVerifiers(SUBMITTER, EV);
        Vm.Log[] memory entries = vm.getRecordedLogs();

        bytes32 requestId = entries[0].topics[2];
        StructDefinition.DistributionVerifierRequestContext
            memory context = distribution.getRequestIdToContext(
                uint256(requestId)
            );
        assertEq(context.requester, SUBMITTER);
        assert(
            keccak256(abi.encodePacked(context.ev.evidenceIpfsHash)) ==
                keccak256(abi.encodePacked(IPFS_HASH))
        );
    }

    ////////////////////////////////
    //     fulfillRandomWords     //
    ////////////////////////////////

    // Will be tested in the verifier test
}
