// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";

import {MockAavePool} from "../mocks/MockAavePool.sol";
import {MockERC20} from "../mocks/MockERC20.sol";

abstract contract AaveFork is Test {
    uint256 internal constant USDC_UNIT = 1e6;
    uint256 internal constant FEE_RATE_BPS = 500;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal treasury = makeAddr("treasury");

    MockERC20 internal usdc;
    MockERC20 internal aUsdc;
    MockAavePool internal pool;

    function setUp() public virtual {
        usdc = new MockERC20("USD Coin", "USDC", 6);
        aUsdc = new MockERC20("Aave USDC", "aUSDC", 6);
        pool = new MockAavePool(address(usdc), address(aUsdc));
    }
}
