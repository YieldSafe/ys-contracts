# YieldSave — Complete Guide

> **Your savings, always earning.**
> A non-custodial DeFi vault that automatically puts your USDC to work in Aave V3 — earning yield with no lock-up, no bank, and no middleman.

---

## Table of Contents

1. [What is YieldSave?](#1-what-is-yieldsave)
2. [How It Works](#2-how-it-works)
3. [Getting Started (User Guide)](#3-getting-started-user-guide)
4. [Revenue Model — For the Protocol](#4-revenue-model--for-the-protocol)
5. [Value Delivered — For Users](#5-value-delivered--for-users)
6. [Fee Transparency & Examples](#6-fee-transparency--examples)
7. [Smart Contract Architecture](#7-smart-contract-architecture)
8. [ERC-4626 & the Share Model](#8-erc-4626--the-share-model)
9. [Security & Trust](#9-security--trust)
10. [Developer Reference](#10-developer-reference)
11. [Project Folder Structure](#11-project-folder-structure)
12. [Roadmap](#12-roadmap)
13. [FAQ](#13-faq)

---

## 1. What is YieldSave?

YieldSave is a **non-custodial savings protocol** built on Ethereum. It lets anyone with USDC automatically earn DeFi yield by depositing into a smart contract vault, which routes funds into **Aave V3** — one of the most battle-tested lending protocols in DeFi with over $10B in Total Value Locked.

### The one-line pitch

> Deposit USDC. Earn yield automatically. Withdraw anytime — principal plus interest, guaranteed.

### What makes it different from a bank savings account

| Feature                | Traditional Bank  | YieldSave                          |
| ---------------------- | ----------------- | ---------------------------------- |
| Typical APY            | ~0.5%             | ~4–8% (Aave market rate)           |
| Lock-up period         | Often required    | None — withdraw anytime            |
| Minimum balance        | Often required    | None                               |
| Who holds your money   | The bank          | A smart contract — no one          |
| Geographic restriction | Yes (KYC, region) | No — wallet + USDC is all you need |
| Auditable              | No                | Yes — every transaction on-chain   |
| Earning starts         | Next business day | Next Ethereum block (~12 seconds)  |

### What makes it different from using Aave directly

Aave is powerful but technical. Using it directly requires understanding aTokens, gas management, and DeFi mechanics. YieldSave abstracts all of that away. Users deposit USDC and withdraw USDC — they never need to know what aUSDC is or how supply rates work.

---

## 2. How It Works

### The deposit flow

```
User approves YieldSaveVault to spend USDC
         ↓
User calls deposit(amount)
         ↓
Vault transfers USDC from user wallet
         ↓
Vault approves Aave Pool and calls pool.supply()
         ↓
Aave mints aUSDC to the vault (interest-bearing token)
         ↓
Vault calculates and records user's shares
         ↓
User's position is now earning yield — every block
```

### The yield accrual (no transaction needed)

Aave's aUSDC balance increases every Ethereum block. Because the vault holds aUSDC, its `totalAssets` grows automatically. A user's USDC claim = their shares × (totalAssets / totalShares). This grows passively — no staking, no claiming, no action required.

### The withdrawal flow

```
User calls withdraw(shares)
         ↓
Vault calculates user's gross USDC claim
         ↓
Vault isolates yield earned (gross − original deposit)
         ↓
Protocol fee deducted from yield only (never principal)
         ↓
Vault calls pool.withdraw() on Aave
         ↓
Aave burns aUSDC and returns USDC to vault
         ↓
Vault sends net USDC to user
         ↓
Vault sends fee to treasury
         ↓
User's shares are burned
```

---

## 3. Getting Started (User Guide)

### What you need before you start

- A crypto wallet (MetaMask, Coinbase Wallet, Rainbow, or any WalletConnect-compatible wallet)
- USDC on the supported network (Sepolia testnet for MVP; Base/Optimism for mainnet)
- A small amount of ETH for gas fees (usually less than $0.50 on L2s)

### Step 1 — Connect your wallet

Open the YieldSave app and click **Connect Wallet**. Select your wallet provider. Approve the connection request in your wallet. Your USDC balance will appear on the dashboard.

### Step 2 — Approve USDC spending

Before depositing, you must give the YieldSave vault permission to move your USDC. Click **Approve** and confirm the transaction in your wallet. This is a one-time step per wallet. You set the approval amount — you can approve exactly what you want to deposit, or approve a larger amount to avoid doing this step again later.

> **Why is this needed?** ERC-20 tokens (like USDC) require explicit permission before a contract can move them on your behalf. This is a security feature, not a limitation.

### Step 3 — Deposit

Enter the amount of USDC you want to deposit and click **Deposit**. Confirm the transaction in your wallet. Once the transaction is confirmed (usually within 15 seconds on L2s), your savings balance will appear on the dashboard.

### Step 4 — Watch your balance grow

Your **Saved Balance** on the dashboard updates to reflect real-time yield. The difference between your saved balance and your original deposit is your **Estimated Yield**. This increases every block — roughly every 12 seconds.

### Step 5 — Withdraw

When you want to access your funds, click **Withdraw**, enter the amount of shares to redeem (or click Max to withdraw everything), and confirm the transaction. You will receive your original deposit plus all accrued yield, minus the protocol fee on yield only. Funds arrive in your wallet in the same transaction.

### Dashboard at a glance

```
┌─────────────────────────────────────────┐
│  Wallet Balance      1,000.00 USDC      │
│  Saved Balance         204.82 USDC      │
│  Original Deposit      200.00 USDC      │
│  Yield Earned            4.82 USDC      │
│  Protocol Fee (est.)     0.24 USDC      │
│  Your Net Gain           4.58 USDC      │
│                                         │
│  [ Deposit ]        [ Withdraw ]        │
└─────────────────────────────────────────┘
```

---

## 4. Revenue Model — For the Protocol

YieldSave is designed to be financially sustainable. The protocol earns revenue by taking a **percentage cut of yield only** — never of principal. This aligns incentives perfectly: YieldSave only makes money when users make money.

### The fee structure

| Fee type             | Rate       | Applied to        | When collected     |
| -------------------- | ---------- | ----------------- | ------------------ |
| Protocol yield fee   | 5%         | Yield earned only | At withdrawal      |
| Strategy routing fee | 0.1%       | Yield (Phase 2+)  | At withdrawal      |
| Whitelabel fee       | Negotiated | TVL-based         | Monthly (Phase 3+) |

> The 5% rate is set in basis points in the contract: `feeRate = 500`. This can be adjusted via governance in later phases, subject to a maximum cap hard-coded at deployment.

### How the fee is calculated in the contract

```solidity
uint256 public feeRate = 500;            // 5% (500 basis points out of 10,000)
address public treasury;                  // YieldSave revenue address
mapping(address => uint256) public userDeposits;  // tracks original principal

// Inside withdraw():
uint256 gross     = shares * totalAssets / totalShares;
uint256 principal = userDeposits[msg.sender];
uint256 yld       = gross > principal ? gross - principal : 0;
uint256 fee       = (yld * feeRate) / 10000;
uint256 payout    = gross - fee;

usdc.transfer(msg.sender, payout);           // user receives principal + net yield
if (fee > 0) usdc.transfer(treasury, fee);  // protocol collects fee
```

### Why this model is fair

- **Fee is only on profit.** If a user deposits $500 and withdraws $500 (because yield was zero), they pay $0 in fees.
- **Principal is sacred.** The contract mathematically cannot deduct from principal — `yld` is clamped to zero if `gross <= principal`.
- **Transparent on-chain.** Every fee transfer is a public blockchain transaction. Nothing is hidden.
- **Aligns incentives.** YieldSave only earns when the protocol delivers yield to users. A protocol that stops generating yield stops generating revenue.

### Revenue projections

| TVL   | Aave APY (est.) | Annual user yield | Annual protocol revenue (5%) |
| ----- | --------------- | ----------------- | ---------------------------- |
| $500K | 5%              | $25,000           | $1,250                       |
| $1M   | 5%              | $50,000           | $2,500                       |
| $10M  | 5%              | $500,000          | $25,000                      |
| $50M  | 5%              | $2,500,000        | $125,000                     |
| $100M | 5%              | $5,000,000        | $250,000                     |

Revenue scales linearly with TVL and with Aave's supply APY. There is no infrastructure cost increase at scale — the same contract handles $1M and $100M.

### Future revenue streams

**Phase 2 — Strategy routing fee**
When the vault can route between multiple yield sources (Aave, Compound, Morpho), a small additional fee is taken when the vault auto-selects the highest-yielding strategy. Users get better yield; the protocol takes a small cut of the improvement.

**Phase 3 — Whitelabel / institutional API**
Other protocols can deploy a YieldSave vault under their own brand for a monthly TVL-based fee. A neobank or savings app integrating YieldSave as their yield backend would pay a licensing fee — high margin, recurring, no user acquisition cost.

**Long term — Governance token**
A protocol token captures fee value and distributes it to long-term stakeholders. This creates a flywheel: token holders are incentivised to grow TVL, which grows revenue, which grows token value.

---

## 5. Value Delivered — For Users

### Concrete user benefit

At Aave's current USDC supply rate of ~5% APY:

| Deposit | Time      | Gross yield | Protocol fee (5%) | **User keeps** |
| ------- | --------- | ----------- | ----------------- | -------------- |
| $100    | 1 month   | $0.42       | $0.02             | **$0.40**      |
| $100    | 6 months  | $2.50       | $0.13             | **$2.37**      |
| $100    | 12 months | $5.00       | $0.25             | **$4.75**      |
| $1,000  | 12 months | $50.00      | $2.50             | **$47.50**     |
| $10,000 | 12 months | $500.00     | $25.00            | **$475.00**    |

Compare this to a typical bank savings account at 0.5% APY. On $10,000 for 12 months a bank pays $50. YieldSave pays $475 net of fees — **9.5× more**.

### What users never have to worry about

- They never hold aUSDC — they deposit USDC and withdraw USDC
- They never manage gas limits manually — the frontend handles this
- They never understand Aave's supply/borrow mechanics — that's the vault's job
- They never wait for a distribution event — yield is always already in their balance

### User protections built into the contract

- `require(amount > 0)` — prevents zero-value deposits
- `require(userShares[msg.sender] >= shares)` — prevents withdrawing more than you own
- `SafeERC20` transfers — prevents silent failures on token transfers
- Principal protection — fee math is clamped so principal can never be deducted
- No admin withdrawal — the contract has no function that lets the team pull user funds

---

## 6. Fee Transparency & Examples

Every fee is visible before you withdraw. The `previewWithdraw(shares)` function returns exactly how much USDC you will receive, after fees, before you submit any transaction.

### Full worked example

Suppose you deposit **$500 USDC** and withdraw after 8 months when Aave has grown your position to **$521 USDC**.

```
Gross withdrawal amount:     $521.00
Original deposit (principal): $500.00
─────────────────────────────────────
Yield earned:                  $21.00
Protocol fee (5% of yield):    -$1.05
─────────────────────────────────────
You receive:                  $519.95
Treasury receives:               $1.05
```

Your net APY after fees at 5% gross: **~4.75%**. A bank savings account at 0.5% on the same $500 for 8 months would pay $1.67. YieldSave pays $20.95 net — **12.5× more**, even after the fee.

### What happens if yield is zero

If Aave's APY drops to zero (extremely unlikely but theoretically possible), users withdraw exactly their principal. The vault calculates `yld = 0`, fee = $0, and the full deposit is returned. **YieldSave earns nothing in this scenario.**

### What happens if you withdraw early

There is no early withdrawal penalty. The fee is always and only on yield earned. If you deposit and withdraw in the same week and Aave earned $0.01, the fee is $0.0005. You are never punished for withdrawing at any time.

---

## 7. Smart Contract Architecture

### Contract: `YieldSaveVault`

```
YieldSaveVault
├── State
│   ├── IERC20 usdc              — the deposit/withdrawal token
│   ├── IERC20 aUsdc             — Aave's interest-bearing token
│   ├── IPool  aavePool          — Aave V3 pool entrypoint
│   ├── address treasury         — receives protocol fees
│   ├── uint256 feeRate          — basis points (500 = 5%)
│   ├── uint256 totalShares      — total shares in circulation
│   ├── mapping userShares       — each user's share balance
│   └── mapping userDeposits     — each user's original principal
│
├── Write functions
│   ├── deposit(uint256 amount)
│   └── withdraw(uint256 shares)
│
└── Read functions
    ├── getVaultBalance()        — live aUSDC balance (includes all yield)
    ├── getUserBalance(address)  — user's USDC claim including yield, after fee
    ├── previewDeposit(uint256)  — shares to be minted for a given deposit
    └── previewWithdraw(uint256) — USDC to be received for a given share count
```

### Key invariants the contract always maintains

1. `totalAssets = aUsdc.balanceOf(address(this))` — never a stored variable
2. `sum(userShares[all addresses]) = totalShares`
3. `fee` can never exceed `yld` — principal cannot be touched
4. No function exists that allows the deployer to withdraw user funds

### Integration with Aave V3

```solidity
// On deposit — vault supplies to Aave
IERC20(usdc).approve(address(aavePool), amount);
aavePool.supply(address(usdc), amount, address(this), 0);
// Vault now holds aUSDC equal to amount, which grows every block

// On withdrawal — vault pulls from Aave
aavePool.withdraw(address(usdc), amount, address(this));
// aUSDC is burned, vault receives USDC
```

---

## 8. ERC-4626 & the Share Model

ERC-4626 is the Ethereum standard for tokenized yield-bearing vaults, finalised in 2022. It defines a common interface so that any protocol can integrate any compliant vault without custom code.

YieldSave follows ERC-4626 **principles** in its MVP (the share math, deposit/withdraw model, and preview functions) but does not implement the full standard interface. This was a deliberate tradeoff: full ERC-4626 compliance adds significant surface area (mintable/transferable share tokens, additional function signatures) that increases audit complexity for a 4-day build.

### How the share price works

```
Share price = totalAssets / totalShares

Example:
  Day 0: 1,000 USDC deposited, 1,000 shares minted
         share price = 1.000 USDC/share

  Day 180: Aave has grown the vault to 1,050 USDC (5% APY)
           1,000 shares still in circulation
           share price = 1.050 USDC/share

  User redeems 1,000 shares:
           receives 1,050 USDC gross
           fee = (50 USDC yield × 5%) = 2.50 USDC
           user gets 1,047.50 USDC
```

### Why shares beat raw balances

If the vault tracked raw balances (`balance[user] = 100 USDC`), yield distribution would require looping over all depositors and updating each balance — expensive and complex. With shares, yield distribution is implicit: as `totalAssets` grows, every share becomes worth more. Zero gas cost, zero complexity.

### First deposit edge case

If no one has deposited yet (`totalShares == 0`), the formula `shares = amount × totalShares / totalAssets` would produce zero. The contract handles this:

```solidity
if (totalShares == 0) {
    shares = amount;  // 1:1 ratio for the first deposit
} else {
    shares = amount * totalShares / totalAssets;
}
```

---

## 9. Security & Trust

### What the contract can and cannot do

| Action                               | Possible?   | Why                           |
| ------------------------------------ | ----------- | ----------------------------- |
| User withdraws their own funds       | ✅ Yes      | Core function                 |
| Contract takes protocol fee on yield | ✅ Yes      | Coded in withdraw()           |
| Team withdraws user funds            | ❌ No       | No such function exists       |
| Team changes the fee rate            | ⚠️ Phase 2+ | Only via governance, with cap |
| Team upgrades the contract           | ❌ No (MVP) | Contract is not upgradeable   |
| User loses principal to fee          | ❌ No       | Math is clamped — impossible  |

### The non-custodial guarantee

The YieldSave team deploys the contract but has no special privileges to access user funds. The contract is the sole custodian. Even if the entire YieldSave team disappeared tomorrow, every user could withdraw their funds directly by calling `withdraw()` on the contract through Etherscan.

### What risks exist (honesty section)

We believe in full transparency. Here are the real risks:

**Smart contract risk** — The YieldSave contract could have a bug. This is why a security audit is the first use of grant funding. Before mainnet launch, the contract will be audited by an independent firm.

**Aave protocol risk** — YieldSave relies on Aave V3. If Aave had a critical exploit, funds could be at risk. Aave has been live since 2020, has undergone multiple audits, and has a large bug bounty program — but risk is never zero.

**Aave liquidity risk** — If a large portion of Aave's USDC is borrowed and utilisation is extremely high, withdrawal may be delayed until liquidity returns. This is a standard DeFi mechanic and has historically resolved quickly.

**USDC depeg risk** — USDC is issued by Circle and is backed 1:1 by US dollars. In the extremely unlikely event Circle failed, USDC could depeg. This is a systemic stablecoin risk, not specific to YieldSave.

---

## 10. Developer Reference

### Contract addresses

| Network         | Contract       | Address               |
| --------------- | -------------- | --------------------- |
| Sepolia testnet | YieldSaveVault | `[deployed address]`  |
| Sepolia testnet | USDC           | `[Aave testnet USDC]` |
| Sepolia testnet | Aave V3 Pool   | `[Aave Sepolia pool]` |

### ABI — Key functions

```typescript
// deposit
{
  name: "deposit",
  inputs: [{ name: "amount", type: "uint256" }],
  outputs: [],
  stateMutability: "nonpayable"
}

// withdraw
{
  name: "withdraw",
  inputs: [{ name: "shares", type: "uint256" }],
  outputs: [],
  stateMutability: "nonpayable"
}

// getUserBalance
{
  name: "getUserBalance",
  inputs: [{ name: "user", type: "address" }],
  outputs: [{ name: "", type: "uint256" }],
  stateMutability: "view"
}

// previewWithdraw
{
  name: "previewWithdraw",
  inputs: [{ name: "shares", type: "uint256" }],
  outputs: [{ name: "amount", type: "uint256" }],
  stateMutability: "view"
}
```

### Frontend integration (wagmi hooks)

```typescript
import { useReadContract, useWriteContract } from "wagmi";
import { parseUnits, formatUnits } from "viem";
import { VAULT_ABI, VAULT_ADDRESS, USDC_ADDRESS } from "./constants";

// Read user's current balance (includes yield, after fee estimate)
const { data: balance } = useReadContract({
  address: VAULT_ADDRESS,
  abi: VAULT_ABI,
  functionName: "getUserBalance",
  args: [userAddress],
});

// Read user's share balance
const { data: shares } = useReadContract({
  address: VAULT_ADDRESS,
  abi: VAULT_ABI,
  functionName: "userShares",
  args: [userAddress],
});

// Preview how much USDC a withdrawal would return
const { data: preview } = useReadContract({
  address: VAULT_ADDRESS,
  abi: VAULT_ABI,
  functionName: "previewWithdraw",
  args: [shares],
  enabled: !!shares,
});

// Approve USDC spending
const { writeContract: approve } = useWriteContract();
const handleApprove = (amount: bigint) => {
  approve({
    address: USDC_ADDRESS,
    abi: ERC20_ABI,
    functionName: "approve",
    args: [VAULT_ADDRESS, amount],
  });
};

// Deposit USDC
const { writeContract: deposit } = useWriteContract();
const handleDeposit = (amountUsdc: string) => {
  deposit({
    address: VAULT_ADDRESS,
    abi: VAULT_ABI,
    functionName: "deposit",
    args: [parseUnits(amountUsdc, 6)], // USDC has 6 decimals
  });
};

// Withdraw shares
const { writeContract: withdraw } = useWriteContract();
const handleWithdraw = (sharesToRedeem: bigint) => {
  withdraw({
    address: VAULT_ADDRESS,
    abi: VAULT_ABI,
    functionName: "withdraw",
    args: [sharesToRedeem],
  });
};
```

> **Important:** USDC uses 6 decimal places, not 18. Always use `parseUnits(amount, 6)` and `formatUnits(amount, 6)` when handling USDC values.

### Getting test USDC on Sepolia

1. Go to [app.aave.com](https://app.aave.com) and switch to testnet mode
2. Use the Aave faucet to mint test USDC to your wallet
3. You will also need Sepolia ETH for gas — use the Alchemy or Infura faucet

---

## 11. Project Folder Structure

The repository is split into two top-level workspaces: `contracts/` for everything on-chain and `frontend/` for the Next.js app. They are completely independent — Person A and B never touch `frontend/`, Person D never touches `contracts/`.

### Root layout

```
yieldsave/
├── contracts/               # Hardhat or Foundry workspace
├── frontend/                # Next.js + wagmi app
├── .github/
│   └── workflows/
│       ├── test.yml         # runs contract tests on every PR
│       └── lint.yml         # runs eslint + solhint
├── .gitignore
├── README.md                # quick-start for new contributors
└── guide.md                 # this file
```

---

### `contracts/` — Smart contract workspace

```
contracts/
├── src/                          # all Solidity source files
│   ├── YieldSaveVault.sol        # ← Person A owns this entirely
│   └── interfaces/
│       ├── IPool.sol             # Aave V3 pool interface
│       └── IERC20.sol            # standard ERC-20 interface
│
├── test/                         # ← Person B owns this entirely
│   ├── YieldSaveVault.t.sol      # Foundry tests  (or .test.ts for Hardhat)
│   ├── helpers/
│   │   ├── AaveFork.sol          # fork setup — pins Aave Sepolia block
│   │   └── Fixtures.sol          # shared test state (deploy vault, mint USDC)
│   └── scenarios/
│       ├── Deposit.t.sol         # deposit edge cases
│       ├── Withdraw.t.sol        # withdraw + fee calculation edge cases
│       ├── ShareMath.t.sol       # first deposit, zero balance, rounding
│       └── Fee.t.sol             # fee-only-on-yield, zero-yield scenario
│
├── script/                       # ← Person B owns deploy scripts
│   ├── Deploy.s.sol              # deploys YieldSaveVault to target network
│   └── VerifyAddresses.s.sol     # prints Aave addresses for chosen network
│
├── deployments/                  # auto-generated — never edit manually
│   ├── sepolia.json              # { "vault": "0x...", "block": 12345678 }
│   └── base.json                 # populated at mainnet deploy
│
├── lib/                          # git submodules (Foundry) or node_modules
│   ├── forge-std/                # Foundry standard library
│   ├── openzeppelin-contracts/   # SafeERC20, ReentrancyGuard
│   └── aave-v3-core/             # Aave interfaces
│
├── foundry.toml                  # Foundry config — RPC URLs, optimizer, fuzz runs
├── remappings.txt                # import path aliases
└── .env.example                  # template — copy to .env, never commit .env
    # SEPOLIA_RPC_URL=
    # DEPLOYER_PRIVATE_KEY=
    # ETHERSCAN_API_KEY=
```

**Key files explained:**

| File                        | Owner    | Purpose                                                             |
| --------------------------- | -------- | ------------------------------------------------------------------- |
| `src/YieldSaveVault.sol`    | Person A | The entire vault logic — deposit, withdraw, fee, share math         |
| `src/interfaces/IPool.sol`  | Person A | Aave pool interface so the compiler knows `pool.supply()` signature |
| `test/YieldSaveVault.t.sol` | Person B | Main test file — imports fixtures, runs all scenarios               |
| `test/helpers/AaveFork.sol` | Person B | Forks Aave Sepolia at a known block so tests are deterministic      |
| `script/Deploy.s.sol`       | Person B | One-command deploy: `forge script Deploy --broadcast --verify`      |
| `deployments/sepolia.json`  | Person B | Shared contract address — frontend reads this at build time         |

---

### `frontend/` — Next.js app workspace

```
frontend/
├── app/                          # Next.js 14 App Router
│   ├── layout.tsx                # root layout — wraps all pages with WagmiProvider
│   ├── page.tsx                  # home page — renders <Dashboard />
│   ├── providers.tsx             # WagmiProvider + QueryClientProvider setup
│   └── globals.css               # Tailwind base styles
│
├── components/                   # ← Person D owns all of these
│   ├── Dashboard/
│   │   ├── Dashboard.tsx         # top-level layout — composes all panels
│   │   ├── BalanceCard.tsx       # shows Saved Balance, Yield Earned, Net Gain
│   │   ├── WalletCard.tsx        # shows connected wallet + USDC wallet balance
│   │   └── StatsRow.tsx          # vault-wide stats: Total TVL, current APY
│   │
│   ├── Deposit/
│   │   ├── DepositPanel.tsx      # deposit form — amount input + Approve/Deposit buttons
│   │   ├── ApproveButton.tsx     # handles allowance check + approve tx
│   │   └── DepositButton.tsx     # disabled until approved; triggers deposit tx
│   │
│   ├── Withdraw/
│   │   ├── WithdrawPanel.tsx     # withdraw form — share input + preview payout
│   │   ├── WithdrawPreview.tsx   # shows breakdown: gross / fee / you receive
│   │   └── WithdrawButton.tsx    # triggers withdraw tx
│   │
│   ├── Transaction/
│   │   ├── TxToast.tsx           # pending / confirmed / failed toast notifications
│   │   ├── TxStatus.tsx          # inline status indicator for active tx
│   │   └── TxLink.tsx            # "View on Etherscan" link with tx hash
│   │
│   └── ui/                       # shared primitive components
│       ├── Button.tsx            # base button with loading/disabled states
│       ├── Input.tsx             # styled number input with USDC label
│       ├── Card.tsx              # card wrapper with border + padding
│       └── Spinner.tsx           # loading spinner
│
├── hooks/                        # ← Person C owns all of these
│   ├── useVaultBalance.ts        # reads getVaultBalance() — total TVL
│   ├── useUserBalance.ts         # reads getUserBalance(address) — user's claim
│   ├── useUserShares.ts          # reads userShares(address) — raw share count
│   ├── usePreviewWithdraw.ts     # reads previewWithdraw(shares) — payout preview
│   ├── useUsdcBalance.ts         # reads USDC.balanceOf(address) — wallet balance
│   ├── useAllowance.ts           # reads USDC.allowance(user, vault) — approval check
│   ├── useApprove.ts             # writes USDC.approve(vault, amount)
│   ├── useDeposit.ts             # writes vault.deposit(amount) + tracks tx state
│   └── useWithdraw.ts            # writes vault.withdraw(shares) + tracks tx state
│
├── lib/                          # ← Person C sets up, shared by all
│   ├── wagmi.ts                  # wagmi config — chains, connectors, transports
│   ├── contracts.ts              # VAULT_ADDRESS, USDC_ADDRESS per chain
│   ├── abis/
│   │   ├── YieldSaveVault.json   # contract ABI — copied from contracts/deployments/
│   │   └── ERC20.json            # standard ERC-20 ABI for USDC calls
│   └── utils.ts                  # formatUsdc(), parseUsdc(), formatYield() helpers
│
├── types/                        # ← Person E sets up on Day 1, frozen early
│   ├── contracts.ts              # TypeScript types matching contract inputs/outputs
│   └── components.ts             # shared prop interfaces between hooks and UI
│
├── constants/
│   ├── chains.ts                 # supported chain IDs and RPC URLs
│   └── fees.ts                   # FEE_RATE_BPS = 500 — mirrors contract constant
│
├── public/
│   ├── logo.svg
│   └── favicon.ico
│
├── .env.local.example            # copy to .env.local — never commit
│   # NEXT_PUBLIC_WALLET_CONNECT_PROJECT_ID=
│   # NEXT_PUBLIC_VAULT_ADDRESS_SEPOLIA=
│   # NEXT_PUBLIC_USDC_ADDRESS_SEPOLIA=
│
├── next.config.ts
├── tailwind.config.ts
├── tsconfig.json
└── package.json
```

**Key files explained:**

| File                                      | Owner    | Purpose                                                                  |
| ----------------------------------------- | -------- | ------------------------------------------------------------------------ |
| `app/providers.tsx`                       | Person C | Wraps the app in WagmiProvider — must exist before any hook works        |
| `lib/wagmi.ts`                            | Person C | Configures chains, RainbowKit connectors, Alchemy transport              |
| `lib/contracts.ts`                        | Person C | Single source of truth for contract addresses per network                |
| `lib/abis/YieldSaveVault.json`            | Person C | Copied from `contracts/deployments/` after Person B deploys              |
| `hooks/useDeposit.ts`                     | Person C | Handles approve-check → write → wait → success/error state machine       |
| `types/contracts.ts`                      | Person E | Frozen on Day 1 — TypeScript types for all ABI inputs/outputs            |
| `types/components.ts`                     | Person E | Frozen on Day 1 — prop interfaces between Person C hooks and Person D UI |
| `components/Dashboard/Dashboard.tsx`      | Person D | Composes all panels; uses mock data until Person C's hooks are ready     |
| `components/Withdraw/WithdrawPreview.tsx` | Person D | Shows fee breakdown so users see exactly what they receive               |

---

### `types/` — The Day 1 contract (shared, frozen early)

These two files are the **interface boundary** between Person C (hooks) and Person D (UI). Person E creates them on Day 1. No one merges code that changes these without a team discussion.

```typescript
// types/contracts.ts
export type DepositArgs = {
  amount: bigint; // USDC amount in 6-decimal units
};

export type WithdrawArgs = {
  shares: bigint; // share count from userShares mapping
};

export type UserBalanceResult = {
  gross: bigint; // raw USDC claim before fee
  principal: bigint; // original deposit amount
  yield: bigint; // gross - principal
  fee: bigint; // protocol fee on yield
  payout: bigint; // what user actually receives
};
```

```typescript
// types/components.ts
export type BalanceCardProps = {
  savedBalance: bigint | undefined;
  originalDeposit: bigint | undefined;
  yieldEarned: bigint | undefined;
  protocolFee: bigint | undefined;
  isLoading: boolean;
};

export type WithdrawPreviewProps = {
  shares: bigint;
  previewPayout: bigint | undefined;
  feeAmount: bigint | undefined;
  isLoading: boolean;
};

export type TxToastProps = {
  status: "idle" | "pending" | "confirmed" | "failed";
  txHash: string | undefined;
  message: string;
};
```

---

### Ownership summary

| Directory / File       | Person A | Person B | Person C | Person D | Person E |
| ---------------------- | :------: | :------: | :------: | :------: | :------: |
| `contracts/src/`       |    ✅    |  reads   |    —     |    —     |    —     |
| `contracts/test/`      |    —     |    ✅    |    —     |    —     |    —     |
| `contracts/script/`    |    —     |    ✅    |    —     |    —     |    —     |
| `frontend/hooks/`      |    —     |    —     |    ✅    |  reads   |    —     |
| `frontend/lib/`        |    —     |    —     |    ✅    |  reads   |    —     |
| `frontend/components/` |    —     |    —     |  reads   |    ✅    |  wires   |
| `frontend/types/`      |    —     |    —     |  reads   |  reads   |    ✅    |
| `frontend/app/`        |    —     |    —     |    —     |    ✅    | reviews  |
| `deployments/*.json`   |    —     |    ✅    |  reads   |    —     |    —     |

---

## 12. Roadmap

### Phase 1 — Cohort MVP (Now)

- [x] ERC-4626 style vault contract on Sepolia
- [x] Full-stack Next.js + wagmi frontend
- [x] `deposit()` and `withdraw()` with share-based accounting
- [x] Aave V3 USDC integration
- [x] 5% protocol fee on yield
- [x] `previewWithdraw()` — users see exact payout before withdrawing
- [ ] Security review (internal)

### Phase 2 — Mainnet launch (Month 1–2)

- [ ] Independent security audit
- [ ] Mainnet deployment on Base and/or Optimism
- [ ] Multiple yield strategies (Aave + Compound + Morpho)
- [ ] Auto-routing to highest-yielding strategy
- [ ] Permit support — gasless approvals via EIP-2612
- [ ] Mobile-responsive UI
- [ ] Strategy routing fee added (0.1% of yield)

### Phase 3 — Scale (Month 3–6)

- [ ] Cross-chain support
- [ ] SDK for developer integrations
- [ ] Whitelabel vault API for institutional partners
- [ ] Governance framework for fee rate changes
- [ ] Full ERC-4626 compliance (transferable share tokens)
- [ ] Bug bounty programme

### Long term

- [ ] Governance token
- [ ] Community-proposed yield strategies
- [ ] Native mobile app
- [ ] Fiat on-ramp integration

---

## 13. FAQ

**Q: Is my principal safe?**
The contract mathematically cannot deduct fees from principal — only from yield. Your deposit is protected by the vault's share math. That said, smart contract and underlying protocol risks exist (see Section 9).

**Q: What is the current APY?**
The APY is set by Aave's USDC supply rate, which fluctuates with market conditions. It is typically between 3–8%. Your net APY after the 5% protocol fee is approximately 95% of the gross Aave rate.

**Q: When exactly is the fee taken?**
Only at withdrawal. While your funds are deposited, no fee is charged. The fee is a single deduction at the moment you withdraw.

**Q: Can YieldSave change the fee?**
In the MVP, the fee rate is set at deployment. In Phase 2+, changes will require governance. A hard-coded maximum cap will prevent the fee from ever exceeding a reasonable ceiling (proposed: 10%).

**Q: Can I lose more than I deposited?**
No — the contract's fee logic ensures you always receive at least your original deposit back, as long as Aave itself is solvent and liquid. You cannot receive less than principal from YieldSave's fee mechanics.

**Q: What happens if I withdraw when Aave has low liquidity?**
Aave's `withdraw()` will revert if utilisation is too high and there is insufficient liquidity. In that case, your funds remain in the vault (still earning yield) until you retry later. This is an Aave-level constraint, not a YieldSave one.

**Q: Is YieldSave open source?**
Yes. The contract, frontend, and all tooling are MIT licensed and publicly available on GitHub.

**Q: Do I need to claim yield?**
No. Yield accrues automatically every block. It is already reflected in your balance when you check the dashboard. Withdrawing once collects everything — principal plus all yield earned.

**Q: Can I deposit multiple times?**
Yes. Each deposit mints additional shares at the current share price. Your `userDeposits` mapping updates to reflect the total principal across all deposits, ensuring the fee is always calculated correctly.

---

_YieldSave is a cohort project built in 4 days by a team of 5. Use on testnets is encouraged. Mainnet use prior to security audit is at your own risk._

_Contract · Frontend · Docs — all open source, MIT licensed._
