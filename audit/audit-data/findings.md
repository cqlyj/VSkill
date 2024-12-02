## High

### [H-1] No restrictions in `VSKillUserNft::mintUserNft` function, anyone can directly call and mint NFTs

**Description:**

In the `VSKillUserNft` contract, the `mintUserNft` function is public and no checks are performed to ensure that only the `VSKill` contract can call this function. This means that anyone can call this function and mint NFTs.

**Impact:**

Users do not need to pay any fees and being verified before minting NFTs. This can lead to a large number of NFTs being minted by anyone. Ruin the verification process.

**Proof of Concept:**

Add the following test case to `VerifierTest.t.sol` file:

<details>
<summary>
Proof of Code
</summary>

```javascript

function testAnyoneCanMintUserNftWithoutEnrollingProtocol() external {
        address randomUser = makeAddr("randomUser");
        string memory skillDomainRandomUserWants = SKILL_DOMAINS[0];
        vm.prank(randomUser);
        verifier.mintUserNft(skillDomainRandomUserWants);

        assert(verifier.getTokenCounter() == 1);
    }

```

</details>

**Recommended Mitigation:**

Add `openzeppelin` access control like `Ownable` to ensure that only the `VSKill` contract can call the `mintUserNft` function.

Then add the modifier `onlyOwner` to the `mintUserNft` function.

```diff
-   function mintUserNft(string memory skillDomain) public {
+   function mintUserNft(string memory skillDomain) public onlyOwner {
        _safeMint(msg.sender, s_tokenCounter);
        s_tokenIdToSkillDomain[s_tokenCounter] = skillDomain;
        s_tokenCounter++;

        emit MintNftSuccess(s_tokenCounter - 1, skillDomain);
    }
```

### [H-2] No restrictions in `Distribution::distributionRandomNumberForVerifiers` function, anyone can directly call it, drain the subscription Link tokens

**Description:**

In the `Distribution` contract, the `distributionRandomNumberForVerifiers` function is public and no checks are performed to ensure that only the `VSKill` contract can call this function.

```javascript
 function distributionRandomNumberForVerifiers(
        address requester,
        StructDefinition.VSkillUserEvidence memory ev
@>  ) public {
        s_requestId = s_vrfCoordinator.requestRandomWords(
            s_keyHash,
            s_subscriptionId,
            s_requestConfirmations,
            s_callbackGasLimit,
            s_numWords
        );

        s_requestIdToContext[s_requestId] = StructDefinition
            .DistributionVerifierRequestContext(requester, ev);

        emit RequestIdToContextUpdated(
            s_requestId,
            s_requestIdToContext[s_requestId]
        );
    }
```

**Impact:**

This means that anyone can call this function and drain the subscription Link tokens, since each time request is made, it will consume the `Chainlink` Link tokens.

**Proof of Concept:**

Add the following test case to `VerifierTest.t.sol` file:

<details>
<summary>
Proof of Code
</summary>

```javascript

 event RequestIdToContextUpdated(
        uint256 indexed requestId,
        StructDefinition.DistributionVerifierRequestContext context
    );

    using StructDefinition for StructDefinition.DistributionVerifierRequestContext;

    function testAnyoneCanMakeRequestToVRF() external {
        address randomUser = makeAddr("randomUser");
        StructDefinition.VSkillUserEvidence
            memory dummyEvidence = StructDefinition.VSkillUserEvidence(
                randomUser,
                IPFS_HASH,
                SKILL_DOMAINS[0],
                StructDefinition.VSkillUserSubmissionStatus.SUBMITTED,
                new string[](0)
            );

        StructDefinition.DistributionVerifierRequestContext
            memory context = StructDefinition
                .DistributionVerifierRequestContext(randomUser, dummyEvidence);

        vm.expectEmit(true, false, false, false, address(verifier));
        emit RequestIdToContextUpdated(1, context);
        vm.prank(randomUser);
        verifier.distributionRandomNumberForVerifiers(
            randomUser,
            dummyEvidence
        );
    }
```

</details>

**Recommended Mitigation:**

Same as the first issue, add `openzeppelin` access control like `Ownable` to ensure that only the `VSKill` contract can call the `distributionRandomNumberForVerifiers` function.

Then add the modifier `onlyOwner` to the `distributionRandomNumberForVerifiers` function.

```diff
function distributionRandomNumberForVerifiers(
        address requester,
        StructDefinition.VSkillUserEvidence memory ev
-   ) public {
+   ) public onlyOwner {
        s_requestId = s_vrfCoordinator.requestRandomWords(
            s_keyHash,
            s_subscriptionId,
            s_requestConfirmations,
            s_callbackGasLimit,
            s_numWords
        );

        s_requestIdToContext[s_requestId] = StructDefinition
            .DistributionVerifierRequestContext(requester, ev);

        emit RequestIdToContextUpdated(
            s_requestId,
            s_requestIdToContext[s_requestId]
        );
    }
```

