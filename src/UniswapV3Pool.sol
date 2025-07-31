// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.24;

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {Tick} from "./lib/Tick.sol";
import {Position} from "./lib/Position.sol";
import {IUniswapV3MintCallback} from "./interfaces/IUniswapV3MintCallback.sol";

contract UniswapV3Pool {
    error InvalidTickRange();
    error InsufficientInputAmount();

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

    function mint(address owner, int24 lowerTick, int24 upperTick, uint128 liquidityAmount)
        external
        returns (uint256 amount0, uint256 amount1)
    {
        if (lowerTick >= upperTick || lowerTick < MIN_TICK || upperTick > MAX_TICK) revert InvalidTickRange();
        
        // Calculate amounts based on liquidity and tick range
        (amount0, amount1) = _calculateAmounts(lowerTick, upperTick, liquidityAmount);
        
        uint256 balance0Before;
        uint256 balance1Before;
        if (amount0 > 0) balance0Before = balance0();
        if (amount1 > 0) balance1Before = balance1();
        
        IUniswapV3MintCallback(msg.sender).uniswapV3MintCallback(amount0, amount1, "");

        if (amount0 > 0 && balance0Before + amount0 > balance0()) revert InsufficientInputAmount();
        if (amount1 > 0 && balance1Before + amount1 > balance1()) revert InsufficientInputAmount();

        // Update position and ticks
        _updatePosition(owner, lowerTick, upperTick, liquidityAmount);
        _updateTicks(lowerTick, upperTick, liquidityAmount);

        emit Mint(msg.sender, owner, lowerTick, upperTick, liquidityAmount, amount0, amount1);
    }

    function _calculateAmounts(int24 lowerTick, int24 upperTick, uint128 liquidityAmount) 
        internal 
        view 
        returns (uint256 amount0, uint256 amount1) 
    {
        int24 currentTick = slot0.tick;
        
        // Calculate amounts based on whether current tick is in range
        if (currentTick < lowerTick) {
            // Current tick is below the range, only token0 is needed
            amount0 = _getAmount0ForLiquidity(lowerTick, upperTick, liquidityAmount);
        } else if (currentTick >= upperTick) {
            // Current tick is above the range, only token1 is needed
            amount1 = _getAmount1ForLiquidity(lowerTick, upperTick, liquidityAmount);
        } else {
            // Current tick is in range, both tokens are needed
            amount0 = _getAmount0ForLiquidity(currentTick, upperTick, liquidityAmount);
            amount1 = _getAmount1ForLiquidity(lowerTick, currentTick, liquidityAmount);
        }
    }

    function _getAmount0ForLiquidity(int24 lowerTick, int24 upperTick, uint128 liquidityAmount) 
        internal 
        pure 
        returns (uint256 amount0) 
    {
        // Ensure upperTick > lowerTick to avoid underflow
        require(upperTick > lowerTick, "Invalid tick range");
        
        // Simplified calculation - in a real implementation this would use proper sqrt price math
        uint256 tickDiff = uint256(uint24(upperTick - lowerTick));
        amount0 = uint256(liquidityAmount) * tickDiff / 1e6;
    }

    function _getAmount1ForLiquidity(int24 lowerTick, int24 upperTick, uint128 liquidityAmount) 
        internal 
        pure 
        returns (uint256 amount1) 
    {
        // Ensure upperTick > lowerTick to avoid underflow
        require(upperTick > lowerTick, "Invalid tick range");
        
        // Simplified calculation - in a real implementation this would use proper sqrt price math
        uint256 tickDiff = uint256(uint24(upperTick - lowerTick));
        amount1 = uint256(liquidityAmount) * tickDiff / 1e6;
    }

    function _updatePosition(address owner, int24 lowerTick, int24 upperTick, uint128 liquidityDelta) internal {
        bytes32 positionKey = keccak256(abi.encodePacked(owner, lowerTick, upperTick));
        Position.Info storage position = positions[positionKey];
        position.update(liquidityDelta);
    }

    function _updateTicks(int24 lowerTick, int24 upperTick, uint128 liquidityDelta) internal {
        ticks.update(lowerTick, liquidityDelta);
        ticks.update(upperTick, liquidityDelta);
    }

    function balance0() internal view returns (uint256 balance) {
        balance = IERC20(token0).balanceOf(address(this));
    }

    function balance1() internal view returns (uint256 balance) {
        balance = IERC20(token1).balanceOf(address(this));
    }
}
