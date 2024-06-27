// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

interface IOwnTokenSample {

    function mintCallReceived() external view returns(
        string memory name, 
        string memory symbol, 
        uint totalSupply, 
        uint decimals
    );

}