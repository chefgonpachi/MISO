pragma solidity ^0.6.9;

import "./ERC20.sol";
import "../../interfaces/IMisoToken.sol";

contract FixedToken is ERC20, IMisoToken {

    bool private initialised;
    
    function initToken(string memory _name, string memory _symbol, address owner) external override {
        _initERC20(_name, _symbol);
    }
    
    function initFixedTotalSupply(uint256 _fixedSupply) public  {
        require(!initialised);
        initialised = true;
        _mint(msg.sender, _fixedSupply);
    }
}
