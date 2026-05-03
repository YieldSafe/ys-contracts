# Testing Guide

## Overview

The test suite is pure Foundry (Forge). It is organised into four layers — each serves a different purpose and has different speed and dependency requirements.

| Layer | Location | Dependencies | Speed |
|---|---|---|---|
| Unit / scenario | `test/scenarios/`, `test/YieldSaveVault.t.sol` | Mock contracts only | Fast (< 1s) |
| Integration | `test/fork/` | Live Aave V3 via RPC | Slow (3–10s per test) |
| Fuzz | Any test with function parameters | Mock contracts only | Medium (256 runs × time per run) |

---

## Test Structure

```
test/
  YieldSaveVault.t.sol              Core unit tests + constructor validation
  helpers/
    Fixtures.sol                    Abstract base: deploys vault + mocks, pre-funds alice/bob
    AaveFork.sol                    Deploys MockERC20 + MockAavePool for unit test setups
    BaseSepoliaFork.sol             Forks Base Sepolia and wires real Aave addresses
  scenarios/
    Deposit.t.sol                   Deposit guard checks, share minting, share price
    Withdraw.t.sol                  Withdrawal flows, proportional principal reduction
    Fee.t.sol                       Fee-only-on-yield, zero-yield no-fee, preview accuracy
    ShareMath.t.sol                 Share price appreciation, later depositor dilution
  mocks/
    MockERC20.sol                   Minimal ERC-20 with mint/burn
    MockAavePool.sol                Deterministic mock: supply, withdraw, accrueYield
  fork/
    BaseSepoliaIntegration.t.sol    Real deposit/withdraw/balance against Aave V3
```

---

## Running Tests

### All tests

```bash
forge test
# or
make test
```

No environment variables are needed. Fork tests skip automatically when `BASE_SEPOLIA_RPC_URL` is unset.

### With traces (recommended when debugging failures)

```bash
forge test -vvvv
# or
make test-verbose
```

`-v` through `-vvvv` increase verbosity. `-vvvv` shows full call traces, storage reads/writes, and gas costs per call.

### Specific file or test

```bash
# Single file
forge test --match-path test/scenarios/Fee.t.sol

# Single function (partial match)
forge test --match-test test_FeeOnlyAppliesToYield

# All tests in a contract
forge test --match-contract FeeScenarios
```

### Watch mode

```bash
forge test --watch
```

Re-runs all tests on every file save. Useful during active development.

---

## Fork Tests

Fork tests create a local EVM clone of Base Sepolia at the current block and run against the real deployed Aave V3 contracts.

```bash
# Requires BASE_SEPOLIA_RPC_URL set in .env
make fork-base

# Or directly:
forge test --fork-url $BASE_SEPOLIA_RPC_URL --match-path test/fork/
```

Fork tests are **not** run in CI by default (they require a live RPC and are slower). Run them manually before opening a PR that touches Aave integration logic.

### When to write fork tests vs mock tests

Write a **mock test** when you want to verify logic in isolation — share math, fee calculation, guard conditions. Mock tests are deterministic and fast.

Write a **fork test** when you need to confirm the Aave integration contract behaves exactly as expected on a live network — call signatures, return values, aUSDC balance changes.

---

## Coverage

```bash
make coverage
# or
forge coverage
```

Coverage output lists line and branch coverage per file. The project targets 100% line coverage on `src/`. Internal helpers (`_safeTransfer`, `_forceApprove`, `_previewDeposit`, etc.) should each have at least one direct test path.

To see which specific lines are uncovered, use the LCOV report:

```bash
forge coverage --report lcov
genhtml lcov.info --output-directory coverage-report
open coverage-report/index.html   # macOS
```

---

## Gas Snapshots

```bash
make gas
# or
forge snapshot
```

This writes `.gas-snapshot` in the repo root. The file is committed to version control — it acts as a gas regression check. If a change unexpectedly increases gas, the snapshot will diverge and CI will flag it.

When you intentionally change gas costs, regenerate and commit the snapshot:

```bash
forge snapshot
git add .gas-snapshot
```

---

## Mock Setup

### MockERC20

A minimal ERC-20 with no restrictions: `transfer`, `approve`, `transferFrom`, `mint`, `burn`. Uses 6 decimal places by default (matching USDC). Tests use it as both the USDC and aUSDC stand-ins.

### MockAavePool

Simulates Aave V3's `supply` and `withdraw` mechanics deterministically:

