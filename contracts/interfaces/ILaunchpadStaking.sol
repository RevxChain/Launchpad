// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

interface ILaunchpadStaking {

    function rewardPool()external view returns(uint);

    function lastUpdateRewardPool()external view returns(uint);

    function totalUsers(uint _tier)external view returns(uint);

    function deposit(uint _underlyingAmount, uint _lockDuration)external;

    function withdraw(uint _sTokenAmount)external;

    function updateRewardPool()external returns(uint);

    function _userInfo(address _user)external view returns(uint _tier, uint _stakedAmount);

    function _addPaymentTokens(uint _amount)external;

}