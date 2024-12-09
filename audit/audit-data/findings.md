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

### [H-5] The same verifier can call multiple times `Verifier::provideFeedback` function to dominate the evidence status, ruin the verification process

**Description:**

In the `Verifier` contract, the `provideFeedback` function is used to provide feedback for the evidence. However, the same selected verifier can just call multiple times this function to pass the `NUM_WORDS` checks and centralize the evidence status.

```javascript
function provideFeedback(
        string memory feedbackIpfsHash,
        string memory evidenceIpfsHash,
        address user,
        bool approved
    ) external {
        .
        .
        .
        // get all the verifiers who provide feedback and call the function to earn rewards or get penalized

@>      if (
@>          s_evidenceIpfsHashToItsInfo[evidenceIpfsHash]
@>              .statusApproveOrNot
@>              .length < s_numWords
        ) {
            return;
        } else {
            address[] memory allSelectedVerifiers = s_evidenceIpfsHashToItsInfo[
                evidenceIpfsHash
            ].selectedVerifiers;
            uint256 allSelectedVerifiersLength = allSelectedVerifiers.length;
            StructDefinition.VSkillUserSubmissionStatus evidenceStatus = _updateEvidenceStatus(
                    evidenceIpfsHash,
                    user
                );
            for (uint256 i = 0; i < allSelectedVerifiersLength; i++) {
                _earnRewardsOrGetPenalized(
                    evidenceIpfsHash,
                    allSelectedVerifiers[i],
                    evidenceStatus
                );
            }
        }
    }
```

**Impact:**

The same verifier can call multiple times this function to pass the `NUM_WORDS` checks and centralize the evidence status. This will ruin the verification process.

**Proof of Concept:**

Add the following test case to `./test/verifier/uint/VerifierTest.t.sol`:

<details>
<summary>
Proof of Code
</summary>

```javascript
function testSelectedVerifierCanProvideMultipleFeedbacksCentralizeTheEvidenceStatus()
        external
    {
        _createNumWordsNumberOfSameDomainVerifier(SKILL_DOMAINS);

        StructDefinition.VSkillUserEvidence memory ev = StructDefinition
            .VSkillUserEvidence(
                USER,
                IPFS_HASH,
                SKILL_DOMAINS[0],
                StructDefinition.VSkillUserSubmissionStatus.SUBMITTED,
                new string[](0)
            );
        vm.startPrank(USER);
        verifier.submitEvidence{
            value: verifier.getSubmissionFeeInUsd().convertUsdToEth(
                AggregatorV3Interface(verifierConstructorParams.priceFeed)
            )
        }(ev.evidenceIpfsHash, ev.skillDomain);
        vm.stopPrank();

        vm.recordLogs();
        verifier._requestVerifiersSelection(ev);
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[0].topics[2];
        VRFCoordinatorV2Mock vrfCoordinatorMock = VRFCoordinatorV2Mock(
            verifierConstructorParams.vrfCoordinator
        );
        vm.pauseGasMetering();
        vm.recordLogs();
        vrfCoordinatorMock.fulfillRandomWords(
            uint256(requestId),
            address(verifier)
        );
        Vm.Log[] memory entriesOfFulfillRandomWords = vm.getRecordedLogs();
        bytes32 selectedVerifierOne = entriesOfFulfillRandomWords[1].topics[1];

        address selectedVerifierAddressOne = address(
            uint160(uint256(selectedVerifierOne))
        );

        uint256 selectedVerifierOneStakeBefore = verifier
            .getVerifierMoneyStakedInEth(selectedVerifierAddressOne);
        console.log(
            "Selected verifier one stake before: ",
            selectedVerifierOneStakeBefore
        );

        uint256 selectedVerifierOneReputationBefore = verifier
            .getVerifierReputation(selectedVerifierAddressOne);
        console.log(
            "Selected verifier one reputation before: ",
            selectedVerifierOneReputationBefore
        );

        // selectedVerifierOne call multiple times to provide feedback, then earn the rewards
        for (uint160 i = 0; i < NUM_WORDS; i++) {
            vm.prank(selectedVerifierAddressOne);
            verifier.provideFeedback(
                FEEDBACK_IPFS_HASH,
                IPFS_HASH,
                USER,
                false
            );
        }

        uint256 selectedVerifierOneStake = verifier.getVerifierMoneyStakedInEth(
            selectedVerifierAddressOne
        );

        uint256 selectedVerifierOneReputation = verifier.getVerifierReputation(
            selectedVerifierAddressOne
        );

        console.log(
            "Selected verifier one stake after: ",
            selectedVerifierOneStake
        );

        console.log(
            "Selected verifier one reputation after: ",
            selectedVerifierOneReputation
        );

        assert(selectedVerifierOneStake > selectedVerifierOneStakeBefore);
        assert(
            selectedVerifierOneReputation > selectedVerifierOneReputationBefore
        );
    }
```

Then run the test case:

```bash
forge test --mt testSelectedVerifierCanProvideMultipleFeedbacksCentralizeTheEvidenceStatus -vv
```

Then you can find that, even though only `selectedVerifierOne` has provided the feedback, he is rewarded.

```bash
  Selected verifier one stake before:  10000000000000000
  Selected verifier one reputation before:  2
  Selected verifier one stake after:  10061753750000000
  Selected verifier one reputation after:  4
```

</details>

**Recommended Mitigation:**

Add some restrictions to ensure that the same verifier can only provide feedback once.

```diff
function provideFeedback(
        string memory feedbackIpfsHash,
        string memory evidenceIpfsHash,
        address user,
        bool approved
    ) external {
        _onlySelectedVerifier(evidenceIpfsHash, msg.sender);
+       _notProvideFeedbackYet(evidenceIpfsHash, msg.sender);
        .
        .
        .
    }
```

### [H-6] The same verifier can call multiple times `Verifier::provideFeedback` function and violate the `Verifier::_earnRewardsOrGetPenalized` function for `DIFFERENTOPINION` status

**Description:**

In the `Verifier` contract, the `provideFeedback` function is used to provide feedback for the evidence. However, the same selected verifier can just call multiple times this function and violate the `_earnRewardsOrGetPenalized` function for `DIFFERENTOPINION` status.

```javascript
function provideFeedback(
        string memory feedbackIpfsHash,
        string memory evidenceIpfsHash,
        address user,
        bool approved
    ) external {
        .
        .
        .
        if (
            s_evidenceIpfsHashToItsInfo[evidenceIpfsHash]
                .statusApproveOrNot
                .length < s_numWords
        ) {
            return;
        } else {
            address[] memory allSelectedVerifiers = s_evidenceIpfsHashToItsInfo[
                evidenceIpfsHash
            ].selectedVerifiers;
            uint256 allSelectedVerifiersLength = allSelectedVerifiers.length;
            StructDefinition.VSkillUserSubmissionStatus evidenceStatus = _updateEvidenceStatus(
                    evidenceIpfsHash,
                    user
                );
@>          for (uint256 i = 0; i < allSelectedVerifiersLength; i++) {
@>              _earnRewardsOrGetPenalized(
                    evidenceIpfsHash,
                    allSelectedVerifiers[i],
                    evidenceStatus
                );
            }
        }
    }
```

