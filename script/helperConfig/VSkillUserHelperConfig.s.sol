// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {MockV3Aggregator} from "../../test/mock/MockV3Aggregator.sol";
import {Vm} from "forge-std/Vm.sol";

contract VSkillUserHelperConfig is Script {
    struct NetworkConfig {
        uint256 submissionFeeInUsd;
        address priceFeed;
        address distributionAddress;
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

    function getActiveNetworkConfig()
        external
        view
        returns (NetworkConfig memory)
    {
        return activeNetworkConfig;
    }

    function getSepoliaConfig() public view returns (NetworkConfig memory) {
        address distributionAddress = Vm(address(vm)).getDeployment(
            "Distribution",
            uint64(block.chainid)
        );
        NetworkConfig memory sepoliaConfig = NetworkConfig({
            submissionFeeInUsd: SUBMISSION_FEE,
            priceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306,
            distributionAddress: distributionAddress
        });
        return sepoliaConfig;
    }

    function getMainnetConfig() public view returns (NetworkConfig memory) {
        address distributionAddress = Vm(address(vm)).getDeployment(
            "Distribution",
            uint64(block.chainid)
        );
        NetworkConfig memory mainnetConfig = NetworkConfig({
            submissionFeeInUsd: SUBMISSION_FEE,
            priceFeed: 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419,
            distributionAddress: distributionAddress
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

        address distributionAddress = Vm(address(vm)).getDeployment(
            "Distribution",
            uint64(block.chainid)
        );

        if (distributionAddress == address(0)) {
            revert("Distribution contract not deployed");
        }

        NetworkConfig memory anvilChainConfig = NetworkConfig({
            submissionFeeInUsd: SUBMISSION_FEE,
            priceFeed: address(mockPriceFeed),
            distributionAddress: distributionAddress
        });

        return anvilChainConfig;
    }
}
