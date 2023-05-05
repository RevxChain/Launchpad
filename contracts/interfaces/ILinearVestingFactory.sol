// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

interface ILinearVesting {

    function teamAmount()external view returns(uint);

    function claimed(address _user)external view returns(bool);

    function cliffTimestamp(uint _tier)external view returns(uint);

    function claim(address _user)external;
}  


interface ILinearVestingFactory {

    function createLinearVesting(
        address _token,  
        address _managementAddress, 
        address _fundraiseAddress, 
        uint _teamAmount, 
        uint _vestingDuration,
        uint[6] memory _vestingStartTimestamp
    ) external returns(address _vestingAddress);

}

    
