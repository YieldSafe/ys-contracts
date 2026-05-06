// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC20} from "../interfaces/IERC20.sol";

library ERC20TransferLib {
    function safeTransfer(IERC20 token, address to, uint256 amount) internal returns (bool) {
        (bool success, bytes memory data) =
            address(token).call(abi.encodeCall(IERC20.transfer, (to, amount)));
        return success && (data.length == 0 || abi.decode(data, (bool)));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal returns (bool) {
        (bool success, bytes memory data) =
            address(token).call(abi.encodeCall(IERC20.transferFrom, (from, to, amount)));
        return success && (data.length == 0 || abi.decode(data, (bool)));
    }

    function forceApprove(IERC20 token, address spender, uint256 amount) internal returns (bool) {
        (bool success, bytes memory data) =
            address(token).call(abi.encodeCall(IERC20.approve, (spender, 0)));
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) return false;

        (success, data) = address(token).call(abi.encodeCall(IERC20.approve, (spender, amount)));
        return success && (data.length == 0 || abi.decode(data, (bool)));
    }
}
