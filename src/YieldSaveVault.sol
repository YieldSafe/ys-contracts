// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ReentrancyGuard} from "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

import {IERC20} from "./interfaces/IERC20.sol";
import {YieldSaveVaultStorage} from "./base/YieldSaveVaultStorage.sol";
import {ERC20TransferLib} from "./libraries/ERC20TransferLib.sol";
import {YieldSaveVaultAccounting} from "./base/YieldSaveVaultAccounting.sol";

contract YieldSaveVault is ReentrancyGuard, YieldSaveVaultAccounting {
    using ERC20TransferLib for IERC20;

    error ZeroAddress();
    error ZeroAmount();
    error InvalidFeeRate();
    error InsufficientShares();
    error ZeroSharesMinted();
    error ERC20CallFailed();

    event Deposited(address indexed user, uint256 assets, uint256 shares);
    event Withdrawn(
        address indexed user,
        uint256 shares,
        uint256 grossAssets,
        uint256 fee,
        uint256 payout
    );

    constructor(address usdc_, address aUsdc_, address aavePool_, address treasury_, uint256 feeRate_)
        YieldSaveVaultStorage(usdc_, aUsdc_, aavePool_, treasury_, feeRate_)
    {
        if (usdc_ == address(0) || aUsdc_ == address(0) || aavePool_ == address(0) || treasury_ == address(0)) {
            revert ZeroAddress();
        }
        if (feeRate_ > MAX_FEE_BPS) revert InvalidFeeRate();
    }

    /// @notice Deposits USDC into the vault and mints internal shares for the sender.
    /// @dev Frontend flow must request a prior ERC20 approval from the user before calling this function:
    /// user calls `USDC.approve(address(this), amount)` first, then calls `deposit(amount)`.
    /// The vault cannot approve on behalf of the user; `_safeTransferFrom` will revert unless this
    /// contract already has sufficient allowance to pull `amount` of USDC from `msg.sender`.
    function deposit(uint256 amount) external nonReentrant returns (uint256 shares) {
        if (amount == 0) revert ZeroAmount();

        shares = _previewDeposit(amount, _totalAssets());
        if (shares == 0) revert ZeroSharesMinted();

        _safeTransferFrom(usdc, msg.sender, address(this), amount);
        _forceApprove(usdc, address(aavePool), amount);
        aavePool.supply(address(usdc), amount, address(this), 0);

        userShares[msg.sender] += shares;
        userDeposits[msg.sender] += amount;
        totalShares += shares;

        emit Deposited(msg.sender, amount, shares);
    }

    /// @notice Burns `shares` from the caller and returns the net USDC payout after any yield fee.
    /// @dev UI flow should use `previewWithdraw` or `previewWithdrawFor` before submit for an optimistic quote,
    /// then sync from this function's return value or the `Withdrawn` event once the transaction confirms.
    /// The preview and execution share the same fee logic, but the final payout can still move if vault assets
    /// change between the preview read and mined withdrawal transaction.
    function withdraw(uint256 shares) external nonReentrant returns (uint256 payout) {
        if (shares == 0) revert ZeroAmount();

        uint256 userShareBalance = userShares[msg.sender];
        if (shares > userShareBalance) revert InsufficientShares();

        (uint256 grossAssets, uint256 principalPortion, uint256 fee) = _quoteWithdraw(
            msg.sender, shares, _totalAssets(), totalShares, userShareBalance
        );

        payout = grossAssets - fee;

        userShares[msg.sender] = userShareBalance - shares;
        userDeposits[msg.sender] -= principalPortion;
        totalShares -= shares;

        aavePool.withdraw(address(usdc), grossAssets, address(this));
        _safeTransfer(usdc, msg.sender, payout);
        if (fee != 0) _safeTransfer(usdc, treasury, fee);

        emit Withdrawn(msg.sender, shares, grossAssets, fee, payout);
    }

    function getVaultBalance() external view returns (uint256) {
        return _totalAssets();
    }

    function getUserBalance(address user) external view returns (uint256) {
        uint256 shares = userShares[user];
        if (shares == 0) return 0;

        (uint256 payout,,) = _previewWithdrawForUser(user, shares);
        return payout;
    }

    /// @notice Quotes how many vault shares would be minted for `amount` of USDC at the current vault ratio.
    /// @dev Intended for pre-transaction UI state only. The frontend should refresh this quote when balances or
    /// vault assets move, and treat the actual `Deposited` event as the source of truth after confirmation.
    function previewDeposit(uint256 amount) external view returns (uint256) {
        return _previewDeposit(amount, _totalAssets());
    }

    /// @notice Quotes the caller's net USDC payout for redeeming `shares` right now.
    /// @dev This is the UI-facing preview for the connected wallet and already excludes the fee charged on yield.
    /// It returns `0` for invalid requests instead of reverting, which makes it safe to poll while the user edits
    /// input. Because assets can change before the withdraw transaction is mined, the UI must resync from the
    /// transaction result or `Withdrawn` event after confirmation.
    function previewWithdraw(uint256 shares) external view returns (uint256) {
        (uint256 payout,,) = _previewWithdrawForUser(msg.sender, shares);
        return payout;
    }

    /// @notice Quotes a specific user's withdraw result, including net payout, gross assets, and fee.
    /// @dev Useful for admin dashboards or richer UI state where the frontend needs to show the fee breakdown in
    /// addition to the final payout. As with `previewWithdraw`, this is a point-in-time quote and not a guarantee.
    function previewWithdrawFor(address user, uint256 shares)
        external
        view
        returns (uint256 payout, uint256 grossAssets, uint256 fee)
    {
        (payout, grossAssets, fee) = _previewWithdrawForUser(user, shares);
    }

    function _safeTransfer(IERC20 token, address to, uint256 amount) internal {
        if (!token.safeTransfer(to, amount)) revert ERC20CallFailed();
    }

    function _safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        if (!token.safeTransferFrom(from, to, amount)) revert ERC20CallFailed();
    }

    function _forceApprove(IERC20 token, address spender, uint256 amount) internal {
        if (!token.forceApprove(spender, amount)) revert ERC20CallFailed();
    }
}
