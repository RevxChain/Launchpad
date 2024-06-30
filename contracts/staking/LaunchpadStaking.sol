// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

import "../utils/AccessControlOperator.sol";

contract LaunchpadStaking is ERC20Burnable, AccessControlOperator, ReentrancyGuard {
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
    uint public constant MINIMUM_AMOUNT_TO_VOTE = 3000e18;

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

    function deposit(uint underlyingAmount, uint lockDuration) external returns(uint userShare) {
        address _user = msg.sender;
        require(underlyingAmount >= MINIMUM_DEPOSIT_AMOUNT, "LaunchpadStaking: Not enough tokens to deposit");
        require(IERC20(launchTokenAddress).balanceOf(_user) >= underlyingAmount, "LaunchpadStaking: Not enough tokens to deposit");
        require(lockDuration >= MINIMUM_LOCK_DURATION, "LaunchpadStaking: Not enough lock duration");

        uint _beforeUserTier = userInfo[_user].tier;
        updateRewardPool();
        userShare = calculateNewRewardPoolInternal(underlyingAmount) - totalSupply();
        _mint(_user, userShare);

        rewardPool += underlyingAmount;
        userInfo[_user].stakedAmount += underlyingAmount;
        userInfo[_user].tier = calculateTierInternal(userInfo[_user].stakedAmount);
        userInfo[_user].unlockTime = block.timestamp + lockDuration;
        calculaterTotalUsersInternal(_user, _beforeUserTier);

        IERC20(launchTokenAddress).safeTransferFrom(_user, address(this), underlyingAmount);  
    }

    function withdraw(uint sTokenAmount) external returns(uint underlyingAmount) {
        address _user = msg.sender;
        require(block.timestamp >= userInfo[_user].unlockTime, "LaunchpadStaking: Too soon to withdraw");
        require(balanceOf(_user) >= sTokenAmount, "LaunchpadStaking: Not enough sTokens");
        require(sTokenAmount >= ACCURACY, "LaunchpadStaking: Invalid sToken amount");

        uint _beforeUserTier = userInfo[_user].tier;
        updateRewardPool();
        userInfo[_user].stakedAmount = balanceOf(_user) * rewardPool / totalSupply();
        underlyingAmount = sTokenAmount * rewardPool / totalSupply();
        _burn(_user, sTokenAmount);

        rewardPool -= underlyingAmount;
        userInfo[_user].stakedAmount -= underlyingAmount;

        userInfo[_user].tier = calculateTierInternal(userInfo[_user].stakedAmount);
        calculaterTotalUsersInternal(_user, _beforeUserTier);

        IERC20(launchTokenAddress).safeTransfer(_user, underlyingAmount);
    }

    function addPaymentTokens(uint amount) external onlyRole(DEFAULT_CALLER) {
        rewardPool += amount;
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

    function calculaterTotalUsersInternal(address user, uint beforeUserTier) internal {
        if(beforeUserTier != userInfo[user].tier){
            if(beforeUserTier != uint(Tier.FCFS)) totalUsers[beforeUserTier] -= 1;
            totalUsers[userInfo[user].tier] += 1;
        }
    }

    function calculateTierInternal(uint stakedAmount) internal pure returns(uint) {
        if(stakedAmount >= FOURTH_TIER_REQUIREMENT){
            return uint(Tier.Fourth);
        } else {
            if(stakedAmount >= THIRD_TIER_REQUIREMENT){
                return uint(Tier.Third);
            } else {
                if(stakedAmount >= SECOND_TIER_REQUIREMENT){
                    return uint(Tier.Second);
                } else {
                    if(stakedAmount >= FIRST_TIER_REQUIREMENT){
                        return uint(Tier.First);
                    }   else {
                        return uint(Tier.FCFS);
                    }
                }
            }
        }
    }

    function calculateNewRewardPoolInternal(uint amount) internal view returns(uint newPool) {
        return totalSupply() * ACCURACY / (ACCURACY - (amount * ACCURACY / (rewardPool + amount)));
    }

    function transfer(address /* to */, uint256 /* amount */) public override returns(bool) { 
        revert("LaunchpadStaking: Untransferable token");
    }

    function transferFrom(address /* from */, address /* to */, uint256 /* amount */) public override returns(bool) { 
        revert("LaunchpadStaking: Untransferable token");
    }
}