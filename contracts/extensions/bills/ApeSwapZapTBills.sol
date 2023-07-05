// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import "./libraries/ICustomBill.sol";
import "../../libraries/Constants.sol";
import "../../utils/TransferHelper.sol";

abstract contract ApeSwapZapTBills is TransferHelper {
    using SafeERC20 for IERC20;

    struct zapTBillParams {
        ICustomBill bill;
        uint256 inputAmount;
        uint256 maxPrice;
        address recipient;
    }

    event ZapTBill(zapTBillParams params);

    function zapTBill(zapTBillParams memory params) external payable {
        require(
            params.recipient != address(0) &&
                params.recipient != address(this) &&
                params.recipient != Constants.ADDRESS_THIS,
            "ApeSwapZap: Recipient can't be address(0) or address(this)"
        );
        if (params.recipient == Constants.MSG_SENDER) params.recipient = msg.sender;

        IERC20 inputToken = IERC20(params.bill.principalToken());
        params.inputAmount = _transferIn(inputToken, params.inputAmount);

        inputToken.approve(address(params.bill), params.inputAmount);
        params.bill.deposit(params.inputAmount, params.maxPrice, params.recipient);
        inputToken.approve(address(params.bill), 0);
        emit ZapTBill(params);
    }
}
