// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {OracleLib} from "./OracleLib.sol";

/**
 * @title PriceConverter library that will be used to convert ETH to USD and USD to ETH
 * @author Luo Yingjie
 * @notice This library uitilize the Chainlink Price Feed to get the latest price of ETH/USD
 * @dev This library is used to convert ETH to USD and USD to ETH
 */

library PriceConverter {
    using OracleLib for AggregatorV3Interface;

    uint256 private constant PRICE_FEED_DECIMALS = 1e8;
    uint256 private constant DECIMALS = 1e18;

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

        return (answer * int(DECIMALS)) / int(PRICE_FEED_DECIMALS);
    }

    function convertEthToUsd(
        uint256 ethAmount,
        AggregatorV3Interface priceFeed
    ) internal view returns (uint256) {
        int ethPrice = getChainlinkDataFeedLatestAnswer(priceFeed);
        return (ethAmount * uint256(ethPrice)) / DECIMALS;
    }

    // For now, we don't need this function

    // function convertUsdToEth(
    //     uint256 usdAmount,
    //     AggregatorV3Interface priceFeed
    // ) internal view returns (uint256) {
    //     int ethPrice = getChainlinkDataFeedLatestAnswer(priceFeed);
    //     return (usdAmount * DECIMALS) / uint256(ethPrice);
    // }
}
