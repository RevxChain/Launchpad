// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/AccessControl.sol";

import "./IAccessControlOperator.sol";

contract AccessControlOperator is IAccessControlOperator, AccessControl {

    address private operatorAddress;

    bytes32 public constant DISPOSABLE_CALLER = keccak256("DISPOSABLE_CALLER");
    bytes32 public constant DEFAULT_CALLER = keccak256("DEFAULT_CALLER");

    constructor() {
        _grantRole(DISPOSABLE_CALLER, tx.origin); 
    }

    function getOperatorAddress() public view returns(address){
        return operatorAddress;
    }

    function setupOperator(address _operatorAdress) external onlyRole(DISPOSABLE_CALLER){
        require(_operatorAdress == address(0), "AccessControlOperator: Operator address has set already");
        require(_operatorAdress != address(0), "AccessControlOperator: Operator zero address");
        require(_operatorAdress != address(this), "AccessControlOperator: Operator wrong address");
        _grantRole(DEFAULT_CALLER, _operatorAdress);
        operatorAddress = _operatorAdress;
    }

}