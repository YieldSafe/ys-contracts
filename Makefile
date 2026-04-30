#######################################
#        FOUNDry PRO MAKEFILE        #
#######################################

.DEFAULT_GOAL := help

#######################################
#            CONFIGURATION            #
#######################################

include .env

NETWORK ?= anvil
SCRIPT ?= script/Deploy.s.sol:Deploy
CONTRACT ?= src/YieldSaveVault.sol:YieldSaveVault

ANVIL_RPC_URL        = http://127.0.0.1:8545
SEPOLIA_RPC_URL      ?= $(SEPOLIA_RPC_URL)
MAINNET_RPC_URL      ?= $(MAINNET_RPC_URL)
BASE_SEPOLIA_RPC_URL ?= $(BASE_SEPOLIA_RPC_URL)

ETH_CHAIN_ID         = 11155111
MAINNET_CHAIN_ID     = 1
BASE_SEPOLIA_CHAIN_ID = 84532

#######################################
#              HELP MENU              #
#######################################

help:
	@echo ""
	@echo "========== Foundry Makefile =========="
	@echo ""
	@echo "make build                     - Compile contracts"
	@echo "make test                      - Run tests"
	@echo "make test-verbose              - Run tests with verbosity"
	@echo "make coverage                  - Run coverage"
	@echo "make gas                       - Generate gas snapshot"
	@echo "make clean                     - Clean artifacts"
	@echo "make format                    - Format solidity"
	@echo ""
	@echo "make anvil                     - Start local anvil node"
	@echo ""
	@echo "make deploy NETWORK=anvil"
	@echo "make deploy NETWORK=sepolia"
	@echo "make deploy NETWORK=mainnet"
	@echo "make deploy NETWORK=base-sepolia"
	@echo ""
	@echo "make verify NETWORK=sepolia ADDRESS=0x..."
	@echo "make verify NETWORK=mainnet ADDRESS=0x..."
	@echo "make verify NETWORK=base-sepolia ADDRESS=0x..."
	@echo ""
	@echo "======================================="
	@echo ""

#######################################
#         BASIC DEVELOPMENT           #
#######################################

.PHONY: build test test-verbose coverage gas clean format deploy verify fork-test anvil

build:
	forge build

test:
	forge test

test-verbose:
	forge test -vvvv

coverage:
	forge coverage

gas:
	forge snapshot

format:
	forge fmt

clean:
	forge clean

#######################################
#         LOCAL DEVELOPMENT           #
#######################################

anvil:
	anvil

#######################################
#         DEPLOYMENT LOGIC            #
#######################################

deploy:
ifeq ($(NETWORK),anvil)
	forge script $(SCRIPT) \
		--rpc-url $(ANVIL_RPC_URL) \
		--private-key $(PRIVATE_KEY) \
		--broadcast
endif

ifeq ($(NETWORK),sepolia)
	forge script $(SCRIPT) \
		--rpc-url $(SEPOLIA_RPC_URL) \
		--private-key $(PRIVATE_KEY) \
		--broadcast \
		--verify \
		--etherscan-api-key $(ETHERSCAN_API_KEY)
endif

ifeq ($(NETWORK),mainnet)
	forge script $(SCRIPT) \
		--rpc-url $(MAINNET_RPC_URL) \
		--private-key $(PRIVATE_KEY) \
		--broadcast \
		--verify \
		--etherscan-api-key $(ETHERSCAN_API_KEY)
endif

ifeq ($(NETWORK),base-sepolia)
	forge script $(SCRIPT) \
		--rpc-url $(BASE_SEPOLIA_RPC_URL) \
		--private-key $(PRIVATE_KEY) \
		--broadcast \
		--verify \
		--verifier blockscout \
		--verifier-url https://base-sepolia.blockscout.com/api/ \
		--etherscan-api-key $(ETHERSCAN_API_KEY)
endif

#######################################
#         CONTRACT VERIFICATION       #
#######################################

verify:
ifeq ($(NETWORK),sepolia)
	forge verify-contract \
		--chain-id $(ETH_CHAIN_ID) \
		--etherscan-api-key $(ETHERSCAN_API_KEY) \
		$(ADDRESS) \
		$(CONTRACT)
endif

ifeq ($(NETWORK),mainnet)
	forge verify-contract \
		--chain-id $(MAINNET_CHAIN_ID) \
		--etherscan-api-key $(ETHERSCAN_API_KEY) \
		$(ADDRESS) \
		$(CONTRACT)
endif

ifeq ($(NETWORK),base-sepolia)
	forge verify-contract \
		--chain-id $(BASE_SEPOLIA_CHAIN_ID) \
		--verifier blockscout \
		--verifier-url https://base-sepolia.blockscout.com/api/ \
		--etherscan-api-key $(ETHERSCAN_API_KEY) \
		$(ADDRESS) \
		$(CONTRACT)
endif

#######################################
#            FORK TESTING             #
#######################################

fork-test:
	forge test --fork-url $(SEPOLIA_RPC_URL)

fork-base:
	forge test --fork-url $(BASE_SEPOLIA_RPC_URL)