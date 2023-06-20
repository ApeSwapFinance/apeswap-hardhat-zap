// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import "./libraries/IMiniApeV2.sol";
import "../../libraries/Constants.sol";
import "../../utils/TransferHelper.sol";

abstract contract ApeSwapZapMiniApeV2 is TransferHelper {
    using SafeERC20 for IERC20;

    struct ZapMiniApeV2Params {
        uint256 inputAmount;
        IMiniApeV2 miniApe;
        uint256 pid;
        address recipient;
    }

    event ZapMiniApeV2(ZapMiniApeV2Params params);

    function zapMiniApeV2(ZapMiniApeV2Params memory params) external payable {
        require(
            params.recipient != address(0) &&
                params.recipient != address(this) &&
                params.recipient != Constants.ADDRESS_THIS,
            "ApeSwapZap: Recipient can't be address(0) or address(this)"
        );
        IERC20 inputToken = IERC20(params.miniApe.lpToken(params.pid));
        params.inputAmount = _transferIn(inputToken, params.inputAmount);

        if (params.recipient == Constants.MSG_SENDER) params.recipient = msg.sender;

        inputToken.approve(address(params.miniApe), params.inputAmount);
        params.miniApe.deposit(params.pid, params.inputAmount, params.recipient);
        inputToken.approve(address(params.miniApe), 0);
        emit ZapMiniApeV2(params);
    }
}
