# Developer FAQ

## General

**Q: Is this ERC-4626 compliant?**

No. The vault uses ERC-4626 concepts (shares, `deposit`, `withdraw`, `previewDeposit`) but shares are not transferable ERC-20 tokens. ERC-4626 requires shares to implement the full ERC-20 interface so they can be traded, used as collateral, or composed with other protocols. That is deferred to a future version to keep the MVP's audit surface minimal. See [Architecture — Design Decisions](architecture.md#design-decisions).

---

**Q: Can the fee rate be changed after deployment?**

No. `feeRate` is an `immutable` state variable — it is set once in the constructor and cannot be changed. To change the fee rate, a new vault must be deployed with the updated rate and users must migrate.

---

**Q: Can the treasury address be changed?**

No, for the same reason. `treasury` is immutable. Any fee recipient change requires a re-deployment.

---

**Q: Is there an admin or owner role?**

No. There are no privileged roles. The deployer has no special access after deployment. No function exists to pause the vault, adjust parameters, or withdraw user funds. See [Architecture — Security Model](architecture.md#security-model).

---

**Q: Can the contract be upgraded?**

No. There is no proxy, no `delegatecall`, and no upgrade mechanism. Bug fixes require deploying a new contract and migrating users. See [Maintenance — Re-Deployment and Migration](maintenance.md#re-deployment-and-migration).

---

## Share Model

**Q: Why do shares have the same decimals as USDC (6) on first deposit?**

The first deposit uses a 1:1 ratio: `shares = amount`. USDC has 6 decimals, so the first depositor of `1_000_000` (1 USDC) gets `1_000_000` shares. Later deposits use the share price formula, which preserves this scale as long as yield accrual is gradual.

---

**Q: What happens if the vault has assets but no shares (orphaned yield)?**

This cannot happen through normal usage. `totalShares` and `totalAssets` only change together — deposits add both, withdrawals reduce both. The only way to get assets with zero shares is via a direct aUSDC transfer to the vault address (which is extremely unlikely and would result in that yield being unreachable).

---

**Q: Can share price decrease?**

Only if Aave suffers a loss event (e.g. bad debt from a security exploit) that reduces the aUSDC balance of the vault. In normal operation, share price is monotonically non-decreasing.

---

**Q: What does `userDeposits` track exactly?**

It tracks the user's cumulative principal — the total USDC deposited, adjusted downward proportionally each time the user makes a partial withdrawal. It is not the current USDC value of their shares. It is used solely to calculate the fee: fee = `feeRate × max(0, currentValue − principal)`.

---

## Fees

**Q: When is the fee charged?**

Only at withdrawal, and only on the yield portion. A user who deposits and immediately withdraws (no time for yield to accrue) pays zero fee. The fee is deducted from the payout before it is sent to the user.

**Q: What if my withdrawal payout would be less than my deposit due to rounding?**

The fee calculation clamps yield to `max(0, grossAssets − principal)`. If rounding causes `grossAssets < principal`, yield is treated as zero and no fee is charged. The user receives `grossAssets` (which equals `grossAssets − 0`). This means the protocol absorbs rounding errors rather than the user.

---

**Q: How do I calculate the exact fee before withdrawing?**

Use `previewWithdrawFor`:

```solidity
(uint256 payout, uint256 grossAssets, uint256 fee) =
    vault.previewWithdrawFor(userAddress, sharesToRedeem);
```

Or via `cast`:

```bash
cast call $VAULT "previewWithdrawFor(address,uint256)(uint256,uint256,uint256)" \
  $USER $SHARES --rpc-url $RPC
```

---

## Integration

**Q: USDC has 6 decimals — what unit should I use for amounts?**

Always pass amounts in the smallest unit (i.e. `1 USDC = 1_000_000`). Use `parseUnits(amount, 6)` in JavaScript/TypeScript and `formatUnits(amount, 6)` when displaying.

```typescript
import { parseUnits, formatUnits } from "viem";

const depositAmount = parseUnits("100", 6);   // 100 USDC → 100_000_000n
const display = formatUnits(rawBalance, 6);    // 100_000_000n → "100"
```

---

**Q: Should I use `previewDeposit` / `previewWithdraw` for UI display?**

Yes — they are view functions with no gas cost. Call them to show the user what they will receive before they sign the transaction.

Note: `previewWithdraw` is relative to `msg.sender`. If you need to preview for a different address, use `previewWithdrawFor(address, shares)` instead.

---

**Q: How do I listen for deposit and withdrawal events?**

Subscribe to the `Deposited` and `Withdrawn` events filtered by the user's address:

```typescript
const depositLogs = await client.getLogs({
    address: VAULT_ADDRESS,
    event: parseAbiItem("event Deposited(address indexed user, uint256 assets, uint256 shares)"),
    args: { user: userAddress },
    fromBlock: DEPLOY_BLOCK,
});
```

The `Withdrawn` event includes `shares`, `grossAssets`, `fee`, and `payout` — enough to show a full breakdown in the UI.

---

**Q: Where do I get the deployed ABI?**

After `forge build`, the full ABI is at `out/YieldSaveVault.sol/YieldSaveVault.json`. The relevant subset for frontend use is documented in [Reference — ABI (JSON)](reference.md#abi-json).

---

## Testing

**Q: Do I need an RPC to run tests?**

No. The standard test suite (`test/scenarios/`, `test/YieldSaveVault.t.sol`) uses mock contracts and runs entirely in-process. Only `test/fork/` requires `BASE_SEPOLIA_RPC_URL`. See [Testing Guide](testing.md).

---

**Q: How do I simulate yield accrual in tests?**

Call `_accrueYield(amount)` in your test (available via `Fixtures`). Under the hood it calls `mockPool.accrueYield(amount)`, which mints aUSDC directly to the vault — the same effect as Aave paying interest over time, but instantaneous.

```solidity
_deposit(alice, 1_000e6);
_accrueYield(50e6);          // vault earned 50 USDC of yield
uint256 balance = vault.getUserBalance(alice);
// balance ≈ 1047.5e6 (1000 principal + 50 yield - 5% fee on yield)
```

---

**Q: How do I test the contract with a real Aave pool locally?**

Use Foundry's fork mode to create a local EVM clone of Base Sepolia:

```bash
forge test --fork-url $BASE_SEPOLIA_RPC_URL --match-path test/fork/
```

The fork is a full snapshot — you get real Aave contracts, real USDC, and real aUSDC. The `BaseSepoliaFork` helper in `test/helpers/` handles setup.

---

**Q: Why is my fuzz test failing with values I didn't expect?**

Fuzz tests receive random inputs including edge cases like `0`, `type(uint256).max`, and values that overflow intermediate calculations. Use `bound(value, min, max)` to constrain inputs to a safe range:

```solidity
amount = bound(amount, 1e6, 1_000_000e6);
```

See [Testing Guide — Fuzz Tests](testing.md#fuzz-test) for a full example.
