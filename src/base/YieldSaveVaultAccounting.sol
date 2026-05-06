// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {YieldSaveVaultStorage} from "./YieldSaveVaultStorage.sol";

abstract contract YieldSaveVaultAccounting is YieldSaveVaultStorage {
    function _previewDeposit(uint256 amount, uint256 assetsBefore) internal view returns (uint256) {
        if (amount == 0) return 0;
        if (totalShares == 0 || assetsBefore == 0) return amount;
        return amount * totalShares / assetsBefore;
    }

    function _quoteWithdraw(
        address user,
        uint256 shares,
        uint256 assets,
        uint256 currentTotalShares,
        uint256 userShareBalance
    ) internal view returns (uint256 grossAssets, uint256 principalPortion, uint256 fee) {
        grossAssets = shares * assets / currentTotalShares;
        principalPortion = userDeposits[user] * shares / userShareBalance;

        uint256 yld = grossAssets > principalPortion ? grossAssets - principalPortion : 0;
        fee = yld * feeRate / BPS_DENOMINATOR;
    }

    function _previewWithdrawForUser(address user, uint256 shares)
        internal
        view
        returns (uint256 payout, uint256 grossAssets, uint256 fee)
    {
        uint256 userShareBalance = userShares[user];
        if (shares == 0 || userShareBalance == 0 || shares > userShareBalance) {
            return (0, 0, 0);
        }

        (grossAssets,, fee) = _quoteWithdraw(user, shares, _totalAssets(), totalShares, userShareBalance);
        payout = grossAssets - fee;
    }

    function _totalAssets() internal view returns (uint256) {
        return aUsdc.balanceOf(address(this));
    }
}
