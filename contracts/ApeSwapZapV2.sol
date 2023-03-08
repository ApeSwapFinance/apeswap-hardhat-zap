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

import "./lib/IApeSwapZapV2.sol";
import "./lib/IApeRouter02.sol";
import "./lib/IApeFactory.sol";
import "./lib/IApePair.sol";
import "./lib/IWETH.sol";
import "./lib/IArrakisRouter.sol";
import "./lib/IArrakisPool.sol";
import "./lib/IArrakisFactoryV1.sol";
import "./lib/ArrakisMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";

contract ApeSwapZapV2 is IApeSwapZapV2, ReentrancyGuard {
    using SafeERC20 for IERC20;

    struct LocalVars {
        uint256 amount0In;
        uint256 amount1In;
        uint256 amount0Out;
        uint256 amount1Out;
        uint256 amount0Lp;
        uint256 amount1Lp;
        address uniV3Pool;
        address arrakisPool;
        address tempToken0;
    }

    struct minAmountsLocalVars {
        uint256 inputAmountHalf;
        uint256 minAmountSwap0;
        uint256 minAmountSwap1;
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

    address public immutable WNATIVE;

    event Zap(ZapParams zapParams);
    event ZapNative(ZapParams zapParams);

    constructor(address _wnative) {
        WNATIVE = _wnative;
    }

    /// @dev The receive method is used as a fallback function in a contract
    /// and is called when ether is sent to a contract with no calldata.
    receive() external payable {
        require(msg.sender == WNATIVE, "ApeSwapZap: Only receive ether from wrapped");
    }

    /// @notice Zap single token to LP
    /// @param zapParams all parameters for zap
    function zap(ZapParams memory zapParams) external override nonReentrant {
        _zapInternal(zapParams);
    }

    /// @notice Zap native token to LP
    /// @param zapParams all parameters for native zap
    function zapNative(ZapParamsNative memory zapParams) external payable override nonReentrant {
        _zapNativeInternal(zapParams);
    }

    /// @notice get min amounts for swaps
    /// @param params all params
    function getMinAmounts(
        MinAmountsParams memory params
    ) external view override returns (uint256[2] memory minAmountsSwap, uint256[2] memory minAmountsLP) {
        require(params.path0.path.length >= 2 || params.path1.path.length >= 2, "ApeSwapZap: Needs at least one path");

        minAmountsLocalVars memory vars;

        IApeFactory factory;
        vars.token0 = params.path0.path.length == 0
            ? params.path1.path[0]
            : params.path0.path[params.path0.path.length - 1];
        vars.token1 = params.path1.path.length == 0
            ? params.path0.path[0]
            : params.path1.path[params.path1.path.length - 1];
        vars.inputToken = params.path0.path.length > 0 ? params.path0.path[0] : params.path1.path[0];

        //get min amounts for swap
        // V2 swap and based on V2 also V3 estimate assuming no arbitrage exists
        IApeRouter02 router = IApeRouter02(params.path0.swapRouter);
        factory = IApeFactory(router.factory());
        vars.inputAmountHalf = params.inputAmount / 2;
        vars.minAmountSwap0 = vars.inputAmountHalf;
        if (params.path0.path.length != 0) {
            uint256[] memory amountsOut0 = router.getAmountsOut(vars.inputAmountHalf, params.path0.path);
            vars.minAmountSwap0 = amountsOut0[amountsOut0.length - 1];
        }
        vars.minAmountSwap1 = vars.inputAmountHalf;
        if (params.path1.path.length != 0) {
            uint256[] memory amountsOut1 = router.getAmountsOut(vars.inputAmountHalf, params.path1.path);
            vars.minAmountSwap1 = amountsOut1[amountsOut1.length - 1];
        }
        minAmountsSwap = [vars.minAmountSwap0, vars.minAmountSwap1];

        // get min amounts for adding liquidity
        if (params.liquidityPath.lpType == LPType.V2) {
            //V2 LP
            IApePair lp = IApePair(factory.getPair(vars.token0, vars.token1));
            (vars.reserveA, vars.reserveB, ) = lp.getReserves();
            if (vars.token0 == lp.token1()) {
                (vars.reserveA, vars.reserveB) = (vars.reserveB, vars.reserveA);
            }
            uint256 amountB = IApeRouter02(params.path0.swapRouter).quote(
                vars.minAmountSwap0,
                vars.reserveA,
                vars.reserveB
            );
            minAmountsLP = [vars.minAmountSwap0, amountB];
        } else if (params.liquidityPath.lpType == LPType.V3) {
            // V3 lp
            revert("UniswapV3 LP is not yet supported");
        } else if (params.liquidityPath.lpType == LPType.Arrakis) {
            // arrakis lp
            vars.uniV3Pool = IUniswapV3Factory(IArrakisRouter(params.liquidityPath.lpRouter).factory()).getPool(
                vars.token0,
                vars.token1,
                params.liquidityPath.uniV3PoolLPFee
            );
            vars.arrakisPool = ArrakisMath.getArrakisPool(
                vars.uniV3Pool,
                IArrakisFactoryV1(params.liquidityPath.arrakisFactory)
            );
            ArrakisMath.SwapRatioParams memory swapRatioParams = ArrakisMath.SwapRatioParams({
                inputToken: vars.inputToken,
                inputAmount: params.inputAmount,
                token0: vars.token0,
                token1: vars.token1,
                path0: params.path0.path,
                path1: params.path1.path,
                uniV3PoolFees0: params.path0.uniV3PoolFees,
                uniV3PoolFees1: params.path1.uniV3PoolFees,
                arrakisPool: vars.arrakisPool,
                uniV2Router0: params.path0.swapRouter,
                uniV2Router1: params.path1.swapRouter,
                uniV3Factory: IArrakisRouter(params.liquidityPath.lpRouter).factory()
            });
            (vars.amount0, vars.amount1) = ArrakisMath.getSwapRatio(swapRatioParams);
            vars.weightedPrice0 = vars.inputToken == vars.token0
                ? 1e18
                : ArrakisMath.getWeightedPrice(
                    params.path0.path,
                    params.path0.uniV3PoolFees,
                    params.path0.swapRouter,
                    IArrakisRouter(params.liquidityPath.lpRouter).factory()
                );
            vars.weightedPrice1 = vars.inputToken == vars.token1
                ? 1e18
                : ArrakisMath.getWeightedPrice(
                    params.path1.path,
                    params.path1.uniV3PoolFees,
                    params.path1.swapRouter,
                    IArrakisRouter(params.liquidityPath.lpRouter).factory()
                );
            minAmountsLP = [(vars.amount0 * vars.weightedPrice0) / 1e18, (vars.amount1 * vars.weightedPrice1) / 1e18];
        }
    }

    function _zapInternal(ZapParams memory zapParams) internal {
        uint256 balanceBefore = _getBalance(zapParams.inputToken);
        zapParams.inputToken.safeTransferFrom(msg.sender, address(this), zapParams.inputAmount);
        zapParams.inputAmount = _getBalance(zapParams.inputToken) - balanceBefore;

        _zapPrivate(zapParams, false);
        emit Zap(zapParams);
    }

    function _zapNativeInternal(ZapParamsNative memory zapParamsNative) internal {
        uint256 inputAmount = msg.value;
        IERC20 inputToken = IERC20(WNATIVE);
        IWETH(WNATIVE).deposit{value: inputAmount}();

        ZapParams memory zapParams = ZapParams({
            inputToken: inputToken,
            inputAmount: inputAmount,
            token0: zapParamsNative.token0,
            token1: zapParamsNative.token1,
            path0: zapParamsNative.path0,
            path1: zapParamsNative.path1,
            liquidityPath: zapParamsNative.liquidityPath,
            to: zapParamsNative.to,
            deadline: zapParamsNative.deadline
        });

        _zapPrivate(zapParams, true);
        emit ZapNative(zapParams);
    }

    function _transfer(address token, uint256 amount, bool native) internal {
        if (amount == 0) return;
        if (token == WNATIVE && native) {
            IWETH(WNATIVE).withdraw(amount);
            // 2600 COLD_ACCOUNT_ACCESS_COST plus 2300 transfer gas - 1
            // Intended to support transfers to contracts, but not allow for further code execution
            (bool success, ) = msg.sender.call{value: amount, gas: 4899}("");
            require(success, "native transfer error");
        } else {
            IERC20(token).safeTransfer(msg.sender, amount);
        }
    }

    function _getBalance(IERC20 token) internal view returns (uint256 balance) {
        balance = token.balanceOf(address(this));
    }

    /// @notice Ultimate ZAP function
    /// @param zapParams all parameters for zap
    /// swapRouter swap router
    /// swapType type of swap zap
    /// lpRouter lp router
    /// lpType type of lp zap
    /// arrakisFactory Arrakis factory
    /// inputToken Address of token to turn into an LP Token
    /// inputAmount Amount of inputToken to deposit into LP
    /// token0 first underlying token of LP
    /// token1 second underlying token of LP
    /// path0 path from input token to first underlying token of LP
    /// minAmountSwap0 min amount of token0 to receive after swap
    /// uniV3PoolFees0 pool fees for path0 for when type of swap is V3
    /// path1 path from input token to second underlying token of LP
    /// minAmountSwap1 min amount of token1 to receive after swap
    /// uniV3PoolFees1 pool fees for path1 for when type of swap is V3
    /// minAmountLP0 min amount of token0 to use when adding liquidity
    /// minAmountLP1 min amount of token1 to use when adding liquidity
    /// uniV3PoolLPFee pool fee of LP for when lp type is Arrakis or V3
    /// to Address which receives the LP Tokens
    /// deadline Latest timestamp this call is valid
    /// @param native Unwrap Wrapped Native tokens before transferring
    function _zapPrivate(ZapParams memory zapParams, bool native) private {
        // Verify inputs
        require(zapParams.to != address(0), "ApeSwapZap: Can't zap to null address");
        require(
            zapParams.path0.swapRouter != address(0) &&
                zapParams.path1.swapRouter != address(0) &&
                zapParams.liquidityPath.lpRouter != address(0),
            "ApeSwapZap: swap and lp routers can not be address(0)"
        );
        require(zapParams.token0 != address(0), "ApeSwapZap: token0 can not be address(0)");
        require(zapParams.token1 != address(0), "ApeSwapZap: token1 can not be address(0)");
        // Setup struct to prevent stack overflow
        LocalVars memory vars;
        // Ensure token addresses and paths are in ascending numerical order
        if (zapParams.token1 < zapParams.token0) {
            (zapParams.token0, zapParams.token1) = (zapParams.token1, zapParams.token0);
            (zapParams.path0, zapParams.path1) = (zapParams.path1, zapParams.path0);
        }

        /**
         * Setup swap amount0 and amount1
         */
        if (zapParams.liquidityPath.lpType == LPType.V2) {
            // Handle UniswapV2 Liquidity
            require(
                IApeFactory(IApeRouter02(zapParams.liquidityPath.lpRouter).factory()).getPair(
                    zapParams.token0,
                    zapParams.token1
                ) != address(0),
                "ApeSwapZap: Pair doesn't exist"
            );
            vars.amount0In = zapParams.inputAmount / 2;
            vars.amount1In = zapParams.inputAmount / 2;
        } else if (zapParams.liquidityPath.lpType == LPType.V3) {
            // Handle UniswapV3 Liquidity
            revert("UniswapV3 LP is not yet supported");
        } else if (zapParams.liquidityPath.lpType == LPType.Arrakis) {
            // Handle Arrakis Liquidity
            require(zapParams.liquidityPath.arrakisFactory != address(0), "ApeSwapZap: Arrakis factory missing");
            vars.uniV3Pool = IUniswapV3Factory(IArrakisRouter(zapParams.liquidityPath.lpRouter).factory()).getPool(
                zapParams.token0,
                zapParams.token1,
                zapParams.liquidityPath.uniV3PoolLPFee
            );
            vars.arrakisPool = ArrakisMath.getArrakisPool(
                vars.uniV3Pool,
                IArrakisFactoryV1(zapParams.liquidityPath.arrakisFactory)
            );

            ArrakisMath.SwapRatioParams memory swapRatioParams = ArrakisMath.SwapRatioParams({
                inputToken: address(zapParams.inputToken),
                inputAmount: zapParams.inputAmount,
                token0: zapParams.token0,
                token1: zapParams.token1,
                path0: zapParams.path0.path,
                path1: zapParams.path1.path,
                uniV3PoolFees0: zapParams.path0.uniV3PoolFees,
                uniV3PoolFees1: zapParams.path1.uniV3PoolFees,
                arrakisPool: vars.arrakisPool,
                uniV2Router0: zapParams.path0.swapRouter,
                uniV2Router1: zapParams.path1.swapRouter,
                uniV3Factory: IArrakisRouter(zapParams.liquidityPath.lpRouter).factory()
            });
            (vars.amount0In, vars.amount1In) = ArrakisMath.getSwapRatio(swapRatioParams);
        } else {
            revert("ApeSwapZap: LPType not supported");
        }

        /**
         * Handle token0 Swap
         */
        if (zapParams.token0 != address(zapParams.inputToken)) {
            require(zapParams.path0.path[0] == address(zapParams.inputToken), "ApeSwapZap: wrong path path0[0]");
            require(
                zapParams.path0.path[zapParams.path0.path.length - 1] == zapParams.token0,
                "ApeSwapZap: wrong path path0[-1]"
            );
            zapParams.inputToken.approve(zapParams.path0.swapRouter, vars.amount0In);
            vars.amount0Out = _routerSwapFromPath(zapParams.path0, vars.amount0In, zapParams.deadline);
        } else {
            vars.amount0Out = zapParams.inputAmount - vars.amount1In;
        }
        /**
         * Handle token1 Swap
         */
        if (zapParams.token1 != address(zapParams.inputToken)) {
            require(zapParams.path1.path[0] == address(zapParams.inputToken), "ApeSwapZap: wrong path path1[0]");
            require(
                zapParams.path1.path[zapParams.path1.path.length - 1] == zapParams.token1,
                "ApeSwapZap: wrong path path1[-1]"
            );
            zapParams.inputToken.approve(zapParams.path1.swapRouter, vars.amount1In);
            vars.amount1Out = _routerSwapFromPath(zapParams.path1, vars.amount1In, zapParams.deadline);
        } else {
            vars.amount1Out = zapParams.inputAmount - vars.amount0In;
        }

        /**
         * Handle Liquidity Add
         */
        IERC20(zapParams.token0).approve(address(zapParams.liquidityPath.lpRouter), vars.amount0Out);
        IERC20(zapParams.token1).approve(address(zapParams.liquidityPath.lpRouter), vars.amount1Out);

        if (zapParams.liquidityPath.lpType == LPType.V2) {
            // Add liquidity to UniswapV2 Pool
            (vars.amount0Lp, vars.amount1Lp, ) = IApeRouter02(zapParams.liquidityPath.lpRouter).addLiquidity(
                zapParams.token0,
                zapParams.token1,
                vars.amount0Out,
                vars.amount1Out,
                zapParams.liquidityPath.minAmountLP0,
                zapParams.liquidityPath.minAmountLP1,
                zapParams.to,
                zapParams.deadline
            );
        } else if (zapParams.liquidityPath.lpType == LPType.Arrakis) {
            // Add liquidity to Arrakis Pool
            (vars.amount0Lp, vars.amount1Lp, ) = IArrakisRouter(zapParams.liquidityPath.lpRouter).addLiquidity(
                IArrakisPool(vars.arrakisPool),
                vars.amount0Out,
                vars.amount1Out,
                zapParams.liquidityPath.minAmountLP0,
                zapParams.liquidityPath.minAmountLP1,
                zapParams.to
            );
        } else {
            revert("ApeSwapZap: lpType not supported");
        }

        if (zapParams.token0 == WNATIVE) {
            // Ensure WNATIVE is called last
            _transfer(zapParams.token1, vars.amount1Out - vars.amount1Lp, native);
            _transfer(zapParams.token0, vars.amount0Out - vars.amount0Lp, native);
        } else {
            _transfer(zapParams.token0, vars.amount0Out - vars.amount0Lp, native);
            _transfer(zapParams.token1, vars.amount1Out - vars.amount1Lp, native);
        }
    }

    function _routerSwapFromPath(
        SwapPath memory _uniSwapPath,
        uint256 _amountIn,
        uint256 _deadline
    ) private returns (uint256 amountOut) {
        require(_uniSwapPath.path.length >= 2, "ApeSwapZap: need path0 of >=2");
        address outputToken = _uniSwapPath.path[_uniSwapPath.path.length - 1];
        uint256 balanceBefore = _getBalance(IERC20(outputToken));
        _routerSwap(
            _uniSwapPath.swapRouter,
            _uniSwapPath.swapType,
            _amountIn,
            _uniSwapPath.minAmountSwap,
            _uniSwapPath.path,
            _uniSwapPath.uniV3PoolFees,
            _deadline
        );
        amountOut = _getBalance(IERC20(outputToken)) - balanceBefore;
    }

    function _routerSwap(
        address router,
        SwapType swapType,
        uint256 amountIn,
        uint256 amountOutMin,
        address[] memory path,
        uint24[] memory uniV3PoolFees,
        uint256 deadline
    ) private {
        if (swapType == SwapType.V2) {
            // Perform UniV2 swap
            require(uniV3PoolFees.length == 0, "ApeSwapZap: uniV3PoolFees should be empty on V2 swap");
            IApeRouter02(router).swapExactTokensForTokens(amountIn, amountOutMin, path, address(this), deadline);
        } else if (swapType == SwapType.V3) {
            // Handle swapping with UNIV3_ROUTER
            require(path.length - 1 == uniV3PoolFees.length, "ApeSwapZap: pool fees don't match path");
            bytes memory encodedPacked;
            for (uint256 index = 0; index < path.length - 1; index++) {
                encodedPacked = abi.encodePacked(encodedPacked, path[index], uniV3PoolFees[index]);
            }
            ISwapRouter.ExactInputParams memory params = ISwapRouter.ExactInputParams({
                path: abi.encodePacked(encodedPacked, path[path.length - 1]),
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: amountIn,
                amountOutMinimum: amountOutMin
            });
            // Perform UniV3 swap
            ISwapRouter(router).exactInput(params);
        } else {
            revert("ApeSwapZap: SwapType not supported");
        }
    }
}
