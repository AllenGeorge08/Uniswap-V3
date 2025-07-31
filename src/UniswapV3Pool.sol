// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.24;

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {Tick} from "./lib/Tick.sol";
import {Position} from "./lib/Position.sol";
import {IUniswapV3MintCallback} from "./interfaces/IUniswapV3MintCallback.sol";

contract UniswapV3Pool {
    error InvalidTickRange();
    error InsufficientInputAmount();
    error ZeroLiquidity();
    error  MintCallbackFailed();

    event Mint(address, address, int24, int24, uint256, uint256, uint256);

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

    // INCOMPLETE
    function mint(address owner, int24 lowerTick, int24 upperTick, uint128 liquidityAmount)
        external
        returns (uint256 amount0, uint256 amount1)
    {
        if (lowerTick >= upperTick || lowerTick < MIN_TICK || upperTick > MAX_TICK) revert InvalidTickRange();

        if (liquidityAmount == 0) revert ZeroLiquidity();

        // amount0 = uint256(amount0Int);
        // amount1 = uint256(amount1Int);

        uint256 balance0Before;
        uint256 balance1Before;

        ticks.update(lowerTick, liquidityAmount);
        ticks.update(upperTick, liquidityAmount);

        Position.Info storage position = positions.get(owner, lowerTick, upperTick);

        position.update(liquidityAmount);

        liquidity += uint128(liquidityAmount);

        if (amount0 > 0) balance0Before = balance0();
        if (amount1 > 0) balance1Before = balance1();

        //User sends tokens through this..The caller is 
        try IUniswapV3MintCallback(msg.sender).uniswapV3MintCallback(amount0, amount1, "") {
            // Callback succeeded, continue with the function
        } catch {
            revert MintCallbackFailed();
        }

        if (amount0 > 0 && balance0Before + amount0 > balance0()) revert InsufficientInputAmount();
        if (amount1 > 0 && balance1Before + amount1 > balance1()) revert InsufficientInputAmount();

        emit Mint(msg.sender, owner, lowerTick, upperTick, liquidityAmount, amount0, amount1);
    }


    function balance0() internal view returns (uint256 balance) {
        balance = IERC20(token0).balanceOf(address(this));
    }

    function balance1() internal view returns (uint256 balance) {
        balance = IERC20(token1).balanceOf(address(this));
    }
}
