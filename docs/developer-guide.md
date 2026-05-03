# Developer Guide

This page is the starting point for engineers working on this codebase. It links to the topic-specific docs below.

## Orientation

YieldSave is a single Solidity contract (`YieldSaveVault`) that accepts USDC deposits, supplies them to Aave V3, tracks shares per user, and distributes yield implicitly via share price appreciation. The codebase is pure Foundry — no Node.js tooling is involved.

Read these first:

| Document | What it covers |
|---|---|
| [Architecture](architecture.md) | Contract design, share model math, fee model, invariants, security model |
| [Setup](setup.md) | Prerequisites, installation, environment variables, local Anvil workflow |
| [Testing](testing.md) | Test suite structure, running tests, writing new tests, mock setup |
| [Deployment](deployment.md) | Deploying to each network, verification, post-deploy checklist |
| [Contract Reference](contracts.md) | Per-contract: purpose, state, functions, logic flow, events, reverts, interaction diagrams |
| [Reference](reference.md) | Full ABI, function signatures, events, errors, `cast` one-liners |
| [Troubleshooting](troubleshooting.md) | Common errors and how to fix them |
| [FAQ](faq.md) | Frequently asked developer questions |

## Common Workflows

### Run the test suite

```bash
forge test          # all unit + scenario tests (no RPC needed)
forge test -vvvv    # with full call traces
make fork-base      # fork tests against real Aave V3 (requires BASE_SEPOLIA_RPC_URL)
```

### Start local development

```bash
# Terminal 1
anvil

# Terminal 2
make deploy NETWORK=anvil
```

### Format and check

```bash
make format         # format Solidity
forge test          # confirm tests still pass
```

### Deploy to testnet

```bash
# 1. Fill in .env (see docs/setup.md for required variables)
# 2. Run
make deploy NETWORK=base-sepolia
```

## Code Conventions

| Element | Convention | Example |
|---|---|---|
| Internal functions | `_camelCase` prefix | `_totalAssets()`, `_safeTransfer()` |
| Public/external functions | `camelCase` | `deposit()`, `getUserBalance()` |
| Constants | `SCREAMING_SNAKE_CASE` | `BPS_DENOMINATOR`, `MAX_FEE_BPS` |
| Custom errors | `PascalCase` | `ZeroAmount`, `InsufficientShares` |
| Events | `PascalCase` | `Deposited`, `Withdrawn` |
| Test functions | `test_PascalCaseDescription` | `test_FeeOnlyAppliesToYield` |

Comments explain *why*, not *what*. Solidity version is pinned at `0.8.30` — do not widen the pragma.
