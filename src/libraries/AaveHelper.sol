// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IPool} from "@aave/src/contracts/interfaces/IPool.sol";
import {IAaveOracle} from "@aave/src/contracts/interfaces/IAaveOracle.sol";
import {IPoolAddressesProvider} from "@aave/src/contracts/interfaces/IPoolAddressesProvider.sol";
import {ICreditDelegationToken} from "@aave/src/contracts/interfaces/ICreditDelegationToken.sol";
import {IAToken} from "@aave/src/contracts/interfaces/IAToken.sol";
import {IERC20} from "@oz/contracts/token/ERC20/IERC20.sol";
import {IVariableDebtToken} from "@aave/src/contracts/interfaces/IVariableDebtToken.sol";
import {DataTypes} from "@aave/src/contracts/protocol/libraries/types/DataTypes.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";

struct ModifyLiquidityAave {
    address to;
    address asset0;
    address asset1;
    BalanceDelta delta;
}

struct SwapParamsAave {
    address asset0;
    address asset1;
    BalanceDelta delta;
}

struct AssetData {
    address aTokenAddress;
    address variableDebtTokenAddress;
    uint128 liquidityIndex;
    uint128 variableBorrowIndex;
    uint128 currentLiquidityRate;
    uint128 currentVariableBorrowRate;
    uint40 lastUpdateTimestamp;
}

struct PoolMetrics {
    uint256 totalCollateral;
    uint256 totalDebt;
    uint256 availableBorrows;
    uint256 currentLiquidationThreshold;
    uint256 ltv;
    uint256 healthFactor;
}

struct ReserveConfigDecoded {
    uint256 ltv;
    uint256 liquidationThreshold;
    uint256 liquidationBonus;
    uint256 decimals;
    bool isActive;
    bool isFrozen;
    bool borrowingEnabled;
    bool isPaused;
    bool isolationModeBorrowingEnabled;
    bool siloedBorrowingEnabled;
    bool flashloanEnabled;
    uint256 reserveFactor;
    uint256 borrowCap;
    uint256 supplyCap;
    uint256 liquidationProtocolFee;
    uint256 debtCeiling;
}

