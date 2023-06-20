// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.15;

/*
  ______                     ______                                 
 /      \                   /      \                                
|  ▓▓▓▓▓▓\ ______   ______ |  ▓▓▓▓▓▓\__   __   __  ______   ______  
| ▓▓__| ▓▓/      \ /      \| ▓▓___\▓▓  \ |  \ |  \|      \ /      \ 
| ▓▓    ▓▓  ▓▓▓▓▓▓\  ▓▓▓▓▓▓\\▓▓    \| ▓▓ | ▓▓ | ▓▓ \▓▓▓▓▓▓\  ▓▓▓▓▓▓\
| ▓▓▓▓▓▓▓▓ ▓▓  | ▓▓ ▓▓    ▓▓_\▓▓▓▓▓▓\ ▓▓ | ▓▓ | ▓▓/      ▓▓ ▓▓  | ▓▓
| ▓▓  | ▓▓ ▓▓__/ ▓▓ ▓▓▓▓▓▓▓▓  \__| ▓▓ ▓▓_/ ▓▓_/ ▓▓  ▓▓▓▓▓▓▓ ▓▓__/ ▓▓
| ▓▓  | ▓▓ ▓▓    ▓▓\▓▓     \\▓▓    ▓▓\▓▓   ▓▓   ▓▓\▓▓    ▓▓ ▓▓    ▓▓
 \▓▓   \▓▓ ▓▓▓▓▓▓▓  \▓▓▓▓▓▓▓ \▓▓▓▓▓▓  \▓▓▓▓▓\▓▓▓▓  \▓▓▓▓▓▓▓ ▓▓▓▓▓▓▓ 
         | ▓▓                                             | ▓▓      
         | ▓▓                                             | ▓▓      
          \▓▓                                              \▓▓         
 * App:             https://ApeSwap.finance
 * Medium:          https://ape-swap.medium.com
 * Twitter:         https://twitter.com/ape_swap
 * Telegram:        https://t.me/ape_swap
 * Announcements:   https://t.me/ape_swap_news
 * Discord:         https://ApeSwap.click/discord
 * Reddit:          https://reddit.com/r/ApeSwap
 * Instagram:       https://instagram.com/ApeSwap.finance
 * GitHub:          https://github.com/ApeSwapFinance
 */

import "./features/arrakis/lib/IArrakisRouter.sol";
import "./features/arrakis/lib/IArrakisPool.sol";
import "./features/arrakis/ArrakisHelper.sol";
import "./features/univ3/lib/INonfungiblePositionManager.sol";
import "./features/univ2/lib/IApePair.sol";
import "./features/univ2/lib/IV2LiquidityRouter02.sol";
import "./features/gamma/lib/IGammaUniProxy.sol";
import "./features/gamma/lib/IGammaHypervisor.sol";
import "../../libraries/Constants.sol";
import "../../utils/TransferHelper.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";