### [H-3] The way delete verifier in `Staking::_removeVerifier` function is not correct, it will ruin the way we fetch verifiers

**Description:**

In the `Staking` contract, the `_removeVerifier` function is implemented in the way below:

```javascript
function _removeVerifier(address verifierAddress) internal {
        uint256 index = s_addressToId[verifierAddress] - 1;
        // @audit-high The way to remove the verifier is not safe, because the id is used to get the index, and the index is used to remove the verifier
        s_verifiers[index] = s_verifiers[s_verifierCount - 1];
        s_verifiers.pop();

        s_addressToId[verifierAddress] = 0;
        s_verifierCount--;

        emit LoseVerifier(verifierAddress);
    }
```

It first gets the index of the verifier, then removes the verifier by replacing the verifier with the last verifier in the array, and then pops the last verifier. This will leads to problem of out-of-range index when fetching verifiers.

How we fetch verifiers in other functions:

```javascript
s_verifiers[s_addressToId[verifierAddress] - 1];
```

As shown, we use the id to get the index of the verifier, and then use the index to get the verifier. But the index will be changed every time a verifier is removed, and thus ruin the way we fetch verifiers in other functions.

**Impact:**

Every time a verifier is removed, the verifiers array will be re-ordered, and the index of the verifiers will be changed. This will lead to the problem of out-of-range index when fetching verifiers. And thus ruin the way we fetch verifiers in other functions.

**Proof of Concept:**

Let's say we have 5 verifiers in the array, and we remove the 3rd verifier. The array will be like this:

```bash
Before:
Verifier 1 2 3 4 5
Index    0 1 2 3 4
```

1. Get the index of the verifier to be removed, which is 3. The index is 2.
2. Replace the verifier with the last verifier in the array, and then pop the last verifier. The array will be like this:

```bash
After:
Verifier 1 2 5 4
Index    0 1 2 3
```

3. Now let's say I want to get the 5th verifier, the index is 4. But we only have 4 verifiers in the array, so the index is out-of-range. Which will lead to the problem of out-of-range index when fetching verifiers and ruin the way we fetch verifiers in other functions.

**Recommended Mitigation:**

There are several ways to fix this issue:

1. Instead of really moving the verifier, we can just set the verifier to be removed to `address(0)`, and then emit an event to notify that the verifier is removed. This way, the index of the verifiers will not be changed, and we can still fetch verifiers correctly. And as for the total number of verifiers, we can just decrease the total number of verifiers by 1.

2. We can use a mapping to store the verifiers, and then use the id to get the verifier. This way, the index of the verifiers will not be changed, and we can still fetch verifiers correctly.

### [H-4] No restrictions in `VSkillUser::earnUserNft` function, anyone can directly call it by passing an approved evidence parameter to mint NFTs, ruin the verification process

**Description:**

In the `VSkillUser` contract, the `earnUserNft` function is public and no checks are performed to make sure that the evidence is approved by the verifier. This means that anyone can call this function by passing an approved evidence parameter to mint NFTs.

```javascript
 function earnUserNft(
@>      StructDefinition.VSkillUserEvidence memory _evidence
@>  ) public virtual {
@>      if (
@>          _evidence.status !=
@>          StructDefinition.VSkillUserSubmissionStatus.APPROVED
        ) {
            revert VSkillUser__EvidenceNotApprovedYet(_evidence.status);
        }

        super.mintUserNft(_evidence.skillDomain);
    }
```

The malicious user can just pass an approved evidence parameter to mint NFTs, which will ruin the verification process.

**Impact:**

Users do not need to pay any fees and being verified before minting NFTs. This can lead to a large number of NFTs being minted by anyone. Ruin the verification process.

**Proof of Concept:**

Add the following test case to `./test/user/uint/VSkillUserTest.t.sol`:

<details>
<summary>
Proof of Code
</summary>

```javascript
using StructDefinition for StructDefinition.VSkillUserSubmissionStatus;

    function testAnyoneCanMintAnNftWithoutSubmitAndGetVerified() external {
        StructDefinition.VSkillUserEvidence memory evidence = StructDefinition
            .VSkillUserEvidence(
                USER,
                IPFS_HASH,
                SKILL_DOMAIN,
                StructDefinition.VSkillUserSubmissionStatus.APPROVED,
                new string[](0)
            );

        vm.prank(USER);
        vskill.earnUserNft(evidence);

        assertEq(vskill.getTokenCounter(), 1);
    }
```

</details>

**Recommended Mitigation:**

Add a modifier to ensure that only the verifier can call the `earnUserNft` function.

