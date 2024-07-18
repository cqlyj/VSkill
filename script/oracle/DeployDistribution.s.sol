// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {Distribution} from "../../src/oracle/Distribution.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployDistribution is Script {
    function run() external returns (Distribution, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        (
            uint64 subscriptionId,
            address vrfCoordinator,
            bytes32 keyHash,
            uint32 callbackGasLimit,
            uint16 requestConfirmations,
            uint32 numWords
        ) = helperConfig.activeNetworkConfig();

        vm.startBroadcast();
        Distribution distribution = new Distribution(
            subscriptionId,
            vrfCoordinator,
            keyHash,
            callbackGasLimit,
            requestConfirmations,
            numWords
        );
        vm.stopBroadcast();

        return (distribution, helperConfig);
    }
}
