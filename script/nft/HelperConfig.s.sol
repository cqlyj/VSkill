// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        string[] userNftImageUris;
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

    // The activeNetworkConfig cannot be declared as public since the getter function cannot get array.
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
        NetworkConfig memory sepoliaConfig = NetworkConfig(userNftImageUris);
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
        NetworkConfig memory mainnetConfig = NetworkConfig(userNftImageUris);
        return mainnetConfig;
    }

    function getOrCreateAnvilChainConfig()
        public
        view
        returns (NetworkConfig memory)
    {
        if (activeNetworkConfig.userNftImageUris.length != 0) {
            return activeNetworkConfig;
        }
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
        NetworkConfig memory anvilChainConfig = NetworkConfig(userNftImageUris);
        return anvilChainConfig;
    }
}
