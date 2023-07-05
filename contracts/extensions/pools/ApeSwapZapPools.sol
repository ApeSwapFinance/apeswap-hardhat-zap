// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import "./libraries/IBEP20RewardApeV5.sol";
import "./libraries/ITreasury.sol";
import "../../libraries/Constants.sol";
import "../../utils/TransferHelper.sol";
import "../../utils/MulticallGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

abstract contract ApeSwapZapPools is TransferHelper, MulticallGuard {
    using SafeERC20 for IERC20;

    struct ZapPoolParams {
        uint256 inputAmount;
        IBEP20RewardApeV5 pool;
        address recipient;
    }

    IERC20 public immutable BANANA;
    IERC20 public immutable GNANA;
    ITreasury public immutable GNANA_TREASURY; // Golden Banana Treasury

    event ZapPool(ZapPoolParams params);

    constructor(ITreasury goldenBananaTreasury) {
        ITreasury gnanaTreasury;
        IERC20 banana;
        IERC20 gnana;
        if (block.chainid == 56) {
            /// @dev The Golden Banana Treasury only exists on BNB Chain
            require(address(goldenBananaTreasury) != address(0), "Must provide Golden BANANA Treasury for BNB Chain");
        }

        if (address(goldenBananaTreasury) != address(0)) {
            gnanaTreasury = goldenBananaTreasury;
            banana = gnanaTreasury.banana();
            gnana = gnanaTreasury.goldenBanana();
        } else {
            gnanaTreasury = ITreasury(address(0));
            banana = IERC20(address(0));
            gnana = IERC20(address(0));
        }
        /// @dev Can't access immutable variables in constructor
        /// @dev Can't initialize immutable variables in if statement.
        GNANA_TREASURY = gnanaTreasury;
        BANANA = banana;
        GNANA = gnana;
    }

    function zapPool(ZapPoolParams memory params) external payable multicallGuard(true, msg.value == 0) {
        require(
            params.recipient != address(0) &&
                params.recipient != address(this) &&
                params.recipient != Constants.ADDRESS_THIS,
            "ApeSwapZap: Recipient can't be address(0) or address(this)"
        );

        IERC20 inputToken = params.pool.STAKE_TOKEN();

        if (params.recipient == Constants.MSG_SENDER) params.recipient = msg.sender;

        if (inputToken == GNANA) {
            params.inputAmount = _transferIn(BANANA, params.inputAmount);
            IERC20(BANANA).approve(address(GNANA_TREASURY), params.inputAmount);
            uint256 beforeAmount = inputToken.balanceOf(address(this));
            GNANA_TREASURY.buy(params.inputAmount);
            params.inputAmount = inputToken.balanceOf(address(this)) - beforeAmount;
        } else {
            params.inputAmount = _transferIn(inputToken, params.inputAmount);
        }

        inputToken.approve(address(params.pool), params.inputAmount);
        params.pool.depositTo(params.inputAmount, params.recipient);
        inputToken.approve(address(params.pool), 0);
        emit ZapPool(params);
    }
}
