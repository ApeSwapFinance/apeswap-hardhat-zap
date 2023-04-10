// import { expect } from 'chai'
// import { utils, dex } from '@ape.swap/hardhat-test-helpers'
// import { mine, time, loadFixture } from '@nomicfoundation/hardhat-network-helpers'
// import '@nomicfoundation/hardhat-chai-matchers'
// import { ethers } from 'hardhat'
// import { deployDexAndZap } from './fixtures/deployDexAndZap'

// const ether = utils.ether

// async function fixture() {
//   const dexAndZap = await deployDexAndZap(ethers)
//   return { ...dexAndZap }
// }

// describe('Zap', function () {
//   it('Should be able to do a token -> token-token zap', async () => {
//     const { zapContract, dexFactory, dexRouter, mockWBNB, banana, bitcoin, ethereum, busd, gnana, signers } =
//       await loadFixture(fixture)

//     const lp = await dexFactory.getPair(banana.address, bitcoin.address)
//     const lpContract = await ethers.getContractAt('IApePair', lp)

//     const balanceBefore = await lpContract.balanceOf(signers.alice.address)

//     await zapContract
//       .connect(signers.alice)
//       .zap(
//         banana.address,
//         ether('1'),
//         [banana.address, bitcoin.address],
//         [],
//         [banana.address, bitcoin.address],
//         [0, 0],
//         [0, 0],
//         signers.alice.address,
//         '9999999999'
//       )

//     const balanceAfter = await lpContract.balanceOf(signers.alice.address)
//     expect(Number(balanceAfter)).gt(Number(balanceBefore))
//   })

//   it('Should be able to do a token -> different token-token zap', async () => {
//     const { zapContract, dexFactory, dexRouter, mockWBNB, banana, bitcoin, ethereum, busd, gnana, signers } =
//       await loadFixture(fixture)

//     const lp = await dexFactory.getPair(ethereum.address, bitcoin.address)
//     const lpContract = await ethers.getContractAt('IApePair', lp)
//     const balanceBefore = await lpContract.balanceOf(signers.alice.address)

//     await zapContract
//       .connect(signers.alice)
//       .zap(
//         banana.address,
//         ether('1'),
//         [ethereum.address, bitcoin.address],
//         [banana.address, ethereum.address],
//         [banana.address, bitcoin.address],
//         [0, 0],
//         [0, 0],
//         signers.alice.address,
//         '9999999999'
//       )

//     const balanceAfter = await lpContract.balanceOf(signers.alice.address)
//     expect(Number(balanceAfter)).gt(Number(balanceBefore))
//   })

//   it('Should be able to do a token -> native-token zap', async () => {
//     const { zapContract, dexFactory, dexRouter, mockWBNB, banana, bitcoin, ethereum, busd, gnana, signers } =
//       await loadFixture(fixture)

//     const lp = await dexFactory.getPair(banana.address, mockWBNB.address)
//     const lpContract = await ethers.getContractAt('IApePair', lp)
//     const balanceBefore = await lpContract.balanceOf(signers.alice.address)

//     await zapContract
//       .connect(signers.alice)
//       .zap(
//         banana.address,
//         ether('1'),
//         [banana.address, mockWBNB.address],
//         [],
//         [banana.address, mockWBNB.address],
//         [0, 0],
//         [0, 0],
//         signers.alice.address,
//         '9999999999'
//       )

//     const balanceAfter = await lpContract.balanceOf(signers.alice.address)
//     expect(Number(balanceAfter)).gt(Number(balanceBefore))
//   })

//   it('Should be able to do a wrapped -> token-token zap', async () => {
//     const { zapContract, dexFactory, dexRouter, mockWBNB, banana, bitcoin, ethereum, busd, gnana, signers } =
//       await loadFixture(fixture)

//     const lp = await dexFactory.getPair(ethereum.address, bitcoin.address)
//     const lpContract = await ethers.getContractAt('IApePair', lp)
//     const balanceBefore = await lpContract.balanceOf(signers.alice.address)

//     await mockWBNB.connect(signers.alice).deposit({ value: ether('1') })
//     await mockWBNB.connect(signers.alice).approve(zapContract.address, ether('1000'))

//     await zapContract
//       .connect(signers.alice)
//       .zap(
//         mockWBNB.address,
//         ether('0.01'),
//         [ethereum.address, bitcoin.address],
//         [mockWBNB.address, ethereum.address],
//         [mockWBNB.address, bitcoin.address],
//         [0, 0],
//         [0, 0],
//         signers.alice.address,
//         '9999999999'
//       )

//     const balanceAfter = await lpContract.balanceOf(signers.alice.address)
//     expect(Number(balanceAfter)).gt(Number(balanceBefore))
//   })

//   it('Should be able to do a wrapped -> native-token zap', async () => {
//     const { zapContract, dexFactory, dexRouter, mockWBNB, banana, bitcoin, ethereum, busd, gnana, signers } =
//       await loadFixture(fixture)

