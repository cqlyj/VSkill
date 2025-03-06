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

### [H-3] Incomplete Verifier Deletion Allows Removed Verifiers to Be Selected

**Description:**

In the `Verifier::withdrawStakeAndLoseVerifier` function, the current implementation does not fully remove a verifier from all relevant mappings and arrays. Specifically, while the verifier is removed from `s_verifierToInfo`, they are still present in `s_skillDomainToVerifiersWithinSameDomain`. As a result, they can still be selected as verifiers even after withdrawing their stake as in `Relayer` contract, the `Relayer::assignEvidenceToVerifiers` function selects the verifiers based on this `s_skillDomainToVerifiersWithinSameDomain` mapping:

In `Verifier` contract:

```javascript

    function withdrawStakeAndLoseVerifier() public onlyInitialized {
        if (s_verifierToInfo[msg.sender].unhandledRequestCount > 0) {
            revert Verifier__ExistUnhandledEvidence();
        }
@>      super.withdrawStake();
    }

```

We only called the `withdrawStake()` function as below:

```javascript
 function withdrawStake() internal onlyVerifier {
@>      s_verifierCount -= 1;
@>      s_addressToIsVerifier[msg.sender] = false;
@>      delete s_verifierToInfo[msg.sender];

        (bool success, ) = msg.sender.call{value: STAKE_ETH_AMOUNT}("");
        if (!success) {
            revert Staking__WithdrawFailed();
        }

        emit LoseVerifier(msg.sender);
        emit Withdrawn(msg.sender, STAKE_ETH_AMOUNT);
    }
```

As we can find, the `s_skillDomainToVerifiersWithinSameDomain` mapping is not updated in the `withdrawStakeAndLoseVerifier` function.

However, in `Relayer` contract, which handles the verifier selection, the `assignEvidenceToVerifiers` function selects verifiers based on the `s_skillDomainToVerifiersWithinSameDomain` mapping:

```javascript
 function assignEvidenceToVerifiers() external onlyOwner {
        .
        .
        .
        for (uint256 i = 0; i < length; i++) {
            uint256 requestId = s_unhandledRequestIds[i];
            uint256[]
                memory randomWordsWithinRange = s_requestIdToRandomWordsWithinRange[
                    requestId
                ];
@>          address[] memory verifiersWithinSameDomain = i_verifier
@>              .getSkillDomainToVerifiersWithinSameDomain(
@>                  i_vSkillUser.getRequestIdToEvidence(requestId).skillDomain
@>              );
        .
        .
        .
    }
```

**Impact:**

- Even though the verifier is no longer active, they can still be randomly assigned new verification tasks.
- This can disrupt the verification process and potentially allow an unqualified verifier to be assigned tasks.
- It introduces inconsistencies in the system, where the internal state does not accurately reflect the verifier’s status.

**Proof of Concept:**

1. A verifier calls `withdrawStakeAndLoseVerifier()`.
2. The contract removes them from `s_verifierToInfo` but does not remove them from `s_skillDomainToVerifiersWithinSameDomain`.
3. The function `assignEvidenceToVerifiers` still selects verifiers based on `s_skillDomainToVerifiersWithinSameDomain`, which includes the removed verifier.
4. The removed verifier may still be assigned verification tasks and ruin this protocol.

Check the following test case in `test/v2/auditTests/ProofOfCodes.t.sol`:

<details>

<summary>Proof of Code</summary>

```javascript
function testVerifierDeletionIsNotComplete() external {
        address verifierAddress = makeAddr("verifier");
        deal(verifierAddress, 1 ether);

        vm.startPrank(verifierAddress);
        verifier.stake{value: verifier.getStakeEthAmount()}();
        verifier.addSkillDomain("Blockchain");

        uint256 verifierWithinSameDomainLength = verifier
            .getSkillDomainToVerifiersWithinSameDomainLength("Blockchain");

        verifier.withdrawStakeAndLoseVerifier();
        uint256 verifierWithinSameDomainLengthAfterDeletion = verifier
            .getSkillDomainToVerifiersWithinSameDomainLength("Blockchain");

        vm.stopPrank();

        console.log(
            "Verifier within same domain length before deletion: ",
            verifierWithinSameDomainLength
        );
        console.log(
            "Verifier within same domain length after deletion: ",
            verifierWithinSameDomainLengthAfterDeletion
        );
        console.log("You can find that the deletion is not complete!");
        console.log(
            "Thus, even if the verifier is deleted, he can still be selected!!!"
        );
    }
```

</details>

**Recommended Mitigation:**

Ensure that when a verifier withdraws their stake, they are also removed from `s_skillDomainToVerifiersWithinSameDomain`. Modify `withdrawStakeAndLoseVerifier()` as follows:

