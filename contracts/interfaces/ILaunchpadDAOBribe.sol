// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

interface ILaunchpadDAOBribe {

    function launchpadStakingAddress() external view returns(address);
    function grafterInfo(address grafter) external view returns(GrafterInfo memory);

    struct GrafterInfo {
        bool opened;
        uint openedTo;
        address purchasedBy;
        uint purchasedTo;
    }

    struct bribeToCalldata {
        address[] grafter;
        address[] paymentToken;
        uint[] expectedPrice;
        uint[] bribeToTimestamp;
    }

    function bribeTo(bribeToCalldata calldata $) external payable;

    function setBribePrices(address[] calldata tokens, uint[] calldata prices, address priceVerifier) external;

    function openBribe(uint openToTimestamp, address priceVerifier) external;

    function setBribeTime(uint openToTimestamp) external;

    function closeBribe() external;

    function withdrawBribes(
        address[] calldata tokens, 
        uint[] calldata amounts, 
        address[] calldata receivers
    ) external;

    function closeExpiredBribe(address grafter) external;

    function validateBribe(address user, address grafter) external view;

    function getPaymentTokenData(address grafter, address paymentToken) external view returns(uint pricePerSec, uint earned);

}   