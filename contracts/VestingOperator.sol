// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "./utils/AccessControlOperator.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./interfaces/IFundraiseFactory.sol";
import "./interfaces/ITokenFactory.sol";
import "./interfaces/IScheduleVestingFactory.sol";
import "./interfaces/ILinearVestingFactory.sol";
import "./interfaces/ILaunchpadStaking.sol";
import "./interfaces/ILaunchpadToken.sol";
import "./interfaces/ILiquidityVault.sol";

contract VestingOperator is AccessControlOperator, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint public constant MINIMUM_LIQUIDITY_SHARE = 2; // 50 %
    uint public constant MINIMUM_LAUNCHPAD_SHARE = 4; // 25 %
    uint public constant MINIMUM_TEAMLOCK_DURATION = 100; //64 weeks; 
    uint public constant MINIMUM_LIQUIDITY_LOCK_DURATION = 150; //90 weeks; 
    uint public constant MINIMUM_TIME_TO_FUNDRAISE_START = 50; //12 weeks;
    uint public constant MINIMUM_TIME_TO_VESTING_START = 30; //1 weeks;
    uint public constant MINIMUM_ETHER_LIQUIDITY = 1e18; //10e18; 

    address public immutable liquidityVault;
    address public immutable launchpadToken;
    address public immutable launchpadStaking;
    address public immutable fundraiseFactory;
    address public immutable scheduleVestingFactory;
    address public immutable linearVestingFactory;
    address public immutable tokenFactory;

    enum Tier{FCFS, First, Second, Third, Fourth, Team}

    enum Amount{Manage, Launch, Liquid}

    enum Status{Audit, Denied, Confirmed, Launched}

    constructor(
        address _launchpadToken, 
        address _fundraiseFactory, 
        address _scheduleVestingFactory, 
        address _linearVestingFactory,
        address _tokenFactory, 
        address _liquidityVault,
        address _launchpadStaking
    )
    {
        launchpadToken = _launchpadToken;
        fundraiseFactory = _fundraiseFactory;
        scheduleVestingFactory = _scheduleVestingFactory;
        linearVestingFactory = _linearVestingFactory;
        tokenFactory = _tokenFactory;
        liquidityVault = _liquidityVault;
        launchpadStaking = _launchpadStaking;
    }

    function createSimpleScheduleVesting( 
        address _management,
        address _token,
        address _fundraise,
        uint[6] memory _cliffTimestamp,
        uint _fundraiseStart,
        uint _manageAmount
    )
        external 
        onlyRole(DEFAULT_CALLER) 
        returns(address _vestingAddress)
    {   
        require(_fundraise != address(0), "Invalid call");
        require(_cliffTimestamp[uint(Tier.Team)] >= block.timestamp + MINIMUM_TEAMLOCK_DURATION, "BaseOperator: Too scant team lock duration");
        require(_cliffTimestamp[uint(Tier.Fourth)] >= _fundraiseStart + MINIMUM_TIME_TO_VESTING_START, "BaseOperator: Too soon to start vesting");
        require(_cliffTimestamp[uint(Tier.Team)] > _cliffTimestamp[uint(Tier.FCFS)], "BaseOperator: Too scant team lock duration");
        
        for(uint i; i < _cliffTimestamp.length - 2; i++){
            require(_cliffTimestamp[i] > _cliffTimestamp[i + 1], "BaseOperator: Wrong cliff timestamps");
        }

        _vestingAddress = IScheduleVestingFactory(scheduleVestingFactory).createScheduleVesting(
            _token,  
            _management, 
            _fundraise, 
            _manageAmount, 
            _cliffTimestamp
        );
    }

    function createScheduleVesting( 
        address _management,
        address _token,
        address _fundraise,
        uint[30] memory _cliffTimestamp, 
        uint[30] memory _cliffAmount,
        uint _fundraiseStart,
        uint _manageAmount
    )
        external 
        onlyRole(DEFAULT_CALLER)
        returns(address _vestingAddress)
    {   
        require(_fundraise != address(0), "Invalid call");
        require(_cliffTimestamp[25] >= block.timestamp + MINIMUM_TEAMLOCK_DURATION, "BaseOperator: Too scant team lock duration");
        require(_cliffTimestamp[20] >= _fundraiseStart + MINIMUM_TIME_TO_VESTING_START, "BaseOperator: Too soon to start vesting");
        require(_cliffTimestamp[25] > _cliffTimestamp[0], "BaseOperator: Too scant team lock duration");

        uint[6] memory _placeholder;

        _vestingAddress = IScheduleVestingFactory(scheduleVestingFactory).createScheduleVesting(
            _token,  
            _management, 
            _fundraise, 
            _manageAmount,
            _placeholder
        );

        IScheduleVesting(_vestingAddress)._setupData(_cliffTimestamp, _cliffAmount);
    }

    function createLinearVesting( 
        address _tokenAddress,  
        address _managementAddress, 
        address _fundraiseAddress, 
        uint _fundraiseStart,
        uint _teamAmount,         
        uint _vestingDuration,
        uint _vestingStartTimestamp,
        uint _vestingTeamStartTimestamp

    )
        external 
        onlyRole(DEFAULT_CALLER)
        returns(address _vestingAddress)
    {   
        require(_fundraiseAddress != address(0), "Invalid call");
        require(_vestingTeamStartTimestamp >= block.timestamp + MINIMUM_TEAMLOCK_DURATION, "BaseOperator: Too scant team lock duration");
        require(_vestingStartTimestamp >= _fundraiseStart + MINIMUM_TIME_TO_VESTING_START, "BaseOperator: Too soon to start vesting");
        require(_vestingTeamStartTimestamp > _vestingStartTimestamp, "BaseOperator: Too scant team lock duration");

        uint[6] memory _vestingStartTimestamps;
        _vestingStartTimestamps[0] = _vestingStartTimestamp;
        _vestingStartTimestamps[5] = _vestingTeamStartTimestamp;

        _vestingAddress = ILinearVestingFactory(linearVestingFactory).createLinearVesting(
            _tokenAddress,  
            _managementAddress, 
            _fundraiseAddress, 
            _teamAmount, 
            _vestingDuration,
            _vestingStartTimestamps
        );
    }
    
    function createCliffLinearVesting( 
        address _tokenAddress,  
        address _managementAddress, 
        address _fundraiseAddress, 
        uint _fundraiseStart,
        uint _teamAmount, 
        uint _vestingDuration,
        uint[6] memory _vestingStartTimestamp
    )
        external 
        onlyRole(DEFAULT_CALLER)
        returns(address _vestingAddress)
    {   
        require(_fundraiseAddress != address(0), "Invalid call");
        require(_vestingStartTimestamp[uint(Tier.Team)] >= block.timestamp + MINIMUM_TEAMLOCK_DURATION, "BaseOperator: Too scant team lock duration");
        require(_vestingStartTimestamp[uint(Tier.Fourth)] >= _fundraiseStart + MINIMUM_TIME_TO_VESTING_START, "BaseOperator: Too soon to start vesting");
        require(_vestingStartTimestamp[5] > _vestingStartTimestamp[0], "BaseOperator: Too scant team lock duration");

        for(uint i; i < _vestingStartTimestamp.length - 2; i++){
            require(_vestingStartTimestamp[i] > _vestingStartTimestamp[i + 1], "BaseOperator: Wrong cliff timestamps");
        }

        _vestingAddress = ILinearVestingFactory(linearVestingFactory).createLinearVesting(
            _tokenAddress,  
            _managementAddress, 
            _fundraiseAddress, 
            _teamAmount, 
            _vestingDuration,
            _vestingStartTimestamp
        );
    }
}