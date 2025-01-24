// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script} from "forge-std/Script.sol";
import {MockRegistry} from "test/mock/MockRegistry.sol";

contract RelayerHelperConfig is Script {
    struct NetworkConfig {
        address registryAddress;
        address registrarAddress;
        address linkTokenAddress;
        uint256 upkeepId;
    }

    NetworkConfig private activeNetworkConfig;

    constructor() {
        if (block.chainid == 1) {
            activeNetworkConfig = getMainnetConfig();
        } else if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaConfig();
        } else if (block.chainid == 80002) {
            activeNetworkConfig = getAmoyConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilChainConfig();
        }
    }

    function getActiveNetworkConfig()
        external
        view
        returns (NetworkConfig memory)
    {
        return activeNetworkConfig;
    }

    function getSepoliaConfig() public pure returns (NetworkConfig memory) {
        NetworkConfig memory sepoliaConfig = NetworkConfig({
            registryAddress: 0x86EFBD0b6736Bed994962f9797049422A3A8E8Ad,
            registrarAddress: 0xb0E49c5D0d05cbc241d68c05BC5BA1d1B7B72976,
            linkTokenAddress: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
            upkeepId: 0 // update this
        });
        return sepoliaConfig;
    }

    function getAmoyConfig() public pure returns (NetworkConfig memory) {
        NetworkConfig memory amoyConfig = NetworkConfig({
            registryAddress: 0x93C0e201f7B158F503a1265B6942088975f92ce7,
            registrarAddress: 0x99083A4bb154B0a3EC7a0D1eb40370C892Db4225,
            linkTokenAddress: 0x0Fd9e8d3aF1aaee056EB9e802c3A762a667b1904,
            upkeepId: 0 // update this
        });
        return amoyConfig;
    }

    function getMainnetConfig() public pure returns (NetworkConfig memory) {
        NetworkConfig memory mainnetConfig = NetworkConfig({
            registryAddress: 0x6593c7De001fC8542bB1703532EE1E5aA0D458fD,
            registrarAddress: 0x6B0B234fB2f380309D47A7E9391E29E9a179395a,
            linkTokenAddress: 0x514910771AF9Ca656af840dff83E8264EcF986CA,
            upkeepId: 0 // update this
        });
        return mainnetConfig;
    }

    function getOrCreateAnvilChainConfig()
        public
        returns (NetworkConfig memory)
    {
        if (activeNetworkConfig.registryAddress != address(0)) {
            return activeNetworkConfig;
        }
        // deploy mock Registry
        vm.startBroadcast();

        MockRegistry registry = new MockRegistry();

        vm.stopBroadcast();

        NetworkConfig memory anvilChainConfig = NetworkConfig({
            registryAddress: address(registry),
            registrarAddress: address(0), // This not matter, for the anvil testnet we will call that performUpkeep function
            linkTokenAddress: address(0), // This also not matter for now
            upkeepId: 0 // update this
        });

        return anvilChainConfig;
    }
}
