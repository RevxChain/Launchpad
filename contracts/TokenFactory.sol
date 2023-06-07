// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "./utils/AccessControlOperator.sol";

contract ERC20Token is ERC20, ERC20Burnable, AccessControl {

    uint private initializeLock;
    uint private immutable mintUnlock;
    uint private immutable burnUnlock;

    address private immutable operatorAddress;

    bytes32 private constant MINTER_ROLE = keccak256(abi.encode("MINTER_ROLE"));
    bytes32 private constant OPERATOR_ROLE = keccak256(abi.encode("OPERATOR_ROLE"));

    modifier burnLocked(){
        require(burnUnlock == 1, "ERC20Token: Not allow to burn");
        _;
    }

    constructor(
        string memory _name, 
        string memory _symbol, 
        address _operatorAddress,
        uint _mintUnlock,
        uint _burnUnlock,
        address _tokenMinter
    ) 
        ERC20(_name, _symbol)
    {
        operatorAddress = _operatorAddress;
        mintUnlock = _mintUnlock;
        burnUnlock = _burnUnlock;

        _setupRole(OPERATOR_ROLE, _operatorAddress);
        _setupRole(OPERATOR_ROLE, _tokenMinter);
    } 

    function initialize(
        address _liquidityVault,
        uint _vestingAmount,
        uint _liquidityAmount,
        address _minter
    ) external onlyRole(OPERATOR_ROLE){
        require(initializeLock == 0, "ERC20Token: Initialized");
        _mint(operatorAddress, _vestingAmount);
        _mint(_liquidityVault, _liquidityAmount);
        initializeLock = 1;
        if(mintUnlock == 1){
            _setupRole(MINTER_ROLE, _minter);
        }
    }

    function mintTo(address _to, uint _amount)external onlyRole(MINTER_ROLE){
        _mint(_to, _amount);
    }

    function burn(uint256 amount)public override burnLocked() {
        super._burn(msg.sender, amount);
    }

    function burnFrom(address account, uint256 amount)public override burnLocked() {
        super.burnFrom(account, amount);
    }

}

contract TokenFactory is AccessControlOperator { 
    
    function createToken(
        string calldata _name, 
        string calldata _symbol,
        uint _mintUnlock,
        uint _burnUnlock,
        address _operatorAddress
    )   
        external 
        onlyRole(DEFAULT_CALLER) 
        returns(address _address)
    {
        ERC20Token _token = new ERC20Token(
            _name, 
            _symbol, 
            _operatorAddress, 
            _mintUnlock, 
            _burnUnlock, 
            viewOperatorAddress()
        );
        _address = address(_token); 
    }

}
