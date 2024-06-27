// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./utils/AccessControlOperator.sol";

import "./interfaces/IFundraiseFactory.sol";
import "./interfaces/ITokenFactory.sol";
import "./interfaces/IScheduleVestingFactory.sol";
import "./interfaces/ILinearVestingFactory.sol";
import "./interfaces/ILaunchpadStaking.sol";
import "./interfaces/ILaunchpadToken.sol";
import "./interfaces/ILiquidityVault.sol";

contract VestingOperator is AccessControlOperator, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint public constant MINIMUM_LIQUIDITY_SHARE = 2; 
    uint public constant MINIMUM_LAUNCHPAD_SHARE = 4;
    uint public constant MINIMUM_TEAMLOCK_DURATION = 64 weeks; 
    uint public constant MINIMUM_LIQUIDITY_LOCK_DURATION = 90 weeks; 
    uint public constant MINIMUM_TIME_TO_FUNDRAISE_START = 12 weeks; 
    uint public constant MINIMUM_TIME_TO_VESTING_START = 1 weeks; 
    uint public constant MINIMUM_ETHER_LIQUIDITY = 10e18; 

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
    ) {
        launchpadToken = _launchpadToken;
        fundraiseFactory = _fundraiseFactory;
        scheduleVestingFactory = _scheduleVestingFactory;
        linearVestingFactory = _linearVestingFactory;
        tokenFactory = _tokenFactory;
        liquidityVault = _liquidityVault;
        launchpadStaking = _launchpadStaking;
    }

    function createSimpleScheduleVesting( 
        address management,
        address token,
        address fundraise,
        uint[6] memory cliffTimestamp,
        uint fundraiseStart,
        uint manageAmount
    ) external onlyRole(DEFAULT_CALLER) returns(address vestingAddress) {   
        require(fundraise != address(0), "VestingOperator: Invalid call");
        require(cliffTimestamp[uint(Tier.Team)] >= block.timestamp + MINIMUM_TEAMLOCK_DURATION, "VestingOperator: Too scant team lock duration");
        require(cliffTimestamp[uint(Tier.Fourth)] >= fundraiseStart + MINIMUM_TIME_TO_VESTING_START, "VestingOperator: Too soon to start vesting");
        require(cliffTimestamp[uint(Tier.Team)] > cliffTimestamp[uint(Tier.FCFS)], "VestingOperator: Too scant team lock duration");
        
        for(uint i; i < cliffTimestamp.length - 2; i++){
            require(cliffTimestamp[i] > cliffTimestamp[i + 1], "VestingOperator: Wrong cliff timestamps");
        }

        vestingAddress = IScheduleVestingFactory(scheduleVestingFactory).createScheduleVesting(
            token,  
            management, 
            fundraise, 
            manageAmount, 
            cliffTimestamp
        );
    }

    function createScheduleVesting( 
        address management,
        address token,
        address fundraise,
        uint[30] memory cliffTimestamp, 
        uint[30] memory cliffAmount,
        uint fundraiseStart,
        uint manageAmount
    ) external onlyRole(DEFAULT_CALLER) returns(address vestingAddress) {   
        require(fundraise != address(0), "VestingOperator: Invalid call");
        require(cliffTimestamp[25] >= block.timestamp + MINIMUM_TEAMLOCK_DURATION, "VestingOperator: Too scant team lock duration");
        require(cliffTimestamp[20] >= fundraiseStart + MINIMUM_TIME_TO_VESTING_START, "VestingOperator: Too soon to start vesting");
        require(cliffTimestamp[25] > cliffTimestamp[0], "VestingOperator: Too scant team lock duration");

        uint[6] memory _placeholder;

        vestingAddress = IScheduleVestingFactory(scheduleVestingFactory).createScheduleVesting(
            token,  
            management, 
            fundraise, 
            manageAmount,
            _placeholder
        );

        IScheduleVesting(vestingAddress)._setupData(cliffTimestamp, cliffAmount);
    }

    function createLinearVesting( 
        address tokenAddress,  
        address managementAddress, 
        address fundraiseAddress, 
        uint fundraiseStart,
        uint teamAmount,         
        uint vestingDuration,
        uint vestingStartTimestamp,
        uint vestingTeamStartTimestamp
    ) external onlyRole(DEFAULT_CALLER) returns(address vestingAddress) {   
        require(fundraiseAddress != address(0), "VestingOperator: Invalid call");
        require(vestingTeamStartTimestamp >= block.timestamp + MINIMUM_TEAMLOCK_DURATION, "VestingOperator: Too scant team lock duration");
        require(vestingStartTimestamp >= fundraiseStart + MINIMUM_TIME_TO_VESTING_START, "VestingOperator: Too soon to start vesting");
        require(vestingTeamStartTimestamp > vestingStartTimestamp, "VestingOperator: Too scant team lock duration");

        uint[6] memory _vestingStartTimestamps;
        _vestingStartTimestamps[0] = vestingStartTimestamp;
        _vestingStartTimestamps[5] = vestingTeamStartTimestamp;

        vestingAddress = ILinearVestingFactory(linearVestingFactory).createLinearVesting(
            tokenAddress,  
            managementAddress, 
            fundraiseAddress, 
            teamAmount, 
            vestingDuration,
            _vestingStartTimestamps
        );
    }
    
    function createCliffLinearVesting( 
        address tokenAddress,  
        address managementAddress, 
        address fundraiseAddress, 
        uint fundraiseStart,
        uint teamAmount, 
        uint vestingDuration,
        uint[6] memory vestingStartTimestamp
    ) external onlyRole(DEFAULT_CALLER) returns(address vestingAddress) {   
        require(fundraiseAddress != address(0), "VestingOperator: Invalid call");
        require(vestingStartTimestamp[uint(Tier.Team)] >= block.timestamp + MINIMUM_TEAMLOCK_DURATION, "VestingOperator: Too scant team lock duration");
        require(vestingStartTimestamp[uint(Tier.Fourth)] >= fundraiseStart + MINIMUM_TIME_TO_VESTING_START, "VestingOperator: Too soon to start vesting");
        require(vestingStartTimestamp[5] > vestingStartTimestamp[0], "VestingOperator: Too scant team lock duration");

        for(uint i; i < vestingStartTimestamp.length - 2; i++){
            require(vestingStartTimestamp[i] > vestingStartTimestamp[i + 1], "VestingOperator: Wrong cliff timestamps");
        }

        vestingAddress = ILinearVestingFactory(linearVestingFactory).createLinearVesting(
            tokenAddress,  
            managementAddress, 
            fundraiseAddress, 
            teamAmount, 
            vestingDuration,
            vestingStartTimestamp
        );
    }
}