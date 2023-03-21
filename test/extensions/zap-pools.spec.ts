import { expect } from 'chai'
import { dex, utils, farmV2 } from '@ape.swap/hardhat-test-helpers'
import { mine, time, loadFixture } from '@nomicfoundation/hardhat-network-helpers'
import '@nomicfoundation/hardhat-chai-matchers'
import { ethers } from 'hardhat'
import { deployDexAndZap } from '../fixtures'

const ether = utils.ether

async function getFactories(_ethers: typeof ethers) {
  const BEP20RewardApeV5__factory = await _ethers.getContractFactory('BEP20RewardApeV5')
  return { BEP20RewardApeV5__factory }
}

async function fixture() {
  const dexAndZap = await deployDexAndZap(ethers)
  const factories = await getFactories(ethers)
  return { ...dexAndZap, factories }
}

describe('Zap pools', function () {
  it('Should zap native into banana pool', async () => {
    const { zapContract, dexFactory, dexRouter, mockWBNB, banana, bitcoin, ethereum, busd, gnana, signers, factories } =
      await loadFixture(fixture)

    const pool = await factories.BEP20RewardApeV5__factory.deploy()
    await pool.initialize(banana.address, banana.address, 0, 0, 0)
    await zapContract
      .connect(signers.alice)
      .zapSingleAssetPoolNative([mockWBNB.address, banana.address], 0, '9999999999', pool.address, {
        value: ether('1'),
      })
    const userInfo = await pool.userInfo(signers.alice.address)
    expect(Number(userInfo.amount)).gt(0)
    const balance = await mockWBNB.balanceOf(zapContract.address)
    expect(Number(balance)).eq(0)
  })

  it('Should zap other into banana pool', async () => {
    const { zapContract, dexFactory, dexRouter, mockWBNB, banana, bitcoin, ethereum, busd, gnana, signers, factories } =
      await loadFixture(fixture)

    const pool = await factories.BEP20RewardApeV5__factory.deploy()
    await pool.initialize(banana.address, banana.address, 0, 0, 0)
    await zapContract
      .connect(signers.alice)
      .zapSingleAssetPool(
        bitcoin.address,
        ether('100'),
        [bitcoin.address, banana.address],
        0,
        '9999999999',
        pool.address
      )
    const userInfo = await pool.userInfo(signers.alice.address)
    expect(Number(userInfo.amount)).gt(0)
    const balance = await bitcoin.balanceOf(zapContract.address)
    expect(Number(balance)).eq(0)
  })

  it('Should zap banana into gnana pool', async () => {
    const { zapContract, dexFactory, dexRouter, mockWBNB, banana, bitcoin, ethereum, busd, gnana, signers, factories } =
      await loadFixture(fixture)

    const pool = await factories.BEP20RewardApeV5__factory.deploy()
    await pool.initialize(gnana.address, banana.address, 0, 0, 0)
    await zapContract
      .connect(signers.alice)
      .zapSingleAssetPool(banana.address, ether('100'), [banana.address], 0, '9999999999', pool.address)
    const userInfo = await pool.userInfo(signers.alice.address)
    expect(Number(userInfo.amount)).gt(0)
    const balance = await banana.balanceOf(zapContract.address)
    expect(Number(balance)).eq(0)
  })

  it('Should zap native into gnana pool', async () => {
    const { zapContract, dexFactory, dexRouter, mockWBNB, banana, bitcoin, ethereum, busd, gnana, signers, factories } =
      await loadFixture(fixture)

    const pool = await factories.BEP20RewardApeV5__factory.deploy()
    await pool.initialize(gnana.address, banana.address, 0, 0, 0)
    await zapContract
      .connect(signers.alice)
      .zapSingleAssetPoolNative([mockWBNB.address, banana.address], 0, '9999999999', pool.address, {
        value: ether('1'),
      })
    const userInfo = await pool.userInfo(signers.alice.address)
    expect(Number(userInfo.amount)).gt(0)
    const balance = await mockWBNB.balanceOf(zapContract.address)
    expect(Number(balance)).eq(0)
  })

  it('Should zap other into gnana pool', async () => {
    const { zapContract, dexFactory, dexRouter, mockWBNB, banana, bitcoin, ethereum, busd, gnana, signers, factories } =
      await loadFixture(fixture)

    const pool = await factories.BEP20RewardApeV5__factory.deploy()
    await pool.initialize(gnana.address, banana.address, 0, 0, 0)
    await zapContract
      .connect(signers.alice)
      .zapSingleAssetPool(
        bitcoin.address,
        ether('100'),
        [bitcoin.address, banana.address],
        0,
        '9999999999',
        pool.address
      )
    const userInfo = await pool.userInfo(signers.alice.address)
    expect(Number(userInfo.amount)).gt(0)
    const balance = await bitcoin.balanceOf(zapContract.address)
    expect(Number(balance)).eq(0)
  })

  it('Should zap banana into busd pool', async () => {
    const { zapContract, dexFactory, dexRouter, mockWBNB, banana, bitcoin, ethereum, busd, gnana, signers, factories } =
      await loadFixture(fixture)

    const pool = await factories.BEP20RewardApeV5__factory.deploy()
    await pool.initialize(busd.address, banana.address, 0, 0, 0)
    await zapContract
      .connect(signers.alice)
      .zapSingleAssetPool(banana.address, ether('100'), [banana.address, busd.address], 0, '9999999999', pool.address)
    const userInfo = await pool.userInfo(signers.alice.address)
    expect(Number(userInfo.amount)).gt(0)
    const balance = await banana.balanceOf(zapContract.address)
    expect(Number(balance)).eq(0)
  })

  it('Should zap native into busd pool', async () => {
    const { zapContract, dexFactory, dexRouter, mockWBNB, banana, bitcoin, ethereum, busd, gnana, signers, factories } =
      await loadFixture(fixture)

    const pool = await factories.BEP20RewardApeV5__factory.deploy()
    await pool.initialize(busd.address, banana.address, 0, 0, 0)
    await zapContract
      .connect(signers.alice)
      .zapSingleAssetPoolNative([mockWBNB.address, busd.address], 0, '9999999999', pool.address, {
        value: ether('1'),
      })
    const userInfo = await pool.userInfo(signers.alice.address)
    expect(Number(userInfo.amount)).gt(0)
    const balance = await mockWBNB.balanceOf(zapContract.address)
    expect(Number(balance)).eq(0)
  })

  it('Should zap other into busd pool', async () => {
    const { zapContract, dexFactory, dexRouter, mockWBNB, banana, bitcoin, ethereum, busd, gnana, signers, factories } =
      await loadFixture(fixture)

    const pool = await factories.BEP20RewardApeV5__factory.deploy()
    await pool.initialize(busd.address, banana.address, 0, 0, 0)
    await zapContract
      .connect(signers.alice)
      .zapSingleAssetPool(
        bitcoin.address,
        ether('100'),
        [bitcoin.address, banana.address, busd.address],
        0,
        '9999999999',
        pool.address
      )
    const userInfo = await pool.userInfo(signers.alice.address)
    expect(Number(userInfo.amount)).gt(0)
    const balance = await bitcoin.balanceOf(zapContract.address)
    expect(Number(balance)).eq(0)
  })

  it('Should zap banana into LP pool', async () => {
    const { zapContract, dexFactory, dexRouter, mockWBNB, banana, bitcoin, ethereum, busd, gnana, signers, factories } =
      await loadFixture(fixture)

    const pool = await factories.BEP20RewardApeV5__factory.deploy()
    const lp = await dexFactory.getPair(banana.address, bitcoin.address)
    await pool.initialize(lp, banana.address, 0, 0, 0)

    await zapContract
      .connect(signers.alice)
      .zapLPPool(
        banana.address,
        ether('100'),
        [banana.address, bitcoin.address],
        [],
        [banana.address, bitcoin.address],
        [0, 0],
        [0, 0],
        '9999999999',
        pool.address
      )

    const userInfo = await pool.userInfo(signers.alice.address)
    expect(Number(userInfo.amount)).gt(0)

    const lpContract = await ethers.getContractAt('IApePair', lp)
    const balance = await lpContract.balanceOf(zapContract.address)
    expect(Number(balance)).eq(0)
  })

  it('Should zap native into LP pool', async () => {
    const { zapContract, dexFactory, dexRouter, mockWBNB, banana, bitcoin, ethereum, busd, gnana, signers, factories } =
      await loadFixture(fixture)

    const pool = await factories.BEP20RewardApeV5__factory.deploy()
    const lp = await dexFactory.getPair(banana.address, bitcoin.address)
    await pool.initialize(lp, banana.address, 0, 0, 0)

    await zapContract
      .connect(signers.alice)
      .zapLPPoolNative(
        [banana.address, bitcoin.address],
        [mockWBNB.address, banana.address],
        [mockWBNB.address, bitcoin.address],
        [0, 0],
        [0, 0],
        '9999999999',
        pool.address,
        { value: ether('1') }
      )

    const userInfo = await pool.userInfo(signers.alice.address)
    expect(Number(userInfo.amount)).gt(0)

    const lpContract = await ethers.getContractAt('IApePair', lp)
    const balance = await lpContract.balanceOf(zapContract.address)
    expect(Number(balance)).eq(0)
  })

  it('Should zap other into LP pool', async () => {
    const { zapContract, dexFactory, dexRouter, mockWBNB, banana, bitcoin, ethereum, busd, gnana, signers, factories } =
      await loadFixture(fixture)

    const pool = await factories.BEP20RewardApeV5__factory.deploy()
    const lp = await dexFactory.getPair(banana.address, bitcoin.address)
    await pool.initialize(lp, banana.address, 0, 0, 0)

    await zapContract
      .connect(signers.alice)
      .zapLPPool(
        ethereum.address,
        ether('100'),
        [banana.address, bitcoin.address],
        [ethereum.address, banana.address],
        [ethereum.address, bitcoin.address],
        [0, 0],
        [0, 0],
        '9999999999',
        pool.address
      )

    const userInfo = await pool.userInfo(signers.alice.address)
    expect(Number(userInfo.amount)).gt(0)

    const lpContract = await ethers.getContractAt('IApePair', lp)
    const balance = await lpContract.balanceOf(zapContract.address)
    expect(Number(balance)).eq(0)
  })
})
