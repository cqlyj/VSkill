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
   - Verifier module: Allows verifiers to assess evidence, provide feedback, and earn rewards.
   - Oracle module: Distributes evidence to verifiers anonymously.
   - Reward module: Issues rewards to verifiers based on their contributions.
   - Penalty module: Penalizes verifiers for acting maliciously or providing inaccurate feedback.
   - Reputation module: Tracks verifiers' reputation and history.
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
