// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {YieldSaveVault} from "../../src/YieldSaveVault.sol";
import {AaveFork} from "./AaveFork.sol";

abstract contract Fixtures is AaveFork {
    YieldSaveVault internal vault;

    function setUp() public virtual override {
        super.setUp();

        vault = new YieldSaveVault(address(usdc), address(aUsdc), address(pool), treasury, FEE_RATE_BPS);

        _mintAndApprove(alice, 1_000_000 * USDC_UNIT);
        _mintAndApprove(bob, 1_000_000 * USDC_UNIT);
    }

    function _mintAndApprove(address user, uint256 amount) internal {
        usdc.mint(user, amount);
        vm.prank(user);
        usdc.approve(address(vault), type(uint256).max);
    }

    function _deposit(address user, uint256 amount) internal returns (uint256 shares) {
        vm.prank(user);
        shares = vault.deposit(amount);
    }

    function _withdraw(address user, uint256 shares) internal returns (uint256 payout) {
        vm.prank(user);
        payout = vault.withdraw(shares);
    }

    function _accrueYield(uint256 amount) internal {
        pool.accrueYield(address(vault), amount);
    }
}
