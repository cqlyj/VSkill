// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {DistributionHelperConfig} from "../../helperConfig/DistributionHelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract AddConsumer is Script {
    function addConsumer(
        address _distribution,
        address _vrfCoordinator,
        uint256 _subId
    ) public {
        console.log(
            "Contract Distribution address: ",
            _distribution,
            "is ready to be added as a consumer!"
        );
        console.log("On chain ID: ", block.chainid);

        vm.startBroadcast();

        VRFCoordinatorV2_5Mock(_vrfCoordinator).addConsumer(
            _subId,
            _distribution
        );

        vm.stopBroadcast();

        console.log("Consumer added!");
    }

    function run() external {
        DistributionHelperConfig helperConfig = new DistributionHelperConfig();
        address vrfCoordinator = helperConfig
            .getActiveNetworkConfig()
            .vrfCoordinator;

        uint256 subId = helperConfig.getActiveNetworkConfig().subscriptionId;

        address mostRecentDeployedDistribution = Vm(address(vm)).getDeployment(
            "Distribution",
            uint64(block.chainid)
        );

        addConsumer(mostRecentDeployedDistribution, vrfCoordinator, subId);
    }
}
