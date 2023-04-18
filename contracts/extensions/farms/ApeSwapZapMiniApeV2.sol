// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import "./libraries/IMiniApeV2.sol";
import "../../libraries/Constants.sol";
import "../../utils/TransferHelper.sol";

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

abstract contract ApeSwapZapMiniApeV2 is TransferHelper {
    using SafeERC20 for IERC20;

    struct zapMiniApeV2Params {
        uint256 inputAmount;
        IMiniApeV2 miniApe;
        uint256 pid;
        address recipient;
    }

    event ZapMiniApeV2(zapMiniApeV2Params params);

    function zapMiniApeV2(zapMiniApeV2Params memory params) external payable {
        IERC20 inputToken = IERC20(IMiniApeV2(params.miniApe).lpToken(params.pid));
        params.inputAmount = _transferIn(inputToken, params.inputAmount);

        if (params.recipient == Constants.MSG_SENDER) params.recipient = msg.sender;
        else if (params.recipient == Constants.ADDRESS_THIS) params.recipient = address(this);

        inputToken.approve(address(params.miniApe), params.inputAmount);
        params.miniApe.deposit(params.pid, params.inputAmount, params.recipient);
        inputToken.approve(address(params.miniApe), 0);
        emit ZapMiniApeV2(params);
    }
}
