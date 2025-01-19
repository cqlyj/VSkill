// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {VSkillUserNft} from "src/VSkillUserNft.sol";
import {VSkillUserNftHelperConfig} from "../helperConfig/VSkillUserNftHelperConfig.s.sol";

contract DeployVSkillUserNft is Script {
    function run() external returns (VSkillUserNft, VSkillUserNftHelperConfig) {
        VSkillUserNftHelperConfig helperConfig = new VSkillUserNftHelperConfig();
        string[] memory skillDomains = helperConfig
            .getActiveNetworkConfig()
            .skillDomains;
        string[] memory userNftImageUris = helperConfig
            .getActiveNetworkConfig()
            .userNftImageUris;

        vm.startBroadcast();
        VSkillUserNft vskillUserNft = new VSkillUserNft(
            skillDomains,
            userNftImageUris
        );
        vm.stopBroadcast();

        console.log("Deployed VSkillUserNft at: ", address(vskillUserNft));

        return (vskillUserNft, helperConfig);
    }
}
