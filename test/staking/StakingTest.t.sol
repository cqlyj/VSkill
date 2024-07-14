// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Test} from "lib/forge-std/src/Test.sol";
import {Staking} from "src/staking/Staking.sol";
import {DeployStaking} from "script/staking/DeployStaking.s.sol";

contract StakingTest is Test {
    Staking staking;

    function setUp() external {
        DeployStaking deployer = new DeployStaking();
        staking = deployer.run();
    }

    function testMinUsdAmountIsTwenty() external view {
        uint256 minUsdAmount = staking.getMinUsdAmount();
        assertEq(minUsdAmount, 20e18);
    }
}
