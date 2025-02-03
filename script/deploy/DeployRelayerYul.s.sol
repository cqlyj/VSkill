// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {RelayerYul} from "src/optimizedGas/RelayerYul.sol";
import {Vm} from "forge-std/Vm.sol";

contract DeployRelayerYul is Script {
    address public vSkillUser;
    address public distribution;
    address public verifier;
    address public vSkillUserNft;

    function deployRelayerYul(
        address _vSkillUser,
        address _distribution,
        address _verifier,
        address _vSkillUserNft
    ) public returns (address) {
        vm.startBroadcast();
        RelayerYul relayerYul = new RelayerYul(
            _vSkillUser,
            _distribution,
            _verifier,
            _vSkillUserNft
        );
        vm.stopBroadcast();

        console.log("RelayerYul deployed at: ", address(relayerYul));

        return address(relayerYul);
    }

    function run() external returns (RelayerYul) {
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

        address relayerYulAddress = deployRelayerYul(
            vSkillUser,
            distribution,
            verifier,
            vSkillUserNft
        );

        return RelayerYul(relayerYulAddress);
    }
}
