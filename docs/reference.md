# Contract Reference

## YieldSaveVault

**Source:** [src/YieldSaveVault.sol](../src/YieldSaveVault.sol)  
**Compiler:** Solidity 0.8.30  
**License:** MIT

### Deployed Addresses

| Network | Chain ID | Address |
|---|---|---|
| Sepolia | 11155111 | `0x6C2Df464b38e92Ec8d01f8BEaF621f1ad894C107` |
| Base Sepolia | 84532 | `0xC0aAd48188dabF8d5B33e30A0946d79d5C8F6323` |

---

## Constructor

```solidity
constructor(
    address usdc_,
    address aUsdc_,
    address aavePool_,
    address treasury_,
    uint256 feeRate_
)
```

All parameters are validated at construction and stored as immutables — they cannot change after deployment.

| Parameter | Type | Validation | Description |
|---|---|---|---|
| `usdc_` | `address` | `!= address(0)` | The ERC-20 deposit/withdrawal token (USDC) |
| `aUsdc_` | `address` | `!= address(0)` | Aave's interest-bearing wrapper token (aUSDC) |
| `aavePool_` | `address` | `!= address(0)` | Aave V3 Pool contract |
| `treasury_` | `address` | `!= address(0)` | Recipient of protocol fees |
| `feeRate_` | `uint256` | `<= MAX_FEE_BPS` | Fee rate in basis points (e.g. `500` = 5%) |

---

## Constants

```solidity
uint256 public constant BPS_DENOMINATOR = 10_000;
uint256 public constant MAX_FEE_BPS     = 1_000;
```

| Name | Value | Description |
|---|---|---|
| `BPS_DENOMINATOR` | `10_000` | Denominator for basis point calculations |
| `MAX_FEE_BPS` | `1_000` | Maximum fee rate allowed at construction (10%) |

---

## Immutable State

```solidity
IERC20  public immutable usdc;
IERC20  public immutable aUsdc;
IPool   public immutable aavePool;
address public immutable treasury;
uint256 public immutable feeRate;
```

| Variable | Type | Description |
|---|---|---|
| `usdc` | `IERC20` | The deposit token |
| `aUsdc` | `IERC20` | Aave's aUSDC (yield-bearing wrapper) |
| `aavePool` | `IPool` | Aave V3 Pool |
| `treasury` | `address` | Fee recipient |
| `feeRate` | `uint256` | Protocol fee rate in basis points |

---

## Mutable State

```solidity
uint256 public totalShares;
mapping(address => uint256) public userShares;
mapping(address => uint256) public userDeposits;
```

| Variable | Type | Description |
|---|---|---|
| `totalShares` | `uint256` | Sum of all shares across all users |
| `userShares` | `mapping(address => uint256)` | Share balance per user |
| `userDeposits` | `mapping(address => uint256)` | Original principal deposited per user (in USDC, 6 decimals) |

`totalAssets` is **not** stored — it is always read live from `aUsdc.balanceOf(address(this))`.

---

## Write Functions

### deposit

```solidity
function deposit(uint256 amount) external nonReentrant returns (uint256 shares)
```

Transfers `amount` USDC from `msg.sender` into the vault and supplies it to Aave V3. Mints `shares` proportional to the current share price and assigns them to `msg.sender`.

**Parameters:**

| Name | Type | Description |
|---|---|---|
| `amount` | `uint256` | USDC amount to deposit (6 decimals) |

**Returns:**

| Name | Type | Description |
|---|---|---|
| `shares` | `uint256` | Vault shares minted to `msg.sender` |

**Reverts:**

| Error | Condition |
|---|---|
| `ZeroAmount` | `amount == 0` |
| `ZeroSharesMinted` | deposit rounds to 0 shares (only possible with dust amounts after large yield accrual) |
| `ERC20CallFailed` | `usdc.transferFrom` or `usdc.approve` fails |

**Requirements:** Caller must have approved the vault to spend at least `amount` USDC before calling.

**Emits:** `Deposited(msg.sender, amount, shares)`

---

### withdraw

```solidity
function withdraw(uint256 shares) external nonReentrant returns (uint256 payout)
```

