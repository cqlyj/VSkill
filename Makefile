-include .env

.PHONY: packToCar unpackToOrigin lighthouse-import-wallet lighthouse-upload deploy check-contract check-network-config

help:
	@echo "Usage: make <target>"

install:
	@forge install OpenZeppelin/openzeppelin-contracts@v5.0.2 --no-commit && forge install foundry-rs/forge-std@v1.9.5 --no-commit && forge install smartcontractkit/chainlink-brownie-contracts@1.3.0 --no-commit

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

##############################   zkSync local node   ##############################

zksync-start:
	@npx zksync-cli dev start

# deploy contracts zkSync

# deploy-staking-zksync-local:
# 	@forge create src/staking/Staking.sol:Staking --rpc-url $(ZKSYNC_LOCAL_RPC_URL) --private-key $(ZKSYNC_LOCAL_PRIVATE_KEY) --legacy --zksync --constructor-args 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419

# deploy-staking-zksync-sepolia:
# 	@forge create src/staking/Staking.sol:Staking --rpc-url $(ZKSYNC_SEPOLIA_RPC_URL) --private-key $(PRIVATE_KEY) --legacy --zksync --constructor-args 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419

##############################   deploy contracts   ##############################

# make deploy ContractName NETWORK=NetworkName

CONTRACT = $(word 2, $(MAKECMDGOALS))
NETWORK = $(if $(word 3,$(MAKECMDGOALS)),$(word 3,$(MAKECMDGOALS)),anvil)

# Main deploy target
deploy: check-contract check-network-config
ifeq ($(NETWORK),anvil)
	@forge script script/deploy/Deploy$(CONTRACT).s.sol:Deploy$(CONTRACT) \
		--rpc-url $(ANVIL_RPC_URL) \
		--private-key $(ANVIL_PRIVATE_KEY) \
		--broadcast -vvvv
else
	@forge script script/deploy/Deploy$(CONTRACT).s.sol:Deploy$(CONTRACT) \
		--rpc-url $($(shell echo $(NETWORK) | tr a-z A-Z)_RPC_URL) \
		--account burner \
		--sender $(BURNER_ADDRESS) \
		--verify \
		--etherscan-api-key $($(shell echo $(NETWORK) | tr a-z A-Z)_ETHERSCAN_API_KEY) \
		--broadcast -vvvv
endif

# Check if contract name is provided
check-contract:
ifndef CONTRACT
	$(error Contract name is required. Usage: make deploy ContractName [NetworkName])
endif

# Check if network configuration exists
check-network-config:
ifneq ($(NETWORK),anvil)
	@if [ -z "$($(shell echo $(NETWORK) | tr a-z A-Z)_RPC_URL)" ]; then \
		echo "Error: Network '$(NETWORK)' is not supported. Please check your .env file for $(shell echo $(NETWORK) | tr a-z A-Z)_RPC_URL configuration."; \
		exit 1; \
	fi
endif

# Handle unknown arguments
%:
	@:

##############################   Interactions  ##############################

# Initialize

initialize-anvil:
	@forge script script/interactions/Initialize.s.sol:Initialize \
		--rpc-url $(ANVIL_RPC_URL) \
		--private-key $(ANVIL_PRIVATE_KEY) \
		--broadcast -vvvv

# These three interactions will not working if you try to manually run them in the command line
# But they will be good to go in the test because each time in the script we have a brand new HelperConfig
# So, only run them in the test or in other network rather than the anvil local network

create-subscription:
	@forge script script/interactions/VRFInteractions/CreateSubscription.s.sol:CreateSubscription \
		--rpc-url $(ANVIL_RPC_URL) \
		--private-key $(ANVIL_PRIVATE_KEY) \
		--broadcast -vvvv

fund-subscription:
	@forge script script/interactions/VRFInteractions/FundSubscription.s.sol:FundSubscription \
		--rpc-url $(ANVIL_RPC_URL) \
		--private-key $(ANVIL_PRIVATE_KEY) \
		--broadcast -vvvv

add-consumer:
	@forge script script/interactions/VRFInteractions/AddConsumer.s.sol:AddConsumer \
		--rpc-url $(ANVIL_RPC_URL) \
		--private-key $(ANVIL_PRIVATE_KEY) \
		--broadcast -vvvv

register-upkeep:
	@forge script script/interactions/AutomationInteractions/RegisterUpkeep.s.sol:RegisterUpkeep \
		--rpc-url $(ANVIL_RPC_URL) \
		--private-key $(ANVIL_PRIVATE_KEY) \
		--broadcast -vvvv	

# VSkillUser
	
submit-evidence-anvil:
	@forge script script/interactions/VSkillUserInteractions.s.sol:SubmitEvidence \
		--rpc-url $(ANVIL_RPC_URL) \
		--private-key $(ANVIL_PRIVATE_KEY) \
		--broadcast -vvvv

change-submission-fee-anvil:
	@forge script script/interactions/VSkillUserInteractions.s.sol:ChangeSubmissionFee \
		--rpc-url $(ANVIL_RPC_URL) \
		--private-key $(ANVIL_PRIVATE_KEY) \
		--broadcast -vvvv

withdraw-profit-anvil:
	@forge script script/interactions/VSkillUserInteractions.s.sol:WithdrawProfit \
		--rpc-url $(ANVIL_RPC_URL) \
		--private-key $(ANVIL_PRIVATE_KEY) \
		--broadcast -vvvv	

