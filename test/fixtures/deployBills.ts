import { ethers } from 'hardhat'
import { ERC20 } from '../../typechain-types'
import { dex, utils, farmV2, ERC20Mock__factory } from '@ape.swap/hardhat-test-helpers'
import { ADDRESS_ZERO } from '../utils/constants'

const ether = utils.ether

const CustomBillRefillableArtifact = require('../../contracts/extensions/bills/lib/CustomBillRefillable.json')
const CustomTreasuryArtifact = require('../../contracts/extensions/bills/lib/CustomTreasury.json')
const BillNftArtifact = require('../../contracts/extensions/bills/lib/BillNft.json')

export async function deployBill(_ethers: typeof ethers, payoutToken: ERC20, principalToken: ERC20) {
  const [owner, feeTo, alice] = await _ethers.getSigners()

  const BillNft__factory = await _ethers.getContractFactoryFromArtifact(BillNftArtifact)
  const billNft = await BillNft__factory.deploy()
  await billNft.connect(owner).initialize('Zap Bills', 'ZB', 'https://uri', owner.address, owner.address)

  const billCreationDetails = {
    payoutToken: payoutToken.address,
    principalToken: principalToken.address,
    initialOwner: owner.address,
    vestingCurve: ADDRESS_ZERO,
    tierCeilings: [0],
    fees: [0],
    feeInPayout: false,
  }
  const billTerms = {
    controlVariable: '250000',
    vestingTerm: '1209600', // One day 1209600 In seconds
    minimumPrice: '0', // '100000',
    maxPayout: '500', // in thousandths of a % of total supply. i.e. 500 = 0.5%
    maxTotalPayout: '168311894000000000000000000',
    maxDebt: '210479370288084000000',
    initialDebt: '147335559201659000000',
  }
  const billAccounts = {
    feeTo: owner.address,
    DAO: owner.address,
    billNft: billNft.address,
  }

  const CustomTreasury__factory = await _ethers.getContractFactoryFromArtifact(CustomTreasuryArtifact)
  const customTreasury = await CustomTreasury__factory.deploy()
  await customTreasury.connect(owner).initialize(payoutToken.address, owner.address, owner.address)

  const CustomBillRefillable__factory = await _ethers.getContractFactoryFromArtifact(CustomBillRefillableArtifact)
  const bill = await CustomBillRefillable__factory.deploy()
  await billNft.connect(owner).addMinter(bill.address)
  await bill
    .connect(owner)
    [
      'initialize(address,(address,address,address,address,uint256[],uint256[],bool),(uint256,uint256,uint256,uint256,uint256,uint256,uint256),(address,address,address),address[])'
    ](customTreasury.address, billCreationDetails, billTerms, billAccounts, [])

  await customTreasury.connect(owner).toggleBillContract(bill.address, true)
  await payoutToken.transfer(customTreasury.address, ether('10'))

  return bill
}
