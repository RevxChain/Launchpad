// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

interface ITokenMinter {

    function defaultTokenMintPrice() external view returns(uint);

    function ownTokenMintPrice() external view returns(uint);

    function createOwnToken(
        string calldata name, 
        string calldata symbol, 
        uint totalSupply, 
        uint decimals
    ) external returns(address tokenAddress);

    function updatePrice(uint priceTypeId, uint newValue) external;

}