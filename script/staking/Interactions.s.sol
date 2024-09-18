// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {Staking} from "src/staking/Staking.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract WithdrawStakeStaking is Script {
    uint256 public MIN_ETH_AMOUNT = 0.01 ether;

    function withdrawStakeStaking(address mostRecentlyDeployed) public {
        vm.startBroadcast();
        Staking staking = Staking(payable(mostRecentlyDeployed));
        staking.withdrawStake(MIN_ETH_AMOUNT);
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
    uint256 public constant ENOUGH_USD_AMOUNT = 1000;

    function stakeStaking(address mostRecentlyDeployed) public {
        vm.startBroadcast();
        Staking staking = Staking(payable(mostRecentlyDeployed));
        staking.stake(ENOUGH_USD_AMOUNT);
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