```javascript
function _earnRewardsOrGetPenalized(
        string memory evidenceIpfsHash,
        address verifierAddress,
        StructDefinition.VSkillUserSubmissionStatus evidenceStatus
    ) internal {
        .
        .
        .
        // DIFFERENTOPINION
@>      else {
@>          s_evidenceIpfsHashToItsInfo[evidenceIpfsHash]
@>              .statusApproveOrNot
@>              .pop();

            return;
        }
    }
```

Here is how the bug happens:

1. The first verifier provides feedback with `true` value for three times.
2. The second verifier provides feedback with `false` value.
3. Once the second verifier provided the feedback, it will reach the line to pop the `statusApproveOrNot` array since already enough feedbacks are provided.
4. Then since there are only two verifiers provide the feedback, the `statusApproveOrNot` array will not be empty. Instead it will be length of 1.
5. Then when the third verifier provides feedback, he will not be able to trigger the line for `_earnRewardsOrGetPenalized` function, because now only the array length is only 2, not enough to meet the `NUM_WORDS` checks.

**Impact:**

The same verifier can call multiple times this function and violate the `_earnRewardsOrGetPenalized` function and violates the other verifiers' rewards.

**Proof of Concept:**

Add the following test case to `./test/verifier/uint/VerifierTest.t.sol`:

<details>
<summary>
Proof of Code
</summary>

```javascript
function testStatusApprovedOrNotArrayWillBePoppedEvenWhenEmpty() external {
        _createNumWordsNumberOfSameDomainVerifier(SKILL_DOMAINS);

        StructDefinition.VSkillUserEvidence memory ev = StructDefinition
            .VSkillUserEvidence(
                USER,
                IPFS_HASH,
                SKILL_DOMAINS[0],
                StructDefinition.VSkillUserSubmissionStatus.SUBMITTED,
                new string[](0)
            );
        vm.startPrank(USER);
        verifier.submitEvidence{
            value: verifier.getSubmissionFeeInUsd().convertUsdToEth(
                AggregatorV3Interface(verifierConstructorParams.priceFeed)
            )
        }(ev.evidenceIpfsHash, ev.skillDomain);
        vm.stopPrank();

        vm.recordLogs();
        verifier._requestVerifiersSelection(ev);
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[0].topics[2];
        VRFCoordinatorV2Mock vrfCoordinatorMock = VRFCoordinatorV2Mock(
            verifierConstructorParams.vrfCoordinator
        );
        vm.pauseGasMetering();
        vm.recordLogs();
        vrfCoordinatorMock.fulfillRandomWords(
            uint256(requestId),
            address(verifier)
        );
        Vm.Log[] memory entriesOfFulfillRandomWords = vm.getRecordedLogs();
        bytes32 selectedVerifierOne = entriesOfFulfillRandomWords[1].topics[1];
        bytes32 selectedVerifierTwo = entriesOfFulfillRandomWords[2].topics[1];

        address selectedVerifierAddressOne = address(
            uint160(uint256(selectedVerifierOne))
        );
        address selectedVerifierAddressTwo = address(
            uint160(uint256(selectedVerifierTwo))
        );

        for (uint160 i = 0; i < 3; i++) {
            vm.prank(selectedVerifierAddressOne);
            verifier.provideFeedback(FEEDBACK_IPFS_HASH, IPFS_HASH, USER, true);
        }
        bool[] memory statusApproveOrNot = verifier
            .getEvidenceToStatusApproveOrNot(IPFS_HASH);
        console.log("Status approve or not: ", statusApproveOrNot.length);

        vm.prank(selectedVerifierAddressTwo);
        verifier.provideFeedback(FEEDBACK_IPFS_HASH, IPFS_HASH, USER, false);

        bool[] memory statusApproveOrNot1 = verifier
            .getEvidenceToStatusApproveOrNot(IPFS_HASH);
        console.log("Status approve or not 1: ", statusApproveOrNot1.length);

        assert(statusApproveOrNot1.length != 0);
    }
```

Then run the commands below:

```bash
forge test --mt testStatusApprovedOrNotArrayWillBePoppedEvenWhenEmpty -vv
```

And you will see the console output:

```bash
  Status approve or not:  3
  Status approve or not 1:  1
```

</details>

**Recommended Mitigation:**

Same as the previous issue, add some restrictions to ensure that the same verifier can only provide feedback once.

### [H-7] If the `Verifier::provideFeedback` function makes the same evidence with `DIFFERENTOPINION` status for more than once, the `statusApproveOrNot` array will be popped when it's empty, ruin the verification process

**Description:**

In the `Verifier` contract, the `provideFeedback` function has the logic below:

```javascript
function provideFeedback(
        string memory feedbackIpfsHash,
        string memory evidenceIpfsHash,
        address user,
        bool approved
    ) external {
        .
        .
        .
        if (
            s_evidenceIpfsHashToItsInfo[evidenceIpfsHash]
                .statusApproveOrNot
                .length < s_numWords
        ) {
            return;
        } else {
            address[] memory allSelectedVerifiers = s_evidenceIpfsHashToItsInfo[
                evidenceIpfsHash
            ].selectedVerifiers;
@>          uint256 allSelectedVerifiersLength = allSelectedVerifiers.length;
            StructDefinition.VSkillUserSubmissionStatus evidenceStatus = _updateEvidenceStatus(
                    evidenceIpfsHash,
                    user
                );

@>          for (uint256 i = 0; i < allSelectedVerifiersLength; i++) {
                _earnRewardsOrGetPenalized(
                    evidenceIpfsHash,
                    allSelectedVerifiers[i],
                    evidenceStatus
                );
            }
        }
    }
```

It will have the for loop for every ever selectedVerifiers to call the `_earnRewardsOrGetPenalized` function. However, in the function we have the logic below for `DIFFERENTOPINION` status condition:

```javascript
 function _earnRewardsOrGetPenalized(
        string memory evidenceIpfsHash,
        address verifierAddress,
        StructDefinition.VSkillUserSubmissionStatus evidenceStatus
    ) internal {
        .
        .
        .
        // DIFFERENTOPINION
        else {
@>          s_evidenceIpfsHashToItsInfo[evidenceIpfsHash]
@>              .statusApproveOrNot
@>              .pop();

            return;
        }
    }
```

Here we will pop the `statusApproveOrNot` array for the selectedVerifiers, but what the bug is, in the for loop we are popping the array for every selectedVerifiers ever, that way, if the same evidence has `DIFFERENTOPINION` status for more than once, the `statusApproveOrNot` array will be popped when it's empty.

