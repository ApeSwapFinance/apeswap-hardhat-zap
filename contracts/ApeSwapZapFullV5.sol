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

import "./WrapNative.sol";
import "./extensions/swap/ZapSwap.sol";
import "./extensions/liquidity/ZapLiquidity.sol";
import "./extensions/bills/ApeSwapZapTBills.sol";
import "./extensions/farms/ApeSwapZapMiniApeV2.sol";
import "./extensions/pools/ApeSwapZapPools.sol";
import "./extensions/pools/libraries/ITreasury.sol";
import "./extensions/vaults/ApeSwapZapVaults.sol";
import "./extensions/lending/ApeSwapZapLending.sol";
import "./lens/IZapAnalyzer.sol";
import "./utils/Multicall.sol";
import "./interfaces/IWETH.sol";

contract ApeSwapZapFullV5 is
    WrapNative,
    ZapSwap,
    ZapLiquidity,
    ApeSwapZapTBills,
    ApeSwapZapMiniApeV2,
    ApeSwapZapPools,
    ApeSwapZapVaults,
    ApeSwapZapLending,
    Multicall,
    IZapAnalyzer
{
    IZapAnalyzer public zapAnalyzer;

    constructor(
        IWETH wNative,
        ITreasury goldenBananaTreasury,
        IZapAnalyzer _zapAnalyzer
    ) WrapNative(wNative) ApeSwapZapPools(goldenBananaTreasury) {
        zapAnalyzer = _zapAnalyzer;
    }

    function estimateSwapReturns(IZapAnalyzer.SwapReturnsParams memory params)
        external
        view
        returns (IZapAnalyzer.SwapReturns memory returnValues)
    {
        return zapAnalyzer.estimateSwapReturns(params);
    }
}