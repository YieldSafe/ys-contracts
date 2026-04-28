// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {BaseSepoliaFork} from "../helpers/BaseSepoliaFork.sol";

contract BaseSepoliaIntegrationTest is BaseSepoliaFork {
    function test_DepositSuppliesRealUsdcToAave() public {
        uint256 amount = 100 * USDC_UNIT;
        uint256 aliceBalanceBefore = usdc.balanceOf(alice);

        uint256 shares = _deposit(alice, amount);

        assertEq(shares, amount);
        assertEq(vault.userShares(alice), amount);
        assertEq(vault.userDeposits(alice), amount);
        assertEq(vault.totalShares(), amount);
        assertEq(usdc.balanceOf(alice), aliceBalanceBefore - amount);
        assertEq(usdc.balanceOf(address(vault)), 0);
        assertApproxEqAbs(aUsdc.balanceOf(address(vault)), amount, 2);
    }

    function test_WithdrawRedeemsPrincipalFromRealAavePool() public {
        uint256 amount = 100 * USDC_UNIT;
        uint256 aliceBalanceBefore = usdc.balanceOf(alice);
        uint256 shares = _deposit(alice, amount);

        vm.prank(alice);
        uint256 preview = vault.previewWithdraw(shares);
        assertApproxEqAbs(preview, amount, 2);

        uint256 payout = _withdraw(alice, shares);

        assertApproxEqAbs(payout, amount, 2);
        assertEq(vault.userShares(alice), 0);
        assertEq(vault.userDeposits(alice), 0);
        assertEq(vault.totalShares(), 0);
        assertApproxEqAbs(usdc.balanceOf(alice), aliceBalanceBefore, 2);
    }

    function test_GetVaultBalanceTracksRealATokenBalance() public {
        uint256 amount = 25 * USDC_UNIT;
        _deposit(alice, amount);

        uint256 vaultBalance = vault.getVaultBalance();

        assertApproxEqAbs(vaultBalance, aUsdc.balanceOf(address(vault)), 1);
        assertApproxEqAbs(vaultBalance, amount, 2);
    }
}
