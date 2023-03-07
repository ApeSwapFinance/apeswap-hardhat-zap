// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IDualStakingRewardsFactory {
    function stakingRewardsInfoByStakingToken(address)
        external
        view
        returns (
            address,
            address,
            address,
            uint256,
            uint256,
            uint256
        );

    function stakingTokens(uint256) external view returns (address);
}
