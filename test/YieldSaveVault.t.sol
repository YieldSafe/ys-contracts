// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Fixtures} from "./helpers/Fixtures.sol";

contract YieldSaveVaultSmokeTest is Fixtures {
    function test_EndToEnd_DepositYieldWithdrawFlow() public {
        uint256 aliceShares = _deposit(alice, 200 * USDC_UNIT);
        _deposit(bob, 100 * USDC_UNIT);
        _accrueYield(30 * USDC_UNIT);

        uint256 alicePreview = vault.getUserBalance(alice);
        uint256 bobPreview = vault.getUserBalance(bob);

        assertEq(aliceShares, 200 * USDC_UNIT);
        assertEq(alicePreview, 219_000_000);
        assertEq(bobPreview, 109_500_000);

        uint256 alicePayout = _withdraw(alice, aliceShares);
        assertEq(alicePayout, 219_000_000);
    }
}
