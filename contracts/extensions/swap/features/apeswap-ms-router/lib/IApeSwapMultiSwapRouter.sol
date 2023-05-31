// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;
pragma abicoder v2;

import "../../univ2/lib/IV2SwapRouter.sol";
import "../../univ3/lib/IV3SwapRouter.sol";

/// @title Uniswap V2 and V3 Swap Router
interface IApeSwapMultiSwapRouter is IV2SwapRouter, IV3SwapRouter {
    function multicall(bytes[] calldata data) external payable returns (bytes[] memory results);

    function wrapETH(uint256 value) external payable;
}
