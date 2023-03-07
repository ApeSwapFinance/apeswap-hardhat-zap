import { expect } from 'chai'
import { dex, utils } from '@ape.swap/hardhat-test-helpers'
import { mine, time, loadFixture } from '@nomicfoundation/hardhat-network-helpers'
import '@nomicfoundation/hardhat-chai-matchers'
import { ethers } from 'hardhat'

const ether = utils.ether

describe('Zap pools', function () {
  async function deployDexAndZap() {
    const ApeSwapZap__factory = await ethers.getContractFactory('ApeSwapZapFullV3')
    const Treasury__factory = await ethers.getContractFactory('Treasury')
    const BEP20RewardApeV5__factory = await ethers.getContractFactory('BEP20RewardApeV5')

    const [owner, feeTo, alice] = await ethers.getSigners()

    let { dexFactory, dexRouter, mockWBNB, mockTokens, dexPairs } = await dex.deployMockDex(
      ethers,
      [owner, feeTo, alice],
      5
    )

    const banana = mockTokens[0]
    const bitcoin = mockTokens[1]
    const ethereum = mockTokens[2]
    const busd = mockTokens[3]
    const gnana = mockTokens[4]

    await banana.mint(ether('4000'))
    await bitcoin.mint(ether('4000'))
    await ethereum.mint(ether('4000'))
    await busd.mint(ether('4000'))
    await banana.connect(alice).mint(ether('1000'))
    await bitcoin.connect(alice).mint(ether('1000'))
    await ethereum.connect(alice).mint(ether('1000'))
    await busd.connect(alice).mint(ether('1000'))

    await banana.approve(dexRouter.address, ether('3000'))
    await bitcoin.approve(dexRouter.address, ether('3000'))
    await ethereum.approve(dexRouter.address, ether('3000'))
    await busd.approve(dexRouter.address, ether('3000'))

    await dexRouter.addLiquidity(
      banana.address,
      bitcoin.address,
      ether('1000'),
      ether('1000'),
      0,
      0,
      owner.address,
      '9999999999'
    )
    await dexRouter.addLiquidity(
      banana.address,
      ethereum.address,
      ether('1000'),
      ether('1000'),
      0,
      0,
      owner.address,
      '9999999999'
    )
    await dexRouter.addLiquidity(
      bitcoin.address,
      ethereum.address,
      ether('1000'),
      ether('1000'),
      0,
      0,
      owner.address,
      '9999999999'
    )
    await dexRouter.addLiquidity(
      banana.address,
      busd.address,
      ether('1000'),
      ether('1000'),
      0,
      0,
      owner.address,
      '9999999999'
    )

    const Treasury = await Treasury__factory.deploy(banana.address, gnana.address)
    await gnana.mint(ether('2000'))
    await gnana.transfer(Treasury.address, ether('2000'))

    const zapContract = await ApeSwapZap__factory.deploy(dexRouter.address, Treasury.address)

    await banana.connect(alice).approve(zapContract.address, ether('1000'))
    await bitcoin.connect(alice).approve(zapContract.address, ether('1000'))
    await ethereum.connect(alice).approve(zapContract.address, ether('1000'))
    await busd.connect(alice).approve(zapContract.address, ether('1000'))

    return {
      zapContract,
      dexFactory,
      dexRouter,
      mockWBNB,
      banana,
      bitcoin,
      ethereum,
      busd,
      gnana,
      signers: { owner, feeTo, alice },
      factories: { BEP20RewardApeV5__factory },
    }
  }

  it('Should zap native into banana pool', async () => {
    const { zapContract, dexFactory, dexRouter, mockWBNB, banana, bitcoin, ethereum, busd, gnana, signers, factories } =
      await loadFixture(deployDexAndZap)

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
      await loadFixture(deployDexAndZap)

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
      await loadFixture(deployDexAndZap)

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
      await loadFixture(deployDexAndZap)

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
      await loadFixture(deployDexAndZap)

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
      await loadFixture(deployDexAndZap)

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
      await loadFixture(deployDexAndZap)

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
      await loadFixture(deployDexAndZap)

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
      await loadFixture(deployDexAndZap)

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
      await loadFixture(deployDexAndZap)

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
      await loadFixture(deployDexAndZap)

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
