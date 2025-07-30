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
}
