// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./utils/AccessControlOperator.sol";

import "./interfaces/IFundraiseFactory.sol";

contract LinearVesting is AccessControl {
    using SafeERC20 for IERC20;

    uint private immutable teamAmount; 
    uint private immutable vestingDuration;

    uint[6] public vestingStartTimestamp;

    address private immutable managementAddress;
    address private immutable fundraiseAddress;
    address private immutable underlyingTokenAddress;

    enum Tier{FCFS, First, Second, Third, Fourth, Team}

    mapping(address => UserData) public userData;

    struct UserData {
        uint tier;
        uint totalAllocation;
        uint claimedTokens;
        uint lastClaimTimestamp;
        uint vestingStartTimestamp;
    }

    constructor(
        address _underlyingTokenAddress, 
        address _managementAddress, 
        address _fundraiseAddress,  
        address _operatorAddress,
        uint _teamAmount,
        uint _vestingDuration,
        uint[6] memory _vestingStartTimestamp
    ) {
        underlyingTokenAddress = _underlyingTokenAddress;
        managementAddress = _managementAddress;
        fundraiseAddress = _fundraiseAddress;
        teamAmount = _teamAmount;
        vestingStartTimestamp = _vestingStartTimestamp;
        vestingDuration = _vestingDuration;
        _grantRole(DEFAULT_ADMIN_ROLE, _operatorAddress);
    }

    function claim() external returns(uint tokensToClaim) {
        (address _user, uint _amount, uint _tier) = (msg.sender, 0, 0);

        if(userData[_user].totalAllocation == 0){
            if(_user != managementAddress){
                (_tier, ,_amount) = IFundraise(fundraiseAddress)._userData(_user);
                require(_amount > 0, "Vesting: You are not a participant");
                if(vestingStartTimestamp[1] == 0){
                    _tier = 0;
                }
                userData[_user].tier = _tier;
                userData[_user].lastClaimTimestamp = vestingStartTimestamp[_tier];
                userData[_user].vestingStartTimestamp = vestingStartTimestamp[_tier];
            } else {
                _amount = teamAmount;
                userData[_user].tier = uint(Tier.Team);
                userData[_user].lastClaimTimestamp = vestingStartTimestamp[uint(Tier.Team)];
                userData[_user].vestingStartTimestamp = vestingStartTimestamp[uint(Tier.Team)];
            }

            userData[_user].totalAllocation = _amount;
        }

        require(userData[_user].totalAllocation > userData[_user].claimedTokens, "Vesting: All tokens claimed already");
        require(block.timestamp > userData[_user].lastClaimTimestamp, "Vesting: Too soon to claim");

        uint _elapsedTime;
        
        if(block.timestamp >= userData[_user].vestingStartTimestamp + vestingDuration){
            tokensToClaim = userData[_user].totalAllocation - userData[_user].claimedTokens; 
        } else {
            _elapsedTime = block.timestamp - userData[_user].lastClaimTimestamp;
            tokensToClaim = _elapsedTime * userData[_user].totalAllocation / vestingDuration;
        }
        userData[_user].claimedTokens += tokensToClaim;
        require(userData[_user].totalAllocation >= userData[_user].claimedTokens, "Vesting: All tokens claimed already");

        IERC20(underlyingTokenAddress).safeTransfer(_user, tokensToClaim);
    }
}

contract LinearVestingFactory is AccessControlOperator {

    function createLinearVesting(
        address _token,  
        address _managementAddress, 
        address _fundraiseAddress, 
        uint _teamAmount, 
        uint _vestingDuration,
        uint[6] memory _vestingStartTimestamp
    ) external onlyRole(DEFAULT_CALLER) returns(address vestingAddress) {
        require(_token != address(0), "VestingFactory: Zero address");
        LinearVesting _vesting = new LinearVesting(
            _token, 
            _managementAddress, 
            _fundraiseAddress,  
            getOperatorAddress(),
            _teamAmount,
            _vestingDuration,
            _vestingStartTimestamp 
        );
        vestingAddress = address(_vesting);
    }
}

