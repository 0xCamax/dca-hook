// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

struct DCA {
    address owner;
    uint160 targetPrice;
    bool zeroForOne;
    uint160 liquidity;
}