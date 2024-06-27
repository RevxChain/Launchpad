// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract LaunchpadToken is ERC20Burnable {

    constructor(address _distributionAddress, uint _distributionAmount) ERC20("LaunchpadToken", "LToken") {
        _mint(_distributionAddress, _distributionAmount);
    }
}

