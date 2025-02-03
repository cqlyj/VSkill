// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {VSkillUser} from "src/VSkillUser.sol";
import {VSkillUserNft} from "src/VSkillUserNft.sol";
import {Verifier} from "src/Verifier.sol";
import {Relayer} from "src/Relayer.sol";
import {Distribution} from "src/Distribution.sol";
import {RelayerHelperConfig} from "../helperConfig/RelayerHelperConfig.s.sol";
import {MockRegistry} from "test/mock/MockRegistry.sol";
import {Vm} from "forge-std/Vm.sol";
import {IKeeperRegistryMaster} from "@chainlink/contracts/src/v0.8/automation/interfaces/v2_1/IKeeperRegistryMaster.sol";

// This script will initialize the contracts to be ready for interacting
contract Initialize is Script {
    address public distributionAddress;
    address public vSkillUserAddress;
    address public vSkillUserNftAddress;
    address public verifierAddress;
    address public relayerAddress;

    function _getContractAddress()
        internal
        returns (address, address, address, address, address)
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
        distributionAddress = Vm(address(vm)).getDeployment(
            "Distribution",
            uint64(block.chainid)
        );

        return (
            vSkillUserAddress,
            vSkillUserNftAddress,
            verifierAddress,
            relayerAddress,
            distributionAddress
        );
    }

    function _initializeToRelayer(
        VSkillUser vSkillUser,
        VSkillUserNft vSkillUserNft,
        Verifier verifier,
        address relayer
    ) public {
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
        address relayerAddressToBeInitialized
    ) public returns (address) {
        // Here we need to think about the Forwarder address setup...
        if (upkeepId == 0 && block.chainid != 31337) {
            console.log(
                "Please update the upkeepId in RelayerHelperConfig first!"
            );
            return address(0);
        }
        console.log(
            "Initializing contracts to Forwarder with upkeepId: ",
            upkeepId
        );
        // upkeepId = 0 implies that we are on testnet, deploy mock Registry
        if (upkeepId == 0) {
            vm.startBroadcast();
            MockRegistry mockRegistry = new MockRegistry();
            address forwarder = mockRegistry.getForwarder(upkeepId);
            Relayer(relayerAddressToBeInitialized).setForwarder(forwarder);
            vm.stopBroadcast();

            console.log(
                "Initialized contracts to Forwarder address: ",
                forwarder
            );

            return forwarder;
        } else {
            IKeeperRegistryMaster mockRegistry = IKeeperRegistryMaster(
                registry
            );
            // here we have the real registry address
            vm.startBroadcast();
            address forwarder = mockRegistry.getForwarder(upkeepId);
            Relayer(relayerAddressToBeInitialized).setForwarder(forwarder);
            vm.stopBroadcast();

            console.log(
                "Initialized contracts to Forwarder address: ",
                forwarder
            );

            return forwarder;
        }
    }

    function _initializeToVSkillUser(
        address distribution,
        address vskillUser
    ) public {
        vm.startBroadcast();
        Distribution(distribution).setVSkillUser(vskillUser);
        vm.stopBroadcast();

        console.log("Initialized Distribution contract to VSkillUser");
    }

    function run() external {
        (
            vSkillUserAddress,
            vSkillUserNftAddress,
            verifierAddress,
            relayerAddress,
            distributionAddress
        ) = _getContractAddress();

        RelayerHelperConfig relayerHelperConfig = new RelayerHelperConfig();

        address registry = relayerHelperConfig
            .getActiveNetworkConfig()
            .registryAddress;
        uint256 upkeepId = relayerHelperConfig
            .getActiveNetworkConfig()
            .upkeepId;

        _initializeToVSkillUser(distributionAddress, vSkillUserAddress);

        _initializeToRelayer(
            VSkillUser(payable(vSkillUserAddress)),
            VSkillUserNft(vSkillUserNftAddress),
            Verifier(payable(verifierAddress)),
            relayerAddress
        );

        _initializeToForwarder(registry, upkeepId, relayerAddress);

        console.log("Initialization completed!!!");
    }
}
