// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Fixtures} from "../helpers/Fixtures.sol";

contract FeeScenariosTest is Fixtures {
    function test_FeeOnlyAppliesToYield() public {
        _deposit(alice, 500 * USDC_UNIT);
        _accrueYield(21 * USDC_UNIT);

        uint256 shares = vault.userShares(alice);
        uint256 treasuryBefore = usdc.balanceOf(treasury);
        uint256 payout = _withdraw(alice, shares);

        assertEq(payout, 519_950_000);
        assertEq(usdc.balanceOf(alice), 1_000_019_950_000);
        assertEq(usdc.balanceOf(treasury) - treasuryBefore, 1_050_000);
    }

    function test_ZeroYieldChargesZeroFee() public {
        _deposit(alice, 100 * USDC_UNIT);
        uint256 shares = vault.userShares(alice);

        uint256 payout = _withdraw(alice, shares);

        assertEq(payout, 100 * USDC_UNIT);
        assertEq(usdc.balanceOf(treasury), 0);
    }

    function test_PreviewWithdrawMatchesFeeDeduction() public {
        _deposit(alice, 200 * USDC_UNIT);
        _accrueYield(20 * USDC_UNIT);
        uint256 shares = vault.userShares(alice);

        vm.prank(alice);
        uint256 preview = vault.previewWithdraw(shares);

        assertEq(preview, 219 * USDC_UNIT);
    }
}
