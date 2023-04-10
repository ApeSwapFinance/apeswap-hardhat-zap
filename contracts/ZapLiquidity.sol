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

 * App:             https://apeswap.finance
 * Medium:          https://ape-swap.medium.com
 * Twitter:         https://twitter.com/ape_swap
 * Discord:         https://discord.com/invite/apeswap
 * Telegram:        https://t.me/ape_swap
 * Announcements:   https://t.me/ape_swap_news
 * GitHub:          https://github.com/ApeSwapFinance 
 */

import "./interfaces/IZapLiquidity.sol";
import "./interfaces/IArrakisRouter.sol";
import "./interfaces/IArrakisPool.sol";
import "./interfaces/INonfungiblePositionManager.sol";
import "./interfaces/IApeFactory.sol";
import "./interfaces/IApePair.sol";
import "./libraries/Constants.sol";
import "./libraries/MathHelper.sol";
import "./utils/TransferHelper.sol";

import "hardhat/console.sol";

contract ZapLiquidity is IZapLiquidity, TransferHelper {
    using SafeERC20 for IERC20;

    function addLiquidityV2(
        AddLiquidityV2Params memory params
    ) external payable returns (uint256 amount0Lp, uint256 amount1Lp) {
        params.amount0Desired = _transferIn(IERC20(params.token0), params.amount0Desired);
        params.amount1Desired = _transferIn(IERC20(params.token1), params.amount1Desired);

        IERC20(params.token0).approve(address(params.lpRouter), params.amount0Desired);
        IERC20(params.token1).approve(address(params.lpRouter), params.amount1Desired);

        if (params.recipient == Constants.MSG_SENDER) params.recipient = msg.sender;
        else if (params.recipient == Constants.ADDRESS_THIS) params.recipient = address(this);

        (amount0Lp, amount1Lp, ) = IApeRouter02(params.lpRouter).addLiquidity(
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
    }

    function removeLiquidityV2(
        RemoveLiquidityV2Params memory params
    ) public returns (uint256 amountAReceived, uint256 amountBReceived) {
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
    }

    function addLiquidityV3(
        AddLiquidityV3Params memory params
    ) external payable returns (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1) {
        require(params.token0 < params.token1, "ApeSwapZap: token0 must be strictly less than token1 by sort order");

        params.amount0Desired = _transferIn(IERC20(params.token0), params.amount0Desired);
        params.amount1Desired = _transferIn(IERC20(params.token1), params.amount1Desired);

        IERC20(params.token0).approve(params.lpRouter, params.amount0Desired);
        IERC20(params.token1).approve(params.lpRouter, params.amount1Desired);

        if (params.recipient == Constants.MSG_SENDER) params.recipient = msg.sender;
        else if (params.recipient == Constants.ADDRESS_THIS) params.recipient = address(this);

        console.log(params.amount0Desired);
        console.log(params.amount1Desired);

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

        console.log(IERC20(params.token0).balanceOf(address(this)));
        console.log(IERC20(params.token1).balanceOf(address(this)));

        _transferOut(IERC20(params.token0), Constants.CONTRACT_BALANCE, msg.sender);
        _transferOut(IERC20(params.token1), Constants.CONTRACT_BALANCE, msg.sender);
    }

    function addLiquidityArrakis(
        AddLiquidityArrakisParams memory params
    ) external payable returns (uint256 amount0Lp, uint256 amount1Lp) {
        params.amount0Desired = _transferIn(IERC20(params.token0), params.amount0Desired);
        params.amount1Desired = _transferIn(IERC20(params.token1), params.amount1Desired);

        IERC20(params.token0).approve(address(params.lpRouter), params.amount0Desired);
        IERC20(params.token1).approve(address(params.lpRouter), params.amount1Desired);

        if (params.recipient == Constants.MSG_SENDER) params.recipient = msg.sender;
        else if (params.recipient == Constants.ADDRESS_THIS) params.recipient = address(this);

        // TODO: you need arrakis pool now. can we get this? or do we need to get it on chain like this
        // vars.uniV3Pool = IUniswapV3Factory(IArrakisRouter(zapParams.liquidityPath.lpRouter).factory()).getPool(
        //     zapParams.token0,
        //     zapParams.token1,
        //     zapParams.liquidityPath.uniV3PoolLPFee
        // );
        // vars.arrakisPool = MathHelper.getArrakisPool(
        //     vars.uniV3Pool,
        //     IArrakisFactoryV1(zapParams.liquidityPath.arrakisFactory)
        // );

        (amount0Lp, amount1Lp, ) = IArrakisRouter(params.lpRouter).addLiquidity(
            IArrakisPool(params.arrakisPool),
            params.amount0Desired,
            params.amount1Desired,
            params.amount0Min,
            params.amount1Min,
            params.recipient
        );

        _transferOut(IERC20(params.token0), Constants.CONTRACT_BALANCE, msg.sender);
        _transferOut(IERC20(params.token1), Constants.CONTRACT_BALANCE, msg.sender);
    }
}
