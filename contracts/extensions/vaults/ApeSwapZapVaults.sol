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
    /// @param lpTokens Tokens of LP to zap to
    /// @param path0 Path from input token to LP token0
    /// @param path1 Path from input token to LP token1
    /// @param minAmountsSwap The minimum amount of output tokens that must be received for swap
    /// @param minAmountsLP AmountAMin and amountBMin for adding liquidity
    /// @param deadline Unix timestamp after which the transaction will revert
    /// @param vaultPid Vault address
    function zapVault(
        IERC20 inputToken,
        uint256 inputAmount,
        address[] memory lpTokens, //[token0, token1]
        address[] calldata path0,
        address[] calldata path1,
        uint256[] memory minAmountsSwap, //[A, B]
        uint256[] memory minAmountsLP, //[amountAMin, amountBMin]
        uint256 deadline,
        IMaximizerVaultApe maximizerVaultApe,
        uint256 vaultPid
    ) external nonReentrant {
        IApePair pair = _validateVault(lpTokens, maximizerVaultApe, vaultPid);
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
        pair.approve(address(maximizerVaultApe), balance);
        maximizerVaultApe.depositTo(vaultPid, msg.sender, balance);
        pair.approve(address(maximizerVaultApe), 0);
        emit ZapVault(inputToken, inputAmount, vaultPid);
    }

    /// @notice Zap native into banana/gnana vault
    /// @param lpTokens Tokens of LP to zap to
    /// @param path0 Path from input token to LP token0
    /// @param path1 Path from input token to LP token1
    /// @param minAmountsSwap The minimum amount of output tokens that must be received for swap
    /// @param minAmountsLP AmountAMin and amountBMin for adding liquidity
    /// @param deadline Unix timestamp after which the transaction will revert
    /// @param vaultPid Vault pid
    function zapVaultNative(
        address[] memory lpTokens, //[token0, token1]
        address[] calldata path0,
        address[] calldata path1,
        uint256[] memory minAmountsSwap, //[A, B]
        uint256[] memory minAmountsLP, //[amountAMin, amountBMin]
        uint256 deadline,
        IMaximizerVaultApe maximizerVaultApe,
        uint256 vaultPid
    ) external payable nonReentrant {
        IApePair pair = _validateVault(lpTokens, maximizerVaultApe, vaultPid);
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

        uint256 balance = pair.balanceOf(address(this));
        pair.approve(address(maximizerVaultApe), balance);
        maximizerVaultApe.depositTo(vaultPid, msg.sender, balance);
        pair.approve(address(maximizerVaultApe), 0);
        emit ZapVaultNative(msg.value, vaultPid);
    }

    /** PRIVATE FUNCTIONs **/

    function _validateVault(
        address[] memory lpTokens,
        IMaximizerVaultApe maximizerVaultApe,
        uint256 vaultPid
    ) private view returns (IApePair pair) {
        IBaseBananaMaximizerStrategy vault = IBaseBananaMaximizerStrategy(maximizerVaultApe.vaults(vaultPid));
        pair = IApePair(vault.STAKE_TOKEN_ADDRESS());
        require(
            (lpTokens[0] == pair.token0() && lpTokens[1] == pair.token1()) ||
                (lpTokens[1] == pair.token0() && lpTokens[0] == pair.token1()),
            "ApeSwapZap: Wrong LP pair for Vault"
        );
    }
}
