// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Tick} from "./Tick.sol";

library Position {
    struct Info {
        uint128 liquidity;
    }

    function update(Info storage self, uint128 liquidityDelta) internal {
        uint128 liquidityBefore = self.liquidity;
        uint128 liquidityAfter = liquidityBefore + liquidityDelta;
        self.liquidity = liquidityAfter;
    }

    /**
     *
     * @param self Position
     * @param owner Allen
     * @param lowerTick The lower range of the position
     * @param upperTick The upper range of the position
     */
    function get(mapping(bytes32 => Info) storage self, address owner, int24 lowerTick, int24 upperTick)
        internal
        view
        returns (Info storage position)
    {
        position = self[ //Hashed: three keys, if individually stored it will take 32 bytes each since sol stores values in 32 byte slots, but it won't happen now
        keccak256(abi.encodePacked(owner, lowerTick, upperTick))];
    }
}
