# VSkill Security Review Onboarding

# Table of Contents

- [VSkill Security Review Onboarding](#vskill-security-review-onboarding)
- [Table of Contents](#table-of-contents)
- [About the project](#about-the-project)
  - [Features](#features)
  - [Key Process](#key-process)
- [Stats](#stats)
- [Setup](#setup)
  - [Requirements](#requirements)
  - [Installation](#installation)
  - [Testing](#testing)
- [Security Review Scope](#security-review-scope)
  - [Commit Hash](#commit-hash)
  - [Repo URL](#repo-url)
  - [In scope vs out of scope contracts](#in-scope-vs-out-of-scope-contracts)
  - [Compatibilities](#compatibilities)
- [Roles](#roles)
- [Known Issues](#known-issues)

# About the project

VSkill (VeriSkill) is a decentralized platform for verifying skills. It leverages blockchain technology to create a transparent and trustworthy system for skill verification.

## Features

- Staking mechanism for verifiers
- Reputation system for verifiers
- Incentive mechanism to encourage correct verifications
- Filecoin(Lighthouse) integration for evidence submission and feedback storage
- NFT minting for verified skills
- Random assignment of evidence to verifiers using Chainlink VRF
- Automated evidence distribution using Chainlink Automation
- Real-time USD/ETH price conversion using Chainlink Price Feed

## Key Process

1. User submits evidence for verification.

<img src="./image/user-submit-evidence.svg">

2. Verifier check evidence and provide feedback.

<img src="./image/verifier-check-evidence-and-provide-feedback.svg">

3. Relayer coordinates the user and verifier.

<img src="./image/relayer-coordinates-user-and-verifier.svg">

# Stats

- nSLOC: 1811
- Complexity Score: 1489
- Security Review Timeline: 2025/2/13 - 2024/2/27(2 weeks)

# Setup

## Requirements

- Foundry
- Git
- CMake

## Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/cqlyj/VSkill
   ```
2. Navigate to the project directory:
   ```bash
   cd VSkill
   ```
3. Install dependencies:
   ```bash
   make install
   ```
4. Build the project:
   ```bash
   make build
   ```

## Testing

VSkill includes a comprehensive test suite to ensure the reliability and correctness of the smart contracts.

To run the tests:

```javascript
// Run all tests on local network
make test

// Run tests on specific network
make test NETWORK=Sepolia
```

# Security Review Scope

```javascript
./src/
#-- Distribution.sol
#-- Relayer.sol
#-- Staking.sol
#-- VSkillUser.sol
#-- VSkillUserNft.sol
#-- Verifier.sol
#-- interfaces
|   #-- IAutomationRegistrar.sol
|   #-- IRelayer.sol
#-- library
|   #-- OracleLib.sol
|   #-- PriceCoverter.sol
|   #-- StructDefinition.sol
#-- optimizedGas
    #-- RelayerYul.sol
```

## Commit Hash

```bash
02ceaa15a2f32ac00ffbb693996cddffa909bd57
```

## Repo URL

https://github.com/cqlyj/VSkill

## In scope vs out of scope contracts

The `/lib` directory is out of scope for the security review.

## Compatibilities

- Solc Version: 0.8.26
- Chain(s) to deploy contract to:
  - Ethereum Sepolia Testnet
  - Amoy Testnet
  - ZkSync Sepolia Testnet
  - Local anvil chain
  - Local ZkSync chain(For now not supported)
  - Any EVM compatible chain
- Tokens:
  - VSkillUserNft(ERC721s)

# Roles

```
1. Users: Submit evidence to be verified.
2. Verifiers: Stake money to become verifiers, review evidence, and decide on skill verification.
3. Owner: Can modify submission fees and supported skills for verification.
```

# Known Issues

1. The owner can modify the submission fees and supported skills, which may lead centralized control over the platform. But for now since only deployed on testnet, it's not a big issue.
2. There is no natspec documentation for the smart contracts, which may lead to misunderstandings of the contract functionalities.