**Impact:**

When the evidence finally get approved or rejected by the last verifier, this function will revert, And the evidence will be ruined, and the verification process will be ruined.

**Proof of Concept:**

Add the following test case to `./test/verifier/uint/VerifierTest.t.sol`:

<details>
<summary>
Proof of Code
</summary>

```javascript
function testIfMoreThanOneTimeDifferentOpinionWillRevert() external {
        uint256 numOfVerifiersWithinOneEvidence = 200;
        address[] memory verifierWithinSameDomain = new address[](
            numOfVerifiersWithinOneEvidence
        );
        for (
            uint160 i = 1;
            i < uint160(numOfVerifiersWithinOneEvidence + 1);
            i++
        ) {
            address verifierAddress = address(i);
            vm.deal(verifierAddress, INITIAL_BALANCE);
            _becomeVerifierWithSkillDomain(verifierAddress, SKILL_DOMAINS);
            verifierWithinSameDomain[i - 1] = verifierAddress;
        }

        StructDefinition.VSkillUserEvidence memory ev = StructDefinition
            .VSkillUserEvidence(
                USER,
                IPFS_HASH,
                SKILL_DOMAINS[0],
                StructDefinition.VSkillUserSubmissionStatus.SUBMITTED,
                new string[](0)
            );

        vm.startPrank(USER);
        verifier.submitEvidence{
            value: verifier.getSubmissionFeeInUsd().convertUsdToEth(
                AggregatorV3Interface(verifierConstructorParams.priceFeed)
            )
        }(ev.evidenceIpfsHash, ev.skillDomain);
        vm.stopPrank();

        vm.recordLogs();
        verifier._requestVerifiersSelection(ev);
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        VRFCoordinatorV2Mock vrfCoordinatorMock = VRFCoordinatorV2Mock(
            verifierConstructorParams.vrfCoordinator
        );
        vm.pauseGasMetering();
        vm.recordLogs();
        vrfCoordinatorMock.fulfillRandomWords(
            uint256(requestId),
            address(verifier)
        );
        Vm.Log[] memory entriesOfFulfillRandomWords = vm.getRecordedLogs();
        bytes32 selectedVerifierOne = entriesOfFulfillRandomWords[1].topics[1];
        bytes32 selectedVerifierTwo = entriesOfFulfillRandomWords[2].topics[1];
        bytes32 selectedVerifierThree = entriesOfFulfillRandomWords[3].topics[
            1
        ];
        address selectedVerifierAddressOne = address(
            uint160(uint256(selectedVerifierOne))
        );
        address selectedVerifierAddressTwo = address(
            uint160(uint256(selectedVerifierTwo))
        );
        address selectedVerifierAddressThree = address(
            uint160(uint256(selectedVerifierThree))
        );

        vm.prank(selectedVerifierAddressOne);
        verifier.provideFeedback(FEEDBACK_IPFS_HASH, IPFS_HASH, USER, true);

        vm.prank(selectedVerifierAddressTwo);
        verifier.provideFeedback(FEEDBACK_IPFS_HASH, IPFS_HASH, USER, false);
        bool[] memory statusApproveOrNot = verifier
            .getEvidenceToStatusApproveOrNot(IPFS_HASH);

        console.log("Status approve or not: ", statusApproveOrNot.length);

        vm.prank(selectedVerifierAddressThree);
        verifier.provideFeedback(FEEDBACK_IPFS_HASH, IPFS_HASH, USER, false);

        vm.recordLogs();
        verifier._requestVerifiersSelection(ev);
        Vm.Log[] memory finalEntries = vm.getRecordedLogs();
        bytes32 finalRequestId = finalEntries[1].topics[1];
        VRFCoordinatorV2Mock finalVrfCoordinatorMock = VRFCoordinatorV2Mock(
            verifierConstructorParams.vrfCoordinator
        );
        vm.pauseGasMetering();
        vm.recordLogs();
        finalVrfCoordinatorMock.fulfillRandomWords(
            uint256(finalRequestId),
            address(verifier)
        );
        Vm.Log[] memory finalEntriesOfFulfillRandomWords = vm.getRecordedLogs();
        bytes32 finalSelectedVerifierOne = finalEntriesOfFulfillRandomWords[1]
            .topics[1];
        bytes32 finalSelectedVerifierTwo = finalEntriesOfFulfillRandomWords[2]
            .topics[1];
        bytes32 finalSelectedVerifierThree = finalEntriesOfFulfillRandomWords[3]
            .topics[1];
        address finalSelectedVerifierAddressOne = address(
            uint160(uint256(finalSelectedVerifierOne))
        );
        address finalSelectedVerifierAddressTwo = address(
            uint160(uint256(finalSelectedVerifierTwo))
        );
        address finalSelectedVerifierAddressThree = address(
            uint160(uint256(finalSelectedVerifierThree))
        );

        vm.prank(finalSelectedVerifierAddressOne);
        verifier.provideFeedback(FEEDBACK_IPFS_HASH, IPFS_HASH, USER, true);

        vm.prank(finalSelectedVerifierAddressTwo);
        verifier.provideFeedback(FEEDBACK_IPFS_HASH, IPFS_HASH, USER, false);

        vm.expectRevert();
        vm.prank(finalSelectedVerifierAddressThree);
        verifier.provideFeedback(FEEDBACK_IPFS_HASH, IPFS_HASH, USER, false);
    }
```

Here we have the same evidence be `DIFFERENTOPINION` status for twice, and the `statusApproveOrNot` array will be popped when it's empty.

Then run the test case:

```bash
forge test --mt testIfMoreThanOneTimeDifferentOpinionWillRevert -vvvv
```

You can get the logs below:

```bash
    │   ├─ emit EvidenceStatusUpdated(user: user: [0x6CA6d1e2D5347Bfab1d91e883F1915560e09129D], evidenceIpfsHash: 0x4ec31a7244ef446c1acb5ded1a805b85118d0f808bcb005219f73857ca57896a, status: 4)
    │   └─ ← [Revert] panic: called `.pop()` on an empty array (0x31)
```

And yes, we indeed see the error `` panic: called `.pop()` on an empty array ``.

</details>

**Recommended Mitigation:**

Refactor the section of how to rewards the verifiers, maybe add the `Chainlink Automation` to listen for the event when the evidence is finally approved or rejected, and then rewards the verifiers.

Then, in the `_earnRewardsOrGetPenalized` function, we can pop the array only three times each time reach the `DIFFERENTOPINION` status.

## Medium

### [M-1] No bounds check in `Verifier::checkUpkeep` for the `s_evidences` array, can cause DoS attack as the array grows

**Description:**

In the `Verifier` contract, the `checkUpkeep` function is called by `chainlink` nodes to automatically check the state of the evidence and distribute the evidence to verifiers. However, there is no bounds check for the `s_evidences` array.

