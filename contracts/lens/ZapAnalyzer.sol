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

import "./IZapAnalyzer.sol";
import "../extensions/liquidity/features/univ2/lib/IApeFactory.sol";
import "../extensions/liquidity/features/univ3/UniV3LiquidityHelper.sol";
import "../extensions/liquidity/features/arrakis/lib/IArrakisRouter.sol";
import "../extensions/liquidity/features/arrakis/lib/IArrakisFactoryV1.sol";
import "../extensions/liquidity/features/arrakis/ArrakisHelper.sol";
import "../extensions/liquidity/features/gamma/lib/IGammaHypervisor.sol";
import "../extensions/liquidity/features/gamma/lib/IGammaUniProxy.sol";
import "../extensions/swap/features/algebra/lib/IAlgebraFactory.sol";
import "../extensions/swap/features/algebra/lib/IAlgebraPool.sol";
import "../extensions/swap/features/algebra/AlgebraSwapHelper.sol";
import "../extensions/swap/features/univ2/lib/IV2SwapRouter02.sol";
import "../extensions/swap/features/univ3/UniV3SwapHelper.sol";
import "../utils/TokenHelper.sol";

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract ZapAnalyzer is IZapAnalyzer {
    struct minAmountsLocalVars {
        address token0;
        address token1;
        address inputToken;
        address uniV3Pool;
        address arrakisPool;
        uint256 weightedPrice0;
        uint256 weightedPrice1;
    }

    /**
     * @dev This function estimates the swap returns based on the given parameters.
     * @param params The struct containing the necessary parameters for estimating swap returns.
     *  See {SwapReturnsParams} for more information.
     * @return returnValues The struct containing the estimated swap returns.
     *  See {SwapReturns} for more information.
     */
    function estimateSwapReturns(SwapReturnsParams memory params)
        external
        view
        override
        returns (SwapReturns memory returnValues)
    {
        minAmountsLocalVars memory vars;

        vars.token0 = params.swapPath0.length == 0
            ? params.swapPath1[0].path[0]
            : params.swapPath0[params.swapPath0.length - 1].path[
                params.swapPath0[params.swapPath0.length - 1].path.length - 1
            ];
        vars.token1 = params.swapPath1.length == 0
            ? params.swapPath0[0].path[0]
            : params.swapPath1[params.swapPath1.length - 1].path[
                params.swapPath1[params.swapPath1.length - 1].path.length - 1
            ];
        vars.inputToken = params.swapPath0.length > 0 ? params.swapPath0[0].path[0] : params.swapPath1[0].path[0];

        if (params.liquidityPath.liquidityType == LiquidityType.V2) {
            //V2 swap amounts
            returnValues.swapToToken0 = params.inputAmount / 2;
            returnValues.swapToToken1 = params.inputAmount / 2;
        } else if (params.liquidityPath.liquidityType == LiquidityType.V3) {
            //V3 swap amounts
            SwapRatioParams memory swapRatioParams = SwapRatioParams({
                inputToken: vars.inputToken,
                inputAmount: params.inputAmount,
                token0: vars.token0,
                token1: vars.token1,
                swapPath0: params.swapPath0,
                swapPath1: params.swapPath1,
                fee: params.liquidityPath.uniV3PoolLPFee,
                tickLower: params.liquidityPath.tickLower,
                tickUpper: params.liquidityPath.tickUpper,
                uniV3Factory: params.liquidityPath.lpRouter,
                gammaHypervisor: address(0)
            });
            (returnValues.swapToToken0, returnValues.swapToToken1) = getSwapRatio(swapRatioParams);
        } else if (params.liquidityPath.liquidityType == LiquidityType.Arrakis) {
            //Arrakis swap amounts
            vars.uniV3Pool = IUniswapV3Factory(IArrakisRouter(params.liquidityPath.lpRouter).factory()).getPool(
                vars.token0,
                vars.token1,
                params.liquidityPath.uniV3PoolLPFee
            );
            vars.arrakisPool = ArrakisHelper.getArrakisPool(
                vars.uniV3Pool,
                IArrakisFactoryV1(params.liquidityPath.arrakisFactory)
            );
            SwapRatioParams memory swapRatioParams = SwapRatioParams({
                inputToken: vars.inputToken,
                inputAmount: params.inputAmount,
                token0: vars.token0,
                token1: vars.token1,
                swapPath0: params.swapPath0,
                swapPath1: params.swapPath1,
                fee: params.liquidityPath.uniV3PoolLPFee,
                tickLower: IArrakisPool(vars.arrakisPool).lowerTick(),
                tickUpper: IArrakisPool(vars.arrakisPool).upperTick(),
                uniV3Factory: IArrakisRouter(params.liquidityPath.lpRouter).factory(),
                gammaHypervisor: address(0)
            });
            (returnValues.swapToToken0, returnValues.swapToToken1) = getSwapRatio(swapRatioParams);
        } else if (params.liquidityPath.liquidityType == LiquidityType.Gamma) {
            //Gamma swap amounts
            SwapRatioParams memory swapRatioParams = SwapRatioParams({
                inputToken: vars.inputToken,
                inputAmount: params.inputAmount,
                token0: vars.token0,
                token1: vars.token1,
                swapPath0: params.swapPath0,
                swapPath1: params.swapPath1,
                fee: 0,
                tickLower: 0,
                tickUpper: 0,
                uniV3Factory: address(0),
                gammaHypervisor: params.liquidityPath.lpRouter
            });
            (returnValues.swapToToken0, returnValues.swapToToken1) = getSwapRatio(swapRatioParams);
        }

        uint256 fullInputToken = 10**TokenHelper.getTokenDecimals(vars.inputToken);
        vars.weightedPrice0 = vars.inputToken == vars.token0 ? fullInputToken : getWeightedPrice(params.swapPath0);
        vars.weightedPrice1 = vars.inputToken == vars.token1 ? fullInputToken : getWeightedPrice(params.swapPath1);
        returnValues.minAmountSwap0 = (returnValues.swapToToken0 * vars.weightedPrice0) / fullInputToken;
        returnValues.minAmountSwap1 = (returnValues.swapToToken1 * vars.weightedPrice1) / fullInputToken;
    }

    struct SwapRatioParams {
        address inputToken;
        uint256 inputAmount;
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        SwapPath[] swapPath0;
        SwapPath[] swapPath1;
        address uniV3Factory;
        address gammaHypervisor;
    }

    struct SwapRatioLocalVars {
        uint256 underlying0;
        uint256 underlying1;
        uint256 weightedPrice0;
        uint256 weightedPrice1;
    }

    /// @notice Get ratio of how much of input token to swap to underlying tokens for lp to match ratio in pool
    /// @param swapRatioParams swap ratio params
    function getSwapRatio(SwapRatioParams memory swapRatioParams)
        internal
        view
        returns (uint256 amount0, uint256 amount1)
    {
        bool swap = false;
        if (swapRatioParams.token1 < swapRatioParams.token0) {
            (swapRatioParams.token0, swapRatioParams.token1) = (swapRatioParams.token1, swapRatioParams.token0);
            (swapRatioParams.swapPath0, swapRatioParams.swapPath1) = (
                swapRatioParams.swapPath1,
                swapRatioParams.swapPath0
            );
            swap = true;
        }

        SwapRatioLocalVars memory vars;

        (vars.underlying0, vars.underlying1) = getLPAddRatio(
            swapRatioParams.uniV3Factory,
            swapRatioParams.token0,
            swapRatioParams.token1,
            swapRatioParams.fee,
            swapRatioParams.tickLower,
            swapRatioParams.tickUpper,
            swapRatioParams.gammaHypervisor
        );

        vars.weightedPrice0 = swapRatioParams.inputToken == swapRatioParams.token0
            ? 1e18
            : getWeightedPrice(swapRatioParams.swapPath0);
        vars.weightedPrice1 = swapRatioParams.inputToken == swapRatioParams.token1
            ? 1e18
            : getWeightedPrice(swapRatioParams.swapPath1);

        uint256 lpRatio = ((vars.underlying0 * 1e36) / vars.underlying1);
        amount0 =
            (((lpRatio * vars.weightedPrice1) / 1e18) * swapRatioParams.inputAmount) /
            (((lpRatio * vars.weightedPrice1) / 1e18) + 1e18 * vars.weightedPrice0);
        amount1 = swapRatioParams.inputAmount - amount0;

        if (swap) {
            (amount0, amount1) = (amount1, amount0);
        }
    }

    function getLPAddRatio(
        address uniV3Factory,
        address token0,
        address token1,
        uint24 fee,
        int24 tickLower,
        int24 tickUpper,
        address gammaHypervisor
    ) internal view returns (uint256 amount0, uint256 amount1) {
        if (uniV3Factory != address(0)) {
            (amount0, amount1) = UniV3LiquidityHelper.getLPAddRatio(
                uniV3Factory,
                token0,
                token1,
                fee,
                tickLower,
                tickUpper
            );
        } else if (gammaHypervisor != address(0)) {
            uint256 fullInputToken = 10**IERC20Metadata(token0).decimals();
            (uint256 amountStart, uint256 amountEnd) = IGammaUniProxy(
                IGammaHypervisor(gammaHypervisor).whitelistedAddress()
            ).getDepositAmount(gammaHypervisor, token0, fullInputToken);
            amount0 = fullInputToken;
            amount1 = (amountStart + amountEnd) / 2;
        } else {
            revert("Liquidity address not set");
        }
    }

    /// @notice Returns value based on other token
    /// @param fullPath swap path
    /// @return weightedPrice value of last token of path based on first
    function getWeightedPrice(SwapPath[] memory fullPath) internal view returns (uint256 weightedPrice) {
        weightedPrice = 1e18;
        for (uint256 i = 0; i < fullPath.length; i++) {
            SwapPath memory path = fullPath[i];
            if (path.swapType == SwapType.V2) {
                //divide by 1/2 to decrease slippage impact
                //Before it was a 1 full token which could cause a lot of slippage
                //For exanple BTC paired with some token with low liquidity
                //Swapping 1 full BTC could empty the pool. But now you swap 0.01 BTC which is less likely to empty the pool
                //We shouldn't increase precision much either. 1000 usdc (6 decimals) to usdt might return 995
                //whereas when precision is 1e6 it would return 0
                uint256 precision = 1e2;
                uint256 amount = 10**IERC20Metadata(path.path[0]).decimals() / precision;

                uint256[] memory amountsOut = IV2SwapRouter02(path.swapRouter).getAmountsOut(amount, path.path);
                weightedPrice = (weightedPrice * (amountsOut[amountsOut.length - 1] * precision)) / 1e18;
            } else if (path.swapType == SwapType.V3) {
                for (uint256 index = 0; index < path.path.length - 1; index++) {
                    weightedPrice =
                        (weightedPrice *
                            UniV3SwapHelper.pairTokensAndValue(
                                path.path[index],
                                path.path[index + 1],
                                path.uniV3PoolFees[index],
                                path.swapRouter
                            )) /
                        1e18;
                }
            } else if (path.swapType == SwapType.ALGEBRA) {
                for (uint256 index = 0; index < path.path.length - 1; index++) {
                    weightedPrice =
                        (weightedPrice *
                            AlgebraSwapHelper.pairTokensAndValue(
                                path.path[index],
                                path.path[index + 1],
                                path.swapRouter
                            )) /
                        1e18;
                }
            }
        }
    }
}
