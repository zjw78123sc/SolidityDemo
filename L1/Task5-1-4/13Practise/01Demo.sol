// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
contract Demo {
    //当给返回值赋值后，并且有个return，以最后的return为主
    function test() public pure returns (uint256 mul) {
        uint256 a = 10;
        // mul = 100;
        return a;
    }
}