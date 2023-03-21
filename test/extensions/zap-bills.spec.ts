import { ethers } from 'hardhat'
import { expect } from 'chai'
import { dex, utils, farmV2, ERC20Mock__factory } from '@ape.swap/hardhat-test-helpers'
import { mine, time, loadFixture } from '@nomicfoundation/hardhat-network-helpers'
import '@nomicfoundation/hardhat-chai-matchers'
import { deployBill, deployDexAndZap } from '../fixtures'

const ether = utils.ether

async function fixture() {
  const dexAndZap = await deployDexAndZap(ethers)
  return { ...dexAndZap }
}

describe('Zap Bills', function () {
  it('Should zap token to single asset into Treasury Bill', async () => {
    const { zapContract, dexFactory, dexRouter, mockWBNB, banana, bitcoin, ethereum, busd, gnana, signers, otherDex } =
      await loadFixture(fixture)
    const bill = await deployBill(ethers, busd, banana)

    const tokenIdsBefore = await bill.getBillIds(signers.alice.address)
    await zapContract.connect(signers.alice).zapSingleAssetTBill(
      ethereum.address, // inputToken
      ether('1'), // inputAmount
      [ethereum.address, banana.address], // path
      0, // minAmountsSwap
      '9999999999', // deadline
      bill.address, // bill address
      ether('999999999') // max price
    )
    const tokenIdsAfter = await bill.getBillIds(signers.alice.address)

    expect(tokenIdsAfter.length - tokenIdsBefore.length).eq(1)
  })

  it('Should zap native to single asset into Treasury Bill', async () => {
    const { zapContract, dexFactory, dexRouter, mockWBNB, banana, bitcoin, ethereum, busd, gnana, signers, otherDex } =
      await loadFixture(fixture)
    const bill = await deployBill(ethers, busd, banana)

    const tokenIdsBefore = await bill.getBillIds(signers.alice.address)
    await zapContract.connect(signers.alice).zapSingleAssetTBillNative(
      [mockWBNB.address, banana.address], // path
      0, // minAmountsSwap
      '9999999999', // deadline
      bill.address, // bill address
      ether('999999999'), // max price
      {
        value: ether('.0001'), // Deposit amount
      }
    )
    const tokenIdsAfter = await bill.getBillIds(signers.alice.address)

    expect(tokenIdsAfter.length - tokenIdsBefore.length).eq(1)
  })

  it('Should zap native to LP into Treasury Bill', async () => {
    const { zapContract, dexFactory, dexRouter, mockWBNB, banana, bitcoin, ethereum, busd, gnana, signers, otherDex } =
      await loadFixture(fixture)
    const lp = await dexFactory.getPair(banana.address, bitcoin.address)
    const lpContract = await ethers.getContractAt('ERC20', lp)
    const bill = await deployBill(ethers, banana, lpContract)

    const tokenIdsBefore = await bill.getBillIds(signers.alice.address)
    await zapContract.connect(signers.alice).zapTBillNative(
      [banana.address, bitcoin.address], // lpTokens
      [mockWBNB.address, banana.address], // path0
      [mockWBNB.address, bitcoin.address], // path1
      [0, 0], // minAmountsSwap
      [0, 0], // minAmountsLP
      '9999999999', // deadline
      bill.address, // bill
      ether('9999999'), // maxPrice
      {
        value: ether('.00001'), // Deposit amount
      }
    )
    const tokenIdsAfter = await bill.getBillIds(signers.alice.address)

    expect(tokenIdsAfter.length - tokenIdsBefore.length).eq(1)
  })

  it('Should zap token to LP into Treasury Bill', async () => {
    const { zapContract, dexFactory, dexRouter, mockWBNB, banana, bitcoin, ethereum, busd, gnana, signers, otherDex } =
      await loadFixture(fixture)
    const lp = await dexFactory.getPair(banana.address, bitcoin.address)
    const lpContract = await ethers.getContractAt('ERC20', lp)
    const bill = await deployBill(ethers, banana, lpContract)

    const tokenIdsBefore = await bill.getBillIds(signers.alice.address)
    await zapContract.connect(signers.alice).zapTBill(
      ethereum.address,
      ether('100'),
      [banana.address, bitcoin.address],
      [ethereum.address, banana.address],
      [ethereum.address, bitcoin.address],
      [0, 0],
      [0, 0],
      '9999999999',
      bill.address, // bill
      ether('9999999') // maxPrice
    )
    const tokenIdsAfter = await bill.getBillIds(signers.alice.address)

    expect(tokenIdsAfter.length - tokenIdsBefore.length).eq(1)
  })
})
