import { ethers } from 'hardhat'
import { dex, utils } from '@ape.swap/hardhat-test-helpers'
import { ApeSwapZapExtendedV0, ApeSwapZapFullV1, IApePair } from '../../typechain-types'
import { Contract } from 'ethers'
const ether = utils.ether

type ZapContractName = 'ApeSwapZapFullV1' | 'ApeSwapZapExtendedV0'
type ZapContractType<C> = C extends 'ApeSwapZapFullV1'
  ? ApeSwapZapFullV1
  : C extends 'ApeSwapZapExtendedV0'
  ? ApeSwapZapExtendedV0
  : never

export async function deployDexAndZapExtended(_ethers: typeof ethers) {
  return await deployDexAndZap(_ethers, 'ApeSwapZapExtendedV0')
}

export async function deployDexAndZapFull(_ethers: typeof ethers) {
  return await deployDexAndZap(_ethers, 'ApeSwapZapFullV1')
}

async function deployDexAndZap<Zap extends ZapContractName>(_ethers: typeof ethers, zapImplementation: Zap) {
  const [owner, feeTo, alice] = await _ethers.getSigners()

  /**
   * Setup Mock Dex
   */
  let { dexFactory, dexRouter, mockWBNB, mockTokens, dexPairs } = await dex.deployMockDex(
    _ethers,
    [owner, feeTo, alice],
    5
  )
  // Setup DEX for migration testing
  const otherDex = await dex.deployMockDex(_ethers, [owner, feeTo, alice], 5)

  const banana = mockTokens[0]
  const bitcoin = mockTokens[1]
  const ethereum = mockTokens[2]
  const busd = mockTokens[3]
  const gnana = mockTokens[4]

  /**
   * Setup test account funding
   */
  await banana.connect(alice).mint(ether('1000'))
  await bitcoin.connect(alice).mint(ether('1000'))
  await ethereum.connect(alice).mint(ether('1000'))
  await busd.connect(alice).mint(ether('1000'))

  /**
   * Add liquidity to Mock DEX
   */
  await banana.connect(owner).mint(ether('4000'))
  await bitcoin.connect(owner).mint(ether('4000'))
  await ethereum.connect(owner).mint(ether('4000'))
  await busd.connect(owner).mint(ether('4000'))

  await banana.connect(owner).approve(dexRouter.address, ether('3000'))
  await bitcoin.connect(owner).approve(dexRouter.address, ether('3000'))
  await ethereum.connect(owner).approve(dexRouter.address, ether('3000'))
  await busd.connect(owner).approve(dexRouter.address, ether('3000'))

  await dexRouter
    .connect(owner)
    .addLiquidity(banana.address, bitcoin.address, ether('1000'), ether('1000'), 0, 0, owner.address, '9999999999')
  await dexRouter
    .connect(owner)
    .addLiquidity(banana.address, ethereum.address, ether('1000'), ether('1000'), 0, 0, owner.address, '9999999999')
  await dexRouter
    .connect(owner)
    .addLiquidity(bitcoin.address, ethereum.address, ether('1000'), ether('1000'), 0, 0, owner.address, '9999999999')
  await dexRouter
    .connect(owner)
    .addLiquidity(banana.address, busd.address, ether('1000'), ether('1000'), 0, 0, owner.address, '9999999999')

  const lpPairs = (await Promise.all([
    dexFactory.getPair(banana.address, bitcoin.address).then((pair) => _ethers.getContractAt('IApePair', pair)),
    dexFactory.getPair(banana.address, ethereum.address).then((pair) => _ethers.getContractAt('IApePair', pair)),
    dexFactory.getPair(bitcoin.address, ethereum.address).then((pair) => _ethers.getContractAt('IApePair', pair)),
    dexFactory.getPair(banana.address, busd.address).then((pair) => _ethers.getContractAt('IApePair', pair)),
  ])) as IApePair[]

  /**
   * GNANA Treasury Creation + Funding
   */
  const Treasury__factory = await _ethers.getContractFactory('Treasury')
  const Treasury = await Treasury__factory.deploy(banana.address, gnana.address)
  await gnana.connect(owner).mint(ether('2000'))
  await gnana.connect(owner).transfer(Treasury.address, ether('2000'))

  /**
   * Zap Contract deployment and approval
   */
  let zapContract: ZapContractType<Zap>
  if (zapImplementation == 'ApeSwapZapFullV1') {
    const ApeSwapZap__factory = await _ethers.getContractFactory('ApeSwapZapFullV1')
    zapContract = (await ApeSwapZap__factory.deploy(dexRouter.address, Treasury.address)) as ZapContractType<Zap>
  } else if (zapImplementation == 'ApeSwapZapExtendedV0') {
    const ApeSwapZap__factory = await _ethers.getContractFactory('ApeSwapZapExtendedV0')
    zapContract = (await ApeSwapZap__factory.deploy(dexRouter.address)) as ZapContractType<Zap>
  } else {
    throw new Error(`${deployDexAndZap.name}:: Invalid Zap Implementation`)
  }

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
    otherDex,
    lpPairs,
  }
}
