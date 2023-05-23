// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IFundraiseFactory.sol";
import "./utils/AccessControlOperator.sol";

contract SimpleScheduleVesting {
    using SafeERC20 for IERC20;

    uint public immutable teamAmount; 

    address private immutable managementAddress;
    address private immutable fundraiseAddress;
    address private immutable underlyingTokenAddress;
    address private immutable defaultCaller;

    mapping(address => bool) public claimed;

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
    )
    {
        underlyingTokenAddress = _underlyingTokenAddress;
        managementAddress = _managementAddress;
        fundraiseAddress = _fundraiseAddress;
        teamAmount = _teamAmount;
        cliffTimestamp = _cliffTimestamp;
        defaultCaller = _operatorAddress;
        
    }

    function claim(address _user)external onlyCaller(msg.sender){
        uint _amount;
        uint _tier;

        if(_user != managementAddress){
            (_tier, ,_amount) = IFundraise(fundraiseAddress)._userData(_user);
            require(_amount > 0, "Vesting: You are not a participant");
        } else {
            _amount = teamAmount;
            _tier = uint(Tier.Team);
        }

        require(block.timestamp >= cliffTimestamp[_tier], "Vesting: Too soon to claim");
        require(claimed[_user] == false, "Vesting: Already claimed");
        IERC20(underlyingTokenAddress).safeTransfer(_user, _amount);
        claimed[_user] = true;
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

    // tier => data
    mapping(uint => Cliff) private cliffs;
    // user => round => claimed
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
    )
    {
        underlyingTokenAddress = _underlyingTokenAddress;
        managementAddress = _managementAddress;
        fundraiseAddress = _fundraiseAddress;
        teamAmount = _teamAmount;
        defaultCaller = _operatorAddress;    
    }

    function _setupData(uint[30] memory _cliffTimestamp, uint[30] memory _cliffAmount)external onlyCaller(msg.sender){
        require(cliffs[0].cliffTimestamp[0] == 0, "Vesting: Data has defined already");
        uint x;
        for(uint i; i < TIERS; i++){
            for(uint n = x; n < x + 4; n++){
                require(_cliffTimestamp[n + 1] > _cliffTimestamp[n], "Vesting: Wrong cliff timestamps 0x00");
            }
            x += 5;
        }
        x = 0;

        for(uint i; i < _cliffTimestamp.length - 11; i += 5){
            require(_cliffTimestamp[i] > _cliffTimestamp[i + 5], "Vesting: Wrong cliff timestamps 0x01");
        }

        for(uint i; i < TIERS; i++){
            uint _totalAmount = 0;
            
            for(uint n = x; n < x + 5; n++){
                _totalAmount += _cliffAmount[n];
            }
            require(_totalAmount == 100, "Vesting: Invalid percentage");
            x += 5;
        }
        x = 0;

        for(uint i; i < TIERS; i++){
            uint y = 0;
            for(uint n = x; n < x + 5; n++){
                cliffs[i].cliffTimestamp[y] = _cliffTimestamp[n];
                cliffs[i].cliffAmount[y] = _cliffAmount[n];
                y += 1;

            }
            x += 5;
        }  
    }

    function claim(address _user, uint _cliffRound)external onlyCaller(msg.sender){
        require(uint(Tier.Team) >= _cliffRound , "Vesting: Invalid cliff round");
        uint _totalAmount;
        uint _tier;

        if(_user != managementAddress){
            (_tier, ,_totalAmount) = IFundraise(fundraiseAddress)._userData(_user);
            require(_totalAmount > 0, "Vesting: You are not a participant");
        } else {
            _totalAmount = teamAmount;
            _tier = uint(Tier.Team);
        }

        require(claimed[_user][_cliffRound] == false, "Vesting: Already claimed");
        require(block.timestamp >= cliffs[_tier].cliffTimestamp[_cliffRound], "Vesting: Too soon to claim");
        require(cliffs[_tier].cliffAmount[_cliffRound] != 0, "Vesting: Invalid vesting round");
        uint _amount = _totalAmount * cliffs[_tier].cliffAmount[_cliffRound] / DIV;

        claimed[_user][_cliffRound] = true;
        claimedAmount[_user] += _amount;

        require(_totalAmount >= claimedAmount[_user], "Vesting: Something went wrong");

        IERC20(underlyingTokenAddress).safeTransfer(_user, _amount);
    }

    function _viewData(uint _tier, uint _cliffRound)external view returns(uint, uint){
        return (cliffs[_tier].cliffTimestamp[_cliffRound], cliffs[_tier].cliffAmount[_cliffRound]);
    }
}

contract ScheduleVestingFactory is AccessControlOperator {

    function createScheduleVesting(
        address _token,  
        address _managementAddress, 
        address _fundraiseAddress, 
        uint _teamAmount, 
        uint[6] memory _cliffTimestamp
    ) 
        external 
        onlyRole(DEFAULT_CALLER)
        returns(address _vestingAddress)
    {
        require(_token != address(0), "VestingFactory: Zero address");

        if(_cliffTimestamp[0] == 0) {
            ScheduleVesting _vesting = new ScheduleVesting(
                _token, 
                _managementAddress, 
                _fundraiseAddress, 
                viewOperatorAddress(),
                _teamAmount 
            );

            _vestingAddress = address(_vesting);
        } else {
            SimpleScheduleVesting _vesting = new SimpleScheduleVesting(
                _token, 
                _managementAddress, 
                _fundraiseAddress, 
                viewOperatorAddress(), 
                _cliffTimestamp,
                _teamAmount
            );

            _vestingAddress = address(_vesting);
        }
    }
}

  