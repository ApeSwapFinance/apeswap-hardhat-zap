import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
import { Network } from '../hardhat'


/**
 * Get the deploy config for a given network
 * @param network
 * @returns
 */
export const getDeployConfig = (network: DeployableNetworks, signers?: SignerWithAddress[]): DeploymentVariables => {
  const config = deployableNetworkConfig[network]
  if (!config) {
    throw new Error(`No deploy config for network ${network}`)
  }
  return config(signers)
}

/**
 * Extract networks as deployments are needed
 *
 * NOTE: Add networks as needed
 */
export type DeployableNetworks = Extract<Network, 'bsc' | 'polygon'>

/**
 * Deployment Variables for each network
 *
 * NOTE: Update variables as needed
 */
interface DeploymentVariables {
  goldenBananaTreasury: string
  wNative: string
}

const deployableNetworkConfig: Record<DeployableNetworks, (signers?: SignerWithAddress[]) => DeploymentVariables> = {
  bsc: (signers?: SignerWithAddress[]) => {
    return {
      goldenBananaTreasury: '0xec4b9d1fd8A3534E31fcE1636c7479BcD29213aE',
      wNative: '0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c',
    }
  },
  polygon: (signers?: SignerWithAddress[]) => {
    return {
      goldenBananaTreasury: '0x0000000000000000000000000000000000000000',
      wNative: '0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270',
    }
  },
}
