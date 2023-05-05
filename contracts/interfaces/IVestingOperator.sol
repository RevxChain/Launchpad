// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

interface IVestingOperator {

    function createSimpleScheduleVesting( 
        address _management,
        address _token,
        address _fundraise,
        uint[6] memory _cliffTimestamp,
        uint _fundraiseStart,
        uint _manageAmount
    ) external returns(address _vestingAddress);

    function createScheduleVesting( 
        address _management,
        address _token,
        address _fundraise,
        uint[30] memory _cliffTimestamp, 
        uint[30] memory _cliffAmount,
        uint _fundraiseStart,
        uint _manageAmount
    ) external returns(address _vestingAddress);

    function createLinearVesting( 
        address _tokenAddress,  
        address _managementAddress, 
        address _fundraiseAddress, 
        uint _fundraiseStart,
        uint _teamAmount, 
        uint _vestingDuration,
        uint _vestingStartTimestamp,
        uint _vestingTeamStartTimestamp
    ) external returns(address _vestingAddress);

    function createCliffLinearVesting( 
        address _tokenAddress,  
        address _managementAddress, 
        address _fundraiseAddress, 
        uint _fundraiseStart,
        uint _teamAmount, 
        uint _vestingDuration,
        uint[6] memory _vestingStartTimestamp
    ) external returns(address _vestingAddress);

    

}