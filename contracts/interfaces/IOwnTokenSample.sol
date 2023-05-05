// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

interface IOwnTokenSample {

    function mintCallReceived()external view returns(string memory _name, string memory _symbol, uint _totalSupply, uint _decimals);


}