import hre, { ethers } from 'hardhat'
import { DeployedNetworks, deployedContractConfigs } from '../zapNetworkConfigs'
import { ApeSwapZapExtendedV0 } from '../../typechain-types'
import erc20ABI from './erc20.json'
import { BigNumber } from 'ethers'

const maxUint = BigNumber.from(2).pow(256).sub(1)

const zapConfig = {
  // inputToken: 'BANANA',
  inputToken: '0x603c7f932ED1fc6575303D8Fb018fDCBb0f39a95',
  // inputAmount: https://bscscan.com/unitconverter/?wei=1000000000000000,
  // inputAmount: https://bscscan.com/unitconverter/?wei=100000000000000000,
  inputAmount: '100000000000000000',
  path: ['0x603c7f932ED1fc6575303D8Fb018fDCBb0f39a95', '0x55d398326f99059fF775485246999027B3197955'],
  minAmountsSwap: '0',
  deadline: '99999999999',
  market: '0xdBFd516D42743CA3f1C555311F7846095D85F6Fd',
  bill: '0xFC5556542649E76f1D1E2C93221F6066B23AF38D',
  maxPrice: maxUint,
}

async function main() {
  const currentNetwork = hre.network.name as DeployedNetworks
  const { zapV1, accountIndex } = deployedContractConfigs[currentNetwork]
  // NOTE: Passing optional accountIndex to getSigners() to use a different account
  const signer = (await ethers.getSigners())[accountIndex || 0]
  console.log(`Using account: ${signer.address}`)

  const deployedZap = (await ethers.getContractAt('ApeSwapZapExtendedV0', zapV1)) as ApeSwapZapExtendedV0
  const inputToken = await ethers.getContractAt(erc20ABI, zapConfig.inputToken)
  const balanceOf = await inputToken.balanceOf(signer.address)
  if (balanceOf.lt(BigNumber.from(zapConfig.inputAmount))) {
    throw new Error(`Insufficient input token balance: ${balanceOf.toString()}`)
  }
  await inputToken.connect(signer).approve(deployedZap.address, zapConfig.inputAmount)

  const tx = await deployedZap
    .connect(signer)
    .zapLendingMarketTBill(
      zapConfig.inputToken,
      zapConfig.inputAmount,
      zapConfig.path,
      zapConfig.minAmountsSwap,
      zapConfig.deadline,
      zapConfig.market,
      zapConfig.bill,
      zapConfig.maxPrice
    )
  await tx.wait()
}

main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
