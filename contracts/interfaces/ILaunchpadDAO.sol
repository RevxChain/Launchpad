// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

interface ILaunchpadDAO {

    function priceProposalExist() external view returns(bool exist);
    function routerProposalExist() external view returns(bool exist);

    function launchpadTokenAddress() external view returns(address);
    function launchpadStakingAddress() external view returns(address);
    function tokenMinterAddress() external view returns(address);
    function liquidityVaultAddress() external view returns(address);

    function voted(address user, bytes32 proposalId) external view returns(bool voted);
    function priceProposals(bytes32 proposalId) external view returns(PriceProposal memory);
    function routerProposals(bytes32 proposalId) external view returns(RouterProposal memory);
    
    struct PriceProposal {
        bytes32 proposalId;
        string priceType;
        uint priceTypeId;
        uint baseValue;
        uint newValue;
        string description;
        uint forVotes;
        uint againstVotes;
        uint proposeTime;
        uint startTime;
        uint endTime;
        uint status;
    }

    struct RouterProposal {
        bytes32 proposalId;
        address baseAddress;
        address newAddress;
        string description;
        uint forVotes;
        uint againstVotes;
        uint proposeTime;
        uint startTime;
        uint endTime;
        uint status;
    }

    function createPriceProposal(
        uint priceTypeId, 
        uint newValue, 
        string calldata description
    ) external returns(bytes32 proposalId);

    function createRouterProposal(
        address newAddress, 
        string calldata description
    ) external returns(bytes32 proposalId);

    function votePriceProposal(
        bytes32 proposalId, 
        bool vote
    ) external returns(uint forVotes, uint againstVotes);

    function voteRouterProposal(
        bytes32 proposalId, 
        bool vote
    ) external returns(uint forVotes, uint againstVotes);

    function executePriceProposal(bytes32 proposalId) external returns(bool result);

    function executeRouterProposal(bytes32 proposalId) external returns(bool result);

    function calculatePriceProposalId(
        string memory priceType, 
        uint baseValue, 
        uint newValue, 
        string calldata description, 
        uint proposeTime,
        uint startTime,
        uint endTime
    ) external pure returns(bytes32 proposalId);

    function calculateRouterProposalId( 
        address baseAddress, 
        address newAddress, 
        string calldata description, 
        uint proposeTime,
        uint startTime,
        uint endTime
    ) external pure returns(bytes32 proposalId);

}   
