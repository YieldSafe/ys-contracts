# Contract Reference

Complete per-contract documentation for every Solidity file in the repository.

---

## Table of Contents

**Production**
- [IERC20](#ierc20--srcinterfacesierc20sol)
- [IPool](#ipool--srcinterfacesipoolsol)
- [YieldSaveVault](#yieldsavevault--srcyieldsavevaultsol)

**Test infrastructure**
- [MockERC20](#mockerc20--testmocksmockerc20sol)
- [MockAavePool](#mockaavepool--testmocksmockaavepoolsol)
- [AaveFork](#aavefork--testhelpersaaveforksol)
- [Fixtures](#fixtures--testhelpersfixtressol)
- [BaseSepoliaFork](#basesepoliafork--testhelpersbasesepoliaforksol)

**Test suites**
- [YieldSaveVaultTest](#yieldsavevaulttest--testyieldsavevaulttsol)
- [DepositScenariosTest](#depositscenariosttest--testscenariosdeposittest)
- [WithdrawScenariosTest](#withdrawscenariostest--testscenarioswithdrawttest)
- [FeeScenariosTest](#feescenariostest--testscenariosfeettest)
- [ShareMathScenariosTest](#sharemathscenariostest--testscenariossharemath-ttestsol)

**Deployment scripts**
- [Deploy](#deploy--scriptdeploysstol)
- [VerifyAddresses](#verifyaddresses--scriptverifyaddressesssol)

---

## System Interaction Overview

The diagram below shows every contract in the repository, the direction of calls at runtime, and the boundaries between production code, test infrastructure, and deployment scripts.

```
╔══════════════════════════════════════════════════════════════════════╗
║  PRODUCTION (src/)                                                   ║
║                                                                      ║
║   ┌─────────────────────────────────────────────────────────────┐   ║
║   │                    YieldSaveVault                           │   ║
║   │                                                             │   ║
║   │  implements:                                                │   ║
║   │    ReentrancyGuard (OZ v5)                                  │   ║
║   │                                                             │   ║
║   │  uses interfaces:                                           │   ║
║   │    IERC20  ──────────────────────────► USDC (external)      │   ║
║   │    IERC20  ──────────────────────────► aUSDC (external)     │   ║
║   │    IPool   ──────────────────────────► Aave V3 Pool (ext.)  │   ║
║   └─────────────────────────────────────────────────────────────┘   ║
║                                                                      ║
╚══════════════════════════════════════════════════════════════════════╝

╔══════════════════════════════════════════════════════════════════════╗
║  TEST INFRASTRUCTURE (test/)                                         ║
║                                                                      ║
║   AaveFork ──► MockERC20 (USDC)    MockAavePool                     ║
║       │    ──► MockERC20 (aUSDC) ──► implements IPool               ║
║       │                          └─► owns MockERC20 refs             ║
║       ▼                                                              ║
║   Fixtures ──► YieldSaveVault (deploys with mock addresses)          ║
║       │    ──► _deposit / _withdraw / _accrueYield helpers           ║
║       │                                                              ║
║   BaseSepoliaFork ──► YieldSaveVault (deploys against live Aave)     ║
║       │           ──► real USDC / aUSDC / Aave Pool (forked chain)   ║
║       │                                                              ║
║   Test suites inherit one of:                                        ║
║     Fixtures              → mock-based tests                         ║
║     BaseSepoliaFork       → fork-based tests                         ║
║     Test (forge-std)      → YieldSaveVaultTest (own fork setup)      ║
║                                                                      ║
╚══════════════════════════════════════════════════════════════════════╝

╔══════════════════════════════════════════════════════════════════════╗
║  DEPLOYMENT SCRIPTS (script/)                                        ║
║                                                                      ║
║   Deploy ──────────────► new YieldSaveVault(...)                     ║
║       │   reads env vars  └─► writes deployments/{network}.json      ║
║       │                                                              ║
║   VerifyAddresses ──────► logs Aave addresses from env vars          ║
║                                                                      ║
╚══════════════════════════════════════════════════════════════════════╝
```

---

## IERC20 — `src/interfaces/IERC20.sol`

### Purpose

A minimal ERC-20 interface declaring only the six functions that `YieldSaveVault` needs to call or inspect on USDC and aUSDC. It is not a full ERC-20 implementation — it is a Solidity type declaration used to give the compiler knowledge of the external function signatures.

Defining a minimal interface rather than importing a full ERC-20 contract keeps compilation fast, eliminates unnecessary ABI encoding surface, and makes the vault's token dependencies explicit.

### State variables

None. Interfaces cannot have state variables.

### Constructor

None. Interfaces cannot be deployed.

### Functions

| Signature | Visibility | Description |
|---|---|---|
| `totalSupply()` | `external view` | Returns the total token supply |
| `balanceOf(address account)` | `external view` | Returns the token balance of `account` |
| `allowance(address owner, address spender)` | `external view` | Returns remaining approved amount |
| `transfer(address to, uint256 value)` | `external` | Transfers `value` tokens from `msg.sender` to `to` |
| `approve(address spender, uint256 value)` | `external` | Approves `spender` to spend `value` tokens on behalf of `msg.sender` |
| `transferFrom(address from, address to, uint256 value)` | `external` | Transfers `value` tokens from `from` to `to` using allowance |

### Access restrictions

Not applicable — this is an interface, not a deployed contract.

### Internal logic flow

Not applicable — interface functions have no implementation.

### Events

None declared. (The full ERC-20 `Transfer` and `Approval` events are not needed by the vault, so they are omitted.)

### Revert conditions

Defined by the concrete implementations (USDC, aUSDC, MockERC20), not by this interface.

### Interaction diagram

```
  YieldSaveVault (caller)
         │
         │  IERC20(usdc).transferFrom(...)
         │  IERC20(usdc).approve(...)
         │  IERC20(usdc).transfer(...)
         │  IERC20(aUsdc).balanceOf(...)
         │
         ▼
  [ Concrete ERC-20 implementation ]
      USDC (Circle)        on mainnet/testnet
      MockERC20            in unit tests
```

---

## IPool — `src/interfaces/IPool.sol`

### Purpose

A minimal Aave V3 Pool interface declaring only the two functions that `YieldSaveVault` calls: `supply` (deposit USDC into Aave and receive aUSDC) and `withdraw` (redeem aUSDC for USDC). The full Aave V3 Pool ABI has dozens of functions; defining only what is needed minimises compilation overhead and makes the dependency surface explicit.

### State variables

None.

### Constructor

None.

### Functions

| Signature | Visibility | Description |
|---|---|---|
| `supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode)` | `external` | Deposits `amount` of `asset` into Aave on behalf of `onBehalfOf`; mints aTokens to `onBehalfOf` |
| `withdraw(address asset, uint256 amount, address to)` | `external returns (uint256)` | Redeems `amount` of `asset` from Aave, sends underlying tokens to `to`; returns actual amount withdrawn |

**`supply` parameter notes:**
- `onBehalfOf`: the address that receives the aTokens — the vault always passes `address(this)`
- `referralCode`: Aave referral program identifier — the vault always passes `0`

**`withdraw` return value:** Aave returns the actual USDC amount withdrawn, which may differ slightly from `amount` due to Aave's internal rounding. The vault does not use the return value.

### Access restrictions

Not applicable.

### Internal logic flow

Not applicable.

### Events

None declared. (Aave emits its own events from the concrete Pool contract.)

### Revert conditions

Defined by the Aave V3 Pool implementation. Most relevant to the vault:
- `supply` reverts if the asset is not supported or the pool is paused
- `withdraw` reverts if there is insufficient liquidity in the pool (utilisation = 100%)

### Interaction diagram

```
  YieldSaveVault (caller)
         │
         │  IPool(aavePool).supply(usdc, amount, vault, 0)
         │  IPool(aavePool).withdraw(usdc, grossAssets, vault)
         │
         ▼
  [ Concrete Aave V3 Pool ]
      Aave V3 Pool         on mainnet/testnet
      MockAavePool         in unit tests
```

---

## YieldSaveVault — `src/YieldSaveVault.sol`

### Purpose

The core protocol contract. It accepts USDC deposits from users, routes them into Aave V3 to earn yield, tracks each user's proportional ownership via non-transferable shares, and returns principal plus net yield (minus a protocol fee) on withdrawal. All protocol configuration is immutable and set at construction.

### Inheritance

```
YieldSaveVault
    └── ReentrancyGuard (OpenZeppelin v5.6.1)
            └── storage: _status (slot 0)
```

### State variables

**Constants** (not in storage — inlined as bytecode literals):

| Name | Value | Description |
|---|---|---|
| `BPS_DENOMINATOR` | `10_000` | Basis point denominator for fee calculations |
| `MAX_FEE_BPS` | `1_000` | Maximum permitted fee rate (10%) |

**Immutables** (not in storage — embedded in deployed bytecode):

| Name | Type | Description |
|---|---|---|
| `usdc` | `IERC20` | The deposit/withdrawal token (USDC) |
| `aUsdc` | `IERC20` | Aave's interest-bearing aUSDC token |
| `aavePool` | `IPool` | Aave V3 Pool |
| `treasury` | `address` | Protocol fee recipient |
| `feeRate` | `uint256` | Fee rate in basis points (e.g. 500 = 5%) |

**Storage** (EVM storage slots, post-inheritance):

| Slot | Name | Type | Description |
|---|---|---|---|
| 0 | `_status` | `uint256` | ReentrancyGuard sentinel (1 = idle, 2 = entered) |
| 1 | `totalShares` | `uint256` | Sum of all outstanding shares |
| 2 | `userShares` | `mapping(address ⇒ uint256)` | Per-user share balance |
| 3 | `userDeposits` | `mapping(address ⇒ uint256)` | Per-user cumulative principal (USDC, 6 dp) |

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

**Validation:**

```
if usdc_ == address(0)     → revert ZeroAddress()
if aUsdc_ == address(0)    → revert ZeroAddress()
if aavePool_ == address(0) → revert ZeroAddress()
if treasury_ == address(0) → revert ZeroAddress()
if feeRate_ > MAX_FEE_BPS  → revert InvalidFeeRate()
```

All five checks must pass before any assignment occurs. If any address is `address(0)`, the entire deployment reverts. All five values are written to immutable storage exactly once and cannot be changed.

### Access restrictions

There are no roles, no `onlyOwner`, and no `onlyAdmin` modifiers. Every external function is callable by any address. The only access control is economic: `withdraw` requires the caller to hold the shares they are redeeming (`userShares[msg.sender] >= shares`).

### Important functions

---

#### `deposit(uint256 amount) → uint256 shares`

**Visibility:** `external nonReentrant`  
**Purpose:** Transfer `amount` USDC from the caller into the vault, supply it to Aave, mint proportional shares.

**Logic flow:**

```
deposit(amount)
    │
    ├─ [GUARD] amount == 0 → revert ZeroAmount
    │
    ├─ snapshot = _totalAssets()           // read aUsdc.balanceOf(vault) BEFORE transfer
    │
    ├─ shares = _previewDeposit(amount, snapshot)
    │       if totalShares == 0 or snapshot == 0:  shares = amount   (1:1 first deposit)
    │       else:                                   shares = amount * totalShares / snapshot
    │
    ├─ [GUARD] shares == 0 → revert ZeroSharesMinted
    │
    ├─ _safeTransferFrom(usdc, msg.sender, vault, amount)
    │       low-level call: usdc.transferFrom(msg.sender, vault, amount)
    │       revert ERC20CallFailed if call fails or returns false
    │
    ├─ _forceApprove(usdc, aavePool, amount)
    │       low-level call: usdc.approve(aavePool, 0)     // reset first
    │       low-level call: usdc.approve(aavePool, amount) // then set
    │       revert ERC20CallFailed on failure
    │
    ├─ aavePool.supply(usdc, amount, vault, 0)
    │       Aave mints aUsdc to vault equal to amount
    │
    ├─ [STATE UPDATE]
    │       userShares[msg.sender] += shares
    │       userDeposits[msg.sender] += amount
    │       totalShares += shares
    │
    └─ emit Deposited(msg.sender, amount, shares)
       return shares
```

**Why `snapshot` is taken before the transfer:**  
If `_totalAssets()` were read after the USDC transfer, the aUSDC balance would be stale from the previous block and the new USDC would not yet appear as aUSDC. Taking the snapshot before any state change ensures the share price used reflects the vault's actual aUSDC position at the time the user initiates the deposit.

**Revert conditions:**

| Error | Condition |
|---|---|
| `ZeroAmount` | `amount == 0` |
| `ZeroSharesMinted` | Computed `shares == 0` (only possible with dust amounts and a very high share price) |
| `ERC20CallFailed` | USDC `transferFrom` or `approve` fails |
| *(Aave revert)* | Aave's `supply` reverts (e.g. pool paused, asset not supported) |

---

#### `withdraw(uint256 shares) → uint256 payout`

**Visibility:** `external nonReentrant`  
**Purpose:** Redeem `shares` from the caller, withdraw the proportional USDC from Aave, deduct the fee on yield, send payout to caller and fee to treasury.

**Logic flow:**

```
withdraw(shares)
    │
    ├─ [GUARD] shares == 0 → revert ZeroAmount
    │
    ├─ userShareBalance = userShares[msg.sender]
    │
    ├─ [GUARD] shares > userShareBalance → revert InsufficientShares
    │
    ├─ (grossAssets, principalPortion, fee) = _quoteWithdraw(
    │       msg.sender, shares, _totalAssets(), totalShares, userShareBalance)
    │
    │       grossAssets     = shares * totalAssets / totalShares
    │       principalPortion = userDeposits[user] * shares / userShareBalance
    │       yield           = grossAssets > principalPortion
    │                           ? grossAssets - principalPortion : 0
    │       fee             = yield * feeRate / BPS_DENOMINATOR
    │
    ├─ payout = grossAssets - fee
    │
    ├─ [STATE UPDATE — before external calls]
    │       userShares[msg.sender] = userShareBalance - shares
    │       userDeposits[msg.sender] -= principalPortion
    │       totalShares -= shares
    │
    ├─ aavePool.withdraw(usdc, grossAssets, vault)
    │       Aave burns vault's aUsdc and transfers USDC to vault
    │
    ├─ _safeTransfer(usdc, msg.sender, payout)
    │
    ├─ if fee != 0: _safeTransfer(usdc, treasury, fee)
    │
    └─ emit Withdrawn(msg.sender, shares, grossAssets, fee, payout)
       return payout
```

**Checks-effects-interactions ordering:**  
State (`userShares`, `userDeposits`, `totalShares`) is updated in step 5, before the Aave withdrawal and token transfers in steps 6–8. This is the correct pattern — even without `nonReentrant`, a reentrant call after step 5 would see the updated (reduced) share balance and be unable to re-use the same shares.

**Revert conditions:**

| Error | Condition |
|---|---|
| `ZeroAmount` | `shares == 0` |
| `InsufficientShares` | `shares > userShares[msg.sender]` |
| `ERC20CallFailed` | Any USDC `transfer` call fails |
| *(Aave revert)* | Aave `withdraw` reverts — most commonly due to zero liquidity (utilisation 100%) |

---

#### `getVaultBalance() → uint256`

**Visibility:** `external view`

Returns `aUsdc.balanceOf(address(this))`. The aUSDC balance of the vault equals the sum of all user deposits plus all accrued Aave yield. It increases every block without any transaction.

---

#### `getUserBalance(address user) → uint256`

**Visibility:** `external view`

Returns the net USDC payout `user` would receive if they withdrew all shares right now (after fee deduction). Returns `0` if `userShares[user] == 0`.

Calls `_previewWithdrawForUser(user, userShares[user])` and returns `payout`.

---

#### `previewDeposit(uint256 amount) → uint256`

**Visibility:** `external view`

Returns the number of shares that would be minted for `amount` USDC at the current share price. Does not modify state. Reflects the same logic as `deposit` without executing it.

---

#### `previewWithdraw(uint256 shares) → uint256`

**Visibility:** `external view`

Returns the net payout `msg.sender` would receive for redeeming `shares`. Returns `0` if invalid (zero shares, no balance, or shares exceed balance).

---

#### `previewWithdrawFor(address user, uint256 shares) → (uint256 payout, uint256 grossAssets, uint256 fee)`

**Visibility:** `external view`

Full three-component withdrawal preview for any `user`. Returns `(0, 0, 0)` on any invalid input.

---

#### Internal: `_previewDeposit(uint256 amount, uint256 assetsBefore) → uint256`

**Visibility:** `internal view`

```
if amount == 0:                        return 0
if totalShares == 0 or assetsBefore == 0:  return amount    ← first deposit: 1:1
else:                                  return amount * totalShares / assetsBefore
```

`assetsBefore` is the aUSDC balance snapshot captured before the USDC transfer in `deposit`. This prevents the share price from being computed on a stale or manipulated balance.

---

#### Internal: `_quoteWithdraw(...) → (uint256 grossAssets, uint256 principalPortion, uint256 fee)`

**Visibility:** `internal view`

```
grossAssets      = shares * assets / currentTotalShares
principalPortion = userDeposits[user] * shares / userShareBalance
yield            = grossAssets > principalPortion ? grossAssets - principalPortion : 0
fee              = yield * feeRate / BPS_DENOMINATOR
```

The yield clamp (`max(0, ...)`) ensures the fee is always non-negative and never exceeds the yield portion. A user who earns no yield pays no fee.

---

#### Internal: `_previewWithdrawForUser(address user, uint256 shares) → (uint256 payout, uint256 grossAssets, uint256 fee)`

**Visibility:** `internal view`

Guard wrapper around `_quoteWithdraw`. Returns `(0, 0, 0)` when: `shares == 0`, `userShareBalance == 0`, or `shares > userShareBalance`. Otherwise delegates to `_quoteWithdraw` and computes `payout = grossAssets - fee`.

---

#### Internal: `_totalAssets() → uint256`

**Visibility:** `internal view`

Returns `aUsdc.balanceOf(address(this))`. The single source of truth for total vault assets. Never cached.

---

#### Internal: `_safeTransfer(IERC20 token, address to, uint256 amount)`

**Visibility:** `internal`

Low-level ERC-20 transfer. Uses `address(token).call(abi.encodeCall(IERC20.transfer, (to, amount)))`.

```
(success, data) = address(token).call(encodeCall(transfer, (to, amount)))
if !success:                       revert ERC20CallFailed
if data.length != 0 and !decode:   revert ERC20CallFailed
// if data.length == 0: treat as success (void-return tokens)
```

---

#### Internal: `_safeTransferFrom(IERC20 token, address from, address to, uint256 amount)`

**Visibility:** `internal`

Identical pattern to `_safeTransfer` but encodes `transferFrom(from, to, amount)`.

---

#### Internal: `_forceApprove(IERC20 token, address spender, uint256 amount)`

**Visibility:** `internal`

```
call: token.approve(spender, 0)       // reset — handles tokens that revert on non-zero approve
  └─ revert ERC20CallFailed on failure
call: token.approve(spender, amount)  // set desired allowance
  └─ revert ERC20CallFailed on failure
```

The two-step reset is required for USDC compatibility. Some USDC deployments revert if `approve` is called when the existing allowance is non-zero. Resetting to 0 first handles this without conditional logic.

### Events

#### `Deposited(address indexed user, uint256 assets, uint256 shares)`

| Field | Type | Indexed | Description |
|---|---|---|---|
| `user` | `address` | Yes | Caller of `deposit` |
| `assets` | `uint256` | No | USDC deposited (6 decimals) |
| `shares` | `uint256` | No | Shares minted |

#### `Withdrawn(address indexed user, uint256 shares, uint256 grossAssets, uint256 fee, uint256 payout)`

| Field | Type | Indexed | Description |
|---|---|---|---|
| `user` | `address` | Yes | Caller of `withdraw` |
| `shares` | `uint256` | No | Shares redeemed |
| `grossAssets` | `uint256` | No | USDC value of redeemed shares before fee |
| `fee` | `uint256` | No | Protocol fee sent to treasury |
| `payout` | `uint256` | No | Net USDC sent to user |

### Interaction diagrams

#### deposit() call flow

```
  User                   YieldSaveVault              USDC (ERC-20)        Aave V3 Pool
   │                           │                           │                    │
   │  ① deposit(amount)        │                           │                    │
   │──────────────────────────►│                           │                    │
   │                           │ ② _totalAssets()          │                    │
   │                           │──────────────────────────►│ balanceOf(vault)   │
   │                           │◄──────────────────────────│                    │
   │                           │                           │                    │
   │                           │ ③ _previewDeposit(amount, snapshot)            │
   │                           │   (internal — no external call)                │
   │                           │                           │                    │
   │                           │ ④ _safeTransferFrom()     │                    │
   │                           │──────────────────────────►│ transferFrom       │
   │                           │   (USDC: user → vault)   │ (user → vault)      │
   │                           │◄──────────────────────────│                    │
   │                           │                           │                    │
   │                           │ ⑤ _forceApprove()         │                    │
   │                           │──────────────────────────►│ approve(pool, 0)   │
   │                           │──────────────────────────►│ approve(pool, amt) │
   │                           │                           │                    │
   │                           │ ⑥ supply(usdc,amt,vault,0)│                    │
   │                           │───────────────────────────────────────────────►│
   │                           │   (aUSDC minted to vault) │                    │◄─ aUsdc.mint(vault, amt)
   │                           │◄───────────────────────────────────────────────│
   │                           │                           │                    │
   │                           │ ⑦ state updates           │                    │
   │                           │   userShares += shares    │                    │
   │                           │   userDeposits += amount  │                    │
   │                           │   totalShares += shares   │                    │
   │                           │                           │                    │
   │  ⑧ emit Deposited(...)    │                           │                    │
   │◄──────────────────────────│                           │                    │
   │   returns shares          │                           │                    │
```

#### withdraw() call flow

```
  User                   YieldSaveVault              USDC (ERC-20)        Aave V3 Pool    Treasury
   │                           │                           │                    │              │
   │  ① withdraw(shares)       │                           │                    │              │
   │──────────────────────────►│                           │                    │              │
   │                           │ ② _totalAssets()          │                    │              │
   │                           │──────────────────────────►│ balanceOf(vault)   │              │
   │                           │◄──────────────────────────│                    │              │
   │                           │                           │                    │              │
   │                           │ ③ _quoteWithdraw(...)     │                    │              │
   │                           │   (internal)              │                    │              │
   │                           │   grossAssets, fee, payout│                    │              │
   │                           │                           │                    │              │
   │                           │ ④ state updates           │                    │              │
   │                           │   userShares -= shares    │                    │              │
   │                           │   userDeposits -= principal                                   │
   │                           │   totalShares -= shares   │                    │              │
   │                           │                           │                    │              │
   │                           │ ⑤ withdraw(usdc,gross,vault)                   │              │
   │                           │───────────────────────────────────────────────►│              │
   │                           │   (USDC returned to vault)│                    │◄─ aUsdc.burn │
   │                           │◄───────────────────────────────────────────────│              │
   │                           │                           │                    │              │
   │                           │ ⑥ _safeTransfer(payout)   │                    │              │
   │                           │──────────────────────────►│ transfer           │              │
   │                           │   (USDC: vault → user)   │ (vault → user)      │              │
   │◄──────────────────────────│◄──────────────────────────│                    │              │
   │                           │                           │                    │              │
   │                           │ ⑦ _safeTransfer(fee)      │                    │              │
   │                           │──────────────────────────►│ transfer           │              │
   │                           │   (USDC: vault → treasury)│ (vault → treasury) │             │◄─ fee arrives
   │                           │                           │                    │              │
   │  ⑧ emit Withdrawn(...)    │                           │                    │              │
   │◄──────────────────────────│                           │                    │              │
   │   returns payout          │                           │                    │              │
```

#### View function flow (read-only, no external writes)

```
  Caller                 YieldSaveVault              aUSDC (ERC-20)
   │                           │                           │
   │  getUserBalance(user)     │                           │
   │──────────────────────────►│                           │
   │                           │ _totalAssets()            │
   │                           │──────────────────────────►│ balanceOf(vault)
   │                           │◄──────────────────────────│
   │                           │ _previewWithdrawForUser(user, userShares[user])
   │                           │   _quoteWithdraw(...)
   │                           │   payout = gross - fee
   │◄──────────────────────────│
   │   returns payout          │
```

---

## MockERC20 — `test/mocks/MockERC20.sol`

### Purpose

A minimal, unrestricted ERC-20 token for use in tests. It fully implements the `IERC20` interface plus `mint` and `burn` functions that have no access control — any test can create or destroy tokens freely. It is used as both the USDC stand-in and the aUSDC stand-in in mock-based tests.

### State variables

| Name | Type | Visibility | Description |
|---|---|---|---|
| `name` | `string` | `public` | Token name |
| `symbol` | `string` | `public` | Token symbol |
| `decimals` | `uint8` | `public immutable` | Decimal places (6 for USDC/aUSDC stand-ins) |
| `totalSupply` | `uint256` | `public` | Total supply, kept in sync by mint/burn |
| `balanceOf` | `mapping(address ⇒ uint256)` | `public` | Per-address balance |
| `allowance` | `mapping(address ⇒ mapping(address ⇒ uint256))` | `public` | Per-address per-spender allowance |

### Constructor

```solidity
constructor(string memory name_, string memory symbol_, uint8 decimals_)
```

Sets `name`, `symbol`, and `decimals`. No validation — any values accepted.

### Access restrictions

None. `mint` and `burn` are callable by any address. This is intentional for test flexibility.

### Important functions

| Function | Description |
|---|---|
| `transfer(to, value)` | Calls `_transfer(msg.sender, to, value)`. Always returns `true`. |
| `approve(spender, value)` | Sets `allowance[msg.sender][spender] = value`. Returns `true`. |
| `transferFrom(from, to, value)` | Reduces allowance (if not `type(uint256).max`), then calls `_transfer`. Returns `true`. |
| `mint(to, value)` | Increases `totalSupply` and `balanceOf[to]` by `value`. |
| `burn(from, value)` | Decreases `balanceOf[from]` and `totalSupply` by `value`. |

#### Internal: `_transfer(from, to, value)`

```
balanceOf[from] -= value    // underflows if insufficient — Solidity 0.8 will revert
balanceOf[to]   += value
```

No events are emitted (unlike a real ERC-20). For test purposes, event emission is not required.

### Revert conditions

| Condition | Cause |
|---|---|
| `transfer` or `transferFrom` with insufficient balance | Solidity 0.8 checked arithmetic underflow on `balanceOf[from] -= value` |
| `burn` with insufficient balance | Same — underflow on `balanceOf[from] -= value` |
| `transferFrom` with insufficient allowance (non-max) | Underflow on `allowance[from][msg.sender] -= value` |

No custom errors — reverts with the default arithmetic panic.

### Events

None. Unlike a production ERC-20, this mock omits `Transfer` and `Approval` events.

### Interaction diagram

```
  Test contract / Fixtures
         │
         │  usdc.mint(alice, 1_000_000e6)
         │  aUsdc.mint(vault, amount)      ← called by MockAavePool.supply
         │  aUsdc.burn(vault, amount)      ← called by MockAavePool.withdraw
         │
         ▼
     MockERC20 (USDC or aUSDC instance)
         │
         │  Read by YieldSaveVault:
         │    aUsdc.balanceOf(vault)       → _totalAssets()
         │
         │  Written by YieldSaveVault (via IERC20 interface):
         │    usdc.transferFrom(user, vault, amount)   → deposit
         │    usdc.approve(pool, amount)               → deposit
         │    usdc.transfer(user, payout)              → withdraw
         │    usdc.transfer(treasury, fee)             → withdraw
```

---

## MockAavePool — `test/mocks/MockAavePool.sol`

### Purpose

A deterministic Aave V3 Pool substitute for unit tests. It implements `IPool` and mirrors Aave's deposit/withdrawal mechanics without any real asset management. It also exposes `accrueYield`, a test-only function that simulates interest accumulation by minting aUSDC directly to the vault.

### State variables

| Name | Type | Visibility | Description |
|---|---|---|---|
| `usdc` | `IERC20` | `public immutable` | Reference to the mock USDC token |
| `aUsdc` | `MockERC20` | `public immutable` | Reference to the mock aUSDC token (typed as `MockERC20` to access `mint`/`burn`) |

### Constructor

```solidity
constructor(address usdc_, address aUsdc_)
```

Stores both token addresses. No validation.

### Access restrictions

None. All functions callable by any address. In practice only `YieldSaveVault` calls `supply` and `withdraw`; only test contracts call `accrueYield`.

### Important functions

#### `supply(address asset, uint256 amount, address onBehalfOf, uint16)`

```
require asset == usdc        // guard against wrong asset
usdc.transferFrom(msg.sender → pool, amount)   // pull USDC from vault
aUsdc.mint(onBehalfOf, amount)                 // mint equivalent aUSDC to vault
```

Mirrors Aave's behaviour: caller provides USDC allowance, pool pulls the USDC, and aTokens appear in `onBehalfOf`'s balance.

#### `withdraw(address asset, uint256 amount, address to)`

```
require asset == usdc
aUsdc.burn(msg.sender, amount)         // destroy vault's aUSDC
usdc.transfer(to, amount)              // return USDC to vault
return amount
```

Mirrors Aave's behaviour: aTokens are burned from the caller (vault), USDC is transferred to `to`.

#### `accrueYield(address account, uint256 amount)` *(test-only)*

```
aUsdc.mint(account, amount)             // simulate aUSDC balance increase (yield on account)
MockERC20(usdc).mint(pool, amount)      // give pool enough USDC to cover future withdrawals
```

This function does not exist on real Aave. It simulates the block-by-block rebasing of aUSDC by directly minting tokens. The pool also mints USDC to itself to remain solvent for subsequent `withdraw` calls.

### Events

None.

### Revert conditions

| Condition | Source |
|---|---|
| `asset != usdc` in `supply` or `withdraw` | `require` string revert: `"unsupported asset"` |
| USDC `transferFrom` fails in `supply` | `require(result, "transferFrom failed")` |
| USDC `transfer` fails in `withdraw` | `require(result, "transfer failed")` |

### Interaction diagram

```
  YieldSaveVault                MockAavePool              MockERC20 (USDC)    MockERC20 (aUSDC)
        │                            │                           │                    │
        │  supply(usdc,amt,vault,0)  │                           │                    │
        │───────────────────────────►│                           │                    │
        │                            │ usdc.transferFrom(vault → pool, amt)            │
        │                            │──────────────────────────►│                    │
        │                            │ aUsdc.mint(vault, amt)    │                    │
        │                            │───────────────────────────────────────────────►│
        │◄───────────────────────────│                           │                    │
        │                            │                           │                    │
        │  withdraw(usdc,gross,vault)│                           │                    │
        │───────────────────────────►│                           │                    │
        │                            │ aUsdc.burn(vault, gross)  │                    │
        │                            │───────────────────────────────────────────────►│
        │                            │ usdc.transfer(vault, gross)                    │
        │                            │──────────────────────────►│                    │
        │◄───────────────────────────│                           │                    │
        │                            │                           │                    │
  Test contract                      │                           │                    │
        │  accrueYield(vault, amt)   │                           │                    │
        │───────────────────────────►│                           │                    │
        │                            │ aUsdc.mint(vault, amt)    │                    │
        │                            │───────────────────────────────────────────────►│
        │                            │ usdc.mint(pool, amt)      │                    │
        │                            │──────────────────────────►│                    │
        │◄───────────────────────────│                           │                    │
```

---

## AaveFork — `test/helpers/AaveFork.sol`

### Purpose

Abstract base contract providing the mock token and pool infrastructure shared by all scenario-based tests. It is responsible for deploying fresh `MockERC20` and `MockAavePool` instances in `setUp`, and for defining the shared test constants and named test addresses. `Fixtures` inherits from `AaveFork` and adds the vault deployment on top.

### State variables

| Name | Type | Visibility | Value / Description |
|---|---|---|---|
| `USDC_UNIT` | `uint256` | `internal constant` | `1e6` — one USDC in base units |
| `FEE_RATE_BPS` | `uint256` | `internal constant` | `500` — 5% fee used in all mock tests |
| `alice` | `address` | `internal` | `makeAddr("alice")` — deterministic test address |
| `bob` | `address` | `internal` | `makeAddr("bob")` — deterministic test address |
| `treasury` | `address` | `internal` | `makeAddr("treasury")` — fee recipient in tests |
| `usdc` | `MockERC20` | `internal` | The mock USDC token (6 decimals) |
| `aUsdc` | `MockERC20` | `internal` | The mock aUSDC token (6 decimals) |
| `pool` | `MockAavePool` | `internal` | The mock Aave Pool |

### Constructor / Initializer

`AaveFork` has no constructor. It uses `setUp()` (Foundry's test initializer):

```solidity
function setUp() public virtual {
    usdc  = new MockERC20("USD Coin", "USDC", 6);
    aUsdc = new MockERC20("Aave USDC", "aUSDC", 6);
    pool  = new MockAavePool(address(usdc), address(aUsdc));
}
```

Marked `virtual` so `Fixtures` (and any other inheritor) can call `super.setUp()` and extend it.

### Access restrictions

Abstract — cannot be deployed directly.

### Events

None.

### Revert conditions

None. `setUp` does not validate anything.

### Interaction diagram

```
  Foundry test runner
         │
         │  setUp()
         ▼
     AaveFork.setUp()
         │
         ├── new MockERC20("USDC", 6)    ──► usdc
         ├── new MockERC20("aUSDC", 6)   ──► aUsdc
         └── new MockAavePool(usdc, aUsdc) ──► pool

     ▼ (inherited by)
  Fixtures.setUp()        (calls super.setUp() first, then deploys vault)
```

---

## Fixtures — `test/helpers/Fixtures.sol`

### Purpose

The primary shared test setup for all scenario-based tests. Inherits `AaveFork` (mock tokens + pool), then deploys a `YieldSaveVault` configured against those mocks, pre-funds `alice` and `bob` with 1,000,000 USDC each, and pre-approves infinite allowances. Provides three helper functions that all scenario tests use to compose test scenarios without boilerplate.

### State variables

Inherits all of `AaveFork`'s state, plus:

| Name | Type | Visibility | Description |
|---|---|---|---|
| `vault` | `YieldSaveVault` | `internal` | The vault under test |

### Constructor / Initializer

```solidity
function setUp() public virtual override {
    super.setUp();   // deploys MockERC20 × 2, MockAavePool

    vault = new YieldSaveVault(
        address(usdc), address(aUsdc), address(pool), treasury, FEE_RATE_BPS
    );

    _mintAndApprove(alice, 1_000_000 * USDC_UNIT);
    _mintAndApprove(bob,   1_000_000 * USDC_UNIT);
}
```

`_mintAndApprove(user, amount)`:
```
usdc.mint(user, amount)
vm.prank(user)
usdc.approve(vault, type(uint256).max)
```

### Helper functions

#### `_deposit(address user, uint256 amount) → uint256 shares`

```
vm.prank(user)
shares = vault.deposit(amount)
```

Wraps `vault.deposit` with the correct `msg.sender`. Allowance is already set to max in `setUp`.

#### `_withdraw(address user, uint256 shares) → uint256 payout`

```
vm.prank(user)
payout = vault.withdraw(shares)
```

Wraps `vault.withdraw` with the correct `msg.sender`.

#### `_accrueYield(uint256 amount)`

```
pool.accrueYield(address(vault), amount)
```

Mints `amount` aUSDC to the vault and `amount` USDC to the pool — simulating Aave yield accrual without advancing blocks.

### Access restrictions

Abstract — cannot be deployed directly.

### Events

None.

### Revert conditions

None in `setUp` itself. `_deposit` and `_withdraw` will propagate reverts from `YieldSaveVault` if the test passes invalid inputs.

### Interaction diagram

```
  Scenario test contract (inherits Fixtures)
         │
         │  setUp()
         ▼
     Fixtures.setUp()
         ├── super.setUp()               → deploys MockERC20×2, MockAavePool
         ├── new YieldSaveVault(...)     → vault
         ├── usdc.mint(alice, 1M USDC)
         ├── alice → usdc.approve(vault, max)
         ├── usdc.mint(bob, 1M USDC)
         └── bob → usdc.approve(vault, max)

         │  test body
         ├── _deposit(alice, 100e6)     → vm.prank(alice) + vault.deposit(100e6)
         ├── _accrueYield(10e6)         → pool.accrueYield(vault, 10e6)
         └── _withdraw(alice, shares)   → vm.prank(alice) + vault.withdraw(shares)
```

---

## BaseSepoliaFork — `test/helpers/BaseSepoliaFork.sol`

### Purpose

Abstract base for fork-based integration tests. Creates a local fork of Base Sepolia at the current block, wires in the real Aave V3 USDC, aUSDC, and Pool contracts (from env vars or hardcoded defaults), and deploys a fresh `YieldSaveVault` against them. Skips all tests automatically if `BASE_SEPOLIA_RPC_URL` is not set. Provides `_deposit` and `_withdraw` helpers identical in signature to `Fixtures`.

### State variables

| Name | Type | Visibility | Value / Description |
|---|---|---|---|
| `USDC_UNIT` | `uint256` | `internal constant` | `1e6` |
| `FEE_RATE_BPS` | `uint256` | `internal constant` | `500` |
| `DEFAULT_BASE_SEPOLIA_USDC` | `address` | `internal constant` | `0xba50Cd2A...` |
| `DEFAULT_BASE_SEPOLIA_AUSDC` | `address` | `internal constant` | `0x10F1A9D1...` |
| `DEFAULT_BASE_SEPOLIA_AAVE_POOL` | `address` | `internal constant` | `0x8bAB6d1b...` |
| `alice` | `address` | `internal` | `makeAddr("alice")` |
| `treasury` | `address` | `internal` | `makeAddr("treasury")` |
| `usdc` | `IERC20` | `internal` | Real USDC on forked chain |
| `aUsdc` | `IERC20` | `internal` | Real aUSDC on forked chain |
| `pool` | `IPool` | `internal` | Real Aave V3 Pool on forked chain |
| `vault` | `YieldSaveVault` | `internal` | Newly deployed vault on forked chain |

### Constructor / Initializer

```solidity
function setUp() public virtual {
    string memory rpcUrl = vm.envOr("BASE_SEPOLIA_RPC_URL", string(""));
    vm.skip(bytes(rpcUrl).length == 0, "BASE_SEPOLIA_RPC_URL is not set");

    vm.createSelectFork(rpcUrl);

    usdc  = IERC20(vm.envOr("BASE_SEPOLIA_USDC", DEFAULT_BASE_SEPOLIA_USDC));
    aUsdc = IERC20(vm.envOr("BASE_SEPOLIA_AUSDC", DEFAULT_BASE_SEPOLIA_AUSDC));
    pool  = IPool(vm.envOr("BASE_SEPOLIA_AAVE_POOL", DEFAULT_BASE_SEPOLIA_AAVE_POOL));

    vault = new YieldSaveVault(address(usdc), address(aUsdc), address(pool), treasury, FEE_RATE_BPS);

    deal(address(usdc), alice, 1_000_000 * USDC_UNIT);

    vm.prank(alice);
    usdc.approve(address(vault), type(uint256).max);
}
```

`vm.skip` causes all tests in any inheriting contract to be skipped (reported as skipped, not failed) when the RPC URL is absent. This allows `forge test` to succeed on machines without a network connection.

`deal` uses Foundry's cheatcode to set `alice`'s USDC balance on the forked chain without needing a real USDC faucet.

### Interaction diagram

```
  Fork test contract (inherits BaseSepoliaFork)
         │
         │  setUp()
         ▼
     BaseSepoliaFork.setUp()
         │
         ├── vm.envOr("BASE_SEPOLIA_RPC_URL") == "" ?
         │       └── vm.skip() → all tests skipped gracefully
         │
         ├── vm.createSelectFork(rpcUrl)
         │       └── EVM state = Base Sepolia at current head
         │
         ├── usdc  = 0xba50Cd2A...   (real Circle USDC on Base Sepolia)
         ├── aUsdc = 0x10F1A9D1...   (real Aave aUSDC on Base Sepolia)
         ├── pool  = 0x8bAB6d1b...   (real Aave V3 Pool on Base Sepolia)
         │
         ├── new YieldSaveVault(usdc, aUsdc, pool, treasury, 500)
         ├── deal(usdc, alice, 1_000_000e6)    (Foundry cheatcode)
         └── alice → usdc.approve(vault, max)
```

---

## YieldSaveVaultTest — `test/YieldSaveVaultTest.t.sol`

### Purpose

The primary unit test contract. Does not inherit `Fixtures` — it sets up its own fork of Base Sepolia (identical pattern to `BaseSepoliaFork`) with `FEE_RATE_BPS = 1000` (10% rather than 5%). Tests all public and external functions, including constructor validation, deposit/withdraw guards, and all preview view functions.

### Setup

Fork-based: reads `BASE_SEPOLIA_RPC_URL`, skips tests if absent. Uses `deal` to give `alice` and `bob` 1,000 USDC each. Approves vault for both.

**Notable difference from scenario tests:** `FEE_RATE_BPS = 1000` (10%), not 500 (5%). This ensures fee calculations are visibly non-zero and distinct from a 5%-based calculation, making fee-related assertions easier to validate.

### Test coverage

| Test | What it validates |
|---|---|
| `test_Constructor_RevertsZeroAddress` | All four address params individually with `address(0)` |
| `test_Constructor_RevertsInvalidFeeRate` | `feeRate = 1001` (one above cap) |
| `test_Deposit_RevertsZeroAmount` | `deposit(0)` → `ZeroAmount` |
| `test_Deposit_Success` | Correct share minting, state updates, event emission |
| `test_Withdraw_RevertsZeroAmount` | `withdraw(0)` → `ZeroAmount` |
| `test_Withdraw_RevertsInsufficientShares` | `withdraw(depositAmount + 1)` → `InsufficientShares` |
| `test_Withdraw_Success` | Full withdraw restores balance (`assertApproxEqAbs` with delta 2 for Aave rounding) |
| `test_ViewFunctions_BeforeDeposit` | `getVaultBalance()`, `getUserBalance()`, `previewDeposit(0)` all return 0 |
| `test_ViewFunctions_AfterDeposit` | `getVaultBalance()`, `getUserBalance()` ≈ deposit amount |
| `test_PreviewWithdraw` | Preview returns ≈ half deposit for half shares |
| `test_PreviewWithdrawFor` | `payout + fee == gross` (identity check) |
| `test_PreviewWithdrawFor_ZeroShares` | Returns `(0, 0, 0)` |
| `test_PreviewWithdrawFor_NonExistentUser` | Returns `payout = 0` for user with no shares |

### Events declared

```solidity
event Deposited(address indexed user, uint256 assets, uint256 shares);
event Withdrawn(address indexed user, uint256 shares, uint256 grossAssets, uint256 fee, uint256 payout);
```

Re-declared locally so `vm.expectEmit` can reference them. Matches the vault's events exactly.

### Revert conditions tested

`ZeroAddress`, `InvalidFeeRate`, `ZeroAmount`, `InsufficientShares`.

---

## DepositScenariosTest — `test/scenarios/Deposit.t.sol`

### Purpose

Scenario tests focused exclusively on the `deposit` function and share minting mechanics. Inherits `Fixtures` (mock infrastructure, 5% fee).

### Test coverage

| Test | Scenario |
|---|---|
| `test_DepositRevertsOnZeroAmount` | Guard: `ZeroAmount` error on `deposit(0)` |
| `test_FirstDepositMintsSharesOneToOne` | First deposit: `shares == amount`, `previewDeposit` matches |
| `test_SecondDepositUsesCurrentSharePrice` | After 20 USDC yield on 100 USDC deposit, second depositor of 60 USDC gets 50 shares (share price = 1.2) |
| `test_MultipleDepositsAccumulatePrincipalAndShares` | Two deposits by same user: `userDeposits` accumulates correctly, second deposit gets fewer shares due to yield |

**Key assertion in `test_SecondDepositUsesCurrentSharePrice`:**
```
totalAssets = 120e6, totalShares = 100e6
bob deposits 60e6 USDC
shares = 60e6 * 100e6 / 120e6 = 50e6
```

---

## WithdrawScenariosTest — `test/scenarios/Withdraw.t.sol`

### Purpose

Scenario tests for the `withdraw` function — withdrawal guards, fee deduction, and proportional principal reduction. Inherits `Fixtures`.

### Test coverage

| Test | Scenario |
|---|---|
| `test_WithdrawRevertsOnZeroShares` | Guard: `ZeroAmount` on `withdraw(0)` |
| `test_WithdrawRevertsWhenUserLacksShares` | Guard: `InsufficientShares` — bob withdraws 1 share without depositing |
| `test_FullWithdrawalReturnsPrincipalPlusNetYield` | 100 USDC deposit + 10 USDC yield → payout = 109.5 USDC (10 × 5% fee = 0.5) |
| `test_PartialWithdrawalReducesPrincipalProportionally` | 40% withdrawal: payout = 47.6 USDC; remaining `userDeposits` = 60 USDC; `getUserBalance` = 71.4 USDC |

**Key numbers in `test_FullWithdrawalReturnsPrincipalPlusNetYield`:**
```
grossAssets = 110e6, principal = 100e6, yield = 10e6
fee = 10e6 * 500 / 10000 = 500_000
payout = 110e6 - 500_000 = 109_500_000
```

**Key numbers in `test_PartialWithdrawalReducesPrincipalProportionally`:**
```
After 20 USDC yield: totalAssets = 120e6, totalShares = 100e6
Redeem 40e6 shares (40%):
  grossAssets = 40e6 * 120e6 / 100e6 = 48e6
  principal   = 100e6 * 40e6 / 100e6 = 40e6
  yield       = 48e6 - 40e6 = 8e6
  fee         = 8e6 * 500 / 10000 = 400_000
  payout      = 48e6 - 400_000 = 47_600_000
Remaining: userShares = 60e6, userDeposits = 60e6
Remaining getUserBalance = 60e6 shares * 72e6 remaining assets / 60e6 remaining shares
  grossAssets = 72e6, yield = 72e6 - 60e6 = 12e6
  fee = 12e6 * 500 / 10000 = 600_000
  payout = 72e6 - 600_000 = 71_400_000
```

---

## FeeScenariosTest — `test/scenarios/Fee.t.sol`

### Purpose

Tests the fee model in isolation — confirming that fees apply only to yield, that zero yield produces zero fee, and that `previewWithdraw` matches the actual deduction. Inherits `Fixtures`.

### Test coverage

| Test | Scenario |
|---|---|
| `test_FeeOnlyAppliesToYield` | 500 USDC deposit + 21 USDC yield; payout = 519.95 USDC; treasury receives 1.05 USDC (5% of 21) |
| `test_ZeroYieldChargesZeroFee` | Immediate withdrawal after deposit: payout = principal exactly, treasury receives 0 |
| `test_PreviewWithdrawMatchesFeeDeduction` | 200 USDC + 20 USDC yield → preview = 219 USDC (20 × 5% = 1 USDC fee) |

**Key assertion in `test_FeeOnlyAppliesToYield`:**
```
deposit 500e6, yield 21e6 → totalAssets = 521e6
fee = 21e6 * 500 / 10000 = 1_050_000
payout = 521e6 - 1_050_000 = 519_950_000
alice USDC = 1_000_000e6 (start) - 500e6 (deposit) + 519_950_000 = 1_000_019_950_000
treasury receives 1_050_000
```

---

## ShareMathScenariosTest — `test/scenarios/ShareMath.t.sol`

### Purpose

Tests the share price appreciation mechanism and its effects on depositors who join at different times. Confirms that `getUserBalance` correctly reflects net yield after fee. Inherits `Fixtures`.

### Test coverage

| Test | Scenario |
|---|---|
| `test_SharePriceAppreciatesAsYieldAccrues` | After 50 USDC yield on 1000 USDC: `aUsdc.balanceOf(vault) == 1050e6`, `totalShares == 1000e6` (share price 1.05) |
| `test_LaterDepositorGetsFewerSharesAfterYield` | After 50% yield: bob's 75 USDC deposit gets 50 shares (75 / 1.5 = 50) |
| `test_GetUserBalanceReturnsNetAssetsAfterFee` | 250 USDC + 25 USDC yield → `getUserBalance` = 273.75 USDC (25 × 5% = 1.25 fee) |

---

## BaseSepoliaIntegrationTest — `test/fork/BaseSepoliaIntegration.t.sol`

### Purpose

Integration tests that run against real Aave V3 contracts on a live Base Sepolia fork. They validate that the vault's `IPool` calls work correctly with the real Aave implementation — including aUSDC minting, USDC withdrawal, and balance tracking. Inherits `BaseSepoliaFork`.

### Test coverage

| Test | What it validates |
|---|---|
| `test_DepositSuppliesRealUsdcToAave` | After `deposit(100 USDC)`: USDC left vault, aUSDC arrived at vault, shares and principal recorded correctly |
| `test_WithdrawRedeemsPrincipalFromRealAavePool` | `previewWithdraw ≈ depositAmount`, payout ≈ depositAmount, all state zeroed out |
| `test_GetVaultBalanceTracksRealATokenBalance` | `getVaultBalance() ≈ aUsdc.balanceOf(vault) ≈ depositAmount` |

**Tolerance:** All assertions use `assertApproxEqAbs(value, expected, 2)`. The tolerance of 2 (0.000002 USDC) accounts for:
- Aave's internal rounding when converting USDC to aUSDC
- Any interest accrued between the transaction and the assertion (on a live fork, time can pass)

### Interaction diagram

```
  BaseSepoliaIntegrationTest
         │
         │  setUp() → BaseSepoliaFork.setUp()
         │    └── fork Base Sepolia
         │    └── new YieldSaveVault (real Aave addresses)
         │    └── deal(usdc, alice, 1M USDC)
         │
         │  test_DepositSuppliesRealUsdcToAave()
         │    ├── _deposit(alice, 100e6)
         │    │       vault.deposit(100e6)
         │    │         └── real USDC.transferFrom(alice → vault)
         │    │         └── real Aave.supply(usdc, 100e6, vault, 0)
         │    │               └── real aUSDC minted to vault
         │    └── assert aUsdc.balanceOf(vault) ≈ 100e6
```

---

## Deploy — `script/Deploy.s.sol`

### Purpose

Foundry deployment script. Reads network configuration from environment variables, detects the target chain from `block.chainid`, deploys `YieldSaveVault` with the correct Aave addresses, and writes the deployment record to `deployments/{network}.json`.

### State variables

None. All values are read from environment or computed at run time.

### Constructor

None. Inherits `Script` from forge-std.

### Functions

#### `run() → YieldSaveVault vault`

The entry point called by `forge script`.

**Logic flow:**

```
run()
  │
  ├── deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY")
  ├── treasury           = vm.envAddress("TREASURY")
  ├── feeRate            = vm.envOr("FEE_RATE_BPS", 500)
  │
  ├── (usdc, aUsdc, pool, network) = _loadNetworkConfig(block.chainid)
  │
  ├── vm.startBroadcast(deployerPrivateKey)
  │       vault = new YieldSaveVault(usdc, aUsdc, pool, treasury, feeRate)
  │   vm.stopBroadcast()
  │
  ├── _writeDeployment(network, address(vault))
  │       path = "./deployments/{network}.json"
  │       vm.serializeAddress / vm.serializeUint / vm.writeJson
  │
  └── console2.log("YieldSaveVault deployed to", address(vault))
      return vault
```

#### `_loadNetworkConfig(uint256 chainId) → (address usdc, address aUsdc, address pool, string network)`

```
if chainId == 11155111 (Sepolia):
    return (env SEPOLIA_USDC, env SEPOLIA_AUSDC, env SEPOLIA_AAVE_POOL, "sepolia")

if chainId == 84532 (Base Sepolia):
    return (env BASE_SEPOLIA_USDC, env BASE_SEPOLIA_AUSDC, env BASE_SEPOLIA_AAVE_POOL, "base-sepolia")

else: revert("unsupported chain")
```

#### `_writeDeployment(string network, address vault)`

Writes a JSON file to `./deployments/{network}.json` using Foundry's `vm.serializeAddress`, `vm.serializeUint`, and `vm.writeJson` cheatcodes. The file contains `vault`, `chainId`, and `block` fields.

### Access restrictions

`vm.startBroadcast` signs transactions with `DEPLOYER_PRIVATE_KEY`. Only the address corresponding to that key pays gas and deploys the contract. The script itself has no on-chain access control.

### Events

None emitted by the script. `YieldSaveVault`'s constructor does not emit events. Deployment is confirmed via `console2.log` output.

### Revert conditions

| Condition | Cause |
|---|---|
| `DEPLOYER_PRIVATE_KEY` not set | `vm.envUint` reverts: environment variable not found |
| `TREASURY` not set | `vm.envAddress` reverts |
| Aave address env vars not set | `vm.envAddress` reverts inside `_loadNetworkConfig` |
| Unsupported `chainId` | `revert("unsupported chain")` |
| Any `address(0)` in Aave addresses | `YieldSaveVault` constructor reverts `ZeroAddress` |
| `feeRate > 1000` | `YieldSaveVault` constructor reverts `InvalidFeeRate` |
| Insufficient gas in deployer wallet | EVM out-of-gas |

### Interaction diagram

```
  forge script Deploy.s.sol
         │
         │  run()
         ▼
     Deploy script
         │
         ├── read env vars (vm.envUint, vm.envAddress, vm.envOr)
         │
         ├── _loadNetworkConfig(block.chainid)
         │       ├── chainId == 11155111 → read SEPOLIA_* env vars
         │       └── chainId == 84532   → read BASE_SEPOLIA_* env vars
         │
         ├── vm.startBroadcast(privateKey)
         │       └── new YieldSaveVault(usdc, aUsdc, pool, treasury, feeRate)
         │               └── [on-chain deployment transaction]
         │   vm.stopBroadcast()
         │
         └── _writeDeployment(network, vaultAddress)
                 └── vm.writeJson → deployments/{network}.json
```

---

## VerifyAddresses — `script/VerifyAddresses.s.sol`

### Purpose

A read-only utility script that logs the Aave V3 contract addresses from environment variables for the current network. Used before deployment to verify that the correct Aave addresses are configured for the target chain. Takes no action on-chain.

### State variables

None.

### Functions

#### `run() external view`

```
if block.chainid == 11155111:
    log "Network: Sepolia"
    log SEPOLIA_USDC
    log SEPOLIA_AUSDC
    log SEPOLIA_AAVE_POOL

if block.chainid == 84532:
    log "Network: Base Sepolia"
    log BASE_SEPOLIA_USDC
    log BASE_SEPOLIA_AUSDC
    log BASE_SEPOLIA_AAVE_POOL

else: revert("unsupported chain")
```

### Access restrictions

View-only (`external view`). No transactions broadcast.

### Events

None.

### Revert conditions

| Condition | Cause |
|---|---|
| Unsupported chain | `revert("unsupported chain")` |
| Address env vars not set | `vm.envAddress` reverts |

### Usage

```bash
# Verify Sepolia addresses before deployment
forge script script/VerifyAddresses.s.sol --rpc-url $SEPOLIA_RPC_URL

# Verify Base Sepolia addresses
forge script script/VerifyAddresses.s.sol --rpc-url $BASE_SEPOLIA_RPC_URL
```

### Interaction diagram

```
  forge script VerifyAddresses.s.sol --rpc-url <url>
         │
         │  run()   (read-only: no broadcast, no state change)
         ▼
     VerifyAddresses
         │
         ├── read block.chainid from RPC
         ├── read env vars (vm.envAddress)
         └── console2.log(addresses)
                 └── printed to terminal
```
