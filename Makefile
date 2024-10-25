-include .env

help:
	@echo "Usage: make <target>"

install:
	@forge install OpenZeppelin/openzeppelin-contracts@v5.0.2 --no-commit && forge install cyfrin/foundry-devops@0.2.2 --no-commit && forge install foundry-rs/forge-std@v1.9.1 --no-commit && forge install smartcontractkit/chainlink-brownie-contracts@1.1.1 --no-commit

build:; @forge build

build-zksync:; @forge build --zksync

compile:; @forge compile

compile-zksync:; @forge compile --zksync

snapshot:; @forge snapshot

coverage-report:
	@forge coverage --report debug > coverage-report.md

test-sepolia:
	@forge test --fork-url $(SEPOLIA_RPC_URL)

test-mainnet:
	@forge test --fork-url $(MAINNET_RPC_URL)

# docker

docker-start:
	@sudo systemctl start docker

docker-stop:
	@sudo systemctl stop docker.socket

docker-status:
	@sudo systemctl status docker

docker-ps:
	@docker ps

# zkSync local node

zksync-start:
	@npx zksync-cli dev start

# deploy contracts zkSync

# deploy-staking-zksync-local:
# 	@forge create src/staking/Staking.sol:Staking --rpc-url $(ZKSYNC_LOCAL_RPC_URL) --private-key $(ZKSYNC_LOCAL_PRIVATE_KEY) --legacy --zksync --constructor-args 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419

# deploy-staking-zksync-sepolia:
# 	@forge create src/staking/Staking.sol:Staking --rpc-url $(ZKSYNC_SEPOLIA_RPC_URL) --private-key $(PRIVATE_KEY) --legacy --zksync --constructor-args 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419

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

# User NFT module interactions

mintUserNftVSkillUserNft-anvil:
	@forge script script/nft/Interactions.s.sol:MintUserNftVSkillUserNft --rpc-url $(ANVIL_RPC_URL) --private-key $(ANVIL_PRIVATE_KEY) --broadcast -vv

# Oracle module interactions

distributionRandomNumberForVerifiersDistribution-anvil:
	@forge script script/oracle/Interactions.s.sol:DistributionRandomNumberForVerifiersDistribution --rpc-url $(ANVIL_RPC_URL) --private-key $(ANVIL_PRIVATE_KEY) --broadcast -vv

# Audit

slither:
	@slither .

aderyn:
	@aderyn .