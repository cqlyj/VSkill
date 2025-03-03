// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {MaliciousMockV3Aggregator} from "test/mock/MaliciousMockV3Aggregator.sol";
import {PriceConverter} from "src/library/PriceCoverter.sol";
import {CorrectPriceConverter, OracleLib} from "test/mock/CorrectPriceConverter.sol";

contract ProofOfCodes is Test {
    using PriceConverter for uint256;
    using CorrectPriceConverter for uint256;

    MaliciousMockV3Aggregator public maliciousMockAggregator;

    function setUp() external {
        maliciousMockAggregator = new MaliciousMockV3Aggregator(8, 2000);
    }

    function testUnstablePriceFeedRevert() external {
        uint256 ethAmount = 1 ether;
        vm.expectRevert(OracleLib.OracleLib__StalePrice.selector);
        ethAmount.correctConvertEthToUsd(maliciousMockAggregator);
        // However, the current price feed will not revert
        uint256 outdatedData = ethAmount.convertEthToUsd(
            maliciousMockAggregator
        );
        console.log("This is the outdated data: ", outdatedData);
    }
}
