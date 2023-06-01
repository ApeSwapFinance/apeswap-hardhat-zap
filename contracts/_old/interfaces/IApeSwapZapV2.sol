// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

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

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../../extensions/swap/features/univ2/lib/IV2SwapRouter02.sol";
import "../extensions/bills/libraries/ICustomBill.sol";

interface IApeSwapZapV2 {
    enum SwapType {
        V2,
        V3
    }

    struct SwapPath {
        address swapRouter;
        SwapType swapType;
        address[] path;
        uint256 minAmountSwap;
        uint24[] uniV3PoolFees; // Required if dexType == V3
    }

    enum LPType {
        V2,
        V3,
        Arrakis
    }

    struct LiquidityPath {
        address lpRouter;
        LPType lpType;
        uint256 minAmountLP0;
        uint256 minAmountLP1;
        uint24 uniV3PoolLPFee;
        address arrakisFactory; // Required if lpType == Arrakis
    }

    struct ZapParams {
        IERC20 inputToken;
        uint256 inputAmount;
        address token0;
        address token1;
        SwapPath path0;
        SwapPath path1;
        LiquidityPath liquidityPath;
        address to;
        uint256 deadline;
    }

    struct ZapParamsNative {
        address token0;
        address token1;
        SwapPath path0;
        SwapPath path1;
        LiquidityPath liquidityPath;
        address to;
        uint256 deadline;
    }

    struct ZapParamsTBill {
        ZapParams zapParams;
        ICustomBill bill;
        uint256 maxPrice;
    }

    struct ZapParamsTBillNative {
        ZapParamsNative zapParamsNative;
        ICustomBill bill;
        uint256 maxPrice;
    }

    struct MinAmountsParams {
        IERC20 inputToken;
        uint256 inputAmount;
        address token0;
        address token1;
        SwapPath path0;
        SwapPath path1;
        LiquidityPath liquidityPath;
    }

    function zap(ZapParams memory zapParams) external;

    function zapNative(ZapParamsNative memory zapParamsNative) external payable;

    function getMinAmounts(
        MinAmountsParams memory params
    ) external view returns (uint256[2] memory minAmountsSwap, uint256[2] memory minAmountsLP);
}
