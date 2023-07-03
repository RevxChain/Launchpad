// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

interface IBaseOperator {

    function confirmTokenToFundraise(address _token, address _minter)external;

    function rejectTokenToFundraise(address _token)external;

    function createFundraise( 
        address _token,
        uint[3] memory _amounts, 
        uint[5] memory _oneTokenPrice, 
        uint _fundraiseStart,
        uint _liquidityLockDuration,
        address _minter 
    ) external payable returns(address _managementAddress);

    function fundraiseParticipate(
        address _token, 
        uint _amount, 
        address _stablecoinAddress
    ) external;

    function cancelFundraise(address _token)external;

    function refund(address _token, address _stablecoinAddress)external;

    function createSimpleScheduleVesting( 
        address _token,
        uint[6] memory _cliffTimestamp
    ) external returns(address _vestingAddress);

    function createScheduleVesting( 
        address _token,
        uint[30] memory _cliffTimestamp, 
        uint[30] memory _cliffAmount
    ) external returns(address _vestingAddress);

    function createLinearVesting( 
        address _token,
        uint _vestingStartTimestamp,
        uint _vestingTeamStartTimestamp,
        uint _vestingDuration
    ) external returns(address _vestingAddress);

    function createCliffLinearVesting( 
        address _token,
        uint _vestingDuration,
        uint[6] memory _vestingStartTimestamp
    ) external returns(address _vestingAddress);

    function changeOver()external;

    function tokenToAuditExternal(
        address _token,
        string calldata _name, 
        string calldata _symbol, 
        address _managementAddress
    ) external;

}   
