import { ethers } from 'hardhat'
import { farmV2, utils } from '@ape.swap/hardhat-test-helpers'
const ether = utils.ether

export async function deployMockFarmV2(_ethers: typeof ethers) {
  const [owner, feeTo, alice] = await _ethers.getSigners()

  const deployedFarmV2 = await farmV2.deployMockFarmV2(_ethers, [owner, feeTo], {})

  return deployedFarmV2
}
