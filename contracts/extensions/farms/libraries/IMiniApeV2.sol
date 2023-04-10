// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IMiniApeV2 {
    function lpToken(uint256 pid) external returns (address);

    function deposit(uint256 pid, uint256 amount, address to) external;
}
