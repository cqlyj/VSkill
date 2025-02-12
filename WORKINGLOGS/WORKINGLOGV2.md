## VSKill Version 2 Working Log

### Checklist of Issues

**High Severity**

- [x] **[H-1]** No restrictions in `VSKillUserNft::mintUserNft` function, anyone can directly call and mint NFTs.
- [x] **[H-2]** No restrictions in `Distribution::distributionRandomNumberForVerifiers` function, anyone can directly call it and drain the subscription Link tokens.
- [x] **[H-3]** The way verifiers are deleted in `Staking::_removeVerifier` function is incorrect, potentially ruining the process of fetching verifiers.
- [x] **[H-4]** No restrictions in `VSkillUser::earnUserNft` function, anyone can directly call it with an approved evidence parameter to mint NFTs, ruining the verification process.
- [x] **[H-5]** The same verifier can call `Verifier::provideFeedback` multiple times to dominate the evidence status, ruining the verification process.
- [x] **[H-6]** The same verifier can call `Verifier::provideFeedback` multiple times and exploit `Verifier::_earnRewardsOrGetPenalized` for the `DIFFERENTOPINION` status.
- [x] **[H-7]** If `Verifier::provideFeedback` sets the same evidence to `DIFFERENTOPINION` multiple times, `statusApproveOrNot` array may be popped when it's empty, ruining the verification process.
- [x] **[H-8]** Verifiers lose all their stake when their reputation is less than `LOWEST_REPUTATION` and may still be penalized again.

**Medium Severity**

- [x] **[M-1]** No bounds check in `Verifier::checkUpkeep` for the `s_evidences` array, which can cause a DoS attack as the array grows.
- [x] **[M-2]** The two `for` loops in `Verifier::_verifiersWithinSameDomain` function can cause a DoS attack as the `s_verifiers` array grows.
- [x] **[M-3]** The `for` loop in `Verifier::_selectedVerifiersAddressCallback` function can cause a DoS attack as the `s_verifiers` array grows.
- [x] **[M-4]** Using memory variables to update the status of evidence in `Verifier::_assignEvidenceToSelectedVerifier` function will drain the Chainlink Automation service.

**Low Severity**

- [x] **[L-1]** The check condition in `VSkillUser::checkFeedbackOfEvidence` is incorrect, causing a revert without the custom error message.
- [x] **[L-2]** No stability check for the price feed in `PriceConverter::getChainlinkDataFeedLatestAnswer`, which may lead to incorrect conversions.
- [x] **[L-3]** No validation in `Verifier::updateSkillDomains` function, allowing verifiers to set arbitrary skill domains.
- [x] **[L-4]** Users can call `VSkillUserNft::mintUserNft` with non-existent skill domains.
- [x] **[L-5]** Invalid `tokenId` results in a blank `imageUri` in `VSkillUserNft::tokenURI` function.

**Informational**

- [x] **[I-1]** Follow the Checks-Effects-Interactions (CEI) pattern in `Staking::withdrawStake` function.
- [x] **[I-2]** Solidity pragma should be specific, not wide.
- [x] **[I-3]** Public functions not used internally could be marked `external`.
- [x] **[I-4]** Define and use constant variables instead of literals.
- [x] **[I-5]** `PUSH0` is not supported by all chains.
- [x] **[I-6]** Modifiers invoked only once could be integrated directly into the function.
- [x] **[I-7]** Unused custom error definitions.
- [x] **[I-8]** Avoid costly operations inside loops.
- [x] **[I-9]** State variables could be declared `constant`.
- [x] **[I-10]** State variables could be declared `immutable`.
- [x] **[I-11]** Use the most up-to-date version of Chainlink VRF.
- [x] **[I-12]** Centralization risk for trusted owners.
- [x] **[I-13]** `Verifier::provideFeedback` function is too long, making maintenance difficult.
- [x] **[I-14]** The first verifier who submits feedback is rewarded more than subsequent verifiers.

**Gas Optimization**

- [x] **[G-1]** Custom error messages include constants (`Staking::minStakeUsdAmount` and `VSkillUser::submittedFeeInUsd`), which cost more gas.
- [x] **[G-2]** Two functions in the `Staking` contract perform the same task, wasting gas.
- [x] **[G-3]** Double checks in `Verifier::_earnRewardsOrGetPenalized` function result in unnecessary gas consumption.
- [x] **[G-4]** Repeated computation of `Verifier::keccak256(abi.encodePacked(evidenceIpfsHash))` wastes gas.

---

### 2024/12/17

**Plan for version 2**

