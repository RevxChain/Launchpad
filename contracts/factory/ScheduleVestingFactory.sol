// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../utils/AccessControlOperator.sol";

import "../interfaces/IFundraiseFactory.sol";

contract SimpleScheduleVesting {
    using SafeERC20 for IERC20;

    uint public immutable teamAmount; 

    address private immutable managementAddress;
    address private immutable fundraiseAddress;
    address private immutable underlyingTokenAddress;
    address private immutable defaultCaller;

    mapping(address user => bool) public claimed;

    uint[6] public cliffTimestamp;

    enum Tier{FCFS, First, Second, Third, Fourth, Team}

    modifier onlyCaller(address _who){
        require(_who == defaultCaller, "Vesting: Invalid call");
        _;
    }

    constructor(
        address _underlyingTokenAddress, 
        address _managementAddress, 
        address _fundraiseAddress, 
        address _operatorAddress, 
        uint[6] memory _cliffTimestamp,
        uint _teamAmount
    ) {
        underlyingTokenAddress = _underlyingTokenAddress;
        managementAddress = _managementAddress;
        fundraiseAddress = _fundraiseAddress;
        teamAmount = _teamAmount;
        cliffTimestamp = _cliffTimestamp;
        defaultCaller = _operatorAddress;
        
    }

    function claim(address user) external onlyCaller(msg.sender) returns(uint claimedAmount) {
        uint _tier;

        if(user != managementAddress){
            (_tier, , claimedAmount) = IFundraise(fundraiseAddress)._userData(user);
            require(claimedAmount > 0, "Vesting: You are not a participant");
        } else {
            claimedAmount = teamAmount;
            _tier = uint(Tier.Team);
        }

        require(block.timestamp >= cliffTimestamp[_tier], "Vesting: Too soon to claim");
        require(!claimed[user], "Vesting: Already claimed");
        claimed[user] = true;

        IERC20(underlyingTokenAddress).safeTransfer(user, claimedAmount);
    }

}

contract ScheduleVesting {
    using SafeERC20 for IERC20;

    uint public immutable teamAmount; 

    uint private constant DIV = 100;
    uint private constant TIERS = 6;

    address private immutable managementAddress;
    address private immutable fundraiseAddress;
    address private immutable underlyingTokenAddress;
    address private immutable defaultCaller;

    mapping(uint => Cliff) private cliffs;
    mapping(address => mapping(uint => bool)) public claimed;
    mapping(address => uint) public claimedAmount;

    struct Cliff{
        uint[5] cliffTimestamp;
        uint[5] cliffAmount; // percentage
    }

    enum Tier{FCFS, First, Second, Third, Fourth, Team}

    modifier onlyCaller(address _who){
        require(_who == defaultCaller, "Vesting: Invalid call");
        _;
    }

    constructor(
        address _underlyingTokenAddress, 
        address _managementAddress, 
        address _fundraiseAddress,
        address _operatorAddress, 
        uint _teamAmount
    ) {
        underlyingTokenAddress = _underlyingTokenAddress;
        managementAddress = _managementAddress;
        fundraiseAddress = _fundraiseAddress;
        teamAmount = _teamAmount;
        defaultCaller = _operatorAddress;    
    }

    function _setupData(uint[30] memory cliffTimestamp, uint[30] memory cliffAmount) external onlyCaller(msg.sender) {
        require(cliffs[0].cliffTimestamp[0] == 0, "Vesting: Data has defined already");
        uint x;
        for(uint i; i < TIERS; i++){
            for(uint n = x; n < x + 4; n++){
                require(cliffTimestamp[n + 1] > cliffTimestamp[n], "Vesting: Wrong cliff timestamps 0x00");
            }
            x += 5;
        }
        x = 0;

        for(uint i; i < cliffTimestamp.length - 11; i += 5){
            require(cliffTimestamp[i] > cliffTimestamp[i + 5], "Vesting: Wrong cliff timestamps 0x01");
        }

        for(uint i; i < TIERS; i++){
            uint _totalAmount = 0;
            
            for(uint n = x; n < x + 5; n++){
                _totalAmount += cliffAmount[n];
            }
            require(_totalAmount == 100, "Vesting: Invalid percentage");
            x += 5;
        }
        x = 0;

        for(uint i; i < TIERS; i++){
            uint y = 0;
            for(uint n = x; n < x + 5; n++){
                cliffs[i].cliffTimestamp[y] = cliffTimestamp[n];
                cliffs[i].cliffAmount[y] = cliffAmount[n];
                y += 1;

            }
            x += 5;
        }  
    }

    function claim(address user, uint cliffRound) external onlyCaller(msg.sender) returns(uint claimedAmount) {
        require(uint(Tier.Team) >= cliffRound , "Vesting: Invalid cliff round");
        (uint _totalAmount, uint _tier);

        if(user != managementAddress){
            (_tier, ,_totalAmount) = IFundraise(fundraiseAddress)._userData(user);
            require(_totalAmount > 0, "Vesting: You are not a participant");
        } else {
            _totalAmount = teamAmount;
            _tier = uint(Tier.Team);
        }

        require(!claimed[user][cliffRound], "Vesting: Already claimed");
        require(block.timestamp >= cliffs[_tier].cliffTimestamp[cliffRound], "Vesting: Too soon to claim");
        require(cliffs[_tier].cliffAmount[cliffRound] != 0, "Vesting: Invalid vesting round");
        claimedAmount = _totalAmount * cliffs[_tier].cliffAmount[cliffRound] / DIV;

        claimed[user][cliffRound] = true;
        claimedAmount[user] += claimedAmount;

        require(_totalAmount >= claimedAmount[user], "Vesting: Something went wrong");

        IERC20(underlyingTokenAddress).safeTransfer(user, claimedAmount);
    }

    function _viewData(uint tier, uint cliffRound) external view returns(uint, uint) {
        return (cliffs[tier].cliffTimestamp[cliffRound], cliffs[tier].cliffAmount[cliffRound]);
    }
}

contract ScheduleVestingFactory is AccessControlOperator {

    function createScheduleVesting(
        address _token,  
        address _managementAddress, 
        address _fundraiseAddress, 
        uint _teamAmount, 
        uint[6] memory _cliffTimestamp
    ) external onlyRole(DEFAULT_CALLER) returns(address vestingAddress) {
        require(_token != address(0), "VestingFactory: Zero address");

        if(_cliffTimestamp[0] == 0) {
            ScheduleVesting _vesting = new ScheduleVesting(
                _token, 
                _managementAddress, 
                _fundraiseAddress, 
                getOperatorAddress(),
                _teamAmount 
            );

            vestingAddress = address(_vesting);
        } else {
            SimpleScheduleVesting _vesting = new SimpleScheduleVesting(
                _token, 
                _managementAddress, 
                _fundraiseAddress, 
                getOperatorAddress(), 
                _cliffTimestamp,
                _teamAmount
            );

            vestingAddress = address(_vesting);
        }
    }
}

  