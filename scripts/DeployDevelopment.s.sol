// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.14;

import "./../lib/forge-std/src/console.sol";
import "./../lib/forge-std/src/Script.sol";
import "./../test/ERCMintable.sol";
import "../src/UniswapV3Pool.sol";
import "../src/UniswapV3Manager.sol";

contract DeployDevelopment is Script {

    function run() public {

        // for testing purposes
        uint256 wethBalance = 1 ether;
        uint256 usdcBalance = 5042 ether;
        int24 currentTick = 85176;
        uint160 currentSqrtP = 5602277097478614198912276234240;

        // anything that happens in between start and stop will be trated as transactions
        vm.startBroadcast();

        // deploy WETH
        ERC20Mintable token0 = new ERC20Mintable("Wrapped Ether", "WETH", 18);

        // deploy USDC
        ERC20Mintable token1 = new ERC20Mintable("USD Coin", "USDC", 18);

        // deploy WETH/USDC Pool
        UniswapV3Pool pool = new UniswapV3Pool(
            address(token0),
            address(token1),
            currentSqrtP,
            currentTick
        );

        // deploy Uniswap Manager Pool
        UniswapV3Manager manager = new UniswapV3Manager();

        // mint some tokens to the user
        token0.mint(msg.sender, wethBalance);
        token1.mint(msg.sender, usdcBalance);

        vm.stopBroadcast();

        // log out the addresses
        console.log("WETH address", address(token0));
        console.log("USDC address", address(token1));
        console.log("Pool address", address(pool));
        console.log("Manager address", address(manager));
    }
}