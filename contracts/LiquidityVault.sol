// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "@uniswap/v2-core/contracts/interfaces/IUniswapV2ERC20.sol";

import "./utils/AccessControlOperator.sol";

import "./interfaces/ILiquidityRouter.sol";

contract LiquidityVault is AccessControlOperator, ReentrancyGuard {
    using SafeERC20 for IERC20; 

    uint public constant MINIMUM_TIME_TO_PROVIDE_START = 1 weeks;

    address public liquidityRouterAddress;

    bytes32 public constant DAO_ROLE = keccak256("DAO_ROLE");

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
        address token, 
        address managementAddress, 
        uint tokensAmount, 
        uint fundraiseStart,
        uint liquidityLockDuration
    ) external payable onlyRole(DEFAULT_CALLER) {
        uint _value = msg.value;
        liquidityData[token].managementAddress = managementAddress;
        liquidityData[token].initializedTokensAmount = tokensAmount;
        liquidityData[token].initializedEtherAmount = _value;
        liquidityData[token].initiationTimestamp = fundraiseStart + MINIMUM_TIME_TO_PROVIDE_START;
        if(liquidityLockDuration == 0) liquidityData[token].lockTimestamp = liquidityLockDuration;
        liquidityData[token].lockTimestamp = block.timestamp + liquidityLockDuration;
    }

    function addLiquidity(address token, bytes calldata data) external {
        require(liquidityData[token].managementAddress != address(0), "LiquidityVault: Invalid token");
        require(liquidityData[token].pairAddress == address(0), "LiquidityVault: Invalid token");
        require(liquidityData[token].lpTokensAmount == 0, "LiquidityVault: Already provided");
        require(block.timestamp >= liquidityData[token].initiationTimestamp, "LiquidityVault: Too soon");
        
        IERC20(token).safeTransfer(liquidityRouterAddress, liquidityData[token].initializedTokensAmount);

        ( , , uint _liquidity, address _pairAddress) = 
        ILiquidityRouter(liquidityRouterAddress).addLiquidityExternal
        {value: liquidityData[token].initializedEtherAmount}(
            token, 
            liquidityData[token].initializedTokensAmount, 
            liquidityData[token].lockTimestamp,
            data
        );

        liquidityData[token].lpTokensAmount = _liquidity;
        liquidityData[token].pairAddress = _pairAddress;
    }

    function removeLiquidity(address token, uint amount) external {
        address _managementAddress = msg.sender;
        require(liquidityData[token].managementAddress == _managementAddress, "LiquidityVault: You are not a management");
        require(liquidityData[token].lpTokensAmount >= amount, "LiquidityVault: Not enough lp tokens amount");
        require(block.timestamp >= liquidityData[token].lockTimestamp, "LiquidityVault: Too soon");
        require(liquidityData[token].lockTimestamp != 0, "LiquidityVault: Liquidity burnt");

        liquidityData[token].lpTokensAmount -= amount;

        IERC20(liquidityData[token].pairAddress).safeTransfer(_managementAddress, amount);
    }

    function setDAORole(address launchpadDAOAddress) external onlyRole(DISPOSABLE_CALLER) {
        require(launchpadDAOAddress != address(0), "LiquidityVault: DAO zero address");
        _grantRole(DAO_ROLE, launchpadDAOAddress);
    }

    function updateRouterAddress(address newRouterAddress) external onlyRole(DAO_ROLE) {
        liquidityRouterAddress = newRouterAddress;
    }
}