//     const lp = await dexFactory.getPair(mockWBNB.address, bitcoin.address)
//     const lpContract = await ethers.getContractAt('IApePair', lp)
//     const balanceBefore = await lpContract.balanceOf(signers.alice.address)

//     await mockWBNB.connect(signers.alice).deposit({ value: ether('1') })
//     await mockWBNB.connect(signers.alice).approve(zapContract.address, ether('1000'))

//     await zapContract
//       .connect(signers.alice)
//       .zap(
//         mockWBNB.address,
//         ether('0.01'),
//         [mockWBNB.address, bitcoin.address],
//         [],
//         [mockWBNB.address, bitcoin.address],
//         [0, 0],
//         [0, 0],
//         signers.alice.address,
//         '9999999999'
//       )

//     const balanceAfter = await lpContract.balanceOf(signers.alice.address)
//     expect(Number(balanceAfter)).gt(Number(balanceBefore))
//   })

//   it('Should be able to do a native -> token-token zap', async () => {
//     const { zapContract, dexFactory, dexRouter, mockWBNB, banana, bitcoin, ethereum, busd, gnana, signers } =
//       await loadFixture(fixture)

//     const lp = await dexFactory.getPair(banana.address, bitcoin.address)
//     const lpContract = await ethers.getContractAt('IApePair', lp)
//     const balanceBefore = await lpContract.balanceOf(signers.alice.address)

//     await zapContract
//       .connect(signers.alice)
//       .zapNative(
//         [banana.address, bitcoin.address],
//         [mockWBNB.address, banana.address],
//         [mockWBNB.address, bitcoin.address],
//         [0, 0],
//         [0, 0],
//         signers.alice.address,
//         '9999999999',
//         { value: ether('1') }
//       )

//     const balanceAfter = await lpContract.balanceOf(signers.alice.address)
//     expect(Number(balanceAfter)).gt(Number(balanceBefore))
//   })

//   it('Should be able to do a native -> native-token zap', async () => {
//     const { zapContract, dexFactory, dexRouter, mockWBNB, banana, bitcoin, ethereum, busd, gnana, signers } =
//       await loadFixture(fixture)

//     const lp = await dexFactory.getPair(banana.address, mockWBNB.address)
//     const lpContract = await ethers.getContractAt('IApePair', lp)
//     const balanceBefore = await lpContract.balanceOf(signers.alice.address)

//     await zapContract
//       .connect(signers.alice)
//       .zapNative(
//         [banana.address, mockWBNB.address],
//         [mockWBNB.address, banana.address],
//         [],
//         [0, 0],
//         [0, 0],
//         signers.alice.address,
//         '9999999999',
//         { value: ether('1') }
//       )

//     const balanceAfter = await lpContract.balanceOf(signers.alice.address)
//     expect(Number(balanceAfter)).gt(Number(balanceBefore))
//   })

//   it('Should receive dust back', async () => {
//     const { zapContract, dexFactory, dexRouter, mockWBNB, banana, bitcoin, ethereum, busd, gnana, signers } =
//       await loadFixture(fixture)

//     const tokenContract0 = await ethers.getContractAt('IERC20', banana.address)
//     const tokenContract1 = await ethers.getContractAt('IERC20', bitcoin.address)
//     const balanceBefore = await tokenContract0.balanceOf(signers.alice.address)

//     await zapContract
//       .connect(signers.alice)
//       .zap(
//         banana.address,
//         ether('1'),
//         [banana.address, bitcoin.address],
//         [],
//         [banana.address, bitcoin.address],
//         [0, 0],
//         [0, 0],
//         signers.alice.address,
//         '9999999999'
//       )

//     const balanceAfter = await tokenContract0.balanceOf(signers.alice.address)
//     expect(Number(balanceAfter)).gt(Number(balanceBefore) - Number(ether('1')))

//     const token0Balance = await tokenContract0.balanceOf(zapContract.address)
//     const token1Balance = await tokenContract1.balanceOf(zapContract.address)
//     expect(Number(token0Balance)).equal(0)
//     expect(Number(token1Balance)).equal(0)
//   })

//   it('Should revert for non existing pair', async () => {
//     const { zapContract, dexFactory, dexRouter, mockWBNB, banana, bitcoin, ethereum, busd, gnana, signers } =
//       await loadFixture(fixture)

//     await expect(
//       zapContract
//         .connect(signers.alice)
//         .zap(
//           banana.address,
//           ether('1'),
//           [bitcoin.address, busd.address],
//           [banana.address, bitcoin.address],
//           [banana.address, busd.address],
//           [0, 0],
//           [0, 0],
//           signers.alice.address,
//           '9999999999'
//         )
//     ).to.be.revertedWith("ApeSwapZap: Pair doesn't exist")
//   })
// })
