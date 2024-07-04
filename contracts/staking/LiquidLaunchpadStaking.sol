// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../interfaces/ILaunchpadStaking.sol";
import "../interfaces/ILaunchpadDAO.sol";
import "../interfaces/ILaunchpadDAOBribe.sol";

contract LiquidLaunchpadStaking is ReentrancyGuard {
    using SafeERC20 for IERC20;

    address public factory;
    address public controller;
    address public launchpadStaking;
    address public launchpadToken;
    address public launchpadDAO;
    address public launchpadDAOBribe;

    constructor(address _factory) {
        factory = _factory; 
    }

    modifier onlyController() {
        require(msg.sender == controller, "LiquidLaunchpadStaking: forbidden");
        _;
    }

    modifier onlyFactory() {
        require(msg.sender == factory, "LiquidLaunchpadStaking: forbidden");
        _;
    }

    function initialize(
        address _controller, 
        address _launchpadStaking, 
        address _launchpadToken,
        address _launchpadDAO,
        address _launchpadDAOBribe
    ) external onlyFactory() {
        controller = _controller;
        launchpadStaking = _launchpadStaking;
        launchpadToken = _launchpadToken;
        launchpadDAO = _launchpadDAO;
        launchpadDAOBribe = _launchpadDAOBribe;
    }

    function deposit(
        uint underlyingAmount, 
        uint lockDuration, 
        uint sTokenMin
    ) external onlyFactory() returns(uint userShare) {
        require(IERC20(launchpadToken).balanceOf(address(this)) >= underlyingAmount, "LiquidLaunchpadStaking: invalid balance");
        IERC20(launchpadToken).forceApprove(launchpadStaking, underlyingAmount);
        userShare = ILaunchpadStaking(launchpadStaking).deposit(underlyingAmount, lockDuration);
        require(userShare >= sTokenMin, "LiquidLaunchpadStaking: slippage");
    }

    function withdraw(
        uint sTokenAmount, 
        uint underlyingMin, 
        address receiver
    ) external onlyFactory() returns(uint underlyingAmount) {
        if(sTokenAmount == 0) sTokenAmount = IERC20(launchpadStaking).balanceOf(address(this));
        underlyingAmount = ILaunchpadStaking(launchpadStaking).withdraw(sTokenAmount);
        require(underlyingAmount >= underlyingMin, "LiquidLaunchpadStaking: slippage");
        IERC20(launchpadToken).safeTransfer(receiver, underlyingAmount);
    }

    function vote(bytes32 proposalId, bool voteType, bool proposalType) external onlyController() {
        if(proposalType){
            ILaunchpadDAO(launchpadDAO).voteRouterProposal(proposalId, voteType, address(this));
        } else {
            ILaunchpadDAO(launchpadDAO).votePriceProposal(proposalId, voteType, address(this));  
        }
    }

    function setBribePrices(
        address[] calldata tokens, 
        uint[] calldata prices, 
        address priceVerifier
    ) external onlyController() {
        ILaunchpadDAOBribe(launchpadDAOBribe).setBribePrices(tokens, prices, priceVerifier);
    }

    function openBribe(uint openToTimestamp, address priceVerifier) external onlyController() {
        ILaunchpadDAOBribe(launchpadDAOBribe).openBribe(openToTimestamp, priceVerifier);
    }

    function setBribeTime(uint openToTimestamp) external onlyController() {
        ILaunchpadDAOBribe(launchpadDAOBribe).setBribeTime(openToTimestamp);
    }

    function closeBribe() external onlyController() {
        ILaunchpadDAOBribe(launchpadDAOBribe).closeBribe();
    }

    function withdrawBribes(
        address[] calldata tokens, 
        uint[] calldata amounts, 
        address[] calldata receivers
    ) external onlyController() {
        ILaunchpadDAOBribe(launchpadDAOBribe).withdrawBribes(tokens, amounts, receivers);
    }

    function getStakeInfo() external view returns(uint sTokenBalance, uint tier, uint stakedAmount, uint unlockTime) {
        return (
            IERC20(launchpadStaking).balanceOf(address(this)),
            ILaunchpadStaking(launchpadStaking).userInfo(address(this)).tier,
            ILaunchpadStaking(launchpadStaking).userInfo(address(this)).stakedAmount,
            ILaunchpadStaking(launchpadStaking).userInfo(address(this)).unlockTime
        );
    }

}