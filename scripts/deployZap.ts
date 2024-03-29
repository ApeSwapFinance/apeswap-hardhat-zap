import { ContractFactory } from 'ethers'
import { ethers, network, run } from 'hardhat'
import { DeployedNetworks, getDeployConfig } from '../deploy.config'
import { ApeSwapZapExtendedV0__factory, ApeSwapZapExtendedV1__factory, ApeSwapZap__factory } from '../typechain-types'
import { DeployManager } from './DeployManager'

/**
 * // NOTE: This is an example of the default hardhat deployment approach.
 * This project takes deployments one step further by assigning each deployment
 * its own task in ../tasks/ organized by date.
 */
async function main() {
  const deployManager = new DeployManager()
  const currentNetwork = network.name as DeployedNetworks
  const accounts = await ethers.getSigners()
  let { apeRouterAddress, goldenBananaTreasury, zapArtifact, args } = getDeployConfig(currentNetwork, accounts)

  const ApeSwapZap_Factory = await ethers.getContractFactory(zapArtifact)

  await deployManager.deployContractFromFactory(ApeSwapZap_Factory, args || [], zapArtifact)

  const output = {
    ...deployManager.contracts,
  }
  await deployManager.saveContractsToFile()
  console.dir(output, { depth: 5 })
  // NOTE: Doing verifications last as they can take a bit
  await deployManager.verifyContracts()
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
