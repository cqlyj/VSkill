// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

library PriceConverter {
    function getChainlinkDataFeedLatestAnswer(
        AggregatorV3Interface priceFeed
    ) internal view returns (int) {
        // prettier-ignore
        (
            /* uint80 roundID */,
            int answer,
            /*uint startedAt*/,
            /*uint timeStamp*/,
            /*uint80 answeredInRound*/
        ) = priceFeed.latestRoundData();
        return answer * 1e10;
    }

    function convertEthToUsd(
        uint256 ethAmount,
        AggregatorV3Interface priceFeed
    ) internal view returns (uint256) {
        int ethPrice = getChainlinkDataFeedLatestAnswer(priceFeed);
        return (ethAmount * uint256(ethPrice)) / 1e18;
    }

    function convertUsdToEth(
        uint256 usdAmount,
        AggregatorV3Interface priceFeed
    ) internal view returns (uint256) {
        int ethPrice = getChainlinkDataFeedLatestAnswer(priceFeed);
        return (usdAmount * 1e18) / uint256(ethPrice);
    }
}
