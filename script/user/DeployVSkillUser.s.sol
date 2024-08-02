// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {VSkillUser} from "../../src//user/VSkillUser.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployVSkillUser is Script {
    function run() external returns (VSkillUser, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        (uint256 submissionFeeInUsd, address priceFeed) = helperConfig
            .activeNetworkConfig();
        vm.startBroadcast();
        VSkillUser vSkill = new VSkillUser(submissionFeeInUsd, priceFeed);
        vm.stopBroadcast();
        return (vSkill, helperConfig);
    }
}
