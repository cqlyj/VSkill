// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {DistributionHelperConfig} from "../../helperConfig/DistributionHelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract CreateSubscription is Script {
    function createSubscription(
        address _vrfCoordinator
    ) public returns (uint256, address) {
        console.log("Creating subscription at chain ID: ", block.chainid);

        vm.startBroadcast();
        uint256 subId = VRFCoordinatorV2_5Mock(_vrfCoordinator)
            .createSubscription();
        vm.stopBroadcast();

        console.log("Subscription ID: ", subId);
        console.log(
            "Please update the subscription ID in the HelperConfig contract!"
        );

        return (subId, _vrfCoordinator);
    }

    function run() external returns (uint256, address) {
        DistributionHelperConfig helperConfig = new DistributionHelperConfig();
        address vrfCoordinator = helperConfig
            .getActiveNetworkConfig()
            .vrfCoordinator;

        (uint256 subId, ) = createSubscription(vrfCoordinator);

        return (subId, vrfCoordinator);
    }
}
