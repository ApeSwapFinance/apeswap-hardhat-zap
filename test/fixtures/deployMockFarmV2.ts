import { ethers } from 'hardhat'
import { farmV2, utils } from '@ape.swap/hardhat-test-helpers'
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
import { Contract } from 'ethers'
const ether = utils.ether

export async function deployMockFarmV2(
  _ethers: typeof ethers,
  [owner, feeTo]: [SignerWithAddress, SignerWithAddress],
  stakeTokens?: Contract[]
) {
  const deployedFarmV2 = await farmV2.deployMockFarmV2(_ethers, [owner, feeTo], {})

  let farmV2PoolIds = undefined
  if (stakeTokens) {
    farmV2PoolIds = await farmV2.addPoolsToFarm([owner], deployedFarmV2.masterApeV2, stakeTokens)
  }

  return { ...deployedFarmV2, farmV2PoolIds }
}
