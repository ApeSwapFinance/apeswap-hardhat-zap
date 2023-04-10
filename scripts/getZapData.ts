import { ethers } from 'hardhat'
import { BigNumber, BytesLike } from 'ethers'
import { ether } from '@ape.swap/hardhat-test-helpers/dist/src/utils'

/// ADDRESSES FOR POLYGON

const zapAddress = '0xA35b2c2bAA77F213ECF6eAa02e734Cfe9480ba55'
const routerAddress = '0x98CB749270aBF8002E8B52CF65e0B0e0b0532071'
const APEV2 = '0xC0788A3aD43d79aa53B09c2EaCc313A787d1d607'
const QUICKV2 = '0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff'
const APEV3 = '0x7Bc382DdC5928964D7af60e7e2f6299A1eA6F48d'
const APEPosManager = '0x0927a5abbD02eD73ba83fC93Bd9900B1C2E52348'
const UNIV3 = '0x1F98431c8aD98523631AE4a59f267346ea31F984'
const UNIPosManager = '0xC36442b4a4522E871399CD717aBDD847Ab11FE88'
const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000'

const WMATIC = '0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270'
const DAI = '0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063'
const WETH = '0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619'
const BANANA = '0x5d47bAbA0d66083C52009271faF3F50DCc01023C'
const USDT = '0xc2132D05D31c914a87C6611C10748AEb04B58e8F'
const USDC = '0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174'

let router
let zapContract

async function main() {
  const ApeSwapZapFullV5 = await ethers.getContractFactory('ApeSwapZapFullV5')
  zapContract = ApeSwapZapFullV5.attach(zapAddress)
  router = await ethers.getContractAt('IApeSwapMultiSwapRouter', routerAddress)

  const swapPath00 = {
    swapRouter: QUICKV2,
    swapType: SwapType.V2,
    path: [WMATIC, USDT],
    uniV3PoolFees: [],
  }

  const swapPath01 = {
    swapRouter: QUICKV2,
    swapType: SwapType.V2,
    path: [USDT, USDC],
    uniV3PoolFees: [],
  }

  const swapPath10 = {
    swapRouter: APEV2,
    swapType: SwapType.V2,
    path: [WMATIC, WETH],
    uniV3PoolFees: [],
  }

  const swapPath11 = {
    swapRouter: APEV2,
    swapType: SwapType.V2,
    path: [WETH, BANANA],
    uniV3PoolFees: [],
  }

  const liquidityPath = {
    lpRouter: APEV2,
    liquidityType: LPType.V2,
    tickLower: -276240,
    tickUpper: -272220,
    uniV3PoolLPFee: 3000,
    arrakisFactory: ZERO_ADDRESS,
  }

  const minAmountsParams = {
    inputAmount: ether('0.01').toString(),
    path0: [swapPath00, swapPath01],
    path1: [swapPath10, swapPath11],
    liquidityPath: liquidityPath,
  }

  const liquidityAdder = APEV2
  const nativeZap = true

  console.log(JSON.stringify(minAmountsParams))
  const minAmountsData = await zapContract.estimateSwapReturns(minAmountsParams)
  console.log(minAmountsData)
  const populatedTx = await getZapData(
    nativeZap,
    minAmountsParams,
    minAmountsData,
    zapContract.address,
    liquidityAdder,
    '0x5c7C7246bD8a18DF5f6Ee422f9F8CCDF716A6aD2'
  )
  console.log('multicall data:')
  console.log(populatedTx)
  await zapContract.multicall(populatedTx, {
    value: nativeZap ? minAmountsParams.inputAmount : '0',
    gasPrice: 150000000000,
  })
  console.log('DONE')
}

const SwapType = {
  V2: 0,
  V3: 1,
}

const LPType = {
  V2: 0,
  V3: 1,
  Arrakis: 2,
}

async function getZapData(
  nativeZap: boolean,
  minAmountsParams: any,
  minAmountsData: any,
  zapTo: string,
  liquidityAdder: string,
  LPTo: string
): Promise<BytesLike[]> {
  let token0 =
    minAmountsParams.path0.length == 0
      ? minAmountsParams.path1[0].path[0]
      : minAmountsParams.path0[minAmountsParams.path0.length - 1].path[
          minAmountsParams.path0[minAmountsParams.path0.length - 1].path.length - 1
        ]
  let token1 =
    minAmountsParams.path1.length == 0
      ? minAmountsParams.path0[0].path[0]
      : minAmountsParams.path1[minAmountsParams.path1.length - 1].path[
          minAmountsParams.path1[minAmountsParams.path1.length - 1].path.length - 1
        ]

  if (token0 > token1) {
    throw Error('Tokens in path not in right order. please swap paths so output tokens are in order by address')
  }

  const ret: any[] = []
  let inputAmount = minAmountsParams.inputAmount
  console.log('wrap')
  if (nativeZap) {
    ret.push(await getWrapData(inputAmount))
    inputAmount = 0
  }
  console.log('zap')
  if (minAmountsParams.path0.length >= 1 || minAmountsParams.path1.length >= 1) {
    const swap = await getSwapData(minAmountsParams, inputAmount, minAmountsData, zapTo)
    ret.push(swap)
  }
  console.log('liquidity')
  ret.push(
    await getLPData(
      liquidityAdder,
      minAmountsParams.liquidityPath.liquidityType,
      token0,
      token1,
      0,
      0,
      LPTo,
      minAmountsParams.liquidityPath.uniV3PoolLPFee,
      minAmountsParams.liquidityPath.tickLower,
      minAmountsParams.liquidityPath.tickUpper
    )
  )
  return ret
}

