### 2024/7/14

1. **What users can do:**

   - Users can submit evidence of their skills. (This will cost some money for each submission -> Ether)
   - Users can view the status of their submissions.
   - Users can receive feedback on their evidence.
   - Users can earn NFTs as proof of their skills.

2. **What verifiers can do:**

   - Verifiers can assess evidence submitted by users.
   - Verifiers can provide feedback on the evidence.
   - Verifiers can earn rewards for providing accurate feedback.
   - Verifiers can be penalized for acting maliciously or providing inaccurate feedback.
   - Verifiers can stake ethers to participate in the verification process.
   - Verifiers can view their reputation score and history.
   - Verifiers can increase reputation to increase their chances of being selected as a verifier.
   - Verifiers can earn NFTs based on their reputation and contributions to the system.

3. **What the system does:**

   - The system distributes evidence to verifiers anonymously using a decentralized oracle system.
   - The system rewards verifiers who provide accurate and honest feedback.
   - The system penalizes verifiers who act maliciously or provide inaccurate feedback.
   - The system requires verifiers to stake ethers to participate in the verification process.
   - The system issues ethers and reputation to incentivize participation.
   - The system issues NFTs to verified users as proof of their skills.
   - The system integrates NFTs with other platforms and services where verified skills are valuable.

4. **Modules to be developed:**

   - User module: Allows users to submit evidence, view status, and receive feedback.
   - Verifier module: Allows verifiers to assess evidence, increase or decrease reputation, provide feedback, and earn rewards.
   - Oracle module: Distributes evidence to verifiers anonymously.
   - Reward module: Issues rewards to verifiers based on their contributions.
   - Penalty module: Penalizes verifiers for acting maliciously or providing inaccurate feedback.
   - Staking module: Requires verifiers to stake ethers to participate in the verification process.
   - NFT module: Issues NFTs to verified users as proof of their skills.
   - Integration module: Integrates NFTs with other platforms and services.

### Plan for today: Staking module

1.  Implement the `stake()`, `withdrawStake()` and `stakeToBeTheVerifier()` functions.
2.  Add the deployments and tests for the staking module.
3.  Update the README and documentation.

---

### 2024/7/15

**What I did today:**

- Update and fix issues in the `stake()`, `withdrawStake()` and `stakeToBeTheVerifier()` functions.
- Add the Interactions script for the staking module.
- Add the integration tests for the staking module.
- Add more unit tests for the staking module.
- Add Makefike for the staking module.

---

### 2024/7/16

**What I did today:**

- Add more tests for the staking module -> test the events emitted.
- Refactor the tests and staking contract.
- Work on the User module:

  - How evidence composed of? -> IPFS hash and the domain of the skill. Such that the evidence can be distributed to the right verifiers. -> chainlink VRF.
  - What status can the evidence have? -> `Submitted`, `In Review`, `Accepted`, `Rejected`. -> Use chainlink automation to update the status.
  - How to store the evidence? -> IPFS hash, domain, status, and user address. -> Use a struct to store the evidence.
  - How to view the evidence? -> By user address. -> Use mappings to store the evidence.
  - Once the evidence is accepted, the corresponding NFT will be minted and sent to the user. -> Use OpenZeppelin ERC721 for NFTs. And chainlink automation to mint and send the NFT.
  - How the submission fee is calculated? -> Just a fixed fee for each submission. -> Use a constant variable for the fee. -> Who can change the fee? -> Only the owner of the contract. -> Use OpenZeppelin Ownable.

  ***

### 2024/7/17

**What I did today:**

- Implement the User module:

  - Add the `submitEvidence()`, `changeSubmissionFee()`, `addMoreDomain()` and other helper, getter or unrealized functions.
  - Add the deployments and tests for the User module.
  - Update the `Makefile` and documentation.
  - Add the Interactions script for the User module.
  - Add the integration tests for the User module.

---

### 2024/7/18

**Thoughts:**

- More thoughts about the verifier:
  - What reputation is? -> A score that reflects the verifier's accuracy and honesty. -> Use a mapping to store the reputation.
  - What reputation can do? -> Increase the chances of being selected as a verifier. -> Higher reputation means higher chances to be selected with chainlink VRF. Like if your reputation is 1, in the distribution of evidence, you will have 1 ticket. If your reputation is 2, you will have 2 tickets.
  - How to increase reputation? -> Each time the evidence will be distributed to 3 verifiers. Each of them will have to set the status of the evidence to `rejected` or `accepted`. If all three of them gives out the same status, all of them will increase their reputation by 1. If not, the evidence will be distributed to another 3 verifiers until the status is the same. All those verifiers in the past verification process who gave out a different status will decrease their reputation by 1.
  - How verifiers can earn rewards? -> Those verifiers who act maliciously or provide inaccurate feedback will be penalized. Together with those users who submit evidence will have to pay the submission fee. The rewards will come from both the penalized ethers and the submission fees. -> Those verifiers who provide accurate feedback will earn rewards. Higher reputation means higher rewards. But there should have a limit to the maximum rewards -> Mechanism to prevent the system from bankruptcy.
  - Should we issue NFT to verifiers if they reach a high reputation? -> Yes, but the NFTs will be different from the NFTs issued to users. -> The NFTs will be used to prove the reputation of the verifiers. -> The NFTs will be minted and sent to the verifiers by the system.
- Which modules will be coneected with the verifier module?
  - `Oracle`, `Reward & Penalty`, `Staking`, `NFT`, `User`.
- Integration is key to the success of the system.
- After the Staking and User module. Which module should be the next priority and why? -> The `Oracle` module. Because the evidence should be distributed to the verifiers anonymously. -> The `Oracle` module will be responsible for this task.
- What `Oracle` module should provide? Like three random numbers and serve as an interface for verifiers to get those numbers. Thus, the evidence will be distributed to the verifiers like: `verifierSelected1 = randomNumber1 % numberOfVerifiersWithReputation` and here should be a mechanism to prevent the same verifier to be selected multiple times.

**What I did today:**

- For `Oracle` module, now just implement the chainlink VRF to get three random numbers. -> `chainlink VRFV2`.
- Add the distribution contract (oracle)
- Add the deployments and tests for the Oracle module.
- Update the `Makefile` and documentation.
- Do a lot refactoring and implement chainlink VRFV2. Now it can generate three random numbers.
- Add the Interactions script for the Oracle module.
- Refactor the deloyments make it easy to create subscription and fund subscription, add consumer in one command.

---
