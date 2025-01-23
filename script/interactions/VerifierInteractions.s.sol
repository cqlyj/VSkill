// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {Verifier} from "src/Verifier.sol";
import {Vm} from "forge-std/Vm.sol";

contract Stake is Script {
    function stake(address verifier) public {
        vm.startBroadcast();

        Verifier verifierInstance = Verifier(payable(verifier));
        verifierInstance.stake{value: verifierInstance.getStakeEthAmount()}();

        vm.stopBroadcast();

        console.log("Stake successful on chain id: ", block.chainid);
    }

    function run() external {
        address verifier = Vm(address(vm)).getDeployment(
            "Verifier",
            uint64(block.chainid)
        );

        stake(verifier);
    }
}

contract AddSkillDomain is Script {
    // @notice: Update this skillDomain to the skillDomain you want to add!
    string skillDomain = "Blockchain";

    function addSkillDomain(address verifier) public {
        vm.startBroadcast();

        Verifier verifierInstance = Verifier(payable(verifier));
        verifierInstance.addSkillDomain(skillDomain);

        vm.stopBroadcast();

        console.log(
            "Skill domain added successfully on chain id: ",
            block.chainid,
            " with skill domain: ",
            skillDomain
        );
    }

    function run() external {
        address verifier = Vm(address(vm)).getDeployment(
            "Verifier",
            uint64(block.chainid)
        );

        addSkillDomain(verifier);
    }
}

contract WithdrawStakeAndLoseVerifier is Script {
    function withdrawStakeAndLoseVerifier(address verifier) public {
        vm.startBroadcast();

        Verifier verifierInstance = Verifier(payable(verifier));
        verifierInstance.withdrawStakeAndLoseVerifier();

        vm.stopBroadcast();

        console.log(
            "Stake withdrawn and verifier lost on chain id: ",
            block.chainid
        );
    }

    function run() external {
        address verifier = Vm(address(vm)).getDeployment(
            "Verifier",
            uint64(block.chainid)
        );

        withdrawStakeAndLoseVerifier(verifier);
    }
}
