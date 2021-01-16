pragma solidity ^0.6.9;

// ----------------------------------------------------------------------------
// BokkyPooBahs White List
//
//
// Enjoy.
//
// (c) BokkyPooBah / Bok Consulting Pty Ltd. The MIT Licence.
// ----------------------------------------------------------------------------

import "./MISOAccessControls.sol";
import "../../interfaces/IWhiteList.sol";


// ----------------------------------------------------------------------------
// White List - on list or not
// ----------------------------------------------------------------------------
contract WhiteList is IWhiteList  {
    mapping(address => bool) public whiteList;
    MISOAccessControls public accessControls;
    bool private initialised;

    event AccountListed(address indexed account, bool status);

    constructor() public {
    }

    function initWhiteList(address _accessControls) public override{
        require(!initialised, "Already initialised");
        accessControls = MISOAccessControls(_accessControls);
        initialised = true;
    }

    function isInWhiteList(address account) public view override returns (bool) {
        return whiteList[account];
    }

    function addWhiteList(address[] memory accounts) public override {  
        require(
            accessControls.hasOperatorRole(msg.sender),
            "Whitelist.addWhiteList: Sender must be operator"
        );
        require(accounts.length != 0);
        for (uint i = 0; i < accounts.length; i++) {
            require(accounts[i] != address(0));
            if (!whiteList[accounts[i]]) {
                whiteList[accounts[i]] = true;
                emit AccountListed(accounts[i], true);
            }
        }
    }
    function removeWhiteList(address[] memory accounts) public override {
        require(
            accessControls.hasOperatorRole(msg.sender),
            "Whitelist.removeWhiteList: Sender must be operator"
        );        require(accounts.length != 0);
        for (uint i = 0; i < accounts.length; i++) {
            require(accounts[i] != address(0));
            if (whiteList[accounts[i]]) {
                delete whiteList[accounts[i]];
                emit AccountListed(accounts[i], false);
            }
        }
    }
}
