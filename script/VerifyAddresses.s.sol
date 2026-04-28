// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

contract VerifyAddresses is Script {
    function run() external view {
        if (block.chainid == 11155111) {
            console2.log("Network: Sepolia");
            console2.log("USDC:", vm.envAddress("SEPOLIA_USDC"));
            console2.log("aUSDC:", vm.envAddress("SEPOLIA_AUSDC"));
            console2.log("Aave Pool:", vm.envAddress("SEPOLIA_AAVE_POOL"));
            return;
        }

        if (block.chainid == 84_532) {
            console2.log("Network: Base Sepolia");
            console2.log("USDC:", vm.envAddress("BASE_SEPOLIA_USDC"));
            console2.log("aUSDC:", vm.envAddress("BASE_SEPOLIA_AUSDC"));
            console2.log("Aave Pool:", vm.envAddress("BASE_SEPOLIA_AAVE_POOL"));
            return;
        }

        revert("unsupported chain");
    }
}