# Verifier

stake-anvil:
	@forge script script/interactions/VerifierInteractions.s.sol:Stake \
		--rpc-url $(ANVIL_RPC_URL) \
		--private-key $(ANVIL_PRIVATE_KEY) \
		--broadcast -vvvv

add-skill-domain-anvil:
	@forge script script/interactions/VerifierInteractions.s.sol:AddSkillDomain \
		--rpc-url $(ANVIL_RPC_URL) \
		--private-key $(ANVIL_PRIVATE_KEY) \
		--broadcast -vvvv

withdraw-stake-and-lose-verifier-anvil:
	@forge script script/interactions/VerifierInteractions.s.sol:WithdrawStakeAndLoseVerifier \
		--rpc-url $(ANVIL_RPC_URL) \
		--private-key $(ANVIL_PRIVATE_KEY) \
		--broadcast -vvvv

# Relayer

assign-evidence-to-verifiers-anvil:
	@forge script script/interactions/RelayerInteractions.s.sol:AssignEvidenceToVerifiers \
		--rpc-url $(ANVIL_RPC_URL) \
		--private-key $(ANVIL_PRIVATE_KEY) \
		--broadcast -vvvv

process-evidence-status-anvil:
	@forge script script/interactions/RelayerInteractions.s.sol:ProcessEvidenceStatus \
		--rpc-url $(ANVIL_RPC_URL) \
		--private-key $(ANVIL_PRIVATE_KEY) \
		--broadcast -vvvv

handle-evidence-after-deadline-anvil:
	@forge script script/interactions/RelayerInteractions.s.sol:HandleEvidenceAfterDeadline \
		--rpc-url $(ANVIL_RPC_URL) \
		--private-key $(ANVIL_PRIVATE_KEY) \
		--broadcast -vvvv

add-more-skill-anvil:
	@forge script script/interactions/RelayerInteractions.s.sol:AddMoreSkill \
		--rpc-url $(ANVIL_RPC_URL) \
		--private-key $(ANVIL_PRIVATE_KEY) \
		--broadcast -vvvv

transfer-bonus-from-VSkillUser-to-Verifier-contract-anvil:
	@forge script script/interactions/RelayerInteractions.s.sol:TransferBonusFromVSkillUserToVerifierContract \
		--rpc-url $(ANVIL_RPC_URL) \
		--private-key $(ANVIL_PRIVATE_KEY) \
		--broadcast -vvvv

##############################   Audit   ##############################

slither:
	@slither . --config-file ./slither.config.json

aderyn:
	@aderyn .

scope:
	@tree ./src/ | sed 's/└/#/g; s/──/--/g; s/├/#/g; s/│ /|/g; s/│/|/g'

scopeFile:
	@tree ./src/ | sed 's/└/#/g' | awk -F '── ' '!/\.sol$$/ { path[int((length($$0) - length($$2))/2)] = $$2; next } { p = "src"; for(i=2; i<=int((length($$0) - length($$2))/2); i++) if (path[i] != "") p = p "/" path[i]; print p "/" $$2; }' > scope.txt

##############################   File conversion   ##############################
packToCar:
	@if [ -z "$(evidence)" ]; then \
		echo "Error: Please specify an evidence file using the 'evidence' variable (e.g., make packToCar evidence=xxx.txt)"; \
		exit 1; \
	fi
	@if [ ! -f evidence/origin/$(evidence) ]; then \
		echo "Error: evidence/origin/$(evidence) does not exist."; \
		exit 1; \
	fi
	mkdir -p evidence/car
	ipfs-car pack --no-wrap evidence/origin/$(evidence) > evidence/car/$(basename $(evidence)).car

unpackToOrigin:
	@if [ -z "$(carfile)" ]; then \
		echo "Error: Please specify a .car file using the 'carfile' variable (e.g., make unpackToOrigin carfile=xxx.car)"; \
		exit 1; \
	fi
	@if [ -z "$(output)" ]; then \
		echo "Error: Please specify the output file using the 'output' variable (e.g., make unpackToOrigin carfile=xxx.car output=xxx.pdf)"; \
		exit 1; \
	fi
	@if [ ! -f evidence/car/$(carfile) ]; then \
		echo "Error: evidence/car/$(carfile) does not exist."; \
		exit 1; \
	fi
	mkdir -p evidence/origin
	ipfs-car unpack --no-wrap evidence/car/$(carfile) > evidence/origin/$(output)

##############################   Upload file to Lighthouse   ##############################

# import your wallet first
lighthouse-import-wallet:
	@if [ -z "$(private-key)" ]; then \
		echo "Error: Please specify the private key using the 'private-key' variable (e.g., make lighthouse-import-wallet private-key=your-private-key)"; \
		exit 1; \
	fi
	lighthouse-web3 import-wallet --key $(private-key)

# generate the api key
lighthouse-generate-api-key:
	@lighthouse-web3 api-key -n

lighthouse-upload:
	@if [ -z "$(carfile)" ]; then \
		echo "Error: Please specify the .car file using the 'carfile' variable (e.g., make lighthouse-upload carfile=evidence.car)"; \
		exit 1; \
	fi
	@if [ ! -f evidence/car/$(carfile) ]; then \
		echo "Error: The file 'evidence/car/$(carfile)' does not exist. Please provide a valid file name."; \
		exit 1; \
	fi
	lighthouse-web3 upload evidence/car/$(carfile)