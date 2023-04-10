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

import "../interfaces/IArrakisPool.sol";
import "../interfaces/IApeRouter02.sol";
import "../interfaces/IArrakisFactoryV1.sol";
import "../interfaces/IZapAnalyzer.sol";

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import "@uniswap/v3-core/contracts/libraries/FullMath.sol";
import "@uniswap/v3-core/contracts/libraries/FixedPoint96.sol";

import "hardhat/console.sol";

library MathHelper {
    struct SwapRatioParams {
        address inputToken;
        uint256 inputAmount;
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        IZapAnalyzer.SwapPath[] path0;
        IZapAnalyzer.SwapPath[] path1;
        address uniV3Factory;
    }

    struct SwapRatioLocalVars {
        uint256 underlying0;
        uint256 underlying1;
        uint256 token0decimals;
        uint256 token1decimals;
        uint256 weightedPrice0;
        uint256 weightedPrice1;
        uint256 percentage0;
        uint256 percentage1;
    }

    /// @notice Downcasts uint256 to uint128
    /// @param x The uint258 to be downcasted
    /// @return y The passed value, downcasted to uint128
    function toUint128(uint256 x) private pure returns (uint128 y) {
        require((y = uint128(x)) == x);
    }

    /// @notice Get ratio of how much of input token to swap to underlying tokens for lp to match ratio in pool
    /// @param swapRatioParams swap ratio params
    /// inputToken Input token
    /// inputAmount Input amount
    /// token0 token0 from LP
    /// token1 token1 from LP
    /// fee fee from LP
    /// path0 Path from input token to underlying token1
    /// path1 Path from input token to underlying token0
    /// uniV3PoolFees0 uniV3 pool fees for path0
    /// uniV3PoolFees1 uniV3 pool fees for path1
    /// arrakisPool arrakis pool
    /// uniV3Factory uniV3 factory
    function getSwapRatio(
        SwapRatioParams memory swapRatioParams
    ) internal view returns (uint256 amount0, uint256 amount1) {
        SwapRatioLocalVars memory vars;

        (vars.underlying0, vars.underlying1) = getLPAddRatio(
            swapRatioParams.uniV3Factory,
            swapRatioParams.token0,
            swapRatioParams.token1,
            swapRatioParams.fee,
            swapRatioParams.tickLower,
            swapRatioParams.tickUpper
        );
        console.log("underlying", vars.underlying0, vars.underlying1);

        vars.token0decimals = ERC20(address(swapRatioParams.token0)).decimals();
        vars.token1decimals = ERC20(address(swapRatioParams.token1)).decimals();
        vars.underlying0 = _normalizeTokenDecimals(vars.underlying0, vars.token0decimals);
        vars.underlying1 = _normalizeTokenDecimals(vars.underlying1, vars.token1decimals);

        vars.weightedPrice0 = swapRatioParams.inputToken == swapRatioParams.token0
            ? 1e18
            : getWeightedPrice(swapRatioParams.path0);
        vars.weightedPrice1 = swapRatioParams.inputToken == swapRatioParams.token1
            ? 1e18
            : getWeightedPrice(swapRatioParams.path1);

        uint256 lpRatio = ((vars.underlying0 * 1e18) / vars.underlying1);
        amount0 =
            (lpRatio * swapRatioParams.inputAmount * vars.weightedPrice1) /
            (1e36 + lpRatio * vars.weightedPrice1);
        amount1 = swapRatioParams.inputAmount - amount0;

        if (swapRatioParams.token1 < swapRatioParams.token0) {
            (amount0, amount1) = (amount1, amount0);
        }
    }

    function getLPAddRatio(
        address uniV3Factory,
        address token0,
        address token1,
        uint24 fee,
        int24 tickLower,
        int24 tickUpper
    ) internal view returns (uint256 amount0, uint256 amount1) {
        uint160 lowPrice = TickMath.getSqrtRatioAtTick(tickLower);
        (uint160 currentPrice, , , , , , ) = IUniswapV3Pool(
            IUniswapV3Factory(uniV3Factory).getPool(token0, token1, fee)
        ).slot0();
        uint160 highPrice = TickMath.getSqrtRatioAtTick(tickUpper);
        uint256 intermediate = FullMath.mulDiv(currentPrice, highPrice, FixedPoint96.Q96);
        uint128 liquidity = toUint128(FullMath.mulDiv(1e18, intermediate, highPrice - currentPrice));
        amount0 = 1e18;
        amount1 = FullMath.mulDivRoundingUp(liquidity, currentPrice - lowPrice, FixedPoint96.Q96);
    }

    /// @notice Normalize token decimals to 18
    /// @param amount Amount of tokens
    /// @param decimals Decimals of given token amount to scale. MUST be <=18
    function _normalizeTokenDecimals(uint256 amount, uint256 decimals) internal pure returns (uint256) {
        return amount * 10 ** (18 - decimals);
    }

    /// @notice Returns value based on other token
    /// @param fullPath swap path
    /// @return weightedPrice value of last token of path based on first
    function getWeightedPrice(IZapAnalyzer.SwapPath[] memory fullPath) internal view returns (uint256 weightedPrice) {
        weightedPrice = 1e18;
        for (uint256 i = 0; i < fullPath.length; i++) {
            console.log("start", i);
            IZapAnalyzer.SwapPath memory path = fullPath[i];
            if (path.swapType == IZapAnalyzer.SwapType.V2) {
                uint256 tokenDecimals = getTokenDecimals(path.path[path.path.length - 1]);

                uint256[] memory amountsOut0 = IApeRouter02(path.swapRouter).getAmountsOut(1e18, path.path);
                weightedPrice =
                    (weightedPrice * _normalizeTokenDecimals(amountsOut0[amountsOut0.length - 1], tokenDecimals)) /
                    1e18;
            } else if (path.swapType == IZapAnalyzer.SwapType.V3) {
                for (uint256 index = 0; index < path.path.length - 1; index++) {
                    console.log(path.path[index], path.path[index + 1], path.uniV3PoolFees[index], path.swapRouter);
                    weightedPrice =
                        (weightedPrice *
                            pairTokensAndValue(
                                path.path[index],
                                path.path[index + 1],
                                path.uniV3PoolFees[index],
                                path.swapRouter
                            )) /
                        1e18;
                }
            }
            console.log("weightedPrice", i, fullPath.length, weightedPrice);
        }
    }

    /// @notice Returns value based on other token
    /// @param token0 initial token
    /// @param token1 end token that needs vaue based of token0
    /// @param fee uniV3 pool fee
    /// @param uniV3Factory uniV3 factory
    /// @return price value of token1 based of token0
    function pairTokensAndValue(
        address token0,
        address token1,
        uint24 fee,
        address uniV3Factory
    ) internal view returns (uint256 price) {
        address tokenPegPair = IUniswapV3Factory(uniV3Factory).getPool(token0, token1, fee);

        // if the address has no contract deployed, the pair doesn't exist
        uint256 size;
        assembly {
            size := extcodesize(tokenPegPair)
        }
        require(size != 0, "UniV3 pair not found");

        uint256 sqrtPriceX96;

        (sqrtPriceX96, , , , , , ) = IUniswapV3Pool(tokenPegPair).slot0();

        uint256 token0Decimals = getTokenDecimals(token0);
        uint256 token1Decimals = getTokenDecimals(token1);

        if (token1 < token0) {
            price = (2 ** 192) / ((sqrtPriceX96) ** 2 / uint256(10 ** (token0Decimals + 18 - token1Decimals)));
        } else {
            price = ((sqrtPriceX96) ** 2) / ((2 ** 192) / uint256(10 ** (token0Decimals + 18 - token1Decimals)));
        }
    }

    function getTokenDecimals(address token) private view returns (uint256 decimals) {
        try ERC20(token).decimals() returns (uint8 dec) {
            decimals = dec;
        } catch {
            decimals = 18;
        }
    }

    /// @notice get arrakis pool from uniV3 pool
    /// @param uniV3Pool uniV3 pool
    /// @param arrakisFactory arrakis factory
    /// @return pool Arrakis pool
    function getArrakisPool(address uniV3Pool, IArrakisFactoryV1 arrakisFactory) internal view returns (address) {
        address[] memory deployers = arrakisFactory.getDeployers();
        for (uint256 i = 0; i < deployers.length; i++) {
            address[] memory pools = arrakisFactory.getPools(deployers[i]);
            for (uint256 n = 0; n < pools.length; n++) {
                address pool = pools[n];
                if (address(IArrakisPool(pool).pool()) == uniV3Pool) {
                    return pool;
                }
            }
        }
        revert("ArrakisMath: Arrakis pool not found");
    }
}
