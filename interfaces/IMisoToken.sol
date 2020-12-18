pragma solidity ^0.6.9;

interface IMisoToken {
    function initToken(string memory _name, string memory _symbol, address owner) external;
}