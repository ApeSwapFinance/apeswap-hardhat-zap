import { ethers } from 'hardhat'

/**
 * // NOTE: This is an example of the default hardhat deployment approach.
 * This project takes deployments one step further by assigning each deployment
 * its own task in ../tasks/ organized by date.
 */
async function main() {
  const ApeSwapZapFullV5 = await ethers.getContractFactory('ApeSwapZapFullV5')
  const zap = await ApeSwapZapFullV5.deploy('0x0000000000000000000000000000000000000000', { gasPrice: '150000000000' })

  await zap.deployed()

  console.log('ZAP: ', zap.address)
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
