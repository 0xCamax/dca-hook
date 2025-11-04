// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract HookDeployer {
    event HookDeployed(address addr);

    function deployHook(bytes calldata creationCode, bytes calldata constructorArgs, bytes32 salt)
        public
        returns (address addr)
    {
        bytes memory creationCodeWithArgs = abi.encodePacked(creationCode, constructorArgs);

        assembly {
            addr := create2(0, add(creationCodeWithArgs, 0x20), mload(creationCodeWithArgs), salt)
        }

        require(addr != address(0), "HookDeploy: Failed");
        emit HookDeployed(addr);
    }

    function safeDeploy(
        bytes calldata creationCode,
        bytes calldata constructorArgs,
        bytes32 salt,
        address expectedAddress,
        uint160[] calldata flags
    ) external returns (address addr) {
        validateHookAddress(expectedAddress, flags);
        addr = deployHook(creationCode, constructorArgs, salt);
        require(addr == expectedAddress, "HookDeployer: Returned wrong address");
    }

    function validateHookAddress(address expectedAddress, uint160[] calldata flags) public pure {
        for (uint8 i = 0; i < flags.length; i++) {
            if (!hasPermission(expectedAddress, flags[i])) {
                revert("Missing flags");
            }
        }
    }

    // This results in a more human friendly view in IDE and avoids `stak to deep`
    function getPermissions(address hook)
        external
        pure
        returns (
            bool beforeInitialize,
            bool afterInitialize,
            bool beforeAddLiquidity,
            bool afterAddLiquidity,
            bool beforeRemoveLiquidity,
            bool afterRemoveLiquidity,
            bool beforeSwap,
            bool afterSwap,
            bool beforeDonate,
            bool afterDonate,
            bool beforeSwapReturnDelta,
            bool afterSwapReturnDelta,
            bool afterAddLiquidityReturnDelta,
            bool afterRemoveLiquidityReturnDelta
        )
    {
        assembly {
            beforeInitialize := iszero(iszero(and(hook, shl(13, 1))))
            afterInitialize := iszero(iszero(and(hook, shl(12, 1))))
            beforeAddLiquidity := iszero(iszero(and(hook, shl(11, 1))))
            afterAddLiquidity := iszero(iszero(and(hook, shl(10, 1))))
            beforeRemoveLiquidity := iszero(iszero(and(hook, shl(9, 1))))
            afterRemoveLiquidity := iszero(iszero(and(hook, shl(8, 1))))
            beforeSwap := iszero(iszero(and(hook, shl(7, 1))))
            afterSwap := iszero(iszero(and(hook, shl(6, 1))))
            beforeDonate := iszero(iszero(and(hook, shl(5, 1))))
            afterDonate := iszero(iszero(and(hook, shl(4, 1))))
            beforeSwapReturnDelta := iszero(iszero(and(hook, shl(3, 1))))
            afterSwapReturnDelta := iszero(iszero(and(hook, shl(2, 1))))
            afterAddLiquidityReturnDelta := iszero(iszero(and(hook, shl(1, 1))))
            afterRemoveLiquidityReturnDelta := iszero(iszero(and(hook, 1)))
        }
    }

    function hasPermission(address hook, uint160 flag) public pure returns (bool) {
        return uint160(hook) & flag != 0;
    }

    function getFlag(string memory name) external pure returns (uint160) {
        if (keccak256(bytes(name)) == keccak256("BEFORE_INITIALIZE")) {
            return uint160(1) << 13;
        }
        if (keccak256(bytes(name)) == keccak256("AFTER_INITIALIZE")) {
            return uint160(1) << 12;
        }

        if (keccak256(bytes(name)) == keccak256("BEFORE_ADD_LIQUIDITY")) {
            return uint160(1) << 11;
        }
        if (keccak256(bytes(name)) == keccak256("AFTER_ADD_LIQUIDITY")) {
            return uint160(1) << 10;
        }

        if (keccak256(bytes(name)) == keccak256("BEFORE_REMOVE_LIQUIDITY")) {
            return uint160(1) << 9;
        }
        if (keccak256(bytes(name)) == keccak256("AFTER_REMOVE_LIQUIDITY")) {
            return uint160(1) << 8;
        }

        if (keccak256(bytes(name)) == keccak256("BEFORE_SWAP")) {
            return uint160(1) << 7;
        }
        if (keccak256(bytes(name)) == keccak256("AFTER_SWAP")) {
            return uint160(1) << 6;
        }

        if (keccak256(bytes(name)) == keccak256("BEFORE_DONATE")) {
            return uint160(1) << 5;
        }
        if (keccak256(bytes(name)) == keccak256("AFTER_DONATE")) {
            return uint160(1) << 4;
        }

        if (keccak256(bytes(name)) == keccak256("BEFORE_SWAP_RETURNS_DELTA")) {
            return uint160(1) << 3;
        }
        if (keccak256(bytes(name)) == keccak256("AFTER_SWAP_RETURNS_DELTA")) {
            return uint160(1) << 2;
        }

        if (keccak256(bytes(name)) == keccak256("AFTER_ADD_LIQUIDITY_RETURNS_DELTA")) return uint160(1) << 1;
        if (keccak256(bytes(name)) == keccak256("AFTER_REMOVE_LIQUIDITY_RETURNS_DELTA")) return uint160(1) << 0;

        revert("Unknown flag");
    }
}
