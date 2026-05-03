# Setup Guide

## Prerequisites

| Tool | Minimum version | Install |
|---|---|---|
| [Foundry](https://book.getfoundry.sh/) | ≥ 0.2 | `curl -L https://foundry.paradigm.xyz \| bash && foundryup` |
| Git | any | system package manager |

No Node.js, Python, or Docker is required. The project is pure Solidity + Foundry.

Confirm your Foundry installation:

```bash
forge --version
cast --version
anvil --version
```

---

## Clone and Install

```bash
git clone https://github.com/your-org/ys-contracts
cd ys-contracts

# Install library dependencies (forge-std, openzeppelin-contracts)
forge install
```

Foundry uses git submodules for dependencies. If `forge install` exits without error but `lib/` is empty, initialise submodules manually:

```bash
git submodule update --init --recursive
```

---

## Build

```bash
forge build
```

This compiles `src/` with Solidity 0.8.30 (pinned in `foundry.toml`). Build artifacts go to `out/`. A clean build with no warnings is expected.

```bash
make clean && forge build   # full clean rebuild
```

---

## Environment Variables

All runtime configuration — RPC endpoints, private keys, token addresses — is read from a `.env` file. Copy the template and fill in what you need:

```bash
cp .env.example .env
```

The Makefile includes `.env` automatically. For `forge` commands run directly, source it first:

```bash
source .env
```

### Variable reference

| Variable | Purpose | Required for |
|---|---|---|
| `PRIVATE_KEY` | Signing key for Anvil transactions | Local deployment only |
| `DEPLOYER_PRIVATE_KEY` | Signing key for testnet/mainnet | Testnet + mainnet deploy |
| `TREASURY` | Fee recipient address | Any deployment |
| `FEE_RATE_BPS` | Protocol fee in basis points (default: `500`) | Any deployment |
| `ETHERSCAN_API_KEY` | Block explorer API key | Contract verification |
| `SEPOLIA_RPC_URL` | Sepolia JSON-RPC endpoint | Sepolia deploy + fork tests |
| `BASE_SEPOLIA_RPC_URL` | Base Sepolia JSON-RPC endpoint | Base Sepolia deploy + fork tests |
| `SEPOLIA_USDC` | USDC address on Sepolia | Sepolia deployment |
| `SEPOLIA_AUSDC` | aUSDC address on Sepolia | Sepolia deployment |
| `SEPOLIA_AAVE_POOL` | Aave V3 Pool address on Sepolia | Sepolia deployment |
| `BASE_SEPOLIA_USDC` | USDC address on Base Sepolia | Base Sepolia deployment |
| `BASE_SEPOLIA_AUSDC` | aUSDC address on Base Sepolia | Base Sepolia deployment |
| `BASE_SEPOLIA_AAVE_POOL` | Aave V3 Pool address on Base Sepolia | Base Sepolia deployment |

**Minimum for running tests:** none — the standard test suite uses mock contracts and requires no RPC.

**Minimum for fork tests:** `BASE_SEPOLIA_RPC_URL` (fork tests skip gracefully if unset).

---

## Local Development with Anvil

Anvil is Foundry's local EVM node. Use it to iterate quickly without spending testnet gas.

```bash
# Terminal 1 — start Anvil
make anvil
# or: anvil

# Anvil prints 10 funded accounts and their private keys.
# Use account 0 as your PRIVATE_KEY in .env:
# PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

# Terminal 2 — deploy to Anvil
make deploy NETWORK=anvil
```

The deployed vault address is printed to stdout and written to `deployments/anvil.json`.

### Interacting with Anvil via cast

```bash
VAULT=<address from deploy output>
RPC=http://127.0.0.1:8545

# Read vault state
cast call $VAULT "getVaultBalance()(uint256)" --rpc-url $RPC

# Send a transaction
cast send $VAULT "deposit(uint256)" 1000000000 \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC
```

---

## IDE Setup

### VS Code

Install the [Hardhat Solidity](https://marketplace.visualstudio.com/items?itemName=NomicFoundation.hardhat-solidity) extension or [solidity](https://marketplace.visualstudio.com/items?itemName=JuanBlanco.solidity) extension for syntax highlighting and inline diagnostics.

Configure remappings so the IDE resolves imports correctly. Both extensions read `remappings.txt` automatically.

### Other editors

Any editor with a Language Server Protocol client can use [solc-select](https://github.com/crytic/solc-select) + a Solidity language server. The `remappings.txt` at the repo root tells the LSP how to resolve `forge-std/` and `openzeppelin-contracts/` imports.

---

## Updating Dependencies

Dependencies are pinned as git submodules in `lib/`. To update to the latest compatible versions:

```bash
forge update                           # update all
forge update lib/openzeppelin-contracts  # update one
```

After updating, rebuild and rerun tests to confirm compatibility:

```bash
forge build && forge test
```

Commit the updated submodule hashes and the `foundry.lock` file together.
