-include .env

.PHONY: packToCar unpackToOrigin lighthouse-import-wallet lighthouse-upload deploy check-contract check-network-config

help:
	@echo "Usage: make <target>"
	@echo ""
	@echo "Available targets:"
	@echo ""
	@echo "Build and Test:"
	@echo "  install              Install the necessary dependencies and libraries"
	@echo "  build                Build the project"
	@echo "  build-zksync         Build the project for zkSync"
	@echo "  compile              Compile the project"
	@echo "  compile-zksync       Compile the project for zkSync"
	@echo "  snapshot             Create a snapshot"
	@echo "  coverage-report      Generate a test coverage report"
	@echo "Testing:"
	@echo "  test                 Run tests (Usage: make test [NetworkName])"
	@echo ""
	@echo "Docker Management:"
	@echo "  docker-start         Start Docker service"
	@echo "  docker-stop          Stop Docker service"
	@echo "  docker-status        Check Docker service status"
	@echo "  docker-ps            List running Docker containers"
	@echo ""
	@echo "zkSync:"
	@echo "  zksync-start         Start zkSync local node"
	@echo ""
	@echo "Deployment:"
	@echo "  deploy               Deploy contract (Usage: make deploy ContractName NETWORK=[NetworkName])"
	@echo ""
	@echo "Interactions:"
	@echo "  VRF:"
	@echo "    create-subscription         Create VRF subscription"
	@echo "    fund-subscription           Fund VRF subscription"
	@echo "    add-consumer                Add consumer to VRF subscription"
	@echo "    register-upkeep             Register for automation upkeep"
	@echo ""
	@echo "  VSkillUser:"
	@echo "    submit-evidence             Submit evidence to VSkillUser"
	@echo "    change-submission-fee       Change the submission fee"
	@echo "    withdraw-profit             Withdraw profits"
	@echo ""
	@echo "  Verifier:"
	@echo "    stake                       Stake tokens as verifier"
	@echo "    add-skill-domain            Add a new skill domain"
	@echo "    withdraw-stake-and-lose-verifier  Withdraw stake and lose verifier status"
	@echo ""
	@echo "  Relayer:"
	@echo "    assign-evidence-to-verifiers     Assign evidence to verifiers"
	@echo "    process-evidence-status          Process evidence status"
	@echo "    handle-evidence-after-deadline   Handle evidence after deadline"
	@echo "    add-more-skill                   Add additional skills"
	@echo "    transfer-bonus-from-VSkillUser-to-Verifier-contract  Transfer bonus between contracts"
	@echo ""
	@echo "Audit:"
	@echo "  slither              Run Slither analysis"
	@echo "  aderyn               Run Aderyn analysis"
	@echo "  scope                Show project structure"
	@echo "  scopeFile            Generate scope file"
	@echo ""
	@echo "File Conversion:"
	@echo "  packToCar            Convert file to CAR format (Usage: make packToCar evidence=filename)"
	@echo "  unpackToOrigin       Convert CAR file back to original (Usage: make unpackToOrigin carfile=filename.car output=filename)"
	@echo ""
	@echo "Lighthouse:"
	@echo "  lighthouse-import-wallet      Import wallet to Lighthouse (Usage: make lighthouse-import-wallet private-key=key)"
	@echo "  lighthouse-generate-api-key   Generate Lighthouse API key"
	@echo "  lighthouse-upload             Upload file to Lighthouse (Usage: make lighthouse-upload carfile=filename.car)"

install:
	@forge install OpenZeppelin/openzeppelin-contracts@v5.0.2 --no-commit && forge install foundry-rs/forge-std@v1.9.5 --no-commit && forge install smartcontractkit/chainlink-brownie-contracts@1.3.0 --no-commit

build:; @forge build

build-zksync:; @forge build --zksync

compile:; @forge compile

compile-zksync:; @forge compile --zksync

snapshot:; @forge snapshot

coverage-report:
	@forge coverage --report debug > coverage-report.md

# Testing
NETWORK = $(if $(word 2,$(MAKECMDGOALS)),$(word 2,$(MAKECMDGOALS)),anvil)

test: check-network-config
ifeq ($(NETWORK),anvil)
	@forge test
else
	@forge test --fork-url $($(shell echo $(NETWORK) | tr a-z A-Z)_RPC_URL)
endif

# Handle unknown arguments
%:
	@:

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

# Network configuration
NETWORK = $(if $(word 2,$(MAKECMDGOALS)),$(word 2,$(MAKECMDGOALS)),anvil)

# Initialize
initialize: check-network-config
ifeq ($(NETWORK),anvil)
	@forge script script/interactions/Initialize.s.sol:Initialize \
		--rpc-url $(ANVIL_RPC_URL) \
		--private-key $(ANVIL_PRIVATE_KEY) \
		--broadcast -vvvv
else
	@forge script script/interactions/Initialize.s.sol:Initialize \
		--rpc-url $($(shell echo $(NETWORK) | tr a-z A-Z)_RPC_URL) \
		--account burner \
		--sender $(BURNER_ADDRESS) \
		--broadcast -vvvv