- This version should first solve those issues that are of high severity.
- We will add the zksync chain and other chains like polygon, avalanche, and arbitrum...
- We will separate the contracts instead of inheriting them.
- We will conduct another more verbose audit including fuzzing and symbolic execution.
- We will make a bunch of changes to the structure!!!
  - The main actors are the verifiers and the users. => Two separate contracts working together.
  - cross-chain features can be considered. That is, the user can use the same NFT on different chains. => maybe leave to version 3.
- We will write a bunch of scripts to make the deployment process more automated.

**What did I do today**

- Update the checklist of issues.
- Using OracleLib library for to ensure the price feed stability.

---

### 2025/1/2

**The new structure of the contracts**

- Two main actors: Verifiers and Users.
- Verifiers contract will contain the staking and verification logic.
- Users contract will contain the NFT minting and evidence submission logic.
- The two contracts will be two separate contracts, not inherited.
- A `Relayer` contract will be used to communicate between the two contracts:
  - Once a user submits evidence, the relayer contract will get the random number to assign the evidence to verifiers.
  - Once the verifiers submit feedback, the relayer contract will update the status of the evidence.
  - The relayer contract will also be responsible for the distribution of rewards and penalties. => All the stake and submission fees will be stored in the relayer contract. Act as a pool thus the distribution will be easier.

**What did I do today**

- Remove some unnecessary variables in the `StructDefinition` library. Those variables actually not needed to record on-chain.

```diff
 struct StakingVerifier {
-        uint256 id;
        address verifierAddress;
        uint256 reputation;
        string[] skillDomains;
        uint256 moneyStakedInEth;
-        address[] evidenceSubmitters;
-        string[] evidenceIpfsHash;
-        string[] feedbackIpfsHash;
    }
```

- Refactor the `Staking` contract.
  - This contract will be served as some inherited functions for the `Verifier` contract.
  - Only three functions will be left in this contract: `stake` and `withdrawStake` and `withdrawStakeAndLoseVerifier`
  - As for `addBonusMoneyForVerifier` functions, will be moved to the `Relayer` contract.

---

### 2025/1/3

**What did I do today**

- Refactor the `VSkillUserNft` contract.
  - This contract will be deployed separately from the `Verifier` contract.
  - Later only the Relayer contract will be able to mint the NFTs for the users.
  - This may need RBAC (Role-Based Access Control) to be implemented. => The Relayer contract will be able to mint, the owner (us) will be able to add new domains
- The design of how the `Oracle` and `Verifier` contract coordinate needs redesign.
  - The `Oracle` contract will be responsible for getting the random number, btw, the `Oracle` contract needs to upgrade to the latest version of Chainlink VRF.
  - The `Relayer` contract will be responsible for reading the random number from the `Oracle` contract and assigning the evidence to the verifiers.
  - The `Verifier` contract will be responsible for submitting feedback, for those evidence and feedbacks
    - => Consider the user of `protocolLab` service to store the evidence and feedbacks.
    - => Consider use the blob storage service to store the evidence and feedbacks since they are not sensitive data and do we want to store those on-chain forever?
- Refactor the `Oracle` contract.
  - This contract will now only be responsible for getting the random number. And we will still use the subscription method, we want to pay the random number fee for the users.
  - This contract will be inherited by the `Relayer` contract.

---

### 2025/1/4

**What did I do today**

- Clean the `VSkillUser` contract
  - This contract will be deployed separately from the `Verifier` contract.
  - The `VSkillUser` contract will be responsible for submitting evidence and retrieving the feedbacks.
  - The `VSkillUser` contract will be able to read the feedbacks from the `protocolLab` service.
  - The `VSkillUser` contract will send the submission fee to the `Relayer` contract.
  - The actual refactor will be done after researching the `protocolLab` service.
- Clean the `Verifier` contract
  - This contract will be deployed separately from the `VSkillUser` contract.
  - The `Verifier` contract will be responsible for submitting feedbacks.
  - The `Verifier` contract will be able to read the evidence from the `protocolLab` service.
  - As for the rewards and penalties, the `Relayer` contract will be responsible for that.
  - The actual refactor will be done after researching the `protocolLab` service and implementing the `Relayer` contract.
- Update the `Staking` contract
  - Stake the Ether will be better than stake certain amount of USD.
- Come back to keep refactoring after researching the `protocolLab` service...

---

### 2025/1/16

**What did I do today**

- Research the `protocolLab` service.
  - Implement the `Filecoin` and `lighthouse` service to store the evidence
  - now we can simply run the Makefile command to store the evidence file on the `lighthouse`.

---

### 2025/1/17

**What did I do today**

- Implement the `VSkillUser` contract
  - We will use the `lighthouse` to store those evidences and send the `cid` as the parameter for verifiers to get the evidence.
  - Delete explicit `checkFeedbackOfEvidence` function, what we really do here is get the cids from the verifier provided.
  - The only one who can modify the `skillDomains` will be the deployer of the contract. Don't forget to update the `VSkillUserNft` contract as well. => Maybe consider to force these two operations to be done always together...
