// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "forge-std/Test.sol";
import {PriceEncoder} from "../../utils/PriceEncoder.sol";
import {DamnValuableToken} from "../../../src/Contracts/DamnValuableToken.sol";
import {WETH9} from "../../../src/Contracts/WETH9.sol";
import {INonfungiblePositionManager} from "../../../src/Contracts/14.puppet-v3/INonfungiblePositionManager.sol";
import {IUniswapV3Factory} from "../../../src/Contracts/14.puppet-v3/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "../../../src/Contracts/14.puppet-v3/IUniswapV3Pool.sol";
import {PuppetV3Pool} from "../../../src/Contracts/14.puppet-v3/PuppetV3Pool.sol";
import {IERC20Minimal} from "../../../src/Contracts/14.puppet-v3/IERC20Minimal.sol";

contract PuppetV3 is Test {
    string public mainnetForkingURL = vm.envString("MAINNET_RPC_URL");
    uint256 public constant MAINNET_BLOCK_NUMBER = 15450164;

    // Initial liquidity amounts for Uniswap v3 pool
    uint256 public constant UNISWAP_INITIAL_TOKEN_LIQUIDITY = 100e18;
    uint256 public constant UNISWAP_INITIAL_WETH_LIQUIDITY = 100e18;
    uint24 public constant UNISWAP_FEE = 3000;

    uint256 public constant ATTACKER_INITIAL_TOKEN_BALANCE = 110e18;
    uint256 public constant ATTACKER_INITIAL_ETH_BALANCE = 1e18;
    uint256 public constant DEPLOYER_INITIAL_ETH_BALANCE = 200e18;

    uint256 public constant LENDING_POOL_INITIAL_TOKEN_BALANCE = 1000000e18;

    IUniswapV3Factory public uniswapFactory;
    WETH9 public weth;
    DamnValuableToken public dvt;
    INonfungiblePositionManager public uniswapPositionManager;
    IUniswapV3Pool public uniswapPool;
    PuppetV3Pool public lendingPool;

    uint256 public forkId;

    address payable public deployer;
    address payable public attacker;
    uint256 public initialBlockTimestamp;

    function setUp() public {
        /**
         * SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE
         */

        // Fork from mainnet state
        forkId = vm.createSelectFork(mainnetForkingURL, MAINNET_BLOCK_NUMBER);

        // Initialize deployer account
        // using private key of account #0 in anvil node
        deployer = payable(vm.addr(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80));
        vm.label(deployer, "Deployer");
        vm.deal(deployer, DEPLOYER_INITIAL_ETH_BALANCE);
        assertEq(deployer.balance, DEPLOYER_INITIAL_ETH_BALANCE);

        // Initialize attacker account
        // using private key of account #1 in anvil node
        attacker = payable(vm.addr(0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d));
        vm.label(attacker, "Attacker");
        vm.deal(attacker, ATTACKER_INITIAL_ETH_BALANCE);
        assertEq(attacker.balance, ATTACKER_INITIAL_ETH_BALANCE);

        // Get a reference to the Uniswap V3 Factory contract
        uniswapFactory = IUniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984);
        vm.label(address(uniswapFactory), "UniswapV3Factory");

        // Get a reference to WETH9
        weth = WETH9(payable(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2));
        vm.label(address(weth), "WETH");

        vm.startPrank(deployer, deployer);

        // Deployer wraps ETH in WETH
        weth.deposit{value: UNISWAP_INITIAL_WETH_LIQUIDITY}();
        assertEq(weth.balanceOf(deployer), UNISWAP_INITIAL_WETH_LIQUIDITY);

        // Deploy DVT token. This is the token to be traded against WETH in the Uniswap v3 pool.
        dvt = new DamnValuableToken();
        vm.label(address(dvt), "DVT");

        // Create the Uniswap v3 pool
        uniswapPositionManager = INonfungiblePositionManager(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);
        vm.label(address(uniswapPositionManager), "UniswapPositionManager");

        uniswapPositionManager.createAndInitializePoolIfNecessary(
            address(weth), address(dvt), UNISWAP_FEE, PriceEncoder.encodePriceSqrt(1, 1)
        );

        uniswapPool = IUniswapV3Pool(uniswapFactory.getPool(address(weth), address(dvt), UNISWAP_FEE));
        uniswapPool.increaseObservationCardinalityNext(40);

        // Deployer adds liquidity at current price to Uniswap V3 exchange
        weth.approve(address(uniswapPositionManager), type(uint256).max);
        dvt.approve(address(uniswapPositionManager), type(uint256).max);

        INonfungiblePositionManager.MintParams memory params;
        params.token0 = address(weth);
        params.token1 = address(dvt);
        params.fee = UNISWAP_FEE;
        params.tickLower = -60;
        params.tickUpper = 60;
        params.amount0Desired = UNISWAP_INITIAL_WETH_LIQUIDITY;
        params.amount1Desired = UNISWAP_INITIAL_TOKEN_LIQUIDITY;
        params.amount0Min = 0;
        params.amount1Min = 0;
        params.recipient = deployer;
        params.deadline = block.timestamp + 300;

        uniswapPositionManager.mint(params);

        // Deploy the lending pool
        lendingPool = new PuppetV3Pool(IERC20Minimal(address(weth)), IERC20Minimal(address(dvt)), uniswapPool);

        // Setup initial token balances of lending pool and player
        dvt.transfer(attacker, ATTACKER_INITIAL_TOKEN_BALANCE);
        dvt.transfer(address(lendingPool), LENDING_POOL_INITIAL_TOKEN_BALANCE);

        // Some time passes
        vm.warp(block.timestamp + 3 days);

        // Ensure oracle in lending pool is working as expected. At this point, DVT/WETH price should be 1:1.
        // To borrow 1 DVT, must deposit 3 ETH
        assertEq(lendingPool.calculateDepositOfWETHRequired(1e18), 3e18);

        // To borrow all DVT in lending pool, user must deposit three times its value
        assertEq(
            lendingPool.calculateDepositOfWETHRequired(LENDING_POOL_INITIAL_TOKEN_BALANCE),
            3 * LENDING_POOL_INITIAL_TOKEN_BALANCE
        );

        // Ensure player doesn't have that much ETH
        assertLt(attacker.balance, 3 * LENDING_POOL_INITIAL_TOKEN_BALANCE);

        initialBlockTimestamp = block.timestamp;

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
        assertLt(block.timestamp - initialBlockTimestamp, 115);
        assertEq(dvt.balanceOf(address(lendingPool)), 0);
        assertGe(dvt.balanceOf(attacker), LENDING_POOL_INITIAL_TOKEN_BALANCE);
    }
}