```javascript
function checkUpkeep(
        bytes calldata /* checkData */
    )
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        // if the evidence status is `submitted` or `differentOpinion`, this function will return true
        uint256 length = s_evidences.length;

@>      for (uint256 i = 0; i < length; i++) {
            if (
                s_evidences[i].status ==
                StructDefinition.VSkillUserSubmissionStatus.SUBMITTED ||
                s_evidences[i].status ==
                StructDefinition.VSkillUserSubmissionStatus.DIFFERENTOPINION
            ) {
                upkeepNeeded = true;
                performData = abi.encode(s_evidences[i]);
                return (upkeepNeeded, performData);
            }
        }
        upkeepNeeded = false;
        return (upkeepNeeded, "");
    }

```

**Impact:**

As the array grows, the function will consume more and more gas, and can cause a DoS attack. Then no evidence will be distributed to verifiers, ruin the verification process.

**Proof of Concept:**

Add the following test case to `./test/verifier/uint/VerifierTest.t.sol`:

<details>
<summary>
Proof of Code
</summary>

```javascript
 function testCheckUpKeepWillCostMoreGasAsTheEvidencesGrows() external {
        StructDefinition.VSkillUserEvidence
            memory dummyEvidence = StructDefinition.VSkillUserEvidence(
                USER,
                IPFS_HASH,
                SKILL_DOMAINS[0],
                StructDefinition.VSkillUserSubmissionStatus.SUBMITTED,
                new string[](0)
            );

        vm.prank(USER);
        verifier.submitEvidence{
            value: verifier.getSubmissionFeeInUsd().convertUsdToEth(
                AggregatorV3Interface(verifierConstructorParams.priceFeed)
            )
        }(dummyEvidence.evidenceIpfsHash, dummyEvidence.skillDomain);

        uint256 gasBefore = gasleft();
        vm.prank(USER);
        verifier.checkUpkeep("");
        uint256 gasAfter = gasleft();
        uint256 gasCost = gasBefore - gasAfter;
        console.log("Gas cost for 1 evidence: ", gasCost);

        for (uint160 i = 0; i < 1000; i++) {
            vm.pauseGasMetering();
            verifier.submitEvidence{
                value: verifier.getSubmissionFeeInUsd().convertUsdToEth(
                    AggregatorV3Interface(verifierConstructorParams.priceFeed)
                )
            }(dummyEvidence.evidenceIpfsHash, dummyEvidence.skillDomain);
        }

        vm.resumeGasMetering();

        uint256 gasBefore2 = gasleft();
        vm.prank(USER);
        verifier.checkUpkeep("");
        uint256 gasAfter2 = gasleft();
        uint256 gasCost2 = gasBefore2 - gasAfter2;
        console.log("Gas cost for 1001 evidence: ", gasCost2);

        assert(gasCost2 > gasCost);

        for (uint160 i = 0; i < 10000; i++) {
            vm.pauseGasMetering();
            verifier.submitEvidence{
                value: verifier.getSubmissionFeeInUsd().convertUsdToEth(
                    AggregatorV3Interface(verifierConstructorParams.priceFeed)
                )
            }(dummyEvidence.evidenceIpfsHash, dummyEvidence.skillDomain);
        }

        vm.resumeGasMetering();

        uint256 gasBefore3 = gasleft();
        vm.prank(USER);
        verifier.checkUpkeep("");
        uint256 gasAfter3 = gasleft();
        uint256 gasCost3 = gasBefore3 - gasAfter3;
        console.log("Gas cost for 11001 evidence: ", gasCost3);

        assert(gasCost3 > gasCost2);
    }
```

Then run the commands below:

```bash
forge test --mt testCheckUpKeepWillCostMoreGasAsTheEvidencesGrows -vv
```

And you will find that the gas cost for 11001 evidence is much higher than the gas cost for 1 evidence. 13192 - 7253 = 5939, almost two times higher.

```bash
  Gas cost for 1 evidence:  7253
  Gas cost for 1001 evidence:  7798
  Gas cost for 11001 evidence:  13192
```

</details>

**Recommended Mitigation:**

Instead of this custom logic automation, try to use the `Chainlink log triggering` to trigger the `checkUpkeep` function. Once someone submits the evidence, emit an event to trigger the `checkUpkeep` function.

### [M-2] The two for loops in `Verifier::_verifiersWithinSameDomain` function can cause DoS attack, as the `s_verifiers` array grows

**Description:**

In the `Verifier` contract, the `_verifiersWithinSameDomain` function has the following two for loops:

```javascript
function _verifiersWithinSameDomain(
        string memory skillDomain
    ) public view returns (address[] memory, uint256 count) {
        uint256 length = s_verifiers.length;

        uint256 verifiersWithinSameDomainCount = 0;

@>      for (uint256 i = 0; i < length; i++) {
            if (s_verifiers[i].skillDomains.length > 0) {
                uint256 skillDomainLength = s_verifiers[i].skillDomains.length;
@>              for (uint256 j = 0; j < skillDomainLength; j++) {
                    if (
                        keccak256(
                            abi.encodePacked(s_verifiers[i].skillDomains[j])
                        ) == keccak256(abi.encodePacked(skillDomain))
                    ) {
                        verifiersWithinSameDomainCount++;
                        break; // No need to check other domains for this verifier
                    }
                }
            }
        }

        address[] memory verifiersWithinSameDomain = new address[](
            verifiersWithinSameDomainCount
        );

        uint256 verifiersWithinSameDomainIndex = 0;

@>      for (uint256 i = 0; i < length; i++) {
            if (s_verifiers[i].skillDomains.length > 0) {
                uint256 skillDomainLength = s_verifiers[i].skillDomains.length;
@>              for (uint256 j = 0; j < skillDomainLength; j++) {
                    if (
                        keccak256(
                            abi.encodePacked(s_verifiers[i].skillDomains[j])
                        ) == keccak256(abi.encodePacked(skillDomain))
                    ) {
                        verifiersWithinSameDomain[
                            verifiersWithinSameDomainIndex
                        ] = s_verifiers[i].verifierAddress;
                        verifiersWithinSameDomainIndex++;
                        break; // No need to check other domains for this verifier
                    }
                }
            }
        }

        return (verifiersWithinSameDomain, verifiersWithinSameDomainCount);
    }
```

The first for loop is used to count the number of verifiers within the same domain, and the second for loop is used to get the verifiers within the same domain.

**Impact:**

As the `s_verifiers` array grows, these two for loops can cause a DoS attack.

**Proof of Concept:**

Add the following test case to `./test/verifier/uint/VerifierTest.t.sol`:

<details>
<summary>
Proof of Code
</summary>