```diff
function withdrawStakeAndLoseVerifier() public onlyInitialized {
        if (s_verifierToInfo[msg.sender].unhandledRequestCount > 0) {
            revert Verifier__ExistUnhandledEvidence();
        }
        super.withdrawStake();

+        string[] memory skillDomains = s_verifierToInfo[msg.sender].skillDomains;
+        uint256 length = skillDomains.length;
+        _removeVerifierFromSkillDomain(skillDomains, length, msg.sender);
    }

```

Where this `_removeVerifierFromSkillDomain` function can be designed as you wish, but it will be better create another variable like a mapping from the skill domain to the verifiers and remove the verifier from this mapping as this will be much gas efficient.

## Medium

### [M-1] Lack of Getter Function for Verifiers to Retrieve Their Assigned Request IDs

**Description:**

The `Verifier` contract assigns verifiers to evidence requests but does not provide a way for them to retrieve their assigned request IDs. This omission forces verifiers to rely on off-chain tracking or event logs, which may be inefficient or unreliable.

Currently, assigned request IDs are stored in `s_verifierToInfo[msg.sender].assignedRequestIds` but cannot be accessed through a public or external function.

**Impact:**

- Verifiers cannot directly check which requests they have been assigned.
- This forces reliance on event logs, which may not be accessible in some cases.
- Makes it harder for verifiers to track pending tasks, increasing the likelihood of missing deadlines and penalties.

**Recommended Mitigation:**

Implement a public getter function for verifiers to check their assigned request IDs.

```diff
+ function getVerifierAssignedRequestIds(
+        address verifier
+    ) external view returns (uint256[] memory) {
+        return s_verifierToInfo[verifier].assignedRequestIds;
+    }
```

## Low

### [L-1] Incorrect Custom Error in `VSkillUser::_calledByVerifierContract`

**Description:**
The `_calledByVerifierContract` function incorrectly uses the `VSkillUser__NotRelayer` error when reverting. The intended check is for the `Verifier` contract, not the `Relayer`.

```javascript
 function _calledByVerifierContract() internal view {
@>      if (msg.sender != Relayer(i_relayer).getVerifierContractAddress()) {
@>          revert VSkillUser__NotRelayer();
        }
    }
```

The error message should clearly indicate that the caller is not the `Verifier` contract, not that it's not the `Relayer`.

**Impact:**

- Misleading error message: Developers debugging contract interactions may misunderstand the issue.
- Harder troubleshooting: Incorrect error messages can make it difficult to determine the real cause of a failed transaction.

**Recommended Mitigation:**

Replace the incorrect error message with a more appropriate one:

```diff
+   error VSkillUser__NotVerifierContract();
function _calledByVerifierContract() internal view {
    if (msg.sender != Relayer(i_relayer).getVerifierContractAddress()) {
-       revert VSkillUser__NotRelayer(); // Incorrect
+       revert VSkillUser__NotVerifierContract(); // Correct
    }
}
```

### [L-2] Potential DoS Risk Due to Excessive Assignments in `Relayer::assignEvidenceToVerifiers`

**Description:**

The `assignEvidenceToVerifiers` function assigns verifiers to evidence requests by randomly selecting verifiers from `verifiersWithinSameDomain`. However, the function does not impose a cap on the number of assignments a single verifier can receive, leading to potential overload.

In `Relayer` contract:

```javascript
 function assignEvidenceToVerifiers() external onlyOwner {
        .
        .
        .
        for (uint256 i = 0; i < length; i++) {
            uint256 requestId = s_unhandledRequestIds[i];
            uint256[]
                memory randomWordsWithinRange = s_requestIdToRandomWordsWithinRange[
                    requestId
                ];
@>          address[] memory verifiersWithinSameDomain = i_verifier
@>              .getSkillDomainToVerifiersWithinSameDomain(
@>                  i_vSkillUser.getRequestIdToEvidence(requestId).skillDomain
@>              );
@>          for (uint8 j = 0; j < randomWordsWithinRange.length; j++) {
@>              s_requestIdToVerifiersAssigned[requestId].push(
@>                  verifiersWithinSameDomain[randomWordsWithinRange[j]]
@>              );
@>              i_verifier.setVerifierAssignedRequestIds(
@>                  requestId,
@>                  verifiersWithinSameDomain[randomWordsWithinRange[j]]
@>              );
@>              i_verifier.addVerifierUnhandledRequestCount(
@>                  verifiersWithinSameDomain[randomWordsWithinRange[j]]
@>              );
@>              // only 7 days allowed for the verifiers to provide feedback
@>              i_vSkillUser.setDeadline(requestId, block.timestamp + DEADLINE);
@>          }
@>      }
        .
        .
        .
    }

```

And if verifier cannot provide the feedback within deadline, they will be a punishment for verifiers:

