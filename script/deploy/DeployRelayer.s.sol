// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {Relayer} from "src/Relayer.sol";
import {Vm} from "forge-std/Vm.sol";

contract DeployRelayer is Script {
    address public vSkillUser;
    address public distribution;
    address public verifier;
    address public vSkillUserNft;

    function _deployRelayer(
        address _vSkillUser,
        address _verifier,
        address _vSkillUserNft,
        address _distribution
    ) internal returns (address) {
        vm.startBroadcast();
        Relayer relayer = new Relayer(
            _vSkillUser,
            _verifier,
            _vSkillUserNft,
            _distribution
        );
        vm.stopBroadcast();

        console.log("Relayer deployed at: ", address(relayer));

        return address(relayer);
    }

    function run() external returns (Relayer) {
        vSkillUser = Vm(address(vm)).getDeployment(
            "VSkillUser",
            uint64(block.chainid)
        );
        verifier = Vm(address(vm)).getDeployment(
            "Verifier",
            uint64(block.chainid)
        );
        vSkillUserNft = Vm(address(vm)).getDeployment(
            "VSkillUserNft",
            uint64(block.chainid)
        );
        distribution = Vm(address(vm)).getDeployment(
            "Distribution",
            uint64(block.chainid)
        );

        address relayerAddress = _deployRelayer(
            vSkillUser,
            verifier,
            vSkillUserNft,
            distribution
        );

        return Relayer(relayerAddress);
    }
}
