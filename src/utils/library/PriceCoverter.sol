// SPDX-License-Identifier: MIT

// @audit-info floating pragma
pragma solidity ^0.8.24;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/**
 * @title PriceConverter library that will be used to convert ETH to USD and USD to ETH
 * @author Luo Yingjie
 * @notice This library uitilize the Chainlink Price Feed to get the latest price of ETH/USD
 * @dev This library is used to convert ETH to USD and USD to ETH
 */
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

        // q why multiply by 1e10?
        // @audit-info magic number
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
