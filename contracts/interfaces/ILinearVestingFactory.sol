// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

interface ILinearVesting {

    function teamAmount() external view returns(uint);

    function claimed(address user) external view returns(bool);

    function cliffTimestamp(uint tier) external view returns(uint);

    function claim(address user) external returns(uint tokensToClaim);
}  

interface ILinearVestingFactory {

    function createLinearVesting(
        address token,  
        address managementAddress, 
        address fundraiseAddress, 
        uint teamAmount, 
        uint vestingDuration,
        uint[6] memory vestingStartTimestamp
    ) external returns(address vestingAddress);

}

    
