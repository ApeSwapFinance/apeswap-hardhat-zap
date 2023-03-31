// https://hardhat.org/hardhat-runner/plugins/nomiclabs-hardhat-etherscan#using-programmatically

import { ContractFactory } from 'ethers'
import { network, run } from 'hardhat'
import fs from 'fs'

/**
 * This class is used to deploy contracts, verify them and save the deployment details to a file.
 *
 * // TODO: This class could use more logging support
 */
export class DeployManager {
  contracts: {
    name: string
    address: string
    encodedConstructorArgs: string
    constructorArguments: any[]
  }[] = []

  async deployContractFromFactory<C extends ContractFactory>(contract: C, params: Parameters<C['deploy']>) {
    const contractInstance = await contract.deploy(...params)
    const encodedConstructorArgs = contractInstance.interface.encodeDeploy(params)
    await contractInstance.deployed()

    const deployDetails = {
      name: contract.toString(),
      address: contractInstance.address,
      encodedConstructorArgs,
      constructorArguments: params,
    }

    this.contracts.push(deployDetails)

    return contractInstance
  }

  async verifyContracts() {
    for (const contract of this.contracts) {
      await run('verify:verify', {
        address: contract.address,
        constructorArguments: contract.constructorArguments,
      })
    }
  }

  async saveContractsToFile() {
    const paramsString = JSON.stringify(this.contracts, null, 2) // The 'null, 2' arguments add indentation for readability
    // Write the string to a file
    const dateString = new Date().toISOString().slice(0, 10).replace(/-/g, '') // e.g. 20230330
    const networkName = network.name

    const filePath = __dirname + `/${dateString}-${networkName}-deployment.js`
    fs.writeFileSync(filePath, `module.exports = ${paramsString};`)

    console.log(`Parameters saved to ${filePath}!`)
  }
}
