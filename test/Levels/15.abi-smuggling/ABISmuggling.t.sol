// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "forge-std/Test.sol";
import {Utilities} from "../../utils/Utilities.sol";
import {DamnValuableToken} from "../../../src/Contracts/DamnValuableToken.sol";
import {SelfAuthorizedVault} from "../../../src/Contracts/15.abi-smuggling/SelfAuthorizedVault.sol";

contract ABISmuggling is Test {
    uint256 public constant VAULT_TOKEN_BALANCE = 1000000e18;

    Utilities public utils;
    DamnValuableToken public dvt;
    SelfAuthorizedVault public vault;

    address payable public deployer;
    address payable public attacker;
    address payable public recovery;

    function setUp() public {
        /**
         * SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE
         */
        utils = new Utilities();

        address payable[] memory users = utils.createUsers(3);
        deployer = users[0];
        attacker = users[1];
        recovery = users[2];

        vm.startPrank(deployer);

        // Deploy Damn Valuable Token contract
        dvt = new DamnValuableToken();

        // Deploy Vault
        vault = new SelfAuthorizedVault();
        assertGt(vault.getLastWithdrawalTimestamp(), 0);

        // Set permissions
        bytes32 deployerPermission =
            vault.getActionId(SelfAuthorizedVault.sweepFunds.selector, deployer, address(vault));
        bytes32 attackerPermission = vault.getActionId(SelfAuthorizedVault.withdraw.selector, attacker, address(vault));
        bytes32[] memory ids = new bytes32[](2);
        ids[0] = deployerPermission;
        ids[1] = attackerPermission;

        vault.setPermissions(ids);

        assertTrue(vault.permissions(deployerPermission));
        assertTrue(vault.permissions(attackerPermission));

        // Make sure Vault is initialized
        assertTrue(vault.initialized());

        // Deposit tokens into the vault
        dvt.transfer(address(vault), VAULT_TOKEN_BALANCE);

        assertEq(dvt.balanceOf(address(vault)), VAULT_TOKEN_BALANCE);
        assertEq(dvt.balanceOf(attacker), 0);

        // Cannot call Vault directly
        vm.expectRevert(SelfAuthorizedVault.CallerNotAllowed.selector);
        vault.sweepFunds(deployer, dvt);
        vm.expectRevert(SelfAuthorizedVault.CallerNotAllowed.selector);
        vault.withdraw(address(dvt), attacker, 10e18);

        console.log(unicode"🧨 Let's see if you can break it... 🧨");
    }

    function testExploit() public {
        /**
         * EXPLOIT START *
         */

        /**
         * EXPLOIT END *
         */
        validation();
        console.log(unicode"\n🎉 Congratulations, you can go to the next level! 🎉");
    }

    function validation() internal {
        /**
         * SUCCESS CONDITIONS - NO NEED TO CHANGE ANYTHING HERE
         */
        assertEq(dvt.balanceOf(address(vault)), 0);
        assertEq(dvt.balanceOf(attacker), 0);
        assertEq(dvt.balanceOf(recovery), VAULT_TOKEN_BALANCE);
    }
}
