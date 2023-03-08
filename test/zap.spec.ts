import { expect } from 'chai'
import { utils, dex } from '@ape.swap/hardhat-test-helpers'
import { mine, time, loadFixture } from '@nomicfoundation/hardhat-network-helpers'
import '@nomicfoundation/hardhat-chai-matchers'
import { ethers } from 'hardhat'

const ether = utils.ether

describe('Zap', function () {
  async function deployDexAndZap() {
    const ApeSwapZap__factory = await ethers.getContractFactory('ApeSwapZapFullV1')
    const Treasury__factory = await ethers.getContractFactory('Treasury')

    const [owner, feeTo, alice] = await ethers.getSigners()

    const { dexFactory, dexRouter, mockWBNB, mockTokens, dexPairs } = await dex.deployMockDex(
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
      factories: {},
    }
  }

  it('Should be able to do a token -> token-token zap', async () => {
    const { zapContract, dexFactory, dexRouter, mockWBNB, banana, bitcoin, ethereum, busd, gnana, signers, factories } =
      await loadFixture(deployDexAndZap)

    const lp = await dexFactory.getPair(banana.address, bitcoin.address)
    const lpContract = await ethers.getContractAt('IApePair', lp)

    const balanceBefore = await lpContract.balanceOf(signers.alice.address)

    await zapContract
      .connect(signers.alice)
      .zap(
        banana.address,
        ether('1'),
        [banana.address, bitcoin.address],
        [],
        [banana.address, bitcoin.address],
        [0, 0],
        [0, 0],
        signers.alice.address,
        '9999999999'
      )

    const balanceAfter = await lpContract.balanceOf(signers.alice.address)
    expect(Number(balanceAfter)).gt(Number(balanceBefore))
  })

  it('Should be able to do a token -> different token-token zap', async () => {
    const { zapContract, dexFactory, dexRouter, mockWBNB, banana, bitcoin, ethereum, busd, gnana, signers, factories } =
      await loadFixture(deployDexAndZap)

    const lp = await dexFactory.getPair(ethereum.address, bitcoin.address)
    const lpContract = await ethers.getContractAt('IApePair', lp)
    const balanceBefore = await lpContract.balanceOf(signers.alice.address)

    await zapContract
      .connect(signers.alice)
      .zap(
        banana.address,
        ether('1'),
        [ethereum.address, bitcoin.address],
        [banana.address, ethereum.address],
        [banana.address, bitcoin.address],
        [0, 0],
        [0, 0],
        signers.alice.address,
        '9999999999'
      )

    const balanceAfter = await lpContract.balanceOf(signers.alice.address)
    expect(Number(balanceAfter)).gt(Number(balanceBefore))
  })

  it('Should be able to do a token -> native-token zap', async () => {
    const { zapContract, dexFactory, dexRouter, mockWBNB, banana, bitcoin, ethereum, busd, gnana, signers, factories } =
      await loadFixture(deployDexAndZap)

    const lp = await dexFactory.getPair(banana.address, mockWBNB.address)
    const lpContract = await ethers.getContractAt('IApePair', lp)
    const balanceBefore = await lpContract.balanceOf(signers.alice.address)

    await zapContract
      .connect(signers.alice)
      .zap(
        banana.address,
        ether('1'),
        [banana.address, mockWBNB.address],
        [],
        [banana.address, mockWBNB.address],
        [0, 0],
        [0, 0],
        signers.alice.address,
        '9999999999'
      )

    const balanceAfter = await lpContract.balanceOf(signers.alice.address)
    expect(Number(balanceAfter)).gt(Number(balanceBefore))
  })

  it('Should be able to do a wrapped -> token-token zap', async () => {
    const { zapContract, dexFactory, dexRouter, mockWBNB, banana, bitcoin, ethereum, busd, gnana, signers, factories } =
      await loadFixture(deployDexAndZap)

    const lp = await dexFactory.getPair(ethereum.address, bitcoin.address)
    const lpContract = await ethers.getContractAt('IApePair', lp)
    const balanceBefore = await lpContract.balanceOf(signers.alice.address)

    await mockWBNB.connect(signers.alice).deposit({ value: ether('1') })
    await mockWBNB.connect(signers.alice).approve(zapContract.address, ether('1000'))

    await zapContract
      .connect(signers.alice)
      .zap(
        mockWBNB.address,
        ether('0.01'),
        [ethereum.address, bitcoin.address],
        [mockWBNB.address, ethereum.address],
        [mockWBNB.address, bitcoin.address],
        [0, 0],
        [0, 0],
        signers.alice.address,
        '9999999999'
      )

    const balanceAfter = await lpContract.balanceOf(signers.alice.address)
    expect(Number(balanceAfter)).gt(Number(balanceBefore))
  })

  it('Should be able to do a wrapped -> native-token zap', async () => {
    const { zapContract, dexFactory, dexRouter, mockWBNB, banana, bitcoin, ethereum, busd, gnana, signers, factories } =
      await loadFixture(deployDexAndZap)

    const lp = await dexFactory.getPair(mockWBNB.address, bitcoin.address)
    const lpContract = await ethers.getContractAt('IApePair', lp)
    const balanceBefore = await lpContract.balanceOf(signers.alice.address)

    await mockWBNB.connect(signers.alice).deposit({ value: ether('1') })
    await mockWBNB.connect(signers.alice).approve(zapContract.address, ether('1000'))

    await zapContract
      .connect(signers.alice)
      .zap(
        mockWBNB.address,
        ether('0.01'),
        [mockWBNB.address, bitcoin.address],
        [],
        [mockWBNB.address, bitcoin.address],
        [0, 0],
        [0, 0],
        signers.alice.address,
        '9999999999'
      )

    const balanceAfter = await lpContract.balanceOf(signers.alice.address)
    expect(Number(balanceAfter)).gt(Number(balanceBefore))
  })

  it('Should be able to do a native -> token-token zap', async () => {
    const { zapContract, dexFactory, dexRouter, mockWBNB, banana, bitcoin, ethereum, busd, gnana, signers, factories } =
      await loadFixture(deployDexAndZap)

    const lp = await dexFactory.getPair(banana.address, bitcoin.address)
    const lpContract = await ethers.getContractAt('IApePair', lp)
    const balanceBefore = await lpContract.balanceOf(signers.alice.address)

    await zapContract
      .connect(signers.alice)
      .zapNative(
        [banana.address, bitcoin.address],
        [mockWBNB.address, banana.address],
        [mockWBNB.address, bitcoin.address],
        [0, 0],
        [0, 0],
        signers.alice.address,
        '9999999999',
        { value: ether('1') }
      )

    const balanceAfter = await lpContract.balanceOf(signers.alice.address)
    expect(Number(balanceAfter)).gt(Number(balanceBefore))
  })

  it('Should be able to do a native -> native-token zap', async () => {
    const { zapContract, dexFactory, dexRouter, mockWBNB, banana, bitcoin, ethereum, busd, gnana, signers, factories } =
      await loadFixture(deployDexAndZap)

    const lp = await dexFactory.getPair(banana.address, mockWBNB.address)
    const lpContract = await ethers.getContractAt('IApePair', lp)
    const balanceBefore = await lpContract.balanceOf(signers.alice.address)

    await zapContract
      .connect(signers.alice)
      .zapNative(
        [banana.address, mockWBNB.address],
        [mockWBNB.address, banana.address],
        [],
        [0, 0],
        [0, 0],
        signers.alice.address,
        '9999999999',
        { value: ether('1') }
      )

    const balanceAfter = await lpContract.balanceOf(signers.alice.address)
    expect(Number(balanceAfter)).gt(Number(balanceBefore))
  })

  it('Should receive dust back', async () => {
    const { zapContract, dexFactory, dexRouter, mockWBNB, banana, bitcoin, ethereum, busd, gnana, signers, factories } =
      await loadFixture(deployDexAndZap)

    const tokenContract0 = await ethers.getContractAt('IERC20', banana.address)
    const tokenContract1 = await ethers.getContractAt('IERC20', bitcoin.address)
    const balanceBefore = await tokenContract0.balanceOf(signers.alice.address)

    await zapContract
      .connect(signers.alice)
      .zap(
        banana.address,
        ether('1'),
        [banana.address, bitcoin.address],
        [],
        [banana.address, bitcoin.address],
        [0, 0],
        [0, 0],
        signers.alice.address,
        '9999999999'
      )

    const balanceAfter = await tokenContract0.balanceOf(signers.alice.address)
    expect(Number(balanceAfter)).gt(Number(balanceBefore) - Number(ether('1')))

    const token0Balance = await tokenContract0.balanceOf(zapContract.address)
    const token1Balance = await tokenContract1.balanceOf(zapContract.address)
    expect(Number(token0Balance)).equal(0)
    expect(Number(token1Balance)).equal(0)
  })

  it('Should revert for non existing pair', async () => {
    const { zapContract, dexFactory, dexRouter, mockWBNB, banana, bitcoin, ethereum, busd, gnana, signers, factories } =
      await loadFixture(deployDexAndZap)

    await expect(
      zapContract
        .connect(signers.alice)
        .zap(
          banana.address,
          ether('1'),
          [bitcoin.address, busd.address],
          [banana.address, bitcoin.address],
          [banana.address, busd.address],
          [0, 0],
          [0, 0],
          signers.alice.address,
          '9999999999'
        )
    ).to.be.revertedWith("ApeSwapZap: Pair doesn't exist")
  })
})
