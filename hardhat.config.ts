import { HardhatUserConfig } from 'hardhat/config'
import '@nomicfoundation/hardhat-toolbox'
import 'solidity-coverage'
import 'hardhat-docgen'
import 'hardhat-contract-sizer'

import { task, types } from 'hardhat/config'
import { TASK_TEST } from 'hardhat/builtin-tasks/task-names'
import { HardhatRuntimeEnvironment, HttpNetworkUserConfig, NetworkUserConfig, SolcUserConfig } from 'hardhat/types'

import { Task, Verifier, Network } from './hardhat'
import { getEnv, Logger, logger, testRunner } from './hardhat/utils'
import solhintConfig from './solhint.config'
import '@openzeppelin/hardhat-upgrades'
import '@nomiclabs/hardhat-etherscan'

task('print-tasks', '🫶 Prints available tasks in tasks/ directory').setAction(async (args: { verbose?: boolean }) => {
  Logger.setDefaults(false, args.verbose || false)
  logger.log(
    `Use the following tasks in a variety of ways \nnpx hardhat deploy --id <task-id> --network <network-name> \nnpx hardhat verify-contract --id <task-id> --network <network-name> --name <contract-name> \n`,
    `🫶`
  )
  Task.printAllTask()
})

/**
 * Example of accessing ethers and performing Web3 calls inside a task
 * task action function receives the Hardhat Runtime Environment as second argument
 *
 * Docs regarding hardhat helper functions added to ethers object:
 * https://github.com/NomicFoundation/hardhat/tree/master/packages/hardhat-ethers#helpers
 */
task('blockNumber', '🫶 Prints the current block number', async (_, hre: HardhatRuntimeEnvironment) => {
  // A provider field is added to ethers, which is an
  //   ethers.providers.Provider automatically connected to the selected network
  await hre.ethers.provider.getBlockNumber().then((blockNumber) => {
    console.log('Current block number: ' + blockNumber)
  })
})

/**
 * Provide additional fork testing options
 *
 * eg: `npx hardhat test --fork <network-name> --blockNumber <block-number>`
 */
task(TASK_TEST, '🫶 Test Task')
  .addOptionalParam('fork', 'Optional network name to be forked block number to fork in case of running fork tests.')
  .addOptionalParam('blockNumber', 'Optional block number to fork in case of running fork tests.', undefined, types.int)
  .setAction(testRunner)

export const mainnetMnemonic = getEnv('MAINNET_MNEMONIC')
export const testnetMnemonic = getEnv('TESTNET_MNEMONIC')

interface NetworkUserConfigExtended extends HttpNetworkUserConfig {
  getExplorerUrl: (address: string) => string
}

const networkConfig: Record<Network, NetworkUserConfigExtended> = {
  mainnet: {
    url: getEnv('MAINNET_RPC_URL') || '',
    getExplorerUrl: (address: string) => `https://etherscan.io/address/${address}`,
    chainId: 1,
    accounts: {
      mnemonic: mainnetMnemonic,
    },
  },
  goerli: {
    url: getEnv('GOERLI_RPC_URL') || '',
    getExplorerUrl: (address: string) => `https://goerli.etherscan.io/address/${address}`,
    chainId: 5,
    accounts: {
      mnemonic: testnetMnemonic,
    },
  },
  arbitrum: {
    url: getEnv('ARBITRUM_RPC_URL') || '',
    getExplorerUrl: (address: string) => `https://arbiscan.io/address/${address}`,
    chainId: 42161,
    accounts: {
      mnemonic: mainnetMnemonic,
    },
  },
  arbitrumGoerli: {
    url: getEnv('ARBITRUM_GOERLI_RPC_URL') || '',
    getExplorerUrl: (address: string) => `https://testnet.arbiscan.io/address/${address}`,
    chainId: 421613,
    accounts: {
      mnemonic: testnetMnemonic,
    },
  },
  bsc: {
    url: getEnv('BSC_RPC_URL') || 'https://bsc-dataseed1.binance.org',
    getExplorerUrl: (address: string) => `https://bscscan.com/address/${address}`,
    chainId: 56,
    accounts: {
      mnemonic: mainnetMnemonic,
    },
  },
  bscDummy: {
    url: getEnv('BSC_RPC_URL') || 'https://bsc-dataseed1.binance.org',
    getExplorerUrl: (address: string) => `https://bscscan.com/address/${address}`,
    chainId: 56,
    accounts: {
      mnemonic: mainnetMnemonic,
    },
  },
  bscTestnet: {
    url: getEnv('BSC_TESTNET_RPC_URL') || 'https://data-seed-prebsc-1-s1.binance.org:8545',
    getExplorerUrl: (address: string) => `https://testnet.bscscan.com/address/${address}`,
    chainId: 97,
    accounts: {
      mnemonic: testnetMnemonic,
    },
  },
  polygon: {
    url: getEnv('POLYGON_RPC_URL') || 'https://matic-mainnet.chainstacklabs.com',
    getExplorerUrl: (address: string) => `https://polygonscan.com/address/${address}`,
    chainId: 137,
    accounts: {
      mnemonic: mainnetMnemonic,
    },
  },
  polygonTestnet: {
    url: getEnv('POLYGON_TESTNET_RPC_URL') || 'https://rpc-mumbai.maticvigil.com/',
    getExplorerUrl: (address: string) => `https://mumbai.polygonscan.com/address/${address}`,
    chainId: 80001,
    accounts: {
      mnemonic: testnetMnemonic,
    },
  },
  telos: {
    url: getEnv('TELOS_RPC_URL') || 'https://mainnet.telos.net/evm',
    getExplorerUrl: (address: string) => `https://www.teloscan.io/address/${address}`,
    chainId: 40,
    accounts: {
      mnemonic: testnetMnemonic,
    },
  },
  telosTestnet: {
    url: getEnv('TELOS_TESTNET_RPC_URL') || 'https://testnet.telos.net/evm',
    getExplorerUrl: (address: string) => `https://testnet.teloscan.io/address/${address}`,
    chainId: 41,
    accounts: {
      mnemonic: testnetMnemonic,
    },
  },
  // Placeholder for the configuration below.
  hardhat: {
    getExplorerUrl: (address: string) => `(NO DEV EXPLORER): ${address}`,
  },
}

