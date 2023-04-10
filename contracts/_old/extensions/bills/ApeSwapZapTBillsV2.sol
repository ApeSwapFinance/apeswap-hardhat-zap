// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import "../../ApeSwapZapV2.sol";
import "./libraries/ICustomBill.sol";
import "../../interfaces/IApeSwapZapV2.sol";
import "../../../interfaces/IApeRouter02.sol";

abstract contract ApeSwapZapTBillsV2 is ApeSwapZapV2 {
    event ZapTBill(ZapParamsTBill zapParamsTBill);
    event ZapTBillNative(ZapParamsTBillNative zapParamsTBillNative);

    /// @notice Zap single token to LP
    /// @param zapParamsTBill all parameters for tbill zap
    /// inputToken Input token to zap
    /// inputAmount Amount of input tokens to zap
    /// underlyingTokens Tokens of LP to zap to
    /// paths Path from input token to LP token0
    /// minAmounts The minimum amount of output tokens that must be received for
    ///   swap and AmountAMin and amountBMin for adding liquidity
    /// deadline Unix timestamp after which the transaction will revert
    /// bill Treasury bill address
    /// maxPrice Max price of treasury bill
    function zapTBill(ZapParamsTBill memory zapParamsTBill) external nonReentrant {
        IApePair pair = IApePair(zapParamsTBill.bill.principalToken());
        require(
            (zapParamsTBill.zapParams.token0 == pair.token0() && zapParamsTBill.zapParams.token1 == pair.token1()) ||
                (zapParamsTBill.zapParams.token1 == pair.token0() && zapParamsTBill.zapParams.token0 == pair.token1()),
            "ApeSwapZap: Wrong LP pair for TBill"
        );
        address to = zapParamsTBill.zapParams.to;
        zapParamsTBill.zapParams.to = address(this);
        _zapInternal(zapParamsTBill.zapParams);

        uint256 balance = pair.balanceOf(address(this));
        pair.approve(address(zapParamsTBill.bill), balance);
        zapParamsTBill.bill.deposit(balance, zapParamsTBill.maxPrice, to);
        pair.approve(address(zapParamsTBill.bill), 0);
        emit ZapTBill(zapParamsTBill);
    }

    /// @notice Zap native token to Treasury Bill
    /// @param zapParamsTBillNative all parameters for native tbill zap
    /// underlyingTokens Tokens of LP to zap to
    /// paths Path from input token to LP token0
    /// minAmounts The minimum amount of output tokens that must be received for
    ///   swap and AmountAMin and amountBMin for adding liquidity
    /// deadline Unix timestamp after which the transaction will revert
    /// bill Treasury bill address
    /// maxPrice Max price of treasury bill
    function zapTBillNative(ZapParamsTBillNative memory zapParamsTBillNative) external payable nonReentrant {
        IApePair pair = IApePair(zapParamsTBillNative.bill.principalToken());
        require(
            (zapParamsTBillNative.zapParamsNative.token0 == pair.token0() &&
                zapParamsTBillNative.zapParamsNative.token1 == pair.token1()) ||
                (zapParamsTBillNative.zapParamsNative.token1 == pair.token0() &&
                    zapParamsTBillNative.zapParamsNative.token0 == pair.token1()),
            "ApeSwapZap: Wrong LP pair for TBill"
        );
        address to = zapParamsTBillNative.zapParamsNative.to;
        zapParamsTBillNative.zapParamsNative.to = address(this);
        _zapNativeInternal(zapParamsTBillNative.zapParamsNative);

        uint256 balance = pair.balanceOf(address(this));
        pair.approve(address(zapParamsTBillNative.bill), balance);
        zapParamsTBillNative.bill.deposit(balance, zapParamsTBillNative.maxPrice, to);
        pair.approve(address(zapParamsTBillNative.bill), 0);
        emit ZapTBillNative(zapParamsTBillNative);
    }
}
