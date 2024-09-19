// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Test, console} from "lib/forge-std/src/Test.sol";
import {Staking} from "src/staking/Staking.sol";
import {DeployStaking} from "script/staking/DeployStaking.s.sol";
import {WithdrawStakeStaking, StakeStaking} from "script/staking/Interactions.s.sol";

contract InteractionsTest is Test {
    Staking staking;

    function setUp() external {
        DeployStaking deployer = new DeployStaking();
        (staking, ) = deployer.run();
    }

    function testInteractions() external {
        StakeStaking staker = new StakeStaking();
        staker.stakeStaking(address(staking));

        assertEq(staking.getVerifierCount(), 1);
        console.log("Stake success");

        WithdrawStakeStaking withdrawer = new WithdrawStakeStaking();
        withdrawer.withdrawStakeStaking(address(staking));

        assertEq(staking.getVerifierCount(), 0);
        console.log("Withdraw stake success");
    }
}