```javascript
    function testDoSHappenWhenTooMuchVerifiers() external {
        vm.pauseGasMetering();
        uint256 numOfVerifiersWithinOneEvidence = 100;
        address[] memory verifierWithinSameDomain = new address[](
            numOfVerifiersWithinOneEvidence
        );
        for (
            uint160 i = 1;
            i < uint160(numOfVerifiersWithinOneEvidence + 1);
            i++
        ) {
            address verifierAddress = address(i);
            vm.deal(verifierAddress, INITIAL_BALANCE);
            _becomeVerifierWithSkillDomain(verifierAddress, SKILL_DOMAINS);
            verifierWithinSameDomain[i - 1] = verifierAddress;
        }
        vm.resumeGasMetering();

        uint256 gasBefore = gasleft();
        verifier._verifiersWithinSameDomain(SKILL_DOMAINS[0]);
        uint256 gasAfter = gasleft();
        uint256 gasCost = gasBefore - gasAfter;

        console.log("Gas cost for 100 verifiers: ", gasCost);

        vm.pauseGasMetering();
        uint256 numOfVerifiersWithinOneEvidence2 = 1000;
        address[] memory verifierWithinSameDomain2 = new address[](
            numOfVerifiersWithinOneEvidence2
        );
        for (
            uint160 i = 1;
            i < uint160(numOfVerifiersWithinOneEvidence2 + 1);
            i++
        ) {
            address verifierAddress = address(i);
            vm.deal(verifierAddress, INITIAL_BALANCE);
            _becomeVerifierWithSkillDomain(verifierAddress, SKILL_DOMAINS);
            verifierWithinSameDomain2[i - 1] = verifierAddress;
        }
        vm.resumeGasMetering();

        uint256 gasBefore2 = gasleft();
        verifier._verifiersWithinSameDomain(SKILL_DOMAINS[0]);
        uint256 gasAfter2 = gasleft();
        uint256 gasCost2 = gasBefore2 - gasAfter2;

        console.log("Gas cost for 1000 verifiers: ", gasCost2);

        assert(gasCost2 > gasCost);

        vm.pauseGasMetering();
        uint256 numOfVerifiersWithinOneEvidence3 = 100000;
        address[] memory verifierWithinSameDomain3 = new address[](
            numOfVerifiersWithinOneEvidence3
        );
        for (
            uint160 i = 1;
            i < uint160(numOfVerifiersWithinOneEvidence3 + 1);
            i++
        ) {
            address verifierAddress = address(i);
            vm.deal(verifierAddress, INITIAL_BALANCE);
            _becomeVerifierWithSkillDomain(verifierAddress, SKILL_DOMAINS);
            verifierWithinSameDomain3[i - 1] = verifierAddress;
        }
        vm.resumeGasMetering();

        vm.expectRevert();
        verifier._verifiersWithinSameDomain(SKILL_DOMAINS[0]);

        console.log("Revert due to DoS!");
    }
```

When we set the num of verifiers to 100000, this function reverts!

And you can run the command below to check the logs see the gas cost for `100` and `1000` verifiers calling this function:

```bash
forge test --mt testDoSHappenWhenTooMuchVerifiers -vv
```

Output:

```bash
  Gas cost for 100 verifiers:  472882
  Gas cost for 1000 verifiers:  4898941
  Revert due to DoS!
```

Here 100 costs `472882`, 1000 costs `4898941`, almost 10 times expensive gas cost!

</details>

**Recommended Mitigation:**

Consider use a map to store the skill domains to the verifiers and when select the verifiers, only a certain amount of verifiers will be first selected as the participants in the final selection.

### [M-3] The for loop in `Verifier::_selectedVerifiersAddressCallback` function can cause DoS attack, as the `s_verifiers` array grows

**Description:**

Same as above but in the `Verifier::_selectedVerifiersAddressCallback` function:

```javascript
 function _selectedVerifiersAddressCallback(
        StructDefinition.VSkillUserEvidence memory ev,
        uint256[] memory randomWords
    )
        public
        enoughNumberOfVerifiers(ev.skillDomain)
        returns (address[] memory)
    {
        address[] memory selectedVerifiers = new address[](s_numWords);

        (
            address[] memory verifiersWithinSameDomain,
            uint256 verifiersWithinSameDomainCount
        ) = _verifiersWithinSameDomain(ev.skillDomain);

        uint256 totalReputationScore = 0;
@>      for (uint256 i = 0; i < verifiersWithinSameDomainCount; i++) {
            totalReputationScore += s_verifiers[
                s_addressToId[verifiersWithinSameDomain[i]] - 1
            ].reputation;
        }

        uint256[] memory selectedIndices = new uint256[](totalReputationScore);

        uint256 selectedIndicesCount = 0;

@>      for (uint256 i = 0; i < verifiersWithinSameDomainCount; i++) {
            uint256 reputation = s_verifiers[
                s_addressToId[verifiersWithinSameDomain[i]] - 1
            ].reputation;
            for (uint256 j = 0; j < reputation; j++) {
                selectedIndices[selectedIndicesCount] = i;
                selectedIndicesCount++;
            }
        }

        for (uint256 i = 0; i < s_numWords; i++) {
            uint256 randomIndex = randomWords[i] % totalReputationScore;
            selectedVerifiers[i] = verifiersWithinSameDomain[
                selectedIndices[randomIndex]
            ];
        }

        _updateSelectedVerifiersInfo(ev.evidenceIpfsHash, selectedVerifiers);

        _assignEvidenceToSelectedVerifier(ev, selectedVerifiers);

        return selectedVerifiers;
    }
```

**Impact:**

As the `s_verifiers` array grows, this for loop can cause a DoS attack.

**Recommended Mitigation:**

Same as `M-2`, as only a certain amount of verifiers will be first selected as the participants in the final selection. The `verifiersWithinSameDomainCount` will be limited to a certain amount.

### [M-4] Using memory variables to update the status of evidence in `Verifier::_assignEvidenceToSelectedVerifier` function, will drain the `Chainlink Automation` service

**Description:**

In the `Verifier` contract, the `_assignEvidenceToSelectedVerifier` use a memory variable as the evidence to update its `status`, which will not update the status of the evidence in the storage.

```javascript
function _assignEvidenceToSelectedVerifier(
@>      StructDefinition.VSkillUserEvidence memory ev,
        address[] memory selectedVerifiers
    ) internal {
        .
        .
        .
@>      ev.status = StructDefinition.VSkillUserSubmissionStatus.INREVIEW;
        emit EvidenceStatusUpdated(
            ev.submitter,
            ev.evidenceIpfsHash,
            ev.status
        );
    }

```

**Impact:**

