## VSKill Version 2 Working Log

### Checklist of Issues

**High Severity**

- [x] **[H-1]** No restrictions in `VSKillUserNft::mintUserNft` function, anyone can directly call and mint NFTs.
- [ ] **[H-2]** No restrictions in `Distribution::distributionRandomNumberForVerifiers` function, anyone can directly call it and drain the subscription Link tokens.
- [x] **[H-3]** The way verifiers are deleted in `Staking::_removeVerifier` function is incorrect, potentially ruining the process of fetching verifiers.
- [ ] **[H-4]** No restrictions in `VSkillUser::earnUserNft` function, anyone can directly call it with an approved evidence parameter to mint NFTs, ruining the verification process.
- [ ] **[H-5]** The same verifier can call `Verifier::provideFeedback` multiple times to dominate the evidence status, ruining the verification process.
- [ ] **[H-6]** The same verifier can call `Verifier::provideFeedback` multiple times and exploit `Verifier::_earnRewardsOrGetPenalized` for the `DIFFERENTOPINION` status.
- [ ] **[H-7]** If `Verifier::provideFeedback` sets the same evidence to `DIFFERENTOPINION` multiple times, `statusApproveOrNot` array may be popped when it's empty, ruining the verification process.
- [ ] **[H-8]** Verifiers lose all their stake when their reputation is less than `LOWEST_REPUTATION` and may still be penalized again.

**Medium Severity**

- [ ] **[M-1]** No bounds check in `Verifier::checkUpkeep` for the `s_evidences` array, which can cause a DoS attack as the array grows.
- [ ] **[M-2]** The two `for` loops in `Verifier::_verifiersWithinSameDomain` function can cause a DoS attack as the `s_verifiers` array grows.
- [ ] **[M-3]** The `for` loop in `Verifier::_selectedVerifiersAddressCallback` function can cause a DoS attack as the `s_verifiers` array grows.
- [ ] **[M-4]** Using memory variables to update the status of evidence in `Verifier::_assignEvidenceToSelectedVerifier` function will drain the Chainlink Automation service.

**Low Severity**

- [ ] **[L-1]** The check condition in `VSkillUser::checkFeedbackOfEvidence` is incorrect, causing a revert without the custom error message.
- [x] **[L-2]** No stability check for the price feed in `PriceConverter::getChainlinkDataFeedLatestAnswer`, which may lead to incorrect conversions.
- [ ] **[L-3]** No validation in `Verifier::updateSkillDomains` function, allowing verifiers to set arbitrary skill domains.
- [ ] **[L-4]** Users can call `VSkillUserNft::mintUserNft` with non-existent skill domains.
- [x] **[L-5]** Invalid `tokenId` results in a blank `imageUri` in `VSkillUserNft::tokenURI` function.

**Informational**

- [x] **[I-1]** Follow the Checks-Effects-Interactions (CEI) pattern in `Staking::withdrawStake` function.
- [x] **[I-2]** Solidity pragma should be specific, not wide.
- [ ] **[I-3]** Public functions not used internally could be marked `external`.
- [x] **[I-4]** Define and use constant variables instead of literals.
- [ ] **[I-5]** `PUSH0` is not supported by all chains.
- [ ] **[I-6]** Modifiers invoked only once could be integrated directly into the function.
- [x] **[I-7]** Unused custom error definitions.
- [ ] **[I-8]** Avoid costly operations inside loops.
- [x] **[I-9]** State variables could be declared `constant`.
- [x] **[I-10]** State variables could be declared `immutable`.
- [ ] **[I-11]** Use the most up-to-date version of Chainlink VRF.
- [x] **[I-12]** Centralization risk for trusted owners.
- [ ] **[I-13]** `Verifier::provideFeedback` function is too long, making maintenance difficult.
- [x] **[I-14]** The first verifier who submits feedback is rewarded more than subsequent verifiers.

**Gas Optimization**

- [x] **[G-1]** Custom error messages include constants (`Staking::minStakeUsdAmount` and `VSkillUser::submittedFeeInUsd`), which cost more gas.
- [x] **[G-2]** Two functions in the `Staking` contract perform the same task, wasting gas.
- [x] **[G-3]** Double checks in `Verifier::_earnRewardsOrGetPenalized` function result in unnecessary gas consumption.
- [ ] **[G-4]** Repeated computation of `Verifier::keccak256(abi.encodePacked(evidenceIpfsHash))` wastes gas.

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
