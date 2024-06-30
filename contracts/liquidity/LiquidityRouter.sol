// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol"; 
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2ERC20.sol";

import "../utils/AccessControlOperator.sol";

contract LiquidityRouter is AccessControlOperator, ReentrancyGuard {

    address public immutable uniswapRouterAddress;
    address public immutable uniswapFactoryAddress;

    address public constant WETH = address(0); // hardcoded to required network

    constructor(address _uniswapRouterAddress, address _uniswapFactoryAddress){
        uniswapRouterAddress = _uniswapRouterAddress;
        uniswapFactoryAddress = _uniswapFactoryAddress;
    }

    function addLiquidityExternal(
        address token, 
        uint tokenAmount, 
        uint burn,
        bytes calldata /* data */
    )
        external 
        payable 
        onlyRole(DEFAULT_CALLER)
        returns(
            uint amountToken, 
            uint amountETH, 
            uint liquidity,
            address pairAddress
        )
    {
        (amountToken, amountETH, liquidity, pairAddress) = addLiquidityInternal(token, tokenAmount, msg.value, burn);

    }

    function addLiquidityInternal(
        address token, 
        uint amountTokenDesired, 
        uint etherValue,
        uint burn
    )
        internal 
        returns(
            uint amountToken, 
            uint amountETH, 
            uint liquidity,
            address pairAddress
        )
    {   
        address _receiver = getOperatorAddress();
        if(burn == 0) _receiver = address(0);

        (amountToken, amountETH, liquidity) = IUniswapV2Router02(uniswapRouterAddress).addLiquidityETH{value: etherValue}(
            token,
            amountTokenDesired,
            amountTokenDesired,
            etherValue,
            _receiver,
            block.timestamp
        );

        pairAddress = IUniswapV2Factory(uniswapFactoryAddress).getPair(token, WETH);
        require(IUniswapV2ERC20(pairAddress).balanceOf(_receiver) >= liquidity, "LiquidityRouter: 0x00");
    }
}

