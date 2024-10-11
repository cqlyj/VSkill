// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {Staking} from "src/staking/Staking.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";
import {PriceConverter} from "../../src/utils/library/PriceCoverter.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract WithdrawStakeStaking is Script {
    using PriceConverter for uint256;

    uint256 public constant MIN_USD_AMOUNT = 20e18;

    function withdrawStakeStaking(address mostRecentlyDeployed) public {
        vm.startBroadcast();
        Staking staking = Staking(payable(mostRecentlyDeployed));
        AggregatorV3Interface priceFeed = staking.getPriceFeed();
        staking.withdrawStake(MIN_USD_AMOUNT.convertUsdToEth(priceFeed));
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
    using PriceConverter for uint256;

    uint256 public constant MIN_USD_AMOUNT = 20e18;

    function stakeStaking(address mostRecentlyDeployed) public {
        vm.startBroadcast();
        Staking staking = Staking(payable(mostRecentlyDeployed));
        AggregatorV3Interface priceFeed = staking.getPriceFeed();
        staking.stake{value: MIN_USD_AMOUNT.convertUsdToEth(priceFeed)}();
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
