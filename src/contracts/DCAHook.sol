// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./BaseHook.sol";
import "../utils/Errors.sol";

abstract contract DCAHook is BaseHook {
    constructor(address _poolManager) BaseHook(_poolManager) {}

    //Block addLiquidity, only add from hook, important for JITLiquidity
    function _beforeAddLiquidity(address, PoolKey calldata, ModifyLiquidityParams calldata, bytes calldata)
        internal
        override
        returns (bytes4)
    {
        revert AddLiquidityFromHook();
    }

    //Revert a swap direction depending on config
    function _beforeSwap(address sender, PoolKey calldata key, SwapParams calldata params, bytes calldata hookData)
        internal
        override
        returns (bytes4, BeforeSwapDelta, uint24)
    {}

    //Access, for DCA setup
    function deposit(PoolKey calldata key, ModifyLiquidityParams calldata params, bytes calldata hookData) external {
        //MOST ADD ONLY ONE TOKEN
    }
}
