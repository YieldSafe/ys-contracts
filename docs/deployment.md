# Deployment Guide

## Overview

Deployment is handled by `script/Deploy.s.sol`. The script:
1. Reads configuration from environment variables
2. Detects the target network from `block.chainid`
3. Deploys `YieldSaveVault` with the correct Aave addresses for that network
4. Writes a deployment record to `deployments/{network}.json`

All deployment commands are wrapped in the `Makefile`. The `NETWORK` variable selects the target.

---

## Pre-Deployment Checklist

Before deploying to any network:

- [ ] `.env` is populated with all required variables for the target network
- [ ] `TREASURY` is set to a verified, controlled address (fees flow here permanently — it cannot be changed after deployment)
- [ ] `FEE_RATE_BPS` is confirmed (default `500` = 5%; max `1000` = 10%)
- [ ] Aave V3 addresses for the target network are correct (USDC, aUSDC, Pool)
- [ ] Deployer wallet has sufficient gas
- [ ] `forge build` passes cleanly
- [ ] `forge test` passes cleanly

---

## Local Deployment (Anvil)

Use Anvil for development and manual testing.

```bash
# Terminal 1 — start the local node
make anvil

# Terminal 2 — deploy
make deploy NETWORK=anvil
```

Anvil uses `PRIVATE_KEY` from `.env`. Any of Anvil's default private keys work.

After deployment, the vault address is printed to stdout and written to `deployments/anvil.json` (this file is gitignored).

---

## Sepolia Deployment

```bash
make deploy NETWORK=sepolia
```

**Required `.env` variables:**

```bash
DEPLOYER_PRIVATE_KEY=0x...       # Must hold Sepolia ETH for gas
TREASURY=0x...
SEPOLIA_RPC_URL=https://...
ETHERSCAN_API_KEY=...
SEPOLIA_USDC=0x...
SEPOLIA_AUSDC=0x...
SEPOLIA_AAVE_POOL=0x...
FEE_RATE_BPS=500
```

The `--verify` flag is included automatically. Etherscan verification happens as part of the same command. If verification fails (e.g., rate limiting), re-run manually:

```bash
make verify NETWORK=sepolia ADDRESS=0xYourVaultAddress
```

---

## Base Sepolia Deployment

```bash
make deploy NETWORK=base-sepolia
```

**Required `.env` variables:**

```bash
DEPLOYER_PRIVATE_KEY=0x...
TREASURY=0x...
BASE_SEPOLIA_RPC_URL=https://...
ETHERSCAN_API_KEY=...            # Used as the Blockscout API key
BASE_SEPOLIA_USDC=0x...
BASE_SEPOLIA_AUSDC=0x...
BASE_SEPOLIA_AAVE_POOL=0x...
FEE_RATE_BPS=500
```

Verification uses Blockscout (`--verifier blockscout --verifier-url https://base-sepolia.blockscout.com/api/`). If it fails:

```bash
make verify NETWORK=base-sepolia ADDRESS=0xYourVaultAddress
```

---

## Mainnet Deployment

> **Warning:** Mainnet deployment is irreversible. All parameters are immutable. Double-check everything.

```bash
make deploy NETWORK=mainnet
```

The Makefile requires `MAINNET_RPC_URL` in `.env`. No mainnet Aave address env vars are pre-configured — add them before deploying:

```bash
MAINNET_USDC=0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
MAINNET_AUSDC=0x98C23E9d8f34FEFb1B7BD6a91B7CF122b3EB2110
MAINNET_AAVE_POOL=0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2
```

Then update `_loadNetworkConfig` in `script/Deploy.s.sol` to handle `chainId == 1` and read these addresses.

**Pre-mainnet checklist (additional):**
- [ ] Independent security audit completed
- [ ] Deploy to testnet first and verify with fork tests
- [ ] Treasury address is a multisig, not an EOA
- [ ] Deployment dry-run with `--dry-run` flag reviewed
- [ ] Team review of final deployment transaction

---

## Adding a New Network

1. **Add Aave addresses to `.env.example`** for the new network:

```bash
NEWNET_USDC=
NEWNET_AUSDC=
NEWNET_AAVE_POOL=
NEWNET_RPC_URL=
```

2. **Add a `chainId` branch to `_loadNetworkConfig`** in `script/Deploy.s.sol`:

```solidity
if (chainId == 99999) {
    return (
        vm.envAddress("NEWNET_USDC"),
        vm.envAddress("NEWNET_AUSDC"),
        vm.envAddress("NEWNET_AAVE_POOL"),
        "newnet"
    );
}
```

3. **Add a `deployments/newnet.json` placeholder**:

```json
{}
```

4. **Add a Makefile target** for deploy and verify with the correct RPC and verifier flags.

5. **Add an RPC endpoint** to `foundry.toml`:

```toml
[rpc_endpoints]
newnet = "${NEWNET_RPC_URL}"
```

---

## Deployment Records

After a successful deployment, `Deploy.s.sol` writes a JSON file to `deployments/`:

```json
{
  "vault": "0xC0aAd48188dabF8d5B33e30A0946d79d5C8F6323",
  "chainId": 84532,
  "block": 40872728
}
```

These files are committed to the repository. The frontend reads them to resolve the vault address per network.

The `deployments/` directory has read-write filesystem access granted in `foundry.toml`:

```toml
fs_permissions = [{ access = "read-write", path = "./deployments" }]
```

---

## Post-Deployment Checklist

After deploying to any network:

- [ ] Vault address in `deployments/{network}.json` matches the on-chain deployment
- [ ] Contract is verified on the block explorer (source code visible)
- [ ] `getVaultBalance()` returns 0 (empty vault, correct state)
- [ ] Run a test deposit via `cast` or the frontend to confirm basic operation
- [ ] Confirm aUSDC balance of vault matches deposit amount after one block
- [ ] Confirm withdrawal returns correct payout
- [ ] Treasury address confirmed via `vault.treasury()` read

```bash
# Verify deployed parameters
cast call $VAULT "usdc()(address)" --rpc-url $RPC
cast call $VAULT "aUsdc()(address)" --rpc-url $RPC
cast call $VAULT "aavePool()(address)" --rpc-url $RPC
cast call $VAULT "treasury()(address)" --rpc-url $RPC
cast call $VAULT "feeRate()(uint256)" --rpc-url $RPC
```

---

## Verifying Aave Addresses

Before deploying, confirm Aave contract addresses are correct for the target network:

```bash
# Run the address verification script
forge script script/VerifyAddresses.s.sol --rpc-url $TARGET_RPC_URL
```

This logs the USDC, aUSDC, and Pool addresses loaded from your `.env`. Cross-check them against the [Aave V3 address book](https://github.com/bgd-labs/aave-address-book).
