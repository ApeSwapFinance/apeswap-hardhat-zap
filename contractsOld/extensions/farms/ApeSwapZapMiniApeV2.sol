// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import "../../ApeSwapZap.sol";
import "./libraries/IMiniApeV2.sol";

abstract contract ApeSwapZapMiniApeV2 is ApeSwapZap {
    using SafeERC20 for IERC20;

    event ZapMiniApeV2(IERC20 inputToken, uint256 inputAmount, uint256 pid);
    event ZapMiniApeV2Native(uint256 inputAmount, uint256 pid);

    constructor() {}

    /// @notice Zap token into miniApev2 style dual farm
    /// @param inputToken Input token to zap
    /// @param inputAmount Amount of input tokens to zap
    /// @param underlyingTokens Tokens of LP to zap to
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
        address[] memory underlyingTokens, //[token0, token1]
        address[] calldata path0,
        address[] calldata path1,
        uint256[] memory minAmountsSwap, //[A, B]
        uint256[] memory minAmountsLP, //[amountAMin, amountBMin]
        uint256 deadline,
        IMiniApeV2 miniApe,
        uint256 pid
    ) external nonReentrant {
        IApePair pair = IApePair(miniApe.lpToken(pid));
        require(
            (underlyingTokens[0] == pair.token0() && underlyingTokens[1] == pair.token1()) ||
                (underlyingTokens[1] == pair.token0() && underlyingTokens[0] == pair.token1()),
            "ApeSwapZap: Wrong LP pair for MiniApe"
        );

        _zapInternal(
            inputToken,
            inputAmount,
            underlyingTokens,
            path0,
            path1,
            minAmountsSwap,
            minAmountsLP,
            address(this),
            deadline
        );

        uint256 balance = pair.balanceOf(address(this));
        pair.approve(address(miniApe), balance);
        miniApe.deposit(pid, balance, msg.sender);
        pair.approve(address(miniApe), 0);
        emit ZapMiniApeV2(inputToken, inputAmount, pid);
    }

    /// @notice Zap native into miniApev2 style dual farm
    /// @param underlyingTokens Tokens of LP to zap to
    /// @param path0 Path from input token to LP token0
    /// @param path1 Path from input token to LP token1
    /// @param minAmountsSwap The minimum amount of output tokens that must be received for swap
    /// @param minAmountsLP AmountAMin and amountBMin for adding liquidity
    /// @param deadline Unix timestamp after which the transaction will revert
    /// @param miniApe The main dualfarm contract
    /// @param pid Dual Farm pid
    function zapMiniApeV2Native(
        address[] memory underlyingTokens, //[token0, token1]
        address[] calldata path0,
        address[] calldata path1,
        uint256[] memory minAmountsSwap, //[A, B]
        uint256[] memory minAmountsLP, //[amountAMin, amountBMin]
        uint256 deadline,
        IMiniApeV2 miniApe,
        uint256 pid
    ) external payable nonReentrant {
        IApePair pair = IApePair(miniApe.lpToken(pid));
        require(
            (underlyingTokens[0] == pair.token0() && underlyingTokens[1] == pair.token1()) ||
                (underlyingTokens[1] == pair.token0() && underlyingTokens[0] == pair.token1()),
            "ApeSwapZap: Wrong LP pair for Dual Farm"
        );

        _zapNativeInternal(underlyingTokens, path0, path1, minAmountsSwap, minAmountsLP, address(this), deadline);

        uint256 balance = pair.balanceOf(address(this));
        pair.approve(address(miniApe), balance);
        miniApe.deposit(pid, balance, msg.sender);
        pair.approve(address(miniApe), 0);
        emit ZapMiniApeV2Native(msg.value, pid);
    }
}
