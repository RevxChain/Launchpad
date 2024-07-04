// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract LiquidStakingToken is ERC20Burnable {

    address public immutable factory;

    constructor(address _factory) ERC20("LiquidStakingToken", "LST") {
        factory = _factory;
    }

    function mint(address account, uint amount) external {
        require(msg.sender == factory, "LiquidStakingToken: forbidden");
        _mint(account, amount);
    }
}