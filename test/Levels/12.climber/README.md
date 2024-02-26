# Challenge #12 - Climber

There’s a secure vault contract guarding 10 million DVT tokens. The vault is upgradeable, following the [UUPS pattern](https://eips.ethereum.org/EIPS/eip-1822).

The owner of the vault, currently a timelock contract, can withdraw a very limited amount of tokens every 15 days.

On the vault there’s an additional role with powers to sweep all tokens in case of an emergency.

On the timelock, only an account with a “Proposer” role can schedule actions that can be executed 1 hour later.

To pass this challenge, take all tokens from the vault.

- [See the contracts](https://github.com/piatoss3612/damn-vulnerable-defi-foundry/tree/v3/src/Contracts/12.climber)
- [Complete the challenge](https://github.com/piatoss3612/damn-vulnerable-defi-foundry/blob/v3/test/Levels/12.climber/Climber.t.sol)
