// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

interface IVestingOperator {

    function createSimpleScheduleVesting( 
        address management,
        address token,
        address fundraise,
        uint[6] memory cliffTimestamp,
        uint fundraiseStart,
        uint manageAmount
    ) external returns(address vestingAddress);

    function createScheduleVesting( 
        address management,
        address token,
        address fundraise,
        uint[30] memory cliffTimestamp, 
        uint[30] memory cliffAmount,
        uint fundraiseStart,
        uint manageAmount
    ) external returns(address vestingAddress);

    function createLinearVesting( 
        address tokenAddress,  
        address managementAddress, 
        address fundraiseAddress, 
        uint fundraiseStart,
        uint teamAmount, 
        uint vestingDuration,
        uint vestingStartTimestamp,
        uint vestingTeamStartTimestamp
    ) external returns(address vestingAddress);

    function createCliffLinearVesting( 
        address tokenAddress,  
        address managementAddress, 
        address fundraiseAddress, 
        uint fundraiseStart,
        uint teamAmount, 
        uint vestingDuration,
        uint[6] memory vestingStartTimestamp
    ) external returns(address vestingAddress);

}