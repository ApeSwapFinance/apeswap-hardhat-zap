// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IStakingDualRewards {
    function balanceOf(address) external view returns (uint256);

    function stakingToken() external view returns (address);
}
