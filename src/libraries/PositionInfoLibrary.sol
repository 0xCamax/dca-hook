// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {LiquidityMath} from "./LiquidityMath.sol";
import {Window} from "../contracts/GranularLiquidityPoolManager.sol";
import {AaveHelper, IPool, ReserveConfigDecoded} from "./AaveHelper.sol";
import {ERC20} from "@oz/contracts/token/ERC20/ERC20.sol";

/// @notice Stores basic information about a user’s position
struct PositionInfo {
    /// @notice Owner of the position
    address owner;
    address asset0;
    address asset1;
    /// @notice Lower tick boundary of the position
    int24 tickLower;
    /// @notice Upper tick boundary of the position
    int24 tickUpper;
    /// @notice The amount of liquidity in this position
    uint128 liquidity;
}

library PositionInfoLibrary {
    using PositionInfoLibrary for PositionInfo;

    function toWindow(PositionInfo memory info) internal pure returns (Window memory) {
        return Window(info.tickLower, info.tickUpper, int128(info.liquidity), true);
    }
}
