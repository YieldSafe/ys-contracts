# Maintenance Guide

## Overview

`YieldSaveVault` is an immutable contract. Once deployed:
- No parameters can be changed
- No funds can be moved by an admin
- No logic can be upgraded

"Maintenance" therefore means: monitoring vault health, collecting fees, responding to external incidents (Aave, USDC), and re-deploying when a bug fix or upgrade is needed.

---

## Vault Health Indicators

Check these regularly to confirm the vault is operating correctly.

### 1. Total assets tracking

The vault's aUSDC balance should equal or exceed the sum of all user deposits (difference is yield):

```bash
cast call $VAULT "getVaultBalance()(uint256)" --rpc-url $RPC
```

Expected: value grows every block as Aave accrues interest. A sudden drop to zero is a critical incident.

### 2. Share price

Share price should be monotonically non-decreasing:

```
sharePrice = getVaultBalance() / totalShares
```

```bash
ASSETS=$(cast call $VAULT "getVaultBalance()(uint256)" --rpc-url $RPC | cast to-dec)
SHARES=$(cast call $VAULT "totalShares()(uint256)" --rpc-url $RPC | cast to-dec)
echo "Share price: $ASSETS / $SHARES"
```

A declining share price indicates a loss event in Aave (a serious incident requiring investigation).

### 3. Aave withdrawal availability

Aave withdrawals fail when the pool utilisation is 100% (all USDC lent out). Check the available liquidity:

```bash
# aUSDC balance held by Aave Pool == withdrawable USDC
cast call $AUSDC "balanceOf(address)(uint256)" $AAVE_POOL --rpc-url $RPC
```

If this is low relative to `getVaultBalance()`, withdrawals may start reverting.

### 4. Failed transactions

Monitor the block explorer for failed transactions to the vault address. Frequent reverts on `withdraw` may indicate Aave liquidity constraints.

---

## Fee Collection

Fees are sent to `treasury` at the time of each withdrawal. There is no fee accumulation inside the vault — each `Withdrawn` event records the fee paid:

```solidity
event Withdrawn(address indexed user, uint256 shares, uint256 grossAssets, uint256 fee, uint256 payout);
```

To calculate total fees collected on a network, query historical `Withdrawn` events and sum the `fee` field:

```bash
cast logs --address $VAULT \
  --event "Withdrawn(address,uint256,uint256,uint256,uint256)" \
  --from-block $DEPLOY_BLOCK \
  --rpc-url $RPC
```

Or use the block explorer's "Events" tab filtered to the `Withdrawn` event signature.

The treasury address cannot be changed after deployment. If the treasury needs to change, a re-deployment is required.

---

## Incident Response

### Aave liquidity crunch

**Symptom:** User `withdraw` calls revert with a low-level error from `aavePool.withdraw`.

**Cause:** Aave's pool utilisation is near 100% — all USDC is currently borrowed.

**Response:**
1. Check Aave's utilisation rate on their dashboard
2. Inform users that withdrawals are temporarily unavailable
3. Monitor until utilisation drops (borrowers repay or more suppliers enter)
4. No contract action is needed — withdrawals automatically succeed once liquidity returns

**This is not a vault bug.** It is an expected condition under extreme Aave usage.

### Aave V3 security incident

**Symptom:** Aave announces a vulnerability, pauses the protocol, or funds move unexpectedly.

**Response:**
1. Assess whether Aave has paused the relevant pool — if so, deposits and withdrawals via the vault are also paused (they revert)
2. Monitor Aave governance and security disclosures
3. If funds are at risk, Aave's emergency mechanism may freeze the pool
4. Communicate status to users immediately
5. If Aave migrates to a new pool contract, a vault re-deployment is required pointing to the new pool address

The vault cannot be patched in-place. A migration plan (see below) is the only remediation path if the Aave integration is permanently broken.

### USDC depeg or Circle issue

**Symptom:** USDC trades significantly below $1.00, or Circle freezes transfers.

**Response:**
1. If Circle blacklists the vault address, all deposits and withdrawals fail permanently — a new vault contract would need to be deployed at a different address
2. If USDC depegs, user funds are still denominated in USDC — the vault has no USD guarantee, only USDC
3. Communicate the risk to users and refer to Circle's official announcements

### Bug in YieldSaveVault

**Symptom:** A logic error is found in the contract.

**Response:**
1. Assess whether the bug is exploitable in its current state
2. If actively being exploited: contact Aave to pause the pool if necessary; communicate to users to withdraw immediately
3. Deploy a fixed contract (see re-deployment below)
4. Communicate the issue transparently, including the vulnerability and timeline

---

## Re-Deployment and Migration

Because `YieldSaveVault` is immutable, any bug fix, parameter change, or feature upgrade requires deploying a new contract and migrating user funds.

### Steps for re-deployment

1. **Deploy the new contract** following the [Deployment Guide](deployment.md)
2. **Announce migration** to users with a clear deadline — e.g., "withdraw from old vault before DATE"
3. **Update the frontend** to point to the new vault address (in `deployments/{network}.json`)
4. **Do not destroy the old vault** — users who miss the deadline can still withdraw directly on-chain via the block explorer

### Assisted migration

If the situation requires assisting users in moving funds (e.g., the old vault has a bug that prevents withdrawal but funds are recoverable):

- This must be done entirely via on-chain user-initiated transactions
- The vault has no admin function to move user funds on their behalf
- Communicate exact steps for users to call `withdraw` with their share balance

### Updating the deployment record

After deploying a replacement, update `deployments/{network}.json` with the new address and commit it:

```json
{
  "vault": "0xNewVaultAddress",
  "chainId": 84532,
  "block": 99999999,
  "previous": "0xOldVaultAddress"
}
```

Adding `previous` preserves the audit trail.

---

## Routine Operations

### Updating Aave addresses for a new pool version

If Aave V3 migrates to a new pool contract:
1. Obtain the new `Pool`, `USDC`, and `aUSDC` addresses from the Aave address book
2. Update `.env` with the new addresses
3. Deploy a new vault pointing to the new addresses
4. Migrate users as above

### Checking deployment integrity

Periodically verify that immutable parameters on deployed vaults match expected values:

```bash
VAULT=0x...
RPC=...

echo "USDC:     $(cast call $VAULT 'usdc()(address)' --rpc-url $RPC)"
echo "aUSDC:    $(cast call $VAULT 'aUsdc()(address)' --rpc-url $RPC)"
echo "Pool:     $(cast call $VAULT 'aavePool()(address)' --rpc-url $RPC)"
echo "Treasury: $(cast call $VAULT 'treasury()(address)' --rpc-url $RPC)"
echo "Fee BPS:  $(cast call $VAULT 'feeRate()(uint256)' --rpc-url $RPC)"
```

Compare against `deployments/{network}.json` and the known Aave addresses.

---

## Known Limitations

| Limitation | Implication |
|---|---|
| Immutable `treasury` | Fee recipient cannot be changed without re-deployment |
| Immutable `feeRate` | Fee rate cannot be adjusted without re-deployment |
| No emergency pause | Cannot halt deposits/withdrawals (must rely on Aave's pause if Aave is the issue) |
| No share transferability | User positions cannot be transferred or used as collateral |
| Single asset (USDC) | Adding new deposit assets requires a new vault contract |
| No yield strategy selection | Yield source is fixed to Aave V3 at deployment |

These are deliberate simplifications for the MVP. They can be addressed in future versions through new deployments.
