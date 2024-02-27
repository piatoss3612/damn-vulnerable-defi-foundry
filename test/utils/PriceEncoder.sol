// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

library PriceEncoder {
    // returns the sqrt price as a 64x96
    function encodePriceSqrt(uint256 reserve1, uint256 reserve0) external pure returns (uint160) {
        uint256 sqrtPriceX96 = sqrtPrice(reserve1, reserve0);
        return uint160(sqrtPriceX96 * (2 ** 96) / 10 ** 9); // Multiply by 2^96 to match the 64x96 format
    }

    // Helper function to calculate square root
    function sqrtPrice(uint256 reserve1, uint256 reserve0) internal pure returns (uint256) {
        require(reserve0 > 0 && reserve1 > 0, "Reserves must be greater than 0");
        uint256 x = reserve1 * 10 ** 18 / reserve0; // Scale reserve1 to match reserve0 precision
        uint256 sqrtX = sqrt(x);
        return sqrtX;
    }

    // Babylonian method for calculating square root
    // Based on https://ethereum.stackexchange.com/a/29148
    function sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}
