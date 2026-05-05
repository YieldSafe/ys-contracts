# YieldSave Contracts

Non-custodial USDC savings vault that automatically routes deposits into Aave V3 to earn yield.

Users deposit USDC, receive vault shares, and withdraw principal plus net yield at any time. A protocol fee (default 5%) is taken only from yield — principal is mathematically protected.

## Deployments

| Network | Address | Explorer |
|---|---|---|
| Sepolia | `0x6C2Df464b38e92Ec8d01f8BEaF621f1ad894C107` | [Etherscan](https://sepolia.etherscan.io/address/0x6C2Df464b38e92Ec8d01f8BEaF621f1ad894C107) |
| Base Sepolia | `0xC0aAd48188dabF8d5B33e30A0946d79d5C8F6323` | [Blockscout](https://base-sepolia.blockscout.com/address/0xC0aAd48188dabF8d5B33e30A0946d79d5C8F6323) |

## Quick Start

**Prerequisites:** [Foundry](https://book.getfoundry.sh/getting-started/installation) ≥ 0.2

```bash
git clone https://github.com/your-org/ys-contracts
cd ys-contracts
forge install
forge build
forge test
```

All unit and scenario tests run against mock contracts with no RPC required. See the [Developer Guide](docs/developer-guide.md) for fork tests and environment setup.

## Documentation

| Document | Purpose |
|---|---|
| [Technical Specification](SPEC.md) | Complete canonical reference: architecture, storage layout, security model, risks |
| [Contract Reference](docs/contracts.md) | Per-contract: purpose, state, functions, logic flow, events, reverts, interaction diagrams |
| [Developer Guide](docs/developer-guide.md) | Orientation, common workflows, code conventions |
| [Setup](docs/setup.md) | Prerequisites, installation, environment variables, Anvil workflow |
| [Architecture](docs/architecture.md) | Contract design, share model, fee math, invariants, security model |
| [Testing](docs/testing.md) | Test suite structure, running tests, writing new tests |
| [Deployment](docs/deployment.md) | Deploying to each network, verification, post-deploy checklist |
| [Reference](docs/reference.md) | Full ABI, function signatures, events, errors, `cast` one-liners |
| [Troubleshooting](docs/troubleshooting.md) | Common errors and how to fix them |
| [FAQ](docs/faq.md) | Frequently asked developer questions |
| [Maintenance](docs/maintenance.md) | Monitoring, fee collection, incident response, re-deployment |
| [User Guide](guide.md) | End-user product documentation |
| [Contributing](CONTRIBUTING.md) | Contribution workflow and standards |

## Tech Stack

| Layer | Technology |
|---|---|
| Smart contracts | Solidity 0.8.30 |
| Toolchain | Foundry (forge, cast, anvil) |
| Access control utility | OpenZeppelin `ReentrancyGuard` |
| Yield source | Aave V3 (USDC → aUSDC) |
| Testing | Forge unit tests, scenario tests, mock contracts, fork tests |

## Repository Layout

```
src/
  YieldSaveVault.sol        Main vault contract
  interfaces/
    IERC20.sol              Minimal ERC-20 interface
    IPool.sol               Aave V3 Pool interface

test/
  YieldSaveVault.t.sol      Core unit + fork tests
  helpers/                  Shared fixtures and fork utilities
  scenarios/                Focused scenario tests (deposit, withdraw, fee, share math)
  mocks/                    MockERC20, MockAavePool
  fork/                     Real-chain integration tests (Base Sepolia)

script/
  Deploy.s.sol              Deployment script (all networks)
  VerifyAddresses.s.sol     Address sanity-check utility

deployments/                JSON records written at deploy time
docs/                       Developer documentation
```

## License

MIT
