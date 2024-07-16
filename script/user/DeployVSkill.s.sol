// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {VSkill} from "../../src//user/VSkill.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployVSkill is Script {
    function run() external returns (VSkill, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        (uint256 submissionFeeInUsd, address priceFeed) = helperConfig
            .activeNetworkConfig();
        vm.startBroadcast();
        VSkill vSkill = new VSkill(submissionFeeInUsd, priceFeed);
        vm.stopBroadcast();
        return (vSkill, helperConfig);
    }
}