As a result, the evidence status will not be updated in the storage and remains as `SUBMITTED`, which will trigger the ``checkUpkeep` function being called by `Chainlink Automation` node, cost the money and drain the service.

**Proof of Concept:**

Add the following test case to `./test/verifier/uint/VerifierTest.t.sol`:

<details>
<summary>
Proof of Code
</summary>

```javascript
 function testEvidenceStatusNotUpdateAfterDistributedToVerifiers() external {
        _createNumWordsNumberOfSameDomainVerifier(SKILL_DOMAINS);

        StructDefinition.VSkillUserEvidence memory ev = StructDefinition
            .VSkillUserEvidence(
                USER,
                IPFS_HASH,
                SKILL_DOMAINS[0],
                StructDefinition.VSkillUserSubmissionStatus.SUBMITTED,
                new string[](0)
            );
        vm.startPrank(USER);
        verifier.submitEvidence{
            value: verifier.getSubmissionFeeInUsd().convertUsdToEth(
                AggregatorV3Interface(verifierConstructorParams.priceFeed)
            )
        }(ev.evidenceIpfsHash, ev.skillDomain);
        vm.stopPrank();

        vm.recordLogs();
        verifier._requestVerifiersSelection(ev);
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[0].topics[2];
        VRFCoordinatorV2Mock vrfCoordinatorMock = VRFCoordinatorV2Mock(
            verifierConstructorParams.vrfCoordinator
        );
        vm.pauseGasMetering();
        vrfCoordinatorMock.fulfillRandomWords(
            uint256(requestId),
            address(verifier)
        );

        StructDefinition.VSkillUserSubmissionStatus status = verifier
            .getEvidenceStatus(USER, 0);
        assert(uint256(status) != uint256(SubmissionStatus.INREVIEW));
        console.log("Evidence status: ", uint256(status));
    }
```

</details>

**Recommended Mitigation:**

Change the `ev` variable to the storage variable to update the status of the evidence in the storage. Or just pass some parameters which can be used to get the storage evidence.

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

### [L-3] No validation check in `Verifier::updateSkillDomains` function, verifier can update the skill domain to whatever value they want

**Description:**

In the `Verifier` contract, the `updateSkillDomains` function is used to update the skill domains. However, there is no validation check for the skill domain value.

```javascript
function updateSkillDomains(
        string[] memory newSkillDomains
    ) external isVeifier {
@>      s_verifiers[s_addressToId[msg.sender] - 1]
            .skillDomains = newSkillDomains;
        emit VerifierSkillDomainUpdated(msg.sender, newSkillDomains);
    }
```

**Impact:**

The verifier can update the skill domain to whatever value they want, which might be hard to manage.

**Recommended Mitigation:**

Add a validation check for the skill domain value.

```diff
function updateSkillDomains(
        string[] memory newSkillDomains
    ) external isVeifier {
+       _validSkillDomains(newSkillDomains);
        s_verifiers[s_addressToId[msg.sender] - 1]
            .skillDomains = newSkillDomains;
        emit VerifierSkillDomainUpdated(msg.sender, newSkillDomains);
    }
```

This `_validSkillDomains` function should check if the user input skill domains exist in the predefined skill domains.

### [L-4] User can call the `VSkillUserNft::mintUserNft` with non-exist skill domain

**Description:**

In the `VSkillUserNft` contract, the `mintUserNft` function does not check if the skill domain exists.

```javascript
@>  function mintUserNft(string memory skillDomain) public {
        _safeMint(msg.sender, s_tokenCounter);
        s_tokenIdToSkillDomain[s_tokenCounter] = skillDomain;
        s_tokenCounter++;

        emit MintNftSuccess(s_tokenCounter - 1, skillDomain);
    }
```

**Impact:**

The user can call the `mintUserNft` function with a non-exist skill domain, generate a lot of no-sense NFTs.

**Proof of Concept:**

Add the following test case to `./test/nft/uint/VSkillUserNftTest.t.sol`:

<details>
<summary>
Proof of Code
</summary>

```javascript
function testUserCanMintANonExistentSkillDomain() external {
        vm.prank(USER);
        vskillUserNft.mintUserNft("non-existent-skill-domain");
        uint256 tokenCounter = vskillUserNft.getTokenCounter();
        assertEq(tokenCounter, 1);
    }
```

</details>

**Recommended Mitigation:**

Add the validation check for the skill domain value.

```diff
 function mintUserNft(string memory skillDomain) public {
+       for (uint256 i = 0; i < s_skillDomains.length; i++) {
+           if (
+               keccak256(abi.encodePacked(s_skillDomains[i])) ==
+               keccak256(abi.encodePacked(skillDomain))
+           ) {
+               break;
+           }
+           if (i == s_skillDomains.length - 1) {
+               revert VSkillUserNft__SkillDomainNotFound(skillDomain);
+           }
+       }
        _safeMint(msg.sender, s_tokenCounter);
        s_tokenIdToSkillDomain[s_tokenCounter] = skillDomain;
        s_tokenCounter++;

        emit MintNftSuccess(s_tokenCounter - 1, skillDomain);
    }
```

### [L-5] Invalid `tokenId` will result in blank `imageUri` in `VSkillUserNft::tokenURI` function

**Description:**

In the `VSkillUserNft` contract, the `tokenURI` function has no validation check for the `tokenId`.

```javascript
function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
@>      string memory skillDomain = s_tokenIdToSkillDomain[tokenId];
@>      string memory imageUri = s_skillDomainToUserNftImageUri[skillDomain];

        return
            string(
                abi.encodePacked(
                    _baseURI(),
                    Base64.encode(
                        bytes( // bytes casting actually unnecessary as 'abi.encodePacked()' returns a bytes
                            abi.encodePacked(
                                '{"name":"',
                                name(),
                                '", "description":"Proof of capability of the skill", ',
                                '"attributes": [{"trait_type": "skill", "value": 100}], "image":"',
                                imageUri,
                                '"}'
                            )
                        )
                    )
                )
            );
    }
```

**Impact:**

If the user input an invalid `tokenId`, the `imageUri` will be blank.

**Proof of Concept:**

Add the following test case to `./test/nft/uint/VSkillUserNftTest.t.sol`:

<details>
<summary>
Proof of Code
</summary>

```javascript
 function testInvalidTokenIdWillReturnBlankString() external view {
        string memory skillDomain = vskillUserNft.tokenURI(100);
        assertEq(
            skillDomain,
            "data:application/json;base64,eyJuYW1lIjoiVlNraWxsVXNlck5mdCIsICJkZXNjcmlwdGlvbiI6IlByb29mIG9mIGNhcGFiaWxpdHkgb2YgdGhlIHNraWxsIiwgImF0dHJpYnV0ZXMiOiBbeyJ0cmFpdF90eXBlIjogInNraWxsIiwgInZhbHVlIjogMTAwfV0sICJpbWFnZSI6IiJ9"
        );
    }
