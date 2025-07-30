// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.24;

import {Tick} from "./lib/Tick.sol";
import {Position} from "./lib/Position.sol";

contract UniswapV3Pool {
    error InvalidTickRange();

    using Tick for mapping(int24 => Tick.Info);
    using Position for mapping(bytes32 => Position.Info);
    using Position for Position.Info;

    int24 internal constant MIN_TICK = -887272;
    int24 internal constant MAX_TICK = -MIN_TICK;

    // Pool tokens,immutable
    address public immutable token0;
    address public immutable token1;

    // Gas optimization: Packing up variables to avoid unecessary calls
    struct Slot0 {
        uint160 sqrtPriceX96; //Current sqrt(P)
        int24 tick; //Current tick
    }

    Slot0 public slot0;

    // Amount of liquidity, L.
    uint128 public liquidity;

    // Ticks info
    mapping(int24 => Tick.Info) public ticks;
    mapping(bytes32 => Position.Info) public positions;

    constructor(address _token0, address _token1, uint160 sqrtPriceX96, int24 tick) {
        token0 = _token0;
        token1 = _token1;

        slot0 = Slot0({sqrtPriceX96: sqrtPriceX96, tick: tick});
    }

    function mint(address owner, int24 lowerTick, int24 upperTick, uint128 amount)
        external
        returns (uint256 amount0, uint256 amount1)
    {
        if (lowerTick >= upperTick || lowerTick < MIN_TICK || upperTick < MAX_TICK) revert InvalidTickRange();
    }
}
