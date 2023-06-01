// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.15;

import "../libraries/Constants.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract TransferHelper {
    using SafeERC20 for IERC20;

    /// @notice transfer tokens in if necessary
    /// @param token input token
    /// @param inputAmount input amount
    function _transferIn(IERC20 token, uint256 inputAmount) internal returns (uint256) {
        if (inputAmount == Constants.CONTRACT_BALANCE) {
            inputAmount = _getBalance(token);
        } else {
            uint256 balanceBefore = _getBalance(token);
            token.safeTransferFrom(msg.sender, address(this), inputAmount);
            inputAmount = _getBalance(token) - balanceBefore;
        }
        return inputAmount;
    }

    /// @notice transfer tokens out if necessary
    /// @param token input token
    /// @param outputAmount output amount
    /// @param recipient transfer tokens to this address
    function _transferOut(IERC20 token, uint256 outputAmount, address recipient) internal returns (uint256) {
        if (outputAmount == Constants.CONTRACT_BALANCE) {
            /// @dev Returns balance in contract. Does not transfer tokens out.
            outputAmount = _getBalance(token);
        }
        if (outputAmount > 0) {
            token.safeTransfer(recipient, outputAmount);
        }
        return outputAmount;
    }

    function _getBalance(IERC20 token) internal view returns (uint256 balance) {
        balance = token.balanceOf(address(this));
    }
}
