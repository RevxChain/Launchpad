// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

interface ILiquidStakingToken {

    function mint(address account, uint256 amount) external;

    function burn(uint256 amount) external;

    function burnFrom(address account, uint256 amount) external;

}