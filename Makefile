-include .env


build:; forge build

deploy-sepolia:
	forge script script/staking/DeployStaking.s.sol:DeployStaking --rpc-url $(SEPOLIA_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) --legacy -vvvv

deploy-anvil:
	forge script script/staking/DeployStaking.s.sol:DeployStaking --rpc-url $(ANVIL_RPC_URL) --private-key $(ANVIL_PRIVATE_KEY) --broadcast -vvvv

stakeToBeTheVerifierStaking-anvil:
	forge script script/staking/Interactions.s.sol:StakeToBeTheVerifierStaking --rpc-url $(ANVIL_RPC_URL) --private-key $(ANVIL_PRIVATE_KEY) --broadcast -vv

withdrawStakeStaking-anvil:
	forge script script/staking/Interactions.s.sol:WithdrawStakeStaking --rpc-url $(ANVIL_RPC_URL) --private-key $(ANVIL_PRIVATE_KEY) --broadcast -vv

stakeSaking-anvil:
	forge script script/staking/Interactions.s.sol:StakeStaking --rpc-url $(ANVIL_RPC_URL) --private-key $(ANVIL_PRIVATE_KEY) --broadcast -vv