- Add a new contract `SkillHandler` to force the `VSkillUser` and `VSkillUserNft` to be updated together.
- Update the `Relayer` and `Verifier` contract.

---

### 2025/1/18

**What did I do today**

- As for the evidence status, here is what will happen after redesign:
  - If the status is `APPROVED`, the user will be able to mint the NFT. The verifiers will get the rewards.
  - If the status is `REJECTED`, the user will will not be able to mint the NFT. The verifiers will get the rewards.
  - If the status is `DIFFERENTOPINION-A`, the user will be able to mint the NFT. The verifiers will be penalized.
  - If the status is `DIFFERENTOPINION-R`, the user will not be able to mint the NFT. The verifiers will be penalized.
    - How to decide if it's `DIFFERENTOPINION`? => if more than 2/3 of the verifiers have approved the evidence, then it's `DIFFERENTOPINION-A`. The rest one will be penalized.
    - If only 1/3 of the verifiers have approved the evidence, the status will be `DIFFERENTOPINION-R`. The rest two will be penalized.
- The verifier need to provide the feedbacks in a certain time frame, otherwise the status will be `REJECTED`.
  - About 1 week after being assigned the evidence, the verifier need to provide the feedbacks.
  - If the verifier doesn't provide the feedbacks in time, their stakes will be took by as the punishment and thus immediately lose the verifier status.
- Keep building the `Relayer` contract and integrate with the `VSkillUser` and `Verifier` contract along the way.

---

### 2025/1/19

**What did I do today**

- Keep building the `Relayer` contract and integrate with the `VSkillUser` and `Verifier` contract along the way.
  - We do not need a separate `SkillHandler` contract, we can just use the `Relayer` contract to handle the `skillDomains` update.
- Follow the slither tool to check the security issues.
- Update the scripts up to date.
- Update the `Chainlink` lib to the latest version.

---

### 2025/1/20

**What did I do today**

- Update the rest scripts up to date.
- Update some outdated dependencies.
- Start to write the test cases for the contracts.
- Notice that if trying to deploy the `Distibution` contract on anvil testnet, it will revert due to the issue the `block.number` is set to 0 in anvil and it will break the rule in contract `SubscriptionAPI` as following:

```javascript

function createSubscription() external override nonReentrant returns (uint256 subId) {
    uint64 currentSubNonce = s_currentSubNonce;
    subId = uint256(
@>    keccak256(abi.encodePacked(msg.sender, blockhash(block.number - 1), address(this), currentSubNonce))
    );
    s_currentSubNonce = currentSubNonce + 1;
    address[] memory consumers = new address[](0);
    s_subscriptions[subId] = Subscription({balance: 0, nativeBalance: 0, reqCount: 0});
    s_subscriptionConfigs[subId] = SubscriptionConfig({
      owner: msg.sender,
      requestedOwner: address(0),
      consumers: consumers
    });
    s_subIds.add(subId);

    emit SubscriptionCreated(subId, msg.sender);
    return subId;
  }

```

This line of code will cause the `blockhash(block.number - 1)` to underflow and thus revert the transaction. This is not a bug in the contract, but a bug in the testnet.

Whenever test on anvil, we need to modify this line of code to `blockhash(block.number)` to make it work.

---

### 2025/1/22

**What did I do today**

- Keep the test cases for the contracts...

---

### 2025/1/23

**What did I do today**

- Keep the test cases for the contracts
- Update the `VSkillUserInteractions` script
- Update the `VerifierInteractions` script

---

### 2025/1/24

**What did I do today**

- Finish all the scripts for the contracts
- Update the `Makefile` to include all the scripts

---

### 2025/1/25

**What did I do today**

- Refactor those scripts to make them more readable and maintainable.

---

### 2025/1/27

**What did I do today**

- Start the gas optimization for the `Relayer` contract.

---

### 2025/2/1

**What did I do today**

- Keep the gas optimization for the `Relayer` contract.

---

### 2025/2/2

**What did I do today**

- Keep the gas optimization for the `Relayer` contract.

---

### 2025/2/3

**What did I do today**

- Finish the gas optimization for the `Relayer` contract.
- Update the tests to differential testing for the original version of `Relayer` contract and the optimized version of `RelayerYul` contract.

---

### 2025/2/11

**What did I do today**

- Update the codebase and get ready to update the `README.md` file for audit.

---

### 2025/2/12

**What did I do today**

- Draw the process diagram for the contracts.
- Update the `README.md` file.
- Update the `Makefile`.
- Prepare the audit files.

---

### 2025/2/13

**What did I do today**
