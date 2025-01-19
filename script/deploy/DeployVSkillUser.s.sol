// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {VSkillUser} from "src/VSkillUser.sol";
import {VSkillUserHelperConfig} from "../helperConfig/VSkillUserHelperConfig.s.sol";

contract DeployVSkillUser is Script {
    function run() external returns (VSkillUser, VSkillUserHelperConfig) {
        VSkillUserHelperConfig helperConfig = new VSkillUserHelperConfig();
        (
            uint256 submissionFeeInUsd,
            address priceFeed,
            address distributionAddress
        ) = helperConfig.activeNetworkConfig();

        vm.startBroadcast();
        VSkillUser vSkillUser = new VSkillUser(
            submissionFeeInUsd,
            priceFeed,
            distributionAddress
        );
        vm.stopBroadcast();

        console.log("VSkillUser deployed at: ", address(vSkillUser));

        return (vSkillUser, helperConfig);
    }
}
