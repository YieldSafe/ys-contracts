// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Fixtures} from "../helpers/Fixtures.sol";
import {YieldSaveVault} from "../../src/YieldSaveVault.sol";

contract DepositScenariosTest is Fixtures {
    function test_DepositRevertsOnZeroAmount() public {
        vm.prank(alice);
        vm.expectRevert(YieldSaveVault.ZeroAmount.selector);
        vault.deposit(0);
    }

    function test_FirstDepositMintsSharesOneToOne() public {
        uint256 amount = 100 * USDC_UNIT;

        uint256 preview = vault.previewDeposit(amount);
        uint256 shares = _deposit(alice, amount);

        assertEq(preview, amount);
        assertEq(shares, amount);
        assertEq(vault.userShares(alice), amount);
        assertEq(vault.userDeposits(alice), amount);
        assertEq(vault.totalShares(), amount);
    }

    function test_SecondDepositUsesCurrentSharePrice() public {
        uint256 initialAmount = 100 * USDC_UNIT;
        _deposit(alice, initialAmount);
        _accrueYield(20 * USDC_UNIT);

        uint256 secondAmount = 60 * USDC_UNIT;
        uint256 preview = vault.previewDeposit(secondAmount);
        uint256 shares = _deposit(bob, secondAmount);

        assertEq(preview, 50 * USDC_UNIT);
        assertEq(shares, 50 * USDC_UNIT);
        assertEq(vault.userShares(bob), 50 * USDC_UNIT);
        assertEq(vault.totalShares(), 150 * USDC_UNIT);
        assertEq(aUsdc.balanceOf(address(vault)), 180 * USDC_UNIT);
    }

    function test_MultipleDepositsAccumulatePrincipalAndShares() public {
        _deposit(alice, 100 * USDC_UNIT);
        _accrueYield(10 * USDC_UNIT);
        _deposit(alice, 55 * USDC_UNIT);

        assertEq(vault.userDeposits(alice), 155 * USDC_UNIT);
        assertEq(vault.userShares(alice), 150 * USDC_UNIT);
        assertEq(vault.totalShares(), 150 * USDC_UNIT);
    }
}
