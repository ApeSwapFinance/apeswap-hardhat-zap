// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import "../../ApeSwapZap.sol";
import "./lib/IMaximizerVaultApe.sol";
import "./lib/IBaseBananaMaximizerStrategy.sol";

abstract contract ApeSwapZapVaults is ApeSwapZap {
    using SafeERC20 for IERC20;

    event ZapVault(IERC20 inputToken, uint256 inputAmount, uint256 vaultPid);
    event ZapVaultNative(uint256 inputAmount, uint256 vaultPid);

    constructor() {}

    /// @notice Zap token into banana/gnana vault
    /// @param inputToken Input token to zap
    /// @param inputAmount Amount of input tokens to zap
    /// @param underlyingTokens Tokens of LP to zap to
    /// @param path0 Path from input token to LP token0
    /// @param path1 Path from input token to LP token1
    /// @param minAmountsSwap The minimum amount of output tokens that must be received for swap
    /// @param minAmountsLP AmountAMin and amountBMin for adding liquidity
    /// @param deadline Unix timestamp after which the transaction will revert
    /// @param vaultPid Vault address
    function zapVault(
        IERC20 inputToken,
        uint256 inputAmount,
        address[] memory underlyingTokens, //[token0, token1]
        address[] calldata path0,
        address[] calldata path1,
        uint256[] memory minAmountsSwap, //[A, B]
        uint256[] memory minAmountsLP, //[amountAMin, amountBMin]
        uint256 deadline,
        IMaximizerVaultApe maximizerVaultApe,
        uint256 vaultPid
    ) external nonReentrant {
        IBaseBananaMaximizerStrategy vault = IBaseBananaMaximizerStrategy(maximizerVaultApe.vaults(vaultPid));
        IApePair pair = IApePair(vault.STAKE_TOKEN_ADDRESS());
        require(
            (underlyingTokens[0] == pair.token0() && underlyingTokens[1] == pair.token1()) ||
                (underlyingTokens[1] == pair.token0() && underlyingTokens[0] == pair.token1()),
            "ApeSwapZap: Wrong LP pair for Vault"
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
        pair.approve(address(maximizerVaultApe), balance);
        maximizerVaultApe.depositTo(vaultPid, msg.sender, balance);
        pair.approve(address(maximizerVaultApe), 0);
        emit ZapVault(inputToken, inputAmount, vaultPid);
    }

    /// @notice Zap native into banana/gnana vault
    /// @param underlyingTokens Tokens of LP to zap to
    /// @param path0 Path from input token to LP token0
    /// @param path1 Path from input token to LP token1
    /// @param minAmountsSwap The minimum amount of output tokens that must be received for swap
    /// @param minAmountsLP AmountAMin and amountBMin for adding liquidity
    /// @param deadline Unix timestamp after which the transaction will revert
    /// @param vaultPid Vault pid
    function zapVaultNative(
        address[] memory underlyingTokens, //[token0, token1]
        address[] calldata path0,
        address[] calldata path1,
        uint256[] memory minAmountsSwap, //[A, B]
        uint256[] memory minAmountsLP, //[amountAMin, amountBMin]
        uint256 deadline,
        IMaximizerVaultApe maximizerVaultApe,
        uint256 vaultPid
    ) external payable nonReentrant {
        IBaseBananaMaximizerStrategy vault = IBaseBananaMaximizerStrategy(maximizerVaultApe.vaults(vaultPid));
        IApePair pair = IApePair(vault.STAKE_TOKEN_ADDRESS());
        require(
            (underlyingTokens[0] == pair.token0() && underlyingTokens[1] == pair.token1()) ||
                (underlyingTokens[1] == pair.token0() && underlyingTokens[0] == pair.token1()),
            "ApeSwapZap: Wrong LP pair for Vault"
        );

        _zapNativeInternal(underlyingTokens, path0, path1, minAmountsSwap, minAmountsLP, address(this), deadline);

        uint256 balance = pair.balanceOf(address(this));
        pair.approve(address(maximizerVaultApe), balance);
        maximizerVaultApe.depositTo(vaultPid, msg.sender, balance);
        pair.approve(address(maximizerVaultApe), 0);
        emit ZapVaultNative(msg.value, vaultPid);
    }
}
