// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.15;

import "../lib/IApePair.sol";
import "../lib/IMasterApe.sol";
import "../lib/IApeFactory.sol";
import "./lib/IStakingRewardsFactory.sol";
import "./lib/IDualStakingRewardsFactory.sol";
import "./lib/IStakingDualRewards.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract LPBalanceCheckerPolygon is Ownable {
    address[] public stakingContracts;
    IStakingRewardsFactory quickswapStakingRewardsFactory =
        IStakingRewardsFactory(0x8aAA5e259F74c8114e0a471d9f2ADFc66Bfe09ed);
    IDualStakingRewardsFactory quickswapDualStakingRewardsFactory =
        IDualStakingRewardsFactory(0x9Dd12421C637689c3Fc6e661C9e2f02C2F61b3Eb);

    struct Balances {
        address stakingAddress;
        Balance[] balances;
    }

    struct Balance {
        uint256 pid;
        address lp;
        address token0;
        address token1;
        uint256 total;
        uint256 wallet;
        uint256 staked;
    }

    constructor(address[] memory _stakingContracts) Ownable() {
        for (uint256 i = 0; i < _stakingContracts.length; i++) {
            addStakingContract(_stakingContracts[i]);
        }
    }

    function getBalance(address user, uint256 customArraySize) external view returns (Balances[] memory pBalances) {
        pBalances = new Balances[](stakingContracts.length);
        for (uint256 i = 0; i < stakingContracts.length; i++) {
            if (stakingContracts[i] == address(quickswapStakingRewardsFactory)) {
                pBalances[i] = getBalanceQuickswap(user, customArraySize, false);
                continue;
            }

            if (stakingContracts[i] == address(quickswapDualStakingRewardsFactory)) {
                pBalances[i] = getBalanceQuickswap(user, customArraySize, true);
                continue;
            }

            IMasterApe stakingContract = IMasterApe(stakingContracts[i]);
            pBalances[i].stakingAddress = address(stakingContract);

            Balance[] memory tempBalances = new Balance[](stakingContract.poolLength());
            uint256 balanceCount;

            for (uint256 poolId = 0; poolId < stakingContract.poolLength(); poolId++) {
                (address lpTokenAddress, , , ) = stakingContract.poolInfo(poolId);
                (uint256 amount, ) = stakingContract.userInfo(poolId, user);

                IApePair lpToken = IApePair(lpTokenAddress);

                Balance memory balance;
                balance.lp = lpTokenAddress;
                balance.pid = poolId;
                balance.wallet = lpToken.balanceOf(user);
                balance.staked = amount;
                balance.total = balance.wallet + balance.staked;
                try lpToken.token0() returns (address _token0) {
                    balance.token0 = _token0;
                } catch (bytes memory) {}
                try lpToken.token1() returns (address _token1) {
                    balance.token1 = _token1;
                } catch (bytes memory) {}

                tempBalances[poolId] = balance;
            }

            for (uint256 balanceIndex = 0; balanceIndex < tempBalances.length; balanceIndex++) {
                if (tempBalances[balanceIndex].total > 0 && tempBalances[balanceIndex].token0 != address(0)) {
                    balanceCount++;
                }
            }

            Balance[] memory balances = new Balance[](balanceCount);
            uint256 newIndex = 0;

            for (uint256 balanceIndex = 0; balanceIndex < tempBalances.length; balanceIndex++) {
                if (tempBalances[balanceIndex].total > 0 && tempBalances[balanceIndex].token0 != address(0)) {
                    balances[newIndex] = tempBalances[balanceIndex];
                    newIndex++;
                }
            }

            pBalances[i].balances = balances;
        }
    }

    function getBalanceQuickswap(
        address user,
        uint256 customArraySize,
        bool dual
    ) public view returns (Balances memory pBalance) {
        if (dual) {
            pBalance.stakingAddress = address(quickswapDualStakingRewardsFactory);
        } else {
            pBalance.stakingAddress = address(quickswapStakingRewardsFactory);
        }

        Balance[] memory tempBalances = new Balance[](customArraySize);
        uint256 balanceCount;

        for (uint256 pairIndex = 0; pairIndex < type(uint256).max; pairIndex++) {
            address lpTokenAddress;
            address stakingRewards;

            if (dual) {
                try quickswapDualStakingRewardsFactory.stakingTokens(pairIndex) returns (address _lpAddress) {
                    lpTokenAddress = _lpAddress;
                    (stakingRewards, , , , , ) = quickswapDualStakingRewardsFactory.stakingRewardsInfoByStakingToken(
                        lpTokenAddress
                    );
                } catch (bytes memory) {
                    break;
                } catch Error(string memory) {
                    break;
                }
            } else {
                try quickswapStakingRewardsFactory.stakingTokens(pairIndex) returns (address _lpAddress) {
                    lpTokenAddress = _lpAddress;
                    (stakingRewards, , ) = quickswapStakingRewardsFactory.stakingRewardsInfoByStakingToken(
                        lpTokenAddress
                    );
                } catch (bytes memory) {
                    break;
                } catch Error(string memory) {
                    break;
                }
            }
            if (lpTokenAddress == address(0)) {
                continue;
            }

            uint256 amount = IStakingDualRewards(stakingRewards).balanceOf(user);

            IApePair lpToken = IApePair(lpTokenAddress);

            Balance memory balance;
            balance.lp = lpTokenAddress;
            balance.pid = 0;
            try lpToken.balanceOf(user) returns (uint256 _balance) {
                balance.wallet = _balance;
            } catch (bytes memory) {
                continue;
            }
            balance.staked = amount;
            balance.total = balance.wallet + balance.staked;
            try lpToken.token0() returns (address _token0) {
                balance.token0 = _token0;
            } catch (bytes memory) {}
            try lpToken.token1() returns (address _token1) {
                balance.token1 = _token1;
            } catch (bytes memory) {}

            tempBalances[pairIndex] = balance;
        }

        for (uint256 balanceIndex = 0; balanceIndex < tempBalances.length; balanceIndex++) {
            if (tempBalances[balanceIndex].total > 0 && tempBalances[balanceIndex].token0 != address(0)) {
                balanceCount++;
            }
        }

        Balance[] memory balances = new Balance[](balanceCount);
        uint256 newIndex = 0;

        for (uint256 balanceIndex = 0; balanceIndex < tempBalances.length; balanceIndex++) {
            if (tempBalances[balanceIndex].total > 0 && tempBalances[balanceIndex].token0 != address(0)) {
                balances[newIndex] = tempBalances[balanceIndex];
                newIndex++;
            }
        }

        pBalance.balances = balances;
    }

    function removeStakingContract(uint256 index) external onlyOwner {
        require(index < stakingContracts.length);
        stakingContracts[index] = stakingContracts[stakingContracts.length - 1];
        stakingContracts.pop();
    }

    function addStakingContract(address stakingContract) public onlyOwner {
        stakingContracts.push(stakingContract);
    }
}
