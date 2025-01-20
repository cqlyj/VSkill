// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {VSkillUser} from "src/VSkillUser.sol";
import {VSkillUserHelperConfig} from "../helperConfig/VSkillUserHelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {DeployDistribution} from "./DeployDistribution.s.sol";
import {Distribution} from "src/Distribution.sol";

contract DeployVSkillUser is Script {
    function run() external returns (VSkillUser, VSkillUserHelperConfig) {
        VSkillUserHelperConfig helperConfig = new VSkillUserHelperConfig();
        DeployDistribution deployDistribution = new DeployDistribution();

        (uint256 submissionFeeInUsd, address priceFeed) = helperConfig
            .activeNetworkConfig();

        // require that the distribution contract is deployed first
        (Distribution distribution, ) = deployDistribution.run();

        vm.startBroadcast();
        VSkillUser vSkillUser = new VSkillUser(
            submissionFeeInUsd,
            priceFeed,
            address(distribution)
        );
        vm.stopBroadcast();

        console.log("VSkillUser deployed at: ", address(vSkillUser));

        return (vSkillUser, helperConfig);
    }
}
