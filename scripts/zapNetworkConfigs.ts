import { Network } from '../hardhat/types'
import { ADDRESS_ZERO } from '../test/utils/constants'

/**
 * Using `Extract<Type, Union>` to pull out networks which are configured here.
 * Add more networks as configurations are added.
 * https://www.typescriptlang.org/docs/handbook/utility-types.html?#extracttype-union
 */
// NOTE: Adding networks which have contracts deployed
export type DeployedNetworks = Extract<
  Network,
  'bsc' | 'bscDummy' /*| 'bsc-testnet' | 'polygon' | 'arbitrum' | 'arbitrum-dummy' | 'telos'*/
>

export interface ContractConfig {
  zapV1: string
  accountIndex?: number
}

export const deployedContractConfigs: Record<DeployedNetworks, ContractConfig> = {
  bsc: {
    zapV1: '0x',
    accountIndex: 2,
  },
  bscDummy: {
    zapV1: '0xAf137915633D80f3D1c5efB2Bde108B1B4Ea5EC2',
    accountIndex: 2,
  },
  /*
  'bsc-testnet': {
    zapV1: 
  },
  polygon: {
    zapV1: 
  },
  arbitrum: {
    zapV1: 
  },
  'arbitrum-dummy': {
    zapV1: 
  },
  telos: {
    zapV1: 
  },
  */
}
