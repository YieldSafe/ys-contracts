# Architecture

## System Overview

YieldSave is a single-contract protocol. One deployment of `YieldSaveVault` manages all user funds for a given network. There is no proxy, no governance, no admin role, and no upgradeability — all configuration is immutable and set at construction time.

```
┌─────────────────────────────────────────────────────────┐
│                        User                             │
│  deposit(amount) ──────────────────┐                   │
│  withdraw(shares) ─────────────────┼──────────────────► │
└────────────────────────────────────┼────────────────────┘
                                     │
                          ┌──────────▼──────────┐
                          │   YieldSaveVault     │
                          │                     │
                          │  - share accounting  │
                          │  - fee calculation   │
                          │  - principal tracking│
                          └──────────┬──────────┘
                                     │ supply / withdraw
                          ┌──────────▼──────────┐
                          │     Aave V3 Pool     │
                          │                     │
                          │  USDC ──► aUSDC      │
                          │  (yield accrues via  │
                          │   aUSDC rebasing)    │
                          └─────────────────────┘
```

**Token flow:**
- Deposit: USDC leaves user → enters vault → enters Aave Pool → aUSDC held by vault
- Withdraw: aUSDC burned by Aave Pool → USDC sent from vault → payout to user + fee to treasury

---

## Share Model

Shares represent proportional ownership of the vault's total assets. They are tracked in mappings — they are not transferable ERC-20 tokens (an intentional simplification for the MVP).

### First deposit

When the vault has no shares or no assets, shares are minted 1:1 with the deposit amount:

```
shares = amount
```

This bootstraps the share price at 1.0 USDC per share.

### Subsequent deposits

```
shares = amount × totalShares / totalAssets
```

`totalAssets` is the live aUSDC balance of the vault at the moment of deposit. As Aave accrues interest, `totalAssets` grows while `totalShares` stays constant, so new depositors receive fewer shares per USDC. This is how yield is distributed implicitly — existing shareholders' claims grow as the share price rises.

### User claim

```
userClaim = userShares × totalAssets / totalShares
```

A user's USDC claim at any point equals their share of the vault's total assets.

### Share price appreciation

```
sharePrice(t) = totalAssets(t) / totalShares
```

`totalShares` only changes on deposit or withdrawal. `totalAssets` grows every block as Aave pays interest. The ratio rises monotonically (barring Aave losses). No explicit yield distribution is needed — it is implicit in the share price.

---

## Fee Model

The fee is applied only to the yield portion of a withdrawal. Principal is always returned in full.

### Definitions

```
grossAssets    = shares × totalAssets / totalShares
principalPortion = userDeposits[user] × shares / userShares[user]
yield          = max(0, grossAssets − principalPortion)
fee            = yield × feeRate / 10_000
payout         = grossAssets − fee
```

### Principal protection guarantee

`yield` is clamped to `max(0, ...)`. This means:
- If a user withdraws before any yield has accrued, `yield = 0` and `fee = 0`.
- If rounding causes `grossAssets < principalPortion`, the shortfall is absorbed by the protocol (not charged to the user).
- The fee can never exceed yield, and yield can never be negative.

### Proportional principal reduction

When a user makes a partial withdrawal, their recorded principal is reduced proportionally to the shares redeemed:

```
principalPortion = userDeposits[user] × shares / userShares[user]
userDeposits[user] -= principalPortion
```

This preserves accurate principal tracking across multiple partial withdrawals.

---

## State Variables

```solidity
// Immutable — set at construction, never change
IERC20 public immutable usdc;
IERC20 public immutable aUsdc;
IPool  public immutable aavePool;
address public immutable treasury;
uint256 public immutable feeRate;

// Mutable
uint256 public totalShares;
mapping(address => uint256) public userShares;
mapping(address => uint256) public userDeposits;
```

`totalAssets` is not stored — it is always read live from `aUsdc.balanceOf(address(this))`. This ensures the vault always reflects the current Aave balance without needing an update trigger.

---

## Key Invariants

These properties must hold at all times:

| Invariant | Expression |
|---|---|
| Total assets is live | `totalAssets == aUsdc.balanceOf(vault)` |
| Shares are fully accounted | `Σ userShares[all] == totalShares` |
| Fee bounded by yield | `fee ≤ max(0, gross − principal)` |
| Principal never penalised | `payout ≥ principalPortion` (when no yield) |
| Share price non-decreasing | `totalAssets / totalShares` grows with Aave APY |

---

## Function Reference

### Write functions

| Function | Guard | Effect |
|---|---|---|
| `deposit(uint256 amount)` | `nonReentrant`, amount > 0 | Transfers USDC, supplies to Aave, mints shares |
| `withdraw(uint256 shares)` | `nonReentrant`, shares ≤ userShares | Redeems shares, withdraws from Aave, pays fee, transfers payout |

