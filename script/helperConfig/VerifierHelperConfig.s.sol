// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {MockV3Aggregator} from "test/mock/MockV3Aggregator.sol";

contract VerifierHelperConfig is Script {
    struct NetworkConfig {
        address priceFeed;
        string[] skillDomains;
    }

    string[] private skillDomains = [
        "Frontend",
        "Backend",
        "Fullstack",
        "DevOps",
        "Blockchain"
    ];

    uint8 private constant DECIMALS = 8;
    int256 private constant INITIAL_ANSWER = 2000e8; // 1ETH = 2000 USD

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
        public
        view
        returns (NetworkConfig memory)
    {
        return activeNetworkConfig;
    }

    function getSepoliaConfig() public view returns (NetworkConfig memory) {
        NetworkConfig memory sepoliaConfig = NetworkConfig({
            priceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306,
            skillDomains: skillDomains
        });
        return sepoliaConfig;
    }

    function getMainnetConfig() public view returns (NetworkConfig memory) {
        NetworkConfig memory mainnetConfig = NetworkConfig({
            priceFeed: 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419,
            skillDomains: skillDomains
        });
        return mainnetConfig;
    }

    function getOrCreateAnvilChainConfig()
        public
        returns (NetworkConfig memory)
    {
        if (activeNetworkConfig.priceFeed != address(0)) {
            return activeNetworkConfig;
        }
        // deploy mock price feed contract
        vm.startBroadcast();
        MockV3Aggregator mockPriceFeed = new MockV3Aggregator(
            DECIMALS,
            INITIAL_ANSWER
        );

        vm.stopBroadcast();

        NetworkConfig memory anvilChainConfig = NetworkConfig({
            priceFeed: address(mockPriceFeed),
            skillDomains: skillDomains
        });

        return anvilChainConfig;
    }
}
