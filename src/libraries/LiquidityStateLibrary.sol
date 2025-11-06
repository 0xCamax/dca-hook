// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Window} from "../contracts/GranularLiquidityPoolManager.sol";
import {IPoolManager, ModifyLiquidityParams} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {Pool} from "@uniswap/v4-core/src/libraries/Pool.sol";
import {TickBitmap} from "@uniswap/v4-core/src/libraries/TickBitmap.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";

library LiquidityStateLibrary {
    function getWindows(Pool.State storage state, int24 currentTick, int24 spacing, bool zeroForOne)
        internal
        view
        returns (Window memory active, Window memory next)
    {
        active = getActiveWindow(state, currentTick, spacing);
        next = _nextNearestWindow(
            state, zeroForOne ? active.tickLower : active.tickUpper, spacing, zeroForOne, active.liquidity
        );
    }

    function getActiveWindow(Pool.State storage state, int24 currentTick, int24 spacing)
        internal
        view
        returns (Window memory window)
    {
        int24 base = currentTick / spacing;
        if (currentTick < 0 && currentTick % spacing != 0) {
            base -= 1;
        }
        window.tickLower = base * spacing;
        window.tickUpper = window.tickLower + spacing;
        window.liquidity = int128(state.liquidity);
    }

    function _nextNearestWindow(Pool.State storage state, int24 tick, int24 spacing, bool zeroForOne, int128 liquidity)
        internal
        view
        returns (Window memory window)
    {
        uint8 MAX_ITERATIONS = 2;
        int24 currentTick = tick;

        for (uint8 i = 0; i < MAX_ITERATIONS; i++) {
            (int24 nearestTick, bool initialized) =
                TickBitmap.nextInitializedTickWithinOneWord(state.tickBitmap, currentTick, spacing, zeroForOne);

            if (!initialized) {
                currentTick = zeroForOne ? nearestTick - spacing : nearestTick + spacing;
                continue;
            }

            int128 liqNet = state.ticks[nearestTick].liquidityNet;

            if (zeroForOne) {
                return _buildWindowZeroForOne(tick, nearestTick, spacing, liquidity, liqNet);
            } else {
                return _buildWindowOneForZero(tick, nearestTick, spacing, liquidity, liqNet);
            }
        }

        // This point should not be reached in normal operation
        // Consider reverting or returning a default window based on your requirements
        revert("No initialized tick found within search range");
    }

    function _buildWindowZeroForOne(int24 tick, int24 nearestTick, int24 spacing, int128 liquidity, int128 liqNet)
        private
        pure
        returns (Window memory window)
    {
        bool hasLiquidity = liqNet > 0 && liquidity > 0;

        window.liquidity = hasLiquidity ? liquidity : liquidity - liqNet;
        window.tickUpper = hasLiquidity ? tick : nearestTick;
        window.tickLower = hasLiquidity ? nearestTick : nearestTick - spacing;
    }

    function _buildWindowOneForZero(int24 tick, int24 nearestTick, int24 spacing, int128 liquidity, int128 liqNet)
        private
        pure
        returns (Window memory window)
    {
        bool hasLiquidity = liqNet < 0 && liquidity > 0;

        window.liquidity = hasLiquidity ? liquidity : liquidity + liqNet;
        window.tickLower = hasLiquidity ? tick : nearestTick;
        window.tickUpper = hasLiquidity ? nearestTick : nearestTick + spacing;
    }
}
