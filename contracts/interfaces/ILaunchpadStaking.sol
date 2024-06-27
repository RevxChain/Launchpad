// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

interface ILaunchpadStaking {

    function rewardPool() external view returns(uint);

    function lastUpdateRewardPool() external view returns(uint);

    function totalUsers(uint tier) external view returns(uint);

    function deposit(uint underlyingAmount, uint lockDuration) external returns(uint userShare);

    function withdraw(uint sTokenAmount) external returns(uint underlyingAmount);

    function updateRewardPool() external returns(uint);

    function userInfo(address user) external view returns(UserInfo memory);

    function addPaymentTokens(uint amount) external;

    struct UserInfo {
        uint tier; 
        uint stakedAmount; 
        uint unlockTime;
    }

}