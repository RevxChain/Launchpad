// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

import "./utils/AccessControlOperator.sol";

contract ERC20Token is ERC20Burnable, AccessControl {

    uint private initializeLock;
    uint private immutable mintUnlock;
    uint private immutable burnUnlock;

    address private immutable operatorAddress;

    bytes32 private constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 private constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

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
    ) ERC20(_name, _symbol) {
        operatorAddress = _operatorAddress;
        mintUnlock = _mintUnlock;
        burnUnlock = _burnUnlock;

        _grantRole(OPERATOR_ROLE, _operatorAddress);
        _grantRole(OPERATOR_ROLE, _tokenMinter);
    } 

    function initialize(
        address liquidityVault,
        uint vestingAmount,
        uint liquidityAmount,
        address minter
    ) external onlyRole(OPERATOR_ROLE) {
        require(initializeLock == 0, "ERC20Token: Initialized");
        _mint(operatorAddress, vestingAmount);
        _mint(liquidityVault, liquidityAmount);
        initializeLock = 1;
        if(mintUnlock == 1) _grantRole(MINTER_ROLE, minter);
    }

    function mintTo(address to, uint amount) external onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    function burn(uint256 amount) public override burnLocked() {
        super._burn(msg.sender, amount);
    }

    function burnFrom(address account, uint256 amount) public override burnLocked() {
        super.burnFrom(account, amount);
    }

}

contract TokenFactory is AccessControlOperator { 
    
    function createToken(
        string calldata name, 
        string calldata symbol,
        uint mintUnlock,
        uint burnUnlock,
        address operatorAddress
    ) external onlyRole(DEFAULT_CALLER) returns(address tokenAddress) {
        ERC20Token _token = new ERC20Token(
            name, 
            symbol, 
            operatorAddress, 
            mintUnlock, 
            burnUnlock, 
            getOperatorAddress()
        );
        tokenAddress = address(_token); 
    }
}
