// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

interface IFundraise {

    function actualTokensAmount() external view returns(uint); 

    function actualAllocation() external view returns(uint);

    function actualTierRound() external view returns(uint);

    function totalAmount() external view returns(uint);

    function fundraiseStart() external view returns(uint);

    function vestingStart() external view returns(uint);

    function oneTokenPrice(uint tier) external view returns(uint);

    function participate(address user, uint amount, address stablecoinAddress) external returns(uint underlyingAmount);

    function userData(address user) external view returns(uint tier, uint totalAllocation, uint allocation);

}

interface IFundraiseFactory {

    function fundraiseAddress(address token) external view returns(address);

    function createFundraise(
        address token, 
        uint totalAmount, 
        uint[5] memory oneTokenPrice, 
        uint fundraiseStart, 
        address managementAddress
    ) external returns(address fundraiseAddress);
}