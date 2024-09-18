// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {MockV3Aggregator} from "../../test/mock/MockV3Aggregator.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        uint256 submissionFeeInUsd;
        address priceFeed;
        string[] userNftImageUris;
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
            submissionFeeInUsd: SUBMISSION_FEE,
            priceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306,
            userNftImageUris: userNftImageUris
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
            submissionFeeInUsd: SUBMISSION_FEE,
            priceFeed: 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419,
            userNftImageUris: userNftImageUris
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
            submissionFeeInUsd: SUBMISSION_FEE,
            priceFeed: address(mockPriceFeed),
            userNftImageUris: userNftImageUris
        });

        return anvilChainConfig;
    }
}