Redeems `shares` from `msg.sender`, withdraws the corresponding USDC from Aave, deducts the protocol fee from the yield portion, and sends the net payout to `msg.sender`. The fee is sent to `treasury`.

**Parameters:**

| Name | Type | Description |
|---|---|---|
| `shares` | `uint256` | Number of vault shares to redeem |

**Returns:**

| Name | Type | Description |
|---|---|---|
| `payout` | `uint256` | USDC received by `msg.sender` (after fee) |

**Reverts:**

| Error | Condition |
|---|---|
| `ZeroAmount` | `shares == 0` |
| `InsufficientShares` | `shares > userShares[msg.sender]` |
| `ERC20CallFailed` | any USDC transfer fails |

**Emits:** `Withdrawn(msg.sender, shares, grossAssets, fee, payout)`

---

## View Functions

### getVaultBalance

```solidity
function getVaultBalance() external view returns (uint256)
```

Returns the total aUSDC balance held by the vault. This equals the sum of all user deposits plus all accrued Aave yield, minus any past withdrawals.

---

### getUserBalance

```solidity
function getUserBalance(address user) external view returns (uint256)
```

Returns the net USDC amount `user` would receive if they called `withdraw` with all their shares right now. Returns `0` if the user has no shares.

The returned value accounts for the protocol fee on any yield.

---

### previewDeposit

```solidity
function previewDeposit(uint256 amount) external view returns (uint256)
```

Returns the number of shares that would be minted for a deposit of `amount` USDC at the current share price.

---

### previewWithdraw

```solidity
function previewWithdraw(uint256 shares) external view returns (uint256)
```

Returns the payout `msg.sender` would receive for redeeming `shares`. Returns `0` if the caller has fewer than `shares`.

---

### previewWithdrawFor

```solidity
function previewWithdrawFor(address user, uint256 shares)
    external
    view
    returns (uint256 payout, uint256 grossAssets, uint256 fee)
```

Full withdrawal preview for any `user`. Returns all three components of the withdrawal calculation.

| Return | Type | Description |
|---|---|---|
| `payout` | `uint256` | Net USDC `user` would receive |
| `grossAssets` | `uint256` | USDC value of `shares` before fee |
| `fee` | `uint256` | Protocol fee amount |

---

## Events

### Deposited

```solidity
event Deposited(address indexed user, uint256 assets, uint256 shares)
```

Emitted on every successful `deposit` call.

| Parameter | Type | Description |
|---|---|---|
| `user` | `address` (indexed) | Depositing address |
| `assets` | `uint256` | USDC deposited |
| `shares` | `uint256` | Vault shares minted |

---

### Withdrawn

```solidity
event Withdrawn(
    address indexed user,
    uint256 shares,
    uint256 grossAssets,
    uint256 fee,
    uint256 payout
)
```

Emitted on every successful `withdraw` call.

| Parameter | Type | Description |
|---|---|---|
| `user` | `address` (indexed) | Withdrawing address |
| `shares` | `uint256` | Shares redeemed |
| `grossAssets` | `uint256` | USDC value of those shares before fee |
| `fee` | `uint256` | Protocol fee paid to treasury |
| `payout` | `uint256` | Net USDC sent to user (`grossAssets - fee`) |

---

## Custom Errors

```solidity
error ZeroAddress();
error ZeroAmount();
error InvalidFeeRate();
error InsufficientShares();
error ZeroSharesMinted();
error ERC20CallFailed();
```

| Error | Selector | When |
|---|---|---|
| `ZeroAddress` | `0xd92e233d` | Constructor receives `address(0)` for any parameter |
| `ZeroAmount` | `0x1f2a2005` | `deposit` or `withdraw` called with `0` |
| `InvalidFeeRate` | — | Constructor `feeRate_` exceeds `MAX_FEE_BPS` |
| `InsufficientShares` | — | `withdraw` requested more shares than the caller holds |
| `ZeroSharesMinted` | — | `deposit` amount rounds to 0 shares |
| `ERC20CallFailed` | — | Any low-level ERC-20 call returns `false` or reverts |

---

## Interfaces

### IERC20

