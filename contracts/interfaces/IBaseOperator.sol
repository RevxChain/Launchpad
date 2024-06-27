// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

interface IBaseOperator {

    function confirmTokenToFundraise(address token, address minter) external;

    function rejectTokenToFundraise(address token) external;

    function createFundraise( 
        address token,
        uint[3] memory amounts, 
        uint[5] memory oneTokenPrice, 
        uint fundraiseStart,
        uint liquidityLockDuration,
        address minter 
    ) external payable returns(address managementAddress);

    function fundraiseParticipate(
        address token, 
        uint amount, 
        address stablecoinAddress
    ) external;

    function cancelFundraise(address token) external;

    function refund(address token, address stablecoinAddress) external;

    function createSimpleScheduleVesting( 
        address token,
        uint[6] memory cliffTimestamp
    ) external returns(address vestingAddress);

    function createScheduleVesting( 
        address token,
        uint[30] memory cliffTimestamp, 
        uint[30] memory cliffAmount
    ) external returns(address vestingAddress);

    function createLinearVesting( 
        address token,
        uint vestingStartTimestamp,
        uint vestingTeamStartTimestamp,
        uint vestingDuration
    ) external returns(address vestingAddress);

    function createCliffLinearVesting( 
        address token,
        uint vestingDuration,
        uint[6] memory vestingStartTimestamp
    ) external returns(address vestingAddress);

    function changeOver() external;

    function tokenToAuditExternal(
        address token,
        string calldata name, 
        string calldata symbol, 
        address managementAddress
    ) external;

}   
