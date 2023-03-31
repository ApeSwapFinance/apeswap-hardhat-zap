import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
import { Network } from './hardhat/types'

/**
 * Using `Extract<Type, Union>` to pull out networks which are configured here.
 * Add more networks as configurations are added.
 * https://www.typescriptlang.org/docs/handbook/utility-types.html?#extracttype-union
 */
// NOTE: Adding networks which have contracts deployed
export type DeployedNetworks = Extract<Network, 'bsc' | 'bscTestnet' | 'polygon' | 'arbitrum' | 'telos'>

// Contract deployment interface
export interface ZapDeployConfig {
  zapArtifact: string
  apeRouterAddress: string
  goldenBananaTreasury: string
  maximizerVaultApe: string
  stakingContracts: string[]
  factoryContracts: string[] // For LPBalance Checker
}

/**
 * Get the deploy config for a given network
 * @param network
 * @returns
 */
// TODO: Consider implementing signers?
export const getDeployConfig = (network: Network, signers?: SignerWithAddress[]): ZapDeployConfig => {
  const config = contractDeployConfigs[network]
  if (!config) {
    throw new Error(`No deploy config for network ${network}`)
  }
  return config
}

const contractDeployConfigs: Record<DeployedNetworks, ZapDeployConfig> = {
  bsc: {
    // zapArtifact: 'ApeSwapZapBSCV1',
    zapArtifact: 'ApeSwapZapBSC_Lend_MAV2',
    apeRouterAddress: '0xcF0feBd3f17CEf5b47b0cD257aCf6025c5BFf3b7',
    goldenBananaTreasury: '0xec4b9d1fd8A3534E31fcE1636c7479BcD29213aE',
    maximizerVaultApe: '',
    stakingContracts: ['0xa5f8C5Dbd5F286960b9d90548680aE5ebFf07652', '0xDbc1A13490deeF9c3C12b44FE77b503c1B061739'],
    factoryContracts: ['0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73', '0x858E3312ed3A876947EA49d572A7C42DE08af7EE'],
  },
  bscTestnet: {
    zapArtifact: 'ApeSwapZapFullV3',
    apeRouterAddress: '0x3380aE82e39E42Ca34EbEd69aF67fAa0683Bb5c1',
    goldenBananaTreasury: '0xbC5ed0829365a0d5bc3A4956A6A0549aE17f41Ab',
    maximizerVaultApe: '0x14993D833C38eCfD3575cD32613460d0f998caAf',
    stakingContracts: ['0xbbC5e1cD3BA8ED639b00927115e5f0e0040aA613'],
    factoryContracts: [],
  },
  polygon: {
    zapArtifact: 'ApeSwapZapFullV3',
    apeRouterAddress: '0xC0788A3aD43d79aa53B09c2EaCc313A787d1d607',
    goldenBananaTreasury: '0xbC5ed0829365a0d5bc3A4956A6A0549aE17f41Ab',
    maximizerVaultApe: '0x',
    stakingContracts: ['0x8aAA5e259F74c8114e0a471d9f2ADFc66Bfe09ed', '0x9Dd12421C637689c3Fc6e661C9e2f02C2F61b3Eb'],
    factoryContracts: [],
  },
  arbitrum: {
    zapArtifact: 'ApeSwapZapArbitrumV1',
    apeRouterAddress: '0x7d13268144adcdbEBDf94F654085CC15502849Ff',
    goldenBananaTreasury: '0x',
    maximizerVaultApe: '0x',
    stakingContracts: [],
    factoryContracts: [],
  },
  telos: {
    zapArtifact: 'ApeSwapZapFullV3',
    apeRouterAddress: '0xb9667Cf9A495A123b0C43B924f6c2244f42817BE',
    goldenBananaTreasury: '0xbC5ed0829365a0d5bc3A4956A6A0549aE17f41Ab',
    maximizerVaultApe: '0x',
    stakingContracts: [],
    factoryContracts: [],
  },
}
