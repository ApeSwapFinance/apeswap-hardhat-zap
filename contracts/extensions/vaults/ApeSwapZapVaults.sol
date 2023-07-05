// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import "./libraries/IMaximizerVaultApe.sol";
import "./libraries/IBaseBananaMaximizerStrategy.sol";
import "../../libraries/Constants.sol";
import "../../utils/TransferHelper.sol";
import "../../utils/MulticallGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

abstract contract ApeSwapZapVaults is TransferHelper, MulticallGuard {
    using SafeERC20 for IERC20;

    struct zapVaultParams {
        uint256 inputAmount;
        IMaximizerVaultApe maximizerVaultApe;
        uint256 vaultPid;
        address recipient;
    }

    event ZapVault(IERC20 inputToken, uint256 inputAmount, uint256 vaultPid);

    function zapVault(zapVaultParams memory params) external payable multicallGuard(true, msg.value == 0) {
        require(
            params.recipient != address(0) &&
                params.recipient != address(this) &&
                params.recipient != Constants.ADDRESS_THIS,
            "ApeSwapZap: Recipient can't be address(0) or address(this)"
        );

        IBaseBananaMaximizerStrategy vault = IBaseBananaMaximizerStrategy(
            params.maximizerVaultApe.vaults(params.vaultPid)
        );
        IERC20 inputToken = IERC20(vault.STAKE_TOKEN_ADDRESS());
        params.inputAmount = _transferIn(inputToken, params.inputAmount);

        if (params.recipient == Constants.MSG_SENDER) params.recipient = msg.sender;

        inputToken.approve(address(params.maximizerVaultApe), params.inputAmount);
        params.maximizerVaultApe.depositTo(params.vaultPid, params.recipient, params.inputAmount);
        inputToken.approve(address(params.maximizerVaultApe), 0);
        emit ZapVault(inputToken, params.inputAmount, params.vaultPid);
    }
}
