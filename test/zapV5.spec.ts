import { expect } from 'chai'
import {
  dex,
  dexV3,
  dexV2AndV3,
  utils,
  SwapRouter02,
  NonfungiblePositionManager__factory,
} from '@ape.swap/hardhat-test-helpers'
import { mine, time, loadFixture } from '@nomicfoundation/hardhat-network-helpers'
import '@nomicfoundation/hardhat-chai-matchers'
import { ethers } from 'hardhat'
import { ADDRESS_ZERO } from './utils/constants'
import { StringDecoder } from 'string_decoder'
import { Address } from 'cluster'
import { BigNumber, Bytes, BytesLike } from 'ethers'

const ether = utils.ether
describe('ZapV5', function () {
  const SwapType = {
    V2: 0,
    V3: 1,
  }

  const LPType = {
    V2: 0,
    V3: 1,
    Arrakis: 2,
  }

  async function deployDexAndZap() {
    const ApeSwapZap__factory = await ethers.getContractFactory('ApeSwapZapFullV5')
    const Treasury__factory = await ethers.getContractFactory('Treasury')

    const [owner, feeTo, alice] = await ethers.getSigners()

    const { DEXV2, DEXV3, router, mockTokens, mockWBNB } = await dexV2AndV3.deployDexesAndRouter(
      ethers,
      [owner, feeTo, alice],
      5
    )

    const banana = mockTokens[0]
    const bitcoin = mockTokens[1]
    const ethereum = mockTokens[2]
    const busd = mockTokens[3]
    const gnana = mockTokens[4]

    await banana.mint(ether('4000'))
    await bitcoin.mint(ether('4000'))
    await ethereum.mint(ether('4000'))
    await busd.mint(ether('4000'))
    await banana.connect(alice).mint(ether('1000'))
    await bitcoin.connect(alice).mint(ether('1000'))
    await ethereum.connect(alice).mint(ether('1000'))
    await busd.connect(alice).mint(ether('1000'))

    await banana.approve(DEXV2.dexRouter.address, ether('3000'))
    await bitcoin.approve(DEXV2.dexRouter.address, ether('3000'))
    await ethereum.approve(DEXV2.dexRouter.address, ether('3000'))
    await busd.approve(DEXV2.dexRouter.address, ether('3000'))
    await banana.approve(DEXV3.positionManager.address, ether('3000'))
    await bitcoin.approve(DEXV3.positionManager.address, ether('3000'))
    await ethereum.approve(DEXV3.positionManager.address, ether('3000'))
    await busd.approve(DEXV3.positionManager.address, ether('3000'))

    await DEXV2.dexRouter.addLiquidity(
      banana.address,
      bitcoin.address,
      ether('1000'),
      ether('1000'),
      0,
      0,
      owner.address,
      '9999999999'
    )
    await DEXV2.dexRouter.addLiquidity(
      banana.address,
      ethereum.address,
      ether('1000'),
      ether('1000'),
      0,
      0,
      owner.address,
      '9999999999'
    )
    await DEXV2.dexRouter.addLiquidity(
      bitcoin.address,
      ethereum.address,
      ether('1000'),
      ether('1000'),
      0,
      0,
      owner.address,
      '9999999999'
    )
    await DEXV2.dexRouter.addLiquidity(
      banana.address,
      busd.address,
      ether('1000'),
      ether('1000'),
      0,
      0,
      owner.address,
      '9999999999'
    )
    await DEXV2.dexRouter.addLiquidity(
      bitcoin.address,
      busd.address,
      ether('1000'),
      ether('1000'),
      0,
      0,
      owner.address,
      '9999999999'
    )
    await DEXV2.dexRouter.addLiquidity(
      ethereum.address,
      busd.address,
      ether('1000'),
      ether('1000'),
      0,
      0,
      owner.address,
      '9999999999'
    )
    const v3MintData = {
      fee: 500,
      tickLower: -887270,
      tickUpper: 887270,
      amount0Desired: ether('1000'),
      amount1Desired: ether('1000'),
      amount0Min: 0,
      amount1Min: 0,
      recipient: owner.address,
      deadline: '9999999999',
    }
    const price = '79228163000000000000000000000' //1 tokenA = 1 tokenB approx
    mintV3Position(DEXV3, v3MintData, banana.address, bitcoin.address, price)
    mintV3Position(DEXV3, v3MintData, banana.address, ethereum.address, price)
    mintV3Position(DEXV3, v3MintData, banana.address, busd.address, price)
    mintV3Position(DEXV3, v3MintData, bitcoin.address, ethereum.address, price)
    mintV3Position(DEXV3, v3MintData, bitcoin.address, busd.address, price)
    mintV3Position(DEXV3, v3MintData, ethereum.address, busd.address, price)

    const zapContract = await ApeSwapZap__factory.deploy(DEXV2.mockWBNB.address, ADDRESS_ZERO)

    await banana.connect(alice).approve(zapContract.address, ether('1000'))
    await bitcoin.connect(alice).approve(zapContract.address, ether('1000'))
    await ethereum.connect(alice).approve(zapContract.address, ether('1000'))
    await busd.connect(alice).approve(zapContract.address, ether('1000'))

    console.log('banana', banana.address)
    console.log('bitcoin', bitcoin.address)
    console.log('ethereum', ethereum.address)
    console.log('busd', busd.address)

    return {
      zapContract,
      DEXV2,
      DEXV3,
      router,
      mockWBNB: DEXV2.mockWBNB,
      banana,
      bitcoin,
      ethereum,
      busd,
      gnana,
      signers: { owner, feeTo, alice },
      factories: {},
    }
  }

  async function mintV3Position(DEXV3: any, v3MintData: any, token0: String, token1: String, price: string) {
    if (token1 < token0) {
      const tempToken = token0
      token0 = token1
      token1 = tempToken
    }
    await DEXV3.positionManager.createAndInitializePoolIfNecessary(token0, token1, v3MintData.fee, price)
    await DEXV3.positionManager.mint({ ...v3MintData, token0, token1 })
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
    if (nativeZap) {
      ret.push(await getWrapData(inputAmount))
      inputAmount = 0
    }
    if (minAmountsParams.path0.length >= 1 || minAmountsParams.path1.length >= 1) {
      const swap = await getSwapData(minAmountsParams, inputAmount, minAmountsData, zapTo)
      ret.push(swap)
    }
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
    const { zapContract, router } = await loadFixture(deployDexAndZap)
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
    const { zapContract, router } = await loadFixture(deployDexAndZap)

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
        console.log(path)
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
    const { zapContract } = await loadFixture(deployDexAndZap)
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

  describe('All kind of swaps. simple V2 LP', function () {
    it('V2 - Nothing', async () => {
      const {
        zapContract,
        DEXV2,
        DEXV3,
        router,
        mockWBNB,
        banana,
        bitcoin,
        ethereum,
        busd,
        gnana,
        signers,
        factories,
      } = await loadFixture(deployDexAndZap)

      const lp = await DEXV2.dexFactory.getPair(banana.address, bitcoin.address)
      const lpContract = await ethers.getContractAt('IApePair', lp)
      const balanceBefore = await lpContract.balanceOf(signers.alice.address)

      const swapPath0 = {
        swapRouter: DEXV2.dexRouter.address,
        swapType: SwapType.V2,
        path: [],
        uniV3PoolFees: [],
      }

      const swapPath1 = {
        swapRouter: DEXV2.dexRouter.address,
        swapType: SwapType.V2,
        path: [banana.address, bitcoin.address],
        uniV3PoolFees: [],
      }

      const liquidityPath = {
        lpRouter: DEXV2.dexRouter.address,
        liquidityType: LPType.V2,
        tickLower: 0,
        tickUpper: 0,
        uniV3PoolLPFee: 0,
        arrakisFactory: ADDRESS_ZERO,
      }

      const minAmountsParams = {
        inputAmount: ether('1').toString(),
        path0: [],
        path1: [swapPath1],
        liquidityPath: liquidityPath,
      }

      const liquidityAdder = DEXV2.dexRouter.address
      const nativeZap = false

      const minAmountsData = await zapContract.connect(signers.alice).estimateSwapReturns(minAmountsParams)
      const populatedTx = await getZapData(
        nativeZap,
        minAmountsParams,
        minAmountsData,
        zapContract.address,
        liquidityAdder,
        signers.alice.address
      )
      await zapContract
        .connect(signers.alice)
        .multicall(populatedTx, { value: nativeZap ? minAmountsParams.inputAmount : 0 })

      const balanceAfter = await lpContract.balanceOf(signers.alice.address)
      expect(Number(balanceAfter)).gt(Number(balanceBefore))
    })

    it('V2 - V2', async () => {
      const {
        zapContract,
        DEXV2,
        DEXV3,
        router,
        mockWBNB,
        banana,
        bitcoin,
        ethereum,
        busd,
        gnana,
        signers,
        factories,
      } = await loadFixture(deployDexAndZap)

      const lp = await DEXV2.dexFactory.getPair(ethereum.address, bitcoin.address)
      const lpContract = await ethers.getContractAt('IApePair', lp)
      const balanceBefore = await lpContract.balanceOf(signers.alice.address)

      const swapPath0 = {
        swapRouter: DEXV2.dexRouter.address,
        swapType: SwapType.V2,
        path: [banana.address, bitcoin.address],
        uniV3PoolFees: [],
      }

      const swapPath1 = {
        swapRouter: DEXV2.dexRouter.address,
        swapType: SwapType.V2,
        path: [banana.address, ethereum.address],
        uniV3PoolFees: [],
      }

      const liquidityPath = {
        lpRouter: DEXV2.dexRouter.address,
        liquidityType: LPType.V2,
        tickLower: 0,
        tickUpper: 0,
        uniV3PoolLPFee: 0,
        arrakisFactory: ADDRESS_ZERO,
      }

      const minAmountsParams = {
        inputAmount: ether('1').toString(),
        path0: [swapPath0],
        path1: [swapPath1],
        liquidityPath: liquidityPath,
      }

      const liquidityAdder = DEXV2.dexRouter.address
      const nativeZap = false

      const minAmountsData = await zapContract.connect(signers.alice).estimateSwapReturns(minAmountsParams)
      const populatedTx = await getZapData(
        nativeZap,
        minAmountsParams,
        minAmountsData,
        zapContract.address,
        liquidityAdder,
        signers.alice.address
      )
      await zapContract
        .connect(signers.alice)
        .multicall(populatedTx, { value: nativeZap ? minAmountsParams.inputAmount : 0 })

      const balanceAfter = await lpContract.balanceOf(signers.alice.address)
      expect(Number(balanceAfter)).gt(Number(balanceBefore))
    })

    it('V3 - V2', async () => {
      const {
        zapContract,
        DEXV2,
        DEXV3,
        router,
        mockWBNB,
        banana,
        bitcoin,
        ethereum,
        busd,
        gnana,
        signers,
        factories,
      } = await loadFixture(deployDexAndZap)

      const lp = await DEXV2.dexFactory.getPair(ethereum.address, bitcoin.address)
      const lpContract = await ethers.getContractAt('IApePair', lp)
      const balanceBefore = await lpContract.balanceOf(signers.alice.address)

      const swapPath0 = {
        swapRouter: DEXV3.dexFactory.address,
        swapType: SwapType.V3,
        path: [banana.address, bitcoin.address],
        uniV3PoolFees: [500],
      }

      const swapPath1 = {
        swapRouter: DEXV2.dexRouter.address,
        swapType: SwapType.V2,
        path: [banana.address, ethereum.address],
        uniV3PoolFees: [],
      }

      const liquidityPath = {
        lpRouter: DEXV2.dexRouter.address,
        liquidityType: LPType.V2,
        tickLower: 0,
        tickUpper: 0,
        uniV3PoolLPFee: 0,
        arrakisFactory: ADDRESS_ZERO,
      }

      const minAmountsParams = {
        inputAmount: ether('1').toString(),
        path0: [swapPath0],
        path1: [swapPath1],
        liquidityPath: liquidityPath,
      }

      const liquidityAdder = DEXV2.dexRouter.address
      const nativeZap = false

      const minAmountsData = await zapContract.connect(signers.alice).estimateSwapReturns(minAmountsParams)
      const populatedTx = await getZapData(
        nativeZap,
        minAmountsParams,
        minAmountsData,
        zapContract.address,
        liquidityAdder,
        signers.alice.address
      )
      await zapContract
        .connect(signers.alice)
        .multicall(populatedTx, { value: nativeZap ? minAmountsParams.inputAmount : 0 })

      const balanceAfter = await lpContract.balanceOf(signers.alice.address)
      expect(Number(balanceAfter)).gt(Number(balanceBefore))
    })

    it('V3 - V3', async () => {
      const {
        zapContract,
        DEXV2,
        DEXV3,
        router,
        mockWBNB,
        banana,
        bitcoin,
        ethereum,
        busd,
        gnana,
        signers,
        factories,
      } = await loadFixture(deployDexAndZap)

      const lp = await DEXV2.dexFactory.getPair(ethereum.address, bitcoin.address)
      const lpContract = await ethers.getContractAt('IApePair', lp)
      const balanceBefore = await lpContract.balanceOf(signers.alice.address)

      const swapPath0 = {
        swapRouter: DEXV3.dexFactory.address,
        swapType: SwapType.V3,
        path: [banana.address, bitcoin.address],
        uniV3PoolFees: [500],
      }

      const swapPath1 = {
        swapRouter: DEXV3.dexFactory.address,
        swapType: SwapType.V3,
        path: [banana.address, ethereum.address],
        uniV3PoolFees: [500],
      }

      const liquidityPath = {
        lpRouter: DEXV2.dexRouter.address,
        liquidityType: LPType.V2,
        tickLower: 0,
        tickUpper: 0,
        uniV3PoolLPFee: 0,
        arrakisFactory: ADDRESS_ZERO,
      }

      const minAmountsParams = {
        inputAmount: ether('1').toString(),
        path0: [swapPath0],
        path1: [swapPath1],
        liquidityPath: liquidityPath,
      }

      const liquidityAdder = DEXV2.dexRouter.address
      const nativeZap = false

      const minAmountsData = await zapContract.connect(signers.alice).estimateSwapReturns(minAmountsParams)
      const populatedTx = await getZapData(
        nativeZap,
        minAmountsParams,
        minAmountsData,
        zapContract.address,
        liquidityAdder,
        signers.alice.address
      )
      await zapContract
        .connect(signers.alice)
        .multicall(populatedTx, { value: nativeZap ? minAmountsParams.inputAmount : 0 })

      const balanceAfter = await lpContract.balanceOf(signers.alice.address)
      expect(Number(balanceAfter)).gt(Number(balanceBefore))
    })

    it('V2 hops - V3 hops', async () => {
      const {
        zapContract,
        DEXV2,
        DEXV3,
        router,
        mockWBNB,
        banana,
        bitcoin,
        ethereum,
        busd,
        gnana,
        signers,
        factories,
      } = await loadFixture(deployDexAndZap)

      const lp = await DEXV2.dexFactory.getPair(ethereum.address, bitcoin.address)
      const lpContract = await ethers.getContractAt('IApePair', lp)
      const balanceBefore = await lpContract.balanceOf(signers.alice.address)

      const swapPath0 = {
        swapRouter: DEXV2.dexRouter.address,
        swapType: SwapType.V2,
        path: [banana.address, busd.address, bitcoin.address],
        uniV3PoolFees: [],
      }

      const swapPath1 = {
        swapRouter: DEXV3.dexFactory.address,
        swapType: SwapType.V3,
        path: [banana.address, busd.address, ethereum.address],
        uniV3PoolFees: [500, 500],
      }

      const liquidityPath = {
        lpRouter: DEXV2.dexRouter.address,
        liquidityType: LPType.V2,
        tickLower: 0,
        tickUpper: 0,
        uniV3PoolLPFee: 0,
        arrakisFactory: ADDRESS_ZERO,
      }

      const minAmountsParams = {
        inputAmount: ether('1').toString(),
        path0: [swapPath0],
        path1: [swapPath1],
        liquidityPath: liquidityPath,
      }

      const liquidityAdder = DEXV2.dexRouter.address
      const nativeZap = false

      const minAmountsData = await zapContract.connect(signers.alice).estimateSwapReturns(minAmountsParams)
      const populatedTx = await getZapData(
        nativeZap,
        minAmountsParams,
        minAmountsData,
        zapContract.address,
        liquidityAdder,
        signers.alice.address
      )
      await zapContract
        .connect(signers.alice)
        .multicall(populatedTx, { value: nativeZap ? minAmountsParams.inputAmount : 0 })

      const balanceAfter = await lpContract.balanceOf(signers.alice.address)
      expect(Number(balanceAfter)).gt(Number(balanceBefore))
    })

    it('V2+V3+V2 - V3 hops', async () => {
      const {
        zapContract,
        DEXV2,
        DEXV3,
        router,
        mockWBNB,
        banana,
        bitcoin,
        ethereum,
        busd,
        gnana,
        signers,
        factories,
      } = await loadFixture(deployDexAndZap)

      const lp = await DEXV2.dexFactory.getPair(ethereum.address, bitcoin.address)
      const lpContract = await ethers.getContractAt('IApePair', lp)
      const balanceBefore = await lpContract.balanceOf(signers.alice.address)

      const swapPath00 = {
        swapRouter: DEXV2.dexRouter.address,
        swapType: SwapType.V2,
        path: [banana.address, busd.address],
        uniV3PoolFees: [],
      }

      const swapPath01 = {
        swapRouter: DEXV3.dexFactory.address,
        swapType: SwapType.V3,
        path: [busd.address, ethereum.address],
        uniV3PoolFees: [500],
      }

      const swapPath02 = {
        swapRouter: DEXV2.dexRouter.address,
        swapType: SwapType.V2,
        path: [ethereum.address, bitcoin.address],
        uniV3PoolFees: [],
      }

      const swapPath10 = {
        swapRouter: DEXV3.dexFactory.address,
        swapType: SwapType.V3,
        path: [banana.address, busd.address, ethereum.address],
        uniV3PoolFees: [500, 500],
      }

      const liquidityPath = {
        lpRouter: DEXV2.dexRouter.address,
        liquidityType: LPType.V2,
        tickLower: 0,
        tickUpper: 0,
        uniV3PoolLPFee: 0,
        arrakisFactory: ADDRESS_ZERO,
      }

      const minAmountsParams = {
        inputAmount: ether('1').toString(),
        path0: [swapPath00, swapPath01, swapPath02],
        path1: [swapPath10],
        liquidityPath: liquidityPath,
      }

      const liquidityAdder = DEXV2.dexRouter.address
      const nativeZap = false

      const minAmountsData = await zapContract.connect(signers.alice).estimateSwapReturns(minAmountsParams)
      const populatedTx = await getZapData(
        nativeZap,
        minAmountsParams,
        minAmountsData,
        zapContract.address,
        liquidityAdder,
        signers.alice.address
      )
      await zapContract
        .connect(signers.alice)
        .multicall(populatedTx, { value: nativeZap ? minAmountsParams.inputAmount : 0 })

      const balanceAfter = await lpContract.balanceOf(signers.alice.address)
      expect(Number(balanceAfter)).gt(Number(balanceBefore))
    })

    it('V2+V3 - V2+V3', async () => {
      const {
        zapContract,
        DEXV2,
        DEXV3,
        router,
        mockWBNB,
        banana,
        bitcoin,
        ethereum,
        busd,
        gnana,
        signers,
        factories,
      } = await loadFixture(deployDexAndZap)

      const lp = await DEXV2.dexFactory.getPair(ethereum.address, bitcoin.address)
      const lpContract = await ethers.getContractAt('IApePair', lp)
      const balanceBefore = await lpContract.balanceOf(signers.alice.address)

      const swapPath00 = {
        swapRouter: DEXV2.dexRouter.address,
        swapType: SwapType.V2,
        path: [banana.address, busd.address],
        uniV3PoolFees: [],
      }

      const swapPath01 = {
        swapRouter: DEXV2.dexRouter.address,
        swapType: SwapType.V2,
        path: [busd.address, bitcoin.address],
        uniV3PoolFees: [],
      }

      const swapPath10 = {
        swapRouter: DEXV2.dexRouter.address,
        swapType: SwapType.V2,
        path: [banana.address, busd.address],
        uniV3PoolFees: [],
      }

      const swapPath11 = {
        swapRouter: DEXV2.dexRouter.address,
        swapType: SwapType.V2,
        path: [busd.address, ethereum.address],
        uniV3PoolFees: [],
      }

      const liquidityPath = {
        lpRouter: DEXV2.dexRouter.address,
        liquidityType: LPType.V2,
        tickLower: 0,
        tickUpper: 0,
        uniV3PoolLPFee: 0,
        arrakisFactory: ADDRESS_ZERO,
      }

      const minAmountsParams = {
        inputAmount: ether('1').toString(),
        path0: [swapPath00, swapPath01],
        path1: [swapPath10, swapPath11],
        liquidityPath: liquidityPath,
      }

      const liquidityAdder = DEXV2.dexRouter.address
      const nativeZap = false

      const minAmountsData = await zapContract.connect(signers.alice).estimateSwapReturns(minAmountsParams)
      const populatedTx = await getZapData(
        nativeZap,
        minAmountsParams,
        minAmountsData,
        zapContract.address,
        liquidityAdder,
        signers.alice.address
      )
      await zapContract
        .connect(signers.alice)
        .multicall(populatedTx, { value: nativeZap ? minAmountsParams.inputAmount : 0 })

      const balanceAfter = await lpContract.balanceOf(signers.alice.address)
      expect(Number(balanceAfter)).gt(Number(balanceBefore))
    })

    it('Native -> V2 - V2', async () => {
      const {
        zapContract,
        DEXV2,
        DEXV3,
        router,
        mockWBNB,
        banana,
        bitcoin,
        ethereum,
        busd,
        gnana,
        signers,
        factories,
      } = await loadFixture(deployDexAndZap)

      const lp = await DEXV2.dexFactory.getPair(ethereum.address, bitcoin.address)
      const lpContract = await ethers.getContractAt('IApePair', lp)
      const balanceBefore = await lpContract.balanceOf(signers.alice.address)

      const swapPath00 = {
        swapRouter: DEXV2.dexRouter.address,
        swapType: SwapType.V2,
        path: [mockWBNB.address, bitcoin.address],
        uniV3PoolFees: [],
      }

      const swapPath10 = {
        swapRouter: DEXV2.dexRouter.address,
        swapType: SwapType.V2,
        path: [mockWBNB.address, ethereum.address],
        uniV3PoolFees: [],
      }

      const liquidityPath = {
        lpRouter: DEXV2.dexRouter.address,
        liquidityType: LPType.V2,
        tickLower: 0,
        tickUpper: 0,
        uniV3PoolLPFee: 0,
        arrakisFactory: ADDRESS_ZERO,
      }

      const minAmountsParams = {
        inputAmount: ether('1').toString(),
        path0: [swapPath00],
        path1: [swapPath10],
        liquidityPath: liquidityPath,
      }

      const liquidityAdder = DEXV2.dexRouter.address
      const nativeZap = true

      const minAmountsData = await zapContract.connect(signers.alice).estimateSwapReturns(minAmountsParams)
      const populatedTx = await getZapData(
        nativeZap,
        minAmountsParams,
        minAmountsData,
        zapContract.address,
        liquidityAdder,
        signers.alice.address
      )
      await zapContract
        .connect(signers.alice)
        .multicall(populatedTx, { value: nativeZap ? minAmountsParams.inputAmount : 0 })

      const balanceAfter = await lpContract.balanceOf(signers.alice.address)
      expect(Number(balanceAfter)).gt(Number(balanceBefore))
    })

    it('Native -> V3 hops+V3+V2 - V2 hops+V3hops', async () => {
      const {
        zapContract,
        DEXV2,
        DEXV3,
        router,
        mockWBNB,
        banana,
        bitcoin,
        ethereum,
        busd,
        gnana,
        signers,
        factories,
      } = await loadFixture(deployDexAndZap)

      const lp = await DEXV2.dexFactory.getPair(ethereum.address, bitcoin.address)
      const lpContract = await ethers.getContractAt('IApePair', lp)
      const balanceBefore = await lpContract.balanceOf(signers.alice.address)

      const swapPath00 = {
        swapRouter: DEXV3.dexFactory.address,
        swapType: SwapType.V3,
        path: [mockWBNB.address, bitcoin.address, busd.address],
        uniV3PoolFees: [500, 500],
      }

      const swapPath01 = {
        swapRouter: DEXV3.dexFactory.address,
        swapType: SwapType.V3,
        path: [busd.address, ethereum.address],
        uniV3PoolFees: [500],
      }

      const swapPath02 = {
        swapRouter: DEXV2.dexRouter.address,
        swapType: SwapType.V2,
        path: [ethereum.address, bitcoin.address],
        uniV3PoolFees: [],
      }

      const swapPath10 = {
        swapRouter: DEXV2.dexRouter.address,
        swapType: SwapType.V2,
        path: [mockWBNB.address, busd.address, bitcoin.address],
        uniV3PoolFees: [],
      }

      const swapPath11 = {
        swapRouter: DEXV3.dexFactory.address,
        swapType: SwapType.V3,
        path: [bitcoin.address, mockWBNB.address, ethereum.address],
        uniV3PoolFees: [500, 500],
      }

      const liquidityPath = {
        lpRouter: DEXV2.dexRouter.address,
        liquidityType: LPType.V2,
        tickLower: 0,
        tickUpper: 0,
        uniV3PoolLPFee: 0,
        arrakisFactory: ADDRESS_ZERO,
      }

      const minAmountsParams = {
        inputAmount: ether('1').toString(),
        path0: [swapPath00, swapPath01, swapPath02],
        path1: [swapPath10, swapPath11],
        liquidityPath: liquidityPath,
      }

      const liquidityAdder = DEXV2.dexRouter.address
      const nativeZap = true

      const minAmountsData = await zapContract.connect(signers.alice).estimateSwapReturns(minAmountsParams)
      const populatedTx = await getZapData(
        nativeZap,
        minAmountsParams,
        minAmountsData,
        zapContract.address,
        liquidityAdder,
        signers.alice.address
      )
      await zapContract
        .connect(signers.alice)
        .multicall(populatedTx, { value: nativeZap ? minAmountsParams.inputAmount : 0 })

      const balanceAfter = await lpContract.balanceOf(signers.alice.address)
      expect(Number(balanceAfter)).gt(Number(balanceBefore))
    })
  })

  describe('Zap to ApeV3', function () {
    it('V2 - V2', async () => {
      const {
        zapContract,
        DEXV2,
        DEXV3,
        router,
        mockWBNB,
        banana,
        bitcoin,
        ethereum,
        busd,
        gnana,
        signers,
        factories,
      } = await loadFixture(deployDexAndZap)
      const swapPath00 = {
        swapRouter: DEXV2.dexRouter.address,
        swapType: SwapType.V2,
        path: [banana.address, bitcoin.address],
        uniV3PoolFees: [],
      }

      const swapPath10 = {
        swapRouter: DEXV2.dexRouter.address,
        swapType: SwapType.V2,
        path: [banana.address, ethereum.address],
        uniV3PoolFees: [],
      }

      const liquidityPath = {
        lpRouter: DEXV3.dexFactory.address,
        liquidityType: LPType.V3,
        tickLower: -12340,
        tickUpper: 12340,
        uniV3PoolLPFee: 500,
        arrakisFactory: ADDRESS_ZERO,
      }

      const minAmountsParams = {
        inputAmount: ether('1').toString(),
        path0: [swapPath00],
        path1: [swapPath10],
        liquidityPath: liquidityPath,
      }

      const liquidityAdder = DEXV3.positionManager.address
      const nativeZap = false

      const minAmountsData = await zapContract.connect(signers.alice).estimateSwapReturns(minAmountsParams)
      const populatedTx = await getZapData(
        nativeZap,
        minAmountsParams,
        minAmountsData,
        zapContract.address,
        liquidityAdder,
        signers.alice.address
      )
      await zapContract
        .connect(signers.alice)
        .multicall(populatedTx, { value: nativeZap ? minAmountsParams.inputAmount : 0 })

      const NFTs = await DEXV3.positionManager.balanceOf(signers.alice.address)
      expect(Number(NFTs)).eq(1)
    })
    it('V2+V3+V3 - V3 hops+V2 hops', async () => {
      const {
        zapContract,
        DEXV2,
        DEXV3,
        router,
        mockWBNB,
        banana,
        bitcoin,
        ethereum,
        busd,
        gnana,
        signers,
        factories,
      } = await loadFixture(deployDexAndZap)
      const swapPath00 = {
        swapRouter: DEXV2.dexRouter.address,
        swapType: SwapType.V2,
        path: [banana.address, bitcoin.address],
        uniV3PoolFees: [],
      }
      const swapPath01 = {
        swapRouter: DEXV3.dexFactory.address,
        swapType: SwapType.V3,
        path: [bitcoin.address, busd.address],
        uniV3PoolFees: [500],
      }
      const swapPath02 = {
        swapRouter: DEXV3.dexFactory.address,
        swapType: SwapType.V3,
        path: [busd.address, bitcoin.address],
        uniV3PoolFees: [500],
      }

      const swapPath10 = {
        swapRouter: DEXV3.dexFactory.address,
        swapType: SwapType.V3,
        path: [banana.address, mockWBNB.address, busd.address],
        uniV3PoolFees: [500, 500],
      }

      const swapPath11 = {
        swapRouter: DEXV2.dexRouter.address,
        swapType: SwapType.V2,
        path: [busd.address, mockWBNB.address, ethereum.address],
        uniV3PoolFees: [],
      }

      const liquidityPath = {
        lpRouter: DEXV3.dexFactory.address,
        liquidityType: LPType.V3,
        tickLower: -12340,
        tickUpper: 12340,
        uniV3PoolLPFee: 500,
        arrakisFactory: ADDRESS_ZERO,
      }

      const minAmountsParams = {
        inputAmount: ether('1').toString(),
        path0: [swapPath00, swapPath01, swapPath02],
        path1: [swapPath10, swapPath11],
        liquidityPath: liquidityPath,
      }

      const liquidityAdder = DEXV3.positionManager.address
      const nativeZap = false

      const minAmountsData = await zapContract.connect(signers.alice).estimateSwapReturns(minAmountsParams)
      const populatedTx = await getZapData(
        nativeZap,
        minAmountsParams,
        minAmountsData,
        zapContract.address,
        liquidityAdder,
        signers.alice.address
      )
      await zapContract
        .connect(signers.alice)
        .multicall(populatedTx, { value: nativeZap ? minAmountsParams.inputAmount : 0 })

      const NFTs = await DEXV3.positionManager.balanceOf(signers.alice.address)
      expect(Number(NFTs)).eq(1)
    })
  })

  it('Should receive dust back', async () => {
    const { zapContract, DEXV2, DEXV3, router, mockWBNB, banana, bitcoin, ethereum, busd, gnana, signers, factories } =
      await loadFixture(deployDexAndZap)

    const tokenContract0 = await ethers.getContractAt('IERC20', banana.address)
    const tokenContract1 = await ethers.getContractAt('IERC20', bitcoin.address)

    const swapPath0 = {
      swapRouter: DEXV2.dexRouter.address,
      swapType: SwapType.V2,
      path: [banana.address, bitcoin.address],
      uniV3PoolFees: [],
    }

    const swapPath1 = {
      swapRouter: DEXV2.dexRouter.address,
      swapType: SwapType.V2,
      path: [banana.address, ethereum.address],
      uniV3PoolFees: [],
    }

    const liquidityPath = {
      lpRouter: DEXV2.dexRouter.address,
      liquidityType: LPType.V2,
      tickLower: 0,
      tickUpper: 0,
      uniV3PoolLPFee: 0,
      arrakisFactory: ADDRESS_ZERO,
    }

    const minAmountsParams = {
      inputAmount: ether('1').toString(),
      path0: [swapPath0],
      path1: [swapPath1],
      liquidityPath: liquidityPath,
    }

    const liquidityAdder = DEXV2.dexRouter.address
    const nativeZap = false

    const minAmountsData = await zapContract.connect(signers.alice).estimateSwapReturns(minAmountsParams)
    const populatedTx = await getZapData(
      nativeZap,
      minAmountsParams,
      minAmountsData,
      zapContract.address,
      liquidityAdder,
      signers.alice.address
    )
    await zapContract
      .connect(signers.alice)
      .multicall(populatedTx, { value: nativeZap ? minAmountsParams.inputAmount : 0 })

    const token0Balance = await tokenContract0.balanceOf(zapContract.address)
    const token1Balance = await tokenContract1.balanceOf(zapContract.address)
    expect(Number(token0Balance)).equal(0)
    expect(Number(token1Balance)).equal(0)
  })
})
