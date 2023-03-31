import { ContractFactory } from 'ethers'
import { ethers, network, run } from 'hardhat'
import { DeployedNetworks, getDeployConfig } from '../deploy.config'
import { ApeSwapZapExtendedV0__factory, ApeSwapZap__factory } from '../typechain-types'
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
  let { apeRouterAddress, goldenBananaTreasury, zapArtifact } = getDeployConfig(currentNetwork, accounts)

  const ApeSwapZapExtendedV0_Factory = (await ethers.getContractFactory(
    'ApeSwapZapExtendedV0'
  )) as ApeSwapZapExtendedV0__factory

  await deployManager.deployContractFromFactory(ApeSwapZapExtendedV0_Factory, [apeRouterAddress, goldenBananaTreasury])

  const ApeSwapZap_factory = (await ethers.getContractFactory('ApeSwapZap')) as ApeSwapZap__factory

  await deployManager.deployContractFromFactory(ApeSwapZap_factory, [apeRouterAddress])

  await deployManager.verifyContracts()
  await deployManager.saveContractsToFile()

  const output = {
    ...deployManager.contracts,
  }

  console.dir(output, { depth: 5 })
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
