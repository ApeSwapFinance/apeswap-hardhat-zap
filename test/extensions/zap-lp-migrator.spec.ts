// import { expect } from 'chai'
// import { dex, utils } from '@ape.swap/hardhat-test-helpers'
// import { mine, time, loadFixture } from '@nomicfoundation/hardhat-network-helpers'
// import '@nomicfoundation/hardhat-chai-matchers'
// import { ethers } from 'hardhat'
// import { deployDexAndZap } from '../fixtures/deployDexAndZap'
// const ether = utils.ether

// async function fixture() {
//   const dexAndZap = await deployDexAndZap(ethers)
//   return { ...dexAndZap }
// }

// describe('Zap LP Migrator', function () {
//   it('Should zap competitive LPs to Ape LPs', async () => {
//     const { zapContract, dexFactory, dexRouter, mockWBNB, banana, bitcoin, ethereum, busd, gnana, signers, otherDex } =
//       await loadFixture(fixture)

//     await banana.approve(otherDex.dexRouter.address, ether('3000'))
//     await bitcoin.approve(otherDex.dexRouter.address, ether('3000'))

//     await otherDex.dexRouter.addLiquidity(
//       banana.address,
//       bitcoin.address,
//       ether('100'),
//       ether('100'),
//       0,
//       0,
//       signers.alice.address,
//       '9999999999'
//     )

//     const apeLP = await dexFactory.getPair(banana.address, bitcoin.address)
//     const apeLPContract = await ethers.getContractAt('IApePair', apeLP)
//     const apeBalanceBefore = await apeLPContract.balanceOf(signers.alice.address)

//     const lp = await otherDex.dexFactory.getPair(banana.address, bitcoin.address)
//     const lpContract = await ethers.getContractAt('IApePair', lp)
//     await lpContract.connect(signers.alice).approve(zapContract.address, ether('10'))
//     const balanceBefore = await lpContract.balanceOf(signers.alice.address)

//     await zapContract
//       .connect(signers.alice)
//       .zapLPMigrator(otherDex.dexRouter.address, lp, ether('10'), 0, 0, 0, 0, '9999999999')

//     const balanceAfter = await lpContract.balanceOf(signers.alice.address)
//     const apeBalanceAfter = await apeLPContract.balanceOf(signers.alice.address)
//     expect(Number(balanceAfter)).lt(Number(balanceBefore))
//     expect(Number(apeBalanceAfter)).gt(Number(apeBalanceBefore))
//   })
// })