```diff
function earnUserNft(
        StructDefinition.VSkillUserEvidence memory _evidence
-   ) public virtual {
+   ) public virtual onlyOwner {
        if (
            _evidence.status !=
            StructDefinition.VSkillUserSubmissionStatus.APPROVED
        ) {
            revert VSkillUser__EvidenceNotApprovedYet(_evidence.status);
        }

        super.mintUserNft(_evidence.skillDomain);
    }
```

## Low

### [L-1] The check condition in `VSkillUser::checkFeedbackOfEvidence` is wrong, user will be reverted due to the return statement, not custom error message

**Description:**

In the `VSkillUser` contract, the `checkFeedbackOfEvidence` function is checking the index of user evidence validity. However, the check condition is wrong.

```javascript
 function checkFeedbackOfEvidence(
        uint256 indexOfUserEvidence
    ) public view virtual returns (string[] memory) {
@>      if (indexOfUserEvidence >= s_evidences.length) {
            revert VSkillUser__EvidenceIndexOutOfRange();
        }

@>      return
            s_addressToEvidences[msg.sender][indexOfUserEvidence]
                .feedbackIpfsHash;
    }
```

This check checks the index of the user evidence with the overall length of the evidences. However, the index should be checked with the length of the user evidences.

**Impact:**

If user input the index of the evidence that is out of range, the user will be reverted due to the return statement, not custom error message.

**Proof of Concept:**

Add the following test case to `./test/user/uint/VSkillUserTest.t.sol`:

<details>
<summary>
Proof of Code
</summary>

```javascript
 function testCheckFeedbackOfEvidenceAlwaysRevertAsLongAsMoreThanTwoUsersSubmitEvidence()
        external
    {
        vm.startPrank(USER);
        vskill.submitEvidence{value: SUBMISSION_FEE_IN_ETH}(
            IPFS_HASH,
            SKILL_DOMAIN
        );
        vm.stopPrank();

        address anotherUser = makeAddr("anotherUser");
        vm.deal(anotherUser, INITIAL_BALANCE);
        vm.startPrank(anotherUser);
        vskill.submitEvidence{value: SUBMISSION_FEE_IN_ETH}(
            IPFS_HASH,
            SKILL_DOMAIN
        );
        vm.stopPrank();

        vm.prank(USER);
        vm.expectRevert();
        vskill.checkFeedbackOfEvidence(1);
    }
```

Then run this test case:

```bash
forge test --mt testCheckFeedbackOfEvidenceAlwaysRevertAsLongAsMoreThanTwoUsersSubmitEvidence -vvvv
```

And you will find that the test case revert with the error:

```bash
 ├─ [697] VSkillUser::checkFeedbackOfEvidence(1) [staticcall]
    │   └─ ← [Revert] panic: array out-of-bounds access (0x32)
```

This `array out-of-bounds access (0x32)` error is not our custom error `VSkillUser__EvidenceIndexOutOfRange()` and is from the return statement.

</details>

**Recommended Mitigation:**

Just change the check condition to check the index of the user evidence with the length of the user evidences.

```diff
function checkFeedbackOfEvidence(
        uint256 indexOfUserEvidence
    ) public view virtual returns (string[] memory) {
-       if (indexOfUserEvidence >= s_evidences.length) {
+       if (indexOfUserEvidence >= s_addressToEvidences[msg.sender].length) {
            revert VSkillUser__EvidenceIndexOutOfRange();
        }

        return
            s_addressToEvidences[msg.sender][indexOfUserEvidence]
                .feedbackIpfsHash;
    }
```

### [L-2] Not checking the stability of the price feed in `PriceConverter::getChainlinkDataFeedLatestAnswer`, may lead to wrong conversion

**Description:**

In the `PriceConverter` library, the `getChainlinkDataFeedLatestAnswer` function is used to get the latest price feed from the `Chainlink` oracle. However, the stability of the price feed is not checked.

**Impact:**

This might lead to wrong conversion, if the price feed is not stable.

**Recommended Mitigation:**

Rewrite the `getChainlinkDataFeedLatestAnswer` function to check the stability of the price feed for a certain period of time.

## Informational

### [I-1] Best follow the CEI in `Staking::withdrawStake` function

**Description:**

In the `Staking` contract, the `withdrawStake` function not follow the `Checks-Effects-Interactions` pattern, it sends the money first and then updates the state.

```javascript
function withdrawStake(uint256 amountToWithdrawInEth) public virtual {
        .
        .
        .
@>      (bool success, ) = msg.sender.call{value: amountToWithdrawInEth}("");
        if (!success) {
            revert Staking__WithdrawFailed();
        }

@>      s_verifiers[s_addressToId[msg.sender] - 1]
            .moneyStakedInEth -= amountToWithdrawInEth;
        .
        .
        .
    }
```

