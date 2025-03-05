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

**Proof of Concept:**

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

### [H-2] `Verifier` locks Ether without a withdraw function.

**Description:**

The `Verifier` contract does not implement a proper withdrawal function for accidentally sent Ether. Since the contract inherits from `Staking`, which defines a `receive()` function but does not handle unintended Ether deposits, any Ether sent to the contract will be permanently locked.

In `Staking` contract:

```javascript
@>  receive() external payable {}

    fallback() external payable {
        stake();
    }
```

This issue arises because the `Verifier` contract does not provide a way for the owner or any user to retrieve mistakenly sent Ether.
The only way to withdraw Ether from the contract is `withdrawStakeAndLoseVerifier()` and `withdrawReward()` which can only withdraw the eth that is either staked or the reward.

In `Verifier` contract:

```javascript

 function withdrawStakeAndLoseVerifier() public onlyInitialized {
        if (s_verifierToInfo[msg.sender].unhandledRequestCount > 0) {
            revert Verifier__ExistUnhandledEvidence();
        }
@>      super.withdrawStake();
    }

 function withdrawReward() public onlyInitialized {
        s_verifierToInfo[msg.sender].reward = 0;
        (bool success, ) = msg.sender.call{
@>          value: s_verifierToInfo[msg.sender].reward
        }("");
        if (!success) {
            revert Staking__WithdrawFailed();
        }

        emit Withdrawn(msg.sender, s_verifierToInfo[msg.sender].reward);
    }
```

In `Staking` contract:

```javascript
function withdrawStake() internal onlyVerifier {
        s_verifierCount -= 1;
        s_addressToIsVerifier[msg.sender] = false;
        delete s_verifierToInfo[msg.sender];

@>      (bool success, ) = msg.sender.call{value: STAKE_ETH_AMOUNT}("");
        if (!success) {
            revert Staking__WithdrawFailed();
        }

        emit LoseVerifier(msg.sender);
        emit Withdrawn(msg.sender, STAKE_ETH_AMOUNT);
    }
```

**Impact:**

- Users who send Ether to the `Verifier` contract by mistake cannot withdraw it.
- The contract may accumulate unintended funds that are forever locked.
- If users expect a refund mechanism, they may experience financial loss due to the missing withdrawal functionality.

**Proof of Concept:**

Check the following test case in `test/v2/auditTests/ProofOfCodes.t.sol`:

<details>
<summary>Proof of Code</summary>

```javascript

function testVerifierLocksEth() external {
        address ethLocker = makeAddr("ethLocker");
        deal(ethLocker, 10 ether);
        vm.prank(ethLocker);
        (bool success, ) = address(verifier).call{value: 1 ether}("");
        assertEq(success, true);

        // This will fail because it will trigger the `stake()` function
        // which will revert if the user has not provided the correct amount of eth
        // Even if someone send the correct amount of eth, he will be a verifier and can withdraw the eth back
        vm.prank(ethLocker);
        (bool fallbackSuccess, ) = address(verifier).call{value: 1 ether}(
            "Give my Eth back!"
        );
        assertEq(fallbackSuccess, false);
    }

```

- This test sends 1 ETH to the `Verifier` contract.
- There is no function to withdraw this ETH.
- As a result, the funds are irretrievable.

</details>

**Recommended Mitigation:**

1. Override the `receive()` function in the `Verifier` contract and store the received Ether in a separate variable. And implement a withdrawal function that allows the owner to send the locked Ether back to the sender.

In `Staking` contract:

```diff
-   receive() external payable {}
+   receive() external payable virtual {}
```

In `Verifier` contract:

```diff
+   mapping(address accidentLocker => uint256 lockedEth) private s_accidentLockerToEth;

+   receive() external payable override {
+        s_accidentLockerToEth[msg.sender] += msg.value;
+    }

+   sendAccidentEth(address to) external onlyOwner {
+       if(s_accidentLockerToEth[to] <=0 ) {
+           revert Verifier__NoAccidentEth();
+       }
+       s_accidentLockerToEth[to] = 0;
+       (bool success, ) = to.call{value: s_accidentLockerToEth[to]}("");
+       if (!success) {
+           revert Verifier__SendAccidentEthFailed();
+       }
+       emit AccidentEthSent(to, s_accidentLockerToEth[to]);
+    }

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

### [I-2] Unused Custom Error

**Description:**

it is recommended that the definition be removed when custom error is unused

- Found in src/VSkillUser.sol [Line: 22](src/VSkillUser.sol#L22)

  ```solidity
      error VSkillUser__EvidenceNotApprovedYet(
  ```

- Found in src/VSkillUserNft.sol [Line: 31](src/VSkillUserNft.sol#L31)

  ```solidity
      error VSkillUserNft__NotSkillHandler();
  ```

</details>

### [I-3] `abi.encodePacked()` should not be used with dynamic types when passing the result to a hash function such as `keccak256()`

**Description:**

Use `abi.encode()` instead which will pad items to 32 bytes, which will [prevent hash collisions](https://docs.soliditylang.org/en/v0.8.13/abi-spec.html#non-standard-packed-mode) (e.g. `abi.encodePacked(0x123,0x456)` => `0x123456` => `abi.encodePacked(0x1,0x23456)`, but `abi.encode(0x123,0x456)` => `0x0...1230...456`). Unless there is a compelling reason, `abi.encode` should be preferred. If there is only one argument to `abi.encodePacked()` it can often be cast to `bytes()` or `bytes32()` [instead](https://ethereum.stackexchange.com/questions/30912/how-to-compare-strings-in-solidity#answer-82739).
If all arguments are strings and or bytes, `bytes.concat()` should be used instead.

<details><summary>2 Found Instances</summary>

- Found in src/VSkillUserNft.sol [Line: 139](src/VSkillUserNft.sol#L139)

  ```solidity
                  abi.encodePacked(
  ```

- Found in src/VSkillUserNft.sol [Line: 143](src/VSkillUserNft.sol#L143)

  ```solidity
                              abi.encodePacked(
  ```

</details>

## Gas

### [G-1] Use big data storage(Contract bytecode) to store the NFT image uris

**Description:**

In `VSkillUserNft` contract, the NFT image URIs are stored in storage slot, which is expensive in terms of gas costs. It is recommended to store the image URIs in contract bytecode, which is cheaper and more efficient.

For more information head to [simple-big-data-storage](https://github.com/cqlyj/simple-big-data-storage).
