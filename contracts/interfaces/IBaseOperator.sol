// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

interface IBaseOperator {

    function tokenToAuditExternal(
        address _token,
        string calldata _name, 
        string calldata _symbol, 
        address _managementAddress
    ) external;

}   
