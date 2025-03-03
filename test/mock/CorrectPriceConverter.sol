// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {OracleLib} from "src/library/OracleLib.sol";

library CorrectPriceConverter {
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
        ) = priceFeed.staleCheckLatestRoundData();

        return (answer * int(DECIMALS)) / int(PRICE_FEED_DECIMALS);
    }

    function correctConvertEthToUsd(
        uint256 ethAmount,
        AggregatorV3Interface priceFeed
    ) internal view returns (uint256) {
        int ethPrice = getChainlinkDataFeedLatestAnswer(priceFeed);
        return (ethAmount * uint256(ethPrice)) / DECIMALS;
    }
}
