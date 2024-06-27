// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./utils/AccessControlOperator.sol";

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

    bytes32 public constant DAO_ROLE = keccak256("DAO_ROLE");

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
    ) {
        launchpadToken = _launchpadToken;
        tokenFactory = _tokenFactory;
        launchpadStaking = _launchpadStaking;
        //_grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        defaultTokenMintPrice = 500e18; 
        ownTokenMintPrice = 10000e18; 
    }

    function createToken( 
        string calldata name, 
        string calldata symbol,
        uint mintUnlock,
        uint burnUnlock,
        uint initialSupply,
        bool toAudit
    ) external nonReentrant() returns(address tokenAddress) {
        address _managementAddress = msg.sender;
        require(IERC20(launchpadToken).balanceOf(_managementAddress) >= defaultTokenMintPrice, "TokenMinter: Not enough tokens to payment");

        tokenAddress = ITokenFactory(tokenFactory).createToken(name, symbol, mintUnlock, burnUnlock, getOperatorAddress());

        if(!toAudit){
            IERC20Token(tokenAddress).initialize(
                _managementAddress,
                0,
                initialSupply,
                _managementAddress
            );

            tokenData[tokenAddress].name = name;
            tokenData[tokenAddress].symbol = symbol;
            tokenData[tokenAddress].managementAddress = _managementAddress;
            allNotSupportedTokens.push(tokenAddress);
        } else {
            IBaseOperator(getOperatorAddress()).tokenToAuditExternal(tokenAddress, name, symbol, _managementAddress);
        }
        
        ILaunchpadToken(launchpadToken).burnFrom(_managementAddress, defaultTokenMintPrice);
    }

    function createOwnToken(
        string calldata name, 
        string calldata symbol, 
        uint totalSupply, 
        uint decimals
    ) external nonReentrant() returns(address tokenAddress) {
        address _managementAddress = tx.origin;
        require(IERC20(launchpadToken).balanceOf(_managementAddress) >= defaultTokenMintPrice, "TokenMinter: Not enough tokens to payment");
        require(totalSupply == 0, "TokenMinter: Invalid data");
        require(decimals == 18, "TokenMinter: Invalid data");

        tokenAddress = msg.sender;
        
        IBaseOperator(getOperatorAddress()).tokenToAuditExternal(tokenAddress, name, symbol, _managementAddress);

        ILaunchpadToken(launchpadToken).burnFrom(_managementAddress, ownTokenMintPrice);
    }

    function setDAORole(address launchpadDAOAddress) external onlyRole(DISPOSABLE_CALLER) {
        require(launchpadDAOAddress != address(0), "TokenMinter: DAO zero address");
        _grantRole(DAO_ROLE, launchpadDAOAddress);
    }

    function updatePrice(uint priceTypeId, uint newValue) external onlyRole(DAO_ROLE) {
        if(priceTypeId == 0){
            defaultTokenMintPrice = newValue;
        } else {
            ownTokenMintPrice = newValue;
        }
    }
}

       