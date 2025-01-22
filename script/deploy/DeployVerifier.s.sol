// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {Verifier} from "src/Verifier.sol";
import {VerifierHelperConfig} from "../helperConfig/VerifierHelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";

contract DeployVerifier is Script {
    function deployVerifier(
        address priceFeed,
        string[] memory skillDomains,
        address vSkillUser
    ) public returns (Verifier) {
        vm.startBroadcast();
        Verifier verifier = new Verifier(priceFeed, skillDomains, vSkillUser);
        vm.stopBroadcast();

        console.log("Verifier deployed at: ", address(verifier));

        return verifier;
    }

    function run() external returns (Verifier, VerifierHelperConfig) {
        VerifierHelperConfig helperConfig = new VerifierHelperConfig();
        address priceFeed = helperConfig.getActiveNetworkConfig().priceFeed;
        string[] memory skillDomains = helperConfig
            .getActiveNetworkConfig()
            .skillDomains;
        address vSkillUser = Vm(address(vm)).getDeployment(
            "VSkillUser",
            uint64(block.chainid)
        );

        Verifier verifier = deployVerifier(priceFeed, skillDomains, vSkillUser);

        return (verifier, helperConfig);
    }
}
