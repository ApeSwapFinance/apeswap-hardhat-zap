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

import "../interfaces/IApeFactory.sol";
import "../interfaces/IArrakisRouter.sol";
import "../interfaces/IZapAnalyzer.sol";
import "../libraries/MathHelper.sol";

import "hardhat/console.sol";

contract ZapAnalyzer is IZapAnalyzer {
    struct minAmountsLocalVars {
        uint256 inputAmountHalf;
        IApeFactory factory;
        address token0;
        address token1;
        address inputToken;
        uint256 amount0;
        uint256 amount1;
        uint256 reserveA;
        uint256 reserveB;
        address uniV3Pool;
        address arrakisPool;
        uint256 weightedPrice0;
        uint256 weightedPrice1;
    }

    /// @notice get min amounts for swaps
    /// @param params all params
    function estimateSwapReturns(
        SwapReturnsParams memory params
    ) external view returns (SwapReturns memory returnValues) {
        minAmountsLocalVars memory vars;

        console.log("START");
        vars.token0 = params.path0.length == 0
            ? params.path1[0].path[0]
            : params.path0[params.path0.length - 1].path[params.path0[params.path0.length - 1].path.length - 1];
        vars.token1 = params.path1.length == 0
            ? params.path0[0].path[0]
            : params.path1[params.path1.length - 1].path[params.path1[params.path1.length - 1].path.length - 1];
        vars.inputToken = params.path0.length > 0 ? params.path0[0].path[0] : params.path1[0].path[0];

        console.log(vars.token0, vars.token1, vars.inputToken);

        if (params.liquidityPath.liquidityType == LiquidityType.V2) {
            //V2 swap amounts
            returnValues.swapToToken0 = params.inputAmount / 2;
            returnValues.swapToToken1 = params.inputAmount / 2;
        } else if (params.liquidityPath.liquidityType == LiquidityType.V3) {
            MathHelper.SwapRatioParams memory swapRatioParams = MathHelper.SwapRatioParams({
                inputToken: vars.inputToken,
                inputAmount: params.inputAmount,
                token0: vars.token0,
                token1: vars.token1,
                path0: params.path0,
                path1: params.path1,
                fee: params.liquidityPath.uniV3PoolLPFee,
                tickLower: params.liquidityPath.tickLower,
                tickUpper: params.liquidityPath.tickUpper,
                uniV3Factory: params.liquidityPath.lpRouter
            });
            (returnValues.swapToToken0, returnValues.swapToToken1) = MathHelper.getSwapRatio(swapRatioParams);
        } else if (params.liquidityPath.liquidityType == LiquidityType.Arrakis) {
            vars.uniV3Pool = IUniswapV3Factory(IArrakisRouter(params.liquidityPath.lpRouter).factory()).getPool(
                vars.token0,
                vars.token1,
                params.liquidityPath.uniV3PoolLPFee
            );
            vars.arrakisPool = MathHelper.getArrakisPool(
                vars.uniV3Pool,
                IArrakisFactoryV1(params.liquidityPath.arrakisFactory)
            );
            MathHelper.SwapRatioParams memory swapRatioParams = MathHelper.SwapRatioParams({
                inputToken: vars.inputToken,
                inputAmount: params.inputAmount,
                token0: vars.token0,
                token1: vars.token1,
                path0: params.path0,
                path1: params.path1,
                fee: params.liquidityPath.uniV3PoolLPFee,
                tickLower: IArrakisPool(vars.arrakisPool).lowerTick(),
                tickUpper: IArrakisPool(vars.arrakisPool).upperTick(),
                uniV3Factory: IArrakisRouter(params.liquidityPath.lpRouter).factory()
            });
            (returnValues.swapToToken0, returnValues.swapToToken1) = MathHelper.getSwapRatio(swapRatioParams);
        }
        console.log("swapToTokens", returnValues.swapToToken0, returnValues.swapToToken1);

        vars.weightedPrice0 = vars.inputToken == vars.token0 ? 1e18 : MathHelper.getWeightedPrice(params.path0);
        vars.weightedPrice1 = vars.inputToken == vars.token1 ? 1e18 : MathHelper.getWeightedPrice(params.path1);
        returnValues.minAmountSwap0 = (returnValues.swapToToken0 * vars.weightedPrice0) / 1e18;
        returnValues.minAmountLP0 = returnValues.minAmountSwap0;
        returnValues.minAmountSwap1 = (returnValues.swapToToken1 * vars.weightedPrice1) / 1e18;
        returnValues.minAmountLP1 = returnValues.minAmountSwap1;

        return returnValues;
    }
}
