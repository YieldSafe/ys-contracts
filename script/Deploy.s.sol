// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {YieldSaveVault} from "../src/YieldSaveVault.sol";

contract Deploy is Script {
    function run() external returns (YieldSaveVault vault) {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address treasury = vm.envAddress("TREASURY");
        uint256 feeRate = vm.envOr("FEE_RATE_BPS", uint256(500));

        (address usdc, address aUsdc, address pool, string memory network) = _loadNetworkConfig(block.chainid);

        vm.startBroadcast(deployerPrivateKey);
        vault = new YieldSaveVault(usdc, aUsdc, pool, treasury, feeRate);
        vm.stopBroadcast();

        _writeDeployment(network, address(vault));
        console2.log("YieldSaveVault deployed to", address(vault));
    }

    function _loadNetworkConfig(uint256 chainId)
        internal
        view
        returns (address usdc, address aUsdc, address pool, string memory network)
    {
        if (chainId == 11155111) {
            return (
                vm.envAddress("SEPOLIA_USDC"),
                vm.envAddress("SEPOLIA_AUSDC"),
                vm.envAddress("SEPOLIA_AAVE_POOL"),
                "sepolia"
            );
        }

        if (chainId == 84_532) {
            return (
                vm.envAddress("BASE_SEPOLIA_USDC"),
                vm.envAddress("BASE_SEPOLIA_AUSDC"),
                vm.envAddress("BASE_SEPOLIA_AAVE_POOL"),
                "base-sepolia"
            );
        }

        revert("unsupported chain");
    }

    function _writeDeployment(string memory network, address vault) internal {
        string memory objectKey = "deployment";
        string memory path = string.concat("./deployments/", network, ".json");

        vm.serializeAddress(objectKey, "vault", vault);
        vm.serializeUint(objectKey, "chainId", block.chainid);
        string memory json = vm.serializeUint(objectKey, "block", block.number);
        vm.writeJson(json, path);
    }
}
