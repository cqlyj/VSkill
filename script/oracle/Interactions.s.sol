// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

// import {Script, console} from "forge-std/Script.sol";
// import {HelperConfig} from "./HelperConfig.s.sol";
// import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2Mock.sol";
// import {MockLinkToken} from "@chainlink/contracts/src/v0.8/mocks/MockLinkToken.sol";
// import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";
// import {Distribution} from "src/oracle/Distribution.sol";
// import {StructDefinition} from "src/utils/library/StructDefinition.sol";

// contract CreateSubscriptionDistribution is Script {
//     function createSubscriptionWithConfig() internal returns (uint64) {
//         HelperConfig helperConfig = new HelperConfig();
//         (, address vrfCoordinator, , , , uint256 deployerKey) = helperConfig
//             .activeNetworkConfig();
//         return createSubscription(vrfCoordinator, deployerKey);
//     }

//     function createSubscription(
//         address vrfCoordinator,
//         uint256 deployerKey
//     ) public returns (uint64) {
//         console.log("Creating subscription on chainid: ", block.chainid);

//         vm.startBroadcast(deployerKey);

//         uint64 subId = VRFCoordinatorV2Mock(vrfCoordinator)
//             .createSubscription();

//         vm.stopBroadcast();

//         console.log("Subscription ID: ", subId);
//         console.log(
//             "Please update the subscription ID in the HelperConfig contract!"
//         );
//         return subId;
//     }

//     function run() external returns (uint64) {
//         return createSubscriptionWithConfig();
//     }
// }

// contract FundSubscriptionDistribution is Script {
//     uint96 public constant FUND_AMOUNT = 3 ether;

//     function fundSubscriptionWithConfig() internal {
//         HelperConfig helperConfig = new HelperConfig();
//         (
//             uint64 subscriptionId,
//             address vrfCoordinator,
//             ,
//             ,
//             address linkTokenAddress,
//             uint256 deployerKey
//         ) = helperConfig.activeNetworkConfig();

//         fundSubscription(
//             vrfCoordinator,
//             subscriptionId,
//             linkTokenAddress,
//             deployerKey
//         );
//     }

//     function fundSubscription(
//         address vrfCoordinator,
//         uint64 subscriptionId,
//         address linkTokenAddress,
//         uint256 deployerKey
//     ) public {
//         console.log("Funding subscription: ", subscriptionId);
//         console.log("Using vrfCoordinator: ", vrfCoordinator);
//         console.log("ChainId:", block.chainid);

//         if (block.chainid == 31337) {
//             vm.startBroadcast(deployerKey);

//             VRFCoordinatorV2Mock(vrfCoordinator).fundSubscription(
//                 subscriptionId,
//                 FUND_AMOUNT
//             );

//             vm.stopBroadcast();
//         } else {
//             vm.startBroadcast(deployerKey);

//             MockLinkToken(linkTokenAddress).transferAndCall(
//                 vrfCoordinator,
//                 FUND_AMOUNT,
//                 abi.encode(subscriptionId)
//             );

//             vm.stopBroadcast();
//         }
//     }

//     function run() external {
//         fundSubscriptionWithConfig();
//     }
// }

// contract AddConsumerDistribution is Script {
//     function addConsumerUsingConfig(address mostRecentlyDeployed) internal {
//         HelperConfig helperConfig = new HelperConfig();
//         (
//             uint64 subscriptionId,
//             address vrfCoordinator,
//             ,
//             ,
//             ,
//             uint256 deployerKey
//         ) = helperConfig.activeNetworkConfig();
//         addConsumer(
//             mostRecentlyDeployed,
//             vrfCoordinator,
//             subscriptionId,
//             deployerKey
//         );
//     }

//     function addConsumer(
//         address mostRecentlyDeployed,
//         address vrfCoordinator,
//         uint64 subscriptionId,
//         uint256 deployerKey
//     ) public {
//         console.log("Adding consumer to Distribution: ", mostRecentlyDeployed);
//         console.log("Using vrfCoordinator: ", vrfCoordinator);
//         console.log("On chainId: ", block.chainid);
//         console.log("Subscription ID: ", subscriptionId);

//         vm.startBroadcast(deployerKey);

//         VRFCoordinatorV2Mock(vrfCoordinator).addConsumer(
//             subscriptionId,
//             mostRecentlyDeployed
//         );

//         vm.stopBroadcast();
//     }

//     function run() external {
//         address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
//             "Distribution",
//             block.chainid
//         );

//         addConsumerUsingConfig(mostRecentlyDeployed);
//     }
// }

// contract DistributionRandomNumberForVerifiersDistribution is Script {
//     using StructDefinition for StructDefinition.VSkillUserEvidence;
//     using StructDefinition for StructDefinition.VSkillUserSubmissionStatus;

//     address public requester = makeAddr("requester");
//     address public submitter = makeAddr("submitter");
//     string constant EVIDENCE_IPFS_HASH = "evidenceIpfsHash";
//     string constant SKILLDOMAIN = "frontEnd";
//     StructDefinition.VSkillUserSubmissionStatus status =
//         StructDefinition.VSkillUserSubmissionStatus.SUBMITTED;
//     string[] feedbackIpfsHash;
//     StructDefinition.VSkillUserEvidence public ev =
//         StructDefinition.VSkillUserEvidence(
//             submitter,
//             EVIDENCE_IPFS_HASH,
//             SKILLDOMAIN,
//             status,
//             feedbackIpfsHash
//         );

//     function distributionRandomNumberForVerifiers(
//         address mostRecentlyDeployed
//     ) public {
//         vm.startBroadcast();
//         Distribution distribution = Distribution(mostRecentlyDeployed);
//         distribution.distributionRandomNumberForVerifiers(requester, ev);
//         vm.stopBroadcast();
//     }

//     function run() external {
//         address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
//             "Distribution",
//             block.chainid
//         );

//         console.log(
//             "Using most recently deployed Distribution: ",
//             mostRecentlyDeployed
//         );

//         distributionRandomNumberForVerifiers(mostRecentlyDeployed);
//     }
// }