```solidity
// src/interfaces/IERC20.sol
interface IERC20 {
    function transfer(address to, uint256 value) external returns (bool);
    function approve(address spender, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function totalSupply() external view returns (uint256);
}
```

### IPool

```solidity
// src/interfaces/IPool.sol
interface IPool {
    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
    function withdraw(address asset, uint256 amount, address to) external returns (uint256);
}
```

---

## ABI (JSON)

The compiled ABI is written to `out/YieldSaveVault.sol/YieldSaveVault.json` after `forge build`. The relevant subset for frontend integration:

```json
[
  {
    "type": "function",
    "name": "deposit",
    "inputs": [{ "name": "amount", "type": "uint256" }],
    "outputs": [{ "name": "shares", "type": "uint256" }],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "withdraw",
    "inputs": [{ "name": "shares", "type": "uint256" }],
    "outputs": [{ "name": "payout", "type": "uint256" }],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "getVaultBalance",
    "inputs": [],
    "outputs": [{ "name": "", "type": "uint256" }],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getUserBalance",
    "inputs": [{ "name": "user", "type": "address" }],
    "outputs": [{ "name": "", "type": "uint256" }],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "previewDeposit",
    "inputs": [{ "name": "amount", "type": "uint256" }],
    "outputs": [{ "name": "", "type": "uint256" }],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "previewWithdraw",
    "inputs": [{ "name": "shares", "type": "uint256" }],
    "outputs": [{ "name": "", "type": "uint256" }],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "previewWithdrawFor",
    "inputs": [
      { "name": "user", "type": "address" },
      { "name": "shares", "type": "uint256" }
    ],
    "outputs": [
      { "name": "payout", "type": "uint256" },
      { "name": "grossAssets", "type": "uint256" },
      { "name": "fee", "type": "uint256" }
    ],
    "stateMutability": "view"
  },
  {
    "type": "event",
    "name": "Deposited",
    "inputs": [
      { "name": "user", "type": "address", "indexed": true },
      { "name": "assets", "type": "uint256", "indexed": false },
      { "name": "shares", "type": "uint256", "indexed": false }
    ]
  },
  {
    "type": "event",
    "name": "Withdrawn",
    "inputs": [
      { "name": "user", "type": "address", "indexed": true },
      { "name": "shares", "type": "uint256", "indexed": false },
      { "name": "grossAssets", "type": "uint256", "indexed": false },
      { "name": "fee", "type": "uint256", "indexed": false },
      { "name": "payout", "type": "uint256", "indexed": false }
    ]
  }
]
```

---

## Cast Quick Reference

```bash
VAULT=<vault address>
RPC=<rpc url>

# Read vault state
cast call $VAULT "getVaultBalance()(uint256)"                              --rpc-url $RPC
cast call $VAULT "totalShares()(uint256)"                                  --rpc-url $RPC
cast call $VAULT "feeRate()(uint256)"                                      --rpc-url $RPC
cast call $VAULT "treasury()(address)"                                     --rpc-url $RPC

# Read user state
cast call $VAULT "getUserBalance(address)(uint256)"    $USER               --rpc-url $RPC
cast call $VAULT "userShares(address)(uint256)"        $USER               --rpc-url $RPC
cast call $VAULT "userDeposits(address)(uint256)"      $USER               --rpc-url $RPC

# Preview operations
cast call $VAULT "previewDeposit(uint256)(uint256)"    $AMOUNT             --rpc-url $RPC
cast call $VAULT "previewWithdraw(uint256)(uint256)"   $SHARES             --rpc-url $RPC
cast call $VAULT "previewWithdrawFor(address,uint256)(uint256,uint256,uint256)" \
                                                       $USER $SHARES       --rpc-url $RPC

# Query historical events
cast logs \
  --address $VAULT \
  --event "Deposited(address,uint256,uint256)" \
  --from-block $DEPLOY_BLOCK \
  --rpc-url $RPC

cast logs \
  --address $VAULT \
  --event "Withdrawn(address,uint256,uint256,uint256,uint256)" \
  --from-block $DEPLOY_BLOCK \
  --rpc-url $RPC
```
