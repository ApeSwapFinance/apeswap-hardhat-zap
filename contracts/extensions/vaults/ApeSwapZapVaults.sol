// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import "./libraries/IMaximizerVaultApe.sol";
import "./libraries/IBaseBananaMaximizerStrategy.sol";
import "../../libraries/Constants.sol";
import "../../utils/TransferHelper.sol";

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

abstract contract ApeSwapZapVaults is TransferHelper {
    using SafeERC20 for IERC20;

    event ZapVault(IERC20 inputToken, uint256 inputAmount, uint256 vaultPid);

    struct zapVaultParams {
        uint256 inputAmount;
        IMaximizerVaultApe maximizerVaultApe;
        uint256 vaultPid;
        address recipient;
    }

    function zapVault(zapVaultParams memory params) external {
        IBaseBananaMaximizerStrategy vault = IBaseBananaMaximizerStrategy(
            params.maximizerVaultApe.vaults(params.vaultPid)
        );
        IERC20 inputToken = IERC20(vault.STAKE_TOKEN_ADDRESS());
        params.inputAmount = _transferIn(inputToken, params.inputAmount);

        if (params.recipient == Constants.MSG_SENDER) params.recipient = msg.sender;
        else if (params.recipient == Constants.ADDRESS_THIS) params.recipient = address(this);

        inputToken.approve(address(params.maximizerVaultApe), params.inputAmount);
        params.maximizerVaultApe.depositTo(params.vaultPid, params.recipient, params.inputAmount);
        inputToken.approve(address(params.maximizerVaultApe), 0);
        emit ZapVault(inputToken, params.inputAmount, params.vaultPid);
    }
}
