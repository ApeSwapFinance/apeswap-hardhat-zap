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

    bool public constant isZapAnalyzer = true;

    /**
     * @dev This function estimates the swap returns based on the given parameters.
     * @param params The struct containing the necessary parameters for estimating swap returns.
     *  See {SwapReturnsParams} for more information.
     * @return returnValues The struct containing the estimated swap returns.
     *  See {SwapReturns} for more information.
     */
    function estimateSwapReturns(
        SwapReturnsParams memory params
    ) external view override returns (SwapReturns memory returnValues) {
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
            (uint256 token0Ratio, uint256 token1Ratio) = UniV3LiquidityHelper.getLPAddRatio(
                params.liquidityPath.lpRouter,
                vars.token0,
                vars.token1,
                params.liquidityPath.uniV3PoolLPFee,
                params.liquidityPath.tickLower,
                params.liquidityPath.tickUpper
            );

            //V3 swap amounts
            SwapRatioParams memory swapRatioParams = SwapRatioParams({
                inputToken: vars.inputToken,
                inputAmount: params.inputAmount,
                token0: vars.token0,
                token0Ratio: token0Ratio,
                token1: vars.token1,
                token1Ratio: token1Ratio,
                swapPath0: params.swapPath0,
                swapPath1: params.swapPath1,
                fee: params.liquidityPath.uniV3PoolLPFee,
                tickLower: params.liquidityPath.tickLower,
                tickUpper: params.liquidityPath.tickUpper,
                uniV3Factory: params.liquidityPath.lpRouter,
                gammaHypervisor: address(0)
            });
            (returnValues.swapToToken0, returnValues.swapToToken1) = _getSwapRatio(swapRatioParams);
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

            uint256 token0FullInput = 10 ** TokenHelper.getTokenDecimals(vars.token0);
            uint256 token1FullInput = 10 ** TokenHelper.getTokenDecimals(vars.token1);
            (uint256 token0Ratio, uint256 token1Ratio, ) = IArrakisPool(vars.arrakisPool).getMintAmounts(
                token0FullInput,
                token1FullInput
            );

            SwapRatioParams memory swapRatioParams = SwapRatioParams({
                inputToken: vars.inputToken,
                inputAmount: params.inputAmount,
                token0: vars.token0,
                token0Ratio: token0Ratio,
                token1: vars.token1,
                token1Ratio: token1Ratio,
                swapPath0: params.swapPath0,
                swapPath1: params.swapPath1,
                fee: params.liquidityPath.uniV3PoolLPFee,
                tickLower: IArrakisPool(vars.arrakisPool).lowerTick(),
                tickUpper: IArrakisPool(vars.arrakisPool).upperTick(),
                uniV3Factory: IArrakisRouter(params.liquidityPath.lpRouter).factory(),
                gammaHypervisor: address(0)
            });

            (returnValues.swapToToken0, returnValues.swapToToken1) = _getSwapRatio(swapRatioParams);
        } else if (params.liquidityPath.liquidityType == LiquidityType.Gamma) {
            uint256 token0FullInput = 10 ** TokenHelper.getTokenDecimals(vars.token0);
            (uint256 amountStart, uint256 amountEnd) = IGammaUniProxy(
                IGammaHypervisor(params.liquidityPath.lpRouter).whitelistedAddress()
            ).getDepositAmount(params.liquidityPath.lpRouter, vars.token0, token0FullInput);
            uint256 token0Ratio = token0FullInput;
            uint256 token1Ratio = (amountStart + amountEnd) / 2;

            //Gamma swap amounts
            SwapRatioParams memory swapRatioParams = SwapRatioParams({
                inputToken: vars.inputToken,
                inputAmount: params.inputAmount,
                token0: vars.token0,
                token0Ratio: token0Ratio,
                token1: vars.token1,
                token1Ratio: token1Ratio,
                swapPath0: params.swapPath0,
                swapPath1: params.swapPath1,
                fee: 0,
                tickLower: 0,
                tickUpper: 0,
                uniV3Factory: address(0),
                gammaHypervisor: params.liquidityPath.lpRouter
            });
            (returnValues.swapToToken0, returnValues.swapToToken1) = _getSwapRatio(swapRatioParams);
        }

        uint256 fullInputToken = 10 ** TokenHelper.getTokenDecimals(vars.inputToken);
        vars.weightedPrice0 = vars.inputToken == vars.token0 ? fullInputToken : _getWeightedPrice(params.swapPath0);
        vars.weightedPrice1 = vars.inputToken == vars.token1 ? fullInputToken : _getWeightedPrice(params.swapPath1);
        returnValues.minAmountSwap0 = (returnValues.swapToToken0 * vars.weightedPrice0) / fullInputToken;
        returnValues.minAmountSwap1 = (returnValues.swapToToken1 * vars.weightedPrice1) / fullInputToken;
    }

    struct SwapRatioParams {
        address inputToken;
        uint256 inputAmount;
        address token0;
        uint256 token0Ratio;
        address token1;
        uint256 token1Ratio;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        SwapPath[] swapPath0;
        SwapPath[] swapPath1;
        address uniV3Factory;
        address gammaHypervisor;
    }

    /// @notice Get ratio of how much of input token to swap to underlying tokens for lp to match ratio in pool
    /// @param swapRatioParams swap ratio params
    function _getSwapRatio(
        SwapRatioParams memory swapRatioParams
    ) internal view returns (uint256 amount0, uint256 amount1) {
        bool swap = false;
        if (swapRatioParams.token1 < swapRatioParams.token0) {
            (swapRatioParams.token0, swapRatioParams.token1) = (swapRatioParams.token1, swapRatioParams.token0);
            (swapRatioParams.swapPath0, swapRatioParams.swapPath1) = (
                swapRatioParams.swapPath1,
                swapRatioParams.swapPath0
            );
            swap = true;
        }

        uint256 weightedPrice0 = swapRatioParams.inputToken == swapRatioParams.token0
            ? 1e18
            : _getWeightedPrice(swapRatioParams.swapPath0);
        uint256 weightedPrice1 = swapRatioParams.inputToken == swapRatioParams.token1
            ? 1e18
            : _getWeightedPrice(swapRatioParams.swapPath1);

        uint256 lpRatio = ((swapRatioParams.token0Ratio * 1e36) / swapRatioParams.token0Ratio);
        amount0 =
            (((lpRatio * weightedPrice1) / 1e18) * swapRatioParams.inputAmount) /
            (((lpRatio * weightedPrice1) / 1e18) + 1e18 * weightedPrice0);
        amount1 = swapRatioParams.inputAmount - amount0;

        if (swap) {
            (amount0, amount1) = (amount1, amount0);
        }
    }

    /// @notice Returns value based on other token
    /// @param fullPath swap path
    /// @return weightedPrice value of last token of path based on first
    function _getWeightedPrice(SwapPath[] memory fullPath) internal view returns (uint256 weightedPrice) {
        weightedPrice = 1e18;
        for (uint256 i = 0; i < fullPath.length; i++) {
            SwapPath memory path = fullPath[i];
            if (path.swapType == SwapType.V2) {
                // Calculate the full token amount based on the token's decimals
                uint256 fullTokenAmount = 10 ** TokenHelper.getTokenDecimals(path.path[0]);

                // Determine the precision for the adjusted amount
                // The goal is to reduce the impact of slippage, especially when dealing with tokens that 
                // have high value or low liquidity. For example, swapping 1 full BTC could cause significant 
                // slippage in a pool with low liquidity, but swapping a smaller fraction of BTC would be less likely
                // to cause high slippage.
                // However, we also want to avoid increasing the precision too much, as this could lead to 
                // rounding errors. For example, swapping 1000 USDC (6 decimals) could return 0 due to rounding errors.
                uint256 precision = 1e6; // Use a precision of 1e6 for tokens with more than 12 decimals
                if (fullTokenAmount <= 1e12) {
                    precision = 1e4; // Use a precision of 1e4 for tokens with more than 6 decimals
                } else if (fullTokenAmount <= 1e6) {
                    precision = 1e2; // Use a precision of 1e2 for tokens with less than or equal to 6 decimals
                }
                uint256 adjustedAmount = fullTokenAmount / precision;

                uint256[] memory amountsOut = IV2SwapRouter02(path.swapRouter).getAmountsOut(adjustedAmount, path.path);
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
