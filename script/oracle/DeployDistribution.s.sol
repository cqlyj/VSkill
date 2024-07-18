// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {Distribution} from "../../src/oracle/Distribution.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscriptionDistribution, FundSubscriptionDistribution, AddConsumerDistribution} from "./Interactions.s.sol";

contract DeployDistribution is Script {
    function run() external returns (Distribution, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        (
            uint64 subscriptionId,
            address vrfCoordinator,
            bytes32 keyHash,
            uint32 callbackGasLimit,
            address linkTokenAddress,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();

        if (subscriptionId == 0) {
            // Create subscription
            CreateSubscriptionDistribution subscription = new CreateSubscriptionDistribution();
            subscriptionId = subscription.createSubscription(
                vrfCoordinator,
                deployerKey
            );

            // Fund subscription
            FundSubscriptionDistribution fund = new FundSubscriptionDistribution();
            fund.fundSubscription(
                vrfCoordinator,
                subscriptionId,
                linkTokenAddress,
                deployerKey
            );
        }

        vm.startBroadcast();
        Distribution distribution = new Distribution(
            subscriptionId,
            vrfCoordinator,
            keyHash,
            callbackGasLimit
        );
        vm.stopBroadcast();

        // Add consumer
        AddConsumerDistribution consumer = new AddConsumerDistribution();
        consumer.addConsumer(
            address(distribution),
            vrfCoordinator,
            subscriptionId,
            deployerKey
        );

        return (distribution, helperConfig);
    }
}
