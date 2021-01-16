pragma solidity ^0.6.9;

import "./ERC20.sol";
import "../../interfaces/IMisoToken.sol";

contract FixedToken is ERC20, IMisoToken {

    
    /// @dev First set the token variables. This can only be done once
    function initToken(string memory _name, string memory _symbol, address _owner, uint256 _initialSupply) external override {
        _initERC20(_name, _symbol);
        _mint(msg.sender, _initialSupply);
    }
    
}
