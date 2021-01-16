pragma solidity ^0.6.9;

import "../Utils/Owned.sol";

import "../../interfaces/IUnicrypt.sol";
import "../Access/MISOAccessControls.sol";

contract UnicryptVault{
    IUnicrypt public unicrypt;
    
    MISOAccessControls public accessControls;
    bool private initialised;

    function initUnicryptVault(address _accessControls, IUnicrypt _unicrypt) public{
        require(!initialised);
        accessControls = MISOAccessControls(_accessControls);
        //Can directly use the required mainnet address
        unicrypt = _unicrypt;
    }
    //Dont think this is required
    /* function depositToken(address token, uint256 amount, uint256 unlock_date) public{
        require(unlock_date < 10000000000, 'Enter an unix timestamp in seconds, not miliseconds');
        require(amount > 0, 'Your attempting to trasfer 0 tokens');
        // add call to LP tokens???
        
        require(token != address(0));
        
        
        unicrypt.depositToken(token,amount,unlock_date);
    } */

}