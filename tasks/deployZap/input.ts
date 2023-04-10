import { Address } from 'cluster'
import { Network } from '../../hardhat'

export type DeploymentInputs = {
  WNATIVE: string
  GNANATreasury: string
}

const DEFAULT_UNLOCK = 100

const deploymentInputs: Record<Network, DeploymentInputs> = {
  mainnet: {
    WNATIVE: '',
    GNANATreasury: '0x0000000000000000000000000000000000000000',
  },
  bsc: {
    WNATIVE: '0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c',
    GNANATreasury: '0xec4b9d1fd8A3534E31fcE1636c7479BcD29213aE',
  },
  bscTestnet: {
    WNATIVE: '',
    GNANATreasury: '0x0000000000000000000000000000000000000000',
  },
  polygon: {
    WNATIVE: '0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270',
    GNANATreasury: '0x0000000000000000000000000000000000000000',
  },
  polygonTestnet: {
    WNATIVE: '',
    GNANATreasury: '0x0000000000000000000000000000000000000000',
  },
  hardhat: {
    WNATIVE: '',
    GNANATreasury: '0x0000000000000000000000000000000000000000',
  },
  arbitrum: { WNATIVE: '', GNANATreasury: '0x0000000000000000000000000000000000000000' },
  arbitrumGoerli: { WNATIVE: '', GNANATreasury: '0x0000000000000000000000000000000000000000' },
  goerli: { WNATIVE: '', GNANATreasury: '0x0000000000000000000000000000000000000000' },
  telos: { WNATIVE: '', GNANATreasury: '0x0000000000000000000000000000000000000000' },
  telosTestnet: { WNATIVE: '', GNANATreasury: '0x0000000000000000000000000000000000000000' },
}

export default deploymentInputs
