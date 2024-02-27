// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "forge-std/Test.sol";
import {Utilities} from "../../utils/Utilities.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {DamnValuableToken} from "../../../src/Contracts/DamnValuableToken.sol";
import {AuthorizerUpgradeable} from "../../../src/Contracts/13.wallet-mining/AuthorizerUpgradeable.sol";
import {WalletDeployer} from "../../../src/Contracts/13.wallet-mining/WalletDeployer.sol";

contract WalletMining is Test {
    address internal constant DEPOSIT_ADDRESS = 0x9B6fb606A9f5789444c17768c6dFCF2f83563801;
    uint256 internal constant DEPOSIT_TOKEN_AMOUNT = 20000000 * 10 ** 18;

    Utilities internal utils;
    DamnValuableToken internal dvt;
    AuthorizerUpgradeable internal authorizerImplenentation;
    ERC1967Proxy internal authorizerProxy;
    WalletDeployer internal walletDeployer;

    // address[] internal users;
    address payable internal deployer;
    address payable internal ward;
    address payable internal attacker;

    uint256 internal initialWalletDeployerTokenBalance;

    function setUp() public {
        /**
         * SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE
         */
        utils = new Utilities();

        address payable[] memory users = utils.createUsers(3);
        deployer = users[0];
        ward = users[1];
        attacker = users[2];
        vm.label(deployer, "Deployer");
        vm.label(ward, "Ward");
        vm.label(attacker, "Attacker");

        vm.startPrank(deployer);

        // Deploy Damn Valuable Token contract
        dvt = new DamnValuableToken();
        vm.label(address(dvt), "DVT");

        // Deploy authorizer with the corresponding proxy
        authorizerImplenentation = new AuthorizerUpgradeable();
        vm.label(address(authorizerImplenentation), "Authorizer Implementation");

        address[] memory wards = new address[](1);
        address[] memory aims = new address[](1);
        wards[0] = ward;
        aims[0] = DEPOSIT_ADDRESS;

        bytes memory data = abi.encodeWithSignature("init(address[],address[])", wards, aims);

        authorizerProxy = new ERC1967Proxy(address(authorizerImplenentation), data);
        vm.label(address(authorizerProxy), "Authorizer Proxy");

        assertEq(AuthorizerUpgradeable(address(authorizerProxy)).owner(), deployer);
        assertEq(AuthorizerUpgradeable(address(authorizerProxy)).can(ward, DEPOSIT_ADDRESS), true);
        assertEq(AuthorizerUpgradeable(address(authorizerProxy)).can(attacker, DEPOSIT_ADDRESS), false);

        // Deploy Safe Deployer contract
        walletDeployer = new WalletDeployer(address(dvt));

        assertEq(walletDeployer.chief(), deployer);
        assertEq(walletDeployer.gem(), address(dvt));

        // Fund Safe Deployer with tokens
        initialWalletDeployerTokenBalance = walletDeployer.pay() * 43;
        dvt.transfer(address(walletDeployer), initialWalletDeployerTokenBalance);

        // Ensure these accounts start empty
        assertEq(DEPOSIT_ADDRESS.code, hex"");
        assertEq(address(walletDeployer.fact()).code, hex"");
        assertEq(walletDeployer.copy().code, hex"");

        // Deposit large amount of DVT tokens to the deposit address
        dvt.transfer(DEPOSIT_ADDRESS, DEPOSIT_TOKEN_AMOUNT);

        // Ensure initial balances are set correctly
        assertEq(dvt.balanceOf(DEPOSIT_ADDRESS), DEPOSIT_TOKEN_AMOUNT);
        assertEq(dvt.balanceOf(address(walletDeployer)), initialWalletDeployerTokenBalance);
        assertEq(dvt.balanceOf(attacker), 0);

        vm.stopPrank();

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
        assert(address(walletDeployer.fact()).code.length > 0);
        assert(walletDeployer.copy().code.length > 0);
        assert(DEPOSIT_ADDRESS.code.length > 0);
        assertEq(dvt.balanceOf(DEPOSIT_ADDRESS), 0);
        assertEq(dvt.balanceOf(address(walletDeployer)), 0);
        assertEq(dvt.balanceOf(attacker), DEPOSIT_TOKEN_AMOUNT + initialWalletDeployerTokenBalance);
    }
}