endif

# VRF Interactions
create-subscription: check-network-config
ifeq ($(NETWORK),anvil)
	@forge script script/interactions/VRFInteractions/CreateSubscription.s.sol:CreateSubscription \
		--rpc-url $(ANVIL_RPC_URL) \
		--private-key $(ANVIL_PRIVATE_KEY) \
		--broadcast -vvvv
else
	@forge script script/interactions/VRFInteractions/CreateSubscription.s.sol:CreateSubscription \
		--rpc-url $($(shell echo $(NETWORK) | tr a-z A-Z)_RPC_URL) \
		--account burner \
		--sender $(BURNER_ADDRESS) \
		--broadcast -vvvv
endif

fund-subscription: check-network-config
ifeq ($(NETWORK),anvil)
	@forge script script/interactions/VRFInteractions/FundSubscription.s.sol:FundSubscription \
		--rpc-url $(ANVIL_RPC_URL) \
		--private-key $(ANVIL_PRIVATE_KEY) \
		--broadcast -vvvv
else
	@forge script script/interactions/VRFInteractions/FundSubscription.s.sol:FundSubscription \
		--rpc-url $($(shell echo $(NETWORK) | tr a-z A-Z)_RPC_URL) \
		--account burner \
		--sender $(BURNER_ADDRESS) \
		--broadcast -vvvv
endif

add-consumer: check-network-config
ifeq ($(NETWORK),anvil)
	@forge script script/interactions/VRFInteractions/AddConsumer.s.sol:AddConsumer \
		--rpc-url $(ANVIL_RPC_URL) \
		--private-key $(ANVIL_PRIVATE_KEY) \
		--broadcast -vvvv
else
	@forge script script/interactions/VRFInteractions/AddConsumer.s.sol:AddConsumer \
		--rpc-url $($(shell echo $(NETWORK) | tr a-z A-Z)_RPC_URL) \
		--account burner \
		--sender $(BURNER_ADDRESS) \
		--broadcast -vvvv
endif

register-upkeep: check-network-config
ifeq ($(NETWORK),anvil)
	@forge script script/interactions/AutomationInteractions/RegisterUpkeep.s.sol:RegisterUpkeep \
		--rpc-url $(ANVIL_RPC_URL) \
		--private-key $(ANVIL_PRIVATE_KEY) \
		--broadcast -vvvv
else
	@forge script script/interactions/AutomationInteractions/RegisterUpkeep.s.sol:RegisterUpkeep \
		--rpc-url $($(shell echo $(NETWORK) | tr a-z A-Z)_RPC_URL) \
		--account burner \
		--sender $(BURNER_ADDRESS) \
		--broadcast -vvvv
endif

# VSkillUser Interactions
submit-evidence: check-network-config
ifeq ($(NETWORK),anvil)
	@forge script script/interactions/VSkillUserInteractions.s.sol:SubmitEvidence \
		--rpc-url $(ANVIL_RPC_URL) \
		--private-key $(ANVIL_PRIVATE_KEY) \
		--broadcast -vvvv
else
	@forge script script/interactions/VSkillUserInteractions.s.sol:SubmitEvidence \
		--rpc-url $($(shell echo $(NETWORK) | tr a-z A-Z)_RPC_URL) \
		--account burner \
		--sender $(BURNER_ADDRESS) \
		--broadcast -vvvv
endif

change-submission-fee: check-network-config
ifeq ($(NETWORK),anvil)
	@forge script script/interactions/VSkillUserInteractions.s.sol:ChangeSubmissionFee \
		--rpc-url $(ANVIL_RPC_URL) \
		--private-key $(ANVIL_PRIVATE_KEY) \
		--broadcast -vvvv
else
	@forge script script/interactions/VSkillUserInteractions.s.sol:ChangeSubmissionFee \
		--rpc-url $($(shell echo $(NETWORK) | tr a-z A-Z)_RPC_URL) \
		--account burner \
		--sender $(BURNER_ADDRESS) \
		--broadcast -vvvv
endif

withdraw-profit: check-network-config
ifeq ($(NETWORK),anvil)
	@forge script script/interactions/VSkillUserInteractions.s.sol:WithdrawProfit \
		--rpc-url $(ANVIL_RPC_URL) \
		--private-key $(ANVIL_PRIVATE_KEY) \
		--broadcast -vvvv
else
	@forge script script/interactions/VSkillUserInteractions.s.sol:WithdrawProfit \
		--rpc-url $($(shell echo $(NETWORK) | tr a-z A-Z)_RPC_URL) \
		--account burner \
		--sender $(BURNER_ADDRESS) \
		--broadcast -vvvv
endif

# Verifier Interactions
stake: check-network-config
ifeq ($(NETWORK),anvil)
	@forge script script/interactions/VerifierInteractions.s.sol:Stake \
		--rpc-url $(ANVIL_RPC_URL) \
		--private-key $(ANVIL_PRIVATE_KEY) \
		--broadcast -vvvv
