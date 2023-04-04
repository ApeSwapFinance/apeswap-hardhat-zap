# ApeSwap Zap

Zap allows you to exchange (zap) your single token into LP in a single operation. It swaps half of your existing token for the other, deposits them into the pool, and then returns the liquidity pool tokens to your address in a single transaction.

## Extensions
The base `ApeSwapZap` contract can be extended to add ZAP functionality directly into other protocol features which can be found in the [contracts/extensions/](./contracts/extensions/) directory.  

These extensions are combined into a single contract for easy use: [ApeSwapZapFullV0.sol](./contracts/ApeSwapZapFullV0.sol). _If new extensions are added, bump the version of this contract to the next version. (i.e. `V1`)_

- `ApeSwapZapLPMigrator.sol`: Provides functionality to migrate LP tokens from one Uniswap V2 DEX to another.  
- `ApeSwapZapTBills.sol`: Provides functionality to purchase Treasury Bills with any type of token.  
- `ApeSwapZapPools.sol`: Provides functionality to zap and stake into pools with any type of token.  

