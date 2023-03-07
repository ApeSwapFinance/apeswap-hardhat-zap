// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IUniV3PriceGetter {
    function getPrice(
        address token,
        uint32 _secondsAgo
    ) external view returns (uint256);
}
