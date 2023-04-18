// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import "./lib/ICErc20.sol";
import "../../utils/TransferHelper.sol";

abstract contract ApeSwapZapLending is TransferHelper {
    using SafeERC20 for IERC20;
    using SafeERC20 for ICErc20;

    /// @dev Native token market underlying
    address public constant LENDING_NATIVE_UNDERLYING = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    event ZapLending(uint256 inputAmount, ICErc20 market, uint256 outputAmount);
    event ZapLendingMarket(uint256 inputAmount, ICErc20 market);

    /// @notice Zap token single asset lending market
    /// @param inputAmount Amount of input tokens to zap
    /// @param market Lending market to deposit to
    /// @param recipient Recipient of cTokens
    function zapLendingMarket(
        uint256 inputAmount,
        ICErc20 market,
        address recipient
    ) external payable {
        IERC20 underlyingToken = IERC20(market.underlying());

        if (address(underlyingToken) == LENDING_NATIVE_UNDERLYING) {
            uint256 depositAmount = inputAmount == 0 ? address(this).balance : inputAmount;
            market.mint{value: depositAmount}();
        } else {
            inputAmount = _transferIn(underlyingToken, inputAmount);
            uint256 depositAmount = underlyingToken.balanceOf(address(this));
            underlyingToken.approve(address(market), depositAmount);
            uint256 mintFailure = market.mint(depositAmount);
            require(mintFailure == 0, "ApeSwapZapLending: Mint failed");
            underlyingToken.approve(address(market), 0);
        }
        uint256 cTokensReceived = market.balanceOf(address(this));
        require(cTokensReceived > 0, "ApeSwapZapLending: Nothing deposited");

        if (recipient == Constants.MSG_SENDER) recipient = msg.sender;

        if (recipient != Constants.ADDRESS_THIS && recipient != address(this)) {
            underlyingToken.transfer(recipient, cTokensReceived);
        }

        emit ZapLending(inputAmount, market, cTokensReceived);
    }
}
