import { expect } from 'chai'
import { dex, dexV3, dexV2AndV3, utils } from '@ape.swap/hardhat-test-helpers'
import { mine, time, loadFixture } from '@nomicfoundation/hardhat-network-helpers'
import '@nomicfoundation/hardhat-chai-matchers'
import { ethers } from 'hardhat'

const ether = utils.ether

describe('ZapV2', function () {
  const SwapType = {
    V2: 0,
    V3: 1,
  }

  const LPType = {
    V2: 0,
    V3: 1,
    Arrakis: 2,
  }

  const NULL_ADDRESS = '0x0000000000000000000000000000000000000000'

  async function deployDexAndZap() {
    const ApeSwapZap__factory = await ethers.getContractFactory('ApeSwapZapFullV4')
    const Treasury__factory = await ethers.getContractFactory('Treasury')

    const [owner, feeTo, alice] = await ethers.getSigners()

    const { DEXV2, DEXV3, mockTokens, mockWBNB, router } = await dexV2AndV3.deployDexesAndRouter(
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

    const zapContract = await ApeSwapZap__factory.deploy(mockWBNB.address)

    await banana.connect(alice).approve(zapContract.address, ether('1000'))
    await bitcoin.connect(alice).approve(zapContract.address, ether('1000'))
    await ethereum.connect(alice).approve(zapContract.address, ether('1000'))
    await busd.connect(alice).approve(zapContract.address, ether('1000'))

    return {
      zapContract,
      DEXV2,
      DEXV3,
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

  describe('ApeV2 zaps', function () {
    it('Should be able to do a token -> token-token zap', async () => {
      const { zapContract, DEXV2, DEXV3, mockWBNB, banana, bitcoin, ethereum, busd, gnana, signers, factories } =
        await loadFixture(deployDexAndZap)

      const lp = await DEXV2.dexFactory.getPair(banana.address, bitcoin.address)
      const lpContract = await ethers.getContractAt('IApePair', lp)
      const balanceBefore = await lpContract.balanceOf(signers.alice.address)

      const swapPath0 = {
        swapRouter: DEXV2.dexRouter.address,
        swapType: SwapType.V2,
        path: [],
        minAmountSwap: 0,
        uniV3PoolFees: [],
      }

      const swapPath1 = {
        swapRouter: DEXV2.dexRouter.address,
        swapType: SwapType.V2,
        path: [banana.address, bitcoin.address],
        minAmountSwap: 0,
        uniV3PoolFees: [],
      }

      const liquidityPath = {
        lpRouter: DEXV2.dexRouter.address,
        lpType: LPType.V2,
        minAmountLP0: 0,
        minAmountLP1: 0,
        uniV3PoolLPFee: 0,
        arrakisFactory: NULL_ADDRESS,
      }

      const zapParams = {
        inputToken: banana.address,
        inputAmount: ether('1').toString(),
        token0: banana.address,
        token1: bitcoin.address,
        path0: swapPath0,
        path1: swapPath1,
        liquidityPath: liquidityPath,
        to: signers.alice.address,
        deadline: '9999999999',
      }
      console.log(DEXV2.dexRouter.address, banana.address, bitcoin.address)
      await zapContract.connect(signers.alice).zap(zapParams)

      const balanceAfter = await lpContract.balanceOf(signers.alice.address)
      expect(Number(balanceAfter)).gt(Number(balanceBefore))
    })

    it('Should be able to do a token -> different token-token zap', async () => {
      const { zapContract, DEXV2, DEXV3, mockWBNB, banana, bitcoin, ethereum, busd, gnana, signers, factories } =
        await loadFixture(deployDexAndZap)

      const lp = await DEXV2.dexFactory.getPair(ethereum.address, bitcoin.address)
      const lpContract = await ethers.getContractAt('IApePair', lp)
      const balanceBefore = await lpContract.balanceOf(signers.alice.address)

      const swapPath0 = {
        swapRouter: DEXV2.dexRouter.address,
        swapType: SwapType.V2,
        path: [banana.address, ethereum.address],
        minAmountSwap: 0,
        uniV3PoolFees: [],
      }

      const swapPath1 = {
        swapRouter: DEXV2.dexRouter.address,
        swapType: SwapType.V2,
        path: [banana.address, bitcoin.address],
        minAmountSwap: 0,
        uniV3PoolFees: [],
      }

      const liquidityPath = {
        lpRouter: DEXV2.dexRouter.address,
        lpType: LPType.V2,
        minAmountLP0: 0,
        minAmountLP1: 0,
        uniV3PoolLPFee: 0,
        arrakisFactory: NULL_ADDRESS,
      }

      const zapParams = {
        inputToken: banana.address,
        inputAmount: ether('1').toString(),
        token0: ethereum.address,
        token1: bitcoin.address,
        path0: swapPath0,
        path1: swapPath1,
        liquidityPath: liquidityPath,
        to: signers.alice.address,
        deadline: '9999999999',
      }

      await zapContract.connect(signers.alice).zap(zapParams)

      const balanceAfter = await lpContract.balanceOf(signers.alice.address)
      expect(Number(balanceAfter)).gt(Number(balanceBefore))
    })

    it('Should be able to do a token -> native-token zap', async () => {
      const { zapContract, DEXV2, DEXV3, mockWBNB, banana, bitcoin, ethereum, busd, gnana, signers, factories } =
        await loadFixture(deployDexAndZap)

      const lp = await DEXV2.dexFactory.getPair(banana.address, mockWBNB.address)
      const lpContract = await ethers.getContractAt('IApePair', lp)
      const balanceBefore = await lpContract.balanceOf(signers.alice.address)

      const swapPath0 = {
        swapRouter: DEXV2.dexRouter.address,
        swapType: SwapType.V2,
        path: [],
        minAmountSwap: 0,
        uniV3PoolFees: [],
      }

      const swapPath1 = {
        swapRouter: DEXV2.dexRouter.address,
        swapType: SwapType.V2,
        path: [banana.address, mockWBNB.address],
        minAmountSwap: 0,
        uniV3PoolFees: [],
      }

      const liquidityPath = {
        lpRouter: DEXV2.dexRouter.address,
        lpType: LPType.V2,
        minAmountLP0: 0,
        minAmountLP1: 0,
        uniV3PoolLPFee: 0,
        arrakisFactory: NULL_ADDRESS,
      }

      const zapParams = {
        inputToken: banana.address,
        inputAmount: ether('1').toString(),
        token0: banana.address,
        token1: mockWBNB.address,
        path0: swapPath0,
        path1: swapPath1,
        liquidityPath: liquidityPath,
        to: signers.alice.address,
        deadline: '9999999999',
      }

      await zapContract.connect(signers.alice).zap(zapParams)

      const balanceAfter = await lpContract.balanceOf(signers.alice.address)
      expect(Number(balanceAfter)).gt(Number(balanceBefore))
    })

    it('Should be able to do a wrapped -> token-token zap', async () => {
      const { zapContract, DEXV2, DEXV3, mockWBNB, banana, bitcoin, ethereum, busd, gnana, signers, factories } =
        await loadFixture(deployDexAndZap)

      const lp = await DEXV2.dexFactory.getPair(ethereum.address, bitcoin.address)
      const lpContract = await ethers.getContractAt('IApePair', lp)
      const balanceBefore = await lpContract.balanceOf(signers.alice.address)

      await mockWBNB.connect(signers.alice).deposit({ value: ether('1') })
      await mockWBNB.connect(signers.alice).approve(zapContract.address, ether('1000'))

      const swapPath0 = {
        swapRouter: DEXV2.dexRouter.address,
        swapType: SwapType.V2,
        path: [mockWBNB.address, ethereum.address],
        minAmountSwap: 0,
        uniV3PoolFees: [],
      }

      const swapPath1 = {
        swapRouter: DEXV2.dexRouter.address,
        swapType: SwapType.V2,
        path: [mockWBNB.address, bitcoin.address],
        minAmountSwap: 0,
        uniV3PoolFees: [],
      }

      const liquidityPath = {
        lpRouter: DEXV2.dexRouter.address,
        lpType: LPType.V2,
        minAmountLP0: 0,
        minAmountLP1: 0,
        uniV3PoolLPFee: 0,
        arrakisFactory: NULL_ADDRESS,
      }

      const zapParams = {
        inputToken: mockWBNB.address,
        inputAmount: ether('1').toString(),
        token0: ethereum.address,
        token1: bitcoin.address,
        path0: swapPath0,
        path1: swapPath1,
        liquidityPath: liquidityPath,
        to: signers.alice.address,
        deadline: '9999999999',
      }

      await zapContract.connect(signers.alice).zap(zapParams)

      const balanceAfter = await lpContract.balanceOf(signers.alice.address)
      expect(Number(balanceAfter)).gt(Number(balanceBefore))
    })

    it('Should be able to do a wrapped -> native-token zap', async () => {
      const { zapContract, DEXV2, DEXV3, mockWBNB, banana, bitcoin, ethereum, busd, gnana, signers, factories } =
        await loadFixture(deployDexAndZap)

      const lp = await DEXV2.dexFactory.getPair(mockWBNB.address, bitcoin.address)
      const lpContract = await ethers.getContractAt('IApePair', lp)
      const balanceBefore = await lpContract.balanceOf(signers.alice.address)

      await mockWBNB.connect(signers.alice).deposit({ value: ether('1') })
      await mockWBNB.connect(signers.alice).approve(zapContract.address, ether('1000'))

      const swapPath0 = {
        swapRouter: DEXV2.dexRouter.address,
        swapType: SwapType.V2,
        path: [],
        minAmountSwap: 0,
        uniV3PoolFees: [],
      }

      const swapPath1 = {
        swapRouter: DEXV2.dexRouter.address,
        swapType: SwapType.V2,
        path: [mockWBNB.address, bitcoin.address],
        minAmountSwap: 0,
        uniV3PoolFees: [],
      }

      const liquidityPath = {
        lpRouter: DEXV2.dexRouter.address,
        lpType: LPType.V2,
        minAmountLP0: 0,
        minAmountLP1: 0,
        uniV3PoolLPFee: 0,
        arrakisFactory: NULL_ADDRESS,
      }

      const zapParams = {
        inputToken: mockWBNB.address,
        inputAmount: ether('1').toString(),
        token0: mockWBNB.address,
        token1: bitcoin.address,
        path0: swapPath0,
        path1: swapPath1,
        liquidityPath: liquidityPath,
        to: signers.alice.address,
        deadline: '9999999999',
      }

      await zapContract.connect(signers.alice).zap(zapParams)

      const balanceAfter = await lpContract.balanceOf(signers.alice.address)
      expect(Number(balanceAfter)).gt(Number(balanceBefore))
    })

    it('Should be able to do a native -> token-token zap', async () => {
      const { zapContract, DEXV2, DEXV3, mockWBNB, banana, bitcoin, ethereum, busd, gnana, signers, factories } =
        await loadFixture(deployDexAndZap)

      const lp = await DEXV2.dexFactory.getPair(banana.address, bitcoin.address)
      const lpContract = await ethers.getContractAt('IApePair', lp)
      const balanceBefore = await lpContract.balanceOf(signers.alice.address)

      const swapPath0 = {
        swapRouter: DEXV2.dexRouter.address,
        swapType: SwapType.V2,
        path: [mockWBNB.address, banana.address],
        minAmountSwap: 0,
        uniV3PoolFees: [],
      }

      const swapPath1 = {
        swapRouter: DEXV2.dexRouter.address,
        swapType: SwapType.V2,
        path: [mockWBNB.address, bitcoin.address],
        minAmountSwap: 0,
        uniV3PoolFees: [],
      }

      const liquidityPath = {
        lpRouter: DEXV2.dexRouter.address,
        lpType: LPType.V2,
        minAmountLP0: 0,
        minAmountLP1: 0,
        uniV3PoolLPFee: 0,
        arrakisFactory: NULL_ADDRESS,
      }

      const zapParams = {
        token0: banana.address,
        token1: bitcoin.address,
        path0: swapPath0,
        path1: swapPath1,
        liquidityPath: liquidityPath,
        to: signers.alice.address,
        deadline: '9999999999',
      }

      await zapContract.connect(signers.alice).zapNative(zapParams, { value: ether('1') })

      const balanceAfter = await lpContract.balanceOf(signers.alice.address)
      expect(Number(balanceAfter)).gt(Number(balanceBefore))
    })

    it('Should be able to do a native -> native-token zap', async () => {
      const { zapContract, DEXV2, DEXV3, mockWBNB, banana, bitcoin, ethereum, busd, gnana, signers, factories } =
        await loadFixture(deployDexAndZap)

      const lp = await DEXV2.dexFactory.getPair(banana.address, mockWBNB.address)
      const lpContract = await ethers.getContractAt('IApePair', lp)
      const balanceBefore = await lpContract.balanceOf(signers.alice.address)

      const swapPath0 = {
        swapRouter: DEXV2.dexRouter.address,
        swapType: SwapType.V2,
        path: [mockWBNB.address, banana.address],
        minAmountSwap: 0,
        uniV3PoolFees: [],
      }

      const swapPath1 = {
        swapRouter: DEXV2.dexRouter.address,
        swapType: SwapType.V2,
        path: [],
        minAmountSwap: 0,
        uniV3PoolFees: [],
      }

      const liquidityPath = {
        lpRouter: DEXV2.dexRouter.address,
        lpType: LPType.V2,
        minAmountLP0: 0,
        minAmountLP1: 0,
        uniV3PoolLPFee: 0,
        arrakisFactory: NULL_ADDRESS,
      }

      const zapParams = {
        token0: banana.address,
        token1: mockWBNB.address,
        path0: swapPath0,
        path1: swapPath1,
        liquidityPath: liquidityPath,
        to: signers.alice.address,
        deadline: '9999999999',
      }

      await zapContract.connect(signers.alice).zapNative(zapParams, { value: ether('1') })

      const balanceAfter = await lpContract.balanceOf(signers.alice.address)
      expect(Number(balanceAfter)).gt(Number(balanceBefore))
    })

    it('Should receive dust back', async () => {
      const { zapContract, DEXV2, DEXV3, mockWBNB, banana, bitcoin, ethereum, busd, gnana, signers, factories } =
        await loadFixture(deployDexAndZap)

      const tokenContract0 = await ethers.getContractAt('IERC20', banana.address)
      const tokenContract1 = await ethers.getContractAt('IERC20', bitcoin.address)

      const balanceBefore = await tokenContract0.balanceOf(signers.alice.address)

      const swapPath0 = {
        swapRouter: DEXV2.dexRouter.address,
        swapType: SwapType.V2,
        path: [],
        minAmountSwap: 0,
        uniV3PoolFees: [],
      }

      const swapPath1 = {
        swapRouter: DEXV2.dexRouter.address,
        swapType: SwapType.V2,
        path: [banana.address, bitcoin.address],
        minAmountSwap: 0,
        uniV3PoolFees: [],
      }

      const liquidityPath = {
        lpRouter: DEXV2.dexRouter.address,
        lpType: LPType.V2,
        minAmountLP0: 0,
        minAmountLP1: 0,
        uniV3PoolLPFee: 0,
        arrakisFactory: NULL_ADDRESS,
      }

      const zapParams = {
        inputToken: banana.address,
        inputAmount: ether('1').toString(),
        token0: banana.address,
        token1: bitcoin.address,
        path0: swapPath0,
        path1: swapPath1,
        liquidityPath: liquidityPath,
        to: signers.alice.address,
        deadline: '9999999999',
      }

      await zapContract.connect(signers.alice).zap(zapParams)

      const balanceAfter = await tokenContract0.balanceOf(signers.alice.address)
      expect(Number(balanceAfter)).gt(Number(balanceBefore) - Number(ether('1')))

      const token0Balance = await tokenContract0.balanceOf(zapContract.address)
      const token1Balance = await tokenContract1.balanceOf(zapContract.address)
      expect(Number(token0Balance)).equal(0)
      expect(Number(token1Balance)).equal(0)
    })

    it('Should revert for non existing pair', async () => {
      const { zapContract, DEXV2, DEXV3, mockWBNB, banana, bitcoin, ethereum, busd, gnana, signers, factories } =
        await loadFixture(deployDexAndZap)

      const swapPath0 = {
        swapRouter: DEXV2.dexRouter.address,
        swapType: SwapType.V2,
        path: [banana.address, bitcoin.address],
        minAmountSwap: 0,
        uniV3PoolFees: [],
      }

      const swapPath1 = {
        swapRouter: DEXV2.dexRouter.address,
        swapType: SwapType.V2,
        path: [banana.address, busd.address],
        minAmountSwap: 0,
        uniV3PoolFees: [],
      }

      const liquidityPath = {
        lpRouter: DEXV2.dexRouter.address,
        lpType: LPType.V2,
        minAmountLP0: 0,
        minAmountLP1: 0,
        uniV3PoolLPFee: 0,
        arrakisFactory: NULL_ADDRESS,
      }

      const zapParams = {
        inputToken: banana.address,
        inputAmount: ether('1').toString(),
        token0: bitcoin.address,
        token1: busd.address,
        path0: swapPath0,
        path1: swapPath1,
        liquidityPath: liquidityPath,
        to: signers.alice.address,
        deadline: '9999999999',
      }

      await expect(zapContract.connect(signers.alice).zap(zapParams)).to.be.revertedWith(
        "ApeSwapZap: Pair doesn't exist"
      )
    })
  })
})
