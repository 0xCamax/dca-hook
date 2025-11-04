// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {PoolId} from "@uniswap/v4-core/src/types/PoolId.sol";
import {BalanceDelta, toBalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {SqrtPriceMath} from "@uniswap/v4-core/src/libraries/SqrtPriceMath.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {SafeCast} from "@uniswap/v4-core/src/libraries/SafeCast.sol";

/// @notice Represents a liquidity window within a tick range
/// @dev Windows are used to manage concentrated liquidity across specific tick ranges
struct Window {
    /// @notice The lower tick boundary of the window
    int24 tickLower;
    /// @notice The upper tick boundary of the window
    int24 tickUpper;
    /// @notice The amount of liquidity in this window
    int128 liquidity;
    /// @notice Whether this window has been initialized
    bool initialized;
}

library LiquidityMath {
    using SafeCast for int256;
    /// @notice Computes asset delta for a given liquidity window

    function _getAmountsDelta(uint160 currentSqrtPrice, Window memory pos) private pure returns (BalanceDelta delta) {
        int24 tick = TickMath.getTickAtSqrtPrice(currentSqrtPrice);

        if (tick < pos.tickLower) {
            // current tick is below the passed range; liquidity can only become in range by crossing from left to
            // right, when we'll need _more_ currency0 (it's becoming more valuable) so user must provide it
            delta = toBalanceDelta(
                -SqrtPriceMath.getAmount0Delta(
                    TickMath.getSqrtPriceAtTick(pos.tickLower),
                    TickMath.getSqrtPriceAtTick(pos.tickUpper),
                    pos.liquidity
                ).toInt128(),
                0
            );
        } else if (tick < pos.tickUpper) {
            delta = toBalanceDelta(
                -SqrtPriceMath.getAmount0Delta(
                    currentSqrtPrice, TickMath.getSqrtPriceAtTick(pos.tickUpper), pos.liquidity
                ).toInt128(),
                -SqrtPriceMath.getAmount1Delta(
                    TickMath.getSqrtPriceAtTick(pos.tickLower), currentSqrtPrice, pos.liquidity
                ).toInt128()
            );
        } else {
            // current tick is above the passed range; liquidity can only become in range by crossing from right to
            // left, when we'll need _more_ currency1 (it's becoming more valuable) so user must provide it
            delta = toBalanceDelta(
                0,
                -SqrtPriceMath.getAmount1Delta(
                    TickMath.getSqrtPriceAtTick(pos.tickLower),
                    TickMath.getSqrtPriceAtTick(pos.tickUpper),
                    pos.liquidity
                ).toInt128()
            );
        }
    }

    /// @notice Returns amounts for a given liquidity window, negated for settlement
    function getAmountsForLiquidity(uint160 currentSqrtPrice, Window memory pos) internal pure returns (BalanceDelta) {
        return _getAmountsDelta(currentSqrtPrice, pos);
    }
}
