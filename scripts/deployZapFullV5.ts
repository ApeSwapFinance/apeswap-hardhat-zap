import { ethers, network } from 'hardhat'
import { DeployableNetworks, getDeployConfig } from './deploy.config'
import { DeployManager } from './DeployManager'

/**
 * // NOTE: This is an example of the default hardhat deployment approach.
 * This project takes deployments one step further by assigning each deployment
 * its own task in ../tasks/ organized by date.
 */
async function main() {
  const currentNetwork = network.name as DeployableNetworks
  const deployConfig = getDeployConfig(currentNetwork) 
  const { wNative, goldenBananaTreasury } = deployConfig
  // Optionally pass in signer to deploy contracts
  const deployManager = new DeployManager()

  const ZapAnalyzer = await ethers.getContractFactory('ZapAnalyzer')
  const zapAnalyzer = await deployManager.deployContractFromFactory(ZapAnalyzer, [])
  
  const ApeSwapZapFullV5 = await ethers.getContractFactory('ApeSwapZapFullV5')
  const zap = await deployManager.deployContractFromFactory(ApeSwapZapFullV5, [wNative, goldenBananaTreasury, zapAnalyzer.address])
  await zap.deployed()

  await deployManager.verifyContracts()

  const output = {
    zap: zap.address,
    zapAnalyzer: zapAnalyzer.address,
    deployConfig,
  }
  console.dir(output, { depth: 5 })
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
