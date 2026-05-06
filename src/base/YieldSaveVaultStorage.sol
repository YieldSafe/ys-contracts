// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC20} from "../interfaces/IERC20.sol";
import {IPool} from "../interfaces/IPool.sol";

abstract contract YieldSaveVaultStorage {
    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant MAX_FEE_BPS = 1_000;

    IERC20 public immutable usdc;
    IERC20 public immutable aUsdc;
    IPool public immutable aavePool;
    address public immutable treasury;
    uint256 public immutable feeRate;

    uint256 public totalShares;
    mapping(address => uint256) public userShares;
    mapping(address => uint256) public userDeposits;

    constructor(address usdc_, address aUsdc_, address aavePool_, address treasury_, uint256 feeRate_) {
        usdc = IERC20(usdc_);
        aUsdc = IERC20(aUsdc_);
        aavePool = IPool(aavePool_);
        treasury = treasury_;
        feeRate = feeRate_;
    }
}
