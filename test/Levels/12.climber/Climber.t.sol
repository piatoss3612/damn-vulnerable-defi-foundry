// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Utilities} from "../../utils/Utilities.sol";
import "openzeppelin-contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "forge-std/Test.sol";

import {DamnValuableToken} from "../../../src/Contracts/DamnValuableToken.sol";
import {ClimberTimelock} from "../../../src/Contracts/12.climber/ClimberTimelock.sol";
import {ClimberVault} from "../../../src/Contracts/12.climber/ClimberVault.sol";
import "../../../src/Contracts/12.climber/ClimberConstants.sol";
import "../../../src/Contracts/12.climber/ClimberErrors.sol";

contract Climber is Test {
    uint256 internal constant VAULT_TOKEN_BALANCE = 10_000_000e18;
    uint256 internal constant ATTACKER_INITIAL_ETH_BALANCE = 0.1 ether;
    uint256 internal constant TIMELOCK_DELAY = 1 hours;

    Utilities internal utils;
    DamnValuableToken internal dvt;
    ClimberTimelock internal timelock;
    ClimberVault internal vaultImplementation;
    ERC1967Proxy internal vaultProxy;
    address[] internal users;
    address payable internal deployer;
    address payable internal proposer;
    address payable internal sweeper;
    address payable internal attacker;

    function setUp() public {
        /**
         * SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE
         */
        utils = new Utilities();
        users = utils.createUsers(3);

        deployer = payable(users[0]);
        proposer = payable(users[1]);
        sweeper = payable(users[2]);

        attacker = payable(address(uint160(uint256(keccak256(abi.encodePacked("attacker"))))));
        vm.label(attacker, "Attacker");
        vm.deal(attacker, ATTACKER_INITIAL_ETH_BALANCE);

        assertEq(attacker.balance, ATTACKER_INITIAL_ETH_BALANCE);

        // Deploy the vault behind a proxy using the UUPS pattern,
        // passing the necessary addresses for the `ClimberVault::initialize(address,address,address)` function
        vaultImplementation = new ClimberVault();
        vm.label(address(vaultImplementation), "ClimberVault Implementation");

        bytes memory data = abi.encodeWithSignature("initialize(address,address,address)", deployer, proposer, sweeper);
        vaultProxy = new ERC1967Proxy(address(vaultImplementation), data);
        vm.label(address(vaultProxy), "ClimberVault Proxy");

        assertEq(ClimberVault(address(vaultProxy)).getSweeper(), sweeper);

        assertGt(ClimberVault(address(vaultProxy)).getLastWithdrawalTimestamp(), 0);

        // Instantiate timelock
        address timelockAddress = ClimberVault(address(vaultProxy)).owner();
        vm.label(timelockAddress, "ClimberTimelock");

        timelock = ClimberTimelock(payable(timelockAddress));

        assertEq(timelock.delay(), TIMELOCK_DELAY);

        vm.expectRevert(CallerNotTimelock.selector);
        timelock.updateDelay(uint64(TIMELOCK_DELAY) + 1);

        assertTrue(timelock.hasRole(PROPOSER_ROLE, proposer));

        assertTrue(timelock.hasRole(ADMIN_ROLE, deployer));

        assertTrue(timelock.hasRole(ADMIN_ROLE, timelockAddress));

        // Deploy token and transfer initial token balance to the vault
        dvt = new DamnValuableToken();
        vm.label(address(dvt), "DVT");
        dvt.transfer(address(vaultProxy), VAULT_TOKEN_BALANCE);

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
         * SUCCESS CONDITIONS
         */
        assertEq(dvt.balanceOf(attacker), VAULT_TOKEN_BALANCE);
        assertEq(dvt.balanceOf(address(vaultProxy)), 0);
    }
}
