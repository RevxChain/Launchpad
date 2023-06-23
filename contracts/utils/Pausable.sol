// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

contract Pausable {

    bool private pause;

    modifier paused(){
        require(pause == false, "Pausable: paused");
        _;
    }

    function _changeOver()internal {
        pause = !pause;
    }
}



