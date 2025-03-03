## High

### [H-1] Miss stable price check in `PriceConverter` library

**Description:**

The function `PriceConverter::getChainlinkDataFeedLatestAnswer` calls `latestRoundData` instead of `staleCheckLatestRoundData` from `OracleLib`. Although `staleCheckLatestRoundData` is available, it is not used, leading to a risk of processing outdated or incorrect price data.

```javascript
(
    /* uint80 roundID */,
    int answer,
    /*uint startedAt*/,
    /*uint timeStamp*/,
    /*uint80 answeredInRound*/
@> ) = priceFeed.latestRoundData();

```

**Impact:**

If the `Chainlink` oracle experiences issues and provides outdated or incorrect price data, contracts depending on this function for ETH/USD conversion could process stale prices, potentially leading to severe financial losses.

Check the following test case in `test/v2/auditTests/ProofOfCodes.t.sol`:

<details>

<summary>Proof of Code</summary>

```javascript
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
```

The `maliciousMockAggregator` is a mock price feed returning outdated price data:

```javascript
 /// @notice This is the malicious part, we return the previous round as the latest round
    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        return (
            uint80(latestRound),
            getAnswer[latestRound],
            getStartedAt[latestRound],
            getTimestamp[latestRound],
@>          uint80(latestRound) - 1
        );
    }
```

Using the correct function `CorrectPriceConverter::correctConvertEthToUsd`, it reverts due to outdated price detection:

```javascript
 function staleCheckLatestRoundData(
        AggregatorV3Interface chainlinkFeed
    ) public view returns (uint80, int256, uint256, uint256, uint80) {
        (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        ) = chainlinkFeed.latestRoundData();

@>      if (updatedAt == 0 || answeredInRound < roundId) {
            revert OracleLib__StalePrice();
        }
        uint256 secondsSince = block.timestamp - updatedAt;
        if (secondsSince > TIMEOUT) revert OracleLib__StalePrice();

        return (roundId, answer, startedAt, updatedAt, answeredInRound);
    }
```

Here, `answeredInRound` is less than `roundId`, triggering a revert:

```javascript
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
@>      ) = priceFeed.staleCheckLatestRoundData();

        return (answer * int(DECIMALS)) / int(PRICE_FEED_DECIMALS);
    }
```

However, using the current function `PriceConverter::convertEthToUsd`, it does not revert and instead returns outdated price data:

```bash
 [38464] ProofOfCodes::testUnstablePriceFeedRevert()
    ├─ [0] VM::expectRevert(custom error 0xc31eb0e0: ġ  :)
    │   └─ ← [Return]
    ├─ [12672] OracleLib::staleCheckLatestRoundData() [delegatecall]
    │   ├─ [9199] MaliciousMockV3Aggregator::latestRoundData() [staticcall]
    │   │   └─ ← [Return] 1, 2000, 1, 1, 0
    │   └─ ← [Revert] OracleLib__StalePrice()
    ├─ [9199] MaliciousMockV3Aggregator::latestRoundData() [staticcall]
    │   └─ ← [Return] 1, 2000, 1, 1, 0
    ├─ [0] console::log("This is the outdated data: ", 20000000000000 [2e13]) [staticcall]
    │   └─ ← [Stop]
    └─ ← [Stop]
```

</details>

**Recommendation:**

**Recommended Mitigation:**

Modify `PriceConverter::getChainlinkDataFeedLatestAnswer` to use `staleCheckLatestRoundData` from `OracleLib` instead of `latestRoundData`. This ensures that stale or invalid price data is not used.

```diff
(
    /* uint80 roundID */,
    int answer,
    /*uint startedAt*/,
    /*uint timeStamp*/,
    /*uint80 answeredInRound*/
- ) = priceFeed.latestRoundData();
+ ) = priceFeed.staleCheckLatestRoundData();
```

## Informational

### [I-1] Incorrect File Name: `PriceCoverter` Should Be `PriceConverter`

**Description:**

The filename for the `PriceConverter` library is currently **`PriceCoverter.sol`**, which appears to be a typo. The correct spelling should be **`PriceConverter.sol`** to align with the library's actual name declared in the contract.

**Impact:**

- This typo may cause **import errors** or confusion when referencing the library in other contracts.
- Developers might unintentionally reference the wrong file name, leading to deployment or compilation issues.
- Consistency across file names and contract/library names is a best practice for maintainability and readability.

**Recommended Mitigation:**

Rename the file from **`PriceCoverter.sol`** to **`PriceConverter.sol`** to match the library name and maintain consistency.

```diff
- PriceCoverter.sol
+ PriceConverter.sol
```

Additionally, ensure all import statements in other contracts reflect the correct filename:

```diff
- import {PriceConverter} from "./PriceCoverter.sol";
+ import {PriceConverter} from "./PriceConverter.sol";
```
