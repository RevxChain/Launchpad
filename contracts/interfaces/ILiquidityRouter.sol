// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

interface ILiquidityRouter {

    function addLiquidityExternal(
        address token, 
        uint tokenAmount, 
        uint burn,
        bytes calldata data
    ) external payable returns(
        uint amountToken, 
        uint amountETH, 
        uint liquidity, 
        address pairAddress
    );

}