else
	@forge script script/interactions/VerifierInteractions.s.sol:Stake \
		--rpc-url $($(shell echo $(NETWORK) | tr a-z A-Z)_RPC_URL) \
		--account burner \
		--sender $(BURNER_ADDRESS) \
		--broadcast -vvvv
endif

add-skill-domain: check-network-config
ifeq ($(NETWORK),anvil)
	@forge script script/interactions/VerifierInteractions.s.sol:AddSkillDomain \
		--rpc-url $(ANVIL_RPC_URL) \
		--private-key $(ANVIL_PRIVATE_KEY) \
		--broadcast -vvvv
else
	@forge script script/interactions/VerifierInteractions.s.sol:AddSkillDomain \
		--rpc-url $($(shell echo $(NETWORK) | tr a-z A-Z)_RPC_URL) \
		--account burner \
		--sender $(BURNER_ADDRESS) \
		--broadcast -vvvv
endif

withdraw-stake-and-lose-verifier: check-network-config
ifeq ($(NETWORK),anvil)
	@forge script script/interactions/VerifierInteractions.s.sol:WithdrawStakeAndLoseVerifier \
		--rpc-url $(ANVIL_RPC_URL) \
		--private-key $(ANVIL_PRIVATE_KEY) \
		--broadcast -vvvv
else
	@forge script script/interactions/VerifierInteractions.s.sol:WithdrawStakeAndLoseVerifier \
		--rpc-url $($(shell echo $(NETWORK) | tr a-z A-Z)_RPC_URL) \
		--account burner \
		--sender $(BURNER_ADDRESS) \
		--broadcast -vvvv
endif

# Relayer Interactions
assign-evidence-to-verifiers: check-network-config
ifeq ($(NETWORK),anvil)
	@forge script script/interactions/RelayerInteractions.s.sol:AssignEvidenceToVerifiers \
		--rpc-url $(ANVIL_RPC_URL) \
		--private-key $(ANVIL_PRIVATE_KEY) \
		--broadcast -vvvv
else
	@forge script script/interactions/RelayerInteractions.s.sol:AssignEvidenceToVerifiers \
		--rpc-url $($(shell echo $(NETWORK) | tr a-z A-Z)_RPC_URL) \
		--account burner \
		--sender $(BURNER_ADDRESS) \
		--broadcast -vvvv
endif

process-evidence-status: check-network-config
ifeq ($(NETWORK),anvil)
	@forge script script/interactions/RelayerInteractions.s.sol:ProcessEvidenceStatus \
		--rpc-url $(ANVIL_RPC_URL) \
		--private-key $(ANVIL_PRIVATE_KEY) \
		--broadcast -vvvv
else
	@forge script script/interactions/RelayerInteractions.s.sol:ProcessEvidenceStatus \
		--rpc-url $($(shell echo $(NETWORK) | tr a-z A-Z)_RPC_URL) \
		--account burner \
		--sender $(BURNER_ADDRESS) \
		--broadcast -vvvv
endif

handle-evidence-after-deadline: check-network-config
ifeq ($(NETWORK),anvil)
	@forge script script/interactions/RelayerInteractions.s.sol:HandleEvidenceAfterDeadline \
		--rpc-url $(ANVIL_RPC_URL) \
		--private-key $(ANVIL_PRIVATE_KEY) \
		--broadcast -vvvv
else
	@forge script script/interactions/RelayerInteractions.s.sol:HandleEvidenceAfterDeadline \
		--rpc-url $($(shell echo $(NETWORK) | tr a-z A-Z)_RPC_URL) \
		--account burner \
		--sender $(BURNER_ADDRESS) \
		--broadcast -vvvv
endif

add-more-skill: check-network-config
ifeq ($(NETWORK),anvil)
	@forge script script/interactions/RelayerInteractions.s.sol:AddMoreSkill \
		--rpc-url $(ANVIL_RPC_URL) \
		--private-key $(ANVIL_PRIVATE_KEY) \
		--broadcast -vvvv
else
	@forge script script/interactions/RelayerInteractions.s.sol:AddMoreSkill \
		--rpc-url $($(shell echo $(NETWORK) | tr a-z A-Z)_RPC_URL) \
		--account burner \
		--sender $(BURNER_ADDRESS) \
		--broadcast -vvvv
endif

transfer-bonus-from-VSkillUser-to-Verifier-contract: check-network-config
ifeq ($(NETWORK),anvil)
	@forge script script/interactions/RelayerInteractions.s.sol:TransferBonusFromVSkillUserToVerifierContract \
		--rpc-url $(ANVIL_RPC_URL) \
		--private-key $(ANVIL_PRIVATE_KEY) \
		--broadcast -vvvv
else
	@forge script script/interactions/RelayerInteractions.s.sol:TransferBonusFromVSkillUserToVerifierContract \
		--rpc-url $($(shell echo $(NETWORK) | tr a-z A-Z)_RPC_URL) \
		--account burner \
		--sender $(BURNER_ADDRESS) \
		--broadcast -vvvv
endif

# Handle unknown arguments
%:
	@:

##############################   Audit   ##############################

slither:
	@slither . --config-file ./slither.config.json --skip-assembly

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