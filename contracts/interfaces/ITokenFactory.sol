// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

interface IERC20Token {

    function initialize(
        address liquidityVault,
        uint vestingAmount,
        uint liquidityAmount,
        address minter
    ) external;

}   

interface ITokenFactory {

    function createToken(
        string calldata name, 
        string calldata symbol,
        uint mintUnlock,
        uint burnUnlock,
        address operatorAddress
    ) external returns(address tokenAddress);

} 