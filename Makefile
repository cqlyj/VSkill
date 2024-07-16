-include .env

help:
	@echo "Usage: make <target>"

install:
	forge install OpenZeppelin/openzeppelin-contracts@5.0.2 --no-commit && forge install cyfrin/foundry-devops@0.2.2 --no-commit && forge install foundry-rs/forge-std@v1.9.1 --no-commit && forge install smartcontractkit/chainlink-brownie-contracts@1.1.1 --no-commit

build:; @forge build

compile:; @forge compile

coverage-report:
	@forge coverage --report debug > coverage-report.md

test-sepolia:
	@forge test --fork-url $(SEPOLIA_RPC_URL)

test-mainnet:
	@forge test --fork-url $(MAINNET_RPC_URL)

deploy-staking-sepolia:
	@forge script script/staking/DeployStaking.s.sol:DeployStaking --rpc-url $(SEPOLIA_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) --legacy -vvvv

deploy-staking-anvil:
	@forge script script/staking/DeployStaking.s.sol:DeployStaking --rpc-url $(ANVIL_RPC_URL) --private-key $(ANVIL_PRIVATE_KEY) --broadcast -vvvv

stakeToBeTheVerifierStaking-anvil:
	@forge script script/staking/Interactions.s.sol:StakeToBeTheVerifierStaking --rpc-url $(ANVIL_RPC_URL) --private-key $(ANVIL_PRIVATE_KEY) --broadcast -vv

withdrawStakeStaking-anvil:
	@forge script script/staking/Interactions.s.sol:WithdrawStakeStaking --rpc-url $(ANVIL_RPC_URL) --private-key $(ANVIL_PRIVATE_KEY) --broadcast -vv

stakeSaking-anvil:
	@forge script script/staking/Interactions.s.sol:StakeStaking --rpc-url $(ANVIL_RPC_URL) --private-key $(ANVIL_PRIVATE_KEY) --broadcast -vv