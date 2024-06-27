// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./utils/Pausable.sol";

import "./interfaces/IFundraiseFactory.sol";
import "./interfaces/ITokenFactory.sol";
import "./interfaces/IVestingOperator.sol";
import "./interfaces/ILaunchpadStaking.sol";
import "./interfaces/ILaunchpadToken.sol";
import "./interfaces/ILiquidityVault.sol";

contract BaseOperator is AccessControl, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    uint public constant DEFAULT_FUNDRAISE_PRICE = 5000e18;  
    uint public constant MINIMUM_LIQUIDITY_SHARE = 2; 
    uint public constant MINIMUM_LAUNCHPAD_SHARE = 4; 
    uint public constant MINIMUM_LIQUIDITY_LOCK_DURATION = 90 weeks; 
    uint public constant MINIMUM_TIME_TO_FUNDRAISE_START = 8 weeks; 
    uint public constant MINIMUM_TIME_TO_CANCEL_FUNDRAISE = 16 weeks; 
    uint public constant MINIMUM_ETHER_LIQUIDITY = 10e18; 

    address public immutable liquidityVault;
    address public immutable launchpadToken;
    address public immutable launchpadStaking;
    address public immutable fundraiseFactory;
    address public immutable vestingOperator;

    address private constant USDCAddress = address(0); // hardcoded to required network
    address private constant USDTAddress = address(0);
    address private constant BUSDAddress = address(0);

    address[] public allSupportedTokens;

    bytes32 public constant TOKEN_MINTER = keccak256("TOKEN_MINTER");

    mapping(address => SupportedTokenData) public tokenData; 
    mapping(address => mapping(address => bool)) public refunded;

    enum Amount{Manage, Launch, Liquid}

    enum Status{Audit, Rejected, Confirmed, Fundraise, Launched, Cancellation}

    struct SupportedTokenData {
        string name;
        string symbol;
        address managementAddress;
        address minterAddress;
        address fundraiseAddress;
        uint fundraiseStart;
        address vestingAddress;
        uint[3] amounts;
        uint[3] fundsRaised;
        uint status;
    }

    constructor(
        address _launchpadToken, 
        address _fundraiseFactory, 
        address _vestingOperator,  
        address _liquidityVault,
        address _launchpadStaking,
        address _tokenMinter
    ) {
        launchpadToken = _launchpadToken;
        fundraiseFactory = _fundraiseFactory;
        vestingOperator = _vestingOperator;
        liquidityVault = _liquidityVault;
        launchpadStaking = _launchpadStaking;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(TOKEN_MINTER, _tokenMinter);
    }

    function confirmTokenToFundraise(address token, address minter) external onlyRole(DEFAULT_ADMIN_ROLE) {
        statusVerificationInternal(token, uint(Status.Audit));
        statusShiftInternal(token, uint(Status.Confirmed));
        tokenData[token].minterAddress = minter;
    }

    function rejectTokenToFundraise(address token) external onlyRole(DEFAULT_ADMIN_ROLE) {
        statusVerificationInternal(token, uint(Status.Audit));
        statusShiftInternal(token, uint(Status.Rejected));
    }

    function createFundraise( 
        address token,
        uint[3] memory amounts, // 0 - teamAmount,  1 - launchPad amount, 2 - liquidityAmount 
        uint[5] memory oneTokenPrice, // enum Tier
        uint fundraiseStart,
        uint liquidityLockDuration, // if 0 = burn
        address minter 
    ) external payable nonReentrant() paused() returns(address managementAddress /* returns fundraise address */) {
        managementAddress = msg.sender;
        uint _etherLiquidity = msg.value;
        managementVerificationInternal(token);
        statusVerificationInternal(token, uint(Status.Confirmed));
        balanceVerificationInternal(launchpadToken, managementAddress, DEFAULT_FUNDRAISE_PRICE);
        uint _totalAmount = amounts[uint(Amount.Manage)] + amounts[uint(Amount.Launch)] + amounts[uint(Amount.Liquid)];
        ratioVerificationInternal(amounts[uint(Amount.Liquid)], MINIMUM_LIQUIDITY_SHARE, _totalAmount);
        ratioVerificationInternal(amounts[uint(Amount.Launch)], MINIMUM_LAUNCHPAD_SHARE, _totalAmount);

        require(fundraiseStart >= block.timestamp + MINIMUM_TIME_TO_FUNDRAISE_START, "BaseOperator: Too soon to start fundraise");
        require(liquidityLockDuration == 0 || liquidityLockDuration >= MINIMUM_LIQUIDITY_LOCK_DURATION, "BaseOperator: Too scant liquidity lock duration");
        require(_etherLiquidity >= MINIMUM_ETHER_LIQUIDITY, "BaseOperator: Not enough ether to provide liquidity");
        require(minter == tokenData[token].minterAddress, "BaseOperator: Wrong minter address");

        tokenData[token].fundraiseAddress = IFundraiseFactory(fundraiseFactory).createFundraise(
            token, 
            amounts[uint(Amount.Launch)], 
            oneTokenPrice, 
            fundraiseStart, 
            managementAddress
        );

        IERC20Token(token).initialize(
            liquidityVault,
            amounts[uint(Amount.Manage)] + amounts[uint(Amount.Launch)],
            amounts[uint(Amount.Liquid)],
            minter
        );

        ILiquidityVault(liquidityVault)._initializeNewToken{value: _etherLiquidity}(
            token, 
            managementAddress, 
            amounts[uint(Amount.Liquid)], 
            fundraiseStart,
            liquidityLockDuration
        );

        tokenData[token].fundraiseStart = fundraiseStart;
        tokenData[token].amounts = amounts;
        statusShiftInternal(token, uint(Status.Fundraise));
        paymentInternal(managementAddress);
        managementAddress = tokenData[token].fundraiseAddress;
    }

    function fundraiseParticipate(
        address token, 
        uint amount, 
        address stablecoinAddress
    ) external nonReentrant() paused() {
        address _user = msg.sender;
        statusVerificationInternal(token, uint(Status.Fundraise));
        stablecoinAddressVerificationInternal(stablecoinAddress);
        uint _underlyingAmount = IFundraise(tokenData[token].fundraiseAddress).participate(_user, amount, stablecoinAddress);
        balanceVerificationInternal(stablecoinAddress, _user, _underlyingAmount);
        IERC20(stablecoinAddress).safeTransferFrom(_user, address(this), _underlyingAmount);
        if(stablecoinAddress == USDCAddress) tokenData[token].fundsRaised[0] += _underlyingAmount;
        stablecoinAddress == USDTAddress ? tokenData[token].fundsRaised[1] += _underlyingAmount : tokenData[token].fundsRaised[2] += _underlyingAmount;
    }

    function cancelFundraise(address token) external onlyRole(DEFAULT_ADMIN_ROLE) {
        statusVerificationInternal(token, uint(Status.Fundraise));
        require(block.timestamp >= tokenData[token].fundraiseStart + MINIMUM_TIME_TO_CANCEL_FUNDRAISE, "BaseOperator: Too soon to cancel");
        statusShiftInternal(token, uint(Status.Cancellation));
    } 

    function refund(address token, address stablecoinAddress) external nonReentrant() {
        address _user = msg.sender;
        require(!refunded[_user][token], "BaseOperator: Refunded already");
        statusVerificationInternal(token, uint(Status.Cancellation));
        stablecoinAddressVerificationInternal(stablecoinAddress);
        (uint _tier, , uint _spentAllocation) = IFundraise(tokenData[token].fundraiseAddress)._userData(_user);
        uint _tokenPrice = IFundraise(tokenData[token].fundraiseAddress).oneTokenPrice(_tier);
        uint _refundAmount = _tokenPrice * _spentAllocation;
        balanceVerificationInternal(stablecoinAddress, address(this), _refundAmount);
        IERC20(stablecoinAddress).safeTransfer(_user, _refundAmount);
        refunded[_user][token] = true;
    }

    function createSimpleScheduleVesting( 
        address token,
        uint[6] memory cliffTimestamp
    ) external nonReentrant() paused() returns(address vestingAddress) {   
        managementVerificationInternal(token);
        statusVerificationInternal(token, uint(Status.Fundraise));

        vestingAddress = IVestingOperator(vestingOperator).createSimpleScheduleVesting( 
            tokenData[token].managementAddress,
            token,
            tokenData[token].fundraiseAddress,
            cliffTimestamp,
            tokenData[token].fundraiseStart,
            tokenData[token].amounts[uint(Amount.Manage)]
        );

        createVestingInternal(token, vestingAddress);
    }

    function createScheduleVesting( 
        address token,
        uint[30] memory cliffTimestamp, 
        uint[30] memory cliffAmount
    ) external nonReentrant() paused() returns(address vestingAddress) {
        managementVerificationInternal(token);
        statusVerificationInternal(token, uint(Status.Fundraise));

        vestingAddress = IVestingOperator(vestingOperator).createScheduleVesting(  
            tokenData[token].managementAddress,
            token,
            tokenData[token].fundraiseAddress,
            cliffTimestamp, 
            cliffAmount,
            tokenData[token].fundraiseStart,
            tokenData[token].amounts[uint(Amount.Manage)]
        );

        createVestingInternal(token, vestingAddress);
    }

    function createLinearVesting( 
        address token,
        uint vestingStartTimestamp,
        uint vestingTeamStartTimestamp,
        uint vestingDuration
    ) external nonReentrant() paused() returns(address vestingAddress) {
        managementVerificationInternal(token);
        statusVerificationInternal(token, uint(Status.Fundraise));

        vestingAddress = IVestingOperator(vestingOperator).createLinearVesting(  
            token,  
            tokenData[token].managementAddress, 
            tokenData[token].fundraiseAddress, 
            tokenData[token].fundraiseStart,
            tokenData[token].amounts[uint(Amount.Manage)], 
            vestingStartTimestamp,
            vestingTeamStartTimestamp,
            vestingDuration
        );

        createVestingInternal(token, vestingAddress);
    }

    function createCliffLinearVesting( 
        address token,
        uint vestingDuration,
        uint[6] memory vestingStartTimestamp
    ) external nonReentrant() paused() returns(address vestingAddress) {
        managementVerificationInternal(token);
        statusVerificationInternal(token, uint(Status.Fundraise));

        vestingAddress = IVestingOperator(vestingOperator).createCliffLinearVesting(  
            token,  
            tokenData[token].managementAddress, 
            tokenData[token].fundraiseAddress, 
            tokenData[token].fundraiseStart,
            tokenData[token].amounts[uint(Amount.Manage)],
            vestingDuration,
            vestingStartTimestamp
        );

        createVestingInternal(token, vestingAddress);
    }

    function changeOver() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _changeOver();
    }

    function tokenToAuditExternal(
        address token,
        string calldata name, 
        string calldata symbol, 
        address managementAddress
    ) external onlyRole(TOKEN_MINTER) {
        tokenData[token].name = name;
        tokenData[token].symbol = symbol;
        tokenData[token].managementAddress = managementAddress;
        tokenData[token].status = uint(Status.Audit);
        allSupportedTokens.push(token);
    }

    function statusShiftInternal(address token, uint status) internal { 
        tokenData[token].status = status;
    }
    
    function paymentInternal(address managementAddress) internal {
        uint _halfPayment = DEFAULT_FUNDRAISE_PRICE / 2;
        IERC20(launchpadToken).safeTransferFrom(managementAddress, launchpadStaking, _halfPayment);
        ILaunchpadToken(launchpadToken).burnFrom(managementAddress, _halfPayment);
        ILaunchpadStaking(launchpadStaking)._addPaymentTokens(_halfPayment);
    }

    function createVestingInternal(address token, address vestingAddress) internal {
        tokenData[token].vestingAddress = vestingAddress;
        uint _amountToVesting = tokenData[token].amounts[uint(Amount.Manage)] + tokenData[token].amounts[uint(Amount.Launch)];
        IERC20(token).safeTransfer(vestingAddress, _amountToVesting);
        statusShiftInternal(token, uint(Status.Launched));
        IERC20(USDCAddress).safeTransfer(tokenData[token].managementAddress, tokenData[token].fundsRaised[0]);
        IERC20(USDTAddress).safeTransfer(tokenData[token].managementAddress, tokenData[token].fundsRaised[1]);
        IERC20(BUSDAddress).safeTransfer(tokenData[token].managementAddress, tokenData[token].fundsRaised[2]);
    } 
    
    function statusVerificationInternal(address token, uint status) internal view {
        require(tokenData[token].status == status, "BaseOperator: Invalid status");
    }

    function balanceVerificationInternal(address token, address user, uint kink) internal view {
        require(IERC20(token).balanceOf(user) >= kink, "BaseOperator: Not enough tokens");
    }

    function managementVerificationInternal(address token) internal view {   
        require(msg.sender == tokenData[token].managementAddress, "BaseOperator: You are not a management");
    }

    function stablecoinAddressVerificationInternal(address stablecoinAddress) internal pure {
        require(stablecoinAddress == USDCAddress || stablecoinAddress == USDTAddress || stablecoinAddress == BUSDAddress, "BaseOperator: Wrong stablecoin");
    }

    function ratioVerificationInternal(uint amount, uint minimum, uint totalAmount) internal pure {
        require(amount * minimum >= totalAmount, "BaseOperator: Wrong tokens amounts ratio");
    }
}