async function getWrapData(inputAmount: number) {
  const maxNative = 1
  if (BigNumber.from(inputAmount) > ether(maxNative.toString())) {
    throw Error('SafeNet. Sending too much native for testing. limit set at: ' + maxNative.toString())
  }
  const populatedTx = await zapContract.populateTransaction.wrapNative(inputAmount, { value: inputAmount })
  return populatedTx.data
}

async function getSwapData(
  minAmountsParams: any,
  inputAmount: number,
  minAmountsData: any,
  lastTo: string
): Promise<BytesLike> {
  const inputToken =
    minAmountsParams.path0.length > 0 ? minAmountsParams.path0[0].path[0] : minAmountsParams.path1[0].path[0]

  const fullSwapData: any[] = []

  let to = router.address
  for (let n = 0; n < 2; n++) {
    to = router.address
    console.log('zap', n)
    const fullPath = n == 0 ? minAmountsParams.path0 : minAmountsParams.path1
    if (fullPath.length == 0) continue
    let swapAmount = n == 0 ? minAmountsData.swapToToken0 : minAmountsData.swapToToken1
    for (let i = 0; i < fullPath.length; i++) {
      if (i == fullPath.length - 1) {
        to = lastTo
      }
      const path = fullPath[i]
      let swapPopulatedTx: any = ''
      if (path.swapType == SwapType.V2) {
        swapPopulatedTx = await router.populateTransaction.swapExactTokensForTokens(
          path.swapRouter,
          swapAmount,
          0,
          path.path,
          to
        )
      } else if (path.swapType == SwapType.V3) {
        const bytesPath = pathToBytesPath(path.path, path.uniV3PoolFees)
        const ExactInput = {
          factory: path.swapRouter,
          path: bytesPath,
          recipient: to,
          amountIn: swapAmount,
          amountOutMinimum: 0,
        }
        swapPopulatedTx = await router.populateTransaction.exactInput(ExactInput)
      }

      fullSwapData.push(swapPopulatedTx.data)
      swapAmount = 0
    }
  }
  const swapParams = {
    inputToken: inputToken,
    inputAmount: inputAmount,
    swapType: 0,
    caller: router.address,
    swapData: fullSwapData,
    to: to,
    deadline: '9999999999',
  }
  const populatedTx = await zapContract.populateTransaction.swap(swapParams)
  if (ethers.utils.isBytesLike(populatedTx.data)) {
    return populatedTx.data
  }
  return '0x'
}

function pathToBytesPath(path: string[], fees: number[]) {
  let retString = '0x'
  for (let index = 0; index < path.length; index++) {
    const feeHex = fees.length > index ? ethers.utils.hexlify(fees[index]).substring(2) : ''
    let zeros = ''
    for (let i = 0; i < 6 - feeHex.length; i++) {
      zeros += '0'
    }
    retString += path[index].substring(2) + zeros + feeHex
  }
  return retString.slice(0, -6)
}

async function getLPData(
  liquidityAdder: string,
  lptype: number,
  token0: string,
  token1: string,
  amount0: any,
  amount1: any,
  to: string,
  fee: any = 0,
  tickLower: any = 0,
  tickUpper: any = 0
): Promise<BytesLike> {
  if (lptype == LPType.V2) {
    const params = {
      lpRouter: liquidityAdder,
      token0: token0,
      token1: token1,
      amount0Desired: amount0,
      amount1Desired: amount1,
      amount0Min: '0',
      amount1Min: '0',
      recipient: to,
      deadline: '9999999999',
    }
    const populatedTx = await zapContract.populateTransaction.addLiquidityV2(params)
    if (ethers.utils.isBytesLike(populatedTx.data)) {
      return populatedTx.data
    }
    return '0x'
  } else if (lptype == LPType.V3) {
    const params = {
      lpRouter: liquidityAdder,
      token0: token0,
      token1: token1,
      fee: fee,
      tickLower: tickLower,
      tickUpper: tickUpper,
      amount0Desired: amount0,
      amount1Desired: amount1,
      amount0Min: '0',
      amount1Min: '0',
      recipient: to,
      deadline: '9999999999',
    }
    const populatedTx = await zapContract.populateTransaction.addLiquidityV3(params)
    if (ethers.utils.isBytesLike(populatedTx.data)) {
      return populatedTx.data
    }
    return '0x'
  }
  return '0x'
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
