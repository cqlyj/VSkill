// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {DeployDistribution} from "script/oracle/DeployDistribution.s.sol";
import {Distribution} from "src/oracle/Distribution.sol";
import {HelperConfig} from "script/oracle/HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2Mock.sol";
import {Vm} from "forge-std/Vm.sol";

contract DistributionTest is Test {
    DeployDistribution deployer;
    Distribution distribution;
    HelperConfig helperConfig;
    uint64 subscriptionId;
    address vrfCoordinator;
    bytes32 keyHash;
    uint32 callbackGasLimit;
    uint16 requestConfirmations;
    uint32 numWords = 3;
    address linkTokenAddress;
    uint256 deployerKey;

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

    function testFulfillRandomWordsUpdatesRandomWords()
        external
        skipMainnetForkingTest
    {
        vm.recordLogs();
        distribution.distributionRandomNumberForVerifiers();
        Vm.Log[] memory entries = vm.getRecordedLogs();

        bytes32 requestId = entries[0].topics[2];
        VRFCoordinatorV2Mock vrfCoordinatorMock = VRFCoordinatorV2Mock(
            vrfCoordinator
        );
        vrfCoordinatorMock.fulfillRandomWords(
            uint256(requestId),
            address(distribution)
        );
        uint256[] memory randomWords = distribution.getRandomWords();
        assertEq(randomWords.length, uint256(numWords));
    }
}
