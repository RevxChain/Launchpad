// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

interface ILiquidityVault {

    function liquidityRouterAddress()external view returns(address);

    function _initializeNewToken(
        address _token, 
        address _managementAddress, 
        uint _tokensAmount, 
        uint _fundraiseStart,
        uint _liquidityLockDuration
    ) external payable;

    function _liquidityLockDurationSet(address _token, uint _liquidityLockDuration)external;

    function addLiquidity(address _token)external;

    function removeLiquidity(address _token, uint _amount)external;

    function updateRouterAddress(address _newRouterAddress)external;

}