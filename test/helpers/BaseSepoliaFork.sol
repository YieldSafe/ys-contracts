// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";

import {YieldSaveVault} from "../../src/YieldSaveVault.sol";
import {IERC20} from "../../src/interfaces/IERC20.sol";
import {IPool} from "../../src/interfaces/IPool.sol";

abstract contract BaseSepoliaFork is Test {
    uint256 internal constant USDC_UNIT = 1e6;
    uint256 internal constant FEE_RATE_BPS = 500;

    address internal constant DEFAULT_BASE_SEPOLIA_USDC = 0xba50Cd2A20f6DA35D788639E581bca8d0B5d4D5f;
    address internal constant DEFAULT_BASE_SEPOLIA_AUSDC = 0x10F1A9D11CDf50041f3f8cB7191CBE2f31750ACC;
    address internal constant DEFAULT_BASE_SEPOLIA_AAVE_POOL = 0x8bAB6d1b75f19e9eD9fCe8b9BD338844fF79aE27;

    address internal alice = makeAddr("alice");
    address internal treasury = makeAddr("treasury");

    IERC20 internal usdc;
    IERC20 internal aUsdc;
    IPool internal pool;
    YieldSaveVault internal vault;

    function setUp() public virtual {
        string memory rpcUrl = vm.envOr("BASE_SEPOLIA_RPC_URL", string(""));
        vm.skip(bytes(rpcUrl).length == 0, "BASE_SEPOLIA_RPC_URL is not set");

        vm.createSelectFork(rpcUrl);

        usdc = IERC20(vm.envOr("BASE_SEPOLIA_USDC", DEFAULT_BASE_SEPOLIA_USDC));
        aUsdc = IERC20(vm.envOr("BASE_SEPOLIA_AUSDC", DEFAULT_BASE_SEPOLIA_AUSDC));
        pool = IPool(vm.envOr("BASE_SEPOLIA_AAVE_POOL", DEFAULT_BASE_SEPOLIA_AAVE_POOL));
        vault = new YieldSaveVault(address(usdc), address(aUsdc), address(pool), treasury, FEE_RATE_BPS);

        deal(address(usdc), alice, 1_000_000 * USDC_UNIT);

        vm.prank(alice);
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
}
