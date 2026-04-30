// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {YieldSaveVault} from "../src/YieldSaveVault.sol";
import {IERC20} from "../src/interfaces/IERC20.sol";
import {IPool} from "../src/interfaces/IPool.sol";

// --- Tests ---

contract YieldSaveVaultTest is Test {
    uint256 internal constant USDC_UNIT = 1e6;
    uint256 internal constant FEE_RATE_BPS = 1000; // 10%
    
    address internal constant DEFAULT_BASE_SEPOLIA_USDC = 0xba50Cd2A20f6DA35D788639E581bca8d0B5d4D5f;
    address internal constant DEFAULT_BASE_SEPOLIA_AUSDC = 0x10F1A9D11CDf50041f3f8cB7191CBE2f31750ACC;
    address internal constant DEFAULT_BASE_SEPOLIA_AAVE_POOL = 0x8bAB6d1b75f19e9eD9fCe8b9BD338844fF79aE27;

    YieldSaveVault public vault;
    IERC20 public usdc;
    IERC20 public aUsdc;
    IPool public aavePool;

    address public alice;
    address public bob;
    address public treasury;

    event Deposited(address indexed user, uint256 assets, uint256 shares);
    event Withdrawn(address indexed user, uint256 shares, uint256 grossAssets, uint256 fee, uint256 payout);

    function setUp() public {
        // Load RPC URL from .env, skip test if not available
        string memory rpcUrl = vm.envOr("BASE_SEPOLIA_RPC_URL", string(""));
        vm.skip(bytes(rpcUrl).length == 0, "BASE_SEPOLIA_RPC_URL is not set");

        // Create and select fork
        vm.createSelectFork(rpcUrl);

        // Load contract addresses from .env with fallbacks
        address usdcAddress = vm.envOr("BASE_SEPOLIA_USDC", DEFAULT_BASE_SEPOLIA_USDC);
        address aUsdcAddress = vm.envOr("BASE_SEPOLIA_AUSDC", DEFAULT_BASE_SEPOLIA_AUSDC);
        address poolAddress = vm.envOr("BASE_SEPOLIA_AAVE_POOL", DEFAULT_BASE_SEPOLIA_AAVE_POOL);

        usdc = IERC20(usdcAddress);
        aUsdc = IERC20(aUsdcAddress);
        aavePool = IPool(poolAddress);

        alice = makeAddr("alice");
        bob = makeAddr("bob");
        treasury = makeAddr("treasury");

        vault = new YieldSaveVault(
            address(usdc),
            address(aUsdc),
            address(aavePool),
            treasury,
            FEE_RATE_BPS
        );

        // Deal USDC to test accounts
        deal(address(usdc), alice, 1000 * USDC_UNIT);
        deal(address(usdc), bob, 1000 * USDC_UNIT);

        vm.prank(alice);
        usdc.approve(address(vault), type(uint256).max);

        vm.prank(bob);
        usdc.approve(address(vault), type(uint256).max);
    }

    // --- Constructor Tests ---
    function test_Constructor_RevertsZeroAddress() public {
        vm.expectRevert(YieldSaveVault.ZeroAddress.selector);
        new YieldSaveVault(address(0), address(aUsdc), address(aavePool), treasury, 1000);

        vm.expectRevert(YieldSaveVault.ZeroAddress.selector);
        new YieldSaveVault(address(usdc), address(0), address(aavePool), treasury, 1000);

        vm.expectRevert(YieldSaveVault.ZeroAddress.selector);
        new YieldSaveVault(address(usdc), address(aUsdc), address(0), treasury, 1000);

        vm.expectRevert(YieldSaveVault.ZeroAddress.selector);
        new YieldSaveVault(address(usdc), address(aUsdc), address(aavePool), address(0), 1000);
    }

    function test_Constructor_RevertsInvalidFeeRate() public {
        vm.expectRevert(YieldSaveVault.InvalidFeeRate.selector);
        new YieldSaveVault(address(usdc), address(aUsdc), address(aavePool), treasury, 1001);
    }

    // --- Deposit Tests ---
    function test_Deposit_RevertsZeroAmount() public {
        vm.prank(alice);
        vm.expectRevert(YieldSaveVault.ZeroAmount.selector);
        vault.deposit(0);
    }

    function test_Deposit_Success() public {
        uint256 depositAmount = 100 * USDC_UNIT;
        
        vm.expectEmit(true, false, false, true);
        emit Deposited(alice, depositAmount, depositAmount);
        
        vm.prank(alice);
        vault.deposit(depositAmount);

        assertEq(vault.userShares(alice), depositAmount);
        assertEq(vault.userDeposits(alice), depositAmount);
        assertEq(vault.totalShares(), depositAmount);
    }

    // --- Withdraw Tests ---
    function test_Withdraw_RevertsZeroAmount() public {
        vm.prank(alice);
        vm.expectRevert(YieldSaveVault.ZeroAmount.selector);
        vault.withdraw(0);
    }

    function test_Withdraw_RevertsInsufficientShares() public {
        uint256 depositAmount = 100 * USDC_UNIT;
        
        vm.prank(alice);
        vault.deposit(depositAmount);

        vm.prank(alice);
        vm.expectRevert(YieldSaveVault.InsufficientShares.selector);
        vault.withdraw(depositAmount + 1);
    }

    function test_Withdraw_Success() public {
        uint256 depositAmount = 100 * USDC_UNIT;
        uint256 aliceBalanceBefore = usdc.balanceOf(alice);
        
        vm.prank(alice);
        vault.deposit(depositAmount);

        vm.prank(alice);
        vault.withdraw(depositAmount);

        assertEq(vault.userShares(alice), uint256(0));
        // Balance should be approximately restored (may have small variance due to aave)
        assertApproxEqAbs(usdc.balanceOf(alice), aliceBalanceBefore, 2);
    }

    // --- View Functions & Preview Tests ---
    function test_ViewFunctions_BeforeDeposit() public {
        assertEq(vault.getVaultBalance(), uint256(0));
        assertEq(vault.getUserBalance(alice), uint256(0));
        assertEq(vault.previewDeposit(0), uint256(0));
    }

    function test_ViewFunctions_AfterDeposit() public {
        uint256 depositAmount = 100 * USDC_UNIT;
        
        vm.prank(alice);
        vault.deposit(depositAmount);

        assertApproxEqAbs(vault.getVaultBalance(), depositAmount, 2);
        assertApproxEqAbs(vault.getUserBalance(alice), depositAmount, 2);
    }

    function test_PreviewWithdraw() public {
        uint256 depositAmount = 100 * USDC_UNIT;
        
        vm.prank(alice);
        vault.deposit(depositAmount);

        vm.prank(alice);
        uint256 preview = vault.previewWithdraw(depositAmount / 2);
        assertApproxEqAbs(preview, depositAmount / 2, 2);
    }

    function test_PreviewWithdrawFor() public {
        uint256 depositAmount = 100 * USDC_UNIT;
        
        vm.prank(alice);
        vault.deposit(depositAmount);

        (uint256 payout, uint256 gross, uint256 fee) = vault.previewWithdrawFor(alice, depositAmount);
        assertApproxEqAbs(payout + fee, gross, 2);
    }

    function test_PreviewWithdrawFor_ZeroShares() public {
        (uint256 payout, uint256 gross, uint256 fee) = vault.previewWithdrawFor(alice, 0);
        assertEq(payout, uint256(0));
        assertEq(gross, uint256(0));
        assertEq(fee, uint256(0));
    }

    function test_PreviewWithdrawFor_NonExistentUser() public {
        (uint256 payout, uint256 gross, uint256 fee) = vault.previewWithdrawFor(bob, 50);
        assertEq(payout, uint256(0));
    }

}