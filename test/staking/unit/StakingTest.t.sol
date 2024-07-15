// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Test, console} from "lib/forge-std/src/Test.sol";
import {Staking} from "src/staking/Staking.sol";
import {DeployStaking} from "script/staking/DeployStaking.s.sol";

contract StakingTest is Test {
    Staking staking;
    uint256 public constant MIN_USD_AMOUNT = 0.01 ether;
    uint256 public constant INITIAL_BALANCE = 100 ether;
    address public USER = makeAddr("user");

    function setUp() external {
        DeployStaking deployer = new DeployStaking();
        staking = deployer.run();
        vm.deal(USER, INITIAL_BALANCE);
    }

    // Initial state

    function testMinUsdAmountIsTwenty() external view {
        uint256 minUsdAmount = staking.getMinUsdAmount();
        assertEq(minUsdAmount, 20e18);
    }

    // Constructor

    function testIdIsOneAfterDeployment() external view {
        uint256 id = staking.getLatestId();
        assertEq(id, 1);
    }

    function testVerifierCountIsZeroAfterDeployment() external view {
        uint256 count = staking.getVerifierCount();
        assertEq(count, 0);
    }

    // stakeToBeTheVerifier

    function testStakeToBeTheVerifierRevertIfNotEnoughUsd() external {
        vm.expectRevert();
        staking.stakeToBeTheVerifier();
    }

    function testStakeToBeTheVerifierOnlyIfEnoughUsd() external {
        vm.startPrank(USER);
        staking.stakeToBeTheVerifier{value: MIN_USD_AMOUNT}();
        vm.stopPrank();

        uint256 balance = staking.getMoneyStaked(USER);
        assertEq(balance, MIN_USD_AMOUNT);
    }

    function testSakeToBeTheVerifierSuccessUpdatesVerifier() external {
        vm.startPrank(USER);
        staking.stakeToBeTheVerifier{value: MIN_USD_AMOUNT}();
        vm.stopPrank();

        uint256 id = staking.getVerifierId(USER);
        assertEq(id, 1);
    }

    function testStakeToBeTheVerifierOnlyCanBeCalledIfNotVerifier() external {
        vm.startPrank(USER);
        staking.stakeToBeTheVerifier{value: MIN_USD_AMOUNT}();
        vm.expectRevert();
        staking.stakeToBeTheVerifier{value: MIN_USD_AMOUNT}();
        vm.stopPrank();
    }

    function testStakeToBeTheVerifierSuccessAndIdIncreament() external {
        vm.startPrank(USER);
        staking.stakeToBeTheVerifier{value: MIN_USD_AMOUNT}();
        vm.stopPrank();

        address anotherUser = makeAddr("anotherUser");
        vm.deal(anotherUser, INITIAL_BALANCE);
        vm.startPrank(anotherUser);
        staking.stakeToBeTheVerifier{value: MIN_USD_AMOUNT}();
        vm.stopPrank();

        uint256 id = staking.getVerifierId(anotherUser);
        console.log("id", id);
        assertEq(id, 2);

        uint256 latestId = staking.getLatestId();
        assertEq(latestId, 3);
    }

    // withdrawStake

    function testWithdrawStakeRevertIfNotEnoughBalance() external {
        vm.expectRevert();
        staking.withdrawStake(MIN_USD_AMOUNT);
    }

    function testWithdrawStakeSuccessUpdatesBalance() external {
        vm.startPrank(USER);
        staking.stakeToBeTheVerifier{value: MIN_USD_AMOUNT}();
        staking.withdrawStake(MIN_USD_AMOUNT / 2);
        vm.stopPrank();

        uint256 balance = staking.getMoneyStaked(USER);
        assertEq(balance, MIN_USD_AMOUNT / 2);
    }

    function testWithdrawStakeSuccessChecksVerifierStatus() external {
        vm.startPrank(USER);
        staking.stakeToBeTheVerifier{value: MIN_USD_AMOUNT}();
        staking.withdrawStake(MIN_USD_AMOUNT);
        vm.stopPrank();

        uint256 id = staking.getVerifierId(USER);
        assertEq(id, 0);
    }

    function testWithdrawStakeReduceVerifierCountIfSomeoneWithdrawTooMuchToMeetMinUsdAmount()
        external
    {
        vm.startPrank(USER);
        staking.stakeToBeTheVerifier{value: MIN_USD_AMOUNT}();
        vm.stopPrank();

        address anotherUser = makeAddr("anotherUser");
        vm.deal(anotherUser, INITIAL_BALANCE);
        vm.startPrank(anotherUser);
        staking.stakeToBeTheVerifier{value: MIN_USD_AMOUNT}();
        vm.stopPrank();

        vm.startPrank(USER);
        staking.withdrawStake(MIN_USD_AMOUNT);
        vm.stopPrank();

        uint256 count = staking.getVerifierCount();
        assertEq(count, 1);
    }

    // stake

    function testStakeUpdatesBalance() external {
        vm.startPrank(USER);
        staking.stake{value: MIN_USD_AMOUNT / 2}();
        vm.stopPrank();

        uint256 balance = staking.getMoneyStaked(USER);
        assertEq(balance, MIN_USD_AMOUNT / 2);
    }

    function testStakeCheckVerifierStatus() external {
        vm.startPrank(USER);
        staking.stake{value: MIN_USD_AMOUNT}();
        vm.stopPrank();

        uint256 id = staking.getVerifierId(USER);
        assertEq(id, 1);
        assertEq(staking.getVerifierCount(), 1);
    }
}
