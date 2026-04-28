// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Fixtures} from "../helpers/Fixtures.sol";

contract ShareMathScenariosTest is Fixtures {
    function test_SharePriceAppreciatesAsYieldAccrues() public {
        _deposit(alice, 1_000 * USDC_UNIT);
        _accrueYield(50 * USDC_UNIT);

        assertEq(aUsdc.balanceOf(address(vault)), 1_050 * USDC_UNIT);
        assertEq(vault.totalShares(), 1_000 * USDC_UNIT);
    }

    function test_LaterDepositorGetsFewerSharesAfterYield() public {
        _deposit(alice, 100 * USDC_UNIT);
        _accrueYield(50 * USDC_UNIT);

        uint256 bobShares = _deposit(bob, 75 * USDC_UNIT);

        assertEq(bobShares, 50 * USDC_UNIT);
        assertEq(vault.userShares(alice), 100 * USDC_UNIT);
        assertEq(vault.userShares(bob), 50 * USDC_UNIT);
    }

    function test_GetUserBalanceReturnsNetAssetsAfterFee() public {
        _deposit(alice, 250 * USDC_UNIT);
        _accrueYield(25 * USDC_UNIT);

        uint256 balance = vault.getUserBalance(alice);

        assertEq(balance, 273_750_000);
    }
}