| Function | Behaviour |
|---|---|
| `supply(asset, amount, onBehalfOf, referralCode)` | Pulls `amount` USDC from `onBehalfOf`, mints equal aUSDC to `onBehalfOf` |
| `withdraw(asset, amount, to)` | Burns `amount` aUSDC from caller, transfers `amount` USDC to `to` |
| `accrueYield(amount)` | Mints `amount` aUSDC to vault + `amount` USDC to pool (simulates block-by-block yield) |

`accrueYield` is test-only — it does not exist on real Aave.

### Fixtures

`Fixtures` is an abstract base contract for scenario tests:

```solidity
abstract contract Fixtures is Test {
    YieldSaveVault vault;
    MockERC20      usdc;
    MockERC20      aUsdc;
    MockAavePool   pool;

    address alice = address(0xA);
    address bob   = address(0xB);
    address treasury = address(0xFEE);

    function setUp() public virtual {
        // deploys mocks and vault, mints 1M USDC each to alice and bob
    }

    function _deposit(address user, uint256 amount) internal { ... }
    function _withdraw(address user, uint256 shares) internal { ... }
    function _accrueYield(uint256 amount) internal { ... }
}
```

All scenario test files inherit `Fixtures`:

```solidity
contract DepositScenarios is Fixtures {
    function test_FirstDepositMintsSharesOneToOne() public {
        _deposit(alice, 1_000e6);
        assertEq(vault.userShares(alice), 1_000e6);
    }
}
```

---

## Writing Tests

### Scenario test (most common)

1. Create `test/scenarios/YourFeature.t.sol`
2. Inherit `Fixtures`
3. Prefix test functions with `test_`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Fixtures} from "../helpers/Fixtures.sol";

contract YourFeatureScenarios is Fixtures {
    function test_SomeCondition() public {
        _deposit(alice, 500e6);
        _accrueYield(25e6);

        uint256 shares = vault.userShares(alice);
        uint256 payout = vault.getUserBalance(alice);

        assertGt(payout, 500e6, "payout should include yield");
    }
}
```

### Fuzz test

Add parameters to any test function — Foundry automatically fuzz-tests it:

```solidity
function test_FuzzDepositShares(uint256 amount) public {
    amount = bound(amount, 1e6, 1_000_000e6);  // clamp to valid range

    vm.prank(alice);
    usdc.approve(address(vault), amount);

    vm.prank(alice);
    uint256 shares = vault.deposit(amount);

    assertEq(shares, amount);  // first deposit is 1:1
}
```

The `bound(value, min, max)` cheatcode from `forge-std` is essential for clamping inputs to valid ranges. Fuzz runs default to 256 (configured in `foundry.toml`).

### Fork test

1. Create `test/fork/YourIntegration.t.sol`
2. Inherit `BaseSepoliaFork`
3. The base class skips automatically when `BASE_SEPOLIA_RPC_URL` is unset

```solidity
contract YourIntegrationTest is BaseSepoliaFork {
    function test_RealAaveInteraction() public {
        uint256 amount = 10e6;  // 10 USDC
        _deposit(testUser, amount);

        assertGt(vault.getVaultBalance(), 0);
    }
}
```

### Revert tests

Use `vm.expectRevert` to assert that a call reverts with a specific error:

```solidity
function test_DepositRevertsOnZeroAmount() public {
    vm.prank(alice);
    vm.expectRevert(YieldSaveVault.ZeroAmount.selector);
    vault.deposit(0);
}
```

---

## Conventions

### Test function naming

All test functions follow `test_{Description}` in PascalCase description, e.g.:

```
test_DepositRevertsOnZeroAmount
test_FirstDepositMintsSharesOneToOne
test_FeeOnlyAppliesToYield
test_SharePriceAppreciatesAsYieldAccrues
```

### Assertions

Prefer the most specific assertion:

| Use | Instead of |
|---|---|
| `assertEq(a, b)` | `assertTrue(a == b)` |
| `assertGt(a, b)` | `assertTrue(a > b)` |
| `assertApproxEqAbs(a, b, delta)` | manual tolerance check |

Always include a failure message as the third argument when the assertion is non-obvious.

### `vm.prank` vs `vm.startPrank`

Use `vm.prank(user)` for a single call. Use `vm.startPrank(user)` + `vm.stopPrank()` when a test requires multiple consecutive calls from the same address.

### No `console.log` in committed tests

`console2.log` calls are acceptable during debugging but must be removed before merging. They add noise to test output and slow down runs.
