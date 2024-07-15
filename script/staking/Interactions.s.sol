// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {Staking} from "src/staking/Staking.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract StakeToBeTheVerifierStaking is Script {
    uint256 public constant MIN_USD_AMOUNT = 0.01 ether;

    function stakeToBeTheVerifierStaking(address mostRecentlyDeployed) public {
        Staking staking = Staking(payable(mostRecentlyDeployed));
        staking.stakeToBeTheVerifier{value: MIN_USD_AMOUNT}();
    }

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
            "Staking",
            block.chainid
        );
        console.log("Most recently deployed address: ", mostRecentlyDeployed);
        vm.startBroadcast();
        uint256 balanceBeforeStaking = address(mostRecentlyDeployed).balance;
        stakeToBeTheVerifierStaking(mostRecentlyDeployed);
        uint256 balanceAfterStaking = address(mostRecentlyDeployed).balance;
        console.log(
            "Balance before staking: ",
            balanceBeforeStaking,
            " Balance after staking: ",
            balanceAfterStaking
        );
        vm.stopBroadcast();
    }
}

contract WithdrawStakeStaking is Script {
    uint256 public constant MIN_USD_AMOUNT = 0.01 ether;

    function withdrawStakeStaking(address mostRecentlyDeployed) public {
        Staking staking = Staking(payable(mostRecentlyDeployed));
        staking.withdrawStake(MIN_USD_AMOUNT);
    }

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
            "Staking",
            block.chainid
        );
        console.log("Most recently deployed address: ", mostRecentlyDeployed);
        vm.startBroadcast();
        uint256 balanceBeforeWithdrawing = address(mostRecentlyDeployed)
            .balance;
        withdrawStakeStaking(mostRecentlyDeployed);
        uint256 balanceAfterWithdrawing = address(mostRecentlyDeployed).balance;
        console.log(
            "Balance before withdrawing: ",
            balanceBeforeWithdrawing,
            " Balance after withdrawing: ",
            balanceAfterWithdrawing
        );
        vm.stopBroadcast();
    }
}

contract StakeStaking is Script {
    uint256 public constant MIN_USD_AMOUNT = 0.01 ether;

    function stakeStaking(address mostRecentlyDeployed) public {
        Staking staking = Staking(payable(mostRecentlyDeployed));
        staking.stake{value: MIN_USD_AMOUNT}();
    }

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
            "Staking",
            block.chainid
        );
        console.log("Most recently deployed address: ", mostRecentlyDeployed);
        vm.startBroadcast();
        uint256 balanceBeforeStaking = address(mostRecentlyDeployed).balance;
        stakeStaking(mostRecentlyDeployed);
        uint256 balanceAfterStaking = address(mostRecentlyDeployed).balance;
        console.log(
            "Balance before staking: ",
            balanceBeforeStaking,
            " Balance after staking: ",
            balanceAfterStaking
        );
        vm.stopBroadcast();
    }
}
