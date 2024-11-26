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
