# Challenge #14 - Puppet V3

Even on a bear market, the devs behind [the lending pool](https://www.damnvulnerabledefi.xyz/challenges/puppet-v3/) kept building.

In the latest version, they’re using Uniswap V3 as an oracle. That’s right, no longer using spot prices! This time the pool queries the time-weighted average price of the asset, with all the recommended libraries.

The Uniswap market has 100 WETH and 100 DVT in liquidity. The lending pool has a million DVT tokens.

Starting with 1 ETH and some DVT, pass this challenge by taking all tokens from the lending pool.

NOTE: unlike others, this challenge requires you to set a valid RPC URL in the challenge’s test file to fork mainnet state into your local environment.

- [See the contracts](https://github.com/piatoss3612/damn-vulnerable-defi-foundry/tree/v3/src/Contracts/14.puppet-v3)
- [Complete the challenge](https://github.com/piatoss3612/damn-vulnerable-defi-foundry/blob/v3/test/Levels/14.puppet-v3/PuppetV3.t.sol)
