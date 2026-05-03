# YieldSave Technical Specification

**Version:** 1.0  
**Contract:** `YieldSaveVault`  
**Solidity:** 0.8.30  
**Last updated:** 2026-05-03

This document is the single authoritative technical reference for the YieldSave protocol. It is intended for auditors, integration engineers, and engineers joining the project. It supersedes scattered information in other docs for the topics it covers.

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Blockchain Network](#2-blockchain-network)
3. [Token Standards](#3-token-standards)
4. [Technology Stack](#4-technology-stack)
5. [Repository Structure](#5-repository-structure)
6. [Contract Architecture](#6-contract-architecture)
7. [Detailed Contract Reference](#7-detailed-contract-reference)
8. [Storage Layout](#8-storage-layout)
9. [Security & Access Control Model](#9-security--access-control-model)
10. [Event Documentation](#10-event-documentation)
11. [Deployment Guide](#11-deployment-guide)
12. [Testing Guide](#12-testing-guide)
13. [Known Risks & Assumptions](#13-known-risks--assumptions)

---

## 1. Project Overview

YieldSave is a non-custodial savings protocol that allows any wallet holder to earn yield on USDC without taking custody or requiring any off-chain infrastructure. Users deposit USDC into a single smart contract vault. The vault supplies that USDC to Aave V3, which pays a variable interest rate in the form of rebasing aUSDC tokens. Users earn yield proportional to their share of the vault. When they withdraw, they receive their original principal plus net yield, with a protocol fee deducted only from the yield portion.

### Core guarantees

1. **Principal protection.** The protocol fee is mathematically bounded to the yield portion. A user who earns zero yield pays zero fee. A user's principal is always returned in full.
2. **Non-custodial.** No address — including the deployer — can withdraw user funds. Users can recover funds at any time by calling `withdraw` directly on-chain.
3. **Immutable parameters.** All protocol configuration (fee rate, treasury, token addresses) is set at construction and cannot be changed.
4. **Permissionless.** Any wallet with USDC can deposit or withdraw. No KYC, whitelist, or minimum balance.

### What YieldSave is not

- It is not a lending protocol.
- It is not a yield aggregator (no strategy selection; Aave V3 is the sole yield source).
- It is not an ERC-4626 vault (shares are not transferable ERC-20 tokens in this version).
- It is not upgradeable.

---

## 2. Blockchain Network

### EVM compatibility

YieldSave is deployed on EVM-compatible networks. It requires Aave V3 to be available on the target network, as the vault calls `IPool.supply` and `IPool.withdraw` directly. No cross-chain messaging or bridge infrastructure is used.

### Deployed networks

| Network | Chain ID | Type | Vault Address | Block |
|---|---|---|---|---|
| Ethereum Sepolia | 11155111 | Testnet | `0x6C2Df464b38e92Ec8d01f8BEaF621f1ad894C107` | 10,759,020 |
| Base Sepolia | 84532 | Testnet | `0xC0aAd48188dabF8d5B33e30A0946d79d5C8F6323` | 40,872,728 |
| Base Mainnet | 8453 | Mainnet | Not yet deployed | — |

### Aave V3 addresses (Base Sepolia)

These are the canonical addresses used by the Base Sepolia deployment and the fork test suite.

| Contract | Address |
|---|---|
| USDC | `0xba50Cd2A20f6DA35D788639E581bca8d0B5d4D5f` |
| aUSDC | `0x10F1A9D11CDf50041f3f8cB7191CBE2f31750ACC` |
| Aave V3 Pool | `0x8bAB6d1b75f19e9eD9fCe8b9BD338844fF79aE27` |

### Network selection in deployment script

The deployment script (`script/Deploy.s.sol`) detects the target network from `block.chainid` at runtime and loads the corresponding Aave addresses from environment variables. Adding support for a new network requires adding a `chainId` branch to `_loadNetworkConfig`.

---

## 3. Token Standards

### 3.1 USDC — Deposit and withdrawal token

| Property | Value |
|---|---|
| Standard | ERC-20 |
| Issuer | Circle Internet Financial |
| Decimals | 6 |
| Symbol | USDC |
| Behaviour | Standard ERC-20; Circle retains blacklist authority |

USDC is the only accepted deposit asset. The vault has no logic for any other token. All `amount` parameters are denominated in USDC units (6 decimal places): `1 USDC = 1_000_000`.

**Non-standard behaviour to be aware of:** Some older USDC deployments do not return a `bool` from `transfer` and `approve`. The vault uses a low-level call pattern (`_safeTransfer`, `_safeTransferFrom`, `_forceApprove`) that handles both conforming and non-conforming ERC-20 implementations.

### 3.2 aUSDC — Yield-bearing wrapper (Aave)

| Property | Value |
|---|---|
| Standard | ERC-20 (Aave AToken) |
| Issuer | Aave V3 Protocol |
| Decimals | 6 (matches underlying USDC) |
| Symbol | aUSDC |
| Behaviour | Rebasing — balance grows every block to reflect accrued interest |

The vault receives aUSDC when it calls `aavePool.supply`. The vault does not interact with aUSDC directly; it reads `aUsdc.balanceOf(address(this))` to determine total assets and calls `aavePool.withdraw` to redeem aUSDC back to USDC. The rebasing nature of aUSDC is how yield is distributed: as the aUSDC balance of the vault grows without any minting event, the share price increases.

### 3.3 Vault shares — Internal accounting unit

| Property | Value |
|---|---|
| Standard | None — internal mapping, not transferable |
| Decimals | 6 (matches USDC on first deposit; preserved thereafter) |
| Symbol | None |
| Behaviour | Non-transferable; tracked in `userShares[address]` mapping |

Vault shares are not ERC-20 tokens. They cannot be transferred, traded, or used as collateral in other protocols. This is a deliberate design choice for the MVP to reduce audit surface and eliminate composability risks. ERC-4626 share tokens are planned for a future version.

**Relationship to ERC-4626:** The vault adopts ERC-4626 naming conventions (`deposit`, `withdraw`, `previewDeposit`, `previewWithdraw`) and the proportional share model, but does not implement the full ERC-4626 interface. Specifically: no `ERC20` methods on shares, no `mint`/`redeem` entry points, no `asset()` function, no `totalAssets()` public function, no `convertToShares`/`convertToAssets` functions.

---

## 4. Technology Stack

### Solidity

| Property | Value |
|---|---|
| Version | 0.8.30 (pinned via `foundry.toml: solc = "0.8.30"`) |
| Pragma | `^0.8.30` |
| Optimiser | Enabled, 200 runs |
| ABI coder | Default (v2) |

Solidity 0.8.x provides built-in overflow/underflow protection (checked arithmetic by default). Custom errors (introduced in 0.8.4) are used throughout for gas-efficient reverts.

### Framework

| Tool | Version | Purpose |
|---|---|---|
| Foundry (forge) | latest stable | Compile, test, script, deploy |
| Foundry (cast) | latest stable | On-chain reads, transaction inspection |
| Foundry (anvil) | latest stable | Local EVM node |

### Dependencies

| Library | Version | Import path | Usage |
|---|---|---|---|
| OpenZeppelin Contracts | v5.6.1 | `openzeppelin-contracts/` | `ReentrancyGuard` |
| forge-std | v1.16.0 | `forge-std/` | Test base contracts, cheatcodes, `console2` |

No other dependencies. In particular: no Hardhat, no Node.js, no Truffle, no OpenZeppelin upgrades, no Chainlink, no OpenZeppelin SafeERC20 (the vault uses its own low-level wrappers).

---

## 5. Repository Structure

```
ys-contracts/
│
├── src/                                   Smart contract source
│   ├── YieldSaveVault.sol                 Main vault contract (180 lines)
│   └── interfaces/
│       ├── IERC20.sol                     Minimal ERC-20 interface
│       └── IPool.sol                      Aave V3 Pool interface
│
├── test/                                  Foundry test suite
│   ├── YieldSaveVault.t.sol               Core unit tests (12 tests)
│   ├── helpers/
│   │   ├── AaveFork.sol                   Base class: deploys MockERC20 + MockAavePool
│   │   ├── Fixtures.sol                   Base class: deploys vault, pre-funds users
│   │   └── BaseSepoliaFork.sol            Base class: forks Base Sepolia, wires real Aave
│   ├── scenarios/
│   │   ├── Deposit.t.sol                  Deposit flows (4 tests)
│   │   ├── Withdraw.t.sol                 Withdrawal flows (4 tests)
│   │   ├── Fee.t.sol                      Fee mechanics (3 tests)
│   │   └── ShareMath.t.sol               Share price math (3 tests)
│   ├── mocks/
│   │   ├── MockERC20.sol                  Minimal ERC-20 with mint/burn
│   │   └── MockAavePool.sol              Deterministic mock: supply, withdraw, accrueYield
│   └── fork/
│       └── BaseSepoliaIntegration.t.sol   Real Aave V3 integration tests (3 tests)
│
├── script/
│   ├── Deploy.s.sol                       Deployment script (all networks)
│   └── VerifyAddresses.s.sol             Address sanity check utility
│
├── deployments/
│   ├── sepolia.json                       Deployment record: Sepolia
│   ├── base-sepolia.json                  Deployment record: Base Sepolia
│   └── base.json                          Deployment record: Base Mainnet (empty)
│
├── docs/                                  Developer documentation
│   ├── architecture.md
│   ├── deployment.md
│   ├── developer-guide.md
│   ├── faq.md
│   ├── maintenance.md
│   ├── reference.md
│   ├── setup.md
│   ├── testing.md
│   └── troubleshooting.md
│
├── lib/                                   Git submodule dependencies
│   ├── forge-std/                         Foundry standard library (v1.16.0)
│   └── openzeppelin-contracts/            OpenZeppelin (v5.6.1)
│
├── SPEC.md                                This document
├── README.md                              Project overview and quick start
├── CONTRIBUTING.md                        Contribution guidelines
├── guide.md                               End-user product documentation
├── foundry.toml                           Foundry configuration
├── foundry.lock                           Dependency version lock
├── remappings.txt                         Solidity import path aliases
├── Makefile                               Build and deployment automation
└── .env.example                           Environment variable template
```

### Key file responsibilities

| File | Responsibility |
|---|---|
| `src/YieldSaveVault.sol` | All protocol logic: deposits, withdrawals, share accounting, fee calculation |
| `src/interfaces/IPool.sol` | Aave V3 interface — only `supply` and `withdraw` are needed |
| `src/interfaces/IERC20.sol` | Minimal ERC-20 — only the 4 functions the vault calls |
| `script/Deploy.s.sol` | Network-aware deployment: detects chain, loads addresses, writes record |
| `deployments/*.json` | Authoritative on-chain addresses per network — read by frontends |
| `test/helpers/Fixtures.sol` | Single source of truth for test setup shared across all scenario tests |

---

## 6. Contract Architecture

### 6.1 System overview

```
                         ┌──────────────────────────────────────────┐
                         │             User Wallet                   │
                         │                                           │
                         │  1. approve(vault, amount)                │
                         │  2. deposit(amount)  ─────────────────►  │
                         │  ◄───────────── withdraw(shares)  3.      │
                         └──────────────────────────────────────────┘
                                      │ deposit / withdraw
                         ┌────────────▼─────────────────────────────┐
                         │          YieldSaveVault                   │
                         │                                           │
                         │  State:                                   │
                         │    totalShares           uint256          │
                         │    userShares[addr]      mapping          │
                         │    userDeposits[addr]    mapping          │
                         │                                           │
                         │  Immutables:                              │
                         │    usdc, aUsdc, aavePool, treasury,       │
                         │    feeRate                                │
                         └────────────┬─────────────────────────────┘
                                      │ supply / withdraw
                         ┌────────────▼─────────────────────────────┐
                         │          Aave V3 Pool                     │
                         │                                           │
                         │  USDC ──supply──► aUSDC (held by vault)  │
                         │  aUSDC ─withdraw─► USDC (returned)       │
                         │  aUSDC balance grows every block          │
                         └──────────────────────────────────────────┘
```

**Token flow on deposit:**
1. User approves vault to spend USDC
2. Vault calls `usdc.transferFrom(user, vault, amount)`
3. Vault approves Aave Pool to spend USDC
4. Vault calls `aavePool.supply(usdc, amount, vault, 0)` — aUSDC minted to vault
5. Vault mints shares to user, records principal

**Token flow on withdrawal:**
1. Vault calculates gross USDC owed, principal portion, yield, and fee
2. Vault burns user shares, reduces principal record
3. Vault calls `aavePool.withdraw(usdc, grossAssets, vault)` — USDC returned to vault
4. Vault calls `usdc.transfer(user, payout)` — net payout to user
5. Vault calls `usdc.transfer(treasury, fee)` — fee to treasury (if non-zero)

### 6.2 Share model

Shares represent proportional ownership of the vault's total USDC-denominated assets. `totalAssets` is the live aUSDC balance of the vault, which increases every block as Aave accrues interest.

**First deposit (bootstrapping):**
```
shares = amount
```
This sets the initial share price to exactly 1.0 USDC per share.

**Subsequent deposits:**
```
shares = amount × totalShares / totalAssets
```

Because `totalAssets` grows (via Aave yield) while `totalShares` does not, subsequent depositors receive fewer shares per USDC. Existing shareholders' proportional claim on `totalAssets` remains unchanged — their shares are worth more USDC.

**User's USDC claim at any point:**
```
claim = userShares[user] × totalAssets / totalShares
```

**Share price (implicit):**
```
sharePrice = totalAssets / totalShares
```

Share price is monotonically non-decreasing in normal operation. It increases as Aave accrues yield and is unchanged by deposits or withdrawals (because both change `totalShares` and `totalAssets` in the same proportion).

### 6.3 Fee model

The protocol fee is applied at withdrawal time and only to the yield portion of the withdrawal. Principal is always returned in full.

**Step 1 — Gross assets for the redeemed shares:**
```
grossAssets = shares × totalAssets / totalShares
```

**Step 2 — Principal portion attributable to these shares:**
```
principalPortion = userDeposits[user] × shares / userShares[user]
```

This proportional reduction means partial withdrawals correctly track which fraction of the principal is being redeemed.

**Step 3 — Yield (clamped to zero):**
```
yield = max(0, grossAssets − principalPortion)
```

The clamp ensures that rounding errors or edge cases where `grossAssets < principalPortion` never result in a negative fee or a fee charged against principal.

**Step 4 — Fee:**
```
fee = yield × feeRate / 10_000
```

**Step 5 — Payout:**
```
payout = grossAssets − fee
```

**Worked example** (from `test_FullWithdrawalReturnsPrincipalPlusNetYield`):
- Alice deposits 100 USDC → 100,000,000 shares (1:1)
- Vault earns 10 USDC yield → totalAssets = 110,000,000
- Alice redeems all 100,000,000 shares
- grossAssets = 100,000,000 × 110,000,000 / 100,000,000 = 110,000,000
- principalPortion = 100,000,000 × 100,000,000 / 100,000,000 = 100,000,000
- yield = 110,000,000 − 100,000,000 = 10,000,000
- fee = 10,000,000 × 500 / 10,000 = 500,000
- payout = 110,000,000 − 500,000 = 109,500,000 (109.5 USDC)
- treasury receives 500,000 (0.5 USDC)

### 6.4 Partial withdrawal and principal tracking

When a user makes a partial withdrawal, `userDeposits[user]` is reduced proportionally:
```
userDeposits[user] -= principalPortion
```
where `principalPortion = userDeposits[user] × shares / userShares[user]` at the time of withdrawal.

This means the per-share principal cost basis is preserved across multiple partial withdrawals. A user who withdraws 50% of their shares retains exactly 50% of their recorded principal for future withdrawals.

### 6.5 Design decisions

**Why not implement ERC-4626 fully?**  
ERC-4626 requires shares to implement the full ERC-20 interface (including `transfer`, `approve`, etc.). Adding that requires significant additional code paths, increases the reentrancy attack surface, and adds composability vectors that are inappropriate for an MVP with no audit. Future versions can add ERC-4626 by making shares a separate ERC-20 contract or by adding the token interface to this contract.

**Why are all parameters immutable?**  
Mutable governance parameters (even behind a timelock) require trusting the governance mechanism. For an MVP, immutability provides a stronger and simpler trust guarantee. The deployer cannot extract fees beyond the declared rate or redirect fees to a different address after deployment. Changes require a new contract deployment and user migration.

**Why is there no admin pause function?**  
Pause mechanisms require trusting the pause key holder. An emergency pause by a compromised key is itself an attack vector. The vault defers to Aave's own pool-level pause mechanism for Aave-specific emergencies.

**Why separate `usdc` and `aUsdc` interfaces?**  
Both are ERC-20 tokens but serve different roles. Separating them in the constructor makes the intent explicit and allows the correct address to be verified independently. Using a single token variable would obscure which token is being operated on in each call.

---

## 7. Detailed Contract Reference

### Contract: YieldSaveVault

```
File:     src/YieldSaveVault.sol
Inherits: ReentrancyGuard (OpenZeppelin v5.6.1)
License:  MIT
```

---

### Constructor

```solidity
constructor(
    address usdc_,
    address aUsdc_,
    address aavePool_,
    address treasury_,
    uint256 feeRate_
)
```

Sets all immutable state variables. Reverts if any address is `address(0)` or if `feeRate_` exceeds `MAX_FEE_BPS`.

| Parameter | Validation | Effect |
|---|---|---|
| `usdc_` | `!= address(0)` | Stored as `usdc` |
| `aUsdc_` | `!= address(0)` | Stored as `aUsdc` |
| `aavePool_` | `!= address(0)` | Stored as `aavePool` |
| `treasury_` | `!= address(0)` | Stored as `treasury` |
| `feeRate_` | `<= MAX_FEE_BPS (1000)` | Stored as `feeRate` |

---

### Constants

```solidity
uint256 public constant BPS_DENOMINATOR = 10_000;
uint256 public constant MAX_FEE_BPS     = 1_000;
```

Constants are not stored in contract storage. They are inlined as literals by the compiler.

---

### Immutable variables

```solidity
IERC20  public immutable usdc;
IERC20  public immutable aUsdc;
IPool   public immutable aavePool;
address public immutable treasury;
uint256 public immutable feeRate;
```

Immutables are embedded in the contract's deployed bytecode during construction. They cannot be read from storage — they are loaded directly by the bytecode at execution time. This is more gas-efficient than storage reads.

---

### Public state variables

```solidity
uint256 public totalShares;
mapping(address => uint256) public userShares;
mapping(address => uint256) public userDeposits;
```

| Variable | Type | Unit | Description |
|---|---|---|---|
| `totalShares` | `uint256` | shares (6 dp) | Sum of all outstanding shares across all users |
| `userShares` | `mapping` | shares (6 dp) | Per-user share balance |
| `userDeposits` | `mapping` | USDC (6 dp) | Per-user cumulative principal contributed, adjusted for partial withdrawals |

`totalAssets` is not a stored variable. It is computed on every access as `aUsdc.balanceOf(address(this))`.

---

### External write functions

#### `deposit(uint256 amount) external nonReentrant returns (uint256 shares)`

Transfers `amount` USDC from `msg.sender` to the vault, supplies it to Aave, and mints `shares` to `msg.sender`.

**Pre-conditions:**
- Caller has approved vault to spend at least `amount` USDC
- `amount > 0`
- `_previewDeposit(amount, currentTotalAssets) > 0`

**Execution steps:**
1. Revert with `ZeroAmount` if `amount == 0`
2. Call `_previewDeposit` to calculate shares to mint
3. Revert with `ZeroSharesMinted` if `shares == 0`
4. `_safeTransferFrom(usdc, msg.sender, address(this), amount)`
5. `_forceApprove(usdc, address(aavePool), amount)`
6. `aavePool.supply(address(usdc), amount, address(this), 0)`
7. `userShares[msg.sender] += shares`
8. `userDeposits[msg.sender] += amount`
9. `totalShares += shares`
10. Emit `Deposited(msg.sender, amount, shares)`
11. Return `shares`

**Post-conditions:**
- `aUsdc.balanceOf(address(this))` increased by `amount` (plus any yield accrued in the same block)
- `userShares[msg.sender]` increased by `shares`
- `userDeposits[msg.sender]` increased by `amount`
- `totalShares` increased by `shares`

**Revert conditions:**

| Error | Condition |
|---|---|
| `ZeroAmount` | `amount == 0` |
| `ZeroSharesMinted` | computed `shares == 0` (dust amount with very high share price) |
| `ERC20CallFailed` | `usdc.transferFrom` or `usdc.approve` returns false |

---

#### `withdraw(uint256 shares) external nonReentrant returns (uint256 payout)`

Redeems `shares` from `msg.sender`, withdraws the corresponding USDC from Aave, deducts the protocol fee, and transfers payout to `msg.sender` and fee to `treasury`.

**Pre-conditions:**
- `shares > 0`
- `userShares[msg.sender] >= shares`

**Execution steps:**
1. Revert with `ZeroAmount` if `shares == 0`
2. Load `userShareBalance = userShares[msg.sender]`
3. Revert with `InsufficientShares` if `shares > userShareBalance`
4. Call `_quoteWithdraw` to calculate `grossAssets`, `principalPortion`, `fee`
5. Compute `payout = grossAssets - fee`
6. `userShares[msg.sender] = userShareBalance - shares`
7. `userDeposits[msg.sender] -= principalPortion`
8. `totalShares -= shares`
9. `aavePool.withdraw(address(usdc), grossAssets, address(this))`
10. `_safeTransfer(usdc, msg.sender, payout)`
11. If `fee != 0`: `_safeTransfer(usdc, treasury, fee)`
12. Emit `Withdrawn(msg.sender, shares, grossAssets, fee, payout)`
13. Return `payout`

**Post-conditions:**
- `aUsdc.balanceOf(address(this))` decreased by `grossAssets`
- `userShares[msg.sender]` decreased by `shares`
- `userDeposits[msg.sender]` decreased by `principalPortion`
- `totalShares` decreased by `shares`
- `msg.sender` USDC balance increased by `payout`
- `treasury` USDC balance increased by `fee` (if `fee > 0`)

**Revert conditions:**

| Error | Condition |
|---|---|
| `ZeroAmount` | `shares == 0` |
| `InsufficientShares` | `shares > userShares[msg.sender]` |
| `ERC20CallFailed` | any `usdc.transfer` call returns false |

**Note on state update ordering:** State (`userShares`, `userDeposits`, `totalShares`) is updated before the external Aave and ERC-20 calls (steps 6–8 before step 9). This follows the checks-effects-interactions pattern and is reinforced by `nonReentrant`.

---

### External view functions

#### `getVaultBalance() external view returns (uint256)`

Returns `aUsdc.balanceOf(address(this))`. This is the total USDC-denominated value managed by the vault, including all user deposits and all accrued yield.

#### `getUserBalance(address user) external view returns (uint256)`

Returns the net USDC payout `user` would receive if they withdrew all their shares right now (after the protocol fee on yield). Returns `0` if `userShares[user] == 0`.

Internally calls `_previewWithdrawForUser(user, userShares[user])` and returns `payout`.

#### `previewDeposit(uint256 amount) external view returns (uint256)`

Returns the number of shares that would be minted for a deposit of `amount` at the current share price. Does not modify state. Returns `amount` when the vault is empty (first-deposit 1:1 ratio). Returns `0` when `amount == 0`.

#### `previewWithdraw(uint256 shares) external view returns (uint256)`

Returns the net payout `msg.sender` would receive for redeeming `shares`. Returns `0` if `shares == 0`, `userShares[msg.sender] == 0`, or `shares > userShares[msg.sender]`.

#### `previewWithdrawFor(address user, uint256 shares) external view returns (uint256 payout, uint256 grossAssets, uint256 fee)`

Full withdrawal preview for any `user` and `shares`. Returns all three components:
- `payout` — net USDC sent to user
- `grossAssets` — USDC value of `shares` before fee
- `fee` — protocol fee amount

Returns `(0, 0, 0)` if `shares == 0`, `userShares[user] == 0`, or `shares > userShares[user]`.

---

### Internal functions

#### `_previewDeposit(uint256 amount, uint256 assetsBefore) internal view returns (uint256)`

```
if amount == 0:            return 0
if totalShares == 0 or assetsBefore == 0:  return amount  (first deposit, 1:1)
else:                      return amount * totalShares / assetsBefore
```

`assetsBefore` is passed in (rather than reading `_totalAssets()` again) so that `deposit` can snapshot the balance before the USDC transfer and use that snapshot for share calculation.

#### `_quoteWithdraw(address user, uint256 shares, uint256 assets, uint256 currentTotalShares, uint256 userShareBalance) internal view returns (uint256 grossAssets, uint256 principalPortion, uint256 fee)`

```
grossAssets     = shares * assets / currentTotalShares
principalPortion = userDeposits[user] * shares / userShareBalance
yield           = grossAssets > principalPortion ? grossAssets - principalPortion : 0
fee             = yield * feeRate / BPS_DENOMINATOR
```

#### `_previewWithdrawForUser(address user, uint256 shares) internal view returns (uint256 payout, uint256 grossAssets, uint256 fee)`

Guard-only wrapper around `_quoteWithdraw`. Returns `(0, 0, 0)` if inputs are invalid; otherwise calls `_quoteWithdraw` and computes `payout = grossAssets - fee`.

#### `_totalAssets() internal view returns (uint256)`

Returns `aUsdc.balanceOf(address(this))`. Called on every view and write operation that needs the current vault balance. Never cached.

#### `_safeTransfer(IERC20 token, address to, uint256 amount) internal`

Low-level ERC-20 transfer with return value check. Uses `address(token).call(abi.encodeCall(IERC20.transfer, (to, amount)))`. Reverts with `ERC20CallFailed` if the call fails or returns `false`. Handles tokens that return no data (treats empty return as success, as is conventional).

#### `_safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal`

Same pattern as `_safeTransfer` but for `transferFrom`.

#### `_forceApprove(IERC20 token, address spender, uint256 amount) internal`

Resets allowance to `0` first, then approves `amount`. Both calls use the low-level pattern and revert on failure. The double-step handles ERC-20 implementations that revert if `approve` is called when the existing allowance is non-zero (some older or non-standard tokens). This is a safe, explicit pattern rather than relying on OpenZeppelin's `SafeERC20`.

---

### Custom errors

```solidity
error ZeroAddress();
error ZeroAmount();
error InvalidFeeRate();
error InsufficientShares();
error ZeroSharesMinted();
error ERC20CallFailed();
```

| Error | 4-byte selector | Thrown by | Condition |
|---|---|---|---|
| `ZeroAddress` | `0xd92e233d` | constructor | Any address parameter is `address(0)` |
| `ZeroAmount` | `0x1f2a2005` | `deposit`, `withdraw` | `amount == 0` or `shares == 0` |
| `InvalidFeeRate` | — | constructor | `feeRate_ > MAX_FEE_BPS` |
| `InsufficientShares` | — | `withdraw` | `shares > userShares[msg.sender]` |
| `ZeroSharesMinted` | — | `deposit` | Share calculation rounds to 0 |
| `ERC20CallFailed` | — | `_safeTransfer`, `_safeTransferFrom`, `_forceApprove` | ERC-20 call fails or returns `false` |

Custom errors are more gas-efficient than `require` strings because their ABI encoding is 4 bytes (selector only) rather than a variable-length string.

---

### Interfaces

#### `src/interfaces/IERC20.sol`

Minimal subset of ERC-20. Only the four functions the vault calls are declared:

```solidity
interface IERC20 {
    function transfer(address to, uint256 value) external returns (bool);
    function approve(address spender, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function totalSupply() external view returns (uint256);
}
```

Not used for direct calls — all ERC-20 calls go through the low-level `_safe*` wrappers. The interface is used only for type declarations.

#### `src/interfaces/IPool.sol`

Minimal Aave V3 Pool interface. Only `supply` and `withdraw` are declared:

```solidity
interface IPool {
    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
    function withdraw(address asset, uint256 amount, address to) external returns (uint256);
}
```

---

## 8. Storage Layout

Storage slots are assigned sequentially starting from slot 0. Inherited contracts occupy the lowest slots.

### Inherited storage: ReentrancyGuard (OpenZeppelin v5.6.1)

```
Slot 0: _status (uint256)
```

`_status` holds the reentrancy sentinel. Its values in OZ v5 are:
- `1` (NOT_ENTERED): no reentrant call active
- `2` (ENTERED): a `nonReentrant` function is currently executing

The `nonReentrant` modifier sets `_status = 2` on entry and resets it to `1` on exit. Any reentrant call that attempts to enter another `nonReentrant` function reverts immediately.

### YieldSaveVault own storage

```
Slot 1: totalShares (uint256)
Slot 2: userShares  (mapping(address => uint256))
Slot 3: userDeposits (mapping(address => uint256))
```

### Computing mapping slot keys

For a mapping at slot `n`, the value for key `k` is stored at:
```
keccak256(abi.encode(k, n))
```

| Mapping | Slot | Key type | Value slot formula |
|---|---|---|---|
| `userShares[addr]` | 2 | `address` | `keccak256(abi.encode(addr, 2))` |
| `userDeposits[addr]` | 3 | `address` | `keccak256(abi.encode(addr, 3))` |

### What is NOT in storage

| Variable | Where it lives |
|---|---|
| `usdc`, `aUsdc`, `aavePool`, `treasury`, `feeRate` | Immutables — embedded in deployed bytecode |
| `BPS_DENOMINATOR`, `MAX_FEE_BPS` | Constants — inlined as literals by compiler |
| `totalAssets` | Not stored — computed on every access |

### Full layout table

```
Slot  Type                           Name                Source
────  ─────────────────────────────  ──────────────────  ──────────────────
0     uint256                        _status             ReentrancyGuard
1     uint256                        totalShares         YieldSaveVault
2     mapping(address => uint256)    userShares          YieldSaveVault
3     mapping(address => uint256)    userDeposits        YieldSaveVault
```

### Storage inspection with cast

```bash
VAULT=0xC0aAd48188dabF8d5B33e30A0946d79d5C8F6323
RPC=<rpc url>

# _status (slot 0) — expect 1 (NOT_ENTERED) when idle
cast storage $VAULT 0 --rpc-url $RPC

# totalShares (slot 1)
cast storage $VAULT 1 --rpc-url $RPC

# userShares[addr] — compute key first
USER=0xYourAddress
SLOT=$(cast keccak $(cast abi-encode "f(address,uint256)" $USER 2))
cast storage $VAULT $SLOT --rpc-url $RPC

# userDeposits[addr]
SLOT=$(cast keccak $(cast abi-encode "f(address,uint256)" $USER 3))
cast storage $VAULT $SLOT --rpc-url $RPC
```

---

## 9. Security & Access Control Model

### 9.1 Privilege model

`YieldSaveVault` has **no privileged roles**. There is no `owner`, no `admin`, no `pauser`, no `upgrader`, and no `governance` address. The deployer receives no special access after deployment. The contract has no `Ownable`, `AccessControl`, or similar pattern.

The `treasury` address is the only address that receives any benefit from the protocol (fees), but it has no ability to call any function or modify any state. It is a pure recipient.

| Role | Exists | Address | Capabilities |
|---|---|---|---|
| Owner / Admin | No | — | — |
| Pauser | No | — | — |
| Fee recipient (treasury) | Yes | Set at construction | Receive USDC fees on each withdrawal; no contract functions |
| Upgrader | No | — | — |
| Any user | Yes | Any EOA or contract | Call `deposit` and `withdraw` with their own assets |

### 9.2 Reentrancy protection

Both `deposit` and `withdraw` are marked `nonReentrant` (OpenZeppelin v5 `ReentrancyGuard`). This prevents:

- A malicious ERC-20 token calling back into the vault during `transfer`/`transferFrom`/`approve`
- A malicious Aave pool calling back into the vault during `supply`/`withdraw`

The vault uses checks-effects-interactions ordering in `withdraw`: all state is updated (shares burned, principal reduced, `totalShares` decremented) before any external call (`aavePool.withdraw`, `usdc.transfer`). This means even if `nonReentrant` were removed, the state would be consistent before any external interaction.

In `deposit`, state is updated after the USDC transfer from the user but after the Aave supply. This is acceptable because `_previewDeposit` uses the pre-transfer snapshot of `totalAssets` (preventing share inflation via sandwich attack on the `totalAssets` read).

### 9.3 Input validation

| Check | Location | Error |
|---|---|---|
| All constructor addresses non-zero | `constructor` | `ZeroAddress` |
| Fee rate ≤ 10% | `constructor` | `InvalidFeeRate` |
| Deposit amount > 0 | `deposit` | `ZeroAmount` |
| Deposit mints > 0 shares | `deposit` | `ZeroSharesMinted` |
| Withdraw shares > 0 | `withdraw` | `ZeroAmount` |
| Withdraw shares ≤ user balance | `withdraw` | `InsufficientShares` |

### 9.4 Safe ERC-20 pattern

The vault does not use OpenZeppelin `SafeERC20`. Instead it implements three private low-level wrappers:

- `_safeTransfer` — wraps `transfer`
- `_safeTransferFrom` — wraps `transferFrom`
- `_forceApprove` — resets allowance to 0, then approves

All three use `address(token).call(abi.encodeCall(...))` and check the return value:
- If the call reverts: revert with `ERC20CallFailed`
- If the call returns data: decode as `bool` and revert with `ERC20CallFailed` if false
- If the call returns no data: treat as success (handles void-return tokens like old USDC versions)

`_forceApprove` resets allowance to 0 before setting the new value. This is required for tokens that revert when `approve` is called with a non-zero existing allowance (the USDC implementation has historically had this behaviour in some deployments). The vault always approves exactly `amount` and no more; leftover allowance is not a concern.

### 9.5 Fee cap

The `feeRate` is validated at construction against `MAX_FEE_BPS = 1000` (10%). This is an absolute ceiling. The fee rate cannot be raised after deployment.

Additionally, the fee calculation in `_quoteWithdraw` clamps yield to `max(0, grossAssets - principalPortion)`. This means:
- The fee is always ≤ yield
- The fee is always ≥ 0
- A loss (grossAssets < principalPortion) results in zero fee, not a negative payout
- Principal is always returned in full regardless of rounding

### 9.6 No flash loan surface

The vault does not implement any flash loan interface. There is no `flashLoan`, `flash`, or callback mechanism. The vault's `deposit` and `withdraw` functions are guarded by `nonReentrant`, making flash-loan-style same-transaction manipulation of share price non-viable.

### 9.7 No governance attack surface

There are no governance functions, no timelocks, no multisig requirements, and no proposal mechanisms. There is nothing to attack at the governance layer. Protocol changes require deploying a new contract.

### 9.8 What cannot be done by any address

These actions are impossible by construction:

- Withdrawing user funds without the user's private key
- Changing the fee rate after deployment
- Changing the treasury address after deployment
- Pausing or halting deposits or withdrawals (except via Aave pool-level pause)
- Upgrading or replacing the contract logic
- Recovering "stuck" tokens sent to the vault address by mistake (there is no recovery function)

---

## 10. Event Documentation

### `Deposited`

```solidity
event Deposited(address indexed user, uint256 assets, uint256 shares)
```

Emitted once per successful `deposit` call.

| Parameter | Type | Indexed | Description |
|---|---|---|---|
| `user` | `address` | Yes | Address that called `deposit` and received the shares |
| `assets` | `uint256` | No | USDC amount deposited, in 6-decimal units |
| `shares` | `uint256` | No | Vault shares minted to `user`, in 6-decimal units |

**Topic layout:**
```
topic[0]: keccak256("Deposited(address,uint256,uint256)")
         = 0x5548c837ab068cf56a2c2479df0882a4922fd203edb7517321831d95078c5f62
topic[1]: user address (left-padded to 32 bytes)
data:     abi.encode(assets, shares)
```

**Use cases:**
- Build a deposit history for a user's address
- Track total USDC deposited into the protocol over time
- Verify a deposit transaction on-chain

---

### `Withdrawn`

```solidity
event Withdrawn(
    address indexed user,
    uint256 shares,
    uint256 grossAssets,
    uint256 fee,
    uint256 payout
)
```

Emitted once per successful `withdraw` call.

| Parameter | Type | Indexed | Description |
|---|---|---|---|
| `user` | `address` | Yes | Address that called `withdraw` and received the payout |
| `shares` | `uint256` | No | Number of vault shares redeemed |
| `grossAssets` | `uint256` | No | USDC value of the redeemed shares before fee (6 decimals) |
| `fee` | `uint256` | No | Protocol fee deducted (6 decimals); zero when no yield |
| `payout` | `uint256` | No | Net USDC sent to `user` (`grossAssets − fee`) (6 decimals) |

**Topic layout:**
```
topic[0]: keccak256("Withdrawn(address,uint256,uint256,uint256,uint256)")
         = 0x884edad9ce6fa2440d8a54cc123490eb96d2768479d49ff9c7366125a9424364
topic[1]: user address (left-padded to 32 bytes)
data:     abi.encode(shares, grossAssets, fee, payout)
```

**Use cases:**
- Compute total protocol fees collected: sum `fee` across all `Withdrawn` events
- Compute net yield earned per user: sum `(grossAssets - userDeposits portion)` per address
- Build a complete withdrawal history

**Querying events with cast:**
```bash
cast logs \
  --address $VAULT \
  --event "Deposited(address,uint256,uint256)" \
  --from-block $DEPLOY_BLOCK \
  --to-block latest \
  --rpc-url $RPC

cast logs \
  --address $VAULT \
  --event "Withdrawn(address,uint256,uint256,uint256,uint256)" \
  --from-block $DEPLOY_BLOCK \
  --to-block latest \
  --rpc-url $RPC
```

---

## 11. Deployment Guide

### 11.1 Pre-deployment checklist

Before deploying to any network, verify all of the following:

- [ ] `forge build` completes with zero errors and zero warnings
- [ ] `forge test` passes all tests (including fork tests if targeting a live network)
- [ ] `.env` is populated with the correct values for the target network
- [ ] `TREASURY` is a verified, controlled address — this cannot be changed post-deployment
- [ ] `FEE_RATE_BPS` is confirmed (`500` = 5%; maximum `1000` = 10%)
- [ ] All Aave V3 addresses (USDC, aUSDC, Pool) are verified against the [Aave address book](https://github.com/bgd-labs/aave-address-book)
- [ ] Deployer wallet has sufficient native token (ETH) for gas
- [ ] For mainnet: independent security audit has been completed
- [ ] For mainnet: treasury is a multisig, not a single-key EOA

### 11.2 Environment variables required

| Variable | Deployment target | Notes |
|---|---|---|
| `DEPLOYER_PRIVATE_KEY` | All networks except Anvil | Must hold gas on target chain |
| `PRIVATE_KEY` | Anvil only | Any Anvil default key works |
| `TREASURY` | All | Fee recipient — permanent |
| `FEE_RATE_BPS` | All | Default: `500` if unset |
| `ETHERSCAN_API_KEY` | Sepolia, Mainnet, Base Sepolia | Used for block explorer verification |
| `SEPOLIA_RPC_URL` | Sepolia | HTTPS JSON-RPC endpoint |
| `BASE_SEPOLIA_RPC_URL` | Base Sepolia | HTTPS JSON-RPC endpoint |
| `MAINNET_RPC_URL` | Mainnet | HTTPS JSON-RPC endpoint |
| `SEPOLIA_USDC` | Sepolia | Aave testnet USDC |
| `SEPOLIA_AUSDC` | Sepolia | Aave testnet aUSDC |
| `SEPOLIA_AAVE_POOL` | Sepolia | Aave V3 Pool |
| `BASE_SEPOLIA_USDC` | Base Sepolia | (default: `0xba50Cd2A...`) |
| `BASE_SEPOLIA_AUSDC` | Base Sepolia | (default: `0x10F1A9D1...`) |
| `BASE_SEPOLIA_AAVE_POOL` | Base Sepolia | (default: `0x8bAB6d1b...`) |

### 11.3 Deployment commands

```bash
# Local Anvil
make anvil                        # Terminal 1
make deploy NETWORK=anvil         # Terminal 2

# Sepolia testnet
make deploy NETWORK=sepolia

# Base Sepolia testnet
make deploy NETWORK=base-sepolia

# Mainnet (requires adding chainId 1 to Deploy.s.sol first)
make deploy NETWORK=mainnet
```

The deployment script (`script/Deploy.s.sol`):
1. Reads `DEPLOYER_PRIVATE_KEY`, `TREASURY`, `FEE_RATE_BPS` from environment
2. Calls `_loadNetworkConfig(block.chainid)` to get Aave addresses
3. Broadcasts `new YieldSaveVault(...)` via `vm.startBroadcast`
4. Writes `deployments/{network}.json` with `vault`, `chainId`, `block`

### 11.4 Post-deployment verification

After deployment, run these checks:

```bash
VAULT=<deployed address>
RPC=<rpc url>

# Verify immutable parameters
cast call $VAULT "usdc()(address)"      --rpc-url $RPC
cast call $VAULT "aUsdc()(address)"     --rpc-url $RPC
cast call $VAULT "aavePool()(address)"  --rpc-url $RPC
cast call $VAULT "treasury()(address)"  --rpc-url $RPC
cast call $VAULT "feeRate()(uint256)"   --rpc-url $RPC

# Confirm initial state (should all be 0)
cast call $VAULT "getVaultBalance()(uint256)"  --rpc-url $RPC
cast call $VAULT "totalShares()(uint256)"      --rpc-url $RPC
```

Cross-check all addresses against known Aave V3 addresses for the network. Confirm the `deployments/{network}.json` file matches the on-chain address. Confirm block explorer shows verified source code.

### 11.5 Adding a new network

1. Add Aave V3 contract addresses to `.env.example`
2. Add a `chainId` branch to `_loadNetworkConfig` in `script/Deploy.s.sol`
3. Add an RPC endpoint to `foundry.toml` under `[rpc_endpoints]`
4. Add Makefile targets for `deploy` and `verify` on the new network
5. Add an empty `deployments/{network}.json` placeholder
6. Verify Aave addresses with `forge script script/VerifyAddresses.s.sol --rpc-url <url>`

---

## 12. Testing Guide

### 12.1 Test suite overview

| Layer | Files | Test count | Dependencies |
|---|---|---|---|
| Unit / constructor | `test/YieldSaveVault.t.sol` | 12 | Mock + fork |
| Deposit scenarios | `test/scenarios/Deposit.t.sol` | 4 | Mock only |
| Withdrawal scenarios | `test/scenarios/Withdraw.t.sol` | 4 | Mock only |
| Fee scenarios | `test/scenarios/Fee.t.sol` | 3 | Mock only |
| Share math scenarios | `test/scenarios/ShareMath.t.sol` | 3 | Mock only |
| Fork integration | `test/fork/BaseSepoliaIntegration.t.sol` | 3 | Live RPC |
| **Total** | | **~29** | |

Fuzz tests are configured with 256 runs (`foundry.toml: fuzz.runs = 256`).

### 12.2 Running tests

```bash
# All tests (fork tests skip if BASE_SEPOLIA_RPC_URL is unset)
forge test

# Specific file
forge test --match-path test/scenarios/Fee.t.sol

# Specific function
forge test --match-test test_FullWithdrawalReturnsPrincipalPlusNetYield

# With call traces (essential for debugging failures)
forge test -vvvv

# Fork tests (requires BASE_SEPOLIA_RPC_URL)
make fork-base
```

### 12.3 Mock infrastructure

**MockERC20** (`test/mocks/MockERC20.sol`): Minimal ERC-20 with `mint(address, uint256)` and `burn(address, uint256)`. No restrictions on who can call `mint`/`burn` — this is intentional for test flexibility.

**MockAavePool** (`test/mocks/MockAavePool.sol`): Simulates Aave V3 `supply` and `withdraw` mechanics:
- `supply`: pulls USDC from `onBehalfOf`, mints equal aUSDC to `onBehalfOf`
- `withdraw`: burns aUSDC from caller, transfers USDC to `to`
- `accrueYield(address account, uint256 amount)`: mints aUSDC to `account` and USDC to the pool balance — simulates block-by-block Aave yield accrual

**AaveFork** (`test/helpers/AaveFork.sol`): Abstract base that deploys `MockERC20` (USDC, 6 decimals), `MockERC20` (aUSDC, 6 decimals), and `MockAavePool`. Defines `alice`, `bob`, `treasury` addresses.

**Fixtures** (`test/helpers/Fixtures.sol`): Inherits `AaveFork`, deploys `YieldSaveVault` with fee rate 500 (5%), mints 1,000,000 USDC to `alice` and `bob`, and approves the vault for `type(uint256).max`. Provides `_deposit(user, amount)`, `_withdraw(user, shares)`, `_accrueYield(amount)` helpers.

### 12.4 Coverage targets

All public and external functions must have:
- At least one success-path test
- At least one test for each revert condition
- At least one test for each boundary condition (zero, first deposit, etc.)

All internal helper functions (`_safeTransfer`, `_safeTransferFrom`, `_forceApprove`, `_quoteWithdraw`, `_previewDeposit`) are covered via their callers.

```bash
forge coverage              # line and branch summary
forge coverage --report lcov  # LCOV report for HTML rendering
```

### 12.5 Gas snapshot

```bash
forge snapshot      # regenerates .gas-snapshot
```

The `.gas-snapshot` file is committed to version control and serves as a gas regression check. CI fails if the snapshot diverges without a deliberate regeneration. Regenerate and commit the snapshot whenever a change intentionally affects gas costs.

---

## 13. Known Risks & Assumptions

### 13.1 Protocol assumptions

These are conditions that must hold for the vault to behave correctly. Violating any of them may result in loss of funds or incorrect accounting.

| Assumption | Basis | Risk if violated |
|---|---|---|
| Aave V3 correctly maintains `aUsdc.balanceOf(vault)` as the USDC-equivalent claim | Aave V3 design | Share price corrupted, potential under-payment |
| aUSDC is non-deflationary (balance never decreases without a `withdraw` call) | Aave V3 design | Share price decline; user loss |
| USDC `transfer` and `transferFrom` behave as standard ERC-20 | Circle implementation | Payout failures; stuck funds |
| Aave `withdraw` returns at least `grossAssets` USDC when `aUsdc.balanceOf(vault) >= grossAssets` | Aave V3 design | Withdrawal reverts; user unable to withdraw |
| No Aave governance action silently reduces aUSDC balances below the USDC value of the vault | Aave protocol safety | Loss of user funds |

### 13.2 External protocol risks

**Aave V3 smart contract risk**  
The vault's assets are held inside Aave V3. An exploit, bug, or governance manipulation in Aave V3 could result in partial or total loss of funds. Aave V3 has been live since 2020, has undergone multiple security audits, and holds billions in TVL — but past performance is not a guarantee of future safety.

**Aave liquidity risk**  
When Aave's pool utilisation is 100% (all deposited USDC is borrowed), `aavePool.withdraw` reverts. Withdrawals from the vault are temporarily blocked until utilisation decreases. The vault has no mechanism to force liquidity — users must wait. This is an inherent property of Aave's lending model, not a bug in the vault.

**aUSDC accounting correctness**  
The vault relies entirely on `aUsdc.balanceOf(address(this))` as the source of truth for total assets. If Aave introduces a bug that causes this value to be incorrect (e.g., a precision error in the yield accrual mechanism), share prices and payouts will be wrong.

### 13.3 Token risks

**USDC blacklisting**  
Circle can blacklist any address at the USDC contract level. If the vault address is blacklisted, all deposits and withdrawals will fail permanently. If a user's address is blacklisted, their withdrawal will fail. There is no mitigation within the vault contract.

**USDC depeg**  
If USDC trades below $1 USD, users' funds are still denominated in USDC — they are not insured against the USD value of their USDC. The vault provides no stablecoin guarantee.

**USDC upgrade**  
Circle has upgraded the USDC contract in the past. A future upgrade that changes `transfer` behaviour could break the vault's ERC-20 interaction. The `_forceApprove` reset-before-approve pattern mitigates one known class of this issue.

### 13.4 Contract-level risks

**No upgradeability**  
If a bug is found in `YieldSaveVault` after deployment, the contract cannot be patched. A new contract must be deployed and users must migrate manually. See [Maintenance — Re-Deployment and Migration](docs/maintenance.md#re-deployment-and-migration).

**Rounding behaviour**  
Integer division in Solidity truncates (rounds down). This affects:
- `deposit`: shares minted may be slightly fewer than the exact mathematical result. The rounding error is in the protocol's favour (vault accumulates fractional USDC).
- `withdraw`: gross assets may be slightly fewer than the exact value. This is also in the protocol's favour.
- `_quoteWithdraw`: `principalPortion` rounds down, which slightly inflates the yield and thus the fee. The effect is negligible in practice (sub-unit rounding at 6 decimal places).

Critically, `ZeroSharesMinted` protects against the edge case where `amount * totalShares / totalAssets` rounds to exactly 0 (only possible with very large share prices from accumulated yield and very small deposit amounts).

**Principal tracking correctness**  
`userDeposits` tracks each user's principal for the purpose of fee calculation. If a user makes many partial withdrawals, each one reduces `userDeposits` proportionally. Rounding in this reduction accumulates over many withdrawals, slightly under-recording the principal. This results in a marginally higher fee on future withdrawals — the rounding error is in the protocol's favour.

**First depositor share price manipulation**  
An attacker could theoretically inflate the share price by depositing a small amount and then donating aUSDC directly to the vault (not via `deposit`). This would make the initial share price very high and cause subsequent depositors' shares to round to 0, triggering `ZeroSharesMinted`. This is a known share price inflation attack vector. The current mitigation is `ZeroSharesMinted` (which prevents the victim from depositing at all, rather than silently stealing their funds). Future mitigation options include virtual shares or minimum deposit sizes.

### 13.5 Operational risks

**Treasury key compromise**  
The treasury address receives protocol fees. If the treasury private key is compromised, the attacker gains access only to future fee payments — they cannot access user funds. Using a multisig treasury mitigates this.

**Deployer key reuse**  
The deployer key is only needed during deployment. After deployment, the key has no special powers. Nevertheless, best practice is to use a dedicated deployment key and not reuse it for operational transactions.

**No emergency stop**  
There is no admin pause function. In the event of a critical vulnerability, the options are: (1) communicate to users to withdraw immediately, (2) contact Aave to pause the relevant pool if the issue is Aave-related, (3) deploy a fixed contract and update frontend pointing to it. There is no in-contract emergency mechanism.

### 13.6 Audit status

As of the date of this document, `YieldSaveVault` has not undergone a formal third-party security audit. **Deployment to mainnet should not proceed without an independent audit.** The test suite provides confidence in functional correctness but does not replace a security audit.
