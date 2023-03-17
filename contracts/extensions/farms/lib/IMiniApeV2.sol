// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IMiniApeV2 {
    function lpToken(uint256 pid) external view returns (address);

    function deposit(uint256 pid, uint256 amount, address to) external;
}
