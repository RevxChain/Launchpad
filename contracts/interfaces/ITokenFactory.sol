// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

interface IERC20Token {

    function initialize(
        address _liquidityVault,
        uint _vestingAmount,
        uint _liquidityAmount,
        address _minter
    ) external;

}   

interface ITokenFactory {

    function createToken(
        string calldata _name, 
        string calldata _symbol,
        uint _mintUnlock,
        uint _burnUnlock,
        address _operatorAddress
    ) external returns(address _address);

} 