However, The verifier cannot withdraw their stakes multiple times and drain the protocol because the state change will be reverted if the moneyStakedInEth is negative.

**Impact:**

It's best to follow the best practices, which can avoid this kind psuedo-reentrancy attack.

**Proof of Concept:**

In the `test/staking/uint/StakingTest.t.sol` file, add the following test case:

<details>
<summary>
Proof of Code
</summary>

```javascript
 function testVerifierCanDrainTheProtocolByReenterWithdrawStakeFunction()
        external
    {
        vm.startPrank(USER);
        staking.stake{value: 2 * MIN_ETH_AMOUNT}();
        vm.stopPrank();

        MaliciousUser attacker = new MaliciousUser(staking);
        address attackUser = makeAddr("attackUser");
        vm.deal(attackUser, MIN_ETH_AMOUNT);

        uint256 balanceBefore = address(staking).balance;
        uint256 balanceBeforeAttacker = address(attacker).balance;
        console.log("Balance before attack: ", balanceBefore);
        console.log("Attacker balance before attack: ", balanceBeforeAttacker);

        vm.expectRevert();
        vm.startPrank(attackUser);
        attacker.hack{value: MIN_ETH_AMOUNT}();
        vm.stopPrank();

        uint256 balanceAfter = address(staking).balance;
        uint256 balanceAfterAttacker = address(attacker).balance;
        console.log("Balance after attack: ", balanceAfter);
        console.log("Attacker balance after attack: ", balanceAfterAttacker);
    }
```

And also this contract:

```javascript
contract MaliciousUser {
    using PriceConverter for uint256;

    Staking staking;
    // Only works on anvil local chain, since we know the price is 2000 USD per ETH
    uint256 MIN_ETH_AMOUNT = 1e16;

    constructor(Staking _stakingContract) {
        staking = _stakingContract;
    }

    function hack() external payable {
        staking.stake{value: MIN_ETH_AMOUNT}();
        staking.withdrawStake(MIN_ETH_AMOUNT);
    }

    receive() external payable {
        if (address(staking).balance >= MIN_ETH_AMOUNT) {
            staking.withdrawStake(MIN_ETH_AMOUNT);
        }
    }
}
```

</details>

Then run the test case:

```bash
forge test --mt testVerifierCanDrainTheProtocolByReenterWithdrawStakeFunction -vvvvv
```

You will see the logs like below:

```bash
  │   ├─ [42884] Staking::withdrawStake(10000000000000000 [1e16])
    │   │   ├─ [34747] MaliciousUser::receive{value: 10000000000000000}()
    │   │   │   ├─ [33743] Staking::withdrawStake(10000000000000000 [1e16])
    │   │   │   │   ├─ [25452] MaliciousUser::receive{value: 10000000000000000}()
    │   │   │   │   │   ├─ [24460] Staking::withdrawStake(10000000000000000 [1e16])
    │   │   │   │   │   │   ├─ [396] MaliciousUser::receive{value: 10000000000000000}()
    │   │   │   │   │   │   │   └─ ← [Stop]
    │   │   │   │   │   │   ├─ emit Withdrawn(staker: MaliciousUser: [0x2e234DAe75C793f67A35089C9d99245E1C58470b], amount: 10000000000000000 [1e16])
    │   │   │   │   │   │   ├─ emit VerifierStakeUpdated(verifier: MaliciousUser: [0x2e234DAe75C793f67A35089C9d99245E1C58470b], previousAmountInEth: 10000000000000000 [1e16], newAmountInEth: 0)
    │   │   │   │   │   │   ├─ [993] MockV3Aggregator::latestRoundData() [staticcall]
    │   │   │   │   │   │   │   └─ ← [Return] 1, 200000000000 [2e11], 1, 1, 1
    │   │   │   │   │   │   ├─ emit LoseVerifier(verifier: MaliciousUser: [0x2e234DAe75C793f67A35089C9d99245E1C58470b])
    │   │   │   │   │   │   └─ ← [Stop]
    │   │   │   │   │   └─ ← [Stop]
    │   │   │   │   └─ ← [Revert] panic: arithmetic underflow or overflow (0x11)
    │   │   │   └─ ← [Revert] panic: arithmetic underflow or overflow (0x11)
    │   │   └─ ← [Revert] Staking__WithdrawFailed()
    │   └─ ← [Revert] Staking__WithdrawFailed()
```

And also you can see the console value:

```bash
  Balance before attack:  20000000000000000
  Attacker balance before attack:  0
  Balance after attack:  20000000000000000
  Attacker balance after attack:  0
```

We didn't see the attacker's balance increase, which means the attacker cannot drain the protocol by reentering the `withdrawStake` function.

**Recommended Mitigation:**

Just follow the some best practices.
