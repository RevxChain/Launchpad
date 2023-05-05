// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

interface ISimpleScheduleVesting {

    function teamAmount()external view returns(uint);

    function claimed(address _user)external view returns(bool);

    function cliffTimestamp(uint _tier)external view returns(uint);

    function claim(address _user)external;
}  

interface IScheduleVesting {

    function teamAmount()external view returns(uint);

    function claimed(address _user, uint _cliffRound)external view returns(bool);

    function claimedAmount(address _user)external view returns(uint);

    function claim(address _user, uint _cliffRound)external;

    function _setupData(uint[30] memory _cliffTimestamp, uint[30] memory _cliffAmount)external;

    function _viewData(uint _tier, uint _cliffRound)external view returns(uint _timestamp, uint _amount);
}  

interface IScheduleVestingFactory {

    function createScheduleVesting(
        address _token,  
        address _managementAddress, 
        address _fundraiseAddress, 
        uint _teamAmount, 
        uint[6] memory _cliffTimestamp
    ) external returns(address _vestingAddress);

}

    
