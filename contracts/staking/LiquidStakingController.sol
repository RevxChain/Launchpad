// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../interfaces/ILiquidLaunchpadStaking.sol";

contract LiquidStakingController is AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;

    bytes32 public constant VOTER_ROLE = keccak256("VOTER_ROLE");
    bytes32 public constant BRIBE_MANAGER_ROLE = keccak256("BRIBE_MANAGER_ROLE");
    bytes32 public constant BRIBE_WITHDRAWER_ROLE = keccak256("BRIBE_WITHDRAWER_ROLE");

    struct voteCalldata {
        address[] modules;
        bytes32[] proposalId; 
        bool[] vote;
        bool[] proposalType;
    }

    constructor () {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function vote(voteCalldata calldata $) external onlyRole(VOTER_ROLE) {
        uint _length = $.modules.length;
        require(
            _length == $.proposalId.length &&
            _length == $.vote.length &&
            _length == $.proposalType.length,
            "LiquidStakingController: invalid data"
        );

        for(uint i; _length > i; i++){
            ILiquidLaunchpadStaking($.modules[i]).vote($.proposalId[i], $.vote[i], $.proposalType[i]);
        }

    }

    function setBribePrices(
        address module,
        address[] calldata tokens, 
        uint[] calldata prices, 
        address priceVerifier
    ) external onlyRole(BRIBE_MANAGER_ROLE) {
        ILiquidLaunchpadStaking(module).setBribePrices(tokens, prices, priceVerifier);
    }

    function openBribe(address module, uint openToTimestamp, address priceVerifier) external onlyRole(BRIBE_MANAGER_ROLE) {
        ILiquidLaunchpadStaking(module).openBribe(openToTimestamp, priceVerifier);
    }

    function setBribeTime(address module, uint openToTimestamp) external onlyRole(BRIBE_MANAGER_ROLE) {
        ILiquidLaunchpadStaking(module).setBribeTime(openToTimestamp);
    }

    function closeBribe(address module) external onlyRole(BRIBE_MANAGER_ROLE) {
        ILiquidLaunchpadStaking(module).closeBribe();
    }

    function withdrawBribes(
        address module,
        address[] calldata tokens, 
        uint[] calldata amounts, 
        address[] calldata receivers
    ) external onlyRole(BRIBE_WITHDRAWER_ROLE) {
        ILiquidLaunchpadStaking(module).withdrawBribes(tokens, amounts, receivers);
    }

}