# Troubleshooting

## Build Issues

### `forge build` fails with "Source not found"

```
Error: Source "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol" not found
```

**Cause:** Library submodules are not initialised.

**Fix:**
```bash
forge install
# or, if forge install completes but the error persists:
git submodule update --init --recursive
```

---

### `forge build` fails with wrong Solidity version

```
Error: Source file requires different compiler version
```

**Cause:** Your local `solc` does not match the version pinned in `foundry.toml` (`solc = "0.8.30"`).

**Fix:**
```bash
foundryup          # updates forge/cast/anvil to latest
# Foundry manages its own solc binaries — it will download 0.8.30 automatically on next build
forge build
```

---

### Remapping errors (imports not resolved)

```
Error: No such file or directory: lib/forge-std/src/Test.sol
```

**Cause:** `remappings.txt` is present but the `lib/` directory is missing or incomplete.

**Fix:**
```bash
forge install
cat remappings.txt   # confirm it contains: forge-std/=lib/forge-std/src/
```

---

## Test Failures

### Fork tests are skipped / "no tests matched"

**Cause:** `BASE_SEPOLIA_RPC_URL` is not set, so fork tests skip themselves.

**Fix:**
```bash
# Add to .env:
BASE_SEPOLIA_RPC_URL=https://base-sepolia.g.alchemy.com/v2/YOUR_KEY

source .env
make fork-base
```

---

### Fork test fails with "connection refused" or timeout

**Cause:** RPC endpoint is unreachable or rate-limited.

**Fix:**
- Confirm the URL in `.env` is correct and the API key is valid
- Try a different RPC provider (Alchemy, Infura, Ankr)
- Check the Alchemy/Infura dashboard for rate limit status

---

### Test fails with "ERC20: insufficient allowance"

**Cause:** The test calls `vault.deposit` but the mock USDC `approve` was not called first.

**Fix:** Ensure the test calls `approve` before `deposit`:

```solidity
vm.prank(alice);
usdc.approve(address(vault), amount);

vm.prank(alice);
vault.deposit(amount);
```

Or use the `_deposit` helper from `Fixtures`, which handles approval internally.

---

### Fuzz test fails with an unexpected revert

**Cause:** The fuzz input is out of a valid range (e.g. `amount = 0` hitting `ZeroAmount`).

**Fix:** Clamp inputs with `bound`:

```solidity
function test_FuzzWithdraw(uint256 shares) public {
    shares = bound(shares, 1, vault.userShares(alice));
    ...
}
```

---

### `vm.expectRevert` does not match

```
Error: Expected revert, but the call succeeded
```

or

```
Error: Reverted with custom error, but expected panic
```

**Cause:** The wrong error selector is used, or the revert happens in a different function than expected.

**Fix:** Use the exact custom error selector:

```solidity
vm.expectRevert(YieldSaveVault.ZeroAmount.selector);
vault.deposit(0);
```

Do not use string selectors for custom errors — they only work for `require`-style reverts.

---

## Deployment Issues

### Deploy fails with "private key not set"

```
Error: environment variable not found: DEPLOYER_PRIVATE_KEY
```

**Fix:** Set `DEPLOYER_PRIVATE_KEY` in `.env` and ensure `.env` is loaded:

```bash
source .env
make deploy NETWORK=sepolia
```

The Makefile `include .env` loads the file automatically when using `make`. Direct `forge` commands need `source .env` first.

---

### Deploy fails with "insufficient funds"

**Cause:** The deployer wallet does not hold enough native token (ETH on Sepolia, ETH on Base Sepolia) to pay for gas.

