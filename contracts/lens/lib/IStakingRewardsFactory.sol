// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IStakingRewardsFactory {
    function stakingRewardsInfoByStakingToken(address)
        external
        view
        returns (
            address,
            uint256,
            uint256
        );

    function stakingTokens(uint256) external view returns (address);
}
