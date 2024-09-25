// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import {MockV3Aggregator} from "../../test/mock/MockV3Aggregator.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2Mock.sol";
import {MockLinkToken} from "@chainlink/contracts/src/v0.8/mocks/MockLinkToken.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        address priceFeed;
        uint64 subscriptionId;
        address vrfCoordinator;
        bytes32 keyHash;
        uint32 callbackGasLimit;
        uint256 submissionFeeInUsd;
        string[] userNftImageUris;
        address linkTokenAddress;
        uint256 deployerKey;
    }

    uint256 private constant SUBMISSION_FEE = 5e18; // 5 USD
    uint8 private constant DECIMALS = 8;
    int256 private constant INITIAL_ANSWER = 2000e8; // 1ETH = 2000 USD
    uint96 public constant BASE_FEE = 0.25 ether; // 0.25 LINK
    uint96 public constant GAS_PRICE_LINK = 1e9; // 1 gwei LINK

    NetworkConfig public activeNetworkConfig;

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

    function svgToImageUri(
        string memory svg
    ) public pure returns (string memory) {
        string memory baseURI = "data:image/svg+xml;base64,";
        string memory svgBase64Encoded = Base64.encode(
            bytes(string(abi.encodePacked(svg)))
        );
        return string(abi.encodePacked(baseURI, svgBase64Encoded));
    }

    function getSepoliaConfig() public view returns (NetworkConfig memory) {
        string memory frontendSvg = vm.readFile("./image/frontend.svg");
        string memory backendSvg = vm.readFile("./image/backend.svg");
        string memory fullstackSvg = vm.readFile("./image/fullstack.svg");
        string memory devopsSvg = vm.readFile("./image/devops.svg");
        string memory blockchainSvg = vm.readFile("./image/blockchain.svg");
        string[] memory userNftImageUris = new string[](5);
        userNftImageUris[0] = svgToImageUri(frontendSvg);
        userNftImageUris[1] = svgToImageUri(backendSvg);
        userNftImageUris[2] = svgToImageUri(fullstackSvg);
        userNftImageUris[3] = svgToImageUri(devopsSvg);
        userNftImageUris[4] = svgToImageUri(blockchainSvg);

        NetworkConfig memory sepoliaConfig = NetworkConfig({
            priceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306,
            subscriptionId: 0,
            vrfCoordinator: 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625,
            keyHash: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
            callbackGasLimit: 500000,
            submissionFeeInUsd: SUBMISSION_FEE,
            userNftImageUris: userNftImageUris,
            linkTokenAddress: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
        return sepoliaConfig;
    }

    function getMainnetConfig() public view returns (NetworkConfig memory) {
        string memory frontendSvg = vm.readFile("./image/frontend.svg");
        string memory backendSvg = vm.readFile("./image/backend.svg");
        string memory fullstackSvg = vm.readFile("./image/fullstack.svg");
        string memory devopsSvg = vm.readFile("./image/devops.svg");
        string memory blockchainSvg = vm.readFile("./image/blockchain.svg");
        string[] memory userNftImageUris = new string[](5);
        userNftImageUris[0] = svgToImageUri(frontendSvg);
        userNftImageUris[1] = svgToImageUri(backendSvg);
        userNftImageUris[2] = svgToImageUri(fullstackSvg);
        userNftImageUris[3] = svgToImageUri(devopsSvg);
        userNftImageUris[4] = svgToImageUri(blockchainSvg);

        NetworkConfig memory mainnetConfig = NetworkConfig({
            priceFeed: 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419,
            subscriptionId: 0,
            vrfCoordinator: 0x271682DEB8C4E0901D1a1550aD2e64D568E69909,
            keyHash: 0xff8dedfbfa60af186cf3c830acbc32c05aae823045ae5ea7da1e45fbfaba4f92,
            callbackGasLimit: 500000,
            submissionFeeInUsd: SUBMISSION_FEE,
            userNftImageUris: userNftImageUris,
            linkTokenAddress: 0x514910771AF9Ca656af840dff83E8264EcF986CA,
            deployerKey: vm.envUint("PRIVATE_KEY")
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

        VRFCoordinatorV2Mock vrfCoordinator = new VRFCoordinatorV2Mock(
            BASE_FEE,
            GAS_PRICE_LINK
        );

        MockLinkToken linkToken = new MockLinkToken();
        vm.stopBroadcast();

        string memory frontendSvg = vm.readFile("./image/frontend.svg");
        string memory backendSvg = vm.readFile("./image/backend.svg");
        string memory fullstackSvg = vm.readFile("./image/fullstack.svg");
        string memory devopsSvg = vm.readFile("./image/devops.svg");
        string memory blockchainSvg = vm.readFile("./image/blockchain.svg");
        string[] memory userNftImageUris = new string[](5);
        userNftImageUris[0] = svgToImageUri(frontendSvg);
        userNftImageUris[1] = svgToImageUri(backendSvg);
        userNftImageUris[2] = svgToImageUri(fullstackSvg);
        userNftImageUris[3] = svgToImageUri(devopsSvg);
        userNftImageUris[4] = svgToImageUri(blockchainSvg);

        NetworkConfig memory anvilChainConfig = NetworkConfig({
            priceFeed: address(mockPriceFeed),
            subscriptionId: 0,
            vrfCoordinator: address(vrfCoordinator),
            keyHash: 0xd89b2bf150e3b9e13446986e571fb9cab24b13cea0a43ea20a6049a85cc807cc,
            callbackGasLimit: 500000,
            submissionFeeInUsd: SUBMISSION_FEE,
            userNftImageUris: userNftImageUris,
            linkTokenAddress: address(linkToken),
            deployerKey: vm.envUint("ANVIL_PRIVATE_KEY")
        });

        return anvilChainConfig;
    }
}
