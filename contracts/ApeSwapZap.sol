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

import "./IApeSwapZap.sol";
import "./lib/IApeRouter02.sol";
import "./lib/IApeFactory.sol";
import "./lib/IApePair.sol";
import "./lib/IWETH.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract ApeSwapZap is IApeSwapZap, ReentrancyGuard {
    using SafeERC20 for IERC20;

    struct BalanceLocalVars {
        uint256 amount0;
        uint256 amount1;
    }

    IApeRouter02 public immutable router;
    IApeFactory public immutable factory;
    address public immutable WNATIVE;

    event Zap(address inputToken, uint256 inputAmount, address[] lpTokens);
    event ZapNative(uint256 inputAmount, address[] lpTokens);

    constructor(IApeRouter02 _router) {
        router = _router;
        factory = IApeFactory(router.factory());
        WNATIVE = router.WETH();
    }

    /// @dev The receive method is used as a fallback function in a contract
    /// and is called when ether is sent to a contract with no calldata.
    receive() external payable {
        require(msg.sender == WNATIVE, "ApeSwapZap: Only receive ether from wrapped");
    }

    /// @notice Zap single token to LP
    /// @param inputToken Input token
    /// @param inputAmount Input amount
    /// @param lpTokens Tokens of LP to zap to
    /// @param path0 Path from input token to LP token0
    /// @param path1 Path from input token to LP token1
    /// @param minAmountsSwap The minimum amount of output tokens that must be received for swap
    /// @param minAmountsLP AmountAMin and amountBMin for adding liquidity
    /// @param to address to receive LPs
    /// @param deadline Unix timestamp after which the transaction will revert
    function zap(
        IERC20 inputToken,
        uint256 inputAmount,
        address[] memory lpTokens, //[tokenA, tokenB]
        address[] calldata path0,
        address[] calldata path1,
        uint256[] memory minAmountsSwap, //[A, B]
        uint256[] memory minAmountsLP, //[amountAMin, amountBMin]
        address to,
        uint256 deadline
    ) external override nonReentrant {
        _zapInternal(inputToken, inputAmount, lpTokens, path0, path1, minAmountsSwap, minAmountsLP, to, deadline);
    }

    /// @notice Zap native token to LP
    /// @param lpTokens Tokens of LP to zap to
    /// @param path0 Path from input token to LP token0
    /// @param path1 Path from input token to LP token1
    /// @param minAmountsSwap The minimum amount of output tokens that must be received for swap
    /// @param minAmountsLP AmountAMin and amountBMin for adding liquidity
    /// @param to address to receive LPs
    /// @param deadline Unix timestamp after which the transaction will revert
    function zapNative(
        address[] memory lpTokens, //[tokenA, tokenB]
        address[] calldata path0,
        address[] calldata path1,
        uint256[] memory minAmountsSwap, //[A, B]
        uint256[] memory minAmountsLP, //[amountAMin, amountBMin]
        address to,
        uint256 deadline
    ) external payable override nonReentrant {
        _zapNativeInternal(lpTokens, path0, path1, minAmountsSwap, minAmountsLP, to, deadline);
    }

    /// @notice get min amounts for swaps
    /// @param inputAmount total input amount for swap
    /// @param path0 path from input token to LP token0
    /// @param path1 path from input token to LP token1
    function getMinAmounts(
        uint256 inputAmount,
        address[] calldata path0,
        address[] calldata path1
    ) external view override returns (uint256[2] memory minAmountsSwap, uint256[2] memory minAmountsLP) {
        require(path0.length >= 2 || path1.length >= 2, "ApeSwapZap: Needs at least one path");

        uint256 inputAmountHalf = inputAmount / 2;

        uint256 minAmountSwap0 = inputAmountHalf;
        if (path0.length != 0) {
            uint256[] memory amountsOut0 = router.getAmountsOut(inputAmountHalf, path0);
            minAmountSwap0 = amountsOut0[amountsOut0.length - 1];
        }

        uint256 minAmountSwap1 = inputAmountHalf;
        if (path1.length != 0) {
            uint256[] memory amountsOut1 = router.getAmountsOut(inputAmountHalf, path1);
            minAmountSwap1 = amountsOut1[amountsOut1.length - 1];
        }

        address token0 = path0.length == 0 ? path1[0] : path0[path0.length - 1];
        address token1 = path1.length == 0 ? path0[0] : path1[path1.length - 1];

        IApePair lp = IApePair(factory.getPair(token0, token1));
        (uint256 reserveA, uint256 reserveB, ) = lp.getReserves();
        if (token0 == lp.token1()) {
            (reserveA, reserveB) = (reserveB, reserveA);
        }
        uint256 amountB = router.quote(minAmountSwap0, reserveA, reserveB);

        minAmountsSwap = [minAmountSwap0, minAmountSwap1];
        minAmountsLP = [minAmountSwap0, amountB];
    }

    function _zapInternal(
        IERC20 inputToken,
        uint256 inputAmount,
        address[] memory lpTokens, //[tokenA, tokenB]
        address[] calldata path0,
        address[] calldata path1,
        uint256[] memory minAmountsSwap, //[A, B]
        uint256[] memory minAmountsLP, //[amountAMin, amountBMin]
        address to,
        uint256 deadline
    ) internal {
        uint256 balanceBefore = _getBalance(inputToken);
        inputToken.safeTransferFrom(msg.sender, address(this), inputAmount);
        inputAmount = _getBalance(inputToken) - balanceBefore;

        _zapPrivate(inputToken, inputAmount, lpTokens, path0, path1, minAmountsSwap, minAmountsLP, to, deadline, false);
        emit Zap(address(inputToken), inputAmount, lpTokens);
    }

    function _zapNativeInternal(
        address[] memory lpTokens, //[tokenA, tokenB]
        address[] calldata path0,
        address[] calldata path1,
        uint256[] memory minAmountsSwap, //[A, B]
        uint256[] memory minAmountsLP, //[amountAMin, amountBMin]
        address to,
        uint256 deadline
    ) internal {
        (uint256 inputAmount, IERC20 inputToken) = _wrapNative();

        _zapPrivate(inputToken, inputAmount, lpTokens, path0, path1, minAmountsSwap, minAmountsLP, to, deadline, true);
        emit ZapNative(inputAmount, lpTokens);
    }

    /// @notice Wrap the msg.value into the Wrapped Native token
    /// @return amount Amount of native tokens wrapped
    /// @return wNative The IERC20 representation of the wrapped asset
    function _wrapNative() internal returns (uint256 amount, IERC20 wNative) {
        wNative = IERC20(WNATIVE);
        amount = msg.value;
        IWETH(WNATIVE).deposit{value: amount}();
    }

    /// @notice Unwrap current balance of Wrapped Native tokens
    /// @return amount Amount of native tokens unwrapped
    function _unwrapNative() internal returns (uint256 amount) {
        amount = IERC20(WNATIVE).balanceOf(address(this));
        IWETH(WNATIVE).withdraw(amount);
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

    /// @notice Swap single token to single token
    /// @param amountIn Amount of input token to pass in
    /// @param amountOutMin Min amount of output token to accept
    /// @param path Path from input token to output token
    /// @param deadline Unix timestamp after which the transaction will revert
    /// @return amountOut The final amount of output tokens received
    function _routerSwap(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] memory path,
        uint256 deadline
    ) internal returns (uint256 amountOut) {
        address outputToken = path[path.length - 1];
        uint256 balanceBefore = _getBalance(IERC20(outputToken));
        router.swapExactTokensForTokens(amountIn, amountOutMin, path, address(this), deadline);
        amountOut = _getBalance(IERC20(outputToken)) - balanceBefore;
    }

    function _getBalance(IERC20 token) internal view returns (uint256 balance) {
        balance = token.balanceOf(address(this));
    }

    function _zapPrivate(
        IERC20 inputToken,
        uint256 inputAmount,
        address[] memory lpTokens, //[tokenA, tokenB]
        address[] calldata path0,
        address[] calldata path1,
        uint256[] memory minAmountsSwap, //[A, B]
        uint256[] memory minAmountsLP, //[amountAMin, amountBMin]
        address to,
        uint256 deadline,
        bool native
    ) private {
        require(to != address(0), "ApeSwapZap: Can't zap to null address");
        require(lpTokens.length == 2, "ApeSwapZap: need exactly 2 tokens to form a LP");
        require(factory.getPair(lpTokens[0], lpTokens[1]) != address(0), "ApeSwapZap: Pair doesn't exist");

        BalanceLocalVars memory vars;

        inputToken.approve(address(router), inputAmount);

        vars.amount0 = inputAmount / 2;
        if (lpTokens[0] != address(inputToken)) {
            uint256 path0Length = path0.length;
            require(path0Length > 0, "ApeSwapZap: path0 is required for this operation");
            require(path0[0] == address(inputToken), "ApeSwapZap: wrong path path0[0]");
            require(path0[path0Length - 1] == lpTokens[0], "ApeSwapZap: wrong path path0[-1]");
            vars.amount0 = _routerSwap(vars.amount0, minAmountsSwap[0], path0, deadline);
        }

        vars.amount1 = inputAmount / 2;
        if (lpTokens[1] != address(inputToken)) {
            uint256 path1Length = path1.length;
            require(path1Length > 0, "ApeSwapZap: path0 is required for this operation");
            require(path1[0] == address(inputToken), "ApeSwapZap: wrong path path1[0]");
            require(path1[path1Length - 1] == lpTokens[1], "ApeSwapZap: wrong path path1[-1]");
            vars.amount1 = _routerSwap(vars.amount1, minAmountsSwap[1], path1, deadline);
        }

        IERC20(lpTokens[0]).approve(address(router), vars.amount0);
        IERC20(lpTokens[1]).approve(address(router), vars.amount1);
        (uint256 amountA, uint256 amountB, ) = router.addLiquidity(
            lpTokens[0],
            lpTokens[1],
            vars.amount0,
            vars.amount1,
            minAmountsLP[0],
            minAmountsLP[1],
            to,
            deadline
        );

        if (lpTokens[0] == WNATIVE) {
            // Ensure WNATIVE is called last
            _transfer(lpTokens[1], vars.amount1 - amountB, native);
            _transfer(lpTokens[0], vars.amount0 - amountA, native);
        } else {
            _transfer(lpTokens[0], vars.amount0 - amountA, native);
            _transfer(lpTokens[1], vars.amount1 - amountB, native);
        }
    }
}
