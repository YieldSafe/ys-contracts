// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ReentrancyGuard} from "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

import {IERC20} from "./interfaces/IERC20.sol";
import {IPool} from "./interfaces/IPool.sol";

contract YieldSaveVault is ReentrancyGuard {
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

    error ZeroAddress();
    error ZeroAmount();
    error InvalidFeeRate();
    error InsufficientShares();
    error ZeroSharesMinted();
    error ERC20CallFailed();

    event Deposited(address indexed user, uint256 assets, uint256 shares);
    event Withdrawn(
        address indexed user,
        uint256 shares,
        uint256 grossAssets,
        uint256 fee,
        uint256 payout
    );

    constructor(address usdc_, address aUsdc_, address aavePool_, address treasury_, uint256 feeRate_) {
        if (usdc_ == address(0) || aUsdc_ == address(0) || aavePool_ == address(0) || treasury_ == address(0)) {
            revert ZeroAddress();
        }
        if (feeRate_ > MAX_FEE_BPS) revert InvalidFeeRate();

        usdc = IERC20(usdc_);
        aUsdc = IERC20(aUsdc_);
        aavePool = IPool(aavePool_);
        treasury = treasury_;
        feeRate = feeRate_;
    }

    function deposit(uint256 amount) external nonReentrant returns (uint256 shares) {
        if (amount == 0) revert ZeroAmount();

        shares = _previewDeposit(amount, _totalAssets());
        if (shares == 0) revert ZeroSharesMinted();

        _safeTransferFrom(usdc, msg.sender, address(this), amount);
        _forceApprove(usdc, address(aavePool), amount);
        aavePool.supply(address(usdc), amount, address(this), 0);

        userShares[msg.sender] += shares;
        userDeposits[msg.sender] += amount;
        totalShares += shares;

        emit Deposited(msg.sender, amount, shares);
    }

    function withdraw(uint256 shares) external nonReentrant returns (uint256 payout) {
        if (shares == 0) revert ZeroAmount();

        uint256 userShareBalance = userShares[msg.sender];
        if (shares > userShareBalance) revert InsufficientShares();

        (uint256 grossAssets, uint256 principalPortion, uint256 fee) = _quoteWithdraw(
            msg.sender, shares, _totalAssets(), totalShares, userShareBalance
        );

        payout = grossAssets - fee;

        userShares[msg.sender] = userShareBalance - shares;
        userDeposits[msg.sender] -= principalPortion;
        totalShares -= shares;

        aavePool.withdraw(address(usdc), grossAssets, address(this));
        _safeTransfer(usdc, msg.sender, payout);
        if (fee != 0) _safeTransfer(usdc, treasury, fee);

        emit Withdrawn(msg.sender, shares, grossAssets, fee, payout);
    }

    function getVaultBalance() external view returns (uint256) {
        return _totalAssets();
    }

    function getUserBalance(address user) external view returns (uint256) {
        uint256 shares = userShares[user];
        if (shares == 0) return 0;

        (uint256 payout,,) = _previewWithdrawForUser(user, shares);
        return payout;
    }

    function previewDeposit(uint256 amount) external view returns (uint256) {
        return _previewDeposit(amount, _totalAssets());
    }

    function previewWithdraw(uint256 shares) external view returns (uint256) {
        (uint256 payout,,) = _previewWithdrawForUser(msg.sender, shares);
        return payout;
    }

    function previewWithdrawFor(address user, uint256 shares)
        external
        view
        returns (uint256 payout, uint256 grossAssets, uint256 fee)
    {
        (payout, grossAssets, fee) = _previewWithdrawForUser(user, shares);
    }

    function _previewWithdrawForUser(address user, uint256 shares)
        internal
        view
        returns (uint256 payout, uint256 grossAssets, uint256 fee)
    {
        uint256 userShareBalance = userShares[user];
        if (shares == 0 || userShareBalance == 0 || shares > userShareBalance) {
            return (0, 0, 0);
        }

        (grossAssets,, fee) = _quoteWithdraw(user, shares, _totalAssets(), totalShares, userShareBalance);
        payout = grossAssets - fee;
    }

    function _previewDeposit(uint256 amount, uint256 assetsBefore) internal view returns (uint256) {
        if (amount == 0) return 0;
        if (totalShares == 0 || assetsBefore == 0) return amount;
        return amount * totalShares / assetsBefore;
    }

    function _quoteWithdraw(
        address user,
        uint256 shares,
        uint256 assets,
        uint256 currentTotalShares,
        uint256 userShareBalance
    ) internal view returns (uint256 grossAssets, uint256 principalPortion, uint256 fee) {
        grossAssets = shares * assets / currentTotalShares;
        principalPortion = userDeposits[user] * shares / userShareBalance;

        uint256 yld = grossAssets > principalPortion ? grossAssets - principalPortion : 0;
        fee = yld * feeRate / BPS_DENOMINATOR;
    }

    function _totalAssets() internal view returns (uint256) {
        return aUsdc.balanceOf(address(this));
    }

    function _safeTransfer(IERC20 token, address to, uint256 amount) internal {
        (bool success, bytes memory data) =
            address(token).call(abi.encodeCall(IERC20.transfer, (to, amount)));
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) revert ERC20CallFailed();
    }

    function _safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) =
            address(token).call(abi.encodeCall(IERC20.transferFrom, (from, to, amount)));
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) revert ERC20CallFailed();
    }

    function _forceApprove(IERC20 token, address spender, uint256 amount) internal {
        (bool success, bytes memory data) =
            address(token).call(abi.encodeCall(IERC20.approve, (spender, 0)));
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) revert ERC20CallFailed();

        (success, data) = address(token).call(abi.encodeCall(IERC20.approve, (spender, amount)));
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) revert ERC20CallFailed();
    }
}
