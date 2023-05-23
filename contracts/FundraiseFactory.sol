// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./interfaces/IFundraiseFactory.sol";
import "./interfaces/ITokenFactory.sol";
import "./interfaces/ILaunchpadStaking.sol";
import "./utils/AccessControlOperator.sol";

contract Fundraise is AccessControl, ReentrancyGuard{
    using SafeERC20 for IERC20;

    uint public actualTokensAmount;
    uint public actualAllocation;
    uint public actualTierRound;
    uint public unrealizedTokensAmount;

    uint public immutable totalAmount;
    uint public immutable fundraiseStart;
    uint public immutable vestingStart;

    uint private constant ACCURACY = 1e18;
    uint private constant fundraiseDuration = 5 days;
    uint private constant fundraiseRoundDuration = 1 days;

    uint[5] public oneTokenPrice;
    uint[3] public stablecoinsDecimals;

    address private immutable managementAddress;
    address private immutable operatorAddress;
    address private immutable launchpadStakingAddress;

    address private constant BUSDAddress = address(0); // hardcoded to required network

    mapping(address => Participant) public participants;

    enum Tier{FCFS, First, Second, Third, Fourth}

    struct Participant {
        uint tier; 
        uint totalAllocation; 
        uint spentAllocation; 
    }

    constructor(
        uint _totalAmount, 
        uint[5] memory _oneTokenPrice, 
        uint _fundraiseStart, 
        address _managementAddress, 
        address _operatorAddress, 
        address _launchpadStakingAddress
    )
    {
        totalAmount = _totalAmount;
        oneTokenPrice = _oneTokenPrice;
        fundraiseStart = _fundraiseStart;
        actualTokensAmount = _totalAmount;
        managementAddress = _managementAddress;
        operatorAddress = _operatorAddress;
        launchpadStakingAddress = _launchpadStakingAddress;
        unrealizedTokensAmount = _totalAmount;

        uint _actualTierUsers = ILaunchpadStaking(launchpadStakingAddress).totalUsers(uint(Tier.Fourth));
        if(_actualTierUsers == 0){
            actualAllocation = _totalAmount;
        } else {
            actualAllocation = _totalAmount / _actualTierUsers;
        }
        
        actualTierRound = uint(Tier.Fourth);

        vestingStart = _fundraiseStart + fundraiseRoundDuration * 5;

        _setupRole(DEFAULT_ADMIN_ROLE, _operatorAddress);
    }

    function participate(
        address _user, 
        uint _amount, 
        address _stablecoinAddress
    )
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
        returns(uint _underlyingAmount)
    {
        require(participants[_user].totalAllocation >= participants[_user].spentAllocation);
        require(_amount >= ACCURACY, "Fundraise: invalid amount");
        uint _actualTierRound = calculateActualRoundInternal(fundraiseStart, fundraiseDuration, fundraiseRoundDuration);
        (uint _tier, ) = ILaunchpadStaking(launchpadStakingAddress)._userInfo(_user);
        require(_actualTierRound == _tier, "Fundraise: it is not time for you");
        uint _actualTierUsers;
        if(actualTierRound != _actualTierRound){
            if(_actualTierRound == uint(Tier.FCFS)){
                _actualTierUsers = ILaunchpadStaking(launchpadStakingAddress).totalUsers(uint(Tier.First));
            } else {
                _actualTierUsers = ILaunchpadStaking(launchpadStakingAddress).totalUsers(_actualTierRound);
            }

            if(_actualTierUsers == 0){
                actualAllocation = actualTokensAmount;
            } else {
                actualAllocation = actualTokensAmount / _actualTierUsers;
            }

            actualTierRound = _actualTierRound;
        }   
        require(actualAllocation >= _amount, "Fundraise: not enough allocation");

        uint _decimals;
        
        if(_stablecoinAddress != BUSDAddress){
            _decimals = 1e6;
        } else {
            _decimals = ACCURACY;
        }

        _underlyingAmount = _amount * oneTokenPrice[_actualTierRound] / _decimals; 
        if(participants[_user].totalAllocation == 0){
            participants[_user].tier = _tier;
            participants[_user].totalAllocation = actualAllocation;
        }

        require(participants[_user].totalAllocation >= participants[_user].spentAllocation + _amount, "Fundraise:  not enough allocation");
        participants[_user].spentAllocation += _amount;
        unrealizedTokensAmount -= _amount;
    }

    function calculateActualRoundInternal(
        uint _fundraiseStart, 
        uint _fundraiseDuration, 
        uint _fundraiseRoundDuration
    )
        internal 
        view 
        returns(uint)
    {
        require(_fundraiseStart + _fundraiseDuration >= block.timestamp, "Fundraise: fundraise is closed");
        require(block.timestamp >= _fundraiseStart, "Fundraise: fundraise is not opened yet");
        if(block.timestamp >= _fundraiseStart + _fundraiseRoundDuration * uint(Tier.Fourth)){ 
            return uint(Tier.FCFS);
        } else {
            if(block.timestamp >= _fundraiseStart + _fundraiseRoundDuration * uint(Tier.Third)){ 
                return uint(Tier.First);
            } else {
                if(block.timestamp >= _fundraiseStart + _fundraiseRoundDuration * uint(Tier.Second)){ 
                    return uint(Tier.Second);
                } else {
                    if(block.timestamp >= _fundraiseStart + _fundraiseRoundDuration){ 
                        return uint(Tier.Third);
                    } else {
                        return uint(Tier.Fourth);
                    }
                }
            }
        }
    }

    function _userData(address _user)external view returns(uint _tier, uint _totalAllocation, uint _spentAllocation){
        return (participants[_user].tier, participants[_user].totalAllocation, participants[_user].spentAllocation);
    }

}

contract FundraiseFactory is AccessControlOperator {

    address public immutable launchpadStakingAddress;

    constructor(address _launchpadStakingAddress){
        launchpadStakingAddress = _launchpadStakingAddress;
    }

    function createFundraise(
        address _token, 
        uint _totalAmount, 
        uint[5] memory _oneTokenPrice, 
        uint _fundraiseStart, 
        address _managementAddress
    ) 
        external 
        onlyRole(DEFAULT_CALLER)
        returns(address _address)
    {
        require(_token != address(0), "FundraiseFactory: Zero address");

        Fundraise _fundraise = new Fundraise(
            _totalAmount, 
            _oneTokenPrice, 
            _fundraiseStart, 
            _managementAddress, 
            viewOperatorAddress(), 
            launchpadStakingAddress
        );
        _address = address(_fundraise); 
    }
}