**Fix:**
- Sepolia ETH faucet: [sepoliafaucet.com](https://sepoliafaucet.com) or Alchemy faucet
- Base Sepolia ETH: bridge from Sepolia or use the Coinbase faucet

---

### Etherscan verification fails after deployment

```
Error: Contract source code already verified
```
or
```
Error: Unable to verify — Rate limited
```

**Fix:** Re-run verification separately:

```bash
make verify NETWORK=sepolia ADDRESS=0xYourVaultAddress
```

If Etherscan is rate-limiting, wait a few minutes and retry. Verification is cosmetic — the contract is deployed and functional regardless.

---

### Deployment writes to wrong `deployments/` file

**Cause:** The wrong `NETWORK` was passed to `make deploy`, or `block.chainid` in the script doesn't match the expected network.

**Fix:**
```bash
# Check which chain the RPC connects to
cast chain-id --rpc-url $YOUR_RPC_URL

# Confirm it matches what Deploy.s.sol expects:
# 11155111 = Sepolia, 84532 = Base Sepolia
```

---

### `make deploy NETWORK=mainnet` fails — unsupported chain

**Cause:** Mainnet (`chainId == 1`) is not yet handled in `_loadNetworkConfig` in `Deploy.s.sol`.

**Fix:** Add mainnet address support to the script before deploying. See the [Deployment Guide — Adding a New Network](deployment.md#adding-a-new-network).

---

## On-Chain Issues

### `withdraw` reverts — Aave liquidity crunch

```
Error: execution reverted
```

When calling `vault.withdraw` on a live network and Aave's withdraw reverts, the most likely cause is high utilisation (all USDC is lent out).

**Diagnosis:**
```bash
# Check aUSDC balance in Aave's pool (withdrawable liquidity)
cast call $AUSDC "balanceOf(address)(uint256)" $AAVE_POOL --rpc-url $RPC
```

If this value is low relative to the vault's total assets, withdrawals are temporarily blocked by Aave.

**Resolution:** Wait for borrowers to repay. No contract action is needed.

---

### `deposit` or `withdraw` reverts with `ERC20CallFailed`

**Cause:** A low-level ERC-20 call failed. Possible reasons:
- USDC allowance not set before deposit
- Caller's USDC balance is lower than `amount`
- Circle has blacklisted the vault or user address (rare)

**Diagnosis:**
```bash
# Check USDC allowance
cast call $USDC "allowance(address,address)(uint256)" $USER $VAULT --rpc-url $RPC

# Check USDC balance
cast call $USDC "balanceOf(address)(uint256)" $USER --rpc-url $RPC
```

---

### User balance shows 0 but shares are non-zero

**Cause:** `getUserBalance` calls `previewWithdrawFor`, which returns `0` when `shares > userShares[user]`. This should not be possible through normal usage.

**Diagnosis:**
```bash
cast call $VAULT "userShares(address)(uint256)" $USER --rpc-url $RPC
cast call $VAULT "totalShares()(uint256)" --rpc-url $RPC
cast call $VAULT "getVaultBalance()(uint256)" --rpc-url $RPC
```

If `userShares > 0` and `getVaultBalance > 0`, the user does have a positive balance — call `previewWithdrawFor` with the exact share amount.

---

## Environment / Toolchain

### `make` fails with "Makefile:12: .env: No such file or directory"

**Fix:**
```bash
cp .env.example .env
# then fill in the values you need
```

---

### `forge test --watch` does not detect file changes on macOS

**Cause:** Foundry's file watcher may not work with some macOS configurations.

**Fix:** Use `nodemon` as a workaround:
```bash
brew install nodemon
nodemon --watch src --watch test --ext sol --exec "forge test"
```

---

### `cast` returns raw hex instead of decoded values

**Fix:** Include the return type in the function signature:

```bash
# Wrong (returns raw hex)
cast call $VAULT "getVaultBalance()" --rpc-url $RPC

# Correct (decoded uint256)
cast call $VAULT "getVaultBalance()(uint256)" --rpc-url $RPC
```

---

## Getting More Help

- **Foundry documentation:** [book.getfoundry.sh](https://book.getfoundry.sh)
- **Aave V3 developer docs:** [docs.aave.com/developers](https://docs.aave.com/developers)
- **OpenZeppelin contracts:** [docs.openzeppelin.com/contracts](https://docs.openzeppelin.com/contracts)
- **Open a bug report:** [GitHub Issues](https://github.com/your-org/ys-contracts/issues)
