// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

interface ILiquidityRouter {

    function addLiquidityExternal(
        address _token, 
        uint _tokenAmount, 
        uint _burn,
        bytes calldata _data
    ) external payable returns(
        uint _amountToken, 
        uint _amountETH, 
        uint _liquidity, 
        address _pairAddress
    );

}