```

You can copy the `data:application...` to your browser and you will find the output like this:

```json
{
  "name": "VSkillUserNft",
  "description": "Proof of capability of the skill",
  "attributes": [
    {
      "trait_type": "skill",
      "value": 100
    }
  ],
  "image": ""
}
```

The image is blank.

</details>

**Recommended Mitigation:**

Add the validation check for the `tokenId`.

```diff
error VSkillUserNft__InvalidTokenId(uint256 tokenId);

function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
+       if (_ownerOf(tokenId) == address(0)) {
+           revert VSkillUserNft__InvalidTokenId(tokenId);
+       }
        string memory skillDomain = s_tokenIdToSkillDomain[tokenId];
        string memory imageUri = s_skillDomainToUserNftImageUri[skillDomain];

        return
            string(
                abi.encodePacked(
                    _baseURI(),
                    Base64.encode(
                        bytes( // bytes casting actually unnecessary as 'abi.encodePacked()' returns a bytes
                            abi.encodePacked(
                                '{"name":"',
                                name(),
                                '", "description":"Proof of capability of the skill", ',
                                '"attributes": [{"trait_type": "skill", "value": 100}], "image":"',
                                imageUri,
                                '"}'
                            )
                        )
                    )
                )
            );
    }
```

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

### [I-2] Solidity pragma should be specific, not wide

Consider using a specific version of Solidity in your contracts instead of a wide version. For example, instead of `pragma solidity ^0.8.24;`, use `pragma solidity 0.8.24;`

<details><summary>6 Found Instances</summary>

- Found in src/nft/VSkillUserNft.sol [Line: 3](src/nft/VSkillUserNft.sol#L3)

  ```solidity
  pragma solidity ^0.8.24;
  ```

- Found in src/oracle/Distribution.sol [Line: 2](src/oracle/Distribution.sol#L2)

  ```solidity
  pragma solidity ^0.8.24;
  ```

- Found in src/staking/Staking.sol [Line: 3](src/staking/Staking.sol#L3)

  ```solidity
  pragma solidity ^0.8.24;
  ```

- Found in src/user/VSkillUser.sol [Line: 2](src/user/VSkillUser.sol#L2)

  ```solidity
  pragma solidity ^0.8.24;
  ```

- Found in src/utils/interface/VerifierInterface.sol [Line: 3](src/utils/interface/VerifierInterface.sol#L3)

  ```solidity
  pragma solidity ^0.8.24;
  ```

- Found in src/verifier/Verifier.sol [Line: 2](src/verifier/Verifier.sol#L2)

  ```solidity
  pragma solidity ^0.8.24;
  ```

</details>

### [I-3] `public` functions not used internally could be marked `external`

Instead of marking a function as `public`, consider marking it as `external` if it is not used internally.

<details><summary>28 Found Instances</summary>

- Found in src/nft/VSkillUserNft.sol [Line: 54](src/nft/VSkillUserNft.sol#L54)

  ```solidity
      function mintUserNft(string memory skillDomain) public {
  ```

- Found in src/nft/VSkillUserNft.sol [Line: 68](src/nft/VSkillUserNft.sol#L68)

  ```solidity
      function tokenURI(
  ```

- Found in src/nft/VSkillUserNft.sol [Line: 103](src/nft/VSkillUserNft.sol#L103)

  ```solidity
      function _addMoreSkillsForNft(
  ```

- Found in src/oracle/Distribution.sol [Line: 60](src/oracle/Distribution.sol#L60)

  ```solidity
      function distributionRandomNumberForVerifiers(
  ```

- Found in src/oracle/Distribution.sol [Line: 116](src/oracle/Distribution.sol#L116)

  ```solidity
      function getRandomWords() public view returns (uint256[] memory) {
  ```

- Found in src/oracle/Distribution.sol [Line: 120](src/oracle/Distribution.sol#L120)

  ```solidity
      function getRequestIdToContext(
  ```

- Found in src/oracle/Distribution.sol [Line: 130](src/oracle/Distribution.sol#L130)

  ```solidity
      function getSubscriptionId() public view returns (uint64) {
  ```

- Found in src/oracle/Distribution.sol [Line: 134](src/oracle/Distribution.sol#L134)

  ```solidity
      function getVrfCoordinator()
  ```

- Found in src/oracle/Distribution.sol [Line: 142](src/oracle/Distribution.sol#L142)

  ```solidity
      function getKeyHash() public view returns (bytes32) {
  ```

- Found in src/oracle/Distribution.sol [Line: 146](src/oracle/Distribution.sol#L146)

  ```solidity
      function getCallbackGasLimit() public view returns (uint32) {
  ```

- Found in src/oracle/Distribution.sol [Line: 150](src/oracle/Distribution.sol#L150)

  ```solidity
      function getRequestConfirmations() public view returns (uint16) {
  ```

- Found in src/staking/Staking.sol [Line: 97](src/staking/Staking.sol#L97)

  ```solidity
      function withdrawStake(uint256 amountToWithdrawInEth) public virtual {
  ```

- Found in src/staking/Staking.sol [Line: 189](src/staking/Staking.sol#L189)

  ```solidity
      function addBonusMoneyForVerifier() public payable {
  ```

- Found in src/staking/Staking.sol [Line: 378](src/staking/Staking.sol#L378)

  ```solidity
      function getVerifierEvidenceIpfsHash(
  ```

- Found in src/staking/Staking.sol [Line: 414](src/staking/Staking.sol#L414)

  ```solidity
      function getBonusMoneyInEth() public view returns (uint256) {
  ```

- Found in src/user/VSkillUser.sol [Line: 83](src/user/VSkillUser.sol#L83)

  ```solidity
      function submitEvidence(
  ```

- Found in src/user/VSkillUser.sol [Line: 143](src/user/VSkillUser.sol#L143)

  ```solidity
      function checkFeedbackOfEvidence(
  ```

- Found in src/user/VSkillUser.sol [Line: 161](src/user/VSkillUser.sol#L161)

  ```solidity
      function earnUserNft(
  ```

- Found in src/user/VSkillUser.sol [Line: 185](src/user/VSkillUser.sol#L185)

  ```solidity
      function changeSubmissionFee(uint256 newFeeInUsd) public virtual onlyOwner {
  ```

- Found in src/user/VSkillUser.sol [Line: 198](src/user/VSkillUser.sol#L198)

  ```solidity
      function addMoreSkills(
  ```

- Found in src/verifier/Verifier.sol [Line: 331](src/verifier/Verifier.sol#L331)

  ```solidity
      function stake() public payable override {
  ```

- Found in src/verifier/Verifier.sol [Line: 335](src/verifier/Verifier.sol#L335)

  ```solidity
      function withdrawStake(uint256 amountToWithdrawInEth) public override {
  ```

- Found in src/verifier/Verifier.sol [Line: 343](src/verifier/Verifier.sol#L343)

  ```solidity
      function submitEvidence(
  ```

- Found in src/verifier/Verifier.sol [Line: 350](src/verifier/Verifier.sol#L350)

  ```solidity
      function checkFeedbackOfEvidence(
  ```

- Found in src/verifier/Verifier.sol [Line: 356](src/verifier/Verifier.sol#L356)

  ```solidity
      function earnUserNft(
  ```

- Found in src/verifier/Verifier.sol [Line: 362](src/verifier/Verifier.sol#L362)

  ```solidity
      function changeSubmissionFee(
  ```

- Found in src/verifier/Verifier.sol [Line: 368](src/verifier/Verifier.sol#L368)

  ```solidity
      function addMoreSkills(
  ```

- Found in src/verifier/Verifier.sol [Line: 636](src/verifier/Verifier.sol#L636)

  ```solidity
      function _selectedVerifiersAddressCallback(
  ```

</details>

### [I-4] Define and use `constant` variables instead of using literals

If the same constant literal value is used multiple times, create a constant state variable and reference it throughout the contract.

<details><summary>2 Found Instances</summary>

- Found in src/utils/library/PriceCoverter.sol [Line: 33](src/utils/library/PriceCoverter.sol#L33)

  ```solidity
          return (ethAmount * uint256(ethPrice)) / 1e18;
  ```

- Found in src/utils/library/PriceCoverter.sol [Line: 41](src/utils/library/PriceCoverter.sol#L41)

  ```solidity
          return (usdAmount * 1e18) / uint256(ethPrice);
  ```

</details>

### [I-5] PUSH0 is not supported by all chains

Solc compiler version 0.8.20 switches the default target EVM version to Shanghai, which means that the generated bytecode will include PUSH0 opcodes. Be sure to select the appropriate EVM version in case you intend to deploy on a chain other than mainnet like L2 chains that may not support PUSH0, otherwise deployment of your contracts will fail.

<details><summary>8 Found Instances</summary>

- Found in src/nft/VSkillUserNft.sol [Line: 3](src/nft/VSkillUserNft.sol#L3)

  ```solidity
  pragma solidity ^0.8.24;
  ```

- Found in src/oracle/Distribution.sol [Line: 2](src/oracle/Distribution.sol#L2)

  ```solidity
  pragma solidity ^0.8.24;
  ```

- Found in src/staking/Staking.sol [Line: 3](src/staking/Staking.sol#L3)

  ```solidity
  pragma solidity ^0.8.24;
  ```

- Found in src/user/VSkillUser.sol [Line: 2](src/user/VSkillUser.sol#L2)

  ```solidity
  pragma solidity ^0.8.24;
  ```

- Found in src/utils/interface/VerifierInterface.sol [Line: 3](src/utils/interface/VerifierInterface.sol#L3)

  ```solidity
  pragma solidity ^0.8.24;
  ```

- Found in src/utils/library/PriceCoverter.sol [Line: 3](src/utils/library/PriceCoverter.sol#L3)

  ```solidity
  pragma solidity ^0.8.24;
  ```

- Found in src/utils/library/StructDefinition.sol [Line: 3](src/utils/library/StructDefinition.sol#L3)

  ```solidity
  pragma solidity ^0.8.24;
  ```

- Found in src/verifier/Verifier.sol [Line: 2](src/verifier/Verifier.sol#L2)

  ```solidity
  pragma solidity ^0.8.24;
  ```

</details>

### [I-6] Modifiers invoked only once can be shoe-horned into the function

<details><summary>1 Found Instances</summary>

- Found in src/verifier/Verifier.sol [Line: 115](src/verifier/Verifier.sol#L115)

  ```solidity
      modifier enoughNumberOfVerifiers(string memory skillDomain) {
  ```

</details>

### [I-7] Unused Custom Error

it is recommended that the definition be removed when custom error is unused

<details><summary>1 Found Instances</summary>

- Found in src/staking/Staking.sol [Line: 23](src/staking/Staking.sol#L23)

  ```solidity
      error Staking__AlreadyVerifier();
  ```

</details>

### [I-8] Costly operations inside loops.

Invoking `SSTORE`operations in loops may lead to Out-of-gas errors. Use a local variable to hold the loop computation result.

<details><summary>4 Found Instances</summary>

- Found in src/nft/VSkillUserNft.sol [Line: 42](src/nft/VSkillUserNft.sol#L42)

  ```solidity
          for (uint256 i = 0; i < skillDomainLength; i++) {
  ```

- Found in src/verifier/Verifier.sol [Line: 314](src/verifier/Verifier.sol#L314)

  ```solidity
              for (uint256 i = 0; i < allSelectedVerifiersLength; i++) {
  ```

- Found in src/verifier/Verifier.sol [Line: 759](src/verifier/Verifier.sol#L759)

  ```solidity
          for (uint256 i = 0; i < s_numWords; i++) {
  ```

- Found in src/verifier/Verifier.sol [Line: 870](src/verifier/Verifier.sol#L870)

  ```solidity
          for (uint256 i = 1; i < statusLength; i++) {
  ```

</details>

### [I-9] State variable could be declared constant

State variables that are not updated following deployment should be declared constant to save gas. Add the `constant` attribute to state variables that never change.

<details><summary>2 Found Instances</summary>

- Found in src/oracle/Distribution.sol [Line: 29](src/oracle/Distribution.sol#L29)

  ```solidity
      uint16 s_requestConfirmations = 3;
  ```

- Found in src/oracle/Distribution.sol [Line: 30](src/oracle/Distribution.sol#L30)

  ```solidity
      uint32 s_numWords = 3;
  ```

</details>

### [I-10] State variable could be declared immutable

State variables that are should be declared immutable to save gas. Add the `immutable` attribute to state variables that are only changed in the constructor

<details><summary>5 Found Instances</summary>

- Found in src/oracle/Distribution.sol [Line: 25](src/oracle/Distribution.sol#L25)

  ```solidity
      uint64 s_subscriptionId;
  ```

- Found in src/oracle/Distribution.sol [Line: 26](src/oracle/Distribution.sol#L26)

  ```solidity
      VRFCoordinatorV2Interface s_vrfCoordinator;
  ```

- Found in src/oracle/Distribution.sol [Line: 27](src/oracle/Distribution.sol#L27)

  ```solidity
      bytes32 s_keyHash;
  ```

- Found in src/oracle/Distribution.sol [Line: 28](src/oracle/Distribution.sol#L28)

  ```solidity
      uint32 s_callbackGasLimit;
  ```

- Found in src/staking/Staking.sol [Line: 54](src/staking/Staking.sol#L54)

  ```solidity
      AggregatorV3Interface internal s_priceFeed;
  ```

</details>

### [I-11] It's best to use the most up-to-date version of `Chainlink VRF`

**Description:**

In the `Distribution` contract, we are using the `VRFCoordinatorV2` contract, which is the old version of the `Chainlink VRF`. It's best to use the most up-to-date version of version 2.5.
