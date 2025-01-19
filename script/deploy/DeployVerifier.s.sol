// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {Verifier} from "src/Verifier.sol";
import {VerifierHelperConfig} from "../helperConfig/VerifierHelperConfig.s.sol";

contract DeployVerifier is Script {
    function run() external returns (Verifier, VerifierHelperConfig) {
        VerifierHelperConfig helperConfig = new VerifierHelperConfig();
        address priceFeed = helperConfig.getActiveNetworkConfig().priceFeed;
        string[] memory skillDomains = helperConfig
            .getActiveNetworkConfig()
            .skillDomains;
        address vSkillUser = helperConfig.getActiveNetworkConfig().vSkillUser;

        vm.startBroadcast();
        Verifier verifier = new Verifier(priceFeed, skillDomains, vSkillUser);
        vm.stopBroadcast();

        console.log("Verifier deployed at: ", address(verifier));

        return (verifier, helperConfig);
    }
}
