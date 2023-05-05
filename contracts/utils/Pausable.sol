// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

contract Pausable {

    bool private pause;

    error Paused();

    modifier paused(){
        require(pause == false, "Pausable: Paused");
        _;
    }

    function _changeOver()internal {
        pause = !pause;
    }
}