/**
 * Configure compiler versions in ./solhint.config.js
 *
 * @returns SolcUserConfig[]
 */
function getSolcUserConfig(): SolcUserConfig[] {
  return (solhintConfig.rules['compiler-version'][2] as string[]).map((compiler) => {
    return {
      // Adding multiple compiler versions
      // https://hardhat.org/hardhat-runner/docs/advanced/multiple-solidity-versions#multiple-solidity-versions
      version: compiler,
      settings: {
        optimizer: {
          enabled: true,
          runs: 1000,
        },
      },
    }
  })
}

const config: HardhatUserConfig = {
  solidity: { compilers: getSolcUserConfig() },
  networks: {
    ...networkConfig,
    hardhat: {
      gas: 'auto',
      gasPrice: 'auto',
    },
  },
  gasReporter: {
    // More options can be found here:
    // https://www.npmjs.com/package/hardhat-gas-reporter
    enabled: getEnv('REPORT_GAS') ? true : false,
    currency: 'USD',
    excludeContracts: [],
  },
  docgen: {
    path: './docs',
    clear: true,
    runOnCompile: true,
  },
  typechain: {
    // outDir: 'src/types', // defaults to './typechain-types/'
    target: 'ethers-v5',
    externalArtifacts: ['./contracts/extensions/bills/lib/**.json'], // optional array of glob patterns with external artifacts to process (for example external libs from node_modules)
    alwaysGenerateOverloads: false, // should overloads with full signatures like deposit(uint256) be generated always, even if there are no overloads?
    dontOverrideCompile: false, // defaults to false
  },
  contractSizer: {
    // https://github.com/ItsNickBarry/hardhat-contract-sizer#usage
    alphaSort: false, // whether to sort results table alphabetically (default sort is by contract size)
    disambiguatePaths: false, // whether to output the full path to the compilation artifact (relative to the Hardhat root directory)
    runOnCompile: false, // whether to output contract sizes automatically after compilation
    strict: false, // whether to throw an error if any contracts exceed the size limit
    // only: [':ERC20$'], // Array of String matchers used to include contracts
    // except: [':ERC20$'], // Array of String matchers used to exclude contracts
    // outputFile: './contract-size.md', // Optional output file to write to
  },
  // https://github.com/NomicFoundation/hardhat/tree/main/packages/hardhat-etherscan
  etherscan: {
    apiKey: {
      mainnet: getEnv('ETHERSCAN_API_KEY'),
      optimisticEthereum: getEnv('OPTIMISTIC_ETHERSCAN_API_KEY'),
      arbitrumOne: getEnv('ARBISCAN_API_KEY'),
      bsc: getEnv('BSCSCAN_API_KEY'),
      bscTestnet: getEnv('BSCSCAN_API_KEY'),
      polygon: getEnv('POLYGONSCAN_API_KEY'),
      polygonMumbai: getEnv('POLYGONSCAN_API_KEY'),
    },
  },
}

export default config
