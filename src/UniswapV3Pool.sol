// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.14;

import "./lib/Tick.sol";
import "./lib/Position.sol";

contract UniswapV3Pool {
    using Tick for mapping(int24 => Tick.Info);
    using Position for mapping(bytes32 => Position.Info);
    using Position for Position.Info;

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

    Slot0 public slot0;

    uint128 public liquidity; // amount of liquidity L
    // Ticks info
    mapping(int24 => Tick.Info) public ticks; // index  to tick info mapping
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
        uint128 amount // amount depositing
    ) external returns (uint256 amount0, uint256 amount1) {

        // edge cases checks
        if (lowerTick >= upperTick || lowerTick < MIN_TICK || upperTick > MAX_TICK) {
            revert InvalidTickRange();
        }

        if (amount == 0) {
            revert ZeroLiquidity();
        }

        // update tick and positions
        ticks.update(lowerTick,amount);
        ticks.update(upperTick, amount);

        Position.Info storage position = positions.get(owner, lowerTick, upperTick);
        position.update(amount);
    }

}
