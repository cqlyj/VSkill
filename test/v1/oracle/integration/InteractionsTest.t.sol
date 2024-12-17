// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

// import {Test} from "forge-std/Test.sol";
// import {Distribution} from "src/oracle/Distribution.sol";
// import {DeployDistribution} from "script/oracle/DeployDistribution.s.sol";
// import {HelperConfig} from "script/oracle/HelperConfig.s.sol";
// import {DistributionRandomNumberForVerifiersDistribution} from "script/oracle/Interactions.s.sol";
// import {Vm} from "forge-std/Vm.sol";

// contract InteractionsTest is Test {
//     DeployDistribution deployDistribution;
//     HelperConfig helperConfig;
//     Distribution distribution;

//     function setUp() external {
//         deployDistribution = new DeployDistribution();
//         (distribution, helperConfig) = deployDistribution.run();
//     }

//     function testInteractionsDistribution() external {
//         DistributionRandomNumberForVerifiersDistribution distributionRandomNumberForVerifiersDistribution = new DistributionRandomNumberForVerifiersDistribution();
//         vm.recordLogs();
//         distributionRandomNumberForVerifiersDistribution
//             .distributionRandomNumberForVerifiers(address(distribution));
//         Vm.Log[] memory entries = vm.getRecordedLogs();
//         assertEq(entries.length, 2);
//     }
// }
