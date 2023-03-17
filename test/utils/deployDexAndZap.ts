import { ethers } from 'hardhat'
import { dex, utils } from '@ape.swap/hardhat-test-helpers'
const ether = utils.ether

export async function deployDexAndZap() {
  const ApeSwapZap__factory = await ethers.getContractFactory('ApeSwapZapFullV1')
  const Treasury__factory = await ethers.getContractFactory('Treasury')

  const [owner, feeTo, alice] = await ethers.getSigners()

  let { dexFactory, dexRouter, mockWBNB, mockTokens, dexPairs } = await dex.deployMockDex(
    ethers,
    [owner, feeTo, alice],
    5
  )

  const otherDex = await dex.deployMockDex(ethers, [owner, feeTo, alice], 5)

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
    // FIXME: cc
    // factories: {},
    otherDex,
  }
}
