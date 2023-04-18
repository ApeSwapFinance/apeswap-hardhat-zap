// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.15;

import "./interfaces/IWETH.sol";
import "./libraries/Constants.sol";

contract WrapNative {
    IWETH public WNative;

    constructor(IWETH _wNative) {
        WNative = _wNative;
    }

    function wrapNative(uint256 amount, address recipient) external payable {
        IWETH(WNative).deposit{value: amount}();

        if (recipient == Constants.MSG_SENDER) recipient = msg.sender;
        if (recipient != Constants.ADDRESS_THIS && recipient != address(this)) {
            WNative.transfer(recipient, amount);
        }
    }

    function unwrapNative(uint256 amount, address recipient) external {
        IWETH(WNative).withdraw(amount);

        if (recipient == Constants.MSG_SENDER) recipient = msg.sender;
        if (recipient != Constants.ADDRESS_THIS && recipient != address(this)) {
            // 2600 COLD_ACCOUNT_ACCESS_COST plus 2300 transfer gas - 1
            // Intended to support transfers to contracts, but not allow for further code execution
            (bool success, ) = recipient.call{value: amount, gas: 4899}(new bytes(0));
            require(success, "Native transfer failed");
        }
    }
}
