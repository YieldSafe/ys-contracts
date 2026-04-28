// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IPool} from "../../src/interfaces/IPool.sol";
import {IERC20} from "../../src/interfaces/IERC20.sol";
import {MockERC20} from "./MockERC20.sol";

contract MockAavePool is IPool {
    IERC20 public immutable usdc;
    MockERC20 public immutable aUsdc;

    constructor(address usdc_, address aUsdc_) {
        usdc = IERC20(usdc_);
        aUsdc = MockERC20(aUsdc_);
    }

    function supply(address asset, uint256 amount, address onBehalfOf, uint16) external override {
        require(asset == address(usdc), "unsupported asset");
        require(usdc.transferFrom(msg.sender, address(this), amount), "transferFrom failed");
        aUsdc.mint(onBehalfOf, amount);
    }

    function withdraw(address asset, uint256 amount, address to) external override returns (uint256) {
        require(asset == address(usdc), "unsupported asset");
        aUsdc.burn(msg.sender, amount);
        require(usdc.transfer(to, amount), "transfer failed");
        return amount;
    }

    function accrueYield(address account, uint256 amount) external {
        aUsdc.mint(account, amount);
        MockERC20(address(usdc)).mint(address(this), amount);
    }
}
