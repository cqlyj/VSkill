// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";

contract VSkillUserNftHelperConfig is Script {
    struct NetworkConfig {
        string[] skillDomains;
        string[] userNftImageUris;
    }

    NetworkConfig private activeNetworkConfig;
    string[] private skillDomains = [
        "Frontend",
        "Backend",
        "Fullstack",
        "DevOps",
        "Blockchain"
    ];
    string[] userNftImageUris = new string[](5);

    // @audit Add the zksync and amoy networks later..
    constructor() {
        string memory frontendSvg = vm.readFile("./image/frontend.svg");
        string memory backendSvg = vm.readFile("./image/backend.svg");
        string memory fullstackSvg = vm.readFile("./image/fullstack.svg");
        string memory devopsSvg = vm.readFile("./image/devops.svg");
        string memory blockchainSvg = vm.readFile("./image/blockchain.svg");
        userNftImageUris[0] = svgToImageUri(frontendSvg);
        userNftImageUris[1] = svgToImageUri(backendSvg);
        userNftImageUris[2] = svgToImageUri(fullstackSvg);
        userNftImageUris[3] = svgToImageUri(devopsSvg);
        userNftImageUris[4] = svgToImageUri(blockchainSvg);

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
        NetworkConfig memory sepoliaConfig = NetworkConfig(
            skillDomains,
            userNftImageUris
        );
        return sepoliaConfig;
    }

    function getAmoyConfig() public view returns (NetworkConfig memory) {
        NetworkConfig memory amoyConfig = NetworkConfig(
            skillDomains,
            userNftImageUris
        );
        return amoyConfig;
    }

    function getMainnetConfig() public view returns (NetworkConfig memory) {
        NetworkConfig memory mainnetConfig = NetworkConfig(
            skillDomains,
            userNftImageUris
        );
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
        NetworkConfig memory anvilChainConfig = NetworkConfig(
            skillDomains,
            userNftImageUris
        );
        return anvilChainConfig;
    }
}
