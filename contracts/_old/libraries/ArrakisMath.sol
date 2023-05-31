// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.15;

import "../../extensions/liquidity/features/arrakis/lib/IArrakisPool.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "../../extensions/swap/features/univ2/lib/IV2SwapRouter02.sol";
import "../../extensions/liquidity/features/arrakis/lib/IArrakisFactoryV1.sol";

library ArrakisMath {
    struct SwapRatioParams {
        address inputToken;
        uint256 inputAmount;
        address token0;
        address token1;
        address[] path0;
        address[] path1;
        uint24[] uniV3PoolFees0;
        uint24[] uniV3PoolFees1;
        address arrakisPool;
        address uniV2Router0;
        address uniV2Router1;
        address uniV3Factory;
    }

    struct SwapRatioLocalVars {
        address arrakisPool;
        uint256 underlying0;
        uint256 underlying1;
        uint256 token0decimals;
        uint256 token1decimals;
        uint256 weightedPrice0;
        uint256 weightedPrice1;
        uint256 percentage0;
        uint256 percentage1;
    }

    /// @notice Get ratio of how much of input token to swap to underlying tokens for lp to match ratio in pool
    /// @param swapRatioParams swap ratio params
    /// inputToken Input token
    /// inputAmount Input amount
    /// token0 token0 from LP
    /// token1 token1 from LP
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

        (vars.underlying0, vars.underlying1) = IArrakisPool(swapRatioParams.arrakisPool).getUnderlyingBalances();

        vars.token0decimals = ERC20(address(swapRatioParams.token0)).decimals();
        vars.token1decimals = ERC20(address(swapRatioParams.token1)).decimals();
        vars.underlying0 = _normalizeTokenDecimals(vars.underlying0, vars.token0decimals);
        vars.underlying1 = _normalizeTokenDecimals(vars.underlying1, vars.token1decimals);

        vars.weightedPrice0 = swapRatioParams.inputToken == swapRatioParams.token0
            ? 1e18
            : getWeightedPrice(
                swapRatioParams.path0,
                swapRatioParams.uniV3PoolFees0,
                swapRatioParams.uniV2Router0,
                swapRatioParams.uniV3Factory
            );
        vars.weightedPrice1 = swapRatioParams.inputToken == swapRatioParams.token1
            ? 1e18
            : getWeightedPrice(
                swapRatioParams.path1,
                swapRatioParams.uniV3PoolFees1,
                swapRatioParams.uniV2Router1,
                swapRatioParams.uniV3Factory
            );

        vars.percentage0 =
            (((vars.underlying0 * 1e18) / (vars.underlying0 + vars.underlying1)) * vars.weightedPrice0) /
            (vars.weightedPrice0 + vars.weightedPrice1);

        vars.percentage1 =
            (((vars.underlying1 * 1e18) / (vars.underlying0 + vars.underlying1)) * vars.weightedPrice1) /
            (vars.weightedPrice0 + vars.weightedPrice1);

        amount0 =
            (((vars.percentage0 * 1e18) / (vars.percentage0 + vars.percentage1)) * swapRatioParams.inputAmount) /
            1e18;

        amount1 = swapRatioParams.inputAmount - amount0;
    }

    /// @notice Normalize token decimals to 18
    /// @param amount Amount of tokens
    /// @param decimals Decimals of given token amount to scale. MUST be <=18
    function _normalizeTokenDecimals(uint256 amount, uint256 decimals) internal pure returns (uint256) {
        return amount * 10 ** (18 - decimals);
    }

    /// @notice Returns value based on other token
    /// @param path swap path
    /// @param uniV3PoolFees uniV3 pool fees from path Lps
    /// @param uniV3Factory uniV3 factory
    /// @return weightedPrice value of last token of path based on first
    function getWeightedPrice(
        address[] memory path,
        uint24[] memory uniV3PoolFees,
        address uniV2Router,
        address uniV3Factory
    ) internal view returns (uint256 weightedPrice) {
        weightedPrice = 1e18;
        if (uniV3PoolFees.length == 0) {
            uint256 tokenDecimals = getTokenDecimals(path[path.length - 1]);

            uint256[] memory amountsOut0 = IV2SwapRouter02(uniV2Router).getAmountsOut(1e18, path);
            weightedPrice = _normalizeTokenDecimals(amountsOut0[amountsOut0.length - 1], tokenDecimals);
        } else {
            for (uint256 index = 0; index < path.length - 1; index++) {
                weightedPrice =
                    (weightedPrice *
                        pairTokensAndValue(path[index], path[index + 1], uniV3PoolFees[index], uniV3Factory)) /
                    1e18;
            }
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
        require(size != 0, "ArrakisMath: UniV3 pair not found");

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
