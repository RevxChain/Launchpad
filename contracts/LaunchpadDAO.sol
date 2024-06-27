// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./interfaces/ILiquidityVault.sol";
import "./interfaces/ITokenMinter.sol";
import "./interfaces/ILaunchpadToken.sol";
import "./interfaces/ILaunchpadStaking.sol";

contract LaunchpadDAO is ReentrancyGuard {

    uint public constant PAYMENT_TO_CREATE_PROPOSAL = 1000e18; 
    uint public constant MINIMUM_AMOUNT_TO_CREATE_PROPOSAL = 15000e18; 
    uint public constant MINIMUM_AMOUNT_TO_VOTE = 3000e18; 
    uint public constant TIME_TO_START_VOTING = 3 days; 
    uint public constant VOTING_DURATION = 7 days; 
    uint public constant MINIMUM_QUORUM = 70; 
    uint public constant DIV = 100; 

    bool public priceProposalExist;
    bool public routerProposalExist;

    address public immutable launchpadTokenAddress;
    address public immutable launchpadStakingAddress;
    address public immutable tokenMinterAddress;
    address public immutable liquidityVaultAddress;
    
    mapping(bytes32 => PriceProposal) public priceProposals;
    mapping(bytes32 => RouterProposal) public routerProposals;
    mapping(address => mapping(bytes32 => bool)) public voted;

    enum Status{Preparation, Voting, Executed, Rejected}

    enum Prices{DefaultTokenMintPrice, OwnTokenMintPrice}

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

    constructor(
        address _launchpadTokenAddress, 
        address _launchpadStakingAddress, 
        address _tokenMinterAddress, 
        address _liquidityVaultAddress
    ) {
        launchpadTokenAddress = _launchpadTokenAddress;
        launchpadStakingAddress = _launchpadStakingAddress;
        tokenMinterAddress = _tokenMinterAddress;
        liquidityVaultAddress = _liquidityVaultAddress;
    }

    function createPriceProposal(
        uint priceTypeId, 
        uint newValue, 
        string calldata description
    ) external nonReentrant() returns(bytes32 proposalId) {
        address _user = msg.sender;
        uint _stakedAmount = ILaunchpadStaking(launchpadStakingAddress).userInfo(_user).stakedAmount;
        require(_stakedAmount >= MINIMUM_AMOUNT_TO_CREATE_PROPOSAL, "LaunchpadDAO: Not enough staked tokens to create proposal");
        require(IERC20(launchpadTokenAddress).balanceOf(_user) >= PAYMENT_TO_CREATE_PROPOSAL, "LaunchpadDAO: Not enough launchpad tokens to create proposal");
        require(priceTypeId == uint(Prices.DefaultTokenMintPrice) || priceTypeId == uint(Prices.OwnTokenMintPrice), "LaunchpadDAO: Wrong price type");
        require(!priceProposalExist, "LaunchpadDAO: Price proposal is exist already");

        string memory _priceType;
        uint _baseValue;

        if(priceTypeId == uint(Prices.DefaultTokenMintPrice)){
            _priceType = "DefaultTokenMintPrice";
            _baseValue = ITokenMinter(tokenMinterAddress).defaultTokenMintPrice();
        } else {
            _priceType = "OwnTokenMintPrice";
            _baseValue = ITokenMinter(tokenMinterAddress).ownTokenMintPrice();
        }

        uint _startTime = block.timestamp + TIME_TO_START_VOTING;
        uint _endTime = _startTime + VOTING_DURATION;

        proposalId = calculatePriceProposalId(
            _priceType, 
            _baseValue, 
            newValue, 
            description, 
            block.timestamp, 
            _startTime, 
            _endTime 
        );

        priceProposals[proposalId] = PriceProposal({
            proposalId: proposalId,
            priceType: _priceType,
            priceTypeId: _priceTypeId,
            baseValue: _baseValue,
            newValue: newValue,
            description: description,
            forVotes: 0,
            againstVotes: 0,
            proposeTime: block.timestamp,
            startTime: _startTime,
            endTime: _endTime,
            status: uint(Status.Preparation)
        });

        ILaunchpadToken(launchpadTokenAddress).burnFrom(_user, PAYMENT_TO_CREATE_PROPOSAL);
        priceProposalExist = true;
    }

    function createAddressProposal(
        address newAddress, 
        string calldata description
    ) external nonReentrant() returns(bytes32 proposalId) {
        address _user = msg.sender;
        uint _stakedAmount = ILaunchpadStaking(launchpadStakingAddress).userInfo(_user).stakedAmount;
        require(_stakedAmount >= MINIMUM_AMOUNT_TO_CREATE_PROPOSAL, "LaunchpadDAO: Not enough staked tokens to create proposal");
        require(IERC20(launchpadTokenAddress).balanceOf(_user) >= PAYMENT_TO_CREATE_PROPOSAL, "LaunchpadDAO: Not enough launchpad tokens to create proposal");
        require(contractSize(newAddress) > 0, "LaunchpadDAO: Invalid address");
        require(!routerProposalExist, "LaunchpadDAO: Router proposal is exist already");

        address _baseAddress = ILiquidityVault(liquidityVaultAddress).liquidityRouterAddress();
        uint _startTime = block.timestamp + TIME_TO_START_VOTING;
        uint _endTime = _startTime + VOTING_DURATION;

        proposalId = calculateRouterProposalId( 
            _baseAddress, 
            newAddress, 
            description, 
            block.timestamp, 
            _startTime, 
            _endTime 
        );

        routerProposals[proposalId] = RouterProposal({
            proposalId: proposalId,
            baseAddress: _baseAddress,
            newAddress: newAddress,
            description: description,
            forVotes: 0,
            againstVotes: 0,
            proposeTime: block.timestamp,
            startTime: _startTime,
            endTime: _endTime,
            status: uint(Status.Preparation)
        });

        ILaunchpadToken(launchpadTokenAddress).burnFrom(_user, PAYMENT_TO_CREATE_PROPOSAL);
        routerProposalExist = true;
    }

    function votePriceProposal(
        bytes32 proposalId, 
        bool vote
    ) external nonReentrant() returns(uint forVotes, uint againstVotes) {
        address _user = msg.sender;
        require(block.timestamp >= priceProposals[proposalId].startTime, "LaunchpadDAO: Too soon to vote");
        require(priceProposals[proposalId].endTime > block.timestamp, "LaunchpadDAO: Proposal has ended");

        if(priceProposals[proposalId].status == uint(Status.Preparation)){
            priceProposals[proposalId].status = uint(Status.Voting);
        } else {
            require(priceProposals[proposalId].status == uint(Status.Voting), "LaunchpadDAO: Something went wrong");
        }

        uint _stakedAmount = ILaunchpadStaking(launchpadStakingAddress).userInfo(_user).stakedAmount;
        require(_stakedAmount >= MINIMUM_AMOUNT_TO_VOTE, "LaunchpadDAO: Not enough staked tokens to vote");
        require(!voted[_user][proposalId], "LaunchpadDAO: You are voted already");
        require(priceProposalExist, "LaunchpadDAO: Price proposal is not exist");

        if(vote){
            priceProposals[proposalId].forVotes += 1;
        } else {  
            priceProposals[proposalId].againstVotes += 1;
        } 
        
        voted[_user][proposalId] = true;

        return (priceProposals[proposalId].forVotes, priceProposals[proposalId].againstVotes);
    }

    function voteRouterProposal(
        bytes32 proposalId, 
        bool vote
    ) external nonReentrant() returns(uint forVotes, uint againstVotes) {
        address _user = msg.sender;
        require(block.timestamp >= routerProposals[proposalId].startTime, "LaunchpadDAO: Too soon to vote");
        require(routerProposals[proposalId].endTime > block.timestamp, "LaunchpadDAO: Proposal has ended");
        if(routerProposals[proposalId].status == uint(Status.Preparation)){
            routerProposals[proposalId].status = uint(Status.Voting);
        } else {
            require(routerProposals[proposalId].status == uint(Status.Voting), "LaunchpadDAO: Proposal has ended");
        }

        uint _stakedAmount = ILaunchpadStaking(launchpadStakingAddress).userInfo(_user).stakedAmount;
        require(_stakedAmount >= MINIMUM_AMOUNT_TO_VOTE, "LaunchpadDAO: Not enough staked tokens to vote");
        require(!voted[_user][proposalId], "LaunchpadDAO: You are voted already");
        require(routerProposalExist, "LaunchpadDAO: Router proposal is not exist");

        if(vote){
            routerProposals[proposalId].forVotes += 1;
        } else {  
            routerProposals[proposalId].againstVotes += 1;
        } 
        voted[_user][proposalId] = true;

        return (routerProposals[proposalId].forVotes, routerProposals[proposalId].againstVotes);
    }

    function executePriceProposal(bytes32 proposalId) external nonReentrant() returns(bool result) {
        require(block.timestamp >= priceProposals[proposalId].endTime, "LaunchpadDAO: Proposal has not ended");
        require(priceProposals[proposalId].status == uint(Status.Voting), "LaunchpadDAO: Voting is processing");
        require(priceProposalExist, "LaunchpadDAO: Price proposal is not exist");
        priceProposalExist = false;
        uint _totalVotes = priceProposals[proposalId].forVotes + priceProposals[proposalId].againstVotes;
        uint _quorumKink = _totalVotes * MINIMUM_QUORUM / DIV;

        if(priceProposals[proposalId].forVotes >= _quorumKink){
            priceProposals[proposalId].status = uint(Status.Executed);
            ITokenMinter(tokenMinterAddress).updatePrice(priceProposals[proposalId].priceTypeId, priceProposals[proposalId].newValue);

            return true;
        } else {    
            priceProposals[proposalId].status = uint(Status.Rejected);

            return false;
        }
    }

    function executeRouterProposal(bytes32 proposalId) external nonReentrant() returns(bool result) {
        require(block.timestamp >= routerProposals[proposalId].endTime, "LaunchpadDAO: Proposal has not ended");
        require(routerProposals[proposalId].status == uint(Status.Voting), "LaunchpadDAO: Voting is processing");
        require(routerProposalExist, "LaunchpadDAO: Router proposal is not exist");
        routerProposalExist = false;

        uint _totalVotes = routerProposals[proposalId].forVotes + routerProposals[proposalId].againstVotes;
        uint _quorumKink = _totalVotes * MINIMUM_QUORUM / DIV;

        if(routerProposals[proposalId].forVotes >= _quorumKink){
            routerProposals[proposalId].status = uint(Status.Executed);
            ILiquidityVault(liquidityVaultAddress).updateRouterAddress(routerProposals[proposalId].newAddress);

            return true;
        } else {    
            routerProposals[proposalId].status = uint(Status.Rejected);

            return false;
        }  
    }

    function calculatePriceProposalId(
        string calldata priceType, 
        uint baseValue, 
        uint newValue, 
        string calldata description, 
        uint proposeTime,
        uint startTime,
        uint endTime
    ) public pure returns(bytes32 proposalId) {
        return keccak256(abi.encode(
            keccak256(bytes(priceType)), 
            baseValue, 
            newValue, 
            keccak256(bytes(description)), 
            proposeTime, 
            startTime, 
            endTime
        ));
    }

    function calculateRouterProposalId( 
        address baseAddress, 
        address newAddress, 
        string calldata description, 
        uint proposeTime,
        uint startTime,
        uint endTime
    ) public pure returns(bytes32 proposalId) {
        return keccak256(abi.encode( 
            baseAddress, 
            newAddress, 
            keccak256(bytes(description)), 
            proposeTime, 
            startTime, 
            endTime
        ));
    }

    function contractSize(address target) internal view returns(uint size) {
        assembly {
            size := extcodesize(target)
        }
    }
}