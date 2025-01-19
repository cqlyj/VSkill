// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract DistributionHelperConfig is Script {
    struct NetworkConfig {
        uint64 subscriptionId;
        address vrfCoordinator;
        bytes32 keyHash;
        uint32 callbackGasLimit;
    }

    NetworkConfig public activeNetworkConfig;
    uint96 public constant BASE_FEE = 0.25 ether; // 0.25 LINK
    uint96 public constant GAS_PRICE_LINK = 1e9; // 1 gwei LINK
    int256 public constant WEI_PER_UNIT_LINK = 4e15; // 0.0004 LINK

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
            subscriptionId: 0, // Update this before deployment
            vrfCoordinator: 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625,
            keyHash: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
            callbackGasLimit: 500000
        });
        return sepoliaConfig;
    }

    function getMainnetConfig() public pure returns (NetworkConfig memory) {
        NetworkConfig memory mainnetConfig = NetworkConfig({
            subscriptionId: 0, // Update this before deployment
            vrfCoordinator: 0x271682DEB8C4E0901D1a1550aD2e64D568E69909,
            keyHash: 0xff8dedfbfa60af186cf3c830acbc32c05aae823045ae5ea7da1e45fbfaba4f92, // 500 gWei
            callbackGasLimit: 500000
        });
        return mainnetConfig;
    }

    function getOrCreateAnvilChainConfig()
        public
        returns (NetworkConfig memory)
    {
        if (activeNetworkConfig.vrfCoordinator != address(0)) {
            return activeNetworkConfig;
        }

        vm.startBroadcast();

        VRFCoordinatorV2_5Mock vrfCoordinator = new VRFCoordinatorV2_5Mock(
            BASE_FEE,
            GAS_PRICE_LINK,
            WEI_PER_UNIT_LINK
        );

        vm.stopBroadcast();

        NetworkConfig memory anvilChainConfig = NetworkConfig({
            subscriptionId: 0, // Update this before deployment
            vrfCoordinator: address(vrfCoordinator),
            keyHash: 0xd89b2bf150e3b9e13446986e571fb9cab24b13cea0a43ea20a6049a85cc807cc, // arbitrary
            callbackGasLimit: 500000
        });

        return anvilChainConfig;
    }
}
