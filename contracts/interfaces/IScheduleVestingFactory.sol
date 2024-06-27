// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

interface ISimpleScheduleVesting {

    function teamAmount() external view returns(uint);

    function claimed(address user) external view returns(bool);

    function cliffTimestamp(uint tier) external view returns(uint);

    function claim(address user) external returns(uint claimedAmount);
}  

interface IScheduleVesting {

    function teamAmount() external view returns(uint);

    function claimed(address user, uint cliffRound) external view returns(bool);

    function claimedAmount(address user) external view returns(uint);

    function claim(address user, uint cliffRound) external returns(uint claimedAmount);

    function _setupData(uint[30] memory cliffTimestamp, uint[30] memory cliffAmount) external;

    function _viewData(uint tier, uint cliffRound) external view returns(uint timestamp, uint amount);
}  

interface IScheduleVestingFactory {

    function createScheduleVesting(
        address token,  
        address managementAddress, 
        address fundraiseAddress, 
        uint teamAmount, 
        uint[6] memory cliffTimestamp
    ) external returns(address vestingAddress);

}

    
