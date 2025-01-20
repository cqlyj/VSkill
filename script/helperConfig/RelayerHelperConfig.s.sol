// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script} from "forge-std/Script.sol";
import {MockRegistry} from "test/mock/MockRegistry.sol";

contract RelayerHelperConfig is Script {
    struct NetworkConfig {
        address registryAddress;
        uint256 upkeepId;
    }

    NetworkConfig private activeNetworkConfig;

    constructor() {
        if (block.chainid == 1) {
            activeNetworkConfig = getMainnetConfig();
        } else if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaConfig();
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
            upkeepId: 0 // update this
        });
        return sepoliaConfig;
    }

    function getMainnetConfig() public pure returns (NetworkConfig memory) {
        NetworkConfig memory mainnetConfig = NetworkConfig({
            registryAddress: 0x6593c7De001fC8542bB1703532EE1E5aA0D458fD,
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
            upkeepId: 0 // update this
        });

        return anvilChainConfig;
    }
}
