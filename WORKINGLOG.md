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

### 2024/7/19

**ISSUE**

- `make test-mainnet` will revert on the `Oracle` module. -> The `Oracle` module is not working properly. The `FundSubscription` function is not working properly.
- Come back to the `Oracle` module and fix the issue.🟩

**What I did today:**

- Add [Issue](https://github.com/foundry-rs/foundry/issues/8475) to the `forge` repository.

---

### 2024/7/20

**REST DAY🍻**

---

### 2024/7/21 - 2024/7/31

**FINAL WEEK EXAM REST DAY🍻**

---

### 2024/8/1

**What I did today:**

- Create the svg for the NFTs of users. -> With the help of chatGPT.

  - `Frontend Developer`

  ![SVG](./image/frontend.svg)

  - `Backend Developer`

  ![SVG](./image/backend.svg)

  - `Fullstack Developer`

  ![SVG](./image/fullstack.svg)

  - `DevOps Engineer`

  ![SVG](./image/devops.svg)

  - `Blockchain Developer`

  ![SVG](./image/blockchain.svg)

- Start to work on the NFT module of users.
- Use base64 to hash the svg and store it in the contract.

  - `Frontend Developer`

  `data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMjUwIiBoZWlnaHQ9IjI1MCIgdmlld0JveD0iMCAwIDI1MCAyNTAiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+CiAgPCEtLSBCYWNrZ3JvdW5kIHdpdGggb3JpZ2luYWwgZ3JhZGllbnQgLS0+CiAgPGRlZnM+CiAgICA8bGluZWFyR3JhZGllbnQgaWQ9ImdyYWQxIiB4MT0iMCUiIHkxPSIwJSIgeDI9IjEwMCUiIHkyPSIxMDAlIj4KICAgICAgPHN0b3Agb2Zmc2V0PSIwJSIgc3R5bGU9InN0b3AtY29sb3I6I2JkYzNjNztzdG9wLW9wYWNpdHk6MSIgLz4KICAgICAgPHN0b3Agb2Zmc2V0PSIxMDAlIiBzdHlsZT0ic3RvcC1jb2xvcjojMmMzZTUwO3N0b3Atb3BhY2l0eToxIiAvPgogICAgPC9saW5lYXJHcmFkaWVudD4KICA8L2RlZnM+CiAgPHJlY3QgeD0iMCIgeT0iMCIgd2lkdGg9IjI1MCIgaGVpZ2h0PSIyNTAiIHJ4PSIxNSIgcnk9IjE1IiBmaWxsPSJ1cmwoI2dyYWQxKSIgLz4KCiAgPCEtLSBCb3JkZXIgLS0+CiAgPHJlY3QgeD0iMTAiIHk9IjEwIiB3aWR0aD0iMjMwIiBoZWlnaHQ9IjIzMCIgcng9IjE1IiByeT0iMTUiIGZpbGw9Im5vbmUiIHN0cm9rZT0iI2VjZjBmMSIgc3Ryb2tlLXdpZHRoPSIyIiAvPgoKICA8IS0tIEFwcCBOYW1lIGFzIGJhY2tncm91bmQgc2hhcGUgLS0+CiAgPHRleHQgeD0iNTAlIiB5PSIzNSUiIGZpbGw9IiNmZmZmZmYiIGZvbnQtZmFtaWx5PSInU0YgUHJvIERpc3BsYXknLCAtYXBwbGUtc3lzdGVtLCBCbGlua01hY1N5c3RlbUZvbnQsIHNhbnMtc2VyaWYiIGZvbnQtc2l6ZT0iNzAiIGZvbnQtd2VpZ2h0PSJib2xkIiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBvcGFjaXR5PSIwLjI1Ij5WU2tpbGw8L3RleHQ+CgogIDwhLS0gVGl0bGUgd2l0aCBtb3JlIGF0dGVudGlvbiAtLT4KICA8dGV4dCB4PSI1MCUiIHk9IjU1JSIgZmlsbD0iI2ZmZmZmZiIgZm9udC1mYW1pbHk9IidTRiBQcm8gRGlzcGxheScsIC1hcHBsZS1zeXN0ZW0sIEJsaW5rTWFjU3lzdGVtRm9udCwgc2Fucy1zZXJpZiIgZm9udC1zaXplPSIzMiIgZm9udC13ZWlnaHQ9IjYwMCIgdGV4dC1hbmNob3I9Im1pZGRsZSIgZHk9Ii4zZW0iPkZyb250ZW5kPC90ZXh0PgogIDx0ZXh0IHg9IjUwJSIgeT0iNzAlIiBmaWxsPSIjZmZmZmZmIiBmb250LWZhbWlseT0iJ1NGIFBybyBEaXNwbGF5JywgLWFwcGxlLXN5c3RlbSwgQmxpbmtNYWNTeXN0ZW1Gb250LCBzYW5zLXNlcmlmIiBmb250LXNpemU9IjMyIiBmb250LXdlaWdodD0iNjAwIiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBkeT0iLjNlbSI+RGV2ZWxvcGVyPC90ZXh0PgoKICA8IS0tIFN1YnRsZSBzaGFkb3cgZm9yIGRlcHRoIC0tPgogIDxyZWN0IHg9IjEwIiB5PSIxMCIgd2lkdGg9IjIzMCIgaGVpZ2h0PSIyMzAiIHJ4PSIxNSIgcnk9IjE1IiBmaWxsPSJub25lIiBzdHJva2U9IiMwMDAiIHN0cm9rZS13aWR0aD0iNSIgb3BhY2l0eT0iMC4xIiAvPgo8L3N2Zz4=`

  - `Backend Developer`

  `data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMjUwIiBoZWlnaHQ9IjI1MCIgdmlld0JveD0iMCAwIDI1MCAyNTAiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+CiAgPCEtLSBCYWNrZ3JvdW5kIHdpdGggb3JpZ2luYWwgZ3JhZGllbnQgLS0+CiAgPGRlZnM+CiAgICA8bGluZWFyR3JhZGllbnQgaWQ9ImdyYWQxIiB4MT0iMCUiIHkxPSIwJSIgeDI9IjEwMCUiIHkyPSIxMDAlIj4KICAgICAgPHN0b3Agb2Zmc2V0PSIwJSIgc3R5bGU9InN0b3AtY29sb3I6I2JkYzNjNztzdG9wLW9wYWNpdHk6MSIgLz4KICAgICAgPHN0b3Agb2Zmc2V0PSIxMDAlIiBzdHlsZT0ic3RvcC1jb2xvcjojMmMzZTUwO3N0b3Atb3BhY2l0eToxIiAvPgogICAgPC9saW5lYXJHcmFkaWVudD4KICA8L2RlZnM+CiAgPHJlY3QgeD0iMCIgeT0iMCIgd2lkdGg9IjI1MCIgaGVpZ2h0PSIyNTAiIHJ4PSIxNSIgcnk9IjE1IiBmaWxsPSJ1cmwoI2dyYWQxKSIgLz4KCiAgPCEtLSBCb3JkZXIgLS0+CiAgPHJlY3QgeD0iMTAiIHk9IjEwIiB3aWR0aD0iMjMwIiBoZWlnaHQ9IjIzMCIgcng9IjE1IiByeT0iMTUiIGZpbGw9Im5vbmUiIHN0cm9rZT0iI2VjZjBmMSIgc3Ryb2tlLXdpZHRoPSIyIiAvPgoKICA8IS0tIEFwcCBOYW1lIGFzIGJhY2tncm91bmQgc2hhcGUgLS0+CiAgPHRleHQgeD0iNTAlIiB5PSIzNSUiIGZpbGw9IiNmZmZmZmYiIGZvbnQtZmFtaWx5PSInU0YgUHJvIERpc3BsYXknLCAtYXBwbGUtc3lzdGVtLCBCbGlua01hY1N5c3RlbUZvbnQsIHNhbnMtc2VyaWYiIGZvbnQtc2l6ZT0iNzAiIGZvbnQtd2VpZ2h0PSJib2xkIiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBvcGFjaXR5PSIwLjI1Ij5WU2tpbGw8L3RleHQ+CgogIDwhLS0gVGl0bGUgd2l0aCBtb3JlIGF0dGVudGlvbiAtLT4KICA8dGV4dCB4PSI1MCUiIHk9IjU1JSIgZmlsbD0iI2ZmZmZmZiIgZm9udC1mYW1pbHk9IidTRiBQcm8gRGlzcGxheScsIC1hcHBsZS1zeXN0ZW0sIEJsaW5rTWFjU3lzdGVtRm9udCwgc2Fucy1zZXJpZiIgZm9udC1zaXplPSIzMiIgZm9udC13ZWlnaHQ9IjYwMCIgdGV4dC1hbmNob3I9Im1pZGRsZSIgZHk9Ii4zZW0iPkJhY2tlbmQ8L3RleHQ+CiAgPHRleHQgeD0iNTAlIiB5PSI3MCUiIGZpbGw9IiNmZmZmZmYiIGZvbnQtZmFtaWx5PSInU0YgUHJvIERpc3BsYXknLCAtYXBwbGUtc3lzdGVtLCBCbGlua01hY1N5c3RlbUZvbnQsIHNhbnMtc2VyaWYiIGZvbnQtc2l6ZT0iMzIiIGZvbnQtd2VpZ2h0PSI2MDAiIHRleHQtYW5jaG9yPSJtaWRkbGUiIGR5PSIuM2VtIj5EZXZlbG9wZXI8L3RleHQ+CgogIDwhLS0gU3VidGxlIHNoYWRvdyBmb3IgZGVwdGggLS0+CiAgPHJlY3QgeD0iMTAiIHk9IjEwIiB3aWR0aD0iMjMwIiBoZWlnaHQ9IjIzMCIgcng9IjE1IiByeT0iMTUiIGZpbGw9Im5vbmUiIHN0cm9rZT0iIzAwMCIgc3Ryb2tlLXdpZHRoPSI1IiBvcGFjaXR5PSIwLjEiIC8+Cjwvc3ZnPg==`

  - `Fullstack Developer`

  `data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMjUwIiBoZWlnaHQ9IjI1MCIgdmlld0JveD0iMCAwIDI1MCAyNTAiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+CiAgPCEtLSBCYWNrZ3JvdW5kIHdpdGggb3JpZ2luYWwgZ3JhZGllbnQgLS0+CiAgPGRlZnM+CiAgICA8bGluZWFyR3JhZGllbnQgaWQ9ImdyYWQxIiB4MT0iMCUiIHkxPSIwJSIgeDI9IjEwMCUiIHkyPSIxMDAlIj4KICAgICAgPHN0b3Agb2Zmc2V0PSIwJSIgc3R5bGU9InN0b3AtY29sb3I6I2JkYzNjNztzdG9wLW9wYWNpdHk6MSIgLz4KICAgICAgPHN0b3Agb2Zmc2V0PSIxMDAlIiBzdHlsZT0ic3RvcC1jb2xvcjojMmMzZTUwO3N0b3Atb3BhY2l0eToxIiAvPgogICAgPC9saW5lYXJHcmFkaWVudD4KICA8L2RlZnM+CiAgPHJlY3QgeD0iMCIgeT0iMCIgd2lkdGg9IjI1MCIgaGVpZ2h0PSIyNTAiIHJ4PSIxNSIgcnk9IjE1IiBmaWxsPSJ1cmwoI2dyYWQxKSIgLz4KCiAgPCEtLSBCb3JkZXIgLS0+CiAgPHJlY3QgeD0iMTAiIHk9IjEwIiB3aWR0aD0iMjMwIiBoZWlnaHQ9IjIzMCIgcng9IjE1IiByeT0iMTUiIGZpbGw9Im5vbmUiIHN0cm9rZT0iI2VjZjBmMSIgc3Ryb2tlLXdpZHRoPSIyIiAvPgoKICA8IS0tIEFwcCBOYW1lIGFzIGJhY2tncm91bmQgc2hhcGUgLS0+CiAgPHRleHQgeD0iNTAlIiB5PSIzNSUiIGZpbGw9IiNmZmZmZmYiIGZvbnQtZmFtaWx5PSInU0YgUHJvIERpc3BsYXknLCAtYXBwbGUtc3lzdGVtLCBCbGlua01hY1N5c3RlbUZvbnQsIHNhbnMtc2VyaWYiIGZvbnQtc2l6ZT0iNzAiIGZvbnQtd2VpZ2h0PSJib2xkIiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBvcGFjaXR5PSIwLjI1Ij5WU2tpbGw8L3RleHQ+CgogIDwhLS0gVGl0bGUgd2l0aCBtb3JlIGF0dGVudGlvbiAtLT4KICA8dGV4dCB4PSI1MCUiIHk9IjU1JSIgZmlsbD0iI2ZmZmZmZiIgZm9udC1mYW1pbHk9IidTRiBQcm8gRGlzcGxheScsIC1hcHBsZS1zeXN0ZW0sIEJsaW5rTWFjU3lzdGVtRm9udCwgc2Fucy1zZXJpZiIgZm9udC1zaXplPSIzMiIgZm9udC13ZWlnaHQ9IjYwMCIgdGV4dC1hbmNob3I9Im1pZGRsZSIgZHk9Ii4zZW0iPkZ1bGxzdGFjazwvdGV4dD4KICA8dGV4dCB4PSI1MCUiIHk9IjcwJSIgZmlsbD0iI2ZmZmZmZiIgZm9udC1mYW1pbHk9IidTRiBQcm8gRGlzcGxheScsIC1hcHBsZS1zeXN0ZW0sIEJsaW5rTWFjU3lzdGVtRm9udCwgc2Fucy1zZXJpZiIgZm9udC1zaXplPSIzMiIgZm9udC13ZWlnaHQ9IjYwMCIgdGV4dC1hbmNob3I9Im1pZGRsZSIgZHk9Ii4zZW0iPkRldmVsb3BlcjwvdGV4dD4KCiAgPCEtLSBTdWJ0bGUgc2hhZG93IGZvciBkZXB0aCAtLT4KICA8cmVjdCB4PSIxMCIgeT0iMTAiIHdpZHRoPSIyMzAiIGhlaWdodD0iMjMwIiByeD0iMTUiIHJ5PSIxNSIgZmlsbD0ibm9uZSIgc3Ryb2tlPSIjMDAwIiBzdHJva2Utd2lkdGg9IjUiIG9wYWNpdHk9IjAuMSIgLz4KPC9zdmc+`

  - `DevOps Engineer`

  `data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMjUwIiBoZWlnaHQ9IjI1MCIgdmlld0JveD0iMCAwIDI1MCAyNTAiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+CiAgPCEtLSBCYWNrZ3JvdW5kIHdpdGggb3JpZ2luYWwgZ3JhZGllbnQgLS0+CiAgPGRlZnM+CiAgICA8bGluZWFyR3JhZGllbnQgaWQ9ImdyYWQxIiB4MT0iMCUiIHkxPSIwJSIgeDI9IjEwMCUiIHkyPSIxMDAlIj4KICAgICAgPHN0b3Agb2Zmc2V0PSIwJSIgc3R5bGU9InN0b3AtY29sb3I6I2JkYzNjNztzdG9wLW9wYWNpdHk6MSIgLz4KICAgICAgPHN0b3Agb2Zmc2V0PSIxMDAlIiBzdHlsZT0ic3RvcC1jb2xvcjojMmMzZTUwO3N0b3Atb3BhY2l0eToxIiAvPgogICAgPC9saW5lYXJHcmFkaWVudD4KICA8L2RlZnM+CiAgPHJlY3QgeD0iMCIgeT0iMCIgd2lkdGg9IjI1MCIgaGVpZ2h0PSIyNTAiIHJ4PSIxNSIgcnk9IjE1IiBmaWxsPSJ1cmwoI2dyYWQxKSIgLz4KCiAgPCEtLSBCb3JkZXIgLS0+CiAgPHJlY3QgeD0iMTAiIHk9IjEwIiB3aWR0aD0iMjMwIiBoZWlnaHQ9IjIzMCIgcng9IjE1IiByeT0iMTUiIGZpbGw9Im5vbmUiIHN0cm9rZT0iI2VjZjBmMSIgc3Ryb2tlLXdpZHRoPSIyIiAvPgoKICA8IS0tIEFwcCBOYW1lIGFzIGJhY2tncm91bmQgc2hhcGUgLS0+CiAgPHRleHQgeD0iNTAlIiB5PSIzNSUiIGZpbGw9IiNmZmZmZmYiIGZvbnQtZmFtaWx5PSInU0YgUHJvIERpc3BsYXknLCAtYXBwbGUtc3lzdGVtLCBCbGlua01hY1N5c3RlbUZvbnQsIHNhbnMtc2VyaWYiIGZvbnQtc2l6ZT0iNzAiIGZvbnQtd2VpZ2h0PSJib2xkIiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBvcGFjaXR5PSIwLjI1Ij5WU2tpbGw8L3RleHQ+CgogIDwhLS0gVGl0bGUgd2l0aCBtb3JlIGF0dGVudGlvbiAtLT4KICA8dGV4dCB4PSI1MCUiIHk9IjU1JSIgZmlsbD0iI2ZmZmZmZiIgZm9udC1mYW1pbHk9IidTRiBQcm8gRGlzcGxheScsIC1hcHBsZS1zeXN0ZW0sIEJsaW5rTWFjU3lzdGVtRm9udCwgc2Fucy1zZXJpZiIgZm9udC1zaXplPSIzMiIgZm9udC13ZWlnaHQ9IjYwMCIgdGV4dC1hbmNob3I9Im1pZGRsZSIgZHk9Ii4zZW0iPkRldk9wczwvdGV4dD4KICA8dGV4dCB4PSI1MCUiIHk9IjcwJSIgZmlsbD0iI2ZmZmZmZiIgZm9udC1mYW1pbHk9IidTRiBQcm8gRGlzcGxheScsIC1hcHBsZS1zeXN0ZW0sIEJsaW5rTWFjU3lzdGVtRm9udCwgc2Fucy1zZXJpZiIgZm9udC1zaXplPSIzMiIgZm9udC13ZWlnaHQ9IjYwMCIgdGV4dC1hbmNob3I9Im1pZGRsZSIgZHk9Ii4zZW0iPkVuZ2luZWVyPC90ZXh0PgoKICA8IS0tIFN1YnRsZSBzaGFkb3cgZm9yIGRlcHRoIC0tPgogIDxyZWN0IHg9IjEwIiB5PSIxMCIgd2lkdGg9IjIzMCIgaGVpZ2h0PSIyMzAiIHJ4PSIxNSIgcnk9IjE1IiBmaWxsPSJub25lIiBzdHJva2U9IiMwMDAiIHN0cm9rZS13aWR0aD0iNSIgb3BhY2l0eT0iMC4xIiAvPgo8L3N2Zz4=`

  - `Blockchain Developer`

  `data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMjUwIiBoZWlnaHQ9IjI1MCIgdmlld0JveD0iMCAwIDI1MCAyNTAiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+CiAgPCEtLSBCYWNrZ3JvdW5kIHdpdGggb3JpZ2luYWwgZ3JhZGllbnQgLS0+CiAgPGRlZnM+CiAgICA8bGluZWFyR3JhZGllbnQgaWQ9ImdyYWQxIiB4MT0iMCUiIHkxPSIwJSIgeDI9IjEwMCUiIHkyPSIxMDAlIj4KICAgICAgPHN0b3Agb2Zmc2V0PSIwJSIgc3R5bGU9InN0b3AtY29sb3I6I2JkYzNjNztzdG9wLW9wYWNpdHk6MSIgLz4KICAgICAgPHN0b3Agb2Zmc2V0PSIxMDAlIiBzdHlsZT0ic3RvcC1jb2xvcjojMmMzZTUwO3N0b3Atb3BhY2l0eToxIiAvPgogICAgPC9saW5lYXJHcmFkaWVudD4KICA8L2RlZnM+CiAgPHJlY3QgeD0iMCIgeT0iMCIgd2lkdGg9IjI1MCIgaGVpZ2h0PSIyNTAiIHJ4PSIxNSIgcnk9IjE1IiBmaWxsPSJ1cmwoI2dyYWQxKSIgLz4KCiAgPCEtLSBCb3JkZXIgLS0+CiAgPHJlY3QgeD0iMTAiIHk9IjEwIiB3aWR0aD0iMjMwIiBoZWlnaHQ9IjIzMCIgcng9IjE1IiByeT0iMTUiIGZpbGw9Im5vbmUiIHN0cm9rZT0iI2VjZjBmMSIgc3Ryb2tlLXdpZHRoPSIyIiAvPgoKICA8IS0tIEFwcCBOYW1lIGFzIGJhY2tncm91bmQgc2hhcGUgLS0+CiAgPHRleHQgeD0iNTAlIiB5PSIzNSUiIGZpbGw9IiNmZmZmZmYiIGZvbnQtZmFtaWx5PSInU0YgUHJvIERpc3BsYXknLCAtYXBwbGUtc3lzdGVtLCBCbGlua01hY1N5c3RlbUZvbnQsIHNhbnMtc2VyaWYiIGZvbnQtc2l6ZT0iNzAiIGZvbnQtd2VpZ2h0PSJib2xkIiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBvcGFjaXR5PSIwLjI1Ij5WU2tpbGw8L3RleHQ+CgogIDwhLS0gVGl0bGUgd2l0aCBtb3JlIGF0dGVudGlvbiAtLT4KICA8dGV4dCB4PSI1MCUiIHk9IjU1JSIgZmlsbD0iI2ZmZmZmZiIgZm9udC1mYW1pbHk9IidTRiBQcm8gRGlzcGxheScsIC1hcHBsZS1zeXN0ZW0sIEJsaW5rTWFjU3lzdGVtRm9udCwgc2Fucy1zZXJpZiIgZm9udC1zaXplPSIzMiIgZm9udC13ZWlnaHQ9IjYwMCIgdGV4dC1hbmNob3I9Im1pZGRsZSIgZHk9Ii4zZW0iPkJsb2NrY2hhaW48L3RleHQ+CiAgPHRleHQgeD0iNTAlIiB5PSI3MCUiIGZpbGw9IiNmZmZmZmYiIGZvbnQtZmFtaWx5PSInU0YgUHJvIERpc3BsYXknLCAtYXBwbGUtc3lzdGVtLCBCbGlua01hY1N5c3RlbUZvbnQsIHNhbnMtc2VyaWYiIGZvbnQtc2l6ZT0iMzIiIGZvbnQtd2VpZ2h0PSI2MDAiIHRleHQtYW5jaG9yPSJtaWRkbGUiIGR5PSIuM2VtIj5EZXZlbG9wZXI8L3RleHQ+CgogIDwhLS0gU3VidGxlIHNoYWRvdyBmb3IgZGVwdGggLS0+CiAgPHJlY3QgeD0iMTAiIHk9IjEwIiB3aWR0aD0iMjMwIiBoZWlnaHQ9IjIzMCIgcng9IjE1IiByeT0iMTUiIGZpbGw9Im5vbmUiIHN0cm9rZT0iIzAwMCIgc3Ryb2tlLXdpZHRoPSI1IiBvcGFjaXR5PSIwLjEiIC8+Cjwvc3ZnPg==`

- What about the NFT of verifiers?🤔 -> After deciding the reputation to the NFT mapping, back to implement this.
- Add the NFT module for users and verifiers.
- Implement the NFT module for users.
- Add deployment and test for the NFT module of users.
- Update the `Makefile` and documentation.

**Thoughts:**

- Implement the verifier module first and then implement the NFT module for verifiers.
- Verifier module -> `distribution`, `reputation`, `rewards`, `penalties`, and `NFT`.
- **`Distribution`**: The evidence of users will be distributed to three verifiers in the same skill domain randomly.
- **`Reputation`**: The reputation of verifiers will be based on the performance of the verifiers.

  Range from `0` to `10`. That is to say, if the reputation score is less than or equal to `1`, the verifier will be penalized to be deducted the stake.

  `Initial reputation` is `2`, and the reputation will be updated based on the performance of the verifiers. If each time the three verifiers give the same result, the reputation of the verifiers will be increased by `1`. If the result is different, the evidence will be distributed to another three verifiers and those who give the wrong result will be penalized to deducted the reputation score by `1`.

  Higher reputation will have higher chance to be selected as the verifier. Since the highest score is `10`, each one score will have be considered as half a verifiers. For example, the initial score `2` means `1` verifier, and the score `10` means `5` verifiers which indicates that the verifier who has the highest reputation will have 5 more chances to be selected as the verifier.

  Once the verifier reach the score `10`, subsequent successful verification won't increase the reputation score to eliminate the probability of domination of the verifier.

  The NFT will be minted automatically once the verifier reach the score `10`. And it will be burned if the reputation score is less than `8` automatically.

- **`Rewards`**: The rewards will be distributed to the verifiers each successful verification.

  The amount of rewards will be calculated in the formula:

  `Rewards = (TotalBalanceOfSubmissionFee + TotalBalanceOfPenaltyFee) * AmountOfStakesOfVerifier / TotalAmountOfStakesOfVerifiers / 3 * 50%`.

  That is to say, the rewards will be distributed to the verifiers based on the amount of stakes of the verifiers. And this formula ensures the balance of rewards never exceed the total balance of submission fee and penalty fee.(The maximum rewards will be `50%` of the total balance of submission fee and penalty fee to prevent the undercollateralization of the system.)

  The rewards will increase if the `TotalBalanceOfPenaltyFee` increase. If no one is penalized, the rewards amount to be almost the same as half of the submission fee.

- **`Penalties`**: The penalties will be deducted from the verifiers each unsuccessful verification. The amount will be 10 USD (half amount of being verifier) and the reputation score will be deducted by `1`.

- **`NFT`**: The NFT will be minted automatically once the verifier reach the score `10`. And it will be burned if the reputation score is less than `8` automatically.

---

### 2024/8/2

**What I did today:**

- Work on the verifier module. -> Begin to integrate this module with previous modules. And refactor those previous modules to adapt to the verifier module.

---

### 2024/8/3 - 2024/8/12

**What I did those days:**

- Refactor the previous modules to adapt to the verifier module.

---

### 2024/8/13

**What I did today:**

- Work on the verifier NFT module. => This NFT should be a random color NFT. Each time the verifier reach the score `10`, the NFT will be minted automatically. And it will be burned if the reputation score is less than `8` automatically. => But what's the meaning of verifier NFT? I think for now it's not necessary to implement this. => So I will skip this and move on to the next task.

---

### 2024/8/14 - 2024/9/16

**Holiday**

---

### 2024/9/17 - 2024/9/19

**What I did:**

- Work on the verifier module. => Keep integrating this module with previous modules. And refactor those previous modules to adapt to the verifier module.
- Refactor and fix the bugs of the previous modules. => Finish the first time of integration and refactor.

---

### 2024/9/20

**What I did today:**

- Work on the verifier module. => After the verifier be removed from the list, what about the money they staked? => It will be recorded in the `bonusMoney` variant in the `Staking` contract and will be distributed to the verifiers who provide correct feedback.
- Add the `bonusMoney` variant in the `Staking` contract.
- Add the corresponding functions to handle the `bonusMoney` in the `Staking` contract.
- Add the penalize and reward functions in the `Staking` and `Verifier` contracts.

- What about the money in the VSkillUser module? => This contract share the same address with the `Staking` contract. => So the money will be recorded in the `bonusMoney` variant in the `Staking` contract and will be distributed to the verifiers who provide correct feedback.

- A known **BUG** here in `Staking` module!!!

```
Let's say for now: 1 ETH = 2000 USD.
And in the future: 1 ETH = 1000 USD.

Now I have stake 1 ETH in the contract, it will record that I have 2000 USD available to withdraw.

But in the future when 1 ETH = 1000 USD, the contract will still record that I have 2000 USD available to withdraw.

When I try to withdraw the 2000 USD, the contract will transfer 2 ETH to me. However the contract only have 1 ETH. => This is a known bug in the contract.
```

---

### 2024/9/21

**What I did today:**

- Fix the known bug yesterday. => The contract will record the amount of ETH only and the amount of USD will be calculated based on the current price of ETH.
- Add more tests for the `Staking` contract.
- start to work on the chainlink `automation` once someone submit the evidence.

---

### 2024/9/22

**REST DAY🍻**

---

### 2024/9/23

**What I did today:**

- Fix issues in the evidence status, add the new status `DifferentOpinions` and fix issues in verifier contract for the reward and penalty.

  - Those evidence which have the status of `Submitted` will be distributed to the verifiers and once this process is done, the status will be updated to `InReview`.
  - If the verifiers have different opinions, the evidence will be distributed to another three verifiers and the status will be updated to `DifferentOpinions`.
  - The distribution of the evidence will be done automatically with the help of the `chainlink automation`.

- refactor the `Verifier` contract...

**Thoughts:**

- The final product will be two contract only: `Verifier` and `VSkillUser`.
- Don't forget to integrate the functions like `withdraw` and `stake` ... in those contracts.
- Those verifiers who make right decision but have different opinions should not be penalized. => This is a known bug in the contract.

---

### 2024/9/24

**What I did today:**

- fix the known bug in the contract. => Those verifiers who make right decision but have different opinions should not be penalized.
- find a bug in `Distribution` test. => the length of `getRandomNumber` is 0 for now.
- keep refactoring the `Verifier` contract...

---

### 2024/9/25

**What I did today:**

- write the scripts for `verifier` contract.
- add new function convert USD to ETH in the `util` module. => The `PriceConverter.sol`
- write some test for the `verifier` contract.

**Issue:** ✅

- for now the `forge compile` works well with the help of `--via-ir`, but `forge coverage` doesn't work with this flag. => https://github.com/foundry-rs/foundry/issues/3357

**Thoughts:**

- maybe not directly inherit the `VSkillUser` contract, instead, add the `VSkillUser` contract address as a parameter of the constructor in the `Verifier` contract. And make the `VSkillUser` contract as a library.

---

### 2024/9/26

**What I did today:**

- refactor the `Verifier` contract and its deployment, helper, and test scripts. Then solve the issue of `Stack too deep`.
  - By creating a new library `StructDefinition.sol` and declare the struct in this library. Then import this library in the `Verifier` contract.

---

### 2024/9/27

**What I did today:**

- refactor the `Verifier` and `Distribution` contract to make them work properly. => Add callback function in the `Verifier` contract to be called by the `fulfillRandomWords` function and thus assign the evidence to the verifiers.
- refactor the `VSkillUser` contract about its structs and enums.
- Add `VerifierInterface` in a new interface folder and will be used in the `Distribution` contract for the callback function.
- Refactor their corresponding deployment and test scripts.
- write a huge test for the `Verifier` contract just to ensure that the VRF works properly and the evidence can be distributed to the verifiers.

---

### 2024/9/28 - 2024/10/1

**REST DAY🍻**

---

### 2024/10/2

**What I did today:**

- refactor the `VSkillUserNft` contract and add two events, refactor its test scripts.
- refactor the `Staking` contract and its test scripts.

---

### 2024/10/4

**What I did today:**

- refactor the `Staking` contract and use `StructDefinition` library to store the `verifier` struct.
- refactor the `VSkillUser` contract and its test scripts.

---

### 2024/10/9

**What I did today:**

- write tests for the `Verifier` contract.
- There exists issue in the `provideFeedback` function... => To be solved now or maybe leave it to audit later.✅

  - ```javascript
    // addressToEvidence[user].length == 0... ??
    addressToEvidences[user][currentEvidenceIndex].feedbackIpfsHash.push(
      feedbackIpfsHash
    );
    ```

  why this `addressToEvidences` not updated in my test case? ✅ => Because the user address set to the test contract address.

  - ```javascript
    if (
             _updateEvidenceStatus(evidenceIpfsHash, user) !=
             StructDefinition.VSkillUserSubmissionStatus.INREVIEW
         ) {
             address[] memory allSelectedVerifiers = evidenceIpfsHashToItsInfo[
                 evidenceIpfsHash
             ].selectedVerifiers;
             uint256 allSelectedVerifiersLength = allSelectedVerifiers.length;
             for (uint256 i = 0; i < allSelectedVerifiersLength; i++) {
                 _earnRewardsOrGetPenalized(
                     evidenceIpfsHash,
                     user,
                     allSelectedVerifiers[i]
                 );
             }
         }
    ```

    This section of code will revert the function with `Verifier__NotAllVerifiersProvidedFeedback`, this need to be fixed so that verifiers who is the first two will not get this error.
    => consider "PULL over PUSH" pattern for the reward and penalty. => line 261 in the `Verifier` contract.

- Issues✅ found in the contract, the `_updateEvidenceStatus` function got some issues here, we should use `storage` instead of `memory` to update the evidence status. => fix this as the test case developed.

---

### 2024/10/10

**What I did today:**

- refactor the test case for the `provideFeedback` function in the `Verifier` contract.
- fix the issue which the `_updateEvidenceStatus` will always revert this function for first two verifiers in the `provideFeedback` function in the `Verifier` contract. => However, this function still got other issues to be fixed. for current test case it reverts for reason below:

```bash
    ├─ [0] Verifier::provideFeedback("https://ipfs.io/ipfs/QmSsYRx3LpDAb1GZQm7zZ1AuHZjfbPkD6J7s9r41xu1mf8", "https://ipfs.io/ipfs/QmbJLndDmDiwdotu3MtfcjC2hC5tXeAR9EXbNSdUDUDYWa", user: [0x6CA6d1e2D5347Bfab1d91e883F1915560e09129D], true)
    │   ├─ emit FeedbackProvided(feedbackInfo: 0x5c96f047d29dbddd4e95634882df52806a722a5ef78b2a9c40d38b1a5df98be3)
    │   ├─ emit EvidenceToStatusApproveOrNotUpdated(evidenceIpfsHash: 0x4ec31a7244ef446c1acb5ded1a805b85118d0f808bcb005219f73857ca57896a, status: true)
    │   ├─ emit EvidenceToAllSelectedVerifiersToFeedbackStatusUpdated(verifierAddress: 0x0000000000000000000000000000000000000003, evidenceIpfsHash: 0x4ec31a7244ef446c1acb5ded1a805b85118d0f808bcb005219f73857ca57896a, status: true)
    │   └─ ← [Revert] panic: array out-of-bounds access (0x32)
    └─ ← [Revert] panic: array out-of-bounds access (0x32)

Suite result: FAILED. 0 passed; 1 failed; 0 skipped; finished in 11.77ms (1.09ms CPU time)

Ran 1 test suite in 1.13s (11.77ms CPU time): 0 tests passed, 1 failed, 0 skipped (1 total tests)

Failing tests:
Encountered 1 failing test in test/verifier/unit/VerifierTest.t.sol:VerifierTest
[FAIL. Reason: panic: array out-of-bounds access (0x32)] testProvideFeedbackCallUpdateEvidenceStatusIfMoreThanNumWordsVerifiersSubmitFeedback() (gas: 9223372036854754743)
```

But it works fine if I comment those code in the function `provideFeedback`:

```javascript
 if (
            evidenceIpfsHashToItsInfo[evidenceIpfsHash]
                .statusApproveOrNot
                .length < numWords
        ) {
            return;
        } else if (
            (_updateEvidenceStatus(evidenceIpfsHash, user) !=
                StructDefinition.VSkillUserSubmissionStatus.INREVIEW) &&
            (_updateEvidenceStatus(evidenceIpfsHash, user) !=
                StructDefinition.VSkillUserSubmissionStatus.SUBMITTED)
        ) {
            address[] memory allSelectedVerifiers = evidenceIpfsHashToItsInfo[
                evidenceIpfsHash
            ].selectedVerifiers;
            uint256 allSelectedVerifiersLength = allSelectedVerifiers.length;
            for (uint256 i = 0; i < allSelectedVerifiersLength; i++) {
                _earnRewardsOrGetPenalized(
                    evidenceIpfsHash,
                    user,
                    allSelectedVerifiers[i]
                );
            }
        }
```

---

### 2024/10/11

**What I did today:**

- fix the issue in the `provideFeedback` function in the `Verifier` contract. => This issue due to the wrong index for loop in the `_updateEvidenceStatus` function.
- find new issue✅ in `_earnRewardsOrGetPenalized`, if `DIFFERENTOPINIONS` status, before the `checkUpkeep` function is called by the chainlink nodes, we need to first remove the previous status in the `evidenceIpfsHashToItsInfo` so that we can update the status again, anyway we have a copy of the previous status in the `evidenceIpfsHashToItsInfo.allSelectedVerifiers` array, thus this will affect the rewards and penalties for the verifiers. => maybe refactor the `_earnRewardsOrGetPenalized` to accept an array of verifiers addresses as parameter. TBC... (This may also solve the known issue below.)
  - Solution: refactor the those functions so the `_updateEvidenceStatus` will be called only once, if the status is `DIFFERENTOPINIONS`, those verifiers who enter the `_earnRewardsOrGetPenalized` function pop their status from the `evidenceIpfsHashToItsInfo` array and then update the status again.

**Known Issue:**

- The `reward` function will distribution different amount of rewards to the verifiers. Those addresses which call the function earlier will get more rewards than those who call the function later.

```bash
 emit VerifierReputationUpdated(verifierAddress: 0x0000000000000000000000000000000000000003, prevousReputation: 2, currentReputation: 3)
    │   ├─ emit BonusMoneyUpdated(previousAmountInEth: 2500000000000000 [2.5e15], newAmountInEth: 2475000000000000 [2.475e15])
@>  │   ├─ emit VerifierStakeUpdated(verifier: 0x0000000000000000000000000000000000000003, previousAmountInEth: 10000000000000000 [1e16], newAmountInEth: 10025000000000000 [1.002e16])
    │   ├─ emit EvidenceStatusUpdated(user: user: [0x6CA6d1e2D5347Bfab1d91e883F1915560e09129D], evidenceIpfsHash: 0x4ec31a7244ef446c1acb5ded1a805b85118d0f808bcb005219f73857ca57896a, status: 2)
    │   ├─ emit EvidenceStatusUpdated(user: user: [0x6CA6d1e2D5347Bfab1d91e883F1915560e09129D], evidenceIpfsHash: 0x4ec31a7244ef446c1acb5ded1a805b85118d0f808bcb005219f73857ca57896a, status: 2)
    │   ├─ emit EvidenceStatusUpdated(user: user: [0x6CA6d1e2D5347Bfab1d91e883F1915560e09129D], evidenceIpfsHash: 0x4ec31a7244ef446c1acb5ded1a805b85118d0f808bcb005219f73857ca57896a, status: 2)
    │   ├─ emit VerifierReputationUpdated(verifierAddress: 0x0000000000000000000000000000000000000002, prevousReputation: 2, currentReputation: 3)
    │   ├─ emit BonusMoneyUpdated(previousAmountInEth: 2475000000000000 [2.475e15], newAmountInEth: 2450250000000000 [2.45e15])
@>  │   ├─ emit VerifierStakeUpdated(verifier: 0x0000000000000000000000000000000000000002, previousAmountInEth: 10000000000000000 [1e16], newAmountInEth: 10024750000000000 [1.002e16])
    │   ├─ emit EvidenceStatusUpdated(user: user: [0x6CA6d1e2D5347Bfab1d91e883F1915560e09129D], evidenceIpfsHash: 0x4ec31a7244ef446c1acb5ded1a805b85118d0f808bcb005219f73857ca57896a, status: 2)
    │   ├─ emit EvidenceStatusUpdated(user: user: [0x6CA6d1e2D5347Bfab1d91e883F1915560e09129D], evidenceIpfsHash: 0x4ec31a7244ef446c1acb5ded1a805b85118d0f808bcb005219f73857ca57896a, status: 2)
    │   ├─ emit EvidenceStatusUpdated(user: user: [0x6CA6d1e2D5347Bfab1d91e883F1915560e09129D], evidenceIpfsHash: 0x4ec31a7244ef446c1acb5ded1a805b85118d0f808bcb005219f73857ca57896a, status: 2)
    │   ├─ emit VerifierReputationUpdated(verifierAddress: 0x0000000000000000000000000000000000000003, prevousReputation: 3, currentReputation: 4)
    │   ├─ emit BonusMoneyUpdated(previousAmountInEth: 2450250000000000 [2.45e15], newAmountInEth: 2413496250000000 [2.413e15])
@>  │   ├─ emit VerifierStakeUpdated(verifier: 0x0000000000000000000000000000000000000003, previousAmountInEth: 10025000000000000 [1.002e16], newAmountInEth: 10061753750000000 [1.006e16])
```

The first verifier will get `25000000000000` while the second verifier will only get `24750000000000` wei as rewards.
It's not a huge gap but it's not fair for the second verifier. But this might incentivize the verifiers to provide feedback earlier.
Fix this or not? => follow up.

- The `Verifier` contract size is above limit:
  ```bash
  `Unknown2` is above the contract size limit (35616 > 24576).
  ```

---

### 2024/10/12

**What I did today:**

- Write integration tests for the `Staking` and `VSkillUser` contracts.

---

### 2024/10/14

**What I did today:**

- Write integration tests for the `VSkillUserNft` and `Oracle` contract.
- Since the verifier contract cannot be deployed due to the contract size limit, no integration tests for this contract now. => leave this for audit later.
- Final refactor and add natspec comments for `Staking` contract.

---

### 2024/10/15

**What I did today:**

- Final refactor for the rest contracts and add natspec comments for them.

---

### 2024/10/16

**What I did today:**

- Update the `README.md` and VSkill version 1 is done now.

---

### 2024/10/17

**What I did today:**

- Add `zkSync` instructions and update the `Makefile` and `README.md` to introduce deploying the contracts on `zkSync`.

---

### 2024/10/22

**What I did today:**

- Refactor those contracts to follow the best practice for variables. => `s_` for storage variables, `i_` for immutable variables... etc.

---

### 2024/10/23

**What I did today:**

- Add the `minimal-onboarding-questions.md` and `extensive-onboarding-questions.md` to the `audit` folder. => for the preparation of the audit.
- Add the `minimnal-onboarding-filled.md` and get ready to audit the contracts.
