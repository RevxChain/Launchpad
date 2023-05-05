// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "./utils/AccessControlOperator.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./interfaces/IFundraiseFactory.sol";
import "./interfaces/IBaseOperator.sol";
import "./interfaces/ITokenFactory.sol";
import "./interfaces/IVestingOperator.sol";
import "./interfaces/ILaunchpadStaking.sol";
import "./interfaces/ILaunchpadToken.sol";
import "./interfaces/ILiquidityVault.sol";
import "./interfaces/IOwnTokenSample.sol";

contract TokenMinter is AccessControlOperator, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint public defaultTokenMintPrice; 
    uint public ownTokenMintPrice;

    address public immutable launchpadToken;
    address public immutable launchpadStaking;
    address public immutable tokenFactory;

    bytes32 public constant DAO_ROLE = keccak256(abi.encode("DAO_ROLE"));

    mapping(address => NotSupportedTokenData) public tokenData; 

    address[] public allNotSupportedTokens;

    struct NotSupportedTokenData {
        string name;
        string symbol;
        address managementAddress;
    }

    constructor(
        address _launchpadToken,  
        address _tokenFactory, 
        address _launchpadStaking
    )
    {
        launchpadToken = _launchpadToken;
        tokenFactory = _tokenFactory;
        launchpadStaking = _launchpadStaking;
        //_setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        defaultTokenMintPrice = 500; //500e18;
        ownTokenMintPrice = 10000; // 10000e18
    }

    function createToken( 
        string calldata _name, 
        string calldata _symbol,
        uint _mintUnlock,
        uint _burnUnlock,
        uint _initialSupply,
        bool _toAudit
    )
        external 
        nonReentrant()
        returns(address _tokenAddress)
    {
        address _managementAddress = msg.sender;
        require(IERC20(launchpadToken).balanceOf(_managementAddress) >= defaultTokenMintPrice, "BaseOperator: Not enough tokens to payment");

        _tokenAddress = ITokenFactory(tokenFactory).createToken(_name, _symbol, _mintUnlock, _burnUnlock, viewOperatorAddress());

        if(_toAudit == false){
            IERC20Token(_tokenAddress).initialize(
                _managementAddress,
                0,
                _initialSupply,
                _managementAddress
            );

            tokenData[_tokenAddress].name = _name;
            tokenData[_tokenAddress].symbol = _symbol;
            tokenData[_tokenAddress].managementAddress = _managementAddress;
            allNotSupportedTokens.push(_tokenAddress);
        } else {
            IBaseOperator(viewOperatorAddress()).tokenToAuditExternal(_tokenAddress, _name, _symbol, _managementAddress);
        }
        
        ILaunchpadToken(launchpadToken).burnFrom(_managementAddress, defaultTokenMintPrice);
    }

    function createOwnToken(
        string calldata _name, 
        string calldata _symbol, 
        uint _totalSupply, 
        uint _decimals
    )
        external 
        nonReentrant() 
        returns(address _tokenAddress)
    {
        address _managementAddress = tx.origin;
        require(IERC20(launchpadToken).balanceOf(_managementAddress) >= defaultTokenMintPrice, "BaseOperator: Not enough tokens to payment");
        require(_totalSupply == 0, "Invalid data");
        require(_decimals == 18, "Invalid data");

        _tokenAddress = msg.sender;
        
        IBaseOperator(viewOperatorAddress()).tokenToAuditExternal(_tokenAddress, _name, _symbol, _managementAddress);

        ILaunchpadToken(launchpadToken).burnFrom(_managementAddress, ownTokenMintPrice);
    }

    function setDAORole(address _launchpadDAOAddress)external onlyRole(DISPOSABLE_CALLER){
        require(_launchpadDAOAddress != address(0), "LiquidityVault: DAO zero address");
        _setupRole(DAO_ROLE, _launchpadDAOAddress);
    }

    function updatePrice(uint _priceTypeId, uint _newValue)external onlyRole(DAO_ROLE){
        if(_priceTypeId == 0){
            defaultTokenMintPrice = _newValue;
        } else {
            ownTokenMintPrice = _newValue;
        }
    }

}

       