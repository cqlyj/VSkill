// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {Distribution} from "src/Distribution.sol";
import {DistributionHelperConfig} from "../helperConfig/DistributionHelperConfig.s.sol";
import {AddConsumer} from "../interactions/VRFInteractions/AddConsumer.s.sol";
import {CreateSubscription} from "../interactions/VRFInteractions/CreateSubscription.s.sol";
import {FundSubscription} from "../interactions/VRFInteractions/FundSubscription.s.sol";

// Before deploy this script, please make sure that the subscription is created and funded
contract DeployDistribution is Script {
    function run() external returns (Distribution, DistributionHelperConfig) {
        DistributionHelperConfig helperConfig = new DistributionHelperConfig();
        (
            uint256 subscriptionId,
            address vrfCoordinator,
            bytes32 keyHash,
            uint32 callbackGasLimit,
            address linkToken
        ) = helperConfig.activeNetworkConfig();

        // these below are commented out because they are not needed in the script for deployment
        // they should be handled in the script for interactions before this deployment script is run
        // @update these below are commented out because they are not needed in the script for deployment

        if (subscriptionId == 0) {
            // Create subscription
            CreateSubscription subscription = new CreateSubscription();
            (subscriptionId, ) = subscription.createSubscription(
                vrfCoordinator
            );

            helperConfig.setActiveNetworkSubscriptionId(subscriptionId);

            // Fund subscription
            FundSubscription fund = new FundSubscription();
            fund.fundSubscription(vrfCoordinator, subscriptionId, linkToken);
        }

        vm.startBroadcast();
        Distribution distribution = new Distribution(
            subscriptionId,
            keyHash,
            callbackGasLimit,
            vrfCoordinator
        );
        vm.stopBroadcast();

        console.log("Distribution deployed at: ", address(distribution));

        // // Add consumer
        AddConsumer consumer = new AddConsumer();
        consumer.addConsumer(
            address(distribution),
            vrfCoordinator,
            subscriptionId
        );

        return (distribution, helperConfig);
    }
}
