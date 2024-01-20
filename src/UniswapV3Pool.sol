// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.14;

import "./interfaces/IERC20.sol";
import "./interfaces/IUniswapV3MintCallback.sol";
import "./interfaces/IUniswapV3SwapCallback.sol";

import "./lib/Math.sol";
import "./lib/Position.sol";
import "./lib/SwapMath.sol";
import "./lib/Tick.sol";
import "./lib/TickBitmap.sol";
import "./lib/TickMath.sol";

contract UniswapV3Pool {
    using Tick for mapping(int24 => Tick.Info);
    using TickBitmap for mapping(int16 => uint256);
    using Position for mapping(bytes32 => Position.Info);
    using Position for Position.Info;

    error InsufficientInputAmount();
    error InvalidTickRange();
    error ZeroLiquidity();

    event Mint(
        address sender,
        address indexed owner,
        int24 indexed tickLower,
        int24 indexed tickUpper,
        uint128 amount,
        uint256 amount0,
        uint256 amount1
    );

    event Swap(
        address indexed sender,
        address indexed recipient,
        int256 amount0,
        int256 amount1,
        uint160 sqrtPriceX96,
        uint128 liquidity,
        int24 tick
    );

    int24 internal constant MIN_TICK = -887272;
    int24 internal constant MAX_TICK = -MIN_TICK;

    // pool tokens
    address public immutable token0; // token 0 address
    address public immutable token1; // token 1 address

    //read more about this
    // packing vars that are read together 
    struct Slot0 {
        uint160 sqrtPriceX96; // curr sqrt(P)
        int24 tick; // curr tick
    }

    struct CallbackData {
        address token0;
        address token1;
        address payer;
    }

    struct SwapState {
        uint256 amountSpecifiedRemaining;
        uint256 amountCalculated;
        uint160 sqrtPriceX96;
        int24 tick;
    }

    struct StepState {
        uint160 sqrtPriceStartX96;
        int24 nextTick;
        uint160 sqrtPriceNextX96;
        uint256 amountIn;
        uint256 amountOut;
    }

    Slot0 public slot0;

    uint128 public liquidity; // amount of liquidity L
    // Ticks info
    mapping(int24 => Tick.Info) public ticks; // index  to tick info mapping
    mapping (int16 => uint256) public tickBitmap; // word to liquidity
    mapping(bytes32 => Position.Info) public positions; // tick to postion info mapping

    constructor(
        address token0_,
        address token1_,
        uint160 sqrtPriceX96,
        int24 tick
    ) {
        token0 = token0_;
        token1 = token1_;
        slot0 = Slot0({sqrtPriceX96: sqrtPriceX96, tick: tick});
    }

    // minting; info: v2 mints liquidity tokens when providing liquidity, v3 doesnt do that they mint nft
    // figure out signed integers were used for tick - sarvad
    function mint(
        address owner, // address depositing
        int24 lowerTick, // lower price range
        int24 upperTick, // upper price range
        uint128 amount, // amount depositing - liquidity
        bytes calldata data // data holding details
    ) external returns (uint256 amount0, uint256 amount1) {

        // edge cases checks
        if (lowerTick >= upperTick || lowerTick < MIN_TICK || upperTick > MAX_TICK) {
            revert InvalidTickRange();
        }

        if (amount == 0) {
            revert ZeroLiquidity();
        }

        // update tick and positions
        bool flippedLower = ticks.update(lowerTick,amount);
        bool flippedUpper = ticks.update(upperTick, amount);

        if (flippedLower) {
            tickBitmap.flipTick(lowerTick, 1);
        }

        if (flippedUpper) {
            tickBitmap.flipTick(upperTick, 1);
        }

        Position.Info storage position = positions.get(owner, lowerTick, upperTick);
        position.update(amount);

        Slot0 memory slot0_ = slot0;

        // calculating amount from liquidity
        amount0 = Math.calcAmount0Delta(TickMath.getSqrtRatioAtTick(slot0_.tick), TickMath.getSqrtRatioAtTick(upperTick), amount);
        amount1 = Math.calcAmount1Delta(TickMath.getSqrtRatioAtTick(slot0_.tick), TickMath.getSqrtRatioAtTick(lowerTick), amount);

        liquidity += uint128(amount);

        // // balance checks
        uint256 balance0Before;
        uint256 balance1Before;

        if (amount0 > 0) balance0Before = balance0();
        if (amount1 > 0) balance1Before = balance1();

        IUniswapV3MintCallback(msg.sender).uniswapV3MintCallback(
            amount0,
            amount1,
            data
        );

        // balance0 over here is the updated balance after depositing token0 amount
        if (amount0 > 0 && balance0Before + amount0 > balance0()) {
            revert InsufficientInputAmount();
        }

        // balance1 over here is the updated balance after depositing token1 amount
        if (amount1 > 0 && balance1Before + amount1 > balance1()) {
            revert InsufficientInputAmount();
        }

        // // mint completion
        emit Mint(msg.sender, owner, lowerTick, upperTick, amount, amount0, amount1);
    }

    function swap(address recipient, bytes calldata data) public returns (int256 amount0, int256 amount1) {

        // target price and tick
        int24 nextTick = 85184;
        uint160 nextPrice = 5604469350942327889444743441197;

        // amount sold and bougth
        amount0 = -0.008396714242162444 ether;
        amount1 = 42 ether;

        // update slot0
        (slot0.tick, slot0.sqrtPriceX96) = (nextTick, nextPrice);

        // send the token x to recipient and receive from token y from recipient
        IERC20(token0).transfer(recipient, uint256(-amount0));
        uint256 balanceBefore1 = balance1();
        IUniswapV3SwapCallback(msg.sender).uniswapV3SwapCallback(amount0, amount1, data);

        // balance check for validation
        if (balanceBefore1 + uint256(amount1) > balance1()) {
            revert InsufficientInputAmount();    
        }

        // one way swap complete
        emit Swap(
                msg.sender,
                recipient,
                amount0,
                amount1,
                slot0.sqrtPriceX96,
                liquidity,
                slot0.tick
            );
    }

    // helper functions
    function balance0() internal returns (uint256 balance) {
        balance = IERC20(token0).balanceOf(address(this));
    }

    function balance1() internal returns (uint256 balance) {
        balance = IERC20(token1).balanceOf(address(this));
    }

}