```javascript
 // punish is lose the verifier, not the same as penalize
    function punishVerifier(
        address verifier
    ) public onlyInitialized onlyRelayer {
        // take all the stake out and remove the verifier
        s_addressToIsVerifier[verifier] = false;
        s_verifierCount -= 1;
        // what about the stake money? The money will be collected by the staking contract and will be used to reward the verifiers who provide feedback
        // also those rewards will be used to reward the verifiers who provide feedback
        s_reward += super.getStakeEthAmount();
        s_reward += s_verifierToInfo[verifier].reward;
        delete s_verifierToInfo[verifier];

        emit LoseVerifier(verifier);
    }
```

There is a risk that a verifier is overloaded with too many requests, preventing them from providing timely feedback. This can lead to:

1. Denial of Service (DoS): If a verifier has an excessive number of pending requests, they might be unable to process all of them before deadlines expire.
2. Unfair Stake Loss: Since verifiers must provide feedback before a deadline, failing to do so results in penalties, potentially leading to the loss of their stake.
3. Imbalanced Workload: If certain domains have fewer verifiers, some might receive significantly more requests than others, worsening the issue.

**Impact:**

- A single verifier could be assigned an excessive number of requests.
- If they cannot provide feedback on all requests before deadlines, they will be penalized unfairly.
- If a skill domain has too few verifiers, they could be overloaded, creating a bottleneck in the verification process.
- This may lead to unintended stake losses and discourage participation.

**Proof of Concept:**

1. Deploy the contract and register a small number of verifiers in a specific domain.
2. Submit a large number of evidence requests.
3. Observe that the few available verifiers receive an excessive number of assignments.
4. If verifiers fail to meet deadlines, they are penalized, even if the workload is too high.

**Recommended Mitigation:**

1. Enforce an Assignment Cap: Before assigning a request, check if a verifier is already handling too many requests.
2. Ensure Fair Distribution:
   - If a verifier is overloaded, select another one from the pool.
   - If all verifiers in a domain are overloaded, prioritize those with the fewest assignments.

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

### [I-4] Excess Submission Fee Taken

**Description:**

In the `VSkillUser::submitEvidence` function, if a user submits more than the required `s_submissionFeeInUsd`, the excess amount is not refunded.

```javascript
 function submitEvidence(
        string memory cid,
        string memory skillDomain
    ) public payable onlyInitialized {
@>      if (msg.value.convertEthToUsd(i_priceFeed) < s_submissionFeeInUsd) {
            revert VSkillUser__NotEnoughSubmissionFee();
        }
        .
        .
        .
```

This behavior may be intentional, allowing the contract owner to use the excess funds at their discretion. However, users may expect a refund instead of their excess payment being treated as profit.

**Impact:**

- Unexpected fund retention: Users might not realize that excess ETH is not refunded.
- Potential user dissatisfaction: Some users might assume they will only pay the exact required submission fee.
- Owner discretion: While the owner can withdraw the funds and possibly return them, this is not guaranteed by the contract.

**Proof of Concept:**

Check the following test case in `test/v2/auditTests/ProofOfCodes.t.sol`:

<details>
<summary>Proof of Code</summary>

If a user sends more than the required submission fee:

```javascript
 function testUserCanSendMoreThanRequiredForSubmission() external {
        vm.prank(USER);
        vSkillUser.submitEvidence{
            value: vSkillUser.getSubmissionFeeInEth() + 1e18
        }("cid", "Blockchain"); // We know that Blockchain is a valid skill domain from the config

        uint256 evidenceLength = vSkillUser.getEvidences().length;
        assertEq(evidenceLength, 1);
    }
```

Here is the log:

```bash
 ├─ [15010] VSkillUser::getSubmissionFeeInEth() [staticcall]
    │   ├─ [8991] MockV3Aggregator::latestRoundData() [staticcall]
    │   │   └─ ← [Return] 1, 200000000000 [2e11], 1, 1, 1
    │   └─ ← [Return] 2500000000000000 [2.5e15]
    ├─ [532533] VSkillUser::submitEvidence{value: 1002500000000000000}("cid", "Blockchain")
    │   ├─ [991] MockV3Aggregator::latestRoundData() [staticcall]
    │   │   └─ ← [Return] 1, 200000000000 [2e11], 1, 1, 1
    │   ├─ [124693] Distribution::distributionRandomNumberForVerifiers()
    │   │   ├─ [115438] VRFCoordinatorV2_5Mock::requestRandomWords(RandomWordsRequest({ keyHash: 0xd89b2bf150e3b9e13446986e571fb9cab24b13cea0a43ea20a6049a85cc807cc, subId: 71559651348530707092126447838144209774845187901096159534269265783461099618592 [7.155e76], requestConfirmations: 3, callbackGasLimit: 500000 [5e5], numWords: 3, extraArgs: 0x92fd13380000000000000000000000000000000000000000000000000000000000000000 }))
    │   │   │   ├─ emit RandomWordsRequested(keyHash: 0xd89b2bf150e3b9e13446986e571fb9cab24b13cea0a43ea20a6049a85cc807cc, requestId: 1, preSeed: 100, subId: 71559651348530707092126447838144209774845187901096159534269265783461099618592 [7.155e76], minimumRequestConfirmations: 3, callbackGasLimit: 500000 [5e5], numWords: 3, extraArgs: 0x92fd13380000000000000000000000000000000000000000000000000000000000000000, sender: Distribution: [0x50EEf481cae4250d252Ae577A09bF514f224C6C4])
    │   │   │   └─ ← [Return] 1
    │   │   ├─ emit VerifierDistributionRequested(requestId: 1)
    │   │   └─ ← [Return] 1
    │   ├─ emit VSkillUser__EvidenceSubmitted(submitter: ProofOfCodes: [0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496])
```

