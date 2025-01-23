// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {MockLinkToken} from "@chainlink/contracts/src/v0.8/mocks/MockLinkToken.sol";

contract DistributionHelperConfig is Script {
    struct NetworkConfig {
        uint256 subscriptionId;
        address vrfCoordinator;
        bytes32 keyHash;
        uint32 callbackGasLimit;
        address linkTokenAddress;
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

    function setActiveNetworkSubscriptionId(uint256 _subscriptionId) external {
        activeNetworkConfig.subscriptionId = _subscriptionId;
    }

    function getSepoliaConfig() public pure returns (NetworkConfig memory) {
        NetworkConfig memory sepoliaConfig = NetworkConfig({
            subscriptionId: 0, // Update this before deployment
            vrfCoordinator: 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625,
            keyHash: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
            callbackGasLimit: 500000,
            linkTokenAddress: 0x779877A7B0D9E8603169DdbD7836e478b4624789
        });
        return sepoliaConfig;
    }

    function getAmoyConfig() public pure returns (NetworkConfig memory) {
        NetworkConfig memory amoyConfig = NetworkConfig({
            subscriptionId: 56003561226016405806153830093780721658933566768163361981188016113168550918782, // Update this before deployment
            vrfCoordinator: 0x343300b5d84D444B2ADc9116FEF1bED02BE49Cf2,
            keyHash: 0x816bedba8a50b294e5cbd47842baf240c2385f2eaf719edbd4f250a137a8c899,
            callbackGasLimit: 500000,
            linkTokenAddress: 0x0Fd9e8d3aF1aaee056EB9e802c3A762a667b1904
        });
        return amoyConfig;
    }

    function getMainnetConfig() public pure returns (NetworkConfig memory) {
        NetworkConfig memory mainnetConfig = NetworkConfig({
            subscriptionId: 0, // Update this before deployment
            vrfCoordinator: 0x271682DEB8C4E0901D1a1550aD2e64D568E69909,
            keyHash: 0xff8dedfbfa60af186cf3c830acbc32c05aae823045ae5ea7da1e45fbfaba4f92, // 500 gWei
            callbackGasLimit: 500000,
            linkTokenAddress: 0x514910771AF9Ca656af840dff83E8264EcF986CA
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

        MockLinkToken linkToken = new MockLinkToken();

        vm.stopBroadcast();

        NetworkConfig memory anvilChainConfig = NetworkConfig({
            subscriptionId: 0, // Update this before deployment
            vrfCoordinator: address(vrfCoordinator),
            keyHash: 0xd89b2bf150e3b9e13446986e571fb9cab24b13cea0a43ea20a6049a85cc807cc, // arbitrary
            callbackGasLimit: 500000,
            linkTokenAddress: address(linkToken)
        });

        return anvilChainConfig;
    }
}
