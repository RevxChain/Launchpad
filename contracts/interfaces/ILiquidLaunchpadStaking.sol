// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

interface ILiquidLaunchpadStaking {

    function factory() external view returns(address);
    function controller() external view returns(address);
    function launchpadStaking() external view returns(address);
    function launchpadToken() external view returns(address);
    function launchpadDAO() external view returns(address);
    function launchpadDAOBribe() external view returns(address);

    function initialize(
        address _controller, 
        address _launchpadStaking, 
        address _launchpadToken,
        address _launchpadDAO,
        address _launchpadDAOBribe
    ) external;

    function deposit(
        uint underlyingAmount, 
        uint lockDuration, 
        uint sTokenMin
    ) external returns(uint userShare);

    function withdraw(
        uint sTokenAmount, 
        uint underlyingMin, 
        address receiver
    ) external returns(uint underlyingAmount);

    function vote(bytes32 proposalId, bool voteType, bool proposalType) external;

    function setBribePrices(
        address[] calldata tokens, 
        uint[] calldata prices, 
        address priceVerifier
    ) external;

    function openBribe(uint openToTimestamp, address priceVerifier) external;

    function setBribeTime(uint openToTimestamp) external;

    function closeBribe() external;

    function withdrawBribes(
        address[] calldata tokens, 
        uint[] calldata amounts, 
        address[] calldata receivers
    ) external;

    function getStakeInfo() external view returns(uint sTokenBalance, uint tier, uint stakedAmount, uint unlockTime);

}