// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import "./lib/ICErc20.sol";
import "../../utils/TransferHelper.sol";
import "../../utils/MulticallGuard.sol";

abstract contract ApeSwapZapLending is TransferHelper, MulticallGuard {
    using SafeERC20 for IERC20;
    using SafeERC20 for ICErc20;

    /// @dev Native token market underlying
    address public constant LENDING_NATIVE_UNDERLYING = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    event ZapLending(ZapLendingMarketParams params, uint256 outputAmount);

    struct ZapLendingMarketParams {
        uint256 inputAmount;
        ICErc20 market;
        address recipient;
    }

    /// @notice Zap token single asset lending market
    function zapLendingMarket(ZapLendingMarketParams memory params) external payable multicallGuard(true, true) {
        require(params.recipient != address(0), "ApeSwapZapLending: Recipient can't be address(0)");
        /// @dev Lending oTokens can be sent to this contract for other feature deposits such as bonds
        if (params.recipient == Constants.MSG_SENDER) params.recipient = msg.sender;
        else if (params.recipient == Constants.ADDRESS_THIS) params.recipient = address(this);

        IERC20 underlyingToken = IERC20(params.market.underlying());

        if (address(underlyingToken) == LENDING_NATIVE_UNDERLYING) {
            /// @dev This validates non-multicall calls as this is a `payable` functions.
            _requireNotInMulticall(msg.value == params.inputAmount);
            uint256 depositAmount = params.inputAmount == Constants.CONTRACT_BALANCE
                ? address(this).balance
                : params.inputAmount;
            params.market.mint{value: depositAmount}();
        } else {
            /// @dev This validates non-multicall calls as this is a `payable` functions.
            _requireNotInMulticall(msg.value == 0);
            uint256 inputAmount = _transferIn(underlyingToken, params.inputAmount);
            underlyingToken.approve(address(params.market), inputAmount);
            uint256 mintFailure = params.market.mint(inputAmount);
            require(mintFailure == 0, "ApeSwapZapLending: Mint failed");
            underlyingToken.approve(address(params.market), 0);
        }
        uint256 cTokensReceived = params.market.balanceOf(address(this));
        require(cTokensReceived > 0, "ApeSwapZapLending: Nothing deposited");

        if (params.recipient == Constants.MSG_SENDER) params.recipient = msg.sender;

        if (params.recipient != Constants.ADDRESS_THIS && params.recipient != address(this)) {
            underlyingToken.safeTransfer(params.recipient, cTokensReceived);
        }

        emit ZapLending(params, cTokensReceived);
    }
}
