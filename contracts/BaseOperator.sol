// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
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

    bytes32 public constant TOKEN_MINTER = keccak256(abi.encode("TOKEN_MINTER"));

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
    )
    {
        launchpadToken = _launchpadToken;
        fundraiseFactory = _fundraiseFactory;
        vestingOperator = _vestingOperator;
        liquidityVault = _liquidityVault;
        launchpadStaking = _launchpadStaking;
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(TOKEN_MINTER, _tokenMinter);
    }

    function confirmTokenToFundraise(address _token, address _minter)external onlyRole(DEFAULT_ADMIN_ROLE){
        statusVerificationInternal(_token, uint(Status.Audit));
        statusShiftInternal(_token, uint(Status.Confirmed));
        tokenData[_token].minterAddress = _minter;
    }

    function rejectTokenToFundraise(address _token)external onlyRole(DEFAULT_ADMIN_ROLE){
        statusVerificationInternal(_token, uint(Status.Audit));
        statusShiftInternal(_token, uint(Status.Rejected));
    }

    function createFundraise( 
        address _token,
        uint[3] memory _amounts, // 0 - teamAmount,  1 - launchPad amount , 2 - liquidityAmount 
        uint[5] memory _oneTokenPrice, // enum Tier
        uint _fundraiseStart,
        uint _liquidityLockDuration, // if 0 = burn
        address _minter 
    )
        external 
        payable 
        nonReentrant()
        paused()
        returns(address _managementAddress) // actually returns fundraise address
    {
        _managementAddress = msg.sender;
        uint _etherLiquidity = msg.value;
        managementVerificationInternal(_token);
        statusVerificationInternal(_token, uint(Status.Confirmed));
        balanceVerificationInternal(launchpadToken, _managementAddress, DEFAULT_FUNDRAISE_PRICE);
        uint _totalAmount = _amounts[uint(Amount.Manage)] + _amounts[uint(Amount.Launch)] + _amounts[uint(Amount.Liquid)];
        ratioVerificationInternal(_amounts[uint(Amount.Liquid)], MINIMUM_LIQUIDITY_SHARE, _totalAmount);
        ratioVerificationInternal(_amounts[uint(Amount.Launch)], MINIMUM_LAUNCHPAD_SHARE, _totalAmount);
        require(_fundraiseStart >= block.timestamp + MINIMUM_TIME_TO_FUNDRAISE_START, "BaseOperator: Too soon to start fundraise");
        require(_liquidityLockDuration == 0 || _liquidityLockDuration >= MINIMUM_LIQUIDITY_LOCK_DURATION, "BaseOperator: Too scant liquidity lock duration");
        require(_etherLiquidity >= MINIMUM_ETHER_LIQUIDITY, "BaseOperator: Not enough ether to provide liquidity");
        require(_minter == tokenData[_token].minterAddress, "BaseOperator: Wrong minter address");

        tokenData[_token].fundraiseAddress = IFundraiseFactory(fundraiseFactory).createFundraise(
            _token, 
            _amounts[uint(Amount.Launch)], 
            _oneTokenPrice, 
            _fundraiseStart, 
            _managementAddress
        );

        IERC20Token(_token).initialize(
            liquidityVault,
            _amounts[uint(Amount.Manage)] + _amounts[uint(Amount.Launch)],
            _amounts[uint(Amount.Liquid)],
            _minter
        );

        ILiquidityVault(liquidityVault)._initializeNewToken{value: _etherLiquidity}(
            _token, 
            _managementAddress, 
            _amounts[uint(Amount.Liquid)], 
            _fundraiseStart,
            _liquidityLockDuration
        );

        tokenData[_token].fundraiseStart = _fundraiseStart;
        tokenData[_token].amounts = _amounts;
        statusShiftInternal(_token, uint(Status.Fundraise));
        paymentInternal(_managementAddress);
        _managementAddress = tokenData[_token].fundraiseAddress;
    }

    function fundraiseParticipate(
        address _token, 
        uint _amount, 
        address _stablecoinAddress
    )
        external 
        nonReentrant() 
        paused()
    {
        address _user = msg.sender;
        statusVerificationInternal(_token, uint(Status.Fundraise));
        stablecoinAddressVerificationInternal(_stablecoinAddress);
        uint _underlyingAmount = IFundraise(tokenData[_token].fundraiseAddress).participate(_user, _amount, _stablecoinAddress);
        balanceVerificationInternal(_stablecoinAddress, _user, _underlyingAmount);
        IERC20(_stablecoinAddress).safeTransferFrom(_user, address(this), _underlyingAmount);
        if(_stablecoinAddress == USDCAddress){
            tokenData[_token].fundsRaised[0] += _underlyingAmount;
        }
        _stablecoinAddress == USDTAddress ? tokenData[_token].fundsRaised[1] += _underlyingAmount : tokenData[_token].fundsRaised[2] += _underlyingAmount;
    }

    function cancelFundraise(address _token)external onlyRole(DEFAULT_ADMIN_ROLE){
        statusVerificationInternal(_token, uint(Status.Fundraise));
        require(block.timestamp >= tokenData[_token].fundraiseStart + MINIMUM_TIME_TO_CANCEL_FUNDRAISE, "BaseOperator: Too soon to cancel");
        statusShiftInternal(_token, uint(Status.Cancellation));
    } 

    function refund(address _token, address _stablecoinAddress)external nonReentrant(){
        address _user = msg.sender;
        require(refunded[_user][_token] == false, "BaseOperator: Refunded already");
        statusVerificationInternal(_token, uint(Status.Cancellation));
        stablecoinAddressVerificationInternal(_stablecoinAddress);
        (uint _tier, , uint _spentAllocation) = IFundraise(tokenData[_token].fundraiseAddress)._userData(_user);
        uint _tokenPrice = IFundraise(tokenData[_token].fundraiseAddress).oneTokenPrice(_tier);
        uint _refundAmount = _tokenPrice * _spentAllocation;
        balanceVerificationInternal(_stablecoinAddress, address(this), _refundAmount);
        IERC20(_stablecoinAddress).safeTransfer(_user, _refundAmount);
        refunded[_user][_token] = true;
    }

    function createSimpleScheduleVesting( 
        address _token,
        uint[6] memory _cliffTimestamp
    )
        external 
        nonReentrant()
        paused()
        returns(address _vestingAddress)
    {   
        managementVerificationInternal(_token);
        statusVerificationInternal(_token, uint(Status.Fundraise));

        _vestingAddress = IVestingOperator(vestingOperator).createSimpleScheduleVesting( 
            tokenData[_token].managementAddress,
            _token,
            tokenData[_token].fundraiseAddress,
            _cliffTimestamp,
            tokenData[_token].fundraiseStart,
            tokenData[_token].amounts[uint(Amount.Manage)]
        );

        createVestingInternal(_token, _vestingAddress);
    }

    function createScheduleVesting( 
        address _token,
        uint[30] memory _cliffTimestamp, 
        uint[30] memory _cliffAmount
    )
        external 
        nonReentrant()
        paused()
        returns(address _vestingAddress)
    {
        managementVerificationInternal(_token);
        statusVerificationInternal(_token, uint(Status.Fundraise));

        _vestingAddress = IVestingOperator(vestingOperator).createScheduleVesting(  
            tokenData[_token].managementAddress,
            _token,
            tokenData[_token].fundraiseAddress,
            _cliffTimestamp, 
            _cliffAmount,
            tokenData[_token].fundraiseStart,
            tokenData[_token].amounts[uint(Amount.Manage)]
        );

        createVestingInternal(_token, _vestingAddress);
    }

    function createLinearVesting( 
        address _token,
        uint _vestingStartTimestamp,
        uint _vestingTeamStartTimestamp,
        uint _vestingDuration
    )
        external 
        nonReentrant()
        paused()
        returns(address _vestingAddress)
    {
        managementVerificationInternal(_token);
        statusVerificationInternal(_token, uint(Status.Fundraise));

        _vestingAddress = IVestingOperator(vestingOperator).createLinearVesting(  
            _token,  
            tokenData[_token].managementAddress, 
            tokenData[_token].fundraiseAddress, 
            tokenData[_token].fundraiseStart,
            tokenData[_token].amounts[uint(Amount.Manage)], 
            _vestingStartTimestamp,
            _vestingTeamStartTimestamp,
            _vestingDuration
        );

        createVestingInternal(_token, _vestingAddress);
    }

    function createCliffLinearVesting( 
        address _token,
        uint _vestingDuration,
        uint[6] memory _vestingStartTimestamp
    )
        external 
        nonReentrant()
        paused()
        returns(address _vestingAddress)
    {
        managementVerificationInternal(_token);
        statusVerificationInternal(_token, uint(Status.Fundraise));

        _vestingAddress = IVestingOperator(vestingOperator).createCliffLinearVesting(  
            _token,  
            tokenData[_token].managementAddress, 
            tokenData[_token].fundraiseAddress, 
            tokenData[_token].fundraiseStart,
            tokenData[_token].amounts[uint(Amount.Manage)],
            _vestingDuration,
            _vestingStartTimestamp
        );

        createVestingInternal(_token, _vestingAddress);
    }

    function changeOver()external onlyRole(DEFAULT_ADMIN_ROLE){
        _changeOver();
    }

    function tokenToAuditExternal(
        address _token,
        string calldata _name, 
        string calldata _symbol, 
        address _managementAddress
    )
        external 
        onlyRole(TOKEN_MINTER)
    {
        tokenData[_token].name = _name;
        tokenData[_token].symbol = _symbol;
        tokenData[_token].managementAddress = _managementAddress;
        tokenData[_token].status = uint(Status.Audit);
        allSupportedTokens.push(_token);
    }

    function statusShiftInternal(address _token, uint _status)internal { 
        tokenData[_token].status = _status;
    }

    function ratioVerificationInternal(uint _amount, uint _minimum, uint _totalAmount)internal pure {
        require(_amount * _minimum >= _totalAmount, "BaseOperator: Wrong tokens amounts ratio");
    }
            
    function statusVerificationInternal(address _token, uint _status)internal view {
        require(tokenData[_token].status == _status, "BaseOperator: Invalid status");
    }

    function balanceVerificationInternal(address _token, address _user, uint _kink)internal view {
        require(IERC20(_token).balanceOf(_user) >= _kink, "BaseOperator: Not enough tokens");
    }

    function stablecoinAddressVerificationInternal(address _stablecoinAddress)internal pure {
        require(_stablecoinAddress == USDCAddress || _stablecoinAddress == USDTAddress || _stablecoinAddress == BUSDAddress, "BaseOperator: Wrong stablecoin");
    }

    function managementVerificationInternal(address _token)internal view {   
        require(msg.sender == tokenData[_token].managementAddress, "BaseOperator: You are not a management");
    }
    
    function paymentInternal(address _managementAddress)internal {
        uint _halfPayment = DEFAULT_FUNDRAISE_PRICE / 2;
        IERC20(launchpadToken).safeTransferFrom(_managementAddress, launchpadStaking, _halfPayment);
        ILaunchpadToken(launchpadToken).burnFrom(_managementAddress, _halfPayment);
        ILaunchpadStaking(launchpadStaking)._addPaymentTokens(_halfPayment);
    }

    function createVestingInternal(address _token, address _vestingAddress)internal {
        tokenData[_token].vestingAddress = _vestingAddress;
        uint _amountToVesting = tokenData[_token].amounts[uint(Amount.Manage)] + tokenData[_token].amounts[uint(Amount.Launch)];
        IERC20(_token).safeTransfer(_vestingAddress, _amountToVesting);
        statusShiftInternal(_token, uint(Status.Launched));
        IERC20(USDCAddress).safeTransfer(tokenData[_token].managementAddress, tokenData[_token].fundsRaised[0]);
        IERC20(USDTAddress).safeTransfer(tokenData[_token].managementAddress, tokenData[_token].fundsRaised[1]);
        IERC20(BUSDAddress).safeTransfer(tokenData[_token].managementAddress, tokenData[_token].fundsRaised[2]);
    } 
}
