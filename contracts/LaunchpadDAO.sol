// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./interfaces/ILiquidityVault.sol";
import "./interfaces/ITokenMinter.sol";
import "./interfaces/ILaunchpadToken.sol";
import "./interfaces/ILaunchpadStaking.sol";

contract LaunchpadDAO is ReentrancyGuard {

    uint public constant PAYMENT_TO_CREATE_PROPOSAL = 1; // 1000e18
    uint public constant MINIMUM_AMOUNT_TO_CREATE_PROPOSAL = 1; //15000e18;
    uint public constant MINIMUM_AMOUNT_TO_VOTE = 1; // 3000e18
    uint public constant TIME_TO_START_VOTING = 1; // 3 days
    uint public constant VOTING_DURATION = 1; // 7 days
    uint public constant MINIMUM_QUORUM = 70; // 70%
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
    )
    {
        launchpadTokenAddress = _launchpadTokenAddress;
        launchpadStakingAddress = _launchpadStakingAddress;
        tokenMinterAddress = _tokenMinterAddress;
        liquidityVaultAddress = _liquidityVaultAddress;
    }

    function createPriceProposal(uint _priceTypeId, uint _newValue, string calldata _description)external nonReentrant() returns(bytes32 _proposalId){
        address _user = msg.sender;
        (, uint _stakedAmount) = ILaunchpadStaking(launchpadStakingAddress)._userInfo(_user);
        require(_stakedAmount >= MINIMUM_AMOUNT_TO_CREATE_PROPOSAL, "LaunchpadDAO: Not enough staked tokens to create proposal");
        require(IERC20(launchpadTokenAddress).balanceOf(_user) >= PAYMENT_TO_CREATE_PROPOSAL, "LaunchpadDAO: Not enough launchpad tokens to create proposal");
        require(_priceTypeId == uint(Prices.DefaultTokenMintPrice) || _priceTypeId == uint(Prices.OwnTokenMintPrice), "LaunchpadDAO: Wrong price type");
        require(priceProposalExist == false, "LaunchpadDAO: Price proposal is exist already");

        string memory _priceType;
        uint _baseValue;
        if(_priceTypeId == uint(Prices.DefaultTokenMintPrice)){
            _priceType = "DefaultTokenMintPrice";
            _baseValue = ITokenMinter(tokenMinterAddress).defaultTokenMintPrice();
        } else {
            _priceType = "OwnTokenMintPrice";
            _baseValue = ITokenMinter(tokenMinterAddress).ownTokenMintPrice();
        }

        uint _startTime = block.timestamp + TIME_TO_START_VOTING;
        uint _endTime = _startTime + VOTING_DURATION;

        _proposalId = calculatePriceProposalId(
            _priceType, 
            _baseValue, 
            _newValue, 
            _description, 
            block.timestamp, 
            _startTime, 
            _endTime 
        );

        priceProposals[_proposalId] = PriceProposal({
            proposalId: _proposalId,
            priceType: _priceType,
            priceTypeId: _priceTypeId,
            baseValue: _baseValue,
            newValue: _newValue,
            description: _description,
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

    function createAddressProposal(address _newAddress, string calldata _description)external nonReentrant() returns(bytes32 _proposalId){
        address _user = msg.sender;
        (, uint _stakedAmount) = ILaunchpadStaking(launchpadStakingAddress)._userInfo(_user);
        require(_stakedAmount >= MINIMUM_AMOUNT_TO_CREATE_PROPOSAL, "LaunchpadDAO: Not enough staked tokens to create proposal");
        require(IERC20(launchpadTokenAddress).balanceOf(_user) >= PAYMENT_TO_CREATE_PROPOSAL, "LaunchpadDAO: Not enough launchpad tokens to create proposal");
        require(contractSize(_newAddress) > 0, "LaunchpadDAO: Invalid address");
        require(routerProposalExist == false, "LaunchpadDAO: Router proposal is exist already");

        address _baseAddress = ILiquidityVault(liquidityVaultAddress).liquidityRouterAddress();
        uint _startTime = block.timestamp + TIME_TO_START_VOTING;
        uint _endTime = _startTime + VOTING_DURATION;

        _proposalId = calculateRouterProposalId( 
            _baseAddress, 
            _newAddress, 
            _description, 
            block.timestamp, 
            _startTime, 
            _endTime 
        );

        routerProposals[_proposalId] = RouterProposal({
            proposalId: _proposalId,
            baseAddress: _baseAddress,
            newAddress: _newAddress,
            description: _description,
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

    function votePriceProposal(bytes32 _proposalId, bool _vote)external nonReentrant() returns(uint _forVotes, uint _againstVotes){
        address _user = msg.sender;

        require(block.timestamp >= priceProposals[_proposalId].startTime, "LaunchpadDAO: Too soon to vote");
        require(priceProposals[_proposalId].endTime > block.timestamp, "LaunchpadDAO: Proposal has ended");

        if(priceProposals[_proposalId].status == uint(Status.Preparation)){
            priceProposals[_proposalId].status = uint(Status.Voting);
        } else {
            require(priceProposals[_proposalId].status == uint(Status.Voting), "LaunchpadDAO: Something went wrong");
        }

        (, uint _stakedAmount) = ILaunchpadStaking(launchpadStakingAddress)._userInfo(_user);
        require(_stakedAmount >= MINIMUM_AMOUNT_TO_VOTE, "LaunchpadDAO: Not enough staked tokens to vote");
        require(voted[_user][_proposalId] == false, "LaunchpadDAO: You are voted already");
        require(priceProposalExist == true, "LaunchpadDAO: Price proposal is not exist");

        if(_vote == true) {
            priceProposals[_proposalId].forVotes += 1;
        } else {  
            priceProposals[_proposalId].againstVotes += 1;
        } 
        
        voted[_user][_proposalId] = true;

        return (priceProposals[_proposalId].forVotes, priceProposals[_proposalId].againstVotes);
    }

    function voteRouterProposal(bytes32 _proposalId, bool _vote)external nonReentrant() returns(uint _forVotes, uint _againstVotes){
        address _user = msg.sender;
        require(block.timestamp >= routerProposals[_proposalId].startTime, "LaunchpadDAO: Too soon to vote");
        require(routerProposals[_proposalId].endTime > block.timestamp, "LaunchpadDAO: Proposal has ended");
        if(routerProposals[_proposalId].status == uint(Status.Preparation)){
            routerProposals[_proposalId].status = uint(Status.Voting);
        } else {
            require(routerProposals[_proposalId].status == uint(Status.Voting), "LaunchpadDAO: Proposal has ended");
        }
        (, uint _stakedAmount) = ILaunchpadStaking(launchpadStakingAddress)._userInfo(_user);
        require(_stakedAmount >= MINIMUM_AMOUNT_TO_VOTE, "LaunchpadDAO: Not enough staked tokens to vote");
        require(voted[_user][_proposalId] == false, "LaunchpadDAO: You are voted already");
        require(routerProposalExist == true, "LaunchpadDAO: Router proposal is not exist");
        if(_vote == true) {
            routerProposals[_proposalId].forVotes += 1;
        } else {  
            routerProposals[_proposalId].againstVotes += 1;
        } 
        voted[_user][_proposalId] = true;

        return (routerProposals[_proposalId].forVotes, routerProposals[_proposalId].againstVotes);
    }

    function executePriceProposal(bytes32 _proposalId)external nonReentrant() returns(bool _result){
        require(block.timestamp >= priceProposals[_proposalId].endTime, "LaunchpadDAO: Proposal has not ended");
        require(priceProposals[_proposalId].status == uint(Status.Voting), "LaunchpadDAO: Voting is processing");
        require(priceProposalExist == true, "LaunchpadDAO: Price proposal is not exist");
        priceProposalExist = false;
        uint _totalVotes = priceProposals[_proposalId].forVotes + priceProposals[_proposalId].againstVotes;
        uint _quorumKink = _totalVotes * MINIMUM_QUORUM / DIV;
        if(priceProposals[_proposalId].forVotes >= _quorumKink){
            priceProposals[_proposalId].status = uint(Status.Executed);
            ITokenMinter(tokenMinterAddress).updatePrice(priceProposals[_proposalId].priceTypeId, priceProposals[_proposalId].newValue);

            return true;
        } else {    
            priceProposals[_proposalId].status = uint(Status.Rejected);

            return false;
        }
    }

    function executeRouterProposal(bytes32 _proposalId)external nonReentrant() returns(bool _result){
        require(block.timestamp >= routerProposals[_proposalId].endTime, "LaunchpadDAO: Proposal has not ended");
        require(routerProposals[_proposalId].status == uint(Status.Voting), "LaunchpadDAO: Voting is processing");
        require(routerProposalExist == true, "LaunchpadDAO: Router proposal is not exist");
        routerProposalExist = false;
        uint _totalVotes = routerProposals[_proposalId].forVotes + routerProposals[_proposalId].againstVotes;
        uint _quorumKink = _totalVotes * MINIMUM_QUORUM / DIV;
        if(routerProposals[_proposalId].forVotes >= _quorumKink){
            routerProposals[_proposalId].status = uint(Status.Executed);
            ILiquidityVault(liquidityVaultAddress).updateRouterAddress(routerProposals[_proposalId].newAddress);

            return true;
        } else {    
            routerProposals[_proposalId].status = uint(Status.Rejected);

            return false;
        }  
    }

    function calculatePriceProposalId(
        string memory _priceType, 
        uint _baseValue, 
        uint _newValue, 
        string calldata _description, 
        uint _proposeTime,
        uint _startTime,
        uint _endTime
    )
        public 
        pure 
        returns(bytes32 _proposalId)
    {
        return keccak256(abi.encode(
            keccak256(bytes(_priceType)), 
            _baseValue, 
            _newValue, 
            keccak256(bytes(_description)), 
            _proposeTime, 
            _startTime, 
            _endTime
        ));
    }

    function calculateRouterProposalId( 
        address _baseAddress, 
        address _newAddress, 
        string calldata _description, 
        uint _proposeTime,
        uint _startTime,
        uint _endTime
    )
        public 
        pure 
        returns(bytes32 _proposalId)
    {
        return keccak256(abi.encode( 
            _baseAddress, 
            _newAddress, 
            keccak256(bytes(_description)), 
            _proposeTime, 
            _startTime, 
            _endTime
        ));
    }

    function contractSize(address _address)public view returns(uint size){
        assembly {
                size := extcodesize(_address)
        }
    }
}