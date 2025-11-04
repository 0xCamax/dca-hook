// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {HookDeployer} from "./HookDeployer.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {IERC20} from "@oz/contracts/token/ERC20/IERC20.sol";
import {IWETH9} from "../interfaces/IWETH9.sol";
import {IPool} from "@aave/src/contracts/interfaces/IPool.sol";
import {IUniversalRouter} from "../interfaces/IUniversalRouter.sol";
import {IPermit2} from "@permit/interfaces/IPermit2.sol";
import {IPositionManager} from "@uniswap/v4-periphery/src/interfaces/IPositionManager.sol";
import {IAToken} from "@aave/src/contracts/interfaces/IAToken.sol";

abstract contract ArbitrumConstants {
    HookDeployer internal constant HOOK_DEPLOYER = HookDeployer(0x7F2A8D28Ea33Fde8c5f2F831EB779B11AB39E1d9);
    IERC20 public constant USDC = IERC20(0xaf88d065e77c8cC2239327C5EDb3A432268e5831);
    IWETH9 public constant WETH = IWETH9(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);
    IPoolManager public constant POOL_MANAGER = IPoolManager(0x360E68faCcca8cA495c1B759Fd9EEe466db9FB32);
    IPool public constant AAVE_POOL = IPool(0x794a61358D6845594F94dc1DB02A252b5b4814aD);
    IUniversalRouter public constant ROUTER = IUniversalRouter(0xA51afAFe0263b40EdaEf0Df8781eA9aa03E381a3);
    IPermit2 public constant PERMIT2 = IPermit2(0x000000000022D473030F116dDEE9F6B43aC78BA3);
    IPositionManager public constant POSITION_MANAGER = IPositionManager(0xd88F38F930b7952f2DB2432Cb002E7abbF3dD869);
    IAToken public constant aUSDC = IAToken(0x724dc807b04555b71ed48a6896b6F41593b8C637);
    IAToken public constant aETH = IAToken(0xe50fA9b3c56FfB159cB0FCA61F5c9D750e8128c8);
}
