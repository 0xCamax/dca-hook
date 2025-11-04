// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../src/utils/Constants.sol";
import {HookMiner} from "@uniswap/v4-periphery/src/utils/HookMiner.sol";
import {Hooks, IHooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {PoolId} from "@uniswap/v4-core/src/types/PoolId.sol";
import {Commands} from "../src/utils/libraries/Commands.sol";
import {Actions} from "@uniswap/v4-periphery/src/libraries/Actions.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IV4Router} from "@uniswap/v4-periphery/src/interfaces/IV4Router.sol";
import {StateLibrary} from "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import {LiquidityMath, Window} from "../src/utils/libraries/LiquidityMath.sol";

contract Helpers is ArbitrumConstants {
    using StateLibrary for IPoolManager;

    PoolKey poolKey;
    PoolKey basePoolKey;
    PoolId poolId;

    function _swap(uint128 amountIn, bool zeroForOne) internal {
        bytes memory commands = abi.encodePacked(uint8(Commands.V4_SWAP));
        bytes memory actions =
            abi.encodePacked(uint8(Actions.SWAP_EXACT_IN_SINGLE), uint8(Actions.SETTLE_ALL), uint8(Actions.TAKE_ALL));

        bytes[] memory params = new bytes[](3);
        params[0] = abi.encode(
            IV4Router.ExactInputSingleParams({
                poolKey: poolKey,
                zeroForOne: zeroForOne,
                amountIn: amountIn,
                amountOutMinimum: 0,
                hookData: bytes("")
            })
        );

        params[1] = abi.encode(zeroForOne ? poolKey.currency0 : poolKey.currency1, amountIn);
        params[2] = abi.encode(zeroForOne ? poolKey.currency1 : poolKey.currency0, 0);

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(actions, params);

        uint256 deadline = block.timestamp + 60;

        if (!zeroForOne) {
            PERMIT2.approve(
                Currency.unwrap(poolKey.currency1), address(ROUTER), type(uint160).max, uint48(block.timestamp + 1 days)
            );
        }

        ROUTER.execute{value: zeroForOne ? amountIn : 0}(commands, inputs, deadline);
    }

    function _configurePoolKeys(uint24 fee, int24 spacing, address hook) internal {
        poolKey = PoolKey({
            currency0: Currency.wrap(address(0)), // ETH
            currency1: Currency.wrap(address(USDC)),
            fee: fee,
            tickSpacing: spacing,
            hooks: IHooks(hook)
        });

        basePoolKey = PoolKey({
            currency0: Currency.wrap(address(0)), // ETH
            currency1: Currency.wrap(address(USDC)),
            fee: 100,
            tickSpacing: 1,
            hooks: IHooks(address(0))
        });

        poolId = poolKey.toId();
    }

    function _setupApprovals(address hook) internal {
        USDC.approve(hook, type(uint256).max);
        USDC.approve(address(PERMIT2), type(uint256).max);
        PERMIT2.approve(address(USDC), address(POSITION_MANAGER), type(uint160).max, uint48(block.timestamp + 1 days));
    }

    function _initializePool() internal {
        (uint160 sqrtPrice,,,) = POOL_MANAGER.getSlot0(basePoolKey.toId());
        POOL_MANAGER.initialize(poolKey, sqrtPrice);
    }

    function _addLiquidity(int128 liquidity) internal {
        bytes memory actions =
            abi.encodePacked(uint8(Actions.MINT_POSITION), uint8(Actions.SETTLE_PAIR), uint8(Actions.SWEEP));
        bytes[] memory params = new bytes[](3);

        (uint160 price, int24 currentTick,,) = POOL_MANAGER.getSlot0(basePoolKey.toId());
        int24 tickLower = currentTick - 10;
        int24 tickUpper = currentTick + 10;

        params[0] =
            abi.encode(poolKey, tickLower, tickUpper, liquidity, type(int128).max, type(int128).max, msg.sender, "");
        params[1] = abi.encode(poolKey.currency0, poolKey.currency1);
        params[2] = abi.encode(poolKey.currency0, msg.sender);

        uint256 deadline = block.timestamp + 60;

        BalanceDelta amounts =
            LiquidityMath.getAmountsForLiquidity(price, Window(tickLower, tickUpper, liquidity, false));

        POSITION_MANAGER.modifyLiquidities{value: uint128(amounts.amount0())}(abi.encode(actions, params), deadline);
    }
}