### View functions

| Function | Returns |
|---|---|
| `getVaultBalance()` | Total aUSDC held by vault |
| `getUserBalance(address user)` | Net USDC the user would receive if they withdrew all shares now |
| `previewDeposit(uint256 amount)` | Shares that would be minted |
| `previewWithdraw(uint256 shares)` | Payout `msg.sender` would receive |
| `previewWithdrawFor(address user, uint256 shares)` | Payout, gross assets, and fee for any user |

### Custom errors

| Error | When |
|---|---|
| `ZeroAddress()` | Constructor receives `address(0)` |
| `ZeroAmount()` | `deposit` or `withdraw` called with 0 |
| `InvalidFeeRate()` | Constructor `feeRate` > `MAX_FEE_BPS` (1000) |
| `InsufficientShares()` | `withdraw` amount exceeds `userShares[msg.sender]` |
| `ZeroSharesMinted()` | Deposit amount rounds to 0 shares |
| `ERC20CallFailed()` | Any ERC-20 low-level call returns false or reverts |

---

## External Dependencies

### Aave V3 Pool (`IPool`)

Two calls are made to Aave:

```solidity
aavePool.supply(address(usdc), amount, address(this), 0);
aavePool.withdraw(address(usdc), grossAssets, address(this));
```

`supply` mints aUSDC to the vault. `withdraw` burns aUSDC and returns USDC. Both are synchronous and revert on failure.

**Risk:** If Aave V3 has a bug, the vault's assets are at risk. If Aave's utilisation is 100%, `withdraw` will revert until liquidity returns.

### aUSDC (`IERC20`)

The vault reads `aUsdc.balanceOf(address(this))` on every view and state-changing call. This is Aave's interest-bearing wrapper token that rebases upward over time — it is how yield accrues.

**Risk:** If Aave's aToken has a bug affecting balances, share price calculations will be corrupted.

### USDC (`IERC20`)

Standard Circle USDC. The vault uses safe ERC-20 wrappers (`_safeTransfer`, `_safeTransferFrom`, `_forceApprove`) to handle non-standard return value behaviour.

**Risk:** USDC can be blacklisted by Circle. If the vault address or user address is blacklisted, transfers will fail. Circle insolvency would affect USDC value.

---

## Security Model

### What is protected

| Threat | Mitigation |
|---|---|
| Reentrancy attack | `ReentrancyGuard` on `deposit` and `withdraw` |
| Admin rug pull | No admin withdrawal functions exist |
| Fee rate escalation | `feeRate` is immutable; capped at 10% at construction |
| Zero-address misconfiguration | Constructor reverts on any `address(0)` argument |
| Silent ERC-20 failures | All token calls use low-level wrappers that check return values |
| Rounding to zero shares | `deposit` reverts with `ZeroSharesMinted` if `shares == 0` |
| Over-withdrawal | `withdraw` reverts with `InsufficientShares` if `shares > userShares[msg.sender]` |

### What is not protected

| Risk | Notes |
|---|---|
| Aave protocol bugs | External dependency; mitigated by Aave V3's track record and audits |
| Aave liquidity crunch | `withdraw` reverts; users must wait for liquidity to free up |
| USDC depeg or blacklist | External dependency; no mitigation in-contract |
| MEV / sandwich attacks | Deposits and withdrawals are permissionless; share price can be front-run at scale |
| No upgradeability | Bugs require re-deployment and migration (see [Maintenance Guide](maintenance.md)) |

### Non-custodial guarantee

The vault has no function that allows any address (including the deployer) to withdraw user funds unilaterally. The only paths to funds are:
1. The depositing user calls `withdraw` with their own shares.
2. Aave withdraws funds automatically in a liquidation scenario (not applicable to supply-only positions).

If the frontend fails, users can recover their funds by calling `withdraw` directly via Etherscan or any EVM wallet.

---

## Design Decisions

**Why not full ERC-4626?**
ERC-4626 requires shares to be a transferable ERC-20. Adding that increases contract complexity and audit surface. The MVP deliberately omits it to keep the attack surface minimal. ERC-4626 compliance is planned for a future version.

**Why immutable configuration?**
Mutable configuration (even behind a timelock) creates governance risk and complicates the trust model. For an MVP, immutability provides a simpler and stronger security guarantee. Protocol parameter changes require a new deployment.

**Why no on-chain oracle?**
Share price is derived from `aUsdc.balanceOf()`, which is the canonical on-chain source of truth for vault assets. No price oracle is needed or appropriate.

**Why `_forceApprove` resets to 0 first?**
Some ERC-20 implementations reject `approve` calls when the current allowance is non-zero (to prevent certain approval race conditions). Resetting to 0 before approving handles these tokens without conditional logic.