library AaveHelper {
    using AaveHelper for IPool;

    uint256 private constant DUST = 1_000;

    function supplyToAave(IPool pool, address asset, uint128 amount) internal {
        IERC20(asset).approve(address(pool), amount);
        pool.supply(asset, amount, address(this), 0);
    }

    function safeWithdraw(IPool pool, address asset, uint128 amount, address to) internal {
        try pool.withdraw(asset, amount, address(this)) {
            IERC20(asset).transfer(to, amount - _handleResidualDebt(pool, asset));
        } catch {
            _handleFallbackWithdraw(pool, asset, to, amount);
        }
    }

    function _handleResidualDebt(IPool pool, address asset) private returns (uint256 repaid) {
        uint256 debt = getVariableDebtBalance(pool, asset);
        if (debt < DUST && debt != 0) {
            repaid = repay(pool, asset, debt, true);
        }
    }

    function _handleFallbackWithdraw(IPool pool, address asset, address to, uint256 amount) private {
        uint256 debt = getVariableDebtBalance(pool, asset);
        uint256 aBalance = getATokenBalance(pool, asset);
        if (debt < DUST && debt != 0) {
            if (amount < aBalance) {
                amount -= repayWithATokens(pool, asset, debt, true);
            } else {
                repay(pool, asset, debt, true);
            }
        }

        pool.withdraw(asset, amount < aBalance ? amount : aBalance, to);
    }

    function modifyLiquidity(IPool pool, ModifyLiquidityAave memory params) internal {
        int128 amount0 = params.delta.amount0();
        int128 amount1 = params.delta.amount1();

        // Supply negative amounts (using helper)
        if (amount0 < 0) supplyToAave(pool, params.asset0, uint128(-amount0));
        if (amount1 < 0) supplyToAave(pool, params.asset1, uint128(-amount1));

        // Withdraw positive amounts (direct calls)
        if (amount0 > 0) safeWithdraw(pool, params.asset0, uint128(amount0), params.to);
        if (amount1 > 0) safeWithdraw(pool, params.asset1, uint128(amount1), params.to);
    }

    function borrow(IPool pool, address asset, uint256 amount) internal {
        pool.setUserUseReserveAsCollateral(asset, true);
        pool.borrow(asset, amount, 2, 0, address(this));
    }

    function repay(IPool pool, address asset, uint256 amount, bool max) internal returns (uint256) {
        IERC20(asset).approve(address(pool), max ? DUST : amount);
        return pool.repay(asset, max ? type(uint256).max : amount, 2, address(this));
    }

    function repayWithATokens(IPool pool, address asset, uint256 amount, bool max) internal returns (uint256) {
        return pool.repayWithATokens(asset, max ? type(uint256).max : amount, 2);
    }

    function getAssetReserveData(IPool pool, address asset)
        internal
        view
        returns (DataTypes.ReserveDataLegacy memory)
    {
        return pool.getReserveData(asset);
    }

    function getReserveConfiguration(IPool pool, address asset)
        internal
        view
        returns (ReserveConfigDecoded memory cfg)
    {
        DataTypes.ReserveConfigurationMap memory m = pool.getConfiguration(asset);

        uint256 data = m.data;

        cfg.ltv = (data >> 0) & 0xFFFF; // bits 0-15
        cfg.liquidationThreshold = (data >> 16) & 0xFFFF; // bits 16-31
        cfg.liquidationBonus = (data >> 32) & 0xFFFF; // bits 32-47
        cfg.decimals = (data >> 48) & 0xFF; // bits 48-55

        cfg.isActive = ((data >> 56) & 1) != 0;
        cfg.isFrozen = ((data >> 57) & 1) != 0;
        cfg.borrowingEnabled = ((data >> 58) & 1) != 0;
        cfg.isPaused = ((data >> 60) & 1) != 0;
        cfg.isolationModeBorrowingEnabled = ((data >> 61) & 1) != 0;
        cfg.siloedBorrowingEnabled = ((data >> 62) & 1) != 0;
        cfg.flashloanEnabled = ((data >> 63) & 1) != 0;

        cfg.reserveFactor = (data >> 64) & 0xFFFF; // bits 64-79
        cfg.borrowCap = (data >> 80) & ((1 << 36) - 1); // bits 80-115
        cfg.supplyCap = (data >> 116) & ((1 << 36) - 1); // bits 116-151
        cfg.liquidationProtocolFee = (data >> 152) & 0xFFFF; // bits 152-167
        cfg.debtCeiling = (data >> 212) & ((1 << 40) - 1); // bits 212-251
    }

    /**
     * @dev Get comprehensive asset data from Aave
     */
    function getAssetData(IPool pool, address asset) internal view returns (AssetData memory data) {
        DataTypes.ReserveDataLegacy memory d = pool.getReserveData(asset);
        data.liquidityIndex = d.liquidityIndex;
        data.variableBorrowIndex = d.variableBorrowIndex;
        data.currentLiquidityRate = d.currentLiquidityRate;
        data.currentVariableBorrowRate = d.currentVariableBorrowRate;
        data.lastUpdateTimestamp = d.lastUpdateTimestamp;
        data.aTokenAddress = pool.getReserveAToken(asset);
        data.variableDebtTokenAddress = pool.getReserveVariableDebtToken(asset);
    }

    /**
     * @dev Get pool's current metrics from Aave
     */
    function getPoolMetrics(IPool pool) internal view returns (PoolMetrics memory metrics) {
        (
            metrics.totalCollateral,
            metrics.totalDebt,
            metrics.availableBorrows,
            metrics.currentLiquidationThreshold,
            metrics.ltv,
            metrics.healthFactor
        ) = pool.getUserAccountData(address(this));
    }

    /**
     * @dev Get current aToken balance for an asset
     */
    function getATokenBalance(IPool pool, address asset) internal view returns (uint256 balance) {
        AssetData memory data = getAssetData(pool, asset);
        if (data.aTokenAddress != address(0)) {
            balance = IAToken(data.aTokenAddress).balanceOf(address(this));
        }
    }

    /**
     * @dev Get current variable debt balance for an asset
     */
    function getVariableDebtBalance(IPool pool, address asset) internal view returns (uint256 balance) {
        AssetData memory data = getAssetData(pool, asset);
        if (data.variableDebtTokenAddress != address(0)) {
            balance = IERC20(data.variableDebtTokenAddress).balanceOf(address(this));
        }
    }

    /**
     * @dev Check if asset can be used as collateral
     */
    function canUseAsCollateral(IPool pool, address asset) internal view returns (bool) {
        AssetData memory data = getAssetData(pool, asset);
        return data.aTokenAddress != address(0) && data.currentLiquidityRate > 0;
    }

    function getAssetsPrices(IPool pool, address[] memory assets) internal view returns (uint256[] memory) {
        IAaveOracle oracle = IAaveOracle(pool.ADDRESSES_PROVIDER().getPriceOracle());
        return oracle.getAssetsPrices(assets);
    }
}