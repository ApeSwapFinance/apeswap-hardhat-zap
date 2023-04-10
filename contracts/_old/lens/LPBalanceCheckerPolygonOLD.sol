// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.15;

import "../../interfaces/IApePair.sol";
import "../../interfaces/IMasterApe.sol";
import "../../interfaces/IApeFactory.sol";
import "./libraries/IDualStakingRewardsFactory.sol";
import "./libraries/IStakingDualRewards.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract LPBalanceCheckerPolygonOLD is Ownable {
    address[] public stakingContracts;
    IDualStakingRewardsFactory quickswapStakingRewardsFactory =
        IDualStakingRewardsFactory(0x9Dd12421C637689c3Fc6e661C9e2f02C2F61b3Eb);
    IApeFactory quickswapFactory = IApeFactory(0x5757371414417b8C6CAad45bAeF941aBc7d3Ab32);

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

    function getBalance(address user) external view returns (Balances[] memory pBalances) {
        pBalances = new Balances[](stakingContracts.length);
        for (uint256 i = 0; i < stakingContracts.length; i++) {
            if (stakingContracts[i] == address(quickswapStakingRewardsFactory)) {
                pBalances[i] = getBalanceQuickswap(user);
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

    function getBalanceQuickswap(address user) public view returns (Balances memory pBalance) {
        pBalance.stakingAddress = address(quickswapStakingRewardsFactory);

        uint256 allPairsLength = quickswapFactory.allPairsLength();
        Balance[] memory tempBalances = new Balance[](allPairsLength);
        uint256 balanceCount;

        for (uint256 pairIndex = 0; pairIndex < allPairsLength; pairIndex++) {
            address lpTokenAddress = quickswapFactory.allPairs(pairIndex);
            (address stakingRewards, , , , , ) = quickswapStakingRewardsFactory.stakingRewardsInfoByStakingToken(
                lpTokenAddress
            );
            if (stakingRewards == address(0)) {
                continue;
            }
            uint256 amount = IStakingDualRewards(stakingRewards).balanceOf(user);

            IApePair lpToken = IApePair(lpTokenAddress);

            Balance memory balance;
            balance.lp = lpTokenAddress;
            balance.pid = 0;
            balance.wallet = lpToken.balanceOf(user);
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
