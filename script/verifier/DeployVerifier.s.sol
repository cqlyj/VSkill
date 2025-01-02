// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

// import {Script} from "forge-std/Script.sol";
// import {CreateSubscriptionDistribution, FundSubscriptionDistribution, AddConsumerDistribution} from "./Interactions.s.sol";
// import {Verifier} from "../../src/verifier/Verifier.sol";
// import {HelperConfig} from "./HelperConfig.s.sol";
// import {StructDefinition} from "../../src/utils/library/StructDefinition.sol";

// contract DeployVerifier is Script {
//     using StructDefinition for StructDefinition.VerifierConstructorParams;

//     function run() external returns (Verifier, HelperConfig) {
//         HelperConfig helperConfig = new HelperConfig();
//         (
//             address priceFeed,
//             uint64 subscriptionId,
//             address vrfCoordinator,
//             bytes32 keyHash,
//             uint32 callbackGasLimit,
//             uint256 submissionFeeInUsd,
//             address linkTokenAddress,
//             uint256 deployerKey
//         ) = helperConfig.activeNetworkConfig();

//         string[] memory userNftImageUris = helperConfig
//             .getActiveNetworkConfig()
//             .userNftImageUris;

//         if (subscriptionId == 0) {
//             // Create subscription
//             CreateSubscriptionDistribution subscription = new CreateSubscriptionDistribution();
//             subscriptionId = subscription.createSubscription(
//                 vrfCoordinator,
//                 deployerKey
//             );

//             // Fund subscription
//             FundSubscriptionDistribution fund = new FundSubscriptionDistribution();
//             fund.fundSubscription(
//                 vrfCoordinator,
//                 subscriptionId,
//                 linkTokenAddress,
//                 deployerKey
//             );
//         }

//         StructDefinition.VerifierConstructorParams
//             memory params = StructDefinition.VerifierConstructorParams({
//                 priceFeed: priceFeed,
//                 subscriptionId: subscriptionId,
//                 vrfCoordinator: vrfCoordinator,
//                 keyHash: keyHash,
//                 callbackGasLimit: callbackGasLimit,
//                 submissionFeeInUsd: submissionFeeInUsd,
//                 userNftImageUris: userNftImageUris
//             });

//         vm.startBroadcast();
//         Verifier verifier = new Verifier(params);
//         vm.stopBroadcast();

//         // Add consumer
//         AddConsumerDistribution consumer = new AddConsumerDistribution();
//         consumer.addConsumer(
//             address(verifier),
//             vrfCoordinator,
//             subscriptionId,
//             deployerKey
//         );

//         return (verifier, helperConfig);
//     }
// }
