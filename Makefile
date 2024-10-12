-include .env

help:
	@echo "Usage: make <target>"

install:
	@forge install OpenZeppelin/openzeppelin-contracts@v5.0.2 --no-commit && forge install cyfrin/foundry-devops@0.2.2 --no-commit && forge install foundry-rs/forge-std@v1.9.1 --no-commit && forge install smartcontractkit/chainlink-brownie-contracts@1.1.1 --no-commit

build:; @forge build

compile:; @forge compile

snapshot:; @forge snapshot

coverage-report:
	@forge coverage --report debug > coverage-report.md

test-sepolia:
	@forge test --fork-url $(SEPOLIA_RPC_URL)

test-mainnet:
	@forge test --fork-url $(MAINNET_RPC_URL)

# deploy contracts

deploy-staking-sepolia:
	@forge script script/staking/DeployStaking.s.sol:DeployStaking --rpc-url $(SEPOLIA_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) --legacy -vvvv

deploy-staking-anvil:
	@forge script script/staking/DeployStaking.s.sol:DeployStaking --rpc-url $(ANVIL_RPC_URL) --private-key $(ANVIL_PRIVATE_KEY) --broadcast -vvvv

deploy-user-sepolia:
	@forge script script/user/DeployVSkillUser.s.sol:DeployVSkillUser --rpc-url $(SEPOLIA_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) --legacy -vvvv

deploy-user-anvil:
	@forge script script/user/DeployVSkillUser.s.sol:DeployVSkillUser --rpc-url $(ANVIL_RPC_URL) --private-key $(ANVIL_PRIVATE_KEY) --broadcast -vvvv

deploy-oracle-sepolia:
	@forge script script/oracle/DeployDistribution.s.sol:DeployDistribution --rpc-url $(SEPOLIA_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) --legacy -vvvv

deploy-oracle-anvil:
	@forge script script/oracle/DeployDistribution.s.sol:DeployDistribution --rpc-url $(ANVIL_RPC_URL) --private-key $(ANVIL_PRIVATE_KEY) --broadcast -vvvv

deploy-nft-user-sepolia:
	@forge script script/nft/DeployVSkillUserNft.s.sol:DeployVSkillUserNft --rpc-url $(SEPOLIA_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) --legacy -vvvv

deploy-nft-user-anvil:
	@forge script script/nft/DeployVSkillUserNft.s.sol:DeployVSkillUserNft --rpc-url $(ANVIL_RPC_URL) --private-key $(ANVIL_PRIVATE_KEY) --broadcast -vvvv

deploy-verifier-sepolia:
	@forge script script/verifier/DeployVerifier.s.sol:DeployVerifier --rpc-url $(SEPOLIA_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) --legacy -vvvv

deploy-verifier-anvil:
	@forge script script/verifier/DeployVerifier.s.sol:DeployVerifier --rpc-url $(ANVIL_RPC_URL) --private-key $(ANVIL_PRIVATE_KEY) --broadcast -vvvv
	
# Staking module interactions

withdrawStakeStaking-anvil:
	@forge script script/staking/Interactions.s.sol:WithdrawStakeStaking --rpc-url $(ANVIL_RPC_URL) --private-key $(ANVIL_PRIVATE_KEY) --broadcast -vv

stakeSaking-anvil:
	@forge script script/staking/Interactions.s.sol:StakeStaking --rpc-url $(ANVIL_RPC_URL) --private-key $(ANVIL_PRIVATE_KEY) --broadcast -vv

addBonusMoneyForVerifierStaking-anvil:
	@forge script script/staking/Interactions.s.sol:AddBonusMoneyForVerifierStaking --rpc-url $(ANVIL_RPC_URL) --private-key $(ANVIL_PRIVATE_KEY) --broadcast -vv

# User module interactions

submitEvidenceVSkillUser-anvil:
	@forge script script/user/Interactions.s.sol:SubmitEvidenceVSkillUser --rpc-url $(ANVIL_RPC_URL) --private-key $(ANVIL_PRIVATE_KEY) --broadcast -vv

changeSubmissionFeeVSkillUser-anvil:
	@forge script script/user/Interactions.s.sol:ChangeSubmissionFeeVSkillUser --rpc-url $(ANVIL_RPC_URL) --private-key $(ANVIL_PRIVATE_KEY) --broadcast -vv

addMoreSkillsVSkillUser-anvil:
	@forge script script/user/Interactions.s.sol:AddMoreSkillsVSkillUser --rpc-url $(ANVIL_RPC_URL) --private-key $(ANVIL_PRIVATE_KEY) --broadcast -vv

checkFeedbackOfEvidenceVSkillUser-anvil:
	@forge script script/user/Interactions.s.sol:CheckFeedbackOfEvidenceVSkillUser --rpc-url $(ANVIL_RPC_URL) --private-key $(ANVIL_PRIVATE_KEY) --broadcast -vv

earnUserNft-anvil:
	@forge script script/user/Interactions.s.sol:EarnUserNft --rpc-url $(ANVIL_RPC_URL) --private-key $(ANVIL_PRIVATE_KEY) --broadcast -vv