- The contract does not refund the extra ETH.
- Instead, the excess amount is retained for the owner.
- Users have no way to retrieve the excess funds themselves.

</details>

**Recommended Mitigation:**

If the intention is only charge the exact amount of ETH, modify the function to check for `!=` instead of `<`, also modify the error message to reflect the new condition.

```diff
 function submitEvidence(
        string memory cid,
        string memory skillDomain
    ) public payable onlyInitialized {
-        if (msg.value.convertEthToUsd(i_priceFeed) < s_submissionFeeInUsd) {
+        if (msg.value.convertEthToUsd(i_priceFeed) != s_submissionFeeInUsd) {
-            revert VSkillUser__NotEnoughSubmissionFee();
+            revert VSkillUser__IncorrectSubmissionFee();
        }
        .
        .
        .
```

If the current behavior is intended, add a clear comment and update documentation to inform users:

```diff
 function submitEvidence(
        string memory cid,
        string memory skillDomain
    ) public payable onlyInitialized {
+       // The submission fee is fixed and any excess amount will be retained by the contract owner as profit.
        if (msg.value.convertEthToUsd(i_priceFeed) < s_submissionFeeInUsd) {
            revert VSkillUser__NotEnoughSubmissionFee();
        }
```

### [I-5] Unused Variable `Verifier::i_priceFeed`

**Description:**

The `Verifier` contract declares an variable `i_priceFeed` which is never used in the contract.:

```javascript
AggregatorV3Interface private immutable i_priceFeed;
```

**Impact:**

- Wasted deployment gas: Assigning an immutable variable consumes gas at deployment.
- Increased bytecode size: Keeping unused variables increases contract size without providing functionality.
- Code maintainability: Unused variables can cause confusion and reduce code clarity.

**Recommended Mitigation:**

Remove it to optimize gas usage and contract size:

```diff
- AggregatorV3Interface private immutable i_priceFeed;
```

### [I-6] Unused Event `Verifier::Verifier__LoseVerifier`

**Description:**

The `Verifier` contract defines an event `Verifier__LoseVerifier`, but it is never emitted anywhere in the contract:

```javascript
event Verifier__LoseVerifier(address indexed verifier);
```

**Impact:**

- Wasted gas on deployment: Declaring an unused event increases contract size and deployment costs.
- Reduces code clarity: Unused events may mislead developers into thinking they are relevant when they are not.

**Recommended Mitigation:**

Remove the unused event

```diff
- event Verifier__LoseVerifier(address indexed verifier);
```

## Gas

### [G-1] Use big data storage(Contract bytecode) to store the NFT image uris

**Description:**

In `VSkillUserNft` contract, the NFT image URIs are stored in storage slot, which is expensive in terms of gas costs. It is recommended to store the image URIs in contract bytecode, which is cheaper and more efficient.

For more information head to [simple-big-data-storage](https://github.com/cqlyj/simple-big-data-storage).

### [G-2] Redundant `tx.origin` Check in `onlyRelayer` Modifier

**Description:**

The `VSkillUser::onlyRelayer` modifier includes a redundant check:

```javascript
@>  if (msg.sender != i_relayer || tx.origin != owner()) {
        revert VSkillUser__NotRelayer();
    }
    _;
```

Since the contract's design ensures that only the relayer contract can call certain functions by owner which is set at the deployment, checking `tx.origin` against `owner()` is unnecessary. Even if the `tx.origin` is not the owner, it's a deployment issue, not a security issue. The second check adds unnecessary gas costs without providing additional security.

**Recommended Mitigation:**

Remove the redundant `tx.origin` check to optimize gas usage:

```diff
modifier onlyRelayer() {
-   if (msg.sender != i_relayer || tx.origin != owner()) {
+   if (msg.sender != i_relayer) {
        revert VSkillUser__NotRelayer();
    }
    _;
}
```
