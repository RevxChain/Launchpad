// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "./utils/AccessControlOperator.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "@uniswap/v2-core/contracts/interfaces/IUniswapV2ERC20.sol";
import "./interfaces/ILiquidityRouter.sol";

contract LiquidityVault is AccessControlOperator, ReentrancyGuard {
    using SafeERC20 for IERC20; 

    uint public constant MINIMUM_TIME_TO_PROVIDE_START = 1 weeks;

    address public liquidityRouterAddress;

    bytes32 public constant DAO_ROLE = keccak256(abi.encode("DAO_ROLE"));

    mapping(address => LiquidityData) public liquidityData;

    struct LiquidityData {
        address managementAddress;
        address pairAddress;
        uint initializedTokensAmount;
        uint initializedEtherAmount;
        uint initiationTimestamp;
        uint lpTokensAmount;
        uint lockTimestamp;
    }

    constructor(address _liquidityRouterAddress){
        liquidityRouterAddress = _liquidityRouterAddress;
    }

    function _initializeNewToken(
        address _token, 
        address _managementAddress, 
        uint _tokensAmount, 
        uint _fundraiseStart,
        uint _liquidityLockDuration
    ) external payable onlyRole(DEFAULT_CALLER) {
        uint _value = msg.value;
        liquidityData[_token].managementAddress = _managementAddress;
        liquidityData[_token].initializedTokensAmount = _tokensAmount;
        liquidityData[_token].initializedEtherAmount = _value;
        liquidityData[_token].initiationTimestamp = _fundraiseStart + MINIMUM_TIME_TO_PROVIDE_START;
        if(_liquidityLockDuration == 0){
            liquidityData[_token].lockTimestamp = _liquidityLockDuration;
        }
        liquidityData[_token].lockTimestamp = block.timestamp + _liquidityLockDuration;
        
    }

    function addLiquidity(address _token, bytes calldata _data) external {
        require(liquidityData[_token].managementAddress != address(0), "LiquidityVault: Invalid token");
        require(liquidityData[_token].pairAddress == address(0), "LiquidityVault: Invalid token");
        require(liquidityData[_token].lpTokensAmount == 0, "LiquidityVault: Already provided");
        require(block.timestamp >= liquidityData[_token].initiationTimestamp, "LiquidityVault: Too soon");
        
        IERC20(_token).safeTransfer(liquidityRouterAddress, liquidityData[_token].initializedTokensAmount);

        ( , , uint _liquidity, address _pairAddress) = 
        ILiquidityRouter(liquidityRouterAddress).addLiquidityExternal
        {value: liquidityData[_token].initializedEtherAmount}(
            _token, 
            liquidityData[_token].initializedTokensAmount, 
            liquidityData[_token].lockTimestamp,
            _data
        );

        liquidityData[_token].lpTokensAmount = _liquidity;
        liquidityData[_token].pairAddress = _pairAddress;

    }

    function removeLiquidity(address _token, uint _amount) external {
        address _managementAddress = msg.sender;
        require(liquidityData[_token].managementAddress == _managementAddress, "LiquidityVault: You are not a management");
        require(liquidityData[_token].lpTokensAmount >= _amount, "LiquidityVault: Not enough lp tokens amount");
        require(block.timestamp >= liquidityData[_token].lockTimestamp, "LiquidityVault: Too soon");
        require(liquidityData[_token].lockTimestamp != 0, "LiquidityVault: Liquidity burnt");

        IERC20(liquidityData[_token].pairAddress).safeTransfer(_managementAddress, _amount);

        liquidityData[_token].lpTokensAmount -= _amount;

    }

    function setDAORole(address _launchpadDAOAddress) external onlyRole(DISPOSABLE_CALLER) {
        require(_launchpadDAOAddress != address(0), "LiquidityVault: DAO zero address");
        _setupRole(DAO_ROLE, _launchpadDAOAddress);
    }

    function updateRouterAddress(address _newRouterAddress) external onlyRole(DAO_ROLE) {
        liquidityRouterAddress = _newRouterAddress;
    }
}