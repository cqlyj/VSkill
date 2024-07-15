// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {Staking} from "src/staking/Staking.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract StakeToBeTheVerifierStaking is Script {
    uint256 public constant MIN_USD_AMOUNT = 0.01 ether;

    function stakeToBeTheVerifierStaking(address mostRecentlyDeployed) public {
        vm.startBroadcast();
        Staking staking = Staking(payable(mostRecentlyDeployed));
        staking.stakeToBeTheVerifier{value: MIN_USD_AMOUNT}();
        vm.stopBroadcast();
    }

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
            "Staking",
            block.chainid
        );
        console.log("Most recently deployed address: ", mostRecentlyDeployed);
        stakeToBeTheVerifierStaking(mostRecentlyDeployed);
    }
}

contract WithdrawStakeStaking is Script {
    uint256 public MIN_USD_AMOUNT = 0.01 ether;

    function withdrawStakeStaking(address mostRecentlyDeployed) public {
        vm.startBroadcast();
        Staking staking = Staking(payable(mostRecentlyDeployed));
        staking.withdrawStake(MIN_USD_AMOUNT);
        vm.stopBroadcast();
    }

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
            "Staking",
            block.chainid
        );
        console.log("Most recently deployed address: ", mostRecentlyDeployed);
        withdrawStakeStaking(mostRecentlyDeployed);
    }
}

contract StakeStaking is Script {
    uint256 public constant MIN_USD_AMOUNT = 0.01 ether;

    function stakeStaking(address mostRecentlyDeployed) public {
        vm.startBroadcast();
        Staking staking = Staking(payable(mostRecentlyDeployed));
        staking.stake{value: MIN_USD_AMOUNT}();
        vm.stopBroadcast();
    }

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
            "Staking",
            block.chainid
        );
        console.log("Most recently deployed address: ", mostRecentlyDeployed);
        stakeStaking(mostRecentlyDeployed);
    }
}
