// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import "../../ApeSwapZap.sol";
import "./lib/IMiniApeV2.sol";

abstract contract ApeSwapZapMiniApeV2 is ApeSwapZap {
    using SafeERC20 for IERC20;

    event ZapMiniApeV2(IERC20 inputToken, uint256 inputAmount, uint256 pid);
    event ZapMiniApeV2Native(uint256 inputAmount, uint256 pid);

    constructor() {}

    /// @notice Zap token into miniApev2 style dual farm
    /// @param inputToken Input token to zap
    /// @param inputAmount Amount of input tokens to zap
    /// @param lpTokens Tokens of LP to zap to
    /// @param path0 Path from input token to LP token0
    /// @param path1 Path from input token to LP token1
    /// @param minAmountsSwap The minimum amount of output tokens that must be received for swap
    /// @param minAmountsLP AmountAMin and amountBMin for adding liquidity
    /// @param deadline Unix timestamp after which the transaction will revert
    /// @param miniApe The main dualfarm contract
    /// @param pid Dual farm pid
    function zapMiniApeV2(
        IERC20 inputToken,
        uint256 inputAmount,
        address[] memory lpTokens, //[tokenA, tokenB]
        address[] calldata path0,
        address[] calldata path1,
        uint256[] memory minAmountsSwap, //[A, B]
        uint256[] memory minAmountsLP, //[amountAMin, amountBMin]
        uint256 deadline,
        IMiniApeV2 miniApe,
        uint256 pid
    ) external nonReentrant {
        IApePair pair = _validateMiniApeV2Zap(lpTokens, miniApe, pid);
        inputAmount = _transferIn(inputToken, inputAmount);
        _zap(
            ZapParams({
                inputToken: inputToken,
                inputAmount: inputAmount,
                lpTokens: lpTokens,
                path0: path0,
                path1: path1,
                minAmountsSwap: minAmountsSwap,
                minAmountsLP: minAmountsLP,
                to: address(this),
                deadline: deadline
            }),
            false
        );

        uint256 balance = pair.balanceOf(address(this));
        pair.approve(address(miniApe), balance);
        miniApe.deposit(pid, balance, msg.sender);
        pair.approve(address(miniApe), 0);
        emit ZapMiniApeV2(inputToken, inputAmount, pid);
    }

    /// @notice Zap native into miniApev2 style dual farm
    /// @param lpTokens Tokens of LP to zap to
    /// @param path0 Path from input token to LP token0
    /// @param path1 Path from input token to LP token1
    /// @param minAmountsSwap The minimum amount of output tokens that must be received for swap
    /// @param minAmountsLP AmountAMin and amountBMin for adding liquidity
    /// @param deadline Unix timestamp after which the transaction will revert
    /// @param miniApe The main dualfarm contract
    /// @param pid Dual Farm pid
    function zapMiniApeV2Native(
        address[] memory lpTokens, //[tokenA, tokenB]
        address[] calldata path0,
        address[] calldata path1,
        uint256[] memory minAmountsSwap, //[A, B]
        uint256[] memory minAmountsLP, //[amountAMin, amountBMin]
        uint256 deadline,
        IMiniApeV2 miniApe,
        uint256 pid
    ) external payable nonReentrant {
        (IERC20 weth, uint256 inputAmount) = _wrapNative();
        _zap(
            ZapParams({
                inputToken: weth,
                inputAmount: inputAmount,
                lpTokens: lpTokens,
                path0: path0,
                path1: path1,
                minAmountsSwap: minAmountsSwap,
                minAmountsLP: minAmountsLP,
                to: address(this),
                deadline: deadline
            }),
            true
        );

        IApePair pair = _validateMiniApeV2Zap(lpTokens, miniApe, pid);
        uint256 balance = pair.balanceOf(address(this));
        pair.approve(address(miniApe), balance);
        miniApe.deposit(pid, balance, msg.sender);
        pair.approve(address(miniApe), 0);
        emit ZapMiniApeV2Native(msg.value, pid);
    }

    /** PRIVATE FUNCTIONs **/

    function _validateMiniApeV2Zap(
        address[] memory lpTokens,
        IMiniApeV2 miniApe,
        uint256 pid
    ) private view returns (IApePair pair) {
        pair = IApePair(miniApe.lpToken(pid));
        require(
            (lpTokens[0] == pair.token0() && lpTokens[1] == pair.token1()) ||
                (lpTokens[1] == pair.token0() && lpTokens[0] == pair.token1()),
            "ApeSwapZapMiniApeV2: Wrong LP pair for Dual Farm"
        );
    }
}
