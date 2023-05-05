// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

interface IAccessControlOperator {

    function viewOperatorAddress()external view returns(address);

    function DISPOSABLE_CALLER()external view returns(bytes32);

    function DEFAULT_CALLER()external view returns(bytes32);

    function setupOperator(address _operatorAdress)external;
}   