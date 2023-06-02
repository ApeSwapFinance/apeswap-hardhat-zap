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

import "../../../../utils/TokenHelper.sol";
import "./lib/IAlgebraFactory.sol";
import "./lib/IAlgebraPool.sol";

library AlgebraSwapHelper {
    /// @notice Returns value based on other token
    /// @param token0 initial token
    /// @param token1 end token that needs value based of token0
    /// @param uniV3Factory uniV3 factory
    /// @return price value of token1 based of token0
    function pairTokensAndValue(
        address token0,
        address token1,
        address uniV3Factory
    ) internal view returns (uint256 price) {
        address tokenPegPair = IAlgebraFactory(uniV3Factory).poolByPair(token0, token1);

        // if the address has no contract deployed, the pair doesn't exist
        uint256 size;
        assembly {
            size := extcodesize(tokenPegPair)
        }
        require(size != 0, "UniV3 pair not found");

        uint256 sqrtPriceX96;

        (sqrtPriceX96, , , , , , ) = IAlgebraPool(tokenPegPair).globalState();

        uint256 token0Decimals = TokenHelper.getTokenDecimals(token0);
        uint256 token1Decimals = TokenHelper.getTokenDecimals(token1);

        if (token1 < token0) {
            price = (2 ** 192) / ((sqrtPriceX96) ** 2 / uint256(10 ** (token0Decimals + 18 - token1Decimals)));
        } else {
            price = ((sqrtPriceX96) ** 2) / ((2 ** 192) / uint256(10 ** (token0Decimals + 18 - token1Decimals)));
        }
    }
}
