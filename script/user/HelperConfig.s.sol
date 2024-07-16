// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {MockV3Aggregator} from "../../test/mock/MockV3Aggregator.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        uint256 submissionFeeInUsd;
        address priceFeed;
    }

    NetworkConfig public activeNetworkConfig;
    uint256 private constant SUBMISSION_FEE = 5e18; // 5 USD
    uint8 private constant DECIMALS = 8;
    int256 private constant INITIAL_ANSWER = 2000e8; // 1ETH = 2000 USD

    constructor() {
        if (block.chainid == 1) {
            activeNetworkConfig = getMainnetConfig();
        } else if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilChainConfig();
        }
    }

    function getSepoliaConfig() public pure returns (NetworkConfig memory) {
        NetworkConfig memory sepoliaConfig = NetworkConfig({
            submissionFeeInUsd: SUBMISSION_FEE,
            priceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306
        });
        return sepoliaConfig;
    }

    function getMainnetConfig() public pure returns (NetworkConfig memory) {
        NetworkConfig memory mainnetConfig = NetworkConfig({
            submissionFeeInUsd: SUBMISSION_FEE,
            priceFeed: 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419
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
            submissionFeeInUsd: SUBMISSION_FEE,
            priceFeed: address(mockPriceFeed)
        });

        return anvilChainConfig;
    }
}
