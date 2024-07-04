// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./LiquidLaunchpadStaking.sol";

import "../interfaces/ILiquidLaunchpadStaking.sol";
import "../interfaces/ILiquidStakingToken.sol";

contract LiquidLaunchpadStakingFactory is ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint public constant MINIMUM_AMOUNT_TO_VOTE = 3000e18; 
    uint public constant MINIMUM_LOCK_DURATION = 26 weeks;

    address public immutable controller;
    address public immutable launchpadStaking;
    address public immutable launchpadToken;
    address public immutable launchpadDAO;
    address public immutable launchpadDAOBribe;
    address public immutable liquidStakingToken;

    uint public modulesCounter;

    mapping(address /* moduleAddress */ => bool) public moduleExist;

    constructor(
        address _controller, 
        address _launchpadStaking, 
        address _launchpadToken,
        address _launchpadDAO,
        address _launchpadDAOBribe,
        address _liquidStakingToken
    ) {
        controller = _controller;
        launchpadStaking = _launchpadStaking;
        launchpadToken = _launchpadToken;
        launchpadDAO = _launchpadDAO;
        launchpadDAOBribe = _launchpadDAOBribe;
        liquidStakingToken = _liquidStakingToken;
    }

    function deposit(
        uint underlyingAmount,  
        uint sTokenMin,
        address module
    ) external nonReentrant() returns(uint userShare) {
        address _user = msg.sender;

        if(module != address(0)){
            require(moduleExist[module], "LiquidLaunchpadStakingFactory: invalid module");
            (, , uint _stakedAmount, ) = ILiquidLaunchpadStaking(module).getStakeInfo();
            require(MINIMUM_AMOUNT_TO_VOTE > _stakedAmount, "LiquidLaunchpadStakingFactory: invalid amount");
        } else {
            bytes memory bytecode = type(LiquidLaunchpadStaking).creationCode;
            bytes32 salt = keccak256(abi.encodePacked(address(this), modulesCounter));
            assembly {
                module := create2(0, add(bytecode, 32), mload(bytecode), salt)
            }

            ILiquidLaunchpadStaking(module).initialize(
                controller, 
                launchpadStaking, 
                launchpadToken,
                launchpadDAO,
                launchpadDAOBribe
            );

            moduleExist[module] = true;
            modulesCounter += 1;
        }

        IERC20(launchpadToken).safeTransferFrom(_user, module, underlyingAmount);
        userShare = ILiquidLaunchpadStaking(module).deposit(underlyingAmount, MINIMUM_LOCK_DURATION, sTokenMin);
        ILiquidStakingToken(liquidStakingToken).mint(_user, userShare);
    }

    function withdraw(
        uint sTokenAmount, 
        uint underlyingMin, 
        address receiver,
        address module
    ) external nonReentrant() returns(uint underlyingAmount) {
        address _user = msg.sender;

        require(moduleExist[module], "LiquidLaunchpadStakingFactory: invalid module");

        underlyingAmount = ILiquidLaunchpadStaking(module).withdraw(sTokenAmount, underlyingMin, receiver);
        ILiquidStakingToken(liquidStakingToken).burnFrom(_user, sTokenAmount);
    }

}