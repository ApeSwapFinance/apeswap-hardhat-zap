// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import "../../ApeSwapZap.sol";
import "./lib/ICErc20.sol";

abstract contract ApeSwapZapLending is ApeSwapZap {
    using SafeERC20 for IERC20;
    using SafeERC20 for ICErc20;

    event ZapLending(IERC20 inputToken, uint256 inputAmount, ICErc20 market);
    event ZapLendingNative(uint256 inputAmount, ICErc20 market);

    /// @dev Native token market underlying
    address public constant NATIVE_UNDERLYING = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    constructor() {}

    /// @notice Zap token single asset lending market
    /// @param inputToken Input token to zap
    /// @param inputAmount Amount of input tokens to zap
    /// @param path Path from input token to stake token
    /// @param minAmountsSwap The minimum amount of output tokens that must be received for swap
    /// @param deadline Unix timestamp after which the transaction will revert
    /// @param market Lending market to deposit to
    function zapLendingMarket(
        IERC20 inputToken,
        uint256 inputAmount,
        address[] calldata path,
        uint256 minAmountsSwap,
        uint256 deadline,
        ICErc20 market
    ) external nonReentrant {
        _validateLendingMarketZap(inputToken, path, market);

        uint256 balanceBefore = _getBalance(inputToken);
        inputToken.safeTransferFrom(msg.sender, address(this), inputAmount);
        inputAmount = _getBalance(inputToken) - balanceBefore;

        inputToken.approve(address(router), inputAmount);
        _routerSwap(inputAmount, minAmountsSwap, path, deadline);
        (, uint256 cTokensReceived) = _mintLendingMarket(market);
        market.transfer(msg.sender, cTokensReceived);

        emit ZapLending(inputToken, inputAmount, market);
    }

    /// @notice Zap native token to a Lending Market
    /// @param path Path from input token to stake token
    /// @param minAmountsSwap The minimum amount of output tokens that must be received for swap
    /// @param deadline Unix timestamp after which the transaction will revert
    /// @param market Lending market to deposit to
    function zapLendingMarketNative(
        address[] calldata path,
        uint256 minAmountsSwap,
        uint256 deadline,
        ICErc20 market
    ) external payable nonReentrant {
        (uint256 inputAmount, IERC20 inputToken) = _wrapNative();
        _validateLendingMarketZap(inputToken, path, market);

        inputToken.approve(address(router), inputAmount);
        _routerSwap(inputAmount, minAmountsSwap, path, deadline);
        (, uint256 cTokensReceived) = _mintLendingMarket(market);
        market.transfer(msg.sender, cTokensReceived);

        emit ZapLendingNative(inputAmount, market);
    }

    function _validateLendingMarketZap(
        IERC20 inputToken,
        address[] calldata path,
        ICErc20 market
    ) private view returns (IERC20 underlyingToken) {
        underlyingToken = IERC20(market.underlying());
        if (address(underlyingToken) == NATIVE_UNDERLYING) {
            underlyingToken = IERC20(WNATIVE);
        }
        require(
            (address(inputToken) == path[0] && address(underlyingToken) == path[path.length - 1]),
            "ApeSwapZapLending: Wrong path for inputToken or principalToken"
        );
    }

    function _mintLendingMarket(ICErc20 market) private returns (uint256 depositAmount, uint256 cTokensReceived) {
        IERC20 underlyingToken = IERC20(market.underlying());
        if (underlyingToken == IERC20(WNATIVE) || address(underlyingToken) == NATIVE_UNDERLYING) {
            depositAmount = _unwrapNative();
            market.mint{value: depositAmount}();
        } else {
            depositAmount = underlyingToken.balanceOf(address(this));
            underlyingToken.approve(address(market), depositAmount);
            uint256 mintFailure = market.mint(depositAmount);
            require(mintFailure == 0, "ApeSwapZapLending: Mint failed");
            underlyingToken.approve(address(market), 0);
        }
        cTokensReceived = market.balanceOf(address(this));
        require(cTokensReceived > 0, "ApeSwapZapLending: Nothing deposited");
    }
}
