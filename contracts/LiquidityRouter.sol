// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "./utils/AccessControlOperator.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol"; 
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2ERC20.sol";

contract LiquidityRouter is AccessControlOperator, ReentrancyGuard {

    uint public constant DEADLINE_DURATION = 300;

    address public immutable uniswapRouterAddress;
    address public immutable uniswapFactoryAddress;

    address public constant WETH = 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4; // hardcoded to Ethereum mainnet


    constructor(address _uniswapRouterAddress, address _uniswapFactoryAddress){// need to hardcode too
        uniswapRouterAddress = _uniswapRouterAddress;
        uniswapFactoryAddress = _uniswapFactoryAddress;
    }

    function addLiquidityExternal(
        address _token, 
        uint _tokenAmount, 
        uint _burn,
        bytes calldata _data
    )
        external 
        payable 
        onlyRole(DEFAULT_CALLER)
        returns(
            uint _amountToken, 
            uint _amountETH, 
            uint _liquidity,
            address _pairAddress
        )
    {
        uint _etherValue = msg.value;
        (_amountToken, _amountETH, _liquidity, _pairAddress) = addLiquidityInternal(_token, _tokenAmount, _etherValue, _burn);

    }

    function addLiquidityInternal(
        address _token, 
        uint _amountTokenDesired, 
        uint _etherValue,
        uint _burn
    )
        internal 
        returns(
            uint _amountToken, 
            uint _amountETH, 
            uint _liquidity,
            address _pairAddress
        )
    {   
        address _receiver = viewOperatorAddress();
        if(_burn == 0){
            _receiver = address(0);
        }
        (_amountToken, _amountETH, _liquidity) = IUniswapV2Router02(uniswapRouterAddress).addLiquidityETH{value: _etherValue}(
            _token,
            _amountTokenDesired,
            _amountTokenDesired,
            _etherValue,
            _receiver,
            block.timestamp + DEADLINE_DURATION
        );

        _pairAddress = IUniswapV2Factory(uniswapFactoryAddress).getPair(_token, WETH);
        require(IUniswapV2ERC20(_pairAddress).balanceOf(_receiver) >= _liquidity, "0x00");
    }

}

