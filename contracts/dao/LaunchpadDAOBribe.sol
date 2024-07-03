// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "../interfaces/ILaunchpadStaking.sol";

contract LaunchpadDAOBribe is ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint public constant MINIMUM_BRIBE_TIME = 7 days;
    uint public constant MINIMUM_AMOUNT_TO_VOTE = 3000e18;

    address public immutable launchpadStakingAddress;

    mapping(address => GrafterInfo) public grafterInfo;

    struct GrafterInfo {
        bool opened;
        uint openedTo;
        address purchasedBy;
        uint purchasedTo;
        mapping(address => uint) pricePerSec;
        mapping(address => uint) earned;
    }

    struct bribeToCalldata {
        address[] grafter;
        address[] paymentToken;
        uint[] expectedPrice;
        uint[] bribeToTimestamp;
    }

    constructor(address _launchpadStakingAddress) {
        launchpadStakingAddress = _launchpadStakingAddress;
    }

    function bribeTo(bribeToCalldata calldata $) external payable nonReentrant() { 
        (address _user, uint _ethLeft, uint _length) = (msg.sender, msg.value, $.grafter.length);
        require(
            _length == $.paymentToken.length &&
            _length == $.expectedPrice.length &&
            _length == $.bribeToTimestamp.length,
            "LaunchpadDAOBribe: invalid data"
        );

        for(uint i; _length > i; i++){
            closeExpiredBribe($.grafter[i]);

            GrafterInfo storage info = grafterInfo[$.grafter[i]];

            require(info.opened, "LaunchpadDAOBribe: closed bribe");
            require(info.openedTo > block.timestamp, "LaunchpadDAOBribe: expired bribe");
            require($.bribeToTimestamp[i] > block.timestamp, "LaunchpadDAOBribe: invalid date");
            require(info.openedTo >= $.bribeToTimestamp[i], "LaunchpadDAOBribe: invalid date");
            require(info.purchasedBy == address(0), "LaunchpadDAOBribe: already purchased");
            require(info.pricePerSec[$.paymentToken[i]] > 0, "LaunchpadDAOBribe: invalid payment");
            if($.expectedPrice[i] > 0) 
            require($.expectedPrice[i] == info.pricePerSec[$.paymentToken[i]], "LaunchpadDAOBribe: slippage");

            uint _paymentAmount = info.pricePerSec[$.paymentToken[i]] * ($.bribeToTimestamp[i] - block.timestamp);

            if($.paymentToken[i] == address(0)){
                require(_ethLeft >= _paymentAmount, "LaunchpadDAOBribe: invalid eth value");
                _ethLeft -= _paymentAmount;
            } else {
                require(
                    IERC20($.paymentToken[i]).balanceOf(_user) >= _paymentAmount, 
                    "LaunchpadDAOBribe: invalid balance"
                );

                uint _balanceBefore = IERC20($.paymentToken[i]).balanceOf(address(this));
                IERC20($.paymentToken[i]).safeTransferFrom(_user, address(this), _paymentAmount);

                require(
                    IERC20($.paymentToken[i]).balanceOf(address(this)) >= _balanceBefore + _paymentAmount, 
                    "LaunchpadDAOBribe: transfer error"
                );
                
                _paymentAmount = IERC20($.paymentToken[i]).balanceOf(address(this)) - _balanceBefore;
            }

            info.earned[$.paymentToken[i]] += _paymentAmount;
            info.purchasedBy = _user;
            info.purchasedTo = $.bribeToTimestamp[i];
        }

        if(_ethLeft > 0){
            (bool _success, ) = _user.call{value: _ethLeft}("");
            require(_success, "LaunchpadDAOBribe: eth transfer failed");
        }
    }

    function setBribePrices(address[] calldata tokens, uint[] calldata prices, address priceVerifier) external {
        (address _user, uint _length) = (msg.sender, tokens.length);
        require(_length == prices.length, "LaunchpadDAOBribe: invalid data");

        for(uint i; _length > i; i++) grafterInfo[_user].pricePerSec[tokens[i]] = prices[i];

        require(grafterInfo[_user].pricePerSec[priceVerifier] > 0, "LaunchpadDAOBribe: invalid priceVerifier");
    }

    function openBribe(uint openToTimestamp, address priceVerifier) external {
        address _user = msg.sender;

        GrafterInfo storage info = grafterInfo[_user];

        require(info.pricePerSec[priceVerifier] > 0, "LaunchpadDAOBribe: invalid priceVerifier");
        require(!info.opened, "LaunchpadDAOBribe: opened");
        require(openToTimestamp >= MINIMUM_BRIBE_TIME + block.timestamp, "LaunchpadDAOBribe: too short");
        require(
            ILaunchpadStaking(launchpadStakingAddress).userInfo(_user).stakedAmount >= MINIMUM_AMOUNT_TO_VOTE, 
            "LaunchpadDAOBribe: not enough stake"
        );

        info.opened = true;
        info.openedTo = openToTimestamp;
    }

    function setBribeTime(uint openToTimestamp) external {
        address _user = msg.sender;
        closeExpiredBribe(_user);

        require(grafterInfo[_user].opened, "LaunchpadDAOBribe: closed");

        grafterInfo[_user].openedTo = openToTimestamp;
    }

    function closeBribe() external {
        address _user = msg.sender;
        closeExpiredBribe(_user);

        require(grafterInfo[_user].opened, "LaunchpadDAOBribe: closed");

        grafterInfo[_user].opened = false;
        grafterInfo[_user].openedTo = 0;
    }

    function withdrawBribes(
        address[] calldata tokens, 
        uint[] memory amounts, 
        address[] calldata receivers
    ) external nonReentrant() {
        (address _user, uint _length) = (msg.sender, tokens.length);
        closeExpiredBribe(_user);
        require(
            _length == amounts.length && 
            _length == receivers.length, 
            "LaunchpadDAOBribe: invalid data"
        );

        for(uint i; _length > i; i++){
            require(amounts[i] > 0, "LaunchpadDAOBribe: zero amount");
            require(grafterInfo[_user].earned[tokens[i]] >= amounts[i], "LaunchpadDAOBribe: not enough earned");

            if(tokens[i] == address(0)){
                (bool _success, ) = receivers[i].call{value: amounts[i]}("");
                if(!_success) continue;
            } else {
                uint _balanceBefore = IERC20(tokens[i]).balanceOf(address(this));
                IERC20(tokens[i]).safeTransfer(receivers[i], amounts[i]);
                amounts[i] = _balanceBefore - IERC20(tokens[i]).balanceOf(address(this));
            }

            grafterInfo[_user].earned[tokens[i]] -= amounts[i];
        }
    }

    function closeExpiredBribe(address grafter) public {
        if(grafterInfo[grafter].purchasedBy != address(0) && block.timestamp > grafterInfo[grafter].purchasedTo){
            grafterInfo[grafter].purchasedBy = address(0);
            grafterInfo[grafter].purchasedTo = 0;
        }
    }

    function validateBribe(address user, address grafter) external view {
        GrafterInfo storage info = grafterInfo[grafter];

        if(grafter != user){
            require(info.purchasedBy == user, "LaunchpadDAOBribe: vote denied");
            require(info.purchasedTo >= block.timestamp, "LaunchpadDAOBribe: vote denied");
        } else {
            require(info.purchasedBy == address(0), "LaunchpadDAOBribe: vote denied");
            require(info.purchasedTo == 0, "LaunchpadDAOBribe: vote denied");
            require(!info.opened, "LaunchpadDAOBribe: vote denied");
            require(info.openedTo == 0, "LaunchpadDAOBribe: vote denied");
        }
    }

    function getPaymentTokenData(address grafter, address paymentToken) external view returns(uint pricePerSec, uint earned) {
        return (grafterInfo[grafter].pricePerSec[paymentToken], grafterInfo[grafter].earned[paymentToken]);
    }

}