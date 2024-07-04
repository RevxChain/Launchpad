// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

interface LiquidLaunchpadStakingFactory {

    function controller() external view returns(address);
    function launchpadStaking() external view returns(address);
    function launchpadToken() external view returns(address);
    function launchpadDAO() external view returns(address);
    function launchpadDAOBribe() external view returns(address); 
    function liquidStakingToken() external view returns(address);

    function modulesCounter() external view returns(uint);
    function moduleExist(address module) external view returns(bool);

    function deposit(
        uint underlyingAmount,  
        uint sTokenMin,
        address module
    ) external returns(uint userShare);

    function withdraw(
        uint sTokenAmount, 
        uint underlyingMin, 
        address receiver,
        address module
    ) external returns(uint underlyingAmount);

}