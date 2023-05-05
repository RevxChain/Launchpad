// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

interface IFundraise {

    function actualTokensAmount()external view returns(uint);

    function actualAllocation()external view returns(uint);

    function actualTierRound()external view returns(uint);

    function totalAmount()external view returns(uint);

    function fundraiseStart()external view returns(uint);

    function vestingStart()external view returns(uint);

    function oneTokenPrice(uint _tier)external view returns(uint);

    function participate(address _user, uint _amount, address _stablecoinAddress)external returns(uint _underlyingAmount);

    function _userData(address _user)external view returns(uint _tier, uint _totalAllocation, uint _allocation);

}

interface IFundraiseFactory {

    function fundraiseAddress(address _token)external view returns(address);

    function createFundraise(
        address _token, 
        uint _totalAmount, 
        uint[5] memory _oneTokenPrice, 
        uint _fundraiseStart, 
        address _managementAddress
    ) external returns(address _address);
}