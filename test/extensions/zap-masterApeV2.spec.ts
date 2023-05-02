import { ethers } from 'hardhat'
import { expect } from 'chai'
import { dex, utils, farmV2, ERC20Mock__factory } from '@ape.swap/hardhat-test-helpers'
import { mine, time, loadFixture } from '@nomicfoundation/hardhat-network-helpers'
import '@nomicfoundation/hardhat-chai-matchers'
import { deployMockFarmV2, deployDexAndZapExtended as deployDexAndZap } from '../fixtures'

const ether = utils.ether

async function fixture() {
  const dexAndZap = await deployDexAndZap(ethers)
  const masterApeV2 = await deployMockFarmV2(
    ethers,
    [dexAndZap.signers.owner, dexAndZap.signers.feeTo],
    dexAndZap.lpPairs
  )
  return { ...dexAndZap, ...masterApeV2 }
}

describe('Zap MasterApeV2', function () {
  it('Should zap ERC-20 token into MasterApeV2', async () => {
    const {
      zapContract,
      dexFactory,
      dexRouter,
      mockWBNB,
      banana,
      bitcoin,
      ethereum,
      busd,
      gnana,
      signers,
      otherDex,
      lpPairs,
      masterApeV2,
      farmV2PoolIds,
    } = await loadFixture(fixture)

    const pid = 1

    // const [token0, token1] = await Promise.all([lpPairs[pid].token0(), lpPairs[pid].token1()])

    const beforeBalance = await masterApeV2.userInfo(pid, signers.alice.address)

    await zapContract.connect(signers.alice).zapMasterApeV2(
      banana.address,
      ether('1'),
      [banana.address, bitcoin.address],
      [], // path0
      [banana.address, bitcoin.address], // path1
      [0, 0], // minAmountsSwap
      [0, 0], // minAmountsLp
      '9999999999',
      masterApeV2.address, // masterApeV2
      pid // pid
    )

    const afterBalance = await masterApeV2.userInfo(pid, signers.alice.address)

    expect(afterBalance.amount.sub(beforeBalance.amount)).to.be.greaterThan(
      '0',
      `User did not receive MasterApeV2 deposit with ERC-20 Zap.`
    )
  })

  it('Should zap native token into MasterApeV2', async () => {
    const {
      zapContract,
      dexFactory,
      dexRouter,
      mockWBNB,
      banana,
      bitcoin,
      ethereum,
      busd,
      gnana,
      signers,
      otherDex,
      lpPairs,
      masterApeV2,
      farmV2PoolIds,
    } = await loadFixture(fixture)

    const pid = 1

    // const [token0, token1] = await Promise.all([lpPairs[pid].token0(), lpPairs[pid].token1()])

    const beforeBalance = await masterApeV2.userInfo(pid, signers.alice.address)

    await zapContract.connect(signers.alice).zapMasterApeV2Native(
      [banana.address, bitcoin.address],
      [mockWBNB.address, banana.address], // path0
      [mockWBNB.address, bitcoin.address], // path1
      [0, 0], // minAmountsSwap
      [0, 0], // minAmountsLp
      '9999999999',
      masterApeV2.address, // masterApeV2
      pid, // pid
      { value: ether('1') }
    )

    const afterBalance = await masterApeV2.userInfo(pid, signers.alice.address)

    expect(afterBalance.amount.sub(beforeBalance.amount)).to.be.greaterThan(
      '0',
      `User did not receive MasterApeV2 deposit with native zap.`
    )
  })
})
