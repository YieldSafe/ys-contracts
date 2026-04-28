// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Fixtures} from "../helpers/Fixtures.sol";
import {YieldSaveVault} from "../../src/YieldSaveVault.sol";

contract WithdrawScenariosTest is Fixtures {
    function test_WithdrawRevertsOnZeroShares() public {
        vm.prank(alice);
        vm.expectRevert(YieldSaveVault.ZeroAmount.selector);
        vault.withdraw(0);
    }

    function test_WithdrawRevertsWhenUserLacksShares() public {
        _deposit(alice, 100 * USDC_UNIT);

        vm.prank(bob);
        vm.expectRevert(YieldSaveVault.InsufficientShares.selector);
        vault.withdraw(1);
    }

    function test_FullWithdrawalReturnsPrincipalPlusNetYield() public {
        _deposit(alice, 100 * USDC_UNIT);
        _accrueYield(10 * USDC_UNIT);

        uint256 shares = vault.userShares(alice);
        uint256 payout = _withdraw(alice, shares);

        assertEq(payout, 109_500_000);
        assertEq(vault.userShares(alice), 0);
        assertEq(vault.userDeposits(alice), 0);
        assertEq(vault.totalShares(), 0);
    }

    function test_PartialWithdrawalReducesPrincipalProportionally() public {
        _deposit(alice, 100 * USDC_UNIT);
        _accrueYield(20 * USDC_UNIT);

        uint256 payout = _withdraw(alice, 40 * USDC_UNIT);

        assertEq(payout, 47_600_000);
        assertEq(vault.userShares(alice), 60 * USDC_UNIT);
        assertEq(vault.userDeposits(alice), 60 * USDC_UNIT);
        assertEq(vault.getUserBalance(alice), 71_400_000);
    }
}
