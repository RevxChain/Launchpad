// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

interface LiquidStakingController {

    struct voteCalldata {
        address[] modules;
        bytes32[] proposalId; 
        bool[] vote;
        bool[] proposalType;
    }

    function vote(voteCalldata calldata $) external;

    function setBribePrices(
        address module,
        address[] calldata tokens, 
        uint[] calldata prices, 
        address priceVerifier
    ) external;

    function openBribe(address module, uint openToTimestamp, address priceVerifier) external;

    function setBribeTime(address module, uint openToTimestamp) external;

    function closeBribe(address module) external;

    function withdrawBribes(
        address module,
        address[] calldata tokens, 
        uint[] calldata amounts, 
        address[] calldata receivers
    ) external;

}