contract ZapLiquidity is TransferHelper {
    using SafeERC20 for IERC20;

    struct AddLiquidityV2Params {
        IV2LiquidityRouter02 lpRouter;
        address token0;
        address token1;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        address recipient;
        uint256 deadline;
    }

    struct RemoveLiquidityV2Params {
        IV2LiquidityRouter02 router;
        IApePair lp;
        uint256 amount;
        uint256 amountAMinRemove;
        uint256 amountBMinRemove;
        address recipient;
        uint256 deadline;
    }

    struct AddLiquidityV3Params {
        address lpRouter;
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        address recipient;
        uint256 deadline;
    }

    struct AddLiquidityArrakisParams {
        IArrakisRouter lpRouter;
        address token0;
        address token1;
        uint24 fee;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        address recipient;
        uint256 deadline;
        address arrakisFactory;
    }

    struct AddLiquidityGammaParams {
        address hypervisor;
        address token0;
        address token1;
        uint256 amount0Desired;
        uint256 amount1Desired;
        address recipient;
        uint256[4] inMin;
    }

    struct RemoveLiquidityGammaParams {
        address hypervisor;
        uint256 shares;
        address recipient;
        uint256[4] minAmounts;
    }

    event AddLiquidityV2(AddLiquidityV2Params params);
    event RemoveLiquidityV2(RemoveLiquidityV2Params params);
    event AddLiquidityV3(AddLiquidityV3Params params);
    event AddLiquidityArrakis(AddLiquidityArrakisParams params);
    event AddLiquidityGamma(AddLiquidityGammaParams params);
    event RemoveLiquidityGamma(RemoveLiquidityGammaParams params);

    function addLiquidityV2(AddLiquidityV2Params memory params)
        external
        payable
        returns (uint256 amount0Lp, uint256 amount1Lp)
    {
        require(params.recipient != address(0), "ApeSwapZap: Recipient can't be address(0)");
        if (params.recipient == Constants.MSG_SENDER) params.recipient = msg.sender;
        else if (params.recipient == Constants.ADDRESS_THIS) params.recipient = address(this);

        params.amount0Desired = _transferIn(IERC20(params.token0), params.amount0Desired);
        params.amount1Desired = _transferIn(IERC20(params.token1), params.amount1Desired);

        IERC20(params.token0).safeApprove(address(params.lpRouter), params.amount0Desired);
        IERC20(params.token1).safeApprove(address(params.lpRouter), params.amount1Desired);

        (amount0Lp, amount1Lp, ) = params.lpRouter.addLiquidity(
            params.token0,
            params.token1,
            params.amount0Desired,
            params.amount1Desired,
            params.amount0Min,
            params.amount1Min,
            params.recipient,
            params.deadline
        );

        _transferOut(IERC20(params.token0), Constants.CONTRACT_BALANCE, msg.sender);
        _transferOut(IERC20(params.token1), Constants.CONTRACT_BALANCE, msg.sender);

        IERC20(params.token0).safeApprove(address(params.lpRouter), 0);
        IERC20(params.token1).safeApprove(address(params.lpRouter), 0);

        emit AddLiquidityV2(params);
    }

    function removeLiquidityV2(RemoveLiquidityV2Params memory params)
        public
        payable
        returns (uint256 amountAReceived, uint256 amountBReceived)
    {
        require(params.recipient != address(0), "ApeSwapZap: Recipient can't be address(0)");
        if (params.recipient == Constants.MSG_SENDER) params.recipient = msg.sender;
        else if (params.recipient == Constants.ADDRESS_THIS) params.recipient = address(this);

        address token0 = params.lp.token0();
        address token1 = params.lp.token1();

        params.amount = _transferIn(IERC20(address(params.lp)), params.amount);
        params.lp.approve(address(params.router), params.amount);
        (amountAReceived, amountBReceived) = params.router.removeLiquidity(
            token0,
            token1,
            params.amount,
            params.amountAMinRemove,
            params.amountBMinRemove,
            params.recipient,
            params.deadline
        );
        emit RemoveLiquidityV2(params);
    }

    function addLiquidityV3(AddLiquidityV3Params memory params)
        external
        payable
        returns (
            uint256 tokenId,
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        )
    {
        require(params.token0 < params.token1, "ZapLiquidity: token0 must be strictly less than token1 by sort order");
        require(params.recipient != address(0), "ApeSwapZap: Recipient can't be address(0)");
        if (params.recipient == Constants.MSG_SENDER) params.recipient = msg.sender;
        else if (params.recipient == Constants.ADDRESS_THIS) params.recipient = address(this);

        params.amount0Desired = _transferIn(IERC20(params.token0), params.amount0Desired);
        params.amount1Desired = _transferIn(IERC20(params.token1), params.amount1Desired);

        IERC20(params.token0).safeApprove(params.lpRouter, params.amount0Desired);
        IERC20(params.token1).safeApprove(params.lpRouter, params.amount1Desired);

        (tokenId, liquidity, amount0, amount1) = INonfungiblePositionManager(params.lpRouter).mint(
            INonfungiblePositionManager.MintParams({
                token0: params.token0,
                token1: params.token1,
                fee: params.fee,
                tickLower: params.tickLower,
                tickUpper: params.tickUpper,
                amount0Desired: params.amount0Desired,
                amount1Desired: params.amount1Desired,
                amount0Min: params.amount0Min,
                amount1Min: params.amount1Min,
                recipient: params.recipient,
                deadline: params.deadline
            })
        );

        _transferOut(IERC20(params.token0), Constants.CONTRACT_BALANCE, msg.sender);
        _transferOut(IERC20(params.token1), Constants.CONTRACT_BALANCE, msg.sender);

        IERC20(params.token0).safeApprove(params.lpRouter, 0);
        IERC20(params.token1).safeApprove(params.lpRouter, 0);

        emit AddLiquidityV3(params);
    }

    function addLiquidityArrakis(AddLiquidityArrakisParams memory params)
        external
        payable
        returns (uint256 amount0Lp, uint256 amount1Lp)
    {
        require(params.recipient != address(0), "ApeSwapZap: Recipient can't be address(0)");
        if (params.recipient == Constants.MSG_SENDER) params.recipient = msg.sender;
        else if (params.recipient == Constants.ADDRESS_THIS) params.recipient = address(this);

        params.amount0Desired = _transferIn(IERC20(params.token0), params.amount0Desired);
        params.amount1Desired = _transferIn(IERC20(params.token1), params.amount1Desired);

        IERC20(params.token0).safeApprove(address(params.lpRouter), params.amount0Desired);
        IERC20(params.token1).safeApprove(address(params.lpRouter), params.amount1Desired);

        address uniV3Pool = IUniswapV3Factory(params.lpRouter.factory()).getPool(
            params.token0,
            params.token1,
            params.fee
        );
        address arrakisPool = ArrakisHelper.getArrakisPool(uniV3Pool, IArrakisFactoryV1(params.arrakisFactory));

        (amount0Lp, amount1Lp, ) = params.lpRouter.addLiquidity(
            IArrakisPool(arrakisPool),
            params.amount0Desired,
            params.amount1Desired,
            params.amount0Min,
            params.amount1Min,
            params.recipient
        );

        _transferOut(IERC20(params.token0), Constants.CONTRACT_BALANCE, msg.sender);
        _transferOut(IERC20(params.token1), Constants.CONTRACT_BALANCE, msg.sender);

        IERC20(params.token0).safeApprove(address(params.lpRouter), 0);
        IERC20(params.token1).safeApprove(address(params.lpRouter), 0);

        emit AddLiquidityArrakis(params);
    }

    function addLiquidityGamma(AddLiquidityGammaParams memory params) external payable returns (uint256 shares) {
        require(params.recipient != address(0), "ApeSwapZap: Recipient can't be address(0)");
        if (params.recipient == Constants.MSG_SENDER) params.recipient = msg.sender;
        else if (params.recipient == Constants.ADDRESS_THIS) params.recipient = address(this);

        params.amount0Desired = _transferIn(IERC20(params.token0), params.amount0Desired);
        params.amount1Desired = _transferIn(IERC20(params.token1), params.amount1Desired);

        IERC20(params.token0).safeApprove(address(params.hypervisor), params.amount0Desired);
        IERC20(params.token1).safeApprove(address(params.hypervisor), params.amount1Desired);

        shares = IGammaUniProxy(IGammaHypervisor(params.hypervisor).whitelistedAddress()).deposit(
            params.amount0Desired,
            params.amount1Desired,
            params.recipient,
            params.hypervisor,
            params.inMin
        );

        _transferOut(IERC20(params.hypervisor), Constants.CONTRACT_BALANCE, params.recipient);
        _transferOut(IERC20(params.token0), Constants.CONTRACT_BALANCE, msg.sender);
        _transferOut(IERC20(params.token1), Constants.CONTRACT_BALANCE, msg.sender);

        IERC20(params.token0).safeApprove(address(params.hypervisor), 0);
        IERC20(params.token1).safeApprove(address(params.hypervisor), 0);

        emit AddLiquidityGamma(params);
    }

    function removeLiquidityGamma(RemoveLiquidityGammaParams memory params)
        external
        payable
        returns (uint256 amount0, uint256 amount1)
    {
        require(params.recipient != address(0), "ApeSwapZap: Recipient can't be address(0)");
        if (params.recipient == Constants.MSG_SENDER) params.recipient = msg.sender;
        else if (params.recipient == Constants.ADDRESS_THIS) params.recipient = address(this);

        (amount0, amount1) = IGammaHypervisor(params.hypervisor).withdraw(
            params.shares,
            params.recipient,
            msg.sender,
            params.minAmounts
        );

        emit RemoveLiquidityGamma(params);
    }
}
