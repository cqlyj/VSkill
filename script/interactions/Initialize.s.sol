// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {VSkillUser} from "src/VSkillUser.sol";
import {VSkillUserNft} from "src/VSkillUserNft.sol";
import {Verifier} from "src/Verifier.sol";
import {Relayer} from "src/Relayer.sol";
import {RelayerHelperConfig} from "../helperConfig/RelayerHelperConfig.s.sol";
import {MockRegistry} from "test/mock/MockRegistry.sol";
import {Vm} from "forge-std/Vm.sol";

// This script will initialize the contracts to be ready for interacting
contract Initialize is Script {
    address public vSkillUserAddress;
    address public vSkillUserNftAddress;
    address public verifierAddress;
    address public relayerAddress;

    function _getContractAddress()
        internal
        returns (address, address, address, address)
    {
        vSkillUserAddress = Vm(address(vm)).getDeployment(
            "VSkillUser",
            uint64(block.chainid)
        );
        vSkillUserNftAddress = Vm(address(vm)).getDeployment(
            "VSkillUserNft",
            uint64(block.chainid)
        );
        verifierAddress = Vm(address(vm)).getDeployment(
            "Verifier",
            uint64(block.chainid)
        );
        relayerAddress = Vm(address(vm)).getDeployment(
            "Relayer",
            uint64(block.chainid)
        );

        return (
            vSkillUserAddress,
            vSkillUserNftAddress,
            verifierAddress,
            relayerAddress
        );
    }

    function _initializeToRelayer(
        VSkillUser vSkillUser,
        VSkillUserNft vSkillUserNft,
        Verifier verifier,
        address relayer
    ) internal {
        vm.startBroadcast();

        vSkillUser.initializeRelayer(relayer);
        vSkillUserNft.initializeRelayer(relayer);
        verifier.initializeRelayer(relayer);

        vm.stopBroadcast();

        console.log("Initialized contracts to Relayer");
    }

    function _initializeToForwarder(
        address registry,
        uint256 upkeepId,
        Relayer relayer
    ) internal {
        console.log(
            "Initializing contracts to Forwarder with upkeepId: ",
            upkeepId
        );
        // upkeepId = 0 implies that we are on testnet, deploy mock Registry
        if (upkeepId == 0) {
            vm.startBroadcast();
            MockRegistry mockRegistry = new MockRegistry();
            address forwarder = mockRegistry.getForwarder(upkeepId);
            relayer.setForwarder(forwarder);
            vm.stopBroadcast();

            console.log(
                "Initialized contracts to Forwarder address: ",
                forwarder
            );
        } else {
            // here we have the real registry address
            vm.startBroadcast();
            MockRegistry mockRegistry = MockRegistry(registry);
            address forwarder = mockRegistry.getForwarder(upkeepId);
            relayer.setForwarder(forwarder);
            vm.stopBroadcast();

            console.log(
                "Initialized contracts to Forwarder address: ",
                forwarder
            );
        }
    }

    function run() external {
        (
            vSkillUserAddress,
            vSkillUserNftAddress,
            verifierAddress,
            relayerAddress
        ) = _getContractAddress();

        RelayerHelperConfig relayerHelperConfig = new RelayerHelperConfig();

        address registry = relayerHelperConfig
            .getActiveNetworkConfig()
            .registryAddress;
        uint256 upkeepId = relayerHelperConfig
            .getActiveNetworkConfig()
            .upkeepId;

        _initializeToRelayer(
            VSkillUser(payable(vSkillUserAddress)),
            VSkillUserNft(vSkillUserNftAddress),
            Verifier(payable(verifierAddress)),
            relayerAddress
        );

        _initializeToForwarder(registry, upkeepId, Relayer(relayerAddress));

        console.log("Initialization completed!!!");
    }
}
