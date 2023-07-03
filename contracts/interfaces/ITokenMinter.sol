// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

interface ITokenMinter {

    function defaultTokenMintPrice()external view returns(uint);

    function ownTokenMintPrice()external view returns(uint);

    function createOwnToken(
        string calldata _name, 
        string calldata _symbol, 
        uint _totalSupply, 
        uint _decimals
    ) external returns(address _tokenAddress);

    function updatePrice(uint _priceTypeId, uint _newValue)external;

}