// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

interface ILiquidityVault {

    function liquidityRouterAddress() external view returns(address);

    function _initializeNewToken(
        address token, 
        address managementAddress, 
        uint tokensAmount, 
        uint fundraiseStart,
        uint liquidityLockDuration
    ) external payable;

    function _liquidityLockDurationSet(address token, uint liquidityLockDuration) external;

    function addLiquidity(address token) external;

    function removeLiquidity(address token, uint amount) external;

    function updateRouterAddress(address newRouterAddress) external;

}