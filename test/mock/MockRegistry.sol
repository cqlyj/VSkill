// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {MockForwarder} from "./MockForwarder.sol";

contract MockRegistry {
    MockForwarder forwarder;

    function getForwarder(uint256 /*upkeepId*/) external returns (address) {
        forwarder = new MockForwarder();
        return address(forwarder);
    }
}
