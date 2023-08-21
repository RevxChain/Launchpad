// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "./utils/AccessControlOperator.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract LaunchpadStaking is ERC20, AccessControlOperator, ReentrancyGuard, ERC20Burnable {
    using SafeERC20 for IERC20;

    uint public rewardPool;
    uint public lastUpdateRewardPool;

    uint public constant BASE_STAKING_RATE = 100000000000000000; 
    uint public constant MINIMUM_LOCK_DURATION = 26 weeks;
    uint public constant ONE_YEAR_DURATION = 52 weeks; 
    uint public constant ACCURACY = 1e18;
    uint public constant INITIALIZATION_VALUE = 10000; 
    uint public constant MINIMUM_DEPOSIT_AMOUNT = 100e18; 
    uint public constant FIRST_TIER_REQUIREMENT = 500e18; 
    uint public constant SECOND_TIER_REQUIREMENT =  3000e18; 
    uint public constant THIRD_TIER_REQUIREMENT = 10000e18; 
    uint public constant FOURTH_TIER_REQUIREMENT = 20000e18; 

    uint[5] public totalUsers;

    address public immutable launchTokenAddress;

    mapping(address => UserInfo) public userInfo;

    enum Tier{FCFS, First, Second, Third, Fourth}

    struct UserInfo {
        uint tier; 
        uint stakedAmount; 
        uint unlockTime;
    }

    constructor(address _launchTokenAddress) ERC20("sToken", "ST") {
        launchTokenAddress = _launchTokenAddress;
        _mint(address(this), INITIALIZATION_VALUE);
        lastUpdateRewardPool = block.timestamp;
        rewardPool = INITIALIZATION_VALUE;
    }

    function deposit(uint _underlyingAmount, uint _lockDuration) external {
        address _user = msg.sender;
        require(_underlyingAmount >= MINIMUM_DEPOSIT_AMOUNT, "LaunchpadStaking: Not enough tokens to deposit");
        require(IERC20(launchTokenAddress).balanceOf(_user) >= _underlyingAmount, "LaunchpadStaking: Not enough tokens to deposit");
        require(_lockDuration >= MINIMUM_LOCK_DURATION, "LaunchpadStaking: Not enough lock duration");
        uint _beforeUserTier = userInfo[_user].tier;
        updateRewardPool();
        uint userShare = calculateNewRewardPoolInternal(_underlyingAmount) - totalSupply();
        _mint(_user, userShare);
        rewardPool += _underlyingAmount;
        userInfo[_user].stakedAmount += _underlyingAmount;
        userInfo[_user].tier = calculateTierInternal(userInfo[_user].stakedAmount);
        userInfo[_user].unlockTime = block.timestamp + _lockDuration;
        calculaterTotalUsersInternal(_user, _beforeUserTier);
        IERC20(launchTokenAddress).safeTransferFrom(_user, address(this), _underlyingAmount);  
    }

    function withdraw(uint _sTokenAmount) external {
        address _user = msg.sender;
        require(block.timestamp >= userInfo[_user].unlockTime, "LaunchpadStaking: Too soon to withdraw");
        require(balanceOf(_user) >= _sTokenAmount, "LaunchpadStaking: Not enough sTokens");
        require(_sTokenAmount >= ACCURACY, "LaunchpadStaking: Invalid sToken amount");
        uint _beforeUserTier = userInfo[_user].tier;
        updateRewardPool();
        userInfo[_user].stakedAmount = balanceOf(_user) * rewardPool / totalSupply();
        uint _underlyingAmount = _sTokenAmount * rewardPool / totalSupply();
        _burn(_user, _sTokenAmount);
        rewardPool -= _underlyingAmount;
        userInfo[_user].stakedAmount -= _underlyingAmount;
        userInfo[_user].tier = calculateTierInternal(userInfo[_user].stakedAmount);
        calculaterTotalUsersInternal(_user, _beforeUserTier);
        IERC20(launchTokenAddress).safeTransfer(_user, _underlyingAmount);
    }

    function _addPaymentTokens(uint _amount) external onlyRole(DEFAULT_CALLER) {
        rewardPool += _amount;
    }

    function updateRewardPool() public returns(uint) {
        if ((block.timestamp - lastUpdateRewardPool) > 0){
            uint rewardPoolIncrease = 
            (rewardPool * BASE_STAKING_RATE * ((block.timestamp - lastUpdateRewardPool) * ACCURACY / ONE_YEAR_DURATION)) / (ACCURACY * ACCURACY);
            rewardPool += rewardPoolIncrease;
            lastUpdateRewardPool = block.timestamp;
        }
        return rewardPool;
    }

    function _userInfo(address _user) external view returns(uint tier, uint stakedAmount) { 
        return (userInfo[_user].tier, userInfo[_user].stakedAmount);
    }

    function calculaterTotalUsersInternal(address _user, uint _beforeUserTier) internal {
        if(_beforeUserTier != userInfo[_user].tier){
            if(_beforeUserTier != uint(Tier.FCFS)){
                totalUsers[_beforeUserTier] -= 1;
            }
            totalUsers[userInfo[_user].tier] += 1;
        }
    }

    function calculateTierInternal(uint _stakedAmount) internal pure returns(uint) {
        if(_stakedAmount >= FOURTH_TIER_REQUIREMENT){
            return uint(Tier.Fourth);
        } else {
            if(_stakedAmount >= THIRD_TIER_REQUIREMENT){
                return uint(Tier.Third);
            } else {
                if(_stakedAmount >= SECOND_TIER_REQUIREMENT){
                    return uint(Tier.Second);
                } else {
                    if(_stakedAmount >= FIRST_TIER_REQUIREMENT){
                        return uint(Tier.First);
                    }   else {
                        return uint(Tier.FCFS);
                    }
                }
            }
        }
    }

    function calculateNewRewardPoolInternal(uint _amount) internal view returns(uint newPool) {
        return totalSupply() * ACCURACY / (ACCURACY - (_amount * ACCURACY / (rewardPool + _amount)));
    }

    function _transfer(address from, address to, uint256 amount) internal view override { 
        require(decimals() == 0, "LaunchpadStaking: Untransferable token");
    }
}