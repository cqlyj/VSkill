// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Test} from "lib/forge-std/src/Test.sol";
import {Staking} from "src/staking/Staking.sol";
import {DeployStaking} from "script/staking/DeployStaking.s.sol";

contract StakingTest is Test {
    Staking staking;
    uint256 public constant MIN_USD_AMOUNT = 20e18;
    uint256 public constant INITIAL_BALANCE = 100e18;
    address public USER = makeAddr("user");

    function setUp() external {
        DeployStaking deployer = new DeployStaking();
        staking = deployer.run();
        vm.deal(USER, INITIAL_BALANCE);
    }

    function testMinUsdAmountIsTwenty() external view {
        uint256 minUsdAmount = staking.getMinUsdAmount();
        assertEq(minUsdAmount, 20e18);
    }

    function testStakeRevertIfNotEnoughUsd() external {
        vm.expectRevert();
        staking.stakeToBeTheVerifier();
    }

    function testStakeOnlyIfEnoughUsd() external {
        vm.startPrank(USER);
        staking.stakeToBeTheVerifier{value: MIN_USD_AMOUNT}();
        vm.stopPrank();

        uint256 balance = staking.getMoneyStaked(USER);
        assertEq(balance, MIN_USD_AMOUNT);
    }

    function testStakeSuccessUpdatesVerifier() external {
        vm.startPrank(USER);
        staking.stakeToBeTheVerifier{value: MIN_USD_AMOUNT}();
        vm.stopPrank();

        address verifiers = staking.getVerifiers(0);
        assertEq(verifiers, USER);
        assertEq(staking.getVerifiersLength(), 1);
    }

    function testWithdrawRevertIfNotEnoughBalance() external {
        vm.expectRevert();
        staking.withdrawStake(MIN_USD_AMOUNT);
    }

    function testWithdrawSuccessUpdatesBalance() external {
        vm.startPrank(USER);
        staking.stakeToBeTheVerifier{value: MIN_USD_AMOUNT}();
        staking.withdrawStake(MIN_USD_AMOUNT / 2);
        vm.stopPrank();

        uint256 balance = staking.getMoneyStaked(USER);
        assertEq(balance, MIN_USD_AMOUNT / 